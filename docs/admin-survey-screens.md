# Admin Survey Screens — Feature & Logic Guide

Documentation of what exists **right now** in the admin Tracer Surveys UI: screens, features, functions, business logic, and how each flow works.

**Primary code:** `lib/features/admin/surveys/`  
**Shared domain:** `lib/features/surveys/`  
**Dashboard entry:** Admin sidebar → **Alumni & tracer** → **Surveys** (menu index `10`)  
**Related:** [ched-survey-templates.md](./ched-survey-templates.md) (built-in CHED GTS schema)

---

## 1. Big picture

Admins manage **tracer survey waves**: create a survey, target alumni by course/batch, publish (assigns + notifies), track pending vs submitted responses, send reminders, and export data.

There are **three survey flavors**:

| Flavor | How created | Questions | Alumni UX | Admin editor |
|--------|-------------|-----------|-----------|--------------|
| **Official CHED GTS (builtin)** | “Official CHED GTS” in picker | Schema in code (`ched_*` keys); **no** `survey_questions` rows | Inline on **Tracer → Active** (wizard A→B→C→D→Review) with skip logic | Title, description, audience only — questions locked |
| **Blank / custom** | “Blank survey” | Admin-defined questions | Classic survey take page | Full question editor |

> Legacy CHED preset packs (editable clones from `survey_templates`) are **no longer creatable**. Existing waves tagged as presets (if any) can still be opened/edited, but new waves should use Official CHED or blank.

```
Admin Dashboard (menu 10)
  └─ Survey list (AdminSurveysScreen)
       ├─ New survey → template picker → create → Editor
       ├─ Edit / Publish → Editor
       └─ View responses → Responses (Overview | Pending | Submitted)
```

---

## 2. File map

| File | Role |
|------|------|
| `presentation/admin_surveys_page.dart` | Catalog list: create, open editor/responses, export, re-assign, close, delete |
| `presentation/admin_survey_editor_page.dart` | Edit metadata + audience; manage questions (classic) or show locked CHED banner |
| `presentation/admin_survey_responses_page.dart` | Stats, pending reminders, submitted answer viewer, CSV / CHED Excel export |
| `widgets/admin_survey_template_picker.dart` | New-survey choice dialog (builtin / legacy / blank) |
| `widgets/admin_form_fields.dart` | Shared form helpers — **not used by survey screens** (used by events) |

**Supporting domain (not under `admin/surveys/` but required):**

| File | Role |
|------|------|
| `features/surveys/data/survey_service.dart` | CRUD, publish, assignments, reminders, CSV/PDF exports |
| `features/surveys/data/survey_template_service.dart` | List/seed legacy template packs |
| `features/surveys/models/survey_model.dart` | `Survey`, `SurveyQuestion`, `SurveyAssignment`, `SurveyParticipant`, `SurveyResponse` |
| `features/surveys/models/survey_template_model.dart` | Template metadata + blueprint questions |
| `features/surveys/ched_gts/*` | Builtin schema, visibility/skip rules, form, wizard, prefill |
| `features/surveys/application/survey_catalog_refresh.dart` | Notifies reports/dashboard when catalog changes |
| `core/services/ched_gts_export_service.dart` | Multi-sheet CHED GTS Excel pack |
| `core/constants/audience_targeting.dart` | Program/batch filter parse + match |

---

## 3. Screen: Survey list (`AdminSurveysScreen`)

### What you see

- Page title **“Tracer surveys”**
- **Refresh** and **New survey** actions
- A card/list of every survey (newest workflows load via `getAllSurveysForAdmin()`)
- Each row shows:
  - Title
  - Status (draft / published / closed) with colored icon
  - Assignment count, submitted/response count
  - Optional **“CHED preset”** label when the survey was cloned from a legacy template (`templateId` set)
  - Created date
- Empty state when no surveys exist

The screen uses `AutomaticKeepAliveClientMixin` so it stays warm while cached in the admin dashboard stack.

### What you can do

| Action | Behavior |
|--------|----------|
| **New survey** | Opens template picker → creates draft → navigates to editor → reloads list on return |
| **Edit / publish** | Opens editor for that survey |
| **View responses** | Opens responses screen |
| **Export detailed CSV** | Wide/tall detailed CSV (web export only) |
| **Export PDF summary** | PDF summary when there are responses (web only) |
| **Re-assign alumni** | Re-runs publish assignment for current audience (`notify: false`) — published surveys |
| **Close survey** | Sets status to `closed` — published surveys |
| **Delete** | Confirm, then cascade-delete survey + questions/assignments/responses |

### How it works (logic)

1. On first frame after mount → `_load()` → `SurveyService.getAllSurveysForAdmin()`.
2. Create path (`_createSurvey`):
   - `showAdminNewSurveyPicker(context)`
   - **Builtin** → `createBuiltinChedGtsSurvey()`
   - **Blank** → small title/description dialog → `createSurvey(…)`
   - Then `Navigator.push` → `AdminSurveyEditorScreen(surveyId: id)`
3. Catalog mutations (create/publish/close/delete) go through `SurveyService`, which bumps `SurveyCatalogRefresh` so Reports can refresh.

List overflow exports (**Export detailed CSV** / **Export PDF summary**) are shown for **custom** surveys only. Official CHED waves use exports inside **View responses**.

### Key methods

| Method | Purpose |
|--------|---------|
| `_load` | Fetch and display admin survey list |
| `_createSurvey` | Picker → create draft → open editor |
| `_exportSurvey` | Detailed CSV export |
| `_exportSurveyPdfSummary` | PDF summary export |
| `_statusColor` | UI color by status |

---

## 4. Dialog: New survey picker (`showAdminNewSurveyPicker`)

### What you see

- Dialog titled **Create survey**
- Help text explaining options
- Recommended card: **Official CHED GTS** (shows `ChedGtsBuiltin.schemaVersion`)
- **Blank survey** card
- Cancel

### Choices returned

| Choice type | Meaning |
|-------------|---------|
| `NewSurveyChedBuiltin` | Locked official form; no editable question rows |
| `NewSurveyBlank` | Empty custom survey |
| `null` | Cancelled |

### How it works

1. Tap a card → `Navigator.pop` with the sealed choice object.
2. List screen interprets the choice and calls `createBuiltinChedGtsSurvey()` or `createSurvey(…)`.

Legacy preset packs are no longer offered in this dialog.

---

## 5. Screen: Survey editor (`AdminSurveyEditorScreen`)

### What you see

- App bar **Edit survey**
- Optional banner:
  - **Official CHED GTS** — questions locked; audience + publish only
  - **Legacy CHED preset** (existing waves only) — disclaimer from template meta; questions still editable
- Fields: **Title**, **Description**
- **Audience**
  - Course chips (`CourseConstants.courses`)
  - Batch years text (ranges like `2020-2027` or comma-separated years)
- Actions: **Save details**; **Publish** (draft) or **Re-assign alumni** (already published)
- **Questions section**
  - Builtin: info only — no add/delete UI
  - Classic/legacy: questions grouped by section + **Add question**

### What you can do

| Action | Behavior |
|--------|----------|
| Save details | Persists title, description, target programs/batches |
| Publish | Validates audience + questions rules, then assigns alumni and notifies **new** assignees |
| Re-assign | Same assignment pass without notification of already-assigned alumni |
| Add question | Dialog for type/prompt/options → `saveQuestion` (classic only) |
| Delete question | Confirm; extra confirm if `isStandardItem` (legacy CHED item) |

### How it works (logic)

1. `_load`:
   - `getSurvey` + `getQuestions`
   - If `templateId` set → `getSurveyTemplateMeta` for banner/disclaimer
   - Hydrates title/desc controllers and audience fields
2. `_syncBatchFromField` / `_saveMetadata`:
   - Parses batch input via `AudienceTargeting`
   - Writes `updateSurvey` with normalized programs/batches
3. `_publish`:
   - `countAudience` — if filters are set and count is `0`, block with error
   - Classic/legacy: must have **≥ 1** question; **builtin may publish with zero DB questions**
   - Saves metadata → `publishSurvey(id, notify: …)`
   - Publish with notify pops back to list

### Audience targeting rules

- **Empty** program and batch filters ⇒ all non-admin alumni.
- Programs: chip multi-select, normalized by `AudienceTargeting.normalizeCourseTargets`.
- Batches: validated/parsed by `validateBatchYearInput` / `parseBatchYearInput`.
- Match at assign time uses alumni tracer profile (`AudienceTargeting.matches`).

### Builtin vs classic in this screen

| Concern | Builtin CHED | Classic / legacy |
|---------|--------------|------------------|
| Question rows | None | Editable list |
| Editor UI | Locked message | Add / delete / section groups |
| Publish gate | Allows empty questions | Requires ≥1 question |
| Alumni form | Tracer inline + skip logic | Generic take page |

---

## 6. Screen: Survey responses (`AdminSurveyResponsesScreen`)

### What you see

Rich workspace header (breadcrumb, status badges, export menu) + three tabs:

1. **Overview** — participation card, survey information (including resolved **Created by** display name), quick actions, analytics funnel
2. **Pending (n)** — searchable/filterable list with student ID, avatar, program/batch, reminder metadata, bulk remind/export
3. **Submitted (n)** — cards per alumnus with device summary, per-response **PDF / Excel / Print**, timeline, and sectioned detail sheet

Export menu (web): **CHED GTS Excel pack**, **Responses CSV**, management report packs (header). Per-response exports live on each submitted card action menu.

### What you can do

| Action | Behavior |
|--------|----------|
| Refresh | Reload survey, questions, participants |
| Remind (In-app / Email / Both) | Selected pending users, or **all pending** if none selected |
| Export CSV | Wide CSV of submitted answers |
| Export CHED Excel | Multi-sheet pack via `ChedGtsExportService` |
| Export PDF / Excel / Print (submitted card) | Single-alumni response via `SurveySingleResponseExportService` |
| View response | Sectioned detail sheet (CHED A–D or classic sections) |
| View timeline | Lifecycle timeline (assigned → reminders → opened → drafts → submitted) |

Opening this screen calls `markSurveyResponsesSeenByAdmin(surveyId)` to clear admin “new responses” attention for that survey.

### Response lifecycle tracking (privacy-safe)

When migration `20260721100024_survey_response_lifecycle.sql` is applied:

| Event | When recorded | Storage |
|-------|---------------|---------|
| **Opened** | First successful interactive load on take page or Tracer inline CHED (not history/read-only) | `survey_responses.opened_at` + one `opened` row in `survey_response_events` via RPC `record_survey_opened` (idempotent) |
| **Draft saved** | Each explicit draft save | `first_draft_at` (first time only) + append `draft_saved` event |
| **Submitted** | First successful submission | Append one `submitted` event |

Device metadata is **coarse only**: `device_category` (mobile/tablet/desktop/other), `platform_family` (android/ios/web/windows/macos/linux/other), `browser_family` (chrome/safari/firefox/edge/opera/native/other). No IP, raw user agent, versions, or device fingerprints.

Client capture: `lib/core/utils/client_context.dart` → `SurveyClientContext.capture()`.

Older responses without tracked events show explicit **Not tracked** / **Not recorded** fallbacks in the timeline UI.

### Participant identity enrichment

`getSurveyParticipants` batch-loads `users.student_id` and `users.profile_image_base64` (public avatar URL; legacy column name). Cards show real student ID when present and avatar with initials fallback. Survey **Created by** resolves through `users.display_name`, falling back to email/UUID.

### How submitted answers are shown

| Survey type | Detail view |
|-------------|-------------|
| Builtin CHED (`isChedGtsBuiltin` **or** answer keys start with `ched_`) | Sectioned read-only CHED form (A–D) with sticky section nav |
| Classic | Sectioned Q&A list grouped by question section |

Per-response PDF/Excel include alumni metadata + sectioned answers (respecting CHED visibility rules for builtin surveys).

### Reminder logic

1. Build target user ids (selection, else all pending).
2. If email requested but SMTP/email config missing → snackbar / fall back to in-app only when both were requested.
3. `SurveyService.sendReminders(...)` creates in-app notifications and optional emails; bumps `reminder_count` / `last_reminder_at` on assignments.

### Key methods

| Method | Purpose |
|--------|---------|
| `_load` | Load survey + questions + participants; mark seen |
| `_filter` | Search pending/submitted by name, email, program, batch |
| `_sendReminders` | In-app and/or email reminders |
| `_exportCsv` | Responses CSV download |
| `_exportChedGtsExcel` | Official multi-sheet Excel |
| `_buildOverview` / `_buildPendingTab` / `_buildSubmittedTab` | Tab UIs |

---

## 7. Publish / assignment pipeline (shared logic)

Owned by `SurveyService.publishSurvey`:

1. Load survey; enforce question rule (skip for builtin).
2. Resolve audience (all alumni or filtered by program/batch).
3. Upsert `survey_assignments` for each matched user (preserve existing status/reminders).
4. Set survey `status = published`; update `assignment_count`.
5. If `notify: true`, notify **only newly assigned** users.
6. Notify catalog refresh.

**Close** sets `status = closed` (no longer offered as an open wave for new completion flows as a published survey).

**Delete** removes the survey row; related questions/assignments/responses cascade.

---

## 8. Data models that drive the UI

### `Survey`

| Field | Meaning |
|-------|---------|
| `id`, `title`, `description` | Identity / copy |
| `status` | `draft` \| `published` \| `closed` |
| `targetPrograms`, `targetBatchYears` | Audience filters |
| `openAt` / `closeAt` | Optional window (`isOpen` getter) |
| `assignmentCount`, `responseCount` | List/overview stats |
| `createdBy`, `createdByDisplayName` | Auth UUID + resolved admin display name (when loaded) |
| `kind`, `templateKey`, `schemaVersion` | Stored in `surveys.data` JSON — builtin marker (`ched_gts_builtin`) |

Getters: `isFromTemplate`, `isChedGtsBuiltin`, `isOpen`.

### `SurveyQuestion` (classic / legacy)

Type (`text` / `single` / `multiple` / `scale` / `date`), `prompt`, `required`, `options`, scale bounds, optional `section`, `chedItemNumber`, `prefillKey`, `isStandardItem`.

### `SurveyAssignment` / `SurveyParticipant`

Assignment status: `notStarted` → `inProgress` → `completed`.  
`SurveyParticipant` joins assignment + display name/email/program/batch + optional `studentId`, `profileImageUrl`, and response for the admin responses UI.

### `SurveyResponse`

`answers` map + `draft`/`submitted` + timestamps. Optional lifecycle fields: `openedAt`, `firstDraftAt`, `deviceCategory`, `platformFamily`, `browserFamily`.  
Builtin answers use stable keys (`ched_1`, `ched_16`, …). Classic answers use question UUIDs.

### `SurveyResponseEvent`

Append-only rows in `survey_response_events`: `opened`, `draft_saved`, `submitted` with coarse device metadata.

---

## 9. Exports (what each button produces)

| Entry point | Output | Notes |
|-------------|--------|-------|
| List → Detailed CSV | Roster + tallies + per-question raw | Question-row based; weak for builtin (no DB questions) |
| List → PDF summary | Summary PDF | Same limitation for builtin |
| Responses → CSV | One row per submitted user; columns from questions/answers | Works for both; builtin columns follow answer keys / questions available |
| Responses → CHED GTS Excel | Sheets: README, A_General, B_Education, Employment_Tracer, Survey_C_D, Survey_Wide | Builtin uses `ChedGtsBuiltin.items`; classic uses `survey_questions` |
| Submitted card → PDF | Single-alumni PDF (metadata + sectioned answers) | Web download via `SurveySingleResponseExportService` |
| Submitted card → Excel | Metadata + Answers sheets | Web download |
| Submitted card → Print | Same PDF bytes | Uses `printing` package; works where platform print dialog is supported |

All file **downloads** are **web-oriented** (`requireWebExport` / `canExportFiles`). Print may work on desktop/mobile where the OS print dialog is available.

---

## 10. End-to-end workflows

### A. Publish Official CHED GTS

1. Surveys → **New survey** → **Official CHED GTS**
2. Editor: set title/description (optional), pick courses/batches (optional)
3. **Publish** → alumni in audience get assignments
4. Alumni complete the form on **Tracer** (not a separate generic survey page)
5. Admin → **View responses** → Submitted → expand → read-only CHED form
6. Optional: CHED Excel export or reminders for pending

### B. Custom / blank survey

1. New → Blank → title/description
2. Editor: add questions → Save → Publish
3. Alumni take via surveys UI
4. Admin views Q&A list under Submitted; CSV/PDF as needed

### C. Legacy template clone

1. New → pick seeded CHED pack
2. Editor shows disclaimer; questions are editable clones
3. Publish / responses / export like a classic survey (no paper skip logic)

---

## 11. Feature checklist (admin surveys today)

- [x] List all surveys with status and counts  
- [x] Create Official CHED or blank survey  
- [x] Edit title, description, audience  
- [x] Publish and re-assign with audience targeting  
- [x] Close and delete surveys  
- [x] Add/delete questions (classic / legacy only)  
- [x] View pending vs submitted participants  
- [x] Search participants  
- [x] In-app and email reminders  
- [x] Read-only CHED form for builtin submissions  
- [x] Classic answer list for custom surveys  
- [x] CSV / PDF / CHED Excel exports (web)  
- [x] Per-response PDF / Excel / print from submitted cards  
- [x] Privacy-safe response lifecycle tracking (opened / draft / submitted)  
- [x] Participant student ID + avatar enrichment  
- [x] Resolved survey creator display name  
- [x] Mark responses seen for admin attention badge  
- [x] Catalog refresh hook for Reports  

---

## 12. Out of scope on these screens

These exist elsewhere but are **not** part of the admin Surveys pages themselves:

- Alumni Tracer wizard / take page (`features/alumni/tracer`, `features/surveys/presentation`)
- Alumni Directory → member detail → Tracer responses viewer
- Admin Reports survey analytics charts
- Dashboard home survey metric chips (consume `SurveyService` stats)

### Applying the response lifecycle migration

Migration file: `supabase/migrations/20260721100024_survey_response_lifecycle.sql` (not auto-applied in this repo).

```bash
supabase db push
```

Or apply the SQL manually in the Supabase SQL editor / your deployment pipeline.

---

*Generated from the current Flutter admin survey implementation. When behavior changes, update this file alongside `lib/features/admin/surveys/`.*
