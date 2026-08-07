# Events Features Overview

> Updated for the Events engagement redesign (cover images, RSVP, categories, capacity, agenda, maps, analytics).

## Purpose
The Events feature lets administrators create and manage alumni events, while alumni users can browse upcoming events, RSVP, discuss events through comments, and receive reminders.

## Feature Summary

### Admin
- Create / edit / archive / cancel / delete events (list-first + sectioned dialog)
- Cover image upload (compress + storage)
- Category, capacity, registration deadline, structured agenda
- RSVP counts and attendee list with filters
- Event detail panel: Overview, Agenda, Attendance, Comments, Analytics
- Search and filters (category, batch, venue, date range)
- Notifications on publish, venue/schedule change, cancel
- Restore from Archives

### Alumni
- Browse upcoming events (list / grid)
- Cover, category, status badge, countdown
- RSVP: Going / Interested / Can't Attend (changeable)
- Automatic local reminders when Going (3 days / 1 day / day-of)
- Open venue in Google Maps
- Comments + admin replies
- Capacity / registration-closed states

## Data model (high level)
`AlumniEvent` fields include theme, batchYear, date, venue, status, times, description, coverImageUrl, category, capacity, registrationDeadline, agenda, viewsCount, cancelled.

`event_rsvps` stores per-user status (`going` | `interested` | `cant_attend`).

Display statuses: Upcoming, Today, Ongoing, Finished, Cancelled, Archived.

## Migration
See `docs/events-engagement-migration.md` and `supabase/migrations/20260727100025_events_engagement.sql`.

## Key files
- `lib/features/admin/events/presentation/admin_events_page.dart`
- `lib/features/admin/events/presentation/admin_event_editor_dialog.dart`
- `lib/features/admin/events/presentation/admin_event_detail_panel.dart`
- `lib/features/events/presentation/events_page.dart`
- `lib/features/events/data/event_service.dart`
- `lib/features/events/data/event_rsvp_service.dart`
- `lib/features/events/widgets/`
