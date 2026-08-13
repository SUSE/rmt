#!/usr/bin/env bash
# Suite 04 — fresh-install schema parity on 3.x.
#
# `db:schema:load` (what a fresh RPM install effectively gets via schema.rb)
# and `db:migrate` from zero (what an upgrade path produces) must converge on
# the same schema. When db/schema.rb is stale relative to db/migrate/ they
# don't, and fresh installs quietly differ from upgraded ones.
#
# Also asserts the reverse: db:migrate from zero leaves db/schema.rb unchanged.

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

SUITE='suite 04 (fresh-install schema parity)'
log "$SUITE"

compose_up_db db-new
compose_up_rmt_new

mkdir -p "$ARTIFACTS_DIR"
MIGRATED_SNAP="$ARTIFACTS_DIR/schema-from-migrate.txt"
LOADED_SNAP="$ARTIFACTS_DIR/schema-from-load.txt"

# --------------------------------------------------- db:migrate from zero ---

log 'building schema with db:migrate from zero'
db_reset db-new
in_service rmt-new 'cd /srv/www/rmt && bundle exec rails db:migrate RAILS_ENV=production >/dev/null'
db_schema_snapshot db-new "$MIGRATED_SNAP"
migrated_versions="$(migration_versions db-new)"

# ------------------------------------------------------- db:schema:load ----

log 'building schema with db:schema:load'
db_reset db-new
in_service rmt-new 'cd /srv/www/rmt && bundle exec rails db:schema:load RAILS_ENV=production >/dev/null'
db_schema_snapshot db-new "$LOADED_SNAP"
loaded_versions="$(migration_versions db-new)"

# ------------------------------------------------------------- compare -----

log 'comparing the two schemas'
if diff -u "$MIGRATED_SNAP" "$LOADED_SNAP" > "$ARTIFACTS_DIR/schema-parity.diff"; then
  ok 'db:migrate and db:schema:load produce identical schemas'
else
  bad "schemas differ — see ${ARTIFACTS_DIR#"$REPO_ROOT"/}/schema-parity.diff"
  head -40 "$ARTIFACTS_DIR/schema-parity.diff" | sed 's/^/    /'
fi

# schema.rb's declared version drives assume_migrated_upto_version; if
# db/migrate/ contains anything newer, a fresh install starts out "needing
# migration" and the two paths diverge until db:migrate runs.
declared="$(grep -oP 'define\(version: \K[0-9_]+' "$REPO_ROOT/db/schema.rb" | tr -d '_')"
newest_file="$(ls "$REPO_ROOT"/db/migrate/*.rb | sed 's#.*/##' | cut -d_ -f1 | sort | tail -1)"
assert_eq "$newest_file" "$declared" 'db/schema.rb version matches newest migration file'

if [[ "$migrated_versions" == "$loaded_versions" ]]; then
  ok 'schema_migrations identical between the two paths'
else
  bad 'schema_migrations differ between db:migrate and db:schema:load'
  diff <(echo "$migrated_versions") <(echo "$loaded_versions") | sed 's/^/    /'
fi

# ------------------------------------------- schema.rb regeneration drift ---

log 'checking db:migrate does not rewrite db/schema.rb'
db_reset db-new
in_service rmt-new 'cd /srv/www/rmt && cp db/schema.rb /tmp/schema.rb.orig &&
                    bundle exec rails db:migrate RAILS_ENV=production >/dev/null 2>&1 || true'
drift="$(in_service rmt-new 'cd /srv/www/rmt && diff -u /tmp/schema.rb.orig db/schema.rb || true')"
if [[ -z "$drift" ]]; then
  ok 'db/schema.rb is up to date with db/migrate/'
else
  bad 'db:migrate regenerated db/schema.rb — the committed file is stale'
  echo "$drift" | head -40 | sed 's/^/    /'
  echo "$drift" > "$ARTIFACTS_DIR/schema-rb-drift.diff"
fi

summary "$SUITE"
