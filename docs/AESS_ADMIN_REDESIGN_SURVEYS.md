# Surveys list (menu index 10) — Phase A audit · Phase B proposal

Date: 2026-10-14. Parent: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §8–§9 (step 4). Builds on Phase 0 ([0a](AESS_ADMIN_REDESIGN_PHASE0A_TOKENS.md), [0b](AESS_ADMIN_REDESIGN_PHASE0B_SHELL.md), [0c](AESS_ADMIN_REDESIGN_PHASE0C_COMPONENTS.md)) and the closed [Dashboard](AESS_ADMIN_REDESIGN_DASHBOARD.md), [Alumni Directory](AESS_ADMIN_REDESIGN_DIRECTORY.md) and [Member Detail](AESS_ADMIN_REDESIGN_MEMBER_DETAIL.md).

Scope: the **list view** of `AdminSurveysPage` — header, KPI cards, toolbar (search, Kind, Sort, status chips), survey cards and their action menu, the confirmation dialogs those actions open, and the "New survey" flow (template picker + Blank survey dialog). **Out of scope:** the in-page Survey Editor (step 5) and Survey Responses (step 6) panels, which this page only switches to.

Evidence:
- **Code inspection** of the files in A2 and the `SurveyService` methods the list calls.
- **Live, read-only** session (release build, `admin@gmail.com`, 2026-10-14). Screenshots kept locally in `%TEMP%\aess_qa\sv_a_*.png`: list at 1920×1080, 1366×768, 1024×768 and 768×1024; action menus of a published and a draft card; New survey picker; Blank survey dialog; Delete confirmation.
- Nothing was created, edited, sent or deleted. The picker's official CHED card was **not** clicked (it creates a draft immediately). The Blank survey dialog was cancelled, and the Delete confirmation was dismissed with Escape; the KPI counts were unchanged afterwards.

---

## A1. Purpose and user

Admins manage every survey the system sends to alumni: official CHED GTS tracer waves and custom surveys. From this list they create a survey, find one by status/kind/text, open its responses, open the editor to edit/publish, and run lifecycle actions (duplicate, export, remind pending alumni, re-assign the audience, close, archive/restore, delete).

## A2. Files

| File | Role | LOC |
|---|---|---:|
| `features/admin/surveys/presentation/admin_surveys_page.dart` | List state, filters, sort, KPIs, menu actions, confirmations, New survey flow; switches to the Editor / Responses panels | 886 |
| `features/admin/surveys/widgets/admin_survey_ui.dart` | `AdminSurveyTheme`, `SurveyStatusChip`, `SurveyKindChip`, `SurveyPageHeader`, `SurveyListCard`, button style helpers (plus editor/responses widgets not used by the list) | 1,173 |
| `features/admin/surveys/widgets/admin_survey_template_picker.dart` | `showAdminNewSurveyPicker` (Official CHED GTS or Blank survey) | 347 |
| Shared, from `features/admin/roster/widgets/alumni_directory_ui.dart` | `DirectoryStatsGrid`, `DirectoryStatCard`, `DirectoryToolbarCard`, `DirectoryFilterField`, `DirectoryToolbarFilterChip`, `DirectoryActiveFilterChip`, `DirectoryEmptyState` | — |
| Shared, other | `AdminInstantContent` (dashboard widgets), `PortalCardListSkeleton` (alumni-portal skeletons), `AdminPageHeader`, `confirmPersonalDataExport`, `requireWebExport`, `tryDownloadBytesOnWeb` | — |

No tests cover this screen today (no test references `AdminSurveysPage`, `SurveyListCard`, the chips or the picker).

## A3. Data and sources (must not change)

| Data | Source |
|---|---|
| Survey list | `SurveyService.getAllSurveysForAdmin()` = `getAllSurveys()` + live submitted-response counts per survey (`countSubmittedResponsesBySurvey`) |
| KPI counts | Computed in the page from the loaded list: Draft / Published / Closed (non-archived, by status), Archived count (chip label), Responses = sum of `responseCount` over non-archived surveys (official CHED and custom together) |
| Card fields | `title` ("Untitled survey" if empty), `status`, `archived`, `isScheduledWindow`, kind (`isChedGtsBuiltin` / `isFromTemplate`), `schemaVersion`/`templateVersion`, `assignmentCount`, `responseCount`, `createdAt`, `openAt`, `closeAt` |
| Filters / sort / search | Client-side over the loaded list: status (Active = all non-archived, Draft, Published, Closed, Archived), kind (All, Official CHED, Custom = everything not official CHED), sort (Newest, Oldest, Title A–Z, Most responses), search over title, description, template key and kind |
| Writes (menu actions) | `createBuiltinChedGtsSurvey`, `createSurvey`, `duplicateSurvey`, `setSurveyArchived`, `publishSurvey` (re-assign), `closeSurvey`, `deleteSurvey` (blocked server-side once a survey has submitted responses), `sendReminders` (in-app + email to pending alumni) |
| Exports | Detailed CSV (`buildDetailedSurveyExportCsv`, after `confirmPersonalDataExport`) and PDF summary (`buildDetailedSurveySummaryPdfBytes`, includes respondents' display names) — custom surveys with ≥ 1 response, web only |

Refresh model: `_load()` runs on first frame, on the toolbar Refresh button, after closing the Editor/Responses panel and after archive/restore, re-assign, close and delete. The page is kept alive in the dashboard's IndexedStack. **It has no survey catalog listener** (the audit's §9 note "catalog refresh listener" applies to the Dashboard and Reports pages, which listen to `SurveyCatalogRefresh`; this list does not).

## A4. Interactions (all preserved in any redesign)

- Header: **New survey** (disabled while loading) → picker: Official CHED GTS card (creates a locked draft at once and opens the editor) or Blank survey (Title + Description dialog → creates a draft → editor). The shell's "+ New → Create Survey" only navigates to this page.
- KPI cards Draft / Published / Closed set the status filter; Responses has no action.
- Toolbar: search (with clear), Refresh, Kind and Sort dropdowns, status chips (Active, Draft, Published, Closed, Archived (N)), active-filter chips with remove, Reset filters.
- Card click → Responses panel. Card menu (items depend on state): Edit / publish, View responses, Duplicate (→ editor), Export detailed CSV, Export PDF summary, Remind pending, Re-assign alumni, Close survey, Archive or Restore from archive, Delete.
- Confirmations: Archive / Restore, Re-assign, Close (red), Delete (red), Send reminders. Success/failure SnackBars.
- Empty states: "No surveys yet" (+ New survey) and "No matches".

## A5. Layout today (live, 1366×768)

Page header "Tracer surveys" / "Create and manage tracer waves and surveys." with **New survey** on the right → four KPI cards in one row (value-first `DirectoryStatCard`: Draft 3, Published 8, Closed 0, Responses 5) → toolbar card (search + Refresh on row 1; Kind, Sort and five status chips on row 2) → vertical list of full-width cards. Each card: optional 4 px orange left bar (official CHED / preset), 32 px icon box, title (13.5 w700), status chip + kind chip ("Official CHED · v3.0.0" with a lock icon, or "Custom"), meta line "N assigned · N submitted · Created … · Opens … · Closes …", and a ⋮ menu on the far right.

Live data: 11 non-archived surveys, 0 archived. 7 are official CHED waves (11 minus the Dashboard's 4 "Other surveys"); all 6 that appeared in the screenshots are titled **"CHED Graduate Tracer Survey (GTS)"**.

## A6. Problems and opportunities

**Functional defects (pre-existing — fixing needs approval):**

1. **Close and Delete have no error handling** (page lines 520–544). `closeSurvey` / `deleteSurvey` throw on failure, and the database blocks deleting a survey that has submitted responses, yet the menu offers Delete on every survey. A failure becomes an unhandled exception: no message, no reload. *(Code inspection; not reproduced, since reproducing needs a write.)*
2. **A failed load looks like an empty system.** `_load` only shows a SnackBar on error; on a first-load failure `_surveys` stays empty, so the page shows "No surveys yet — Create an Official CHED GTS wave…" with a New survey button. On a failed refresh the old list stays with no lasting indication. *(Code inspection.)*
3. **Raw error text** in 8 places: "Error loading surveys: $e", "Error: $e" (create), "Export failed: $e", "PDF export failed: $e", and bare `$e` for duplicate, archive/restore, remind and re-assign (e.g. "Exception: Unarchive this survey before…").
4. **No busy state for row actions.** Duplicate, archive/restore, re-assign, remind and both exports run with no progress indicator, and the same menu can be reopened and the action started again (e.g. a second round of reminder emails while the first is still sending). *(Code inspection.)*
5. **PDF summary export skips the personal-data confirmation.** The CSV export asks `confirmPersonalDataExport` first; the PDF summary (which lists respondents' display names) does not.
6. **Reminder result hides problems.** `sendReminders` returns failures and "email skipped" counts (no address / email not configured), but the SnackBar shows only "Reminders sent: N in-app, N email" in green, even when some failed.
7. **Blank survey can be created with an empty title.** "Create" is always enabled; an empty title is saved and the card shows "Untitled survey". *(Adding validation changes form behaviour — approval item.)*

**Information / consistency:**

8. **"Scheduled" also means "window ended".** `isScheduledWindow` is true for any published survey outside its open/close window — both not yet open and **past its close date**. Live: a wave with "Opens Aug 7, 2026 · Closes Aug 14, 2026" shows **Scheduled** in October 2026. The model already has `isNotYetOpen` and `isPastClose`, so the chip could say "Scheduled" vs "Window ended" without changing any calculation. The same surveys are counted in the "Published — Live waves" KPI.
9. **Identical titles, unnamed confirmations.** At least six cards are titled "CHED Graduate Tracer Survey (GTS)" and differ only in status chip and dates. The Delete, Close, Archive and Re-assign confirmations do not name the survey (live: "Delete survey? This cannot be undone."), and Delete does not mention that it is refused once responses exist.
10. **Status filtering appears twice** (tappable KPI cards and toolbar chips). The "Active" chip means "all non-archived", which reads like "open/published". The Responses KPI looks like the others but has no action.
11. **Kind filter vs card kinds.** Cards show three kinds (Official CHED, CHED preset, Custom); the Kind filter has two, and "Custom" includes CHED presets.
12. **Meta line** shows assigned and submitted counts but not the share submitted, and nothing about the audience. A response rate would be a display-only derived value (approval item).
13. **Exports hidden for official CHED surveys** without a hint (code comment: they live under View responses).
14. **Title wording:** page title "Tracer surveys" while the sidebar and breadcrumb say "Surveys", and the page also holds non-tracer custom surveys. *(Wording — approval item.)*
15. KPI totals differ from the Dashboard's "Other surveys" tile (Published 8 here vs 3 there) because the Dashboard tile excludes official CHED waves; neither surface says so. Not a defect; label clarity only.

**Visual / design-system:**

16. **Action menu:** up to 10 flat text items, no icons, no grouping; Close survey and Delete look like routine items (live). Audit §9 focus: "action menu grouping (routine vs destructive)".
17. **Dialogs not on 0c components:** `_confirmAction`, the reminder dialog (`ElevatedButton` "Send") and the Blank survey dialog are plain `AlertDialog`s with the default Material 3 lavender surface and large radius (live). The Blank survey dialog is narrow (~280 px) and its field borders are hard to see. 0c has `showAdminConfirmDialog` / `showAdminDialogSurface`.
18. **SnackBars** use `Colors.green` / `Colors.red`; archive/restore success has no colour.
19. **KPI cards** use the older `DirectoryStatsGrid` / `DirectoryStatCard` (value-first) while the signed-off Dashboard and Directory use `AdminKpiCard` (+ `DirectoryKpiRow`).
20. **Chips and CHED colours:** status/kind chips are 999-radius pills, 12 px w600, unlike the Directory badges. CHED colour literals `#C2410C`, `#EA580C`, `#FFF7ED` in the card. The same concept is navy-tinted on the card ("Official CHED") but amber in the picker ("Official · v3.0.0").
21. **Loading skeleton** is `PortalCardListSkeleton` from the alumni portal (shape not checked against these cards).
22. **Vertical space:** at 1366×768 the header, KPIs and two-row toolbar use ~315 px; about four cards are visible (live).
23. **Wide screens:** at 1920 cards span ~1,700 px with title/chips/meta on the left and the ⋮ menu at the far right (live).
24. Accessibility: every card icon has `Semantics(label: 'Survey')`, adding a redundant "Survey" announcement per card; the ⋮ button has the tooltip "Survey actions" but no survey name.

**Code health (note only):** `SurveyEmptyState` is not used by the list (it uses `DirectoryEmptyState`) but is used by the Editor and Responses panels.

## A7. Responsive notes (live, read-only)

| Width | Observed |
|---|---|
| 1920×1080 | Sidebar expanded; KPIs 4-up; toolbar 2 rows; very wide cards (A6 item 23). No overflow |
| 1366×768 | As A5; ~4 cards visible. No overflow |
| 1024×768 | Sidebar collapses to the icon rail; KPIs still 4-up; all five status chips fit on toolbar row 2. No overflow |
| 768×1024 | New survey moves under the subtitle; KPIs 2×2; toolbar still 2 rows. No overflow |

Not checked: widths below 768, the loading skeleton, empty states, the error path, and the archived view (no archived surveys in live data).

## A8. Shared-component dependencies and risks

| Component | Other users | Risk if changed |
|---|---|---|
| `DirectoryStatsGrid` / `DirectoryStatCard` | DSS, DSS History, Announcements, Events, Forum, Jobs, Feedback | Do not edit; Surveys can switch to `AdminKpiCard` locally (as the Directory did) |
| `DirectoryToolbarCard`, `DirectoryFilterField`, `DirectoryToolbarFilterChip`, `DirectoryActiveFilterChip` | ~20 files (Directory, Events, Jobs, DSS, Forum, Announcements, Feedback, Activity Logs, Reports filter bar, survey export/analytics/responses, CHED wave comparison) | Use as is |
| `DirectoryEmptyState`, `AdminInstantContent` | Several admin pages | Use as is (pass parameters only) |
| `PortalCardListSkeleton` | Alumni portal: Forum, user Surveys, Tracer | Do not edit; give the admin list its own skeleton if needed |
| `SurveyStatusChip`, `SurveyKindChip` | Survey list **and the Survey Editor header** (step 5) | Any change also shows in the editor → needs approval, or list-local variants |
| `AdminSurveyTheme` | 12 files across the Surveys feature (editor, responses, dialogs) | Do not change values |
| `SurveyListCard`, `SurveyPageHeader`, `showAdminNewSurveyPicker` | Survey list only | Safe to restyle (feature-local) |
| `SurveyService` | Many | Do not change |

Other risks: menu items, their visibility conditions and their order of checks must stay identical; confirmation outcomes and the reload after each action must be preserved; panel switching (`ValueKey`s, return-to-responses) must not change. Phase C would need new widget tests for the card, chips and menu grouping (the page itself talks to Supabase directly).

## A9. Decisions needed before Phase B

1. **Live QA in Phases D/E.** Every list action except opening panels writes data, and **Remind pending sends real in-app notifications and emails to alumni**. Options: (a) keep D/E read-only (open menus and dialogs, then cancel), or (b) allow reversible actions on a QA-only survey created for the test (Blank survey "QA test" → duplicate → archive/restore → delete), never Remind, Re-assign or Close on real waves.
2. **Functional fixes 1–7:** include in the proposal, each separately approvable, or list as follow-ups?
3. **Information items 8–14** (Scheduled vs Window ended, naming the survey in confirmations, Active label and duplicate filters, kind filter, response rate, export hint, title wording): include as approvable proposal items?
4. **New survey flow:** restyle the picker and Blank survey dialog as part of this screen (visual only; behaviour unchanged), or leave them for later?
5. **Status/kind chips:** allow restyling the shared `SurveyStatusChip` / `SurveyKindChip` (the Editor header changes too), or use list-local variants until the Editor step?

**Owner answers (2026-10-14):** (1) Phases D/E **read-only** (open menus and dialogs, then cancel). (2) Functional fixes 1–7 go into the proposal, each separately approvable. (3) Information items 8–14 go into the proposal as approvable items. (4) Picker and Blank survey dialog restyled as part of this screen, visual only. (5) Restyling the shared `SurveyStatusChip` / `SurveyKindChip` **allowed** (Editor header changes too). Owner chose to **stop here**: audit approval and Phase B **not yet given**.

**2026-10-15:** Phase A **approved**; Phase B authorized. Owner switched to **UI-first mode**: Phases D/E for this screen are lightweight code-level checks only; live QA and regression move to the later testing phase. This supersedes answer (1).

---

## B. Redesign proposal (Phase B — no production code changed)

Builds on the signed-off Directory pattern: `AdminKpiCard` (dense) in `DirectoryKpiRow`, `DirectoryToolbarCard` with opt-in `singleRowMinWidth`, 0c dialogs (`showAdminConfirmDialog`, `showAdminDialogSurface`), `AdminStateView`, and the Directory row-menu look (white, radius 12, dense icon rows). No new shared components. No `SurveyService`, model or schema changes.

### B1. Layout (1366×768, sidebar expanded, content ≈ 1,086 px)

```
┌ Surveys ─────────────────────────────────────────────────────────────────────── [+ New survey] ┐
│ Official CHED GTS tracer waves and custom alumni surveys.                                        │
├──────────────────────┬──────────────────────┬──────────────────────┬────────────────────────────┤
│ ✎ Draft            3 │ ⇪ Published        8 │ 🔒 Closed          0 │ ◔ Responses              5 │
│ Not yet published    │ Live, scheduled or   │ Ended waves          │ Submitted · all active     │
│                      │ window ended         │                      │ surveys (CHED + custom)    │
├──────────────────────┴──────────────────────┴──────────────────────┴────────────────────────────┤
│ [🔍 Search title, description, kind…  ] [Kind ▾] [Sort ▾]  All·Draft·Published·Closed·Archived(0) ⟳ │
│ (active-filter chips + Reset only when filters are active)                                        │
├────────────────────────────────────────────────────────────────────────────────────────────────┤
│▌[🎓] CHED Graduate Tracer Survey (GTS)        │ RESPONSES           │ WINDOW               │  ⋮ │
│▌     [Published] [🔒 Official CHED · v3.0.0] │ 3 of 120 · 3%       │ Aug 7 – Aug 14, 2026 │    │
│▌     Created Oct 1, 2026                      │ ▰▱▱▱▱▱▱▱▱▱          │ Window ended         │    │
├────────────────────────────────────────────────────────────────────────────────────────────────┤
│ [▤] Alumni Homecoming Feedback               │ 0 of 0              │ No window set        │  ⋮ │
│     [Draft] [Custom]                          │ Not assigned yet    │                      │    │
│     Created Sep 20, 2026                      │                     │                      │    │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

▌ = 3 px USTP Gold bar on Official CHED rows only (see S2).

### B2. CURRENT DATA → CURRENT COMPONENT → PROPOSED COMPONENT

| Data | Current | Proposed |
|---|---|---|
| Page title/subtitle + New survey | `SurveyPageHeader` "Tracer surveys" | Same component; wording per I7 |
| Draft / Published / Closed / Responses counts (same formulas) | `DirectoryStatsGrid` + `DirectoryStatCard` | `DirectoryKpiRow` + `AdminKpiCard(dense)`; the three status cards keep their tap-to-filter, Responses stays non-interactive (no hover affordance) |
| Search, Refresh, Kind, Sort, status chips, active chips, Reset | `DirectoryToolbarCard` (2 rows) | Same component + `singleRowMinWidth` (one row where it fits, target ≥ 1366; 2 rows below) |
| Title, status, kind, version, assigned, submitted, created, opens, closes | `SurveyListCard`: one meta line | Restyled `SurveyListCard` (feature-local): identity zone (title, chips, created) · Responses zone (submitted of assigned, % and bar, see I5) · Window zone (opens–closes + window state) · ⋮. Below ≈ 960 px content width: stacked layout as today (title, chips, meta line) |
| Menu items (same items, conditions and order) | Flat text `PopupMenuItem`s | Grouped with dividers + leading icons (B3); red text/icon for Close survey and Delete |
| Confirmations | `AlertDialog` (lavender M3 surface) | `showAdminConfirmDialog` (white, 0c); destructive flag kept for Close/Delete |
| Reminder confirmation | `AlertDialog` + `ElevatedButton` "Send" | `showAdminConfirmDialog`, confirm "Send reminders"; same pending count and title in the text |
| Blank survey dialog | Narrow `AlertDialog` | `showAdminDialogSurface`, ~480 px, labelled fields with visible borders, helper text (N2) |
| New survey picker | Custom dialog, 22 px title, amber "Official" badge | Same structure and choices; type scale to `AdminText`, Official badge navy like the card chip (N1) |
| Loading | `PortalCardListSkeleton` (alumni portal) | Feature-local skeleton shaped like the new rows (portal skeleton left untouched) |
| Load failure | SnackBar only (empty state shows "No surveys yet") | `AdminStateView.error` + Try again on first load; slim inline notice on a failed refresh (FX2) |
| SnackBars | `Colors.green` / `Colors.red` / none | `AdminColors.success` / `danger` / `warning` tokens; archive/restore success gets the success colour |

### B3. Action menu grouping (item order unchanged — only dividers and icons added)

| Group | Items (existing conditions) | Icons |
|---|---|---|
| Open | Edit / publish · View responses · Duplicate | `edit_outlined`, `insights_outlined`, `content_copy_outlined` |
| Export *(custom, ≥ 1 response, web)* | Export detailed CSV · Export PDF summary | `table_view_outlined`, `picture_as_pdf_outlined` |
| Audience *(published, not archived)* | Remind pending · Re-assign alumni | `notifications_active_outlined`, `group_add_outlined` |
| Lifecycle | Close survey *(published, not archived; red)* · Archive / Restore from archive | `lock_outline`, `archive_outlined` / `unarchive_outlined` |
| Danger | Delete *(red)* | `delete_outline` |

Menu tooltip becomes "Actions for ‹title›"; the card's redundant `Semantics('Survey')` icon label is removed; the card gets the semantic label "Open responses for ‹title›" (item 24).

### B4. Approvable items

**Base (one approval):** B1 layout, B2 component mapping, B3 menu grouping, KPI/toolbar/skeleton/SnackBar token changes, W1 (zone layout so wide screens no longer leave a 1,700 px card with the ⋮ menu at the far edge).

**Functional fixes (audit items 1–7), each separately approvable:**

| ID | Fix | Behaviour change |
|---|---|---|
| FX1a | Close and Delete get try/catch + friendly SnackBar + reload | Errors now shown instead of an unhandled exception |
| FX1b | Delete is shown **disabled** with "Has responses — archive instead" when `responseCount > 0` (the database already refuses it) | Item still visible; cannot be started |
| FX2 | Load error state (first load) + inline "Couldn't refresh — showing the last loaded list · Try again" on refresh failure | Empty state no longer shown for a failure |
| FX3 | Friendly errors: action context + message without the `Exception:` prefix (e.g. "Couldn't duplicate the survey. ‹reason›") | Text only |
| FX4 | Per-survey busy state: spinner in place of ⋮ and menu disabled while that survey's action runs (duplicate, archive/restore, re-assign, remind, close, delete, both exports) | Prevents double-starting an action |
| FX5 | PDF summary asks `confirmPersonalDataExport` first (as CSV does) | One extra confirmation |
| FX6 | Reminder result shows sent counts plus skipped (no address / email not configured) and failures; warning colour when any skipped/failed | Text/colour only |
| FX7 | Blank survey: **Create** disabled until a title is entered; "Required" helper | Empty-title surveys can no longer be created from this dialog |

**Information items (audit 8–15), each separately approvable:**

| ID | Item |
|---|---|
| I1 | Status chip: "Scheduled" only when not yet open (`isNotYetOpen`); **"Window ended"** for published surveys past `closeAt` (`isPastClose`). Display only; no status or count changes. Via a new `SurveyStatusChip.fromSurvey` factory; the Editor header keeps its current call until step 5 |
| I2 | Confirmations name the survey and add status + dates to tell identical CHED titles apart; Delete text adds "Surveys with submitted responses can't be deleted — archive instead." |
| I3 | Status chip "Active" → **"All"** with tooltip "All surveys except archived" (filter unchanged) |
| I4 | Kind filter adds **CHED preset** (All kinds · Official CHED · CHED preset · Custom), matching the three card kinds; "Custom" then excludes presets (today it includes them) |
| I5 | Response rate: "N of M · P%" + thin bar (P = submitted ÷ assigned, display only); "Not assigned yet" when M = 0 |
| I6 | Official CHED / preset rows: a disabled, informational menu line "Exports: open View responses" in the Export group |
| I7 | Title **"Surveys"** (matches sidebar/breadcrumb), subtitle "Official CHED GTS tracer waves and custom alumni surveys."; KPI captions say what is counted (Published "Live, scheduled or window ended", Responses "Submitted · all active surveys (CHED + custom)" — explains the Dashboard difference, item 15) |

**Shared (allowed in §A9.5, confirm here):** SH1 — `SurveyStatusChip` / `SurveyKindChip` (`_SurveyChip`) restyled to the Directory badge look: radius 6, 11 px w600, 11 px icon, padding 8×4. Same labels and colours (status tokens; Official CHED navy on info tint). **Also visible in the Survey Editor header.**

**New survey flow (visual only):** N1 picker type scale/badge colour/radius tokens; N2 Blank survey dialog as in B2 (labels "Title" / "Description (optional)", helper "Creates a draft. You add questions in the editor next.", buttons Cancel / Create).

**Potential content simplification — requires approval:**

| ID | Change | Recommendation |
|---|---|---|
| S1 | Keep both status filter paths (KPI tap + toolbar chips) | **Keep both** (no change) |
| S2 | Left bar: Official CHED → USTP Gold (`AdminColors.accent`); **CHED preset loses its orange bar** (still identified by its "CHED preset" chip). Removes the `#C2410C` / `#EA580C` / `#FFF7ED` literals | Approve |

### B5. Responsive behaviour

| Width | Behaviour |
|---|---|
| 1920 / 1600 / 1440 | KPIs 4-up; toolbar one row; zone rows (Responses ≈ 180 px, Window ≈ 200 px; title zone takes the rest) |
| 1366 | Same; toolbar single row if it fits (measured in C; otherwise 2 rows as today). Expected ≈ 4–5 rows visible (KPI row is taller as in the Directory, toolbar shorter) |
| 1024 (rail) | KPIs 4-up; toolbar 2 rows; rows switch to the stacked layout below ≈ 960 px content |
| 768 | As today (KPIs 2×2, New survey under subtitle); stacked rows |

### B6. Unchanged

`_load` and its triggers, all `SurveyService` calls and arguments, list/KPI formulas, filter/sort/search logic (except I4 if approved), menu values and their visibility conditions, confirmation outcomes and reloads, panel switching (`ValueKey`s, return-to-responses), card tap → Responses, export file names and contents, New survey choices and the create calls.

### B7. Risks

- SH1 and I1 change what the Survey Editor header shows (chip shape now; I1 only when the Editor adopts the factory in step 5).
- FX1b, FX4, FX5, FX7 and I4 change behaviour slightly (listed above); each can be declined independently.
- Zone layout on very long titles: titles wrap to 2 lines and ellipsize after that (tooltip with full title).
- I5 percentages use `assignmentCount`, which can lag until "Re-assign" runs; shown as-is (no new query).

### B8. Phase C/D/E plan (UI-first mode)

- **C:** implement the approved items only in `admin_surveys_page.dart`, `admin_survey_ui.dart` (chips, card, header, skeleton) and `admin_survey_template_picker.dart`. Checks: `flutter analyze` on the surveys feature; one small widget-test file for the card/menu (menu items, order and conditions unchanged; chip labels; no overflow at 768/1366/1920).
- **D:** code-level responsive review + at most one quick visual look if a preview is already running.
- **E:** deferred to the later testing phase (no live writes).

**2026-10-15:** Phase B **approved in full** (base, FX1a–FX7, I1–I7, SH1, N1, N2, S1 keep both, S2). Phase C authorized.

---

## C. Implementation (Phase C — 2026-10-15)

### C1. Implemented

- **Page** (`admin_surveys_page.dart`): title "Surveys" + new subtitle (I7); KPI row → `DirectoryKpiRow` + dense `AdminKpiCard` with captions (same formulas, same tap filters, Responses non-interactive); toolbar `singleRowMinWidth: 1000` (filters lay out as a Row in single-row mode, Wrap otherwise); status chip "All" + tooltip (I3); Kind filter adds CHED preset (I4: Custom now = not CHED and not from a template); grouped menu with icons, red Close/Delete, disabled Delete with note when `responseCount > 0` (FX1b), disabled "Exports: open View responses" line for official CHED/preset with responses (I6); all confirmations → `showAdminConfirmDialog` and name the survey via `surveyIdentityText` (I2); Close/Delete try/catch + success/failure SnackBars + reload (FX1a); `_friendlyError` (same rule as the Directory) for every error SnackBar (FX3); per-survey `_busyIds` around all non-navigation menu actions (FX4); PDF summary asks `confirmPersonalDataExport` first (FX5); reminder SnackBar adds email-skipped counts and failures, warning colour if any (FX6); Blank survey dialog → `showAdminDialogSurface` 480 px, white fields with visible borders, helper text, Create disabled until a title is entered (N2, FX7); first-load failure → `AdminStateView.error` + Try again, refresh failure → inline warning notice + Try again (FX2); SnackBars on `AdminColors` tokens.
- **Card and chips** (`admin_survey_ui.dart`): `SurveyListCard` rebuilt — zone layout ≥ 960 px card width (identity · RESPONSES "N of M · P%" + bar or "Not assigned yet" · WINDOW dates + state dot "Not yet open / Window ended / Accepting responses" · menu), stacked layout below with the original meta line + rate; 3 px USTP Gold bar on official CHED only, orange literals removed (S2); hover `AdminColors.rowHover`; semantic label "Open responses for ‹title›", menu tooltip "Actions for ‹title›", redundant "Survey" label removed; spinner replaces ⋮ while busy. New: `SurveyStatusChip.fromSurvey` + `windowEnded` (I1), `surveyStatusText`, `surveyWindowText`, `surveyResponseRate`, `surveyIdentityText`, `surveyMenuItem`, `SurveyListSkeleton` (replaces `PortalCardListSkeleton` here only). `_SurveyChip` restyled to the Directory badge look (SH1). `metaLine` parameter removed from `SurveyListCard` (list-only widget).
- **Picker** (`admin_survey_template_picker.dart`, N1): title 22 → 18 px, subtitle on token colour, Official badge navy (matches the card chip), official icon box gold tint, radius token.

### C2. Judgment calls / deviations

1. **SH1 also reaches the Survey Responses panel header** (`SurveyResponsesWorkspaceHeader` uses `SurveyStatusChip`/`SurveyKindChip`), not only the Editor header as A8 listed. Shape/size only; labels unchanged there (it still passes `scheduled:`; I1 wording only on the list until steps 5–6 adopt `fromSurvey`).
2. Close and Delete now show a success SnackBar ("Survey closed" / "Survey deleted"); before, only the list reloaded.
3. Menu order is unchanged; Close survey sits in the Lifecycle group with Archive (after a divider), as in B3.
4. Single-row toolbar threshold 1000 px (same as the Directory); whether it triggers at 1366 depends on the real content width — not verified visually.

### C3. Checks actually performed

- `flutter analyze lib/features/admin/surveys test/admin_surveys`: no issues.
- `flutter test test/admin_surveys`: **18 passed** — status wording (Window ended / Scheduled / Published / Draft / Closed / Archived), helpers (rate, window text, identity text), wide vs narrow card layouts, "Not assigned yet", official CHED chip, busy spinner, menu tooltip, no overflow with a long title at 768/1366/1920, disabled menu item with note not selectable.
- Not done: full test suite, live/browser view (UI-first mode). The page's menu composition (`_menuItemsFor`) is private to a Supabase-backed page and is covered by code review only.

---

## D. Responsive review (Phase D — 2026-10-15, UI-first: code-level)

Method: source review of the changed widgets against the breakpoints, one temporary widget-test measurement (file deleted), and a scan of the owner's running `flutter run -d chrome` log. **No browser view or screenshots** (the preview window is the owner's; its log ends with two "Signing out" lines).

| Area | Finding |
|---|---|
| Header | Unchanged `AdminPageHeader`; New survey wraps under the subtitle at narrow widths as before |
| KPI row | `DirectoryKpiRow`: 4-up ≥ `statsFourColMin`, 2/1 columns below; equal heights (`IntrinsicHeight`); captions max 2 lines (same as Directory) |
| Toolbar | Single row when the card's inner width ≥ 1000. Measured in the test font (squares, much wider than real fonts): filters 858 px → search 86 px at 1000, 148 px at 1062 (≈ 1366 viewport), 386 px at 1300; **no overflow**. Real-font search width estimated ≈ 280–350 px at 1366 (estimate only). Below 1000: the existing two-row layout |
| Survey rows | Zones from 960 px card width (1366+ with the sidebar expanded; identity zone ≈ 400–530 px at the threshold/1366); stacked below (1024 with the rail, 768). Title 2 lines + ellipsis + tooltip; window text 2 lines; responses one line. Widget tests: no overflow with a long title at 768/1366/1920 |
| Menu | Max item ≈ 220 px (within the 280 px popup limit); 40 px rows, 52 px with a note |
| Dialogs | Confirm 440 px and Blank survey 480 px max, both scrollable; long titles wrap |
| States | Skeleton switches zones at the same 960 px rule; error view fills the results area; refresh notice is one flexible row |
| Keyboard/focus | Card `InkWell` focusable with semantic label; menu tooltip names the survey; Blank survey autofocuses Title; destructive confirms focus Cancel (0c) |
| Preview log | No "overflowed" / exception entries in the running session's log |

**Findings needing action:** none. **Deferred to the testing phase:** live look at 1920/1600/1440/1366/1024/768, whether the single row triggers at 1366, and the real search-field width.

---

## E. Functional review (Phase E — 2026-10-15, UI-first: code-level)

Method: comparison of the original page (`git show HEAD:…/admin_surveys_page.dart`) with the new one, plus code review. **No live regression, no data written.**

| Area | Result |
|---|---|
| Service calls, menu values, reloads, panel opens | Extracted in order from both versions: **identical sequence**; only addition is the disabled `exports_hint` line (I6, never selectable) |
| Filters / sort / search / KPI formulas | Unchanged except the approved I4 kind split (Custom excludes CHED presets) |
| Menu visibility conditions | Unchanged (export: custom + responses + web; remind/re-assign/close: published and not archived; archive vs restore). Delete disabled when `responseCount > 0` (FX1b) |
| Confirmation outcomes | Each action still runs only when confirmed; Esc/Cancel/outside tap → no action (0c dialog contract) |
| Panel switching | `_openEditor` / `_openResponses` / `_closeEditor` / `_closePanel`, `ValueKey`s and return-to-responses copied unchanged |
| Busy state | All non-navigation actions run inside `_runBusy`; a second start for the same survey is ignored; cleared in `finally` |
| Other users of changed widgets | `SurveyStatusChip` constructor unchanged (Editor and Responses header compile; analyzer clean); no other tests reference the changed widgets; dashboard still mounts `const AdminSurveysScreen()` |

**Fixed during E:** the Blank survey dialog's text controllers were disposed by the page right after the dialog returned, while the dialog could still be animating out (pre-existing pattern; possible "controller used after being disposed" error). The dialog now owns and disposes its controllers and returns the trimmed `(title, description)`; `createSurvey` receives the same values as before.

Checks: `flutter analyze lib/features/admin/surveys test/admin_surveys` — no issues; `flutter test test/admin_surveys` — 18 passed.

**Deferred to the later testing phase (live):** create (CHED and blank), duplicate, archive/restore, re-assign, close, delete (incl. refusal path), remind (incl. skipped counts), CSV/PDF export with the personal-data confirmation, load-error and refresh-error states, busy spinner during real calls, full `flutter test` suite.

---

## F. Completion report (Phase F — 2026-10-15)

**Screen:** Surveys list (menu index 10, list view + New survey flow). **Status:** visually complete for the manuscript (UI-first mode); responsive and functional checks were **code-level only**; live QA and regression **outstanding** (later testing phase). Awaiting owner sign-off.

| Item | Summary |
|---|---|
| Files changed | `surveys/presentation/admin_surveys_page.dart`, `surveys/widgets/admin_survey_ui.dart`, `surveys/widgets/admin_survey_template_picker.dart`; new test `test/admin_surveys/survey_list_card_test.dart` (18) |
| Reused | `AdminKpiCard`, `DirectoryKpiRow`, `DirectoryToolbarCard` (+ `singleRowMinWidth`), `DirectoryFilterField`, `DirectoryToolbarFilterChip`, `DirectoryActiveFilterChip`, `DirectoryEmptyState`, `AdminInstantContent`, `showAdminConfirmDialog`, `showAdminDialogSurface`, `AdminStateView`, `AdminButtonStyles`, `AdminColors`/`AdminSurfaces`, `Skeleton`/`ShimmerScope` |
| Created (feature-local) | `SurveyStatusChip.fromSurvey`, `surveyStatusText`, `surveyWindowText`, `surveyResponseRate`, `surveyIdentityText`, `surveyMenuItem`, `SurveyListSkeleton`, private `_BlankSurveyDialog` |
| UI/UX changes | §C1: "Surveys" title, captioned KPI row, one-row toolbar, zone rows (identity · responses rate · window state · menu), grouped icon menu with red destructive items, white 0c dialogs naming the survey, restyled picker and Blank survey dialog, row-shaped skeleton, error state + refresh notice, token SnackBars |
| Fixes | FX1a–FX7 (§B4) + Blank-dialog controller lifetime (§E) |
| Responsive | Zones ≥ 960 px card width, stacked below; toolbar single row ≥ 1000 px; KPIs 4/2/1 columns (§D) |
| Preserved | All service calls, menu values/conditions (except approved FX1b), reloads, panel switching, filter/sort/search/KPI logic (except approved I4), export file names/contents (§E) |
| Tests performed | `flutter analyze` (surveys + tests): no issues; `flutter test test/admin_surveys`: 18 passed; temporary toolbar measurement (deleted); preview-log scan. **Not run:** full suite, browser view, live actions |
| Approved deviations / open | §C2-1 chip restyle also in the Survey Responses panel header (kept unless owner objects); §C2-2 success SnackBars after Close/Delete |
| Remaining | Live verification list in §E; Audit §9 "catalog refresh listener" note still does not apply (no listener, unchanged) |
