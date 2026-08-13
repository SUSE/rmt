# VM migration PoC

A single 2.x → 3.x upgrade test that runs in a **virtual machine** instead of a
container, so it can exercise the parts of an upgrade a container cannot reach.

```bash
VM=sle15sp7 ci/vm-migration-poc/run.sh          # resolve the address via virsh
ci/vm-migration-poc/run.sh root@192.168.122.123 # or point it at a host directly
```

It deliberately does **not** manage VM lifecycle — it never defines, starts or
stops a domain. Bring a SLES 15 SP7 VM up however you normally do, then point
this at it.

## Why a VM

[`ci/migration-tests`](../migration-tests/README.md) restores a 2.x dump into a
3.x tree and runs `rails db:migrate` as root. That covers the migrations, but
skips everything that distinguishes an *upgrade* from a schema change:

- the real RPM transaction, `%pre`/`%post` and the SUSE service macros, going
  from `rmt-server-2.28` to `rmt-server-3.1.0`
- the ruby2.5 → ruby3.4 interpreter switch that comes with it
- `rmt-server-migration.service` as an actual systemd unit — `User=_rmt`,
  `ProtectSystem=full`, `ProtectHome`, `PrivateDevices`, `ProtectKernelTunables`
- whether the migration is triggered **automatically** by the upgrade at all,
  which is what an admin running `zypper up` actually experiences

That last one is the point of the exercise. A container harness can only tell
you the migrations work when you run them; this tells you the upgrade runs them
for you.

## Why SLES 15 SP7

It is the one distribution where both ends of the upgrade exist:

| Source | Package |
|---|---|
| `SLE-Module-Server-Applications15-SP7` | `rmt-server` 2.28 (ruby2.5) |
| `systemsmanagement:SCC:RMT/SLE_15_SP7` | `rmt-server` 3.1.0 (ruby3.4) |

The 2.x side is deliberately the **distribution** package rather than an OBS
rebuild — that is what a customer upgrading from the supported RMT is actually
running.

## Guest requirements

- SLES 15 SP7, **registered** (`SUSEConnect --status-text`). The test installs
  mariadb, ruby2.5 and ruby3.4 from the guest's own SUSE repositories.
- root ssh with **key** auth. Password prompts will not work over this driver.
- Outbound network to `updates.suse.com`. The guest does *not* need to reach
  `download.opensuse.org`: `run.sh` fetches the 3.x RPMs on the host and copies
  them in, precisely because a registered SLES can usually reach the former but
  not the latter.

## Environment

### `run.sh` (host)

| Variable | Meaning |
|---|---|
| `VM=<domain>` | Resolve the ssh target from libvirt instead of passing one. Tries the default source, then `lease`, then `agent`, then `arp`. |
| `SKIP_FETCH=1` | Reuse the RPMs already in `.rpms/` instead of re-downloading |
| `SKIP_REFRESH=1` | Forwarded to the guest, see below |
| `SLE_DIR` | OBS repository directory, default `SLE_15_SP7` |
| `KEEP=1` | Leave the copied files in `/root` on the guest |

### `guest-migration-test.sh` (guest)

| Variable | Meaning |
|---|---|
| `SKIP_REFRESH=1` | Skip the `zypper refresh` preflight. A registered SLES carries ~40 repositories and that refresh can dominate the runtime; it is only a preflight, since zypper refreshes what it needs during install anyway. Skip it when re-running against a guest you already refreshed once. |
| `RPM_DIR` | Directory holding a `v3/` subdirectory of RPMs. Set by `run.sh`; unset it and the guest adds the OBS repo itself. |
| `AUTO_MIGRATE_TIMEOUT` | Seconds to wait for the upgrade to migrate on its own, default 180 |
| `BASELINE` | Path to the 2.28 dump, default `/root/baseline-2.28.sql` |
| `SLE_DIR` | Override the detected service pack |

A useful re-run, once the RPMs are cached and the guest is refreshed:

```bash
SKIP_FETCH=1 SKIP_REFRESH=1 VM=sle15sp7 ci/vm-migration-poc/run.sh
```

## Result classes

| | Meaning |
|---|---|
| `PASS` / `FAIL` | Assertions about the upgrade under test. `FAIL` sets a non-zero exit. |
| `KNOWN` | A **pre-existing defect in the 2.x baseline**, hit before the upgrade runs. Reported and counted separately, but does not fail the run. |
| `NOTE` | Something worth seeing that is not a pass/fail judgement |

The `KNOWN` class exists for one specific case: 2.28's `rmt-cli systems list`
genuinely crashes on a system with a `NULL` `registered_at`, because
`System#init` calls `Time.zone.now` in an `after_initialize` hook and the CLI
never sets a time zone. That is a real bug, but it is in an already-released
package and this upgrade cannot be expected to fix it. Counting it separately
keeps it loud without permanently red-flagging a suite whose subject is the
2.x → 3.x transition. The same check runs again *after* the upgrade, where it is
a plain `FAIL`.

## What it asserts

- 2.28 installs, `rmt-server.target` starts, and 2.28's own migration service is
  a no-op against a 2.28 dump — this matters because `%service_del_postun`
  try-restarts the units, and `rmt-server-migration.service` is only pulled in
  when `rmt-server.target` is active. Upgrading a *stopped* RMT is a different
  code path.
- The `zypper` upgrade to 3.x succeeds and the interpreter changes with it
- The upgrade migrates the database **by itself**; if it does not, the test says
  so and then falls back to starting the unit by hand, so you learn whether the
  unit is broken or merely never triggered
- `rmt-server-migration.service` ran, exited 0, and ran as `_rmt` and not root
- Schema: `systems.proxy_byos` removed, `systems.proxy_byos_mode` retained,
  `profiles.data` is `LONGTEXT`, no shipped migration left unapplied
- Data survived: row counts, a multi-byte hostname, JSON in
  `system_information`, and the `NULL` hostname / `NULL` `registered_at` row
- 3.1.0 is usable afterwards: `rmt-cli version`, `repos list`, `systems list`,
  `systems list --csv`, `rmt-server.service` active, no failed `rmt-*` units

Two things are worth knowing about those assertions:

- **`profiles.data` is asserted to be `LONGTEXT`, not `MEDIUMTEXT`.**
  `limit: 16.megabytes` is 16777216, one byte past MEDIUMTEXT's ceiling, so
  Rails emits `LONGTEXT` despite the migration's comment saying otherwise. The
  test asserts the actual behaviour.
- **Two migration classes ship under two timestamps**, so a real 2.28 database
  re-runs both. `ChangeDataType` and `RemoveProxyByosFromSystems` are
  `20260618151105` / `20260618160300` on 2.28 and `20260626153118` /
  `20260626153653` on 3.1.0. They survive the re-run only because both happen
  to be re-runnable (`remove_column` is guarded by `column_exists?`,
  `change_column` re-applies the same type) — but it is still a full `ALTER` on
  `profiles`, which is not free on a large database. This is reported as a
  `NOTE` rather than asserted, and it is also why the pending-migration check
  is a subset check rather than a count: `schema_migrations` legitimately holds
  versions 3.1.0 no longer ships.

## Files

| | |
|---|---|
| `run.sh` | Host-side driver: fetch RPMs, copy everything in, run the test over ssh |
| `guest-migration-test.sh` | The test itself, runs as root inside the VM |
| `baseline-2.28.sql` | A real 2.28 database, restored before the upgrade |
| `.rpms/` | Downloaded 3.x RPMs (git-ignored) |
| `artifacts/last-run.log` | Full output of the most recent run (git-ignored) |
