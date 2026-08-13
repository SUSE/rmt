#!/usr/bin/env bash
# Produce a baseline RMT 2.x database dump to migrate from.
#
#   ci/migration-tests/lib/baseline.sh [--force]
#
# Two sources, selected with BASELINE_SOURCE:
#
#   rpm       (default) Install the published RMT 2.x RPM on Leap 15.6, let it
#             migrate a MariaDB 10.11 database from zero, then seed it. This is
#             the schema real customers upgrade from.
#
#   worktree  Build the RMT 2.x *development* image from a git worktree of
#             $BASELINE_REF and migrate with that. Useful for baselining an
#             unreleased 2.x revision. NOTE: the 2.28 Dockerfile no longer
#             resolves on current Leap 15.6 repositories (libxml2-devel vs.
#             readline-devel/libncurses6), so this path applies a small
#             dependency fixup to a throwaway copy of the Dockerfile.
#
# The dump is cached under fixtures/; pass --force to regenerate.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

BASELINE_SOURCE="${BASELINE_SOURCE:-rpm}"

# Tables the seed data needs. Bail out early with a useful message rather than
# emitting a wall of SQL errors on a baseline that predates them.
REQUIRED_TABLES=(products services repositories repositories_services subscriptions
                 subscription_product_classes systems activations system_uptimes
                 profiles system_profiles products_extensions)

require_cmd docker

# BASELINE_VARIANT=pre-2.28 rewinds the finished 2.28 schema to the state a
# 2.27-era installation is still in (proxy_byos present, profiles.data narrow,
# the two June-2026 migrations unrecorded). Only 2.28 is published for Leap
# 15.6, so without this the 3.x column-drop migration never does real work.
case "$BASELINE_SOURCE" in
  rpm|worktree) ;;
  *) die "BASELINE_SOURCE must be 'rpm' or 'worktree', got '$BASELINE_SOURCE'" ;;
esac
case "$BASELINE_VARIANT" in
  ''|pre-2.28) ;;
  *) die "BASELINE_VARIANT must be empty or 'pre-2.28', got '$BASELINE_VARIANT'" ;;
esac

BASELINE_SQL="$(baseline_path)"

if [[ -f "$BASELINE_SQL" && $FORCE -eq 0 ]]; then
  log "baseline already present: ${BASELINE_SQL#"$REPO_ROOT"/}"
  log 're-run with --force to regenerate'
  exit 0
fi

# ------------------------------------------------------- build the source ---

if [[ "$BASELINE_SOURCE" == 'rpm' ]]; then
  OLD_SERVICE='rpm-old'
  log 'building the RMT 2.x RPM container'
  compose build rpm-old
else
  OLD_SERVICE='rmt-old-src'
  require_cmd git

  log "preparing worktree for $BASELINE_REF"
  git -C "$REPO_ROOT" rev-parse --verify "$BASELINE_REF^{commit}" >/dev/null 2>&1 \
    || die "unknown git ref '$BASELINE_REF'"

  WORKTREE="$REPO_ROOT/.migtest/$BASELINE_REF"
  if [[ -d "$WORKTREE" ]]; then
    debug "reusing $WORKTREE"
  else
    mkdir -p "$REPO_ROOT/.migtest"
    git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$BASELINE_REF"
  fi

  # Let the solver downgrade libncurses6 so readline-devel (and therefore
  # libxml2-devel) is installable again. Applied to a copy, never to the tree.
  sed -e 's/zypper --non-interactive install --no-recommends/zypper --non-interactive install --no-recommends --allow-downgrade --force-resolution/' \
      -e 's/zypper --non-interactive install -t pattern/zypper --non-interactive install --allow-downgrade -t pattern/' \
      "$WORKTREE/Dockerfile" > "$WORKTREE/Dockerfile.migtest"

  log "building RMT $BASELINE_REF from source (Leap 15.6 / Ruby 2.5 — slow)"
  BASELINE_CONTEXT="$WORKTREE" BASELINE_DOCKERFILE=Dockerfile.migtest compose build rmt-old-src
fi

# ---------------------------------------------------------------- migrate ---

compose_up_db db-old
db_reset db-old

BASELINE_CONTEXT="${WORKTREE:-}" BASELINE_DOCKERFILE="${BASELINE_DOCKERFILE:-Dockerfile}" \
  compose up -d "$OLD_SERVICE" >/dev/null

if [[ "$BASELINE_SOURCE" == 'rpm' ]]; then
  installed="$(in_service rpm-old "rpm -q --qf '%{VERSION}-%{RELEASE}' rmt-server")"
  log "baselining from rmt-server-$installed"
  [[ "$installed" == 2.* ]] || die "expected an RMT 2.x package, got $installed"

  compose exec -T rpm-old bash -c "cat > /etc/rmt.conf <<'EOF'
database:
  host: db-old
  database: rmt
  username: rmt
  password: rmt
  adapter: mysql2
  encoding: utf8
  timeout: 5000
  pool: 5
EOF"
  log 'running the 2.x migrations from zero'
  in_service rpm-old 'cd /usr/share/rmt && /usr/share/rmt/bin/rails db:create db:migrate RAILS_ENV=production'
else
  log "running $BASELINE_REF migrations from zero"
  in_service rmt-old-src 'cd /srv/www/rmt && bundle exec rails db:migrate RAILS_ENV=production'
fi

for t in "${REQUIRED_TABLES[@]}"; do
  table_exists db-old "$t" \
    || die "this baseline has no '$t' table — it predates the seed data"
done

# ------------------------------------------------------------------- seed ---

log 'seeding representative 2.x data'
db_load db-old "$MIGTEST_DIR/lib/seed.sql"

if [[ "$BASELINE_VARIANT" == 'pre-2.28' ]]; then
  log 'rewinding to the pre-2.28 schema'
  db_sql db-old "
    ALTER TABLE profiles CHANGE \`data\` \`data\` text NOT NULL;
    ALTER TABLE systems ADD COLUMN proxy_byos tinyint(1) DEFAULT 0;
    DELETE FROM schema_migrations WHERE version IN ('20260618151105', '20260618160300');"
  column_exists db-old systems proxy_byos || die 'failed to re-add systems.proxy_byos'
  debug "profiles.data is now $(column_type db-old profiles data), proxy_byos restored"
fi

# proxy_byos was dropped during the 2.x series; populate it where it still
# exists so the 3.x column-removal migration has something real to remove.
if column_exists db-old systems proxy_byos; then
  debug 'systems.proxy_byos present — populating it'
  db_sql db-old 'UPDATE systems SET proxy_byos = 1 WHERE id IN (1,3);'
else
  debug 'systems.proxy_byos already absent in this baseline'
fi

# ------------------------------------------------------------------- dump ---

mkdir -p "$FIXTURES_DIR"
db_dump db-old "$BASELINE_SQL"

{
  echo "-- RMT migration-test baseline"
  echo "-- source:            $BASELINE_SOURCE${BASELINE_VARIANT:+ (variant: $BASELINE_VARIANT)}"
  if [[ "$BASELINE_SOURCE" == 'rpm' ]]; then
    echo "-- package:           rmt-server-$(in_service rpm-old "rpm -q --qf '%{VERSION}-%{RELEASE}' rmt-server")"
  else
    echo "-- ref:               $BASELINE_REF ($(git -C "$REPO_ROOT" rev-parse --short "$BASELINE_REF"))"
  fi
  echo "-- schema_migrations: $(migration_versions db-old | tr '\n' ' ')"
  cat "$BASELINE_SQL"
} > "$BASELINE_SQL.tmp" && mv "$BASELINE_SQL.tmp" "$BASELINE_SQL"

log "baseline written: ${BASELINE_SQL#"$REPO_ROOT"/}"
compose stop "$OLD_SERVICE" db-old >/dev/null 2>&1 || true
