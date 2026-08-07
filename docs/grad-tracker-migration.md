# Grad Tracker → Alumni System Migration

## Decisions (confirmed)

| Topic | Choice |
|-------|--------|
| Programs | All programs (not BSIT-only) |
| Registration | Open register (current flow) |
| Surveys | Custom-only (Phase 2+); CHED templates can be added later as preset survey packs |
| Reminders | In-app + email (Phase 3) |
| Forum | Public to all alumni (Phase 5) |

## Source of truth

| Data | Primary store | Notes |
|------|---------------|--------|
| Auth & role | Firebase Auth + `users/{uid}` | `uid` document ID |
| Tracer demographics | `users/{uid}` tracer fields | Synced to directory |
| Employment tracer | `employment_records` | Existing ID Tracer |
| Manual alumni directory | `alumni_members/{id}` | Legacy/manual entries; may link via `authUid` |
| Events, jobs, messages | Unchanged | |

## Phase 0 — Firestore fields (`users/{uid}`)

| Field | Type | Description |
|-------|------|-------------|
| `studentId` | string | School ID (legacy: `idNumber`) |
| `program` | string | Degree/program (legacy: `course`) |
| `batchYear` | string | Graduation batch |
| `yearGraduated` | string | Year graduated (defaults to batch) |
| `contactNumber` | string | Phone (legacy: `phoneNumber`) |
| `address` | string | Home address |
| `gender` | string | |
| `civilStatus` | string | Optional |
| `birthDate` | timestamp | Optional |
| `tracerProfileCompletion` | number | 0–100, computed on save |
| `tracerProfileComplete` | bool | All required fields filled |
| `tracerProfileCompletedAt` | timestamp | When marked complete |

## Phase 1 — UI map

| Feature | Location |
|---------|----------|
| Tracer profile form | **Profile** tab → **Tracer Profile** sub-tab |
| Completion banner | **Home** dashboard |
| Employment tracer | **ID Tracer** tab (unchanged) |
| Admin directory | **Alumni Members** → tabs: **Registered** / **Manual directory** |
| Filters | Program, batch, profile complete, search |

## Phase 2 — Custom surveys (shipped)

| Feature | Location |
|---------|----------|
| Admin survey CRUD & publish | **Admin** → **Surveys** (menu index 10) |
| Targeting | Program and/or batch year filters on publish |
| Alumni take survey | **Home** → Graduate Tracer Study → **Assigned surveys** |
| Responses & stats | Admin → survey row → **Responses** |

### Firestore shape

| Collection / path | Purpose |
|-------------------|---------|
| `surveys/{surveyId}` | Title, description, status (`draft` / `published` / `closed`), targets, counts |
| `surveys/{surveyId}/questions/{questionId}` | Question text, type, options, required |
| `surveys/{surveyId}/responses/{userId}` | Answers; doc id = auth uid |
| `survey_assignments/{surveyId}_{userId}` | Per-user assignment status |

Rules: `firestore.rules` — signed-in read; admin write on surveys; users write own responses/assignment updates.

**Note:** `publishSurvey` uses batched writes; very large cohorts (>~250 users) may need chunked batches in a future pass.

## Phase 3 — Response management & reminders (shipped)

| Feature | Location |
|---------|----------|
| Response dashboard | Admin → Surveys → **View responses** |
| Tabs | **Overview**, **Pending** (unresponsive), **Submitted** |
| Reminders | Pending tab or Overview — in-app, email, or both |
| Export | CSV download (web admin) on Submitted / app bar |
| Tracking | `lastReminderAt`, `reminderCount` on `survey_assignments` |

### Email reminders (optional)

Create an EmailJS template with variables: `to_email`, `user_name`, `survey_title`, `message`.

```bash
flutter run -d chrome \
  --dart-define=EMAILJS_SERVICE_ID=... \
  --dart-define=EMAILJS_TEMPLATE_ID=... \
  --dart-define=EMAILJS_PUBLIC_KEY=... \
  --dart-define=EMAILJS_REMINDER_TEMPLATE_ID=...
```

In-app reminders work without the reminder template.

## Phase 4 — Announcements (shipped)

| Feature | Location |
|---------|----------|
| Admin CRUD & publish | **Admin** → **Announcements** (menu index 11) |
| Targeting | Program / batch filters (empty = all alumni) |
| Notify | In-app notification and/or email (same EmailJS reminder template) |
| Alumni feed | **Home** → Announcements section; full list via **See all** |
| Priority | Normal or **Important** (highlighted on home) |

### Firestore

`announcements/{id}` — title, body, status (`draft` / `published` / `archived`), priority, targets, `notifyInApp`, `notifyEmail`, `recipientCount`, timestamps.

Deploy rules: `firebase deploy --only firestore:rules`

## Phase 5 — Public alumni forum (shipped)

| Feature | Location |
|---------|----------|
| Browse & post topics | **Home** → **Alumni Forum** |
| Replies | Topic detail → reply bar |
| New topic | FAB on forum list |
| Admin moderation | **Admin** → **Forum** (menu index 12) — lock, pin, delete |

### Firestore

| Path | Purpose |
|------|---------|
| `forum_topics/{topicId}` | Title, body, author, replyCount, isLocked, isPinned |
| `forum_topics/{topicId}/posts/{postId}` | Replies |

All signed-in alumni can read and post. Authors can delete own topics; admins can moderate all.

Deploy rules: `firebase deploy --only firestore:rules`

## Phase 7 — Reporting & analytics (tracer-focused)

**Admin → Reports & Analytics** (`admin_reports_screen.dart`, `admin_reports_analytics.dart`):

| Deliverable | Description |
|-------------|-------------|
| **KPI cards** | Pending survey assignments (incomplete `survey_assignments`), registered alumni **without** complete demographics tracer |
| **Engagement bars** | Employed % among employment submissions; pending surveys vs total assignments; incomplete tracer vs registered |
| **Charts (`fl_chart`)** | Industry bar chart (employed only, deduped submissions); existing batch, course, employment pie, survey completion, roster breakdown |
| **Survey question summaries** | Top 5 published surveys by response count: per-question choice %, scale avg/min/max, text answer counts (`survey_report_analytics.dart`) |
| **Exports** | New report type **Tracer & Survey KPIs** (Excel: sheets `KPI`, `Industry_employed`, `Surveys`; PDF: same blocks). **Employment Records** export includes **Position** and **Industry** |
| **Service** | `SurveyService.countPendingSurveyAssignments()` — `whereIn` on `notStarted` + `inProgress` |

Per-survey raw responses remain **Admin → Surveys → View responses** (CSV). Phase 7 adds dashboard-level aggregates and KPI export.

## Phase 8 — CHED preset packs (in progress)

| Feature | Status |
|---------|--------|
| Firestore `survey_templates` | Shipped — `ched_gts_official_v2` (CHED PDF C & D) |
| Admin create from template | Shipped |
| Tracer prefill on take survey | Planned |
| Official USTP PDF import | Pending registrar document |

See [ched-survey-templates.md](ched-survey-templates.md).

## Future collections (Phase 6+)

- `admin_requests` (Phase 6)
