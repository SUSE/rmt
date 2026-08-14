# Upgrading RMT 2.x to 3.x

## Known issue: `rmt-cli systems list` fails after the upgrade

On an RMT 3.x installation whose database was migrated from 2.x, listing systems
can abort instead of printing a table:

```
# rmt-cli systems list
/usr/share/rmt/app/models/system.rb:29:in 'System#init': undefined method 'now' for nil (NoMethodError)

    self.registered_at ||= Time.zone.now
```

and, once that one is out of the way, the very next row raises:

```
/usr/share/rmt/lib/rmt/cli/decorators/system_decorator.rb:36:in 'systems_to_arrays':
undefined method 'ljust' for nil (NoMethodError)

        system.hostname.ljust(width[1]),
```

Both affect `rmt-cli systems list` and `rmt-cli systems list --csv`. Nothing
else is impaired: the database is migrated correctly, the web application is
unaffected, and clients continue to register and mirror normally.

### Why it happens

These are **two independent bugs with one shared trigger**: a `systems` row
where a nullable column is actually `NULL`.

The 2.x schema never required `hostname` or `registered_at`, so such rows are
legitimate and common in a 2.x database. The 3.x migrations preserve them
faithfully — correctly so, since discarding them would be data loss. A *fresh*
3.x installation never produces such rows, because registration always sets both.
That is why this only shows up after an upgrade.

**The `Time.zone` failure.** `Time.zone` is not a constant; ActiveSupport
resolves it per call, and it is populated by the `active_support.initialize_time_zone`
Rails initializer from `config.time_zone`. That initializer only runs inside
`Rails.application.initialize!`. The CLI entry points deliberately do not boot
Rails — they load ActiveRecord and the models directly — so `Time.zone` stays
`nil`. Separately, `System` declares `after_initialize :init`, and Rails runs
`after_initialize` on *every* instantiation, including rows hydrated from a
`SELECT`. So merely listing systems executes:

```ruby
self.registered_at ||= Time.zone.now
```

`||=` only evaluates the right-hand side when the column is `NULL`, which is
why a database without such rows never trips over the nil `Time.zone`.

**The `hostname` failure.** `systems_to_arrays` calls `.ljust` on each column
value unguarded, so a `NULL` hostname raises. Both the table and the CSV
renderer share that method.

### Workaround

Backfill the `NULL` columns. This is safe, permanent, and does not lose
information: `registered_at` is derived from the row's own `last_seen_at` or
`created_at` (the latter is `NOT NULL`), and an empty hostname renders as the
blank cell you would want anyway.

Using RMT's own database configuration, so no MySQL credentials are needed:

```bash
cd /usr/share/rmt && sudo -u _rmt RAILS_ENV=production bin/rails runner "
  System.where(registered_at: nil).update_all('registered_at = COALESCE(last_seen_at, created_at)')
  System.where(hostname: nil).update_all(hostname: '')
"
```

A `Bundler will use /tmp/... as your home directory temporarily` warning is
expected — `_rmt` has no home directory — and is harmless.

Or directly in SQL, if you prefer:

```sql
UPDATE systems SET registered_at = COALESCE(last_seen_at, created_at) WHERE registered_at IS NULL;
UPDATE systems SET hostname = ''                                      WHERE hostname IS NULL;
```

To see how many rows are affected before changing anything:

```sql
SELECT COUNT(*) FROM systems WHERE registered_at IS NULL OR hostname IS NULL;
```

### Notes on the permanent fixes

The `Time.zone` half is addressed by setting `Time.zone` explicitly in the CLI
entry points (`config/initializers_cli/time_zone.rb`, sourced from
`RMT::DEFAULT_TIME_ZONE` so it cannot drift from the web application's
`config.time_zone`).

Two things that fix does **not** address, and which the workaround above avoids
entirely:

*   The `NULL` hostname crash is a separate defect in the decorator and needs
    its own guard.
*   `System#init` mutates records loaded from the database, not just new ones.
    With a valid `Time.zone`, reading a row with a `NULL` `registered_at`
    assigns the *current* time in memory and marks the attribute dirty. The
    listing then shows today's date as that system's registration time — a
    fabricated value rather than an error — and any later `save` on the record
    would persist it. Guarding `init` with `if new_record?` would be the more
    correct fix. Backfilling from `created_at`, as above, records the truthful
    value instead.

Verified against `rmt-server-3.1.0-150700.7.1` on SLE 15 SP7, upgraded from the
distribution's `rmt-server` 2.28.
