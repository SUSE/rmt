#!/usr/bin/env bash
# Suite 03 — SMT -> RMT data import (MIGRATE.md path).
#
# Exercises bin/rmt-data-import against a synthetic SMT export on a 3.x
# schema: repository enablement, custom repo creation and attachment, system
# and activation import, hardware info, and the warning paths for data that no
# longer resolves (missing repo / product / system, duplicate login).

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

SUITE='suite 03 (SMT -> RMT data import)'
log "$SUITE"

compose_up_db db-new
compose_up_rmt_new

# ------------------------------------------------- 3.x schema + SCC data ----

log 'preparing a synced 3.x database'
db_reset db-new
in_service rmt-new 'cd /srv/www/rmt && bundle exec rails db:migrate RAILS_ENV=production >/dev/null'
db_load db-new "$MIGTEST_DIR/lib/seed.sql"

# rmt-data-import is what turns mirroring on; start from off so the assertion
# below measures the import rather than the seed.
db_sql db-new 'UPDATE repositories SET mirroring_enabled = 0;'
db_sql db-new "DELETE FROM repositories WHERE friendly_id = 'my-custom-repo';"

pre_systems="$(row_count db-new systems)"

# ---------------------------------------- refuse to import without a sync ---

log 'checking the un-synced guard'
db_sql db-new 'SET FOREIGN_KEY_CHECKS=0; CREATE TABLE products_backup AS SELECT * FROM products; DELETE FROM products; SET FOREIGN_KEY_CHECKS=1;'
guard_out="$(in_service rmt-new 'cd /srv/www/rmt && ./bin/rmt-data-import -d /fixtures/smt-export 2>&1' || true)"
assert_contains "$guard_out" 'has not been synced to SCC' 'import refuses to run before rmt-cli sync'
db_sql db-new 'SET FOREIGN_KEY_CHECKS=0; INSERT INTO products SELECT * FROM products_backup; DROP TABLE products_backup; SET FOREIGN_KEY_CHECKS=1;'

# ------------------------------------------------------------- do import ---

log 'running rmt-data-import'
import_out="$(in_service rmt-new 'cd /srv/www/rmt && ./bin/rmt-data-import -d /fixtures/smt-export 2>&1')" \
  || { echo "$import_out" | sed 's/^/    /'; bad 'rmt-data-import exited non-zero'; }
echo "$import_out" | sed 's/^/    /'

# ---------------------------------------------------------- repositories ---

log 'asserting repository import'
assert_eq '1' "$(db_sql db-new "SELECT mirroring_enabled FROM repositories WHERE friendly_id = '3814';")" \
  'mirroring enabled for repo 3814'
assert_eq '1' "$(db_sql db-new "SELECT mirroring_enabled FROM repositories WHERE friendly_id = '3815';")" \
  'mirroring enabled for repo 3815'
assert_contains "$import_out" 'Repository 9999 was not found' 'warns about unsubscribed repo 9999'

log 'asserting custom repository import'
assert_eq '1' "$(db_sql db-new "SELECT COUNT(*) FROM repositories WHERE external_url = 'http://smt.example.com/repo/custom-a/';")" \
  'custom repo created with trailing slash normalised'
assert_eq '1' "$(db_sql db-new "
  SELECT COUNT(*) FROM repositories_services rs
  JOIN repositories r ON r.id = rs.repository_id
  WHERE r.external_url = 'http://smt.example.com/repo/custom-a/' AND rs.service_id = 1743;")" \
  'custom repo attached to product 1743 service'
assert_contains "$import_out" 'Product 8888 not found' 'warns about custom repo on unknown product'
assert_eq '1' "$(db_sql db-new "SELECT COUNT(*) FROM repositories WHERE external_url = 'http://smt.example.com/repo/custom-b/';")" \
  'orphaned custom repo still created (detachable later)'

# --------------------------------------------------------------- systems ---

log 'asserting system import'
assert_eq "$((pre_systems + 2))" "$(row_count db-new systems)" 'two new systems imported'
assert_eq '1' "$(db_sql db-new "SELECT COUNT(*) FROM systems WHERE login = 'SMT_sys1' AND password = 'smtpass1' AND hostname = 'smt-client-one.example.com';")" \
  'SMT_sys1 imported with credentials and hostname'
assert_eq 'smt-wörkstation.example.com' "$(db_sql db-new "SELECT hostname FROM systems WHERE login = 'SMT_sys2';")" \
  'multi-byte hostname imported intact'
assert_eq '2025-03-01 00:00:00' "$(db_sql db-new "SELECT DATE_FORMAT(registered_at, '%Y-%m-%d %H:%i:%s') FROM systems WHERE login = 'SMT_sys1';")" \
  'registered_at converted from epoch to UTC'
assert_contains "$import_out" 'Duplicate entry for system SCC_abc123' 'duplicate login skipped'

# ----------------------------------------------------------- activations ---

log 'asserting activation import'
assert_eq '2' "$(db_sql db-new "SELECT COUNT(*) FROM activations a JOIN systems s ON s.id = a.system_id WHERE s.login = 'SMT_sys1';")" \
  'both SMT_sys1 activations imported'
assert_eq '1' "$(db_sql db-new "SELECT COUNT(*) FROM activations a JOIN systems s ON s.id = a.system_id WHERE s.login = 'SMT_sys2';")" \
  'SMT_sys2 activation imported, unknown product dropped'
assert_contains "$import_out" 'Product 9999 not found' 'warns about activation on unknown product'
assert_contains "$import_out" 'System SMT_missing not found' 'warns about activation for unknown system'

# ------------------------------------------------------------- hw import ---

log 'asserting hardware info import'
hw="$(db_sql db-new "SELECT system_information FROM systems WHERE login = 'SMT_sys1';")"
assert_contains "$hw" '"hypervisor":"Xen"' 'machinedata hwinfo stored'

# Guarded: with system_information NULL, a plain "does not contain hostname"
# check would pass for the wrong reason.
if [[ -n "$hw" && "$hw" != 'NULL' ]]; then
  assert_not_contains "$hw" 'hostname' 'hostname stripped from hwinfo'
else
  bad 'hostname stripped from hwinfo (nothing was persisted to check)'
fi

assert_eq '1' "$(db_sql db-new "SELECT JSON_VALID(system_information) FROM systems WHERE login = 'SMT_sys2';")" \
  'imported system_information satisfies the json_valid check constraint'

# ------------------------------------------------------------ idempotency --

log 'asserting the import is re-runnable'
rerun_out="$(in_service rmt-new 'cd /srv/www/rmt && ./bin/rmt-data-import -d /fixtures/smt-export 2>&1')" || true
assert_eq "$((pre_systems + 2))" "$(row_count db-new systems)" 'second run creates no duplicate systems'
assert_eq '2' "$(db_sql db-new "SELECT COUNT(*) FROM activations a JOIN systems s ON s.id = a.system_id WHERE s.login = 'SMT_sys1';")" \
  'second run creates no duplicate activations'
assert_contains "$rerun_out" 'Duplicate entry for system SMT_sys1' 'second run reports already-imported systems'

# ---------------------------------------------------------- --no-systems ---

log 'asserting --no-systems'
db_sql db-new "DELETE FROM systems WHERE login LIKE 'SMT_%';"
in_service rmt-new 'cd /srv/www/rmt && ./bin/rmt-data-import -d /fixtures/smt-export --no-systems >/dev/null 2>&1' || true
assert_eq '0' "$(db_sql db-new "SELECT COUNT(*) FROM systems WHERE login LIKE 'SMT_%';")" \
  '--no-systems skips system import'

summary "$SUITE"
