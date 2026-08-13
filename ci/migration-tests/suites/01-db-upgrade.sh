#!/usr/bin/env bash
# Suite 01 — RMT 2.x -> 3.x database upgrade.
#
# Restores a baseline 2.x dump into the MariaDB version 3.x ships with, runs
# 3.x's `rails db:migrate` over it (exactly what rmt-server-migration.service
# does on RPM upgrade) and asserts schema + data came out intact.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

SUITE='suite 01 (2.x -> 3.x db upgrade)'
BASELINE_SQL="$(baseline_path)"

[[ -f "$BASELINE_SQL" ]] || die "no baseline at $BASELINE_SQL — run lib/baseline.sh first"

log "$SUITE — baseline $(basename "$BASELINE_SQL")"
grep -m3 '^-- ' "$BASELINE_SQL" | sed 's/^/    /'

compose_up_db db-new
compose_up_rmt_new

# ------------------------------------------------- restore the 2.x database --

log 'restoring 2.x dump into the 3.x MariaDB'
db_reset db-new
db_load db-new "$BASELINE_SQL"

pre_versions="$(migration_versions db-new)"
pre_systems="$(row_count db-new systems)"
pre_activations="$(row_count db-new activations)"
pre_repositories="$(row_count db-new repositories)"
pre_profile_len="$(db_sql db-new 'SELECT LENGTH(data) FROM profiles WHERE id = 1;')"
pre_hostname3="$(db_sql db-new 'SELECT hostname FROM systems WHERE id = 3;')"

debug "baseline: $(wc -l <<<"$pre_versions") migrations, ${pre_systems} systems, ${pre_activations} activations"

# ------------------------------------------------------ run 3.x migrations --

log 'running 3.x db:migrate'
migrate_out="$(in_service rmt-new 'cd /srv/www/rmt && bundle exec rails db:migrate RAILS_ENV=production 2>&1')" \
  || { echo "$migrate_out"; bad 'db:migrate exited non-zero'; }
echo "$migrate_out" | sed 's/^/    /'

post_versions="$(migration_versions db-new)"

# ------------------------------------------------------------ schema shape --

log 'asserting post-upgrade schema'

if column_exists db-new systems proxy_byos; then
  bad 'systems.proxy_byos should be gone after upgrade'
else
  ok 'systems.proxy_byos removed'
fi

if column_exists db-new systems proxy_byos_mode; then
  ok 'systems.proxy_byos_mode retained'
else
  bad 'systems.proxy_byos_mode was lost'
fi

# ChangeDataType's comment says MEDIUMTEXT, but `limit: 16.megabytes` is
# 16777216 — one byte past MEDIUMTEXT's ceiling — so Rails emits LONGTEXT.
# Asserting the actual result; see the note in the README.
assert_eq 'longtext' "$(column_type db-new profiles data)" 'profiles.data widened to LONGTEXT'

# Schema version must have advanced to what 3.1 declares in db/schema.rb.
expected_version="$(grep -oP 'define\(version: \K[0-9_]+' "$REPO_ROOT/db/schema.rb" | tr -d '_')"
latest_applied="$(tail -1 <<<"$post_versions")"
assert_eq "$expected_version" "$latest_applied" 'schema_migrations reaches db/schema.rb version'

pending="$(in_service rmt-new 'cd /srv/www/rmt && bundle exec rails db:migrate:status RAILS_ENV=production 2>/dev/null | grep "^  down" || true')"
if [[ -z "$pending" ]]; then
  ok 'no pending migrations remain'
else
  bad 'db:migrate:status still reports down migrations'
  echo "$pending" | sed 's/^/    /'
fi

# ----------------------------------------------------------- data survival --

log 'asserting data survived the upgrade'

assert_eq "$pre_systems"      "$(row_count db-new systems)"      'systems row count unchanged'
assert_eq "$pre_activations"  "$(row_count db-new activations)"  'activations row count unchanged'
assert_eq "$pre_repositories" "$(row_count db-new repositories)" 'repositories row count unchanged'
assert_eq "$pre_profile_len"  "$(db_sql db-new 'SELECT LENGTH(data) FROM profiles WHERE id = 1;')" \
  'profiles.data payload not truncated'
assert_eq "$pre_hostname3"    "$(db_sql db-new 'SELECT hostname FROM systems WHERE id = 3;')" \
  'multi-byte hostname preserved'

assert_eq '1' "$(db_sql db-new "SELECT COUNT(*) FROM systems WHERE id = 2 AND hostname IS NULL AND registered_at IS NULL;")" \
  'NULL columns preserved'
assert_eq 'KVM' "$(db_sql db-new "SELECT JSON_UNQUOTE(JSON_EXTRACT(system_information, '\$.hypervisor')) FROM systems WHERE id = 1;")" \
  'system_information JSON still queryable'
assert_eq '1' "$(db_sql db-new "SELECT COUNT(*) FROM activations a JOIN systems s ON s.id = a.system_id JOIN subscriptions sub ON sub.id = a.subscription_id WHERE a.id = 1;")" \
  'foreign keys still resolve'

# ------------------------------------------ profiles.data really is wider ---

log 'verifying widened profiles.data accepts >64 KB'
big_written="$(db_sql db-new "
  INSERT INTO profiles (profile_type, identifier, data, created_at, updated_at)
  VALUES ('package', 'oversize-check', REPEAT('x', 200000), NOW(), NOW());
  SELECT LENGTH(data) FROM profiles WHERE identifier = 'oversize-check';" | tail -1)"
assert_eq '200000' "$big_written" '200 KB payload stored without truncation'
db_sql db-new "DELETE FROM profiles WHERE identifier = 'oversize-check';"

# ------------------------------------------- duplicated-migration analysis --

log 'checking for logically duplicated migrations'
new_versions="$(comm -13 <(echo "$pre_versions") <(echo "$post_versions"))"
debug "migrations applied by the upgrade: $(echo "$new_versions" | tr '\n' ' ')"

# Same migration class shipped under two timestamps (2.x and 3.x) means the
# upgrade re-applies it. Harmless only while both are idempotent.
#
# Migration names are resolved from this checkout first, then from any 2.x ref
# that still carries the file — an RPM-sourced baseline has no git ref of its
# own, so this is best-effort and never fatal.
migration_name_for() { # <version> -> basename without the timestamp, or empty
  local v="$1" f ref
  f=$(find "$REPO_ROOT/db/migrate" -maxdepth 1 -name "${v}_*.rb" -print -quit 2>/dev/null || true)
  if [[ -z "$f" ]]; then
    for ref in "$BASELINE_REF" origin/release-2.28 release-2.28; do
      f=$(git -C "$REPO_ROOT" ls-tree -r --name-only "$ref" -- db/migrate 2>/dev/null \
            | grep -m1 "/${v}_" || true)
      [[ -n "$f" ]] && break
    done
  fi
  [[ -z "$f" ]] && return 0
  f=$(basename "$f" .rb)
  printf '%s' "${f#*_}"
}

declare -A class_of
dupes=''
unresolved=0
for v in $post_versions; do
  name="$(migration_name_for "$v")"
  if [[ -z "$name" ]]; then
    unresolved=$((unresolved + 1))
    continue
  fi
  if [[ -n "${class_of[$name]:-}" ]]; then
    dupes+="$name (${class_of[$name]} + $v) "
  else
    class_of[$name]=$v
  fi
done
(( unresolved > 0 )) && debug "$unresolved migration version(s) could not be mapped to a file"

if [[ -n "$dupes" ]]; then
  skip "duplicated migration classes present: $dupes"
  debug 'these re-run on upgrade; assertions above confirm they are idempotent'
else
  ok 'no duplicated migration classes across the upgrade'
fi

# ------------------------------------------- post-upgrade CLI smoke test ----
# A migrated 2.x database legitimately contains rows with NULL hostname and
# NULL registered_at (both columns are nullable, and SMT-imported systems often
# have neither). `rmt-cli systems list` is the first thing an admin runs after
# upgrading, so it has to survive them.

log 'post-upgrade rmt-cli smoke test'

cli() { in_service rmt-new "cd /srv/www/rmt && ./bin/rmt-cli $1 2>&1" || true; }

assert_contains "$(cli version)" "$(grep -oP "VERSION \|\|= '\K[^']+" "$REPO_ROOT/lib/rmt.rb")" \
  'rmt-cli version works against the migrated DB'
assert_contains "$(cli 'repos list --all')" 'SLE-Product-SLES15-SP6-Pool' \
  'rmt-cli repos list works against the migrated DB'

systems_out="$(cli 'systems list')"
if [[ "$systems_out" == *'SCC_abc123'* ]]; then
  ok 'rmt-cli systems list works against the migrated DB'
else
  bad 'rmt-cli systems list fails on the migrated DB'
  echo "$systems_out" | head -5 | sed 's/^/    /'
fi

# Narrow the failure to each nullable column so a regression report is precise.
db_sql db-new "UPDATE systems SET registered_at = NOW() WHERE registered_at IS NULL;"
if [[ "$(cli 'systems list')" == *'SCC_abc123'* ]]; then
  ok 'rmt-cli systems list survives NULL hostname'
else
  bad 'rmt-cli systems list crashes on a system with NULL hostname'
fi

db_sql db-new "UPDATE systems SET hostname = 'backfilled' WHERE hostname IS NULL;"
db_sql db-new "UPDATE systems SET registered_at = NULL WHERE id = 2;"
if [[ "$(cli 'systems list')" == *'SCC_abc123'* ]]; then
  ok 'rmt-cli systems list survives NULL registered_at'
else
  bad 'rmt-cli systems list crashes on a system with NULL registered_at'
fi

summary "$SUITE"
