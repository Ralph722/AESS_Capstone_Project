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
