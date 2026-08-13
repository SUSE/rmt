#!/usr/bin/env bash
# Suite 02 — RPM upgrade paths.
#
# Part A: cross-major, cross-distro. RMT 2.x RPM on Leap 15.6 initialises a
#         database; that database is carried to Leap 16.0 and the 3.1 RPM's
#         rmt-server-migration.service command is run over it. This mirrors
#         the real 2.x -> 3.x customer upgrade, which necessarily involves a
#         distro upgrade and therefore cannot be a single `zypper up`.
#
# Part B: same-distro, in-place. `zypper up` from the previous 3.x release to
#         3.1 on Leap 16.0. This is a genuine RPM transaction, so it exercises
#         the %post upgrade branch ($1 -eq 2) — ssl relocation, system_uuid
#         move, permission fixups — that Part A cannot reach.
#
# Set RMT_RPM_DIR to a directory of locally built rmt-server RPMs to upgrade to
# those instead of the published ones (see ci/rmt-build-rpm).

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

SUITE='suite 02 (RPM upgrade)'
MIGRATION_CMD='/usr/share/rmt/bin/rails db:create db:migrate RAILS_ENV=production'
TARGET_VERSION="$(ruby -e 'require "./lib/rmt.rb"; print RMT::VERSION' 2>/dev/null \
                  || grep -oP "VERSION \|\|= '\K[^']+" "$REPO_ROOT/lib/rmt.rb")"

log "$SUITE — target version $TARGET_VERSION"

if ! curl -sf -o /dev/null --max-time 20 "${RMT_NEW_REPO:-https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/16.0/}"; then
  skip 'OBS download server unreachable — suite 02 needs network access'
  summary "$SUITE"
  exit 0
fi

mkdir -p "$FIXTURES_DIR/no-local-rpms" "$ARTIFACTS_DIR"

# Rewrite the packaged /etc/rmt.conf database block to point at a test DB.
write_rmt_conf() { # <service> <db host>
  compose exec -T "$1" bash -c "cat > /etc/rmt.conf <<'EOF'
database:
  host: $2
  database: rmt
  username: rmt
  password: rmt
  adapter: mysql2
  encoding: utf8
  timeout: 5000
  pool: 5

scc:
  username:
  password:
  sync_systems: true

mirroring:
  mirror_drpm: true
  mirror_src: false
  dedup_method: hardlink

http_client:
  verbose: false
EOF
chown root:nginx /etc/rmt.conf 2>/dev/null || true
chmod 0640 /etc/rmt.conf"
}

# ============================================================== Part A ======

log 'Part A — RMT 2.x (Leap 15.6) database carried to RMT 3.x (Leap 16.0)'

log 'building 2.x RPM container'
compose build rpm-old
compose_up_db db-old
db_reset db-old
compose up -d rpm-old >/dev/null

old_version="$(in_service rpm-old "rpm -q --qf '%{VERSION}' rmt-server")"
debug "installed old package: rmt-server-$old_version"
assert_contains "$old_version" '2.' 'Part A baseline is an RMT 2.x package'

write_rmt_conf rpm-old db-old

log 'running the 2.x rmt-server-migration.service command'
old_migrate="$(in_service rpm-old "cd /usr/share/rmt && $MIGRATION_CMD 2>&1")" \
  || { echo "$old_migrate" | tail -30 | sed 's/^/    /'; die 'the 2.x package failed to initialise its database'; }

log 'seeding representative data into the 2.x database'
db_load db-old "$MIGTEST_DIR/lib/seed.sql"
if column_exists db-old systems proxy_byos; then
  db_sql db-old 'UPDATE systems SET proxy_byos = 1 WHERE id IN (1,3);'
  debug 'systems.proxy_byos populated'
fi

pre_systems="$(row_count db-old systems)"
pre_activations="$(row_count db-old activations)"
db_dump db-old "$ARTIFACTS_DIR/rpm-upgrade-2x.sql"

log 'carrying the database to the 3.x MariaDB'
compose_up_db db-new
db_reset db-new
db_load db-new "$ARTIFACTS_DIR/rpm-upgrade-2x.sql"

log 'building 3.x RPM container'
compose build rpm-new
compose up -d --force-recreate rpm-new >/dev/null
write_rmt_conf rpm-new db-new

# Bring the container up to the version under test before migrating.
# rmt-server and rmt-server-config are version-locked to each other, so they
# must move in one transaction. --allow-vendor-change covers the case where the
# installed config package came from the distro rather than the OBS repo.
upgrade_to_target() { # <service>
  if compose exec -T "$1" bash -c 'ls /local-rpms/rmt-server-*.rpm >/dev/null 2>&1'; then
    debug 'upgrading from locally built RPMs in /local-rpms'
    compose exec -T "$1" bash -c \
      'zypper --non-interactive --no-gpg-checks install --allow-unsigned-rpm --allow-vendor-change /local-rpms/rmt-server-*.rpm 2>&1'
  else
    debug "upgrading from the published repo to rmt-server=$TARGET_VERSION"
    compose exec -T "$1" bash -c \
      "zypper --non-interactive --gpg-auto-import-keys refresh >/dev/null &&
       zypper --non-interactive install --no-recommends --allow-vendor-change \
         'rmt-server=$TARGET_VERSION' 'rmt-server-config=$TARGET_VERSION' 2>&1"
  fi
}

log "upgrading rpm-new to $TARGET_VERSION"
upgrade_out="$(upgrade_to_target rpm-new)" || { echo "$upgrade_out" | tail -30 | sed 's/^/    /'; bad 'zypper upgrade failed'; }
new_version="$(in_service rpm-new "rpm -q --qf '%{VERSION}' rmt-server")"
assert_eq "$TARGET_VERSION" "$new_version" "rmt-server upgraded to $TARGET_VERSION"

log 'running the 3.x rmt-server-migration.service command over the 2.x database'
new_migrate="$(in_service rpm-new "cd /usr/share/rmt && $MIGRATION_CMD 2>&1")" \
  || { echo "$new_migrate" | tail -40 | sed 's/^/    /'; bad 'db:migrate failed on the carried-over database'; }
echo "$new_migrate" | grep -E 'migrating|migrated|Error' | sed 's/^/    /' || true

log 'asserting Part A results'
if column_exists db-new systems proxy_byos; then
  bad 'systems.proxy_byos survived the RPM upgrade'
else
  ok 'systems.proxy_byos removed by the upgrade'
fi
assert_eq 'longtext' "$(column_type db-new profiles data)" 'profiles.data widened to LONGTEXT'
assert_eq "$pre_systems"     "$(row_count db-new systems)"     'systems preserved across the upgrade'
assert_eq "$pre_activations" "$(row_count db-new activations)" 'activations preserved across the upgrade'

log 'asserting the upgraded installation is usable'
cli_version="$(in_service rpm-new 'rmt-cli version 2>&1' || true)"
assert_contains "$cli_version" "$TARGET_VERSION" 'rmt-cli reports the new version'

repos_out="$(in_service rpm-new 'rmt-cli repos list --all 2>&1' || true)"
assert_contains "$repos_out" 'SLE-Product-SLES15-SP6-Pool' 'rmt-cli reads repositories from the migrated DB'

systems_out="$(in_service rpm-new 'rmt-cli systems list 2>&1' || true)"
assert_contains "$systems_out" 'SCC_abc123' 'rmt-cli reads systems from the migrated DB'

for unit in rmt-server.service rmt-server-migration.service rmt-server.target rmt-server-mirror.timer; do
  if in_service rpm-new "test -f /usr/lib/systemd/system/$unit"; then
    ok "unit installed: $unit"
  else
    bad "unit missing after upgrade: $unit"
  fi
done

# ============================================================== Part B ======

log 'Part B — in-place zypper upgrade on Leap 16.0 (real %post upgrade branch)'

compose up -d --force-recreate rpm-new >/dev/null
write_rmt_conf rpm-new db-new
db_reset db-new

prev_version="$(in_service rpm-new "rpm -q --qf '%{VERSION}' rmt-server")"
if [[ "$prev_version" == "$TARGET_VERSION" ]]; then
  skip "no earlier 3.x package available to upgrade from (already $TARGET_VERSION)"
  summary "$SUITE"
  exit $?
fi
debug "starting from rmt-server-$prev_version"

log 'initialising the database with the previous 3.x release'
in_service rpm-new "cd /usr/share/rmt && $MIGRATION_CMD >/dev/null 2>&1" \
  || bad "the $prev_version package failed to initialise its database"
db_load db-new "$MIGTEST_DIR/lib/seed.sql"
partb_systems="$(row_count db-new systems)"
prev_versions="$(migration_versions db-new)"

# Pre-create the legacy layout the %post upgrade branch is supposed to fix up.
log 'planting legacy ssl/ and system_uuid to exercise the %post relocations'
in_service rpm-new 'mkdir -p /usr/share/rmt/ssl &&
                    echo legacy-ca-cert > /usr/share/rmt/ssl/rmt-ca.crt &&
                    echo legacy-ca-key  > /usr/share/rmt/ssl/rmt-ca.key &&
                    echo legacy-uuid    > /usr/share/rmt/config/system_uuid'

log "upgrading in place to $TARGET_VERSION"
partb_out="$(upgrade_to_target rpm-new)" || { echo "$partb_out" | tail -30 | sed 's/^/    /'; bad 'in-place zypper upgrade failed'; }
echo "$partb_out" | grep -iE 'migration in progress|ssl configuration|error|warning' | sed 's/^/    /' || true

assert_eq "$TARGET_VERSION" "$(in_service rpm-new "rpm -q --qf '%{VERSION}' rmt-server")" \
  'in-place upgrade landed on the target version'
assert_contains "$partb_out" 'RMT database migration in progress' '%post took the upgrade branch, not the install branch'

log 'asserting %post relocations'
if in_service rpm-new 'test -f /etc/rmt/ssl/rmt-ca.crt'; then
  ok 'SSL material moved to /etc/rmt/ssl'
  assert_eq 'legacy-ca-cert' "$(in_service rpm-new 'cat /etc/rmt/ssl/rmt-ca.crt')" 'SSL certificate content intact'
  assert_eq 'legacy-ca-key'  "$(in_service rpm-new 'cat /etc/rmt/ssl/rmt-ca.key')" 'SSL key content intact'
else
  bad 'SSL material was not moved to /etc/rmt/ssl'
fi

if in_service rpm-new 'test -f /var/lib/rmt/system_uuid'; then
  ok 'system_uuid moved to /var/lib/rmt'
  assert_eq 'legacy-uuid' "$(in_service rpm-new 'cat /var/lib/rmt/system_uuid')" 'system_uuid content intact'
else
  bad 'system_uuid was not moved to /var/lib/rmt'
fi

log 'running the migration service command after the in-place upgrade'
in_service rpm-new "cd /usr/share/rmt && $MIGRATION_CMD >/dev/null 2>&1" \
  || bad 'db:migrate failed after the in-place upgrade'

assert_eq "$partb_systems" "$(row_count db-new systems)" 'data preserved across the in-place upgrade'
new_migrations="$(comm -13 <(echo "$prev_versions") <(migration_versions db-new) | tr '\n' ' ')"
debug "migrations added by $prev_version -> $TARGET_VERSION: ${new_migrations:-none}"

assert_contains "$(in_service rpm-new 'rmt-cli systems list 2>&1' || true)" 'SCC_abc123' \
  'rmt-cli works after the in-place upgrade'

# _rmt must still own what the migration service (User=_rmt) writes to.
owner="$(in_service rpm-new "stat -c '%U' /var/lib/rmt" || true)"
assert_eq '_rmt' "$owner" '/var/lib/rmt still owned by _rmt after upgrade'

summary "$SUITE"
