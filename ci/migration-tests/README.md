# RMT migration tests

Container-based tests for the paths that carry an *existing* RMT installation
onto a new release: database upgrades, RPM upgrades, and the SMT import.
Nothing here touches your development database — the stack runs under its own
compose project (`rmt-migtest`) with its own throwaway MariaDB containers.

```bash
ci/migration-tests/run.sh              # all four suites
ci/migration-tests/run.sh 01 04        # just these
ci/migration-tests/run.sh --baseline   # regenerate the 2.x baseline dump
ci/migration-tests/run.sh --clean      # tear everything down
```

## Suites

| # | Suite | What it covers | Needs network |
|---|-------|----------------|---------------|
| 01 | `db-upgrade` | Restore a real 2.x database into MariaDB 11.8, run 3.x `db:migrate`, assert schema + data + post-upgrade `rmt-cli` | only to build the baseline |
| 02 | `rpm-upgrade` | **A:** 2.28 RPM on Leap 15.6 → 3.1 RPM on Leap 16.0. **B:** in-place `zypper up` 3.0.0 → 3.1.0 on Leap 16.0, exercising the real `%post` upgrade branch | yes |
| 03 | `smt-import` | `bin/rmt-data-import` against a synthetic SMT export: repos, custom repos, systems, activations, hwinfo, warning paths, idempotency, `--no-systems` | no |
| 04 | `schema-parity` | `db:migrate` from zero vs. `db:schema:load` produce the same schema; `db/schema.rb` isn't stale | no |

## The 2.x baseline

Suite 01 migrates from a cached dump of a real 2.x database, built once and
committed under `fixtures/`:

```bash
ci/migration-tests/lib/baseline.sh [--force]
```

| Variable | Default | Meaning |
|---|---|---|
| `BASELINE_SOURCE` | `rpm` | `rpm`: install the published 2.x RPM on Leap 15.6 and let it migrate from zero. `worktree`: build the 2.x *dev* image from a git worktree instead. |
| `BASELINE_REF` | `v2.28` | git ref, `BASELINE_SOURCE=worktree` only |
| `BASELINE_VARIANT` | *(none)* | `pre-2.28` rewinds the finished 2.28 schema to a 2.27-era one |
| `RMT_OLD_VERSION` | *(latest)* | pin a specific 2.x RPM version |

**Run suite 01 with both variants.** Only 2.28 is published for Leap 15.6, and
2.28 already applied the `proxy_byos` removal and the `profiles.data` widening.
Against that baseline the corresponding 3.x migrations are no-ops. The
`pre-2.28` variant restores `systems.proxy_byos` and narrows `profiles.data`
back to `TEXT`, so the migrations actually do work:

```bash
ci/migration-tests/run.sh 01                            # 2.28 -> 3.1
BASELINE_VARIANT=pre-2.28 ci/migration-tests/run.sh 01  # 2.27-era -> 3.1
```

`BASELINE_SOURCE=worktree` is the fallback for baselining an unreleased 2.x
revision. The 2.28 `Dockerfile` no longer resolves against current Leap 15.6
repositories (`libxml2-devel` needs `readline-devel`, which conflicts with the
installed `libncurses6`), so `baseline.sh` applies an `--allow-downgrade`
fixup to a throwaway copy of it. It does not modify the worktree's tracked
files.

## Other variables

| Variable | Meaning |
|---|---|
| `RMT_RPM_DIR` | Directory of locally built `rmt-server*.rpm` (see `ci/rmt-build-rpm`). Suite 02 upgrades to these instead of the published ones — use this to gate a release on the RPMs you are about to ship. |
| `KEEP_UP=1` | Leave containers running after the run, for poking at the resulting database |
| `COMPOSE_PROJECT_NAME` | Defaults to `rmt-migtest` |

## Notes on things the suites assert

- **`ChangeDataType` produces `LONGTEXT`, not `MEDIUMTEXT`.** The migration's
  comment says MEDIUMTEXT, but `limit: 16.megabytes` is 16777216 — one byte
  past MEDIUMTEXT's 16777215 ceiling — so Rails emits `LONGTEXT`. The suites
  assert the actual behaviour (`longtext`), matching `db/schema.rb`'s
  `size: :long`. If the intent really was MEDIUMTEXT, the limit needs to be
  `16.megabytes - 1`.

- **Two migrations ship under two timestamps.** `ChangeDataType` and
  `RemoveProxyByosFromSystems` exist on `release-2.28` as `20260618151105` /
  `20260618160300` and on `release-3.1` as `20260626153118` / `20260626153653`.
  A 2.28 → 3.1 upgrade therefore re-applies both. Suite 01 detects this and
  reports it as a `SKIP`, and the surrounding assertions verify that both are
  idempotent, so the upgrade is safe. Two consequences remain: `schema_migrations`
  ends up with four rows for two logical changes, and `db:rollback` from 3.1
  back to 2.28 is not sound.

- **Suite 02 Part A is not a `zypper up`.** RMT 2.x targets Leap 15.x / SLE 15
  and 3.x targets Leap 16 / SLE 16, so the real customer path includes a distro
  upgrade. Part A reproduces the package-and-database half of that (2.x
  initialises and populates a database; the 3.1 package migrates it and has to
  work afterwards). Part B is a genuine single-transaction RPM upgrade and is
  what covers the `%post` upgrade branch.

## Adding coverage

`lib/seed.sql` is the representative 2.x dataset — multi-byte text, NULLs, JSON
in `system_information`, a `profiles.data` payload near the `TEXT` ceiling, rows
on both sides of every foreign key. Extend it rather than adding ad-hoc inserts
to individual suites, so every suite benefits.

Assertion helpers (`assert_eq`, `assert_contains`, `column_type`,
`row_count`, `migration_versions`, …) live in `lib/common.sh`.
