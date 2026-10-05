# Demo alumni data (plan)

Status: planned, not implemented. Agreed on 2026-10-02.

Goal: seed 50 realistic demo alumni into the live Supabase project so the
dashboard, Reports, Program Insights (DSS), directory, surveys, events, forum,
jobs, messages and notifications can be checked with meaningful data. Then
remove everything with one cleanup script.

The app uses a single Supabase project (`lhukeauszbnsyybazauy`), so the demo
data goes into the real database. Everything must be marked and removable.

## Decisions

- 50 demo alumni in total. 38 registered, 12 not registered.
- Employment comes only from what the real app saves (CHED GTS answers), so
  inconsistencies between screens stay visible (see "Known issues").
- Employment rates differ by course on purpose so DSS has something to flag.
- One new "[DEMO]" CHED GTS and one new "[DEMO]" custom survey, created and
  published by the script, assigned only to the 38 demo accounts. Existing
  surveys are not used or changed.
- Demo alumni also interact with events, forum, jobs, messages and feedback.
- Add a few "[DEMO]" events and jobs as well as using the existing ones.
- Forum: demo topics and replies between demo alumni only.
- Keep the notifications the seed produces (useful for testing).
- The 2 existing registered alumni accounts are the owner's test accounts, so
  demo posts being visible to them is fine.

## Markers (used by the cleanup)

- Roster `student_id`: `DEMO-0001` … `DEMO-0050`.
- Emails: `demo.alumni01@aess-demo.test` … (`.test` can never receive mail).
- Titles of events, jobs, surveys and forum topics start with `[DEMO]`.
- All 38 demo logins share one password, documented with the seed script.

## The 50 alumni

10 per course (`BSIT`, `BFPT`, `BTLED-IA`, `BTLED-ICT`, `BTLED-HE`), 2 per
batch year 2021–2025. Set `alumni_members.year_graduated` explicitly (batch
is the graduation year; DSS and Reports group by it).

| Group | Count | Details |
|---|---|---|
| Employed | 20 | `ched_16` = `Yes`. `ched_18`: 7 Regular or Permanent, 5 Contractual, 2 Temporary, 2 Casual, 4 Self-employed. `ched_21`: 17 Local, 3 Abroad. |
| Not employed | 10 | 8 `No` with varied `ched_17` reasons, 2 `Never Employed`. |
| Not tracked | 8 | Registered and assigned the demo tracer, not submitted: 5 never opened, 3 with a partly filled draft. |
| Not registered | 12 | Roster row only, no account. Can be used to test registration. |

Expected demo tracer figures: 30 of 50 tracked (60% coverage), 66.7%
employment among respondents (20 of 30).

Course skew example: BSIT high employment, BTLED-HE lower.

## Demo surveys

1. "[DEMO] CHED Graduate Tracer Survey 2026"
   - `surveys.status='published'`, `data.kind='ched_gts_builtin'`,
     `data.template_key='ched_gts_builtin'`, `data.schema_version='3.0.0'`,
     `data.autoAssignNewAlumni='false'`, `data.archived='false'`,
     `created_by` = the admin user id.
   - No `survey_questions` rows (schema lives in
     `lib/features/surveys/ched_gts/ched_gts_schema.dart`).
   - Full answers for submitted responses, Sections A–D:
     - A `ched_1`–`ched_11`: matches the roster and profile.
     - B `ched_12`–`ched_14`: degree table, some professional exams
       (e.g. licensure for BTLED), reasons for the course.
     - C `ched_15a`/`ched_15b`: some with trainings or advanced studies.
     - D `ched_16`–`ched_34`: follow `ched_gts_visibility.dart` (Yes shows
       18–22, 27–32 and branches; No/Never Employed shows 17). Occupations
       match the course, salary ranges match job level, realistic
       `ched_34` suggestions.
   - Answer shapes: multi-choice = list of strings; matrix (`ched_30`) =
     `{row: {col: true}}`; table rows (`ched_12`, `ched_13`, `ched_15a`) =
     list of maps keyed by column label; date (`ched_8`) = `yyyy-MM-dd`.
   - Mirror what a real submit does: update `users.employment_status`
     (`Employed` / `Unemployed` / `Never employed`) and the Section A/B
     profile fields, like `ChedGtsPrefill.mergeIntoProfile`.
   - Spread `submitted_at` over several weeks; vary `device_category`,
     `platform_family`, `browser_family`.
2. "[DEMO] Alumni Engagement & Satisfaction Survey 2026" (custom)
   - About 8 questions in `survey_questions`, covering every type in
     `SurveyQuestionType`: `text`, `longText`, `singleChoice`,
     `multipleChoice`, `scale`, `date`.
   - Answers are keyed by question id; choice answers are lists of strings.
   - About 28 of the 38 answer it, not the same people who skipped the tracer.

For both surveys: `survey_assignments` (`notStarted` / `inProgress` /
`completed`), `survey_responses` (`draft` / `submitted`), and
`survey_response_events` (`opened`, `draft_saved`, `submitted`). Recompute
`assignment_count` and `response_count`.

Do not press Publish or re-assign on the demo surveys in the admin UI:
`publishSurvey` assigns every matching alumnus, including real ones.

## Registered accounts (38)

For each, matching what registration and onboarding create:

1. `auth.users` (+ `auth.identities`) with confirmed email and the shared
   password. Trigger `handle_new_user` inserts `public.users`.
2. `public.users`: `role='user'`, `display_name`, `email`, `student_id`,
   `program`, `year_graduated`, profile fields,
   `onboarding_complete=true`, `tracer_profile_completion=100`,
   `tracer_profile_complete=true`, varied `last_active_at`.
3. `alumni_members`: `auth_uid`, `is_registered_user=true`,
   `registered_email`, `is_deactivated=false`. Login is refused without this.

## Activity

| Feature | Plan | Tables |
|---|---|---|
| Events | 4 "[DEMO]" events (2 upcoming, 2 past) plus the existing upcoming one. About 60 RSVPs, about 15 comments and replies. | `events` (`date`, `status` `Active`), `event_rsvps` (`going`, `interested`, `cant_attend`; unique event+user), `event_comments`, `event_replies` |
| Forum | About 8 topics by demo alumni, about 30 replies, helpful reactions, bookmarks, a few @mentions. Never reply to real users' topics. | `forum_topics`, `forum_posts`, `forum_helpful_reactions`, `forum_bookmarks`, `forum_topic_tags` |
| Jobs | 4 "[DEMO]" jobs plus the active one. About 40 interests and saves, more from the not-employed group. | `jobs`, `job_interests`, `favorite_jobs` |
| Messages | About 8 threads with the admin, some unread. | `messages` |
| Feedback | About 8 entries. | `feedback` |
| Activity | Varied last-active times (not-tracked group least active). | `users.last_active_at`, `alumni_members.last_active_at` |

## Triggers that fire (expected)

- `users` insert: admin "New alumni registration" notice per account, and
  `trg_users_auto_assign_surveys` assigns every open published survey with
  auto-assign on (today: all current CHED GTS and "Test" surveys). The seed
  must delete those extra assignments and their "New survey" notices, and
  recompute those surveys' `assignment_count`, so existing surveys end up
  unchanged.
- `survey_assignments` insert: "New survey" notice for the demo surveys.
- `survey_responses` submitted: "Survey submitted" receipt.
- `event_comments` insert: admin notice; `event_replies` insert: notice to
  the comment author; comment counts maintained by trigger.
- `forum_posts` insert: notice to the topic author; reply counts maintained
  by trigger.
- `messages` insert: notice to the recipient.
- `feedback` insert/update: admin notice.
- Push only goes out if the user has push tokens (demo accounts have none).
  No database trigger sends email.

Insert guards: `enforce_message_insert` needs `auth.role()` to be
`service_role` (set `request.jwt.claims` in the session).
`forum_topics_guard_insert` only blocks non-admin announcements.

## Cleanup script

Deletes only marked rows and anything linked to them:

1. Activity rows of demo users, and anything on "[DEMO]" content.
2. The two "[DEMO]" surveys with questions, assignments, responses, events.
3. "[DEMO]" events and jobs.
4. Notifications to demo users, and admin notices about demo users/content.
5. `alumni_members` rows with `DEMO-` ids (before auth users, because
   `alumni_members.auth_uid` has no cascade), then `auth.users` for
   `@aess-demo.test` (cascades `public.users`).
6. Recompute `events.comments_count`, forum counts and survey counts.

Anything the admin adds to demo content while testing (replies, comments) is
removed with it.

## Baseline counts (2026-10-02, before seeding)

Verify these are restored after cleanup:

| Table | Rows |
|---|---|
| `alumni_members` | 7 (2 registered) |
| `users` | 2 alumni, 1 admin |
| `events` | 24 (Active: 1 upcoming, 5 past; Archived: 18) |
| `event_rsvps` | 5 |
| `event_comments` | 5 |
| `event_replies` | 2 |
| `jobs` | 5 (1 active, 4 expired) |
| `job_interests` | 2 |
| `favorite_jobs` | 2 |
| `forum_topics` | 6 |
| `forum_posts` | 4 |
| `forum_helpful_reactions` | 2 |
| `forum_bookmarks` | 1 |
| `forum_tags` | 12 |
| `announcements` | 10 |
| `messages` | 8 |
| `feedback` | 0 |
| `surveys` | 11 (8 published) |

`user_notifications` (58) and `audit_logs` (510) grow over time, so compare
them by demo markers rather than totals.

## Known issues the demo will show

- Employment comes from CHED GTS answers everywhere (`gts_employment_records`
  for lists and cards, `gts_metric` for DSS), so demo answers show up in all
  employment figures.
- DSS has no survey filter, so it includes demo answers until cleanup.
  Reports has a survey filter, so the demo tracer can be viewed alone.
- "Not tracked" is not an employment status; it appears as "Registered, no
  tracer" in the tracer coverage figures.

## Steps when resuming

1. Re-check the baseline counts above.
2. Write `supabase/demo/seed_demo_data.sql` and
   `supabase/demo/cleanup_demo_data.sql`. Write files as UTF-8 without BOM.
3. Run the seed with `supabase db query --linked -f <file>`.
4. Verify: login as a demo alumnus, dashboard, Reports (filter to the demo
   tracer), DSS, directory, survey responses, events, forum, jobs, messages,
   notifications.
5. When finished, run the cleanup and confirm the baseline counts.
