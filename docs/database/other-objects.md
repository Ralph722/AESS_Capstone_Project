# Other Database Objects

> Snapshot of the live schema in the linked Supabase project, taken 2026-10-05 with read-only queries. It contains structure only, no row data. Regenerate it from `queries/` instead of editing by hand; the migrations in `supabase/migrations` remain the source of truth.

Enums, views, storage buckets, Realtime publications, scheduled jobs and extensions. Scheduled job commands are left out because they can carry request headers.


## Storage buckets

| Name | Settings |
|---|---|
| images | public=true, size_limit=2097152, mime=image/jpeg |
| message-attachments | public=false, size_limit=2097152, mime=image/jpeg |

## Tables published to Realtime

- `public.announcements`
- `public.event_comments`
- `public.event_replies`
- `public.event_rsvps`
- `public.events`
- `public.feedback`
- `public.forum_helpful_reactions`
- `public.forum_posts`
- `public.forum_reports`
- `public.forum_topics`
- `public.messages`
- `public.survey_assignments`
- `public.user_notifications`

## Scheduled jobs (pg_cron)

| Name | Schedule (UTC) |
|---|---|
| aess-notify-cleanup | `30 19 * * *` |
| aess-notify-events | `0 23 * * *` |
| aess-notify-frequent | `*/15 * * * *` |
| aess-notify-morning | `0 0 * * *` |
| aess-notify-tracer-reminders | `*/5 * * * *` |
| aess-push-dispatch | `* * * * *` |

## Extensions

| Name | Version |
|---|---|
| pg_cron | 1.6.4 |
| pg_net | 0.20.3 |
| pg_stat_statements | 1.11 |
| pgcrypto | 1.3 |
| plpgsql | 1.0 |
| supabase_vault | 0.3.1 |
| uuid-ossp | 1.1 |
