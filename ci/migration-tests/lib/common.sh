# shellcheck shell=bash
# Shared helpers for the RMT migration test suites.

set -euo pipefail

MIGTEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$MIGTEST_DIR/../.." && pwd)"
ARTIFACTS_DIR="$MIGTEST_DIR/artifacts"
FIXTURES_DIR="$MIGTEST_DIR/fixtures"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-rmt-migtest}"
COMPOSE_FILE="$MIGTEST_DIR/compose.yml"

# What to migrate from. See lib/baseline.sh for the full description.
BASELINE_SOURCE="${BASELINE_SOURCE:-rpm}"   # rpm | worktree
BASELINE_REF="${BASELINE_REF:-v2.28}"       # only used by BASELINE_SOURCE=worktree
BASELINE_VARIANT="${BASELINE_VARIANT:-}"    # '' | pre-2.28

# Single source of truth for the cached baseline dump's filename.
baseline_path() {
  local stem
  if [[ "$BASELINE_SOURCE" == 'rpm' ]]; then
    stem="rpm-${RMT_OLD_VERSION:-latest2x}"
  else
    stem="$BASELINE_REF"
  fi
  printf '%s/baseline-%s%s.sql' "$FIXTURES_DIR" "$stem" "${BASELINE_VARIANT:+-$BASELINE_VARIANT}"
}

# ---------------------------------------------------------------- output ----

if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''; C_DIM=''; C_OFF=''
fi

FAILURES=0
ASSERTIONS=0

log()   { printf '%s==>%s %s\n' "$C_BLU" "$C_OFF" "$*"; }
debug() { printf '%s    %s%s\n' "$C_DIM" "$*" "$C_OFF"; }
ok()    { ASSERTIONS=$((ASSERTIONS + 1)); printf '  %sPASS%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
bad()   { ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1)); printf '  %sFAIL%s %s\n' "$C_RED" "$C_OFF" "$*"; }
skip()  { printf '  %sSKIP%s %s\n' "$C_YEL" "$C_OFF" "$*"; }
die()   { printf '%sERROR%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

# ------------------------------------------------------------- assertions ---

assert_eq() { # <expected> <actual> <description>
  local expected="$1" actual="$2" desc="$3"
  if [[ "$expected" == "$actual" ]]; then
    ok "$desc"
  else
    bad "$desc (expected '$expected', got '$actual')"
  fi
}

assert_contains() { # <haystack> <needle> <description>
  if [[ "$1" == *"$2"* ]]; then ok "$3"; else bad "$3 (missing '$2')"; fi
}

assert_not_contains() { # <haystack> <needle> <description>
  if [[ "$1" != *"$2"* ]]; then ok "$3"; else bad "$3 (unexpectedly found '$2')"; fi
}

# --------------------------------------------------------------- compose ----

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

compose_up_db() { # <db-old|db-new>
  log "starting $1"
  compose up -d --wait "$1"
}

# rmt-new bakes the working tree into its image, so it must be rebuilt every
# run — otherwise the suites silently test whatever was committed the last time
# the image was built. Set SKIP_BUILD=1 to reuse the existing image.
compose_up_rmt_new() {
  if [[ "${SKIP_BUILD:-0}" == '1' ]]; then
    debug 'SKIP_BUILD=1 — reusing the existing rmt-new image'
  else
    log 'building rmt-new from the working tree'
    compose build rmt-new
  fi
  compose up -d --force-recreate rmt-new >/dev/null
}

# Run a shell command inside a service container.
in_service() { # <service> <command...>
  compose exec -T "$1" bash -lc "${*:2}"
}

# ------------------------------------------------------------------- sql ----

# MariaDB 10.11 ships `mysql`, 11.8 ships `mariadb`. Pick whichever exists.
_db_client() { # <service>
  compose exec -T "$1" bash -c 'command -v mariadb || command -v mysql' 2>/dev/null | tail -1
}

# The client defaults to latin1 in these images, which mangles multi-byte data
# on the way in and out and would produce bogus "data corrupted" failures.
DB_CHARSET_OPT='--default-character-set=utf8mb4'

db_sql() { # <service> <sql>  -> tab separated, no header
  local svc="$1" sql="$2" client
  client="$(_db_client "$svc")"
  compose exec -T "$svc" "$client" -uroot -ptoor $DB_CHARSET_OPT --batch --skip-column-names rmt -e "$sql" 2>/dev/null
}

db_sql_raw() { # <service> <sql>  -> keeps header, surfaces client errors
  local svc="$1" sql="$2" client
  client="$(_db_client "$svc")"
  compose exec -T "$svc" "$client" -uroot -ptoor $DB_CHARSET_OPT --batch rmt -e "$sql"
}

db_reset() { # <service> — drop and recreate the rmt schema
  local svc="$1" client
  client="$(_db_client "$svc")"
  compose exec -T "$svc" "$client" -uroot -ptoor $DB_CHARSET_OPT -e \
    'DROP DATABASE IF EXISTS rmt; CREATE DATABASE rmt CHARACTER SET utf8mb4; GRANT ALL ON rmt.* TO "rmt"@"%";'
}

db_dump() { # <service> <outfile>
  local svc="$1" out="$2" dumper
  dumper="$(compose exec -T "$svc" bash -c 'command -v mariadb-dump || command -v mysqldump' | tail -1)"
  compose exec -T "$svc" "$dumper" -uroot -ptoor $DB_CHARSET_OPT --single-transaction --routines rmt > "$out"
  debug "dumped $svc -> $(basename "$out") ($(wc -c < "$out") bytes)"
}

db_load() { # <service> <sqlfile>
  local svc="$1" file="$2" client
  client="$(_db_client "$svc")"
  compose exec -T "$svc" "$client" -uroot -ptoor $DB_CHARSET_OPT rmt < "$file"
  debug "loaded $(basename "$file") into $svc"
}

# Normalised `SHOW CREATE TABLE` output for every table, for schema diffing.
db_schema_snapshot() { # <service> <outfile>
  local svc="$1" out="$2" tables t
  tables="$(db_sql "$svc" 'SHOW TABLES;')"
  : > "$out"
  for t in $tables; do
    # ar_internal_metadata / schema_migrations content differs by design
    db_sql "$svc" "SHOW CREATE TABLE \`$t\`;" \
      | sed -e 's/\\n/\n/g' -e 's/ AUTO_INCREMENT=[0-9]*//' \
      >> "$out"
    printf '\n' >> "$out"
  done
  sort -o "$out" "$out"
}

# ------------------------------------------------------- schema introspect --

column_exists() { # <service> <table> <column>
  local n
  n="$(db_sql "$1" "SELECT COUNT(*) FROM information_schema.COLUMNS
                    WHERE TABLE_SCHEMA='rmt' AND TABLE_NAME='$2' AND COLUMN_NAME='$3';")"
  [[ "$n" == "1" ]]
}

column_type() { # <service> <table> <column>
  db_sql "$1" "SELECT COLUMN_TYPE FROM information_schema.COLUMNS
               WHERE TABLE_SCHEMA='rmt' AND TABLE_NAME='$2' AND COLUMN_NAME='$3';"
}

table_exists() { # <service> <table>
  local n
  n="$(db_sql "$1" "SELECT COUNT(*) FROM information_schema.TABLES
                    WHERE TABLE_SCHEMA='rmt' AND TABLE_NAME='$2';")"
  [[ "$n" == "1" ]]
}

row_count() { # <service> <table>
  db_sql "$1" "SELECT COUNT(*) FROM \`$2\`;"
}

migration_versions() { # <service>
  db_sql "$1" 'SELECT version FROM schema_migrations ORDER BY version;'
}

# ------------------------------------------------------------------ misc ----

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed"
}

summary() { # <suite name>
  echo
  if (( FAILURES == 0 )); then
    printf '%s%s: %d/%d assertions passed%s\n' "$C_GRN" "$1" "$ASSERTIONS" "$ASSERTIONS" "$C_OFF"
  else
    printf '%s%s: %d of %d assertions FAILED%s\n' "$C_RED" "$1" "$FAILURES" "$ASSERTIONS" "$C_OFF"
  fi
  return $(( FAILURES > 0 ))
}
