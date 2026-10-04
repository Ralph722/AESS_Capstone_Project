# Tracer Draft Reminders — Implementation Plan (saved, not yet built)

Status: **Built 2026-10-04.** Migration `20261004010000_tracer_draft_reminders.sql` is pushed. Differences from the original plan:

- No on-device backup notification: phones already get the server push, so a local one would show every reminder twice.
- "Opened since the last reminder" uses `survey_responses.updated_at` (bumped by `record_survey_opened` and draft saves), so no extra tracking column.
- Follow-ups are also skipped on the "closing in 3 days" notice day, not only "closing tomorrow".
- The intro card also offers "Remind me" when there is a draft but no reminder.

## Goal

When an alumnus leaves the CHED GTS with a saved draft (emergency, something else to finish), let them pick when to be reminded to finish it, with optional hourly follow-ups on that day only.

## Why it's worth adding

- Users who leave with a draft are the most likely to never come back; a reminder at a time they picked brings them back far more reliably than a generic nudge.
- Most pieces already exist:
  - Server notifications via `pg_cron` + `public.enqueue_notifications` (in-app list + phone push), see `supabase/migrations/20261001050000_notifications_scheduled.sql` and `docs/notifications.md`.
  - On-device scheduling via `flutter_local_notifications` (`lib/features/events/data/reminder_service.dart`, Android/iOS only, no-op on web).
  - Tracer opens are already recorded (`SurveyService.recordSurveyOpened`), which tells us whether a reminder was "missed".

## User flow

1. **Exit dialog** ("Save your progress?") → user taps **Save draft**.
2. A small bottom sheet asks **"Want a reminder to finish?"** with quick choices:
   - In 3 hours
   - Tonight, 8:00 PM
   - Tomorrow, 9:00 AM
   - Pick a date & time (date picker + time picker)
   - No thanks
3. Optional switch (off by default): **"Remind me every hour if I don't open it"**.
4. **Tracer intro card** shows "Reminder set for Tue, Oct 6 · 8:00 PM" with **Change** and **Cancel**.

## Rules

- **Hourly follow-ups:** only on the chosen day; stop when the user opens the tracer, at 9:00 PM, or after 3 follow-ups.
- "Missed" = the tracer has not been opened since the reminder was sent.
- The reminder time cannot be after the tracer's close date. If it is, show: "This tracer closes on {date}, please pick an earlier time."
- One reminder per tracer per user; setting a new one replaces the old one.
- Submitting the tracer cancels all reminders.
- Respect Profile → Notifications settings (survey category off = no reminders).
- Skip hourly follow-ups on a day the existing "survey closing tomorrow" notice is sent, to avoid double notifications.

## Delivery

- **Server-side (primary):** works on web and phone, survives app closed or phone restart.
  - New task in `run_scheduled_notifications`, run every **5 minutes** (the existing frequent job runs every 15, which could make an 8:00 PM reminder arrive at 8:15).
  - Uses `enqueue_notifications` with category `survey`, a dedupe key per reminder/follow-up, and a route to the tracer.
- **On-device (backup, phones only):** schedule an exact local notification at the chosen time via `ReminderService`; cancel it when the reminder is changed, cancelled, or the tracer is submitted.

## Data model (new migration)

Table `public.tracer_draft_reminders`:

| Column | Notes |
|--------|-------|
| `user_id` | uuid, references the alumnus |
| `survey_id` | the CHED GTS survey |
| `remind_at` | timestamptz chosen by the user |
| `repeat_hourly` | bool, default false |
| `followups_sent` | int, default 0 (max 3) |
| `last_sent_at` | timestamptz, null until first send |
| `cancelled_at` | timestamptz, set on cancel or submit |
| `created_at` / `updated_at` | timestamps |

- Unique on (`user_id`, `survey_id`) so a new reminder replaces the old one (upsert).
- RLS: users can read/insert/update/delete only their own rows.
- Function `run_tracer_draft_reminders()` (security definer) sends due reminders and follow-ups, and skips rows where the survey was submitted, closed, or opened after `last_sent_at`.

## App changes

- `lib/features/surveys/ched_gts/ched_gts_take_screen.dart`: after a successful draft save on exit, show the reminder sheet.
- New reminder sheet widget (portal options UI pattern: `PortalOptionsSheet` / `PortalSheetOption`, see `.cursor/rules/portal-options-ui-pattern.mdc`).
- `lib/features/alumni/tracer/presentation/tracer_intro_view.dart`: show the reminder row with Change / Cancel.
- Reminder service (data layer): upsert / cancel / fetch the user's reminder; also schedule/cancel the on-device backup.
- On submit: cancel the reminder (server row + local notification).

## Rollout

- New Supabase migration must be pushed (same as earlier notification migrations).
- Test on web (in-app notification) and Android (push + local backup).
