# Demo data plan (DSS)

Status: approved on 2026-10-08. D1, D3 and D4 are implemented in the repo.
On 2026-10-09 the demo project (`ogxyvjjkgjtzfmsaeeir`) was created, migrated
(67 migrations), set up (notification jobs off) and seeded; counts verified
(150 accounts, 238 roster rows, 3 waves, 224 submitted responses). The
flow-faithful reseed ("V" at the end of this file) is implemented in the
tool scripts; the demo project still holds the first seed until you run
`--reset` then `--seed`. D5 (DSS check in the demo app) follows the reseed.

Goal: realistic CHED GTS tracer data that exercises every DSS case (sample
sizes, multiple waves, Q17 causes, Q29 "Others", group mapping, outcomes),
without ever touching the live project.

## Decisions

- Two layers: an offline demo dataset with tests, and a separate hosted demo
  Supabase project filled by a guarded seed script.
- Never seed the live database. Never seed DSS findings: the DSS engine must
  produce them from the seeded source data.
- 3 demo alumni can log in (password typed when the seed script runs); all
  other demo alumni have no password.
- The app shows a "DEMO DATA" ribbon whenever it is not connected to the live
  project.

## Audit findings that shape the design

1. `lib/core/config/supabase_defaults.dart` hard-codes the live project. The
   app only uses another project when `--dart-define` overrides are passed.
2. `survey_responses.user_id` references `auth.users` (ON DELETE RESTRICT),
   so every respondent must be a real Auth user. Accounts are created with
   the Auth Admin API; inserting into `auth.users` directly would mean
   hashing passwords by hand, which the security rules forbid.
3. Triggers fire on inserts: `handle_new_user` (creates `public.users`),
   `notify_admins_new_registration`, `trg_users_auto_assign_surveys`,
   `alumni_members_sync_user_identity`, `notify_survey_submitted`.
   Cron jobs send tracer reminders (every 5 minutes) and push notifications
   (every minute).
4. `surveys_block_delete_with_submissions` blocks deleting a wave that has
   submitted responses; cleanup must delete responses first.
5. `alumni_members.course` is NOT NULL and references `programs(code)`
   (BSIT, BFPT, BTLED-IA, BTLED-ICT, BTLED-HE, seeded by migration). A roster
   row can lack a batch (`year_graduated` is nullable) but never a course, so
   "course unknown" respondents are always non-roster accounts.
6. A wave is a `surveys` row with `data.template_key = 'ched_gts_builtin'`,
   `schema_version`, `publishedAt`, `archived`, plus `open_at` / `close_at`.
   Answers use `ched_N` keys: multi = list, matrix = map of row to map of
   column to `true`, table = list of maps keyed by column, date =
   `yyyy-MM-dd`. Skip logic lives in `ChedGtsVisibility`.
7. The 67 migrations create their own extensions (pg_cron, pg_net) and read
   push secrets from Vault only at run time, so a fresh project accepts them.
8. `scripts/restore_admin/ensure_supabase_admin.js` reads the live
   service-role key from `supabase/.env` and sets a weak hard-coded password.
   The demo tooling does not reuse that pattern.
9. No Docker and 8 GB RAM, so local Supabase is impractical; the demo runs in
   a second hosted project.

## Steps

### D0. You (about 15 minutes)

1. Create a new Supabase project (for example `aess-demo`).
2. Copy `supabase/.env.demo.example` to `supabase/.env.demo` and fill in the
   demo project ref, URL, anon key, service-role key and database URL. Use
   the legacy JWT `service_role` key (Settings > API Keys > Legacy API keys):
   the seed script checks that its `role` and `ref` claims match the demo
   project, which a `sb_secret_...` key cannot prove.
3. Copy `supabase/demo.dart_defines.example.json` to
   `supabase/demo.dart_defines.json` and fill in the demo URL and anon key
   (keep `"AESS_ENV": "demo"`). Never put the service-role key in this file.

Both real files are git-ignored. Keys never go into code or chat.

### D1. Offline demo dataset (implemented)

- `tool/demo_data/demo_scenarios.dart`: waves and cohort scenarios (table
  below).
- `tool/demo_data/demo_dataset.dart`: deterministic generator. Every answer
  comes from `ChedGtsBuiltin` options and respects `ChedGtsVisibility`.
- `test/demo_data/demo_dataset_test.dart`: determinism, completeness (no
  missing required items, no hidden answers), valid options, demo markers,
  scenario counts.
- `test/dss/dss_demo_baseline_test.dart`: what today's DSS metrics produce
  for the dataset, so each DSS phase shows exactly what it changes.

### D2. Prepare the demo project (after D0)

1. Apply migrations to the demo project only:
   `supabase db push --db-url "<DEMO_DB_URL>"`. The CLI stays linked to live;
   the demo is always named explicitly.
2. Run `tool/demo_data/demo_project_setup.sql` against the demo database
   (SQL editor of the demo project, or
   `supabase db query --db-url "<DEMO_DB_URL>" -f ...`). Never use
   `--linked` for these two commands: the CLI is linked to live. The SQL
   refuses to run if any non-demo account or non-`DEMO-` roster row exists,
   then turns off the notification cron jobs (reminders, push dispatch,
   scheduled notifications). The nightly DSS re-check, notification cleanup
   and audit retention stay on.
3. Do not deploy Edge Functions or set Vault / function secrets (push
   dispatch URL and secret, Gmail, VAPID, AI keys) in the demo project. Push
   needs Vault secrets and device tokens; email needs the `send-email`
   function with Gmail secrets; SMS is not implemented. Without them, nothing
   can leave the demo project, even when a notification row is created.
   Demo addresses use the reserved `.test` domain, so no mail is
   deliverable to them either.

### D3. Seed script (implemented)

`dart run tool/demo_data/seed_demo.dart --dry-run | --seed | --reset --confirm-demo`

Guards, all checked before anything is written:

1. Reads only `supabase/.env.demo`, never `supabase/.env`.
2. Refuses any URL containing the live project ref (`lhukeauszbnsyybazauy`),
   a URL that does not belong to `DEMO_PROJECT_REF`, and a key that is not
   that project's service-role key.
3. Requires `--confirm-demo` and asks you to type the demo project ref
   (or `--confirm-ref=<ref>`). Passwords are typed with echo off, checked
   against the app's password policy, and never stored or logged.
4. Refuses if the target has any Auth account outside `@demo.aess.test`
   (case-insensitive). Such accounts are never changed; the script stops.
5. Guards live in `tool/demo_data/demo_guards.dart` and are tested offline
   by `test/demo_data/demo_guards_test.dart`.

What `--seed` does: it replays the app's flow from the roster import
onward (details in "V. Flow-faithful reseed"). It needs a project without
demo data, so run `--reset` first.

1. Checks the five programs exist, and stops before writing if the roster
   has non-`DEMO-` rows, a survey with a demo wave ID is not a demo wave, or
   demo data is already there.
2. Creates or updates `admin@demo.aess.test` (password typed at run time) and
   gives it the admin role.
3. Imports the 238 roster rows, unlinked, and creates the three waves
   "[DEMO] CHED GTS 2024 / 2025 / 2026" (fixed IDs, inserted directly as
   closed or published, so the "survey published" notification never fires).
4. Registers 192 alumni in registration order: confirmed account through
   the Auth Admin API, then the roster link. Three can log in (`alumni1@`,
   `alumni2@`, `alumni3@demo.aess.test`, password typed at run time); the
   rest have no password.
5. Onboards them, assigns the closed waves, writes 221 responses with their
   events, back-dates everything and writes the activity logs. Nothing
   leaves the project (no push tokens, Vault secrets or email function in
   the demo).

`--admin-password` sets a new password for `admin@demo.aess.test` only
(typed with echo off, same guards and project-ref confirmation); nothing
else changes.

`--reset` deletes only rows the dataset provably owns, by ID:

- accounts whose email is one of the 149 dataset emails (the demo admin and
  any other demo-domain account are kept);
- roster rows whose student ID is one of the 238 dataset IDs;
- the three fixed wave IDs, only if they still carry the demo titles;
- DSS findings whose `survey_id` is a demo wave (the column has no foreign
  key, so it is cleaned explicitly);
- responses, assignments and response events of the dataset accounts (these
  foreign keys block account deletion);
- activity logs of the dataset accounts (deleting an account would keep them
  with an empty owner) and the admin's "New alumni registration" notices
  about them. Their other notifications go with the account.

It first prints a preview of every count, stops if any response on a demo
wave belongs to an account outside the dataset, and then requires typing
`DELETE DEMO DATA <ref>` in a terminal. Deletes run in dependency order
(findings, responses, assignments, events, activity logs, registration
notices, waves, roster, accounts). If a step fails, it stops with the step
name; re-running finishes the job.

### D4. Run the app against the demo (implemented)

`flutter run -d chrome --dart-define-from-file=supabase/demo.dart_defines.json`

Without the flag the app still uses live, exactly as before. With
`AESS_ENV=demo` the app refuses to start unless both the demo URL and key are
set and the URL is not live; it never mixes a demo value with a live default.
It also refuses a service-role or `sb_secret_` key and a key that belongs to
a different project than the URL. The ribbon follows the actual project ref:
"DEMO DATA" for the demo build, "NOT LIVE" for any other non-live project,
none on live. The ribbon is a reminder only; isolation comes from the
separate project.

### D5. Verify (after D2 and D3)

- Count checks against the scenario table.
- In the demo app, run DSS "Refresh insights" and compare with the expected
  results below.
- Confirm the Reports page shows demo numbers and the live project is
  unchanged.

## Waves

| Key | Title | Status | Open | Close |
|---|---|---|---|---|
| w2024 | [DEMO] CHED GTS 2024 | closed | 2024-06-01 | 2024-08-31 |
| w2025 | [DEMO] CHED GTS 2025 | closed | 2025-06-01 | 2025-08-31 |
| w2026 | [DEMO] CHED GTS 2026 | published | 2026-06-01 | 2026-12-15 |

## Scenarios

Respondents in a later wave are the first N respondents of the earlier wave
(same alumni across waves).

| Group | Roster | Wave: respondents | Pattern | What it tests | Expected under the final DSS policy |
|---|---|---|---|---|---|
| BSIT 2022 | 30 | w2024: 25, w2025: 25 | Not employed 3 → 8 | Trend | Trend finding (12% → 32%, 25 per wave) |
| BSIT 2023 | 45 | w2025: 40, w2026: 35 | Not employed 14 (10 job-seeking) → 5; high relatedness; 2 Q29 "Others" | Strong finding, seeking work, success, opportunity | Unemployment finding (strong); next wave improved |
| BSIT 2024 | 60 | w2025: 12 | 2 not employed | Low response rate (20%) | Data-quality coverage finding |
| BTLED-ICT 2023 | 24 | w2025: 20, w2026: 3 | 8 not employed, mostly further study | Cause-specific advice; insufficient follow-up | Finding, but no job-seeking advice; follow-up "Not enough data" |
| BTLED-ICT 2024 | 22 | w2025: 20 | Only 3 employed (17 not employed) | Q29 denominator | Unemployment finding; no Q29 finding (Q29 n = 3) |
| BTLED-HE 2024 | 15 | w2025: 12, w2026: 12 | 10 employed: 6 mismatch, 6 clerical, 7 low pay, 4 long waits plus 1 Q29 "Others", Q34 text | Limited evidence; unsuccessful outcome | Mismatch / underemployment findings (limited); unchanged next wave |
| BTLED-IA 2024 | 10 | w2025: 7 | 4 not employed | Watch | Watch (5–9) |
| BFPT 2022 | 6 | w2025: 4 | 2 not employed | Not enough data | Not enough data |
| BFPT 2023 | 5 | w2025: 1 | 1 not employed | Privacy | Not enough data, no rate shown |
| BFPT 2024 | 15 | none | No responses | Data quality with zero responses | Data-quality coverage finding |
| BSIT, batch not recorded | 6 | w2025: 5 | Mixed | Group mapping case 2 (offline; hosted: they type 2021 at onboarding) | Counts for BSIT course level only; never a batch finding |
| Not on roster | 0 | w2025: 3 | Mixed | Group mapping cases 3 and 4 (offline only) | Never assigned to a course or batch |

Totals: 3 waves, 238 roster rows, 224 submitted responses and 195 accounts
offline; the hosted demo has 192 registered alumni plus the demo admin and
221 responses (checked by `test/demo_data`).

Duplicate responses cannot exist in the database (unique survey and user), so
they are covered by unit tests only. Finding-history cases (resolved,
dismissed, superseded) come from using the demo app or from rolled-back SQL
tests, never from seeding.

## Risks

- An older migration may fail on a fresh project; fixed only in the demo.
- Free projects pause after about a week without use (restore in one click).
- New migrations must also be pushed to the demo project.
- Seeding about 150 accounts through the Admin API takes a minute or two.

## V. Flow-faithful reseed (implemented 2026-10-09; run `--reset` then `--seed`)

### Audit of the first seed (read-only checks on the demo project)

| Area | Real system | First seed | Effect in the app |
|---|---|---|---|
| Onboarding | `saveTracerProfile` fills Section A, B item 12 and employment status on `public.users`, mirrors contact fields to the roster row, sets completion and `tracer_profile_complete`, then `onboarding_complete` | Only `onboarding_complete = true` plus name, email, student ID, program, year | 150 onboarded, 0 complete profiles; "Some tracer profile fields are still missing" |
| Profile vs answers | CHED Section A is prefilled from the profile and the profile is synced back from the answers on submit (`ChedGtsPrefill`) | Answers have addresses, phones, birthdays; profiles are empty | Profile and tracer answers disagree |
| Assignment | Publishing an "All alumni" survey assigns every alumni account at that moment; linking a roster record later auto-assigns the current tracer (`trg_users_auto_assign_surveys` → `auto_assign_open_surveys`) | Assigned per scenario cohort | 2026 wave: 72 assigned of 146 linked alumni |
| Registration | Requires a roster match (`link_alumni_registration`) | 3 accounts not on the roster | Impossible accounts |
| Participation | Some registered alumni never answer | Every account answered every wave it got | 100% completion in 2024 and 2025 |
| Dates | Registration before answering; events at the time they happen | Everything stamped with the seed date | Registered in 2026, answered in 2024 |
| Survey history | `opened`, `draft_saved`, `submitted` events with device info | None (0 events) | Empty response timeline |
| Activity logs | `REGISTER`, `COMPLETE_ONBOARDING`, `LOGIN` | None | Empty activity tab |

### Decisions

- Accounts not on the roster are removed from the hosted demo. The offline
  dataset keeps them so the DSS group-mapping unit tests still cover that
  case. Hosted responses become 221 (224 minus 3); they never counted toward
  a course or batch, so only institution totals change.
- Registered alumni who never answer are added:
  `registered = min(roster, respondents + ceil(roster × 25%))` per cohort,
  192 of 238 roster members. The employment answers do not change, so
  `dss_demo_baseline_test.dart` stays valid.
- Everything the app shows is back-dated to a realistic timeline that ends
  at the snapshot date 2026-10-01 (nothing in the future).
- "BSIT, batch not recorded" (added during implementation): onboarding
  requires a graduation year and the database copies it into the roster, so
  in the hosted demo these 6 alumni type 2021 and their roster batch becomes
  2021. The offline dataset keeps the case for the DSS unit tests.
- Section A uses the app's default college ("... — Oroquieta Campus") and
  Oroquieta City, Misamis Occidental addresses (added during
  implementation). No DSS metric reads Section A or item 12.
- Not changed: the app code, migrations, employment answers (Q13 onward),
  DSS logic, and Auth's own `auth.users.created_at` (the Admin API cannot set
  it and the demo tooling never writes to Auth tables directly).

### Timeline rules (deterministic, in the offline dataset)

- Roster imported 2024-01-15. Nobody registers before that.
- Respondents register after graduation (June 1 of the batch year), after
  the previous wave closed, and at least 7 days before the first wave they
  answer.
- Non-respondents register on a spread of dates between graduation (or the
  roster import) and 2026-09-30.
- A member is assigned wave W when registered before W closes:
  `assigned_at = max(W.open_at, registered_at)` (publish before, auto-assign
  during the window). Every registered alumnus therefore gets the open 2026
  wave, as the real trigger would do.
- Responses: opened about 25 minutes, first draft about 20 minutes before
  submission, inside the wave window, with a fixed device mix
  (mobile/desktop, Android/iOS/Windows, Chrome/Safari/Edge).

### Seed order (mirrors the real flow)

1. Roster rows (unlinked), back-dated to the import date.
2. The 3 waves (2024 and 2025 closed, 2026 published and open).
3. Per member, in registration order:
   - account via the Auth Admin API with a confirmed email (`handle_new_user`
     creates the profile row; the admin gets the "new registration" notice);
   - roster link written exactly as `link_alumni_registration` writes it
     (roster flags, `auth_uid`, `registered_email`; profile identity,
     program, graduation year). The program and year update fires the
     database's own auto-assign trigger for the open 2026 wave;
   - onboarding written like `saveTracerProfile`: Section A and B values
     equal to the member's Section A answers, employment status from the
     latest Q16 answer (non-respondents get one at onboarding), completion
     100%, roster mirror fields, `onboarding_complete`.
4. Publish history for the closed waves: assign every member registered
   before each wave closed.
5. Responses with `opened` / `draft_saved` / `submitted` events, device
   fields, assignment set to completed, profile synced from the answers.
6. Back-dating with the service role: profile and roster rows,
   assignments, response events, and the notifications the triggers created
   (registration, assignment, submission receipt; older ones marked read).
7. Activity logs (`REGISTER`, `COMPLETE_ONBOARDING`, some `LOGIN`) only for
   events the nightly retention would still keep today (1 year; 90 days for
   logins). The insert trigger stamps `now()`, so rows are back-dated by an
   update right after insert.
8. Summary with counts per wave (assigned, completed, pending).

### Reset changes

- Also deletes the demo accounts' activity logs and the admin's
  "new registration" notices that point to demo accounts.
- Everything else stays as in D3: ownership by dataset IDs, preview, typed
  `DELETE DEMO DATA <ref>`.

### Verified on the demo project (read-only)

- `users_guard_protected_columns` and `alumni_members_guard_owner_update`
  let the service role set `created_at`.
- `survey_response_events` has no triggers, so event times are written
  directly. Responses, roster rows and closed-wave assignments are inserted
  with their real times.
- `set_updated_at` stamps `updated_at` with the current time on every
  update, so rows changed after insert (profiles, roster links, the open
  wave's assignments, notifications, activity logs) show the seed time in
  `updated_at` only.
- `audit_logs_stamp_actor` stamps `created_at` on insert; an update right
  after the insert back-dates it.
- `user_notifications_track_read` sets `read_at` when `is_read` changes, so
  `is_read` is set first and `read_at` back-dated in a second update.
- Linking the roster row fires `alumni_members_sync_user_identity`, which
  sets the profile's program and ID, which fires the auto-assign of the open
  wave and its "New survey" notice.
- Deleting an account cascades its notifications but keeps its activity
  logs with an empty owner, hence the reset step.
- `run_notification_cleanup` (nightly) removes read notices older than 90
  days and any notice older than 180 days; the seed removes those it
  back-dated past that point so the first night changes nothing.
- The DSS uses the registered count only as evidence text; response rates
  divide by the whole roster, so extra registered alumni change no
  decision.

Found while verifying (app bug, fixed 2026-10-11): birthdays were saved as
the UTC date of local midnight, so east of UTC (Manila) they moved one day
earlier on every onboarding save, profile edit and tracer submit. Birthdays
are now saved with `CalendarDate.toDb` (the date as picked, no time-zone
conversion). Birthdays saved before the fix may be one day early.

### Tests

- Timeline: registration after the roster import and graduation, before the
  first answer; assignments follow the rule above; every response has a
  completed assignment; the open wave is assigned to every registered member.
- Profiles: 100% complete and equal to the latest Section A answers;
  employment status equal to the latest Q16.
- Hosted subset excludes off-roster accounts; offline totals unchanged.
- DSS baseline test unchanged.

Expected hosted result (also printed by `--dry-run`):

| Wave | Assigned | Submitted | Pending |
|---|---|---|---|
| [DEMO] CHED GTS 2024 | 33 | 25 | 8 |
| [DEMO] CHED GTS 2025 | 173 | 146 | 27 |
| [DEMO] CHED GTS 2026 (open) | 192 | 50 | 142 |

### Rollout

1. Done: implemented and tested locally (tool scripts and tests only).
2. You run `--reset --confirm-demo` (typed confirmation), then
   `--seed --confirm-demo`. Reset keeps the demo admin, so Enter keeps the
   admin password; the 3 alumni logins are recreated and need a password.
   The seed prints the counts it reads back from the database.
3. Read-only verification: counts per wave, 0 incomplete profiles, events,
   dates; then the D5 DSS check in the demo app.
