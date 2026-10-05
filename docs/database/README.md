# Database Reference

Reference snapshot of the live Supabase schema, taken 2026-10-05 for the database architecture audit. It describes structure only and contains no row data, secrets or personal information.

| File | Contents |
|---|---|
| [tables-and-columns.md](tables-and-columns.md) | Every table in `public`, its columns, types, defaults and row level security status |
| [constraints.md](constraints.md) | Primary keys, foreign keys with ON DELETE behaviour, unique and check constraints |
| [indexes.md](indexes.md) | Every index and its definition |
| [rls-policies.md](rls-policies.md) | Row level security policies for `public` and `storage`, plus table grants |
| [functions.md](functions.md) | Function signatures, security mode and who may call them |
| [triggers.md](triggers.md) | Triggers on `public` and `auth` tables |
| [other-objects.md](other-objects.md) | Enums, views, storage buckets, Realtime tables, scheduled jobs, extensions |
| [secrets-runbook.md](secrets-runbook.md) | Where each server secret lives and how to recreate it (names only) |

## Regenerating

The files were produced from the queries in [queries/](queries/). Each one is read-only. To refresh a section, wrap the query in `begin transaction read only;` and `rollback;`, then run it against the linked project:

```powershell
supabase db query --linked -f docs/database/queries/columns.sql -o csv
```

If this snapshot and `supabase/migrations` disagree, the migrations win and the snapshot is out of date.

## Regression tests

[`supabase/regression/`](../../supabase/regression/) holds the test suites from the 2026-10 audit (one per phase, plus a parity report, a scheduled-job dry run and Edge Function abuse tests). Each suite runs in a transaction that is rolled back. Run them before and after any schema change:

```powershell
.\supabase\regression\run_all.ps1            # compare with baselines
.\supabase\regression\run_all.ps1 -Reports -Edge
```

After an intended change, review the reported lines and accept them with `-UpdateBaselines`.

## Restoring from a data backup

A JSON data backup (one file per table) must be loaded into the schema it was taken from, not into today's schema. Later migrations transform the data; for example, `events.starts_at` and `ends_at` are filled by a trigger added in Phase 7 and are missing from older backups.

1. Apply `supabase/migrations` up to the last migration that existed when the backup was taken.
2. Restore `auth.users` and `auth.identities`.
3. For each table, with `set session_replication_role = replica;`, run `insert into public.<table> select * from json_populate_recordset(null::public.<table>, '<json>');`.
4. Re-upload storage objects, then apply the remaining migrations with `supabase db push`.
5. Recreate secrets and Vault entries from [secrets-runbook.md](secrets-runbook.md) and check that the `cron.job` schedules exist.

The Phase 8 drill (2026-10-06) loaded the 2026-10-05 backup into scratch copies of every surviving table inside a rolled-back transaction. All row IDs matched live, `events` loaded once its time trigger was attached, and the only storage differences were the two public message images moved or removed in Phase 1.
