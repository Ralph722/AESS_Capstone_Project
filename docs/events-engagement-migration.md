# Events engagement migration

Apply this SQL in Supabase (already mirrored in `supabase/migrations/20260727100025_events_engagement.sql`):

- Adds to `events`: `cover_image_url`, `category`, `capacity`, `registration_deadline`, `agenda` (jsonb), `views_count`, `cancelled`
- Creates `event_rsvps` with RLS (own read/write + admin all)
- Indexes for category, date/status, RSVP lookups

Cover images use the existing public `images` storage bucket at `events/{eventId}/cover.jpg`.

After migration, hot-restart the Flutter app. Existing events remain valid with defaults (category `Other`, empty cover, no capacity).
