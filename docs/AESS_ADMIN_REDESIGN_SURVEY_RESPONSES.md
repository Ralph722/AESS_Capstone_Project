# Survey Responses (in-page panel of index 10) — Phase A audit · Phase B proposal · Phase C implementation

Date: 2026-10-15. Parent: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §8–§9 (step 6; complexity "Very high"). Builds on the closed [Surveys list](AESS_ADMIN_REDESIGN_SURVEYS.md), [Survey Editor](AESS_ADMIN_REDESIGN_SURVEY_EDITOR.md) and Phase 0 components. Working mode: **UI-first** (progress doc).

Scope: `AdminSurveyResponsesScreen` as opened from the Surveys list ("View responses") — workspace header, Overview / Pending / Submitted tabs, analytics panel, reminders, reminder history, export dialog and the export flows behind it, formal report dialog, response detail and timeline side panels. **Out of scope:** the Editor (closed), Reports & Analytics, the export/report services themselves (`survey_*_export_service.dart`, PDF/XLSX builders), and the alumni-side `ChedGtsForm` rendered inside the detail panel.

Evidence: **code inspection only** (files in A2). No live session (UI-first mode); nothing exported, sent, published or closed.

---

## A1. Purpose and user

After a survey is published, admins come here to see who answered and who hasn't, to read individual responses, to chase non-responders (in-app / email reminders), and to produce files for the office and CHED (responses spreadsheet, management report, CHED outcomes summary, CHED GTS workbook, official fillable PDFs, pending list, single-response PDF/Excel, AI-assisted formal report). They can also publish / close / re-publish and duplicate the survey from the Overview.

## A2. Files

| File | Role | LOC |
|---|---|---:|
| `surveys/presentation/admin_survey_responses_page.dart` | State, load, tabs, Overview left column, Pending and Submitted tables, reminders, reminder history, all export flows, keyboard shortcuts, private row/card widgets | 3,175 |
| `surveys/widgets/admin_survey_analytics_panel.dart` | Overview right pane: batch/course filters, funnel, reminder stats, 30-day trend, audience bars, answer distributions, scale averages, most skipped | 955 |
| `surveys/widgets/admin_survey_export_dialog.dart` | "Download / export" dialog: report list → optional cohort filters → format chips; per-report details pop-up | 1,023 |
| `surveys/widgets/admin_survey_formal_report_dialog.dart` | Generate / edit / copy / print / download a formal report (AI or metric draft) | 373 |
| `surveys/widgets/admin_survey_response_detail_sheet.dart` | One response, by section; side panel (560 px) on wide, bottom sheet otherwise | 559 |
| `surveys/widgets/admin_survey_response_timeline_sheet.dart` | Assigned → reminders → opened → draft → submitted timeline; side panel (480 px) / bottom sheet | 540 |
| `surveys/widgets/admin_survey_ui.dart` (parts) | `SurveyResponsesWorkspaceHeader`, `SurveyWorkspaceSegmentedNav` + `_CountBadge`, `SurveyEmptyState`, `SurveySectionCard`, `SurveyCallout`, status/kind chips | — |
| `shared/widgets/admin/admin_skeletons.dart` (part) | `SurveyResponsesWorkspaceSkeleton.overview()/.list()` | — |
| Shared | `AdminDataTable` / `AdminDataRow` / `AdminTableBadge`, `AdminPaginationBar`, `AdminSearchField`, `DirectoryToolbarFilterChip`, `DirectoryFilterField`, `showAdminOptionPicker`, `showAdminSidePanel`, `showAdminDialogSurface`, `confirmPersonalDataExport` | — |

No widget tests cover this panel (only `adminPageCount` unit tests touch it indirectly).

## A3. Data and sources (must not change)

| Data | Source |
|---|---|
| Load | `markSurveyResponsesSeenByAdmin` (errors ignored) → `getSurvey`, `getQuestions`, `getSurveyParticipants`, `getSurveyResponses`; refresh keeps last data and shows a warning strip |
| Counts | Assigned / completed / pending computed from participants; tab badges use the same lists |
| Analytics | `SurveyReportAnalytics` (participation, audience by program/batch, 30-day trend, reminder stats, aggregates; CHED uses `aggregateChedResponses` with a fixed list of crucial items, capped at 10 cards) — computed client-side, cached by (survey, counts, filters) |
| Publish / close / re-publish | `publishSurvey` (service refuses archived surveys and custom surveys without questions), `closeSurvey`; then reload |
| Duplicate | `duplicateSurvey` → opens the new draft in the Editor |
| Reminders | `sendReminders(surveyId, userIds, inApp, email)` → `SurveyReminderResult` (in-app sent, email sent, skipped no address, **skipped not configured**, failures); email gated client-side by `EmailDeliveryConfig.isConfigured` |
| Reminder history | Assignment `reminderCount` / `lastReminderAt` |
| Exports | CSV / Excel responses, management pack (PDF/XLSX/CSV/print), CHED GTS workbook, CHED outcomes summary, pending list (PDF/XLSX/CSV/print), official fillable ZIP (batch limit 100), selected-pending CSV, single response (PDF/Excel/print); personal-data confirmation before files with personal data; cohort scoping for open-to-all CHED tracers |
| Formal report | `SurveyFormalReportService.generate` (AI if enabled, else metric draft) → editable text → `toPdf` (download or print) |
| Timeline | `getResponseEvents` (errors → empty list) + assignment/response timestamps |

## A4. Interactions (all preserved in any redesign)

- Header: back ("Back to surveys"), title (2 lines), status + kind chips, ⋮ menu (Refresh, Generate formal report, Download / export).
- Tabs: Overview · Pending (count) · Submitted (count). Keyboard: **1 / 2 / 3** and **← / →** switch tabs, **Esc** clears the search.
- Overview left: Quick actions (Publish / Close survey / Re-publish, View survey, Duplicate survey, Download / export, Generate formal report, Reminder history) and Survey information (type, status, created by/date, publish date, last updated, target audience, assigned alumni).
- Overview right: Batch / Course filters + Clear; funnel (not started / in progress / completed + completion %), reminder effectiveness, daily submissions (30 days), by course, by batch, response distribution, rating/scale, most skipped; "More analytics below" cue.
- Pending: search, Status / Course / Batch filter chips, sort, Clear filters, Select page; selection bar (N selected · Send reminder · Send email · Notify in-app · Export selected); table NAME / COURSE / BATCH / STATUS / ASSIGNED / REMINDERS with checkboxes; pagination.
- Submitted: search, sort; table NAME / COURSE / BATCH / SUBMITTED / DURATION / DEVICE / STATUS; row → detail panel; ⋮ View response, Export PDF, Export Excel, Print, View timeline; pagination.
- Export dialog: (1) What do you need? (4–6 reports, ⓘ details) → (2) batch/course (open-to-all CHED only) → (2/3) format chips → Download / Print. Reports needing submissions are disabled with "No submitted responses yet for this report."
- Fillable ZIP: batch-limit dialog when > 100, progress dialog during generation.
- Formal report dialog: Regenerate, Copy, Print, Download PDF; editable body; AI-off notice; disclaimer.
- Detail panel: section chips, "N unanswered in this section" callout, answers; CHED adds the read-only official form for the section; timeline button.
- Timeline panel: recorded / inferred / pending / unavailable steps with device summary.

## A5. Layout today (from code; not viewed live)

Inline header (white) → underline tab bar (44 px tabs, count pills) → tab body.

**Overview ≥ 900 px content width:** Row, left column flex **4** (scrolling: Quick actions card with a wrap of 6 chip-buttons, Survey information card) and right pane flex **6** (analytics: a fixed Filters card, then a scrolling list of ~6–20 cards). At 1366×768 (content ≈ 1,086 px) that is ≈ 420 px / ≈ 640 px. **No KPI row:** the assigned / completed / pending / completion numbers appear only inside the funnel card, below the filters in the right pane (the Overview receives `rate` and `pending` but doesn't show them). **< 900 px:** one ListView — left column, then the analytics pane in a fixed box of max(420, 70 % of height) with its own scroll (nested scrolling).

**Pending / Submitted:** toolbar rows (search + chips + actions), optional selection bar, "Showing X of Y" line, `AdminDataTable`, pagination bar.

## A6. Problems and opportunities

**Functional defects (pre-existing — fixing needs approval):**

1. **Keyboard shortcuts eat typing in the search fields (web).** `CallbackShortcuts` (1/2/3, ←/→) wraps the whole workspace with an autofocus `Focus` (`_withWorkspaceShortcuts`). Flutter's text-field key protections (`DefaultTextEditingShortcuts`, incl. the web disabling map) live at the app root, *above* this widget, so a key typed in `AdminSearchField` reaches these bindings first and is handled. Result: **"1", "2", "3" can't be typed** (typing "2013" in Pending search → "0", then jumps to Overview, then Submitted) and **← / → switch tabs instead of moving the caret**. Verified by reading the SDK source (`C:\flutter\…\default_text_editing_shortcuts.dart`, `_getDisablingShortcut` / `build`); not reproduced live.
2. **Overview Publish / Re-publish bypass every check.** `_overviewPublishToggle` calls `publishSurvey` immediately — no confirmation, no audience count / zero-audience block, no question check (the Editor got all three in FX2/FX6). Re-publish reopens a closed survey and re-assigns alumni with one click. No in-flight guard either (`_isBusyQuickAction` covers only reminders/exports), so a double click can publish twice.
3. **Duplicate** has no in-flight guard — a double click creates two drafts.
4. **Selection crosses filters and pages.** `_selectedUserIds` is only pruned on reload. Reminders go to **all** selected alumni, including ones hidden by the current filter/search/page, while **Export selected** exports only the visible ones — the same "N selected" leads to two different sets, with nothing saying some are hidden.
5. **"Send reminder" silently drops email** when email isn't configured (`email = false` and continues in-app); the result SnackBar never mentions it, and `emailSkippedNotConfigured` from the service is ignored.
6. **Detail panel counts hidden questions as unanswered** (custom surveys). `_unansweredLabelsForActive` and the answer list ignore `visibilityRules`, so a question hidden by a show-when rule shows as "No answer" and in the "N unanswered" callout. (The single-response export service does apply the rules.)
7. **Raw error text** in 14 places: first-load error subtitle (`'$e'`), 7× "Export failed: $e", "Fillable PDF export failed: $e", reminders `'$e'`, publish/close `'$e'` (e.g. "Exception: Add at least one question before publishing"), duplicate `'$e'`; formal report: generation error (red text) and "PDF export failed: $e". (Audit §2 counted 11.)
8. **Formal report loses edits silently.** The body is editable, but **Close (×)** and **Regenerate** replace/discard edited text without a prompt.

**Information / usability:**

9. **No at-a-glance numbers.** Assigned · Submitted · Pending · Completion % are not shown at the top of the Overview (Audit §262 goal: KPI strip with denominators); the funnel sits below the filters in the right pane.
10. Survey information shows the raw enum (`published`, `closed`, `draft`) and raw batch tokens; it ignores "Scheduled" / "Window ended" and has no open/close window row.
11. Quick actions mix a state change (Publish / Close / Re-publish — the primary chip), navigation (View survey), creation (Duplicate) and outputs (export, report, history) in one wrap of look-alike chips; the most-used outputs (export, reminders) duplicate the header ⋮ menu.
12. **DURATION** = submitted − assigned (time until the person answered), not time spent on the form; the label suggests the latter.
13. Daily submissions chart: 30 bars with no dates, axis or hover values.
14. Export dialog (460 px): the report list is capped at 180–220 px, so with CHED (6 reports) part of the list is hidden behind an inner scroll; **ⓘ details is shown only for unselected reports** (the chosen one can't be inspected) and opens a second dialog on top; the "blocked" reason appears below the format chips, far from the disabled report.
15. CHED detail panel shows each section twice (answer blocks, then the full read-only official form).
16. Detail panel header has no course / batch / submitted date / device — those are in the table row the admin just left.
17. Reminder flow: confirmation doesn't say which channel will actually be used (see 5) or how many already got reminders; failures dialog is a plain list.
18. Pending "Select page" + selection bar appear in two different rows; no "Clear selection" in the selection bar.

**Visual / design-system:**

19. Dialogs are default Material `AlertDialog`s (lavender M3 surface): send reminders, reminder failures, close survey, fillable batch limit, fillable progress, formal report shell; not 0c (`showAdminConfirmDialog` / `showAdminDialogSurface`).
20. SnackBars use `Colors.green / red / orange` (≈ 20 places); formal report uses hard-coded `0xFFFFF7ED` / `Colors.red`.
21. `SurveySectionCard`, `SurveyCallout`, `SurveyEmptyState` predate 0c (`AdminText` / `AdminStateView`); the analytics cards use their own 14 px titles; Pending's sort control is a Material `Chip`.
22. Header still uses the old `SurveyStatusChip` constructor → "Scheduled" for a published survey past its close date (Surveys I1 / Editor fix not applied here).
23. Skeletons don't match: Overview skeleton is one column with a 4-tile stat strip (the real page is two panes without one); list skeleton shows profile cards (the real tabs are tables) → layout jump on load.
24. First-load error uses `SurveyEmptyState` + raw text instead of `AdminStateView.error` with details.

**Code health (note only):** one 3,175-line state class; a single `_isExportingChed` flag guards every export kind; legacy overflow values (`csv`, `ched`, `pack_*`) still routed; non-embedded AppBar path kept (white-on-navy app bar).

## A7. Responsive notes (code inspection)

| Width | Expected |
|---|---|
| 1920 | Overview ≈ 720 / 1,080 px; tables comfortable |
| 1366 | Overview ≈ 420 / 640 px; Quick actions wrap to 3 rows; Pending toolbar + selection bar likely wrap to 2 rows each |
| 1024 (rail) | Overview just above 900 → ≈ 380 / 560 px; Pending table 6 columns + checkbox tight |
| 768 | Overview single column with nested analytics scroll; tables stay tables (`_PendingAlumniCard` / `_SubmittedResponseCard` are the table rows, not a card fallback — corrected in §D) |

Export dialog maxHeight 560 / 640; formal report 820 × 90 % height. Not verified live (UI-first).

## A8. Shared-component dependencies and risks

| Component | Other users | Risk if changed |
|---|---|---|
| `SurveySectionCard` | Responses page (2), analytics panel (1) — no other users (`rg`) | Safe to restyle for Responses |
| `SurveyCallout` | Detail panel (1) **and Survey Editor (2, closed screen)** | Restyle changes the signed-off Editor → approval, or Responses-local styling |
| `SurveyResponsesWorkspaceHeader`, `SurveyWorkspaceSegmentedNav`, `SurveyEmptyState` | Responses only (`rg`) | Safe to restyle |
| `SurveyResponsesWorkspaceSkeleton` (`admin_skeletons.dart`) | Responses only; the `AdminSurveyResponsesSkeleton` wrapper has no callers | Shared file — a new local skeleton is safer |
| `AdminDataTable` / `AdminDataRow` / `AdminTableBadge` | Directory, Activity Logs | Do not change; use as is |
| `AdminPaginationBar`, `AdminSearchField`, `DirectoryToolbarFilterChip`, `DirectoryFilterField`, `showAdminOptionPicker`, `showAdminSidePanel` | Many admin screens | Use as is |
| `ChedGtsForm` (inside detail panel) | **Alumni app** | Do not edit |
| `SurveyService`, `SurveyReportAnalytics`, export/report services, `confirmPersonalDataExport` | Many | Do not change |

Other risks: export routing (`_runSurveyExport` + legacy menu values), cohort scoping for open-to-all CHED tracers, the fillable ZIP batch-limit flow, `markSurveyResponsesSeenByAdmin` on open (feeds the list's "new responses" state), and the analytics cache key must stay intact. The panel is a very large single file; any layout work should avoid moving export logic.

## A9. Decisions needed before Phase B

1. **Sub-phases (Audit §8):** propose all of B at once but implement C in sub-phases with a stop after each — R1 shell + Overview, R2 Pending (+ reminders), R3 Submitted (+ detail / timeline panels), R4 export dialog + formal report — or one C pass?
2. **Functional fixes 1–8** into the proposal, each separately approvable?
3. **Overview publish (item 2):** reuse the Editor's checks (confirm with audience count, block zero audience, block question problems) here; or remove Publish / Re-publish from the Overview and send the admin to the Editor; or confirmation only?
4. **Keyboard shortcuts (item 1):** keep them but ignore keys while a text field has focus (recommended), move them to modifier keys (e.g. Alt+1/2/3), or remove them?
5. **Selection (item 4):** clear the selection when filters/search change; or keep it but show "N selected (M hidden by filters)" and act on the same set everywhere?
6. **Overview layout (items 9–11):** add a KPI strip (Assigned · Submitted · Pending · Completion %) above both panes and regroup Quick actions (state change vs outputs) — allowed?
7. **Shared pieces:** restyle `SurveySectionCard`, `SurveyEmptyState`, workspace header and tab bar in place (Responses-only per `rg`); `SurveyCallout` is also in the closed Editor — restyle globally (Editor changes slightly) or style the detail panel's callout locally? Local skeleton instead of editing `admin_skeletons.dart`?
8. **Dialogs (item 19):** move reminder / close / fillable / failures dialogs to 0c; keep the export dialog's two-step structure and only fix items 14 (list height, details for the selected report, blocked reason placement)?
9. **CHED detail duplication (item 15):** keep both views, show the official form behind a toggle, or keep answers only?

**Owner answers (2026-10-15):** Phase A **approved**; Phase B authorized. (1) One proposal; C in **4 sub-phases** with a stop after each (R1 Overview → R2 Pending → R3 Submitted + panels → R4 export / report dialogs). (2) **All** functional fixes go into the proposal, each separately approvable. (3) Keep Overview Publish / Re-publish and add the Editor's checks (confirmation with audience count, block zero audience, block question problems). (4) Keep the shortcuts but **ignore them while a text field has focus**. (5) **Clear the selection** when filters or search change. (6) **Add the KPI row** and regroup Quick actions. (7) `SurveyCallout`: **Responses-local styling**, Editor untouched. (8) Not asked separately — covered by (2) and the proposal. (9) CHED detail: answers by default, official form **behind a toggle**.

---

## B. Redesign proposal (Phase B — no production code changed)

Builds on the signed-off patterns: 0c dialogs (`showAdminConfirmDialog`, `showAdminDialogSurface`), `AdminStateView`, `AdminButtonStyles`, `AdminText` / `AdminColors` tokens, `DirectoryKpiRow` + `AdminKpiCard` (as on the Surveys list), `SurveyStatusChip.fromSurvey`, `surveyStatusText`, `surveyWindowText`, `surveyFriendlyError`, and the Editor's `surveyPublishProblems`. **No shared component used by another screen changes** (`SurveyCallout`, `admin_skeletons.dart`, `AdminDataTable`, pagination, search field, filter chips, side panel all used as-is). No `SurveyService`, analytics, export-service, model, schema or route changes.

Implementation is split into **four sub-phases with a stop after each** (owner answer 1). Each sub-phase lists its own base and items; FX/I numbers are global.

### B1. Overview layout (1366×768, sidebar expanded, content ≈ 1,086 px)

```
┌ ← Alumni Tracer 2026 – Wave 2   [Window ended] [CHED GTS]                               ⋮ ┐
│   Aug 7 – Aug 14, 2026                                                                     │
├ Overview │ Pending 41 │ Submitted 12 ─────────────────────────────────────────────────────┤
│ ┌ Assigned ──┐ ┌ Submitted ─┐ ┌ Pending ───┐ ┌ Completion ┐                               │
│ │ 53         │ │ 12         │ │ 41         │ │ 23 %       │                               │
│ │ alumni     │ │ of 53      │ │ not yet    │ │ 12 of 53   │                               │
│ └────────────┘ └────────────┘ └────────────┘ └────────────┘                               │
│ ┌ Survey ─────────────────────────┐ ┌ Analytics · filters apply to the charts below ─────┐ │
│ │ [■ Close survey              ]  │ │ [Batch: All ▾] [Course: All ▾]            Clear    │ │
│ │ [✎ Edit survey] [⧉ Duplicate ]  │ ├────────────────────────────────────────────────────┤ │
│ │─────────────────────────────────│ │ Participation funnel                               │ │
│ │ Outputs                         │ │ Not started ████░░░░ 30                            │ │
│ │ ⬇ Download / export          ›  │ │ In progress ██░░░░░░ 11                            │ │
│ │ ✦ Generate formal report     ›  │ │ Completed   ███░░░░░ 12                            │ │
│ │ ⟲ Reminder history           ›  │ │ Daily submissions (30 days)                        │ │
│ │─────────────────────────────────│ │ ▁▁▃▁▁▅▁▁▁▂ …                                      │ │
│ │ Details                         │ │ Sep 15                               Oct 14        │ │
│ │ Type        Official CHED GTS   │ │ …                                                  │ │
│ │ Status      Window ended        │ │                                                    │ │
│ │ Window      Aug 7 – Aug 14      │ │                                                    │ │
│ │ Audience    BSIT · 2020–2023    │ │                                                    │ │
│ │ …                               │ │                                                    │ │
│ └─────────────────────────────────┘ └────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

KPI row: four dense `AdminKpiCard`s in `DirectoryKpiRow` (whole survey, not filtered); **Pending** and **Submitted** cards switch to their tabs on tap. Panes keep flex 4 / 6 (≈ 420 / ≈ 640 px). The left column becomes one card with three groups (state actions · outputs · details) instead of two cards and a chip wrap. Below 900 px: KPI row (2×2), then the left card, then analytics (unchanged fixed-height box).

### B2. CURRENT → PROPOSED, by sub-phase

**R1 — Shell + Overview**

| Data | Current | Proposed |
|---|---|---|
| Header chips | `SurveyStatusChip(status, archived, scheduled)` → "Scheduled" after close | `SurveyStatusChip.fromSurvey` → "Window ended" (I1); window text line under the chips (`surveyWindowText`, "No window set") (I2) |
| Header ⋮ menu, back | As listed in A4 | Unchanged |
| Tab bar | `SurveyWorkspaceSegmentedNav` | Same widget; `AdminText` label styles only |
| Counts | Only inside the funnel card | KPI row (I3) |
| Quick actions | `SurveySectionCard` + wrap of 6 chips | One left card: **state button** full-width (Publish / Close survey / Re-publish, `AdminButtonStyles.filled`; Close uses outlined) · **Edit survey** + **Duplicate** (outlined, side by side) · divider · **Outputs** list rows (icon · label · chevron): Download / export, Generate formal report, Reminder history (I4) |
| Survey information | Raw `status.name`, raw batch tokens, no window | Same rows in the same card ("Details" group): Status = `surveyStatusText`; new **Window** row; Audience uses `formatBatchYearsForDisplay` + course list (I5) |
| Analytics pane | `SurveySectionCard` "Filters" + `_AnalyticsCard`s (14 px titles) | `SurveySectionCard` restyled (Responses-only: `AdminText.sectionTitle`, `AdminSurfaces.radiusMd`, border, no shadow); Filters card caption "Filters apply to the charts below"; analytics cards use `AdminText.cardTitle` |
| Daily submissions | 30 unlabeled bars | First / last date under the chart; `Tooltip` per bar ("Oct 3 · 2 submissions") (I6) |
| Publish / Close / Re-publish | No checks, `AlertDialog` for Close | FX2 (below) + 0c confirmations |
| Loading | Shared `SurveyResponsesWorkspaceSkeleton` (stat strip + stacked cards / profile cards) | Responses-local skeletons in `admin_survey_ui.dart`: KPI row + two panes; table-row list for Pending / Submitted (V2). `admin_skeletons.dart` untouched |
| First-load error | `SurveyEmptyState` with raw `'$e'` | `AdminStateView.error` ("Couldn't load responses", friendly message, raw text under Details, Try again); offline wording kept (FX7) |
| SnackBars | `Colors.green/red/orange` | `AdminColors.success/danger/warning` (V1) |

**R2 — Pending (+ reminders)**

| Data | Current | Proposed |
|---|---|---|
| Toolbar | Search · Status/Course/Batch chips · Material `Chip` sort · Clear filters · Select page (wraps) | Same controls; sort becomes the same toolbar-chip look as the filters (`DirectoryToolbarFilterChip` + picker); one row at ≥ 1,050 px, wraps below |
| Selection bar | "N selected" + 4 actions; appears in a second row | Same bar (info tint) with **Clear selection**; "Select page" stays in the toolbar |
| Selection scope | Survives filter/search changes | Cleared on filter or search change (FX4); kept across pages and sort changes, so reminders and Export selected act on the same set |
| Send reminders confirm | `AlertDialog` "Send in-app + email reminders to N pending alumni?" | `showAdminConfirmDialog` naming the survey and the channels **actually used**; when email isn't configured: "Email isn't set up, so these will be sent in-app only." (FX5) |
| Result | "Sent: X in-app, Y email, Z skipped (no email)" | Adds "email skipped (not set up)" from `emailSkippedNotConfigured` (FX5); tone tokens |
| Failures | `AlertDialog` text list | `showAdminDialogSurface` list "N reminders failed" with OK |
| Table / cards / pagination | `AdminDataTable`, `_PendingAlumniCard`, `AdminPaginationBar` | Unchanged components; badge colours via `AdminTableBadge` as today |
| Empty states | `SurveyEmptyState` | `SurveyEmptyState` restyled (Responses-only) with `AdminText` |

**R3 — Submitted + detail / timeline panels**

| Data | Current | Proposed |
|---|---|---|
| DURATION column | submitted − assigned, labelled "DURATION" | Header **TIME TO SUBMIT**, tooltip "Time from assignment to submission" (I7); values unchanged |
| Toolbar / table / ⋮ menu | As A4 | Same; sort chip as in R2 |
| Detail panel header | Name + "Response details" | Name + meta line "BSIT · Batch 2020 · Submitted Oct 3, 2026 · Desktop" (I8; optional `subtitle` parameter on this Responses-only sheet) |
| Unanswered callout | `SurveyCallout` (shared with Editor) | Responses-local compact warning strip (12–13 px, `warningBg`, "N unanswered" + expandable list); `SurveyCallout` untouched (owner answer 7) |
| Hidden questions | Counted as unanswered | Custom surveys: filter by `ClassicSurveyVisibility.visibleQuestions(questions, answers, survey.visibilityRules)` — same rule as the alumni form and the single-response export (FX6) |
| CHED official form | Always shown after the answers | Behind **Show official form** / **Hide official form** per section (I9; owner answer 9) |
| Timeline panel | Own header styles | `AdminText` header; content unchanged |

**R4 — Export dialog, formal report, fillable dialogs**

| Data | Current | Proposed |
|---|---|---|
| Export dialog | 460 px; list capped at 180–220 px; ⓘ only on unselected rows; blocked text under formats | 520 px; whole dialog body scrolls (no inner list cap); ⓘ on every row; reports that need submissions show "Needs submitted responses" in the row and stay selectable for details but Download stays disabled (I10); steps keep numbering; `AdminText` |
| Report details | Second dialog on top (wide) / bottom sheet | Unchanged mechanism, `AdminText` styles |
| Fillable batch limit | `AlertDialog` | `showAdminConfirmDialog` (same text) |
| Fillable progress | `AlertDialog` (non-dismissible) | `showAdminDialogSurface` (non-dismissible), same text and progress |
| Formal report | `Dialog` with raw error, hard-coded colours; Close/Regenerate discard edits | Same 820 px dialog; header `AdminText`; AI-off notice on `warningBg`; generation error → `AdminStateView.error` with Try again; **confirm before Close / Regenerate when the text was edited** (FX8); friendly PDF error |
| Export errors | "Export failed: $e" ×7, fillable `$e` | Friendly text with context ("Couldn't create the pending list PDF. ‹reason›") (FX7) |

### B3. Approvable items

**Base per sub-phase (one approval each, given at the start of that sub-phase):** the CURRENT → PROPOSED rows above that have no FX/I number, plus V1 (SnackBar tokens) and V2 (local skeletons, R1) / V3 (0c dialogs in that sub-phase).

**Functional fixes (A6 1–8), each separately approvable:**

| ID | Sub-phase | Fix | Behaviour change |
|---|---|---|---|
| FX1 | R1 | **Shortcuts ignore typing:** 1/2/3 and ←/→ do nothing while a text field has focus (check the primary focus for an `EditableText` and let the key through); Esc still clears the search | Search fields accept 1/2/3 and caret keys |
| FX2 | R1 | **Overview Publish / Re-publish checks** (draft and closed): (a) custom/preset: `surveyPublishProblems(questions)` → "Fix before publishing" dialog listing problems with **Open in editor**; (b) `countAudience(survey.targetPrograms, expandBatchYearTargets(survey.targetBatchYears))` with a spinner on the button — when a course/batch filter matches 0 alumni, stop with "No alumni match … Open the editor to adjust the audience."; (c) `showAdminConfirmDialog` — Publish: same message as the Editor ("About N alumni match … They will be assigned and notified."); Re-publish: "Re-open this survey for about N matching alumni? Existing submissions are kept." **Close:** 0c confirmation, same text. Busy flag: state button, Duplicate and Edit disabled while running (no double publish) | Publish/Re-publish need confirmation and can be blocked |
| FX3 | R1 | **Duplicate** in-flight guard + spinner | No double drafts |
| FX4 | R2 | **Selection cleared** when filters or search change | Selection no longer survives filtering |
| FX5 | R2 | **Email not set up** stated in the reminder confirmation and result; `emailSkippedNotConfigured` shown | Text only (sending unchanged) |
| FX6 | R3 | **Detail panel respects visibility rules** (custom surveys): hidden questions are not listed and not counted as unanswered | Display only |
| FX7 | R1–R4 | **Friendly errors** in the 14 raw places (`surveyFriendlyError` + context; first-load error with Details) | Text only |
| FX8 | R4 | **Formal report:** confirm "Discard your edits?" before Close or Regenerate when the text differs from the generated draft | New prompt |

**Information items, each separately approvable:**

| ID | Sub-phase | Item |
|---|---|---|
| I1 | R1 | Header status chip `fromSurvey` ("Window ended") |
| I2 | R1 | Window text under the header chips |
| I3 | R1 | KPI row: Assigned · Submitted (of N) · Pending · Completion % (submitted ÷ assigned, "—" when nobody is assigned); Pending/Submitted cards open their tabs |
| I4 | R1 | Left card regrouped (state · edit/duplicate · outputs · details); "View survey" renamed **Edit survey** (it opens the Editor) |
| I5 | R1 | Details: friendly status, Window row, formatted audience |
| I6 | R1 | Trend chart: start/end dates + per-bar tooltip |
| I7 | R3 | "TIME TO SUBMIT" header + tooltip |
| I8 | R3 | Detail panel meta line |
| I9 | R3 | CHED official form behind a toggle |
| I10 | R4 | Export dialog: wider, single scroll, ⓘ on every row, "Needs submitted responses" inside the row |

### B4. Responsive behaviour

| Width (content) | Behaviour |
|---|---|
| 1920 (≈ 1,640) | KPI row one line; Overview ≈ 650 / 975 px; Pending toolbar one row |
| 1366 (≈ 1,086) | KPI row one line (4 × ≈ 255 px); Overview ≈ 420 / 640 px; left card buttons one per row / two side by side; Pending toolbar may wrap to 2 rows (as today) |
| 1024 rail (≈ 950) | KPI row one line (dense); Overview just above 900 → ≈ 375 / 560 px |
| < 900 / 768 | KPI 2×2; single column (left card, then analytics in its fixed box); tables use the existing row cards; export dialog full-width with 16 px inset |

### B5. Unchanged

All service calls and their order (load sequence incl. `markSurveyResponsesSeenByAdmin`, reminders, publish/close/duplicate, exports, formal report, timeline events); export routing (`_runSurveyExport`, legacy menu values), cohort scoping, the fillable ZIP batch limit (100) and progress flow; personal-data confirmations; analytics calculations, filters, caching and the CHED crucial-item list; table columns other than the DURATION header; pagination; tab order, counts and shortcuts' keys; header ⋮ menu; reminder history panel; panel switching and back target.

### B6. Risks

- FX2 adds a read-only `countAudience` call and can block a publish that works today; stored batch tokens must be expanded (`expandBatchYearTargets`) exactly as the Editor does, or counts differ.
- FX1 must not break Esc-to-clear or tab shortcuts when focus is on the page (not a field).
- FX4 changes how bulk selection behaves for admins used to filtering while selecting.
- The analytics cache key and the `TabController` listener must stay intact; KPI cards read the same lists as the tab badges (no new queries).
- The responses page is 3,175 lines; edits stay local to the touched sections — no file split in this step.

### B7. Phase C/D/E plan (UI-first mode)

- **C in four sub-phases** (R1 → R2 → R3 → R4), each followed by a stop for review. Files: `admin_survey_responses_page.dart`, `admin_survey_analytics_panel.dart` (styles + trend labels), `admin_survey_response_detail_sheet.dart`, `admin_survey_response_timeline_sheet.dart` (header styles), `admin_survey_export_dialog.dart`, `admin_survey_formal_report_dialog.dart`, and Responses-only widgets in `admin_survey_ui.dart` (`SurveyResponsesWorkspaceHeader`, `SurveyWorkspaceSegmentedNav`, `SurveySectionCard`, `SurveyEmptyState`, new local skeletons). Checks per sub-phase: `flutter analyze` on the surveys feature + `flutter test test/admin_surveys`; a small widget/unit test file grows per sub-phase (shortcut-while-typing, publish checks, selection clearing, visibility filtering, report discard prompt).
- **D / E:** code-level after R4 (live checks deferred to the testing phase; no live writes).

**2026-10-15:** Phase B **approved in full** (base, FX1–FX8, I1–I10). Phase C authorized for **sub-phase R1 only** (stop for review afterwards).

---

## C. Implementation (Phase C)

### C1. Sub-phase R1 — shell + Overview (2026-10-15)

**Implemented:**

| Item | Where | What |
|---|---|---|
| I1, I2 | `SurveyResponsesWorkspaceHeader` | `SurveyStatusChip.fromSurvey` ("Window ended" / "Scheduled"), window text (`surveyWindowText`, "No window set") after the chips |
| Base | `SurveyWorkspaceSegmentedNav` | Tab labels use `AdminText.body` (13 px; w700 selected / w500) |
| Base | `SurveySectionCard` (Responses-only per `rg`) | Title `AdminText.sectionTitle`, subtitle `AdminText.caption`; card surface unchanged (already `AdminSurfaces.card`) |
| I3 | Overview | `DirectoryKpiRow` of four dense `AdminKpiCard`s: Assigned · Submitted ("of N assigned", opens Submitted) · Pending (opens Pending) · Completion ("—" / "Nobody assigned yet" when 0 assigned). Same lists as the tab badges; no new queries |
| I4 | Overview left card | One `AdminSurfaces.card` with `SurveyEditorSection` groups: **Survey** (full-width state button — Publish / Re-publish filled, Close survey outlined — then Edit survey · Duplicate), **Outputs** (rows: Download / export, Generate formal report, Reminder history), **Details**. "View survey" → **Edit survey** |
| I5 | Details | Status `surveyStatusText`; new **Window** row; audience batches via `expandBatchYearTargets` → `formatBatchYearsForDisplay` |
| I6 | Analytics trend | Tooltip per bar ("Oct 3 · 2 submissions"), first/last date under the chart |
| Base | Analytics panel | Filters subtitle "Filters apply to the charts below"; card titles `AdminText.cardTitle` (w700); section titles `AdminText.sectionTitle` |
| FX1 | New `SurveyWorkspaceShortcuts` (in `admin_survey_ui.dart`) | Same keys (1/2/3, ←/→, Esc; no modifiers); tab keys return *ignored* while the primary focus is inside an `EditableText`, so they reach the field. Esc unchanged (clears search) |
| FX2 | `_overviewPublish` / `_overviewClose` | Publish & Re-publish: question problems (`surveyPublishProblems`, custom/preset) → "Fix before publishing" dialog with **Open in editor**; `countAudience(targetPrograms, expandBatchYearTargets(targetBatchYears))` with "Checking audience…" on the button; zero audience with filters → stop with a danger SnackBar; `showAdminConfirmDialog` (Publish: Editor's wording; Re-publish: "… The survey reopens for them. Existing submissions are kept."); "Publishing…" / "Re-publishing…" spinner. Close: `showAdminConfirmDialog`, same text, "Closing…" spinner. State button, Edit and Duplicate disabled while any step runs |
| FX3 | `_overviewDuplicate` | In-flight guard, "Duplicating…" spinner |
| FX7 (R1 part) | Load, publish, close, duplicate | First-load error → `AdminStateView.error` (friendly message, raw text under Show details, Try again; offline wording kept). Publish/close/duplicate errors via `surveyFriendlyError` with fallbacks |
| V1 (R1 part) | Overview SnackBars | `AdminColors.success` / `danger` |
| V2 | New `SurveyResponsesSkeleton.overview()/.table()` | KPI row + two panes; toolbar + table rows. Shared `SurveyResponsesWorkspaceSkeleton` no longer used here (file untouched) |

**Judgment calls:**
- The Overview left column keeps its own scroll (wide) and sits in the page ListView (narrow); the card sizes to its content instead of stretching to the pane height.
- "Assigned alumni" stays in Details (proposal: same rows) although the KPI row shows it too.
- Close-survey success SnackBar now uses the success token (was untinted).
- The "Fix before publishing" dialog is a Responses copy of the Editor's private dialog (only the action differs: Open in editor instead of Go to question) — the Editor file is not touched.
- Shortcut logic moved into a small widget so it can be tested without Supabase.

**Not in R1 (later sub-phases, unchanged now):** Pending/Submitted tabs, reminders, `SurveyEmptyState`, export / fillable / formal-report dialogs and their SnackBars and raw errors.

**Checks actually performed:** `flutter analyze lib/features/admin/surveys test/admin_surveys` — no issues. `flutter test test/admin_surveys` — 44 passed (8 new in `survey_responses_widgets_test.dart`: shortcuts select tabs without a focused field; digits/arrows don't switch tabs while a `TextField` has focus, Esc still works; header "Window ended" + window text at 768/1366 without overflow; "No window set"; skeletons at 768/1024/1366 — the first run found a 2 px overflow in the KPI skeleton, fixed). The Overview page itself was not rendered in a test (its service needs Supabase); not viewed live; full suite not run.

### C2. Sub-phase R2 — Pending + reminders (2026-10-15)

**Implemented:**

| Item | Where | What |
|---|---|---|
| Base | Pending toolbar | Sort is now a `DirectoryToolbarFilterChip` ("Sort: …") opening `showAdminOptionPicker`, matching the Status / Course / Batch chips (Material `Chip` removed). Sort options and ordering unchanged |
| Base | Selection bar | **Clear selection** button after "N selected"; count text uses `AdminText.body` (w700, primary). "Select page" stays in the toolbar. Info tint, actions and their order unchanged |
| FX4 | Search, filter pickers, Clear filters, empty-state "Clear search & filters", Esc | Selection cleared when the search text changes (debounced), when a Status / Course / Batch picker **changes** value, on Clear filters, and on the empty-state clear. Esc clears it only when the Pending search had text. Kept across pages and sort changes |
| FX5 | `_sendReminders` | Email channel dropped up front when `EmailDeliveryConfig` isn't configured. **Send email** alone then stops with a warning SnackBar before any confirm (nothing sent). Otherwise `showAdminConfirmDialog` "Send reminders?" naming the survey, the channels actually used and the count, plus "Email isn't set up, so these will be sent in-app only." when dropped. Result adds "N email skipped (not set up)" from `emailSkippedNotConfigured`; "· email isn't set up" appended when dropped. `sendReminders` call and arguments otherwise unchanged |
| FX5 | Failures | `showAdminDialogSurface` (max 480 px) with a warning header "N reminders failed", a bordered scrolling list (max 260 px) and OK — replaces the `AlertDialog` |
| FX7 (R2 part) | Reminders | Errors via `surveyFriendlyError(e, 'Couldn't send reminders. Try again.')` |
| V1 (R2 part) | Reminder and Export-selected SnackBars | `AdminColors.success` (all sent), `warning` (failures or email dropped), `danger` (error) |
| Base | `SurveyEmptyState` (Responses-only per `rg`) | Title `AdminText.sectionTitle`, subtitle `AdminText.caption` (line height 1.4) |
| Base | "Showing X of Y pending" | `AdminText.caption` |

**Judgment calls:**
- Pickers clear the selection only when the value actually changes, so reopening a picker and keeping the same value doesn't drop the selection.
- Esc clears the selection only if it also cleared Pending search text; otherwise Esc does nothing to the selection.
- "Send email" with email not set up warns and stops before the confirmation (the old flow sent nothing either, silently).
- Reminder wording moved into two top-level `@visibleForTesting` functions (`surveyReminderConfirmMessage`, `surveyReminderSummary`) in the page file so it can be tested without Supabase.
- The proposal's "one toolbar row at ≥ 1,050 px" was not done: the toolbar keeps search above a wrapping chip row (no layout change in R2).

**Not in R2 (later sub-phases, unchanged now):** Submitted tab, detail / timeline panels, export / fillable / formal-report dialogs, and the remaining `Colors.green/red` export SnackBars and raw `Export failed: $e` messages (R4).

**Checks actually performed:** `flutter analyze lib/features/admin/surveys test/admin_surveys` — no issues. `flutter test test/admin_surveys` — 50 passed (6 new in `survey_responses_widgets_test.dart`: confirm text with survey title and both channels; dropped-email confirm with "this survey" and singular "alumnus"; result with no-address and not-configured skips; dropped-email result and "No reminders sent"; `SurveyEmptyState` with action at 360 and 768 px without overflow). Selection clearing and the Pending tab itself were not rendered in a test (the page needs Supabase); not viewed live; full suite not run; no reminders sent.

### C3. Sub-phase R3 — Submitted + detail / timeline panels (2026-10-15)

**Implemented:**

| Item | Where | What |
|---|---|---|
| I7 | Submitted table | Header **TIME TO SUBMIT** (column 90 → 116 px so the label fits at 11 px). Tooltip "Time from assignment to submission" on each value cell — `AdminDataColumn` (shared) has no tooltip, so the header itself has none. Values unchanged |
| Base | Submitted toolbar | Sort is a `DirectoryToolbarFilterChip` ("Sort: …") opening `showAdminOptionPicker` (as Pending; `PopupMenuButton` + Material `Chip` removed). "Showing X of Y" uses `AdminText.caption` |
| I8 | Detail panel header | New optional `subtitle` on `showAdminSurveyResponseDetailSheet` (Responses-only per `rg`): "BSIT · Batch 2020 · Submitted Oct 3, 2026 · Desktop · Windows · Chrome" from the new `surveyResponseMetaLine` (page file, `@visibleForTesting`). Missing course/batch are skipped; device omitted when not recorded; no submitted time → "Last saved …". Name and meta line on `AdminText` (name 16 px, one line; meta up to 2 lines) |
| FX6 | Detail panel (custom surveys) | New `visibilityRules` parameter (page passes `_survey.visibilityRules`). Answer list and unanswered count use `ClassicSurveyVisibility.visibleQuestions` — same helper as the single-response export. A section whose questions were all hidden says "No questions in this section were shown to this alumnus." Section chips still come from all questions. CHED path unchanged (already used `ChedGtsVisibility`) |
| Base | Unanswered callout | Responses-local `_UnansweredStrip`: `warningBg`, 8 px radius, "N unanswered in this section" + Show/Hide; expanded list shows every prompt (old callout capped at 6). `SurveyCallout` untouched |
| I9 | CHED detail | Official form behind **Show official form** / **Hide official form** under the answers; hidden by default; the choice stays as the admin switches sections |
| Base | Detail panel text | Section title `AdminText.sectionTitle`; "All visible items…" `AdminText.caption` in success colour |
| Base | Timeline panel | Header `AdminText` (title 16 px, name caption one line), intro caption on `AdminText.caption`. Events, loading and the service call unchanged |

**Judgment calls:**
- TIME TO SUBMIT tooltip on the cells rather than the header, to avoid changing the shared `AdminDataColumn`.
- The official-form toggle keeps its state across sections (an admin comparing sections doesn't have to reopen it each time).
- The meta line shows the full device summary (category · platform · browser) rather than only the category.

**Not in R3 (R4, unchanged now):** single-response "Export failed: $e" SnackBar on the Submitted ⋮ menu, export / fillable / formal-report dialogs and their messages.

**Checks actually performed:** `flutter analyze lib/features/admin/surveys test/admin_surveys` — no issues. `flutter test test/admin_surveys` — 56 passed (6 new in `survey_responses_widgets_test.dart`: meta line full and minimal; custom-survey detail at 768 and 1366 (both side panel — ≥ 700 px is wide; "768 bottom sheet" corrected in §D) — hidden question not listed or counted, strip expands to the visible unanswered prompt, no overflow; question shown and counted when its rule matches; CHED official form absent until **Show official form**, then rendered without exceptions). The first CHED test run tapped an off-screen button (test issue, fixed with `ensureVisible`). The Submitted tab itself and the timeline panel were not rendered in tests (both need Supabase); not viewed live; full suite not run.

### C4. Sub-phase R4 — export dialog, formal report, fillable dialogs (2026-10-15)

**Implemented:**

| Item | Where | What |
|---|---|---|
| I10 | `admin_survey_export_dialog.dart` (Responses-only per `rg`) | Width 460 → **520**; max height 560/640 → 680/760 (cohort). The whole body scrolls in one `SingleChildScrollView` (inner 180–220 px list cap removed); Cancel / Download pinned under a divider. Report rows are a new `_ReportRow`: **ⓘ Details on every row** (selected rows show the check *and* ⓘ); reports that need submissions show "Needs submitted responses" (warning, with icon) **inside the row** when there are none, stay selectable, Download stays disabled (same `_canContinue` rule). The note under the format chips stays, reworded "This report needs at least one submitted response." Step numbering, report list, formats, cohort filters and the returned `SurveyExportChoice` unchanged |
| Base | Export dialog text | Title, step labels, hints, row text and the report-details panel/cards on `AdminText` / `AdminColors`. Details still open as a second dialog (wide) or bottom sheet (narrow) — mechanism unchanged |
| V3 | Fillable batch limit | `showAdminConfirmDialog` ("Batch limit", same message, Continue / Cancel) instead of `AlertDialog` |
| V3 | Fillable progress | `showAdminDialogSurface` (420 px, `barrierDismissible: false`, `PopScope(canPop: false)` so Esc can't close it) with `AdminText` title, progress bar, "done / total", current name. Closed the same way as before (`rootNavigator` pop) |
| FX8 | Formal report | Edits tracked against the generated text. **Close (×), Esc and Regenerate** ask "Discard your edits?" (Keep editing / Discard or Regenerate, destructive) when the text was changed; no prompt otherwise. Esc goes through `PopScope` |
| Base | Formal report | Header on `AdminText`; AI-off notice on `AdminColors.warningBg` (hard-coded `0xFFFFF7ED` / `0xFFFED7AA` removed); disclaimer `AdminText.caption` italic; generation error → `AdminStateView.error` ("Couldn't write the report", friendly message, raw text under Show details, Try again); copy / download SnackBars success colour; PDF error "Couldn't create the report PDF. ‹reason›" (danger) |
| FX7 (R4 part) | 8 export catches in the page | New `surveyExportErrorMessage(what, error)` (page file, `@visibleForTesting`): "Couldn't create ‹the pending list›. ‹reason›" when `surveyFriendlyError` finds a readable reason, else "… Try again."; programming errors (`Error`, e.g. `StateError`) always get "Try again." Used for responses CSV, responses Excel, management report, CHED GTS Excel pack, CHED outcomes summary, pending list, single response file (Submitted ⋮), fillable CHED PDFs |
| V1 (R4 part) | Export SnackBars | All via `_showSnack` with `AdminColors.success` / `danger`. Fillable ZIP with skipped forms → **warning** (was green) |

**Judgment calls:**
- The blocked note under the format chips is kept (reworded) in addition to the in-row note, so the reason sits next to the disabled Download too.
- Dialog max height raised because the list no longer has its own scroll; smaller windows still cap at the screen via the dialog insets.
- The formal-report dialog's service is now created lazily, and a `@visibleForTesting` `surveyFormalReportDialogForTest` passes a stand-in draft generator, so the discard prompt can be tested without the AI service. Production path unchanged.
- Partial fillable ZIP success uses the warning colour.
- `dart format` was run on the two dialog files; besides the changes above it re-wrapped some existing lines (layout only, no code change).

**Raw error text after R4:** `rg` over the Responses files finds no remaining `'$e'` / "failed: $e" user messages; the only `'$e'` left is the first-load error, which R1 shows under **Show details** in `AdminStateView`.

**Checks actually performed:** `flutter analyze lib/features/admin/surveys test/admin_surveys` — no issues. `flutter test test/admin_surveys` — 66 passed (10 new in `survey_responses_dialogs_test.dart`: error text keeps a readable reason / hides `StateError` and technical text; export dialog at 768 and 1366 — 6 Details buttons, 4 "Needs submitted responses", Download disabled until Pending list is chosen, no overflow; Details opens for the selected report; cohort filters at 768; formal report closes without a prompt when unedited, asks with edits (Keep editing keeps the text, Discard closes), asks before Regenerate and restores the draft, generation error shows Try again and recovers). Exports themselves, the fillable ZIP flow and the AI service were not run (need Supabase / web download); not viewed live; full suite not run.

## D. Responsive review (Phase D — code level, 2026-10-15)

**Method.** UI-first mode: code reading of the panel's layout branches, plus a temporary widget test that rendered one Pending and one Submitted table row (the page's column specs, long name/course) at several widths and recorded overflows. That test was deleted after use; permanent tests for both tables replaced it (below). The running app's debug log was scanned: only the 4 older overflow lines with no Responses widget in their trace. No browser viewing, no screenshots, no Supabase-backed rendering of the panel.

**Widths.** The shell collapses the sidebar to a 72 px rail below 1,100 px, so the table area is about:

| Viewport | Sidebar | Table width (≈) | Overview | KPI row | Tables (before D1) |
|---|---|---|---|---|---|
| 1920 | 264 | 1,624 | Two panes | 4-up | Fit |
| 1366 | 264 | 1,070 | Two panes (≈ 420 / 640) | 4-up | Fit |
| 1024 | 72 rail | 928 | Two panes (≈ 356 / 534) | 4-up | Fit |
| 768 | 72 rail | 672 | One column, analytics in its fixed box | 2 × 2 | **Overflow:** Pending 16 px, Submitted 20 px |
| (480, stress only) | — | 480 | One column | 2 × 2 | Pending 148 px |

**By area (code reading unless stated):**
- Header and tabs: header tested at 768 / 1366 in R1; the tab bar splits the width into three equal tabs (≈ 224 px each at 672), comfortably more than an icon, label and count badge need (estimate, not measured).
- Overview: below 900 px content it is one ListView (left card, then analytics in a max(420, 70 % height) box) — nested scroll kept as in B4. At 1024 the left pane is ≈ 356 px: Quick actions wrap; Edit and Duplicate are `Expanded` with ellipsis labels, so they shrink rather than overflow.
- Toolbars (search, filters, sort chip, Clear selection, selection bar): all `Wrap`, so they go to extra rows at 672 instead of overflowing.
- Detail (560 px) and timeline (480 px) panels: side panels at any viewport ≥ 700 px, bottom sheets below. Detail tested at 768 / 1366 in R3.
- Export dialog (520 px) and formal report: tested at 768 / 1366 in R4; fillable progress dialog is 420 px.

**D1 — table rows overflow at 768 (fixed).** `AdminDataTable` has no minimum width or horizontal scroll, so at ≈ 672 px the fixed-width columns plus the identity cell's avatar no longer fit. The Pending overflow predates the redesign; the Submitted one was ≈ 9 px before R3 and 20 px after the TIME TO SUBMIT header widened its column to 116. Fix, local to this panel: new `SurveyResponsesTableFrame` in `admin_survey_ui.dart` wraps both tables; at 720 px and above it returns the table unchanged, below that it gives the table 720 px inside a horizontal `SingleChildScrollView` with a visible scrollbar. The shared `AdminDataTable` is not changed. With the frame, permanent tests show no overflow for either table at 480, 672 and 1,070 px; at 720 px and wider the frame returns the table as is, and the temporary test had already found no overflow there (720–1,624).

**Corrections to earlier sections.**
- §C3 said the 768 detail test used a bottom sheet. At 768 the viewport is ≥ 700, so it is the side panel; the test covered the side panel at both 768 and 1366. The bottom-sheet path (viewport < 700) has no test.
- §A7 said the tables "fall back to row cards" at 768. `_PendingAlumniCard` / `_SubmittedResponseCard` are the table rows themselves; there is no card fallback, which is why D1 happened.

**Files changed in D:** `surveys/widgets/admin_survey_ui.dart` (new `SurveyResponsesTableFrame`), `surveys/presentation/admin_survey_responses_page.dart` (both tables wrapped; blocks re-indented by hand — the file was not run through `dart format`), `test/admin_surveys/survey_responses_widgets_test.dart` (7 tests).

**Checks actually performed:** `flutter analyze lib/features/admin/surveys test/admin_surveys` — no issues. `flutter test test/admin_surveys` — 73 passed (7 new: a Pending row and a Submitted row, built with copies of the page's column specs and long name/course text, inside the frame at 480, 672 and 1,070 px — no overflow, horizontal scroll present below 720 and absent at 1,070; control: the Submitted row without the frame at 672 overflows). The tests use copies of the column lists, so they need updating if the page's columns change.

**Deferred to live QA:** viewing the panel at 768 / 1024 / 1366 / 1920 with real data; horizontal scrolling and scrollbar feel at 768; bottom-sheet detail / timeline below 700 px; how the nested Overview scroll feels; the export, fillable and formal-report dialogs at real sizes.

## E. Functional review (Phase E — 2026-10-15, UI-first: code-level)

**Method.** The six Responses files were compared with HEAD (`git show HEAD:…`): every service, export and dialog call was counted on both sides, then each flow was read against its HEAD version. **No live regression, no Supabase session, no data written, no exports or reminders sent.**

| Area | Result |
|---|---|
| Service and export calls | Same calls and counts as HEAD in all six files (load, publish, close, duplicate, `sendReminders`, analytics, CSV/Excel/management/CHED/pending/single-response exports, fillable ZIP `buildZip` + `logBatchSuccess` / `logBatchFailure`, formal report `generate` / `toPdf`, `getResponseEvents`). **One extra read-only `countAudience`** before Overview Publish / Re-publish (approved in B, FX2). Web-only guard (`requireWebExport` ×10), personal-data confirmation (×7), downloads (×16) and the `_isExportingChed` set/reset (6 / 7) appear the same number of times |
| Load / refresh | Same four reads and order, `markSurveyResponsesSeenByAdmin` errors still ignored. First-load failure → `AdminStateView.error` with Try again; failed refresh keeps the last data under the warning strip with Retry (as HEAD). A reload drops ids that are no longer pending from the selection |
| Publish / Re-publish / Close | Same `publishSurvey` / `closeSurvey`, same success texts, reload only after success (as HEAD). New per FX2: question problems block (custom surveys), zero-audience block, confirm with audience count, busy label, friendly errors. HEAD acted only on draft / closed / published; the model has only those three statuses, so the new published → close, otherwise → publish toggle covers the same cases |
| Duplicate | Same call and success text; opens the Editor via the same `onOpenEditor`; now guarded against double taps (FX3) |
| Pending list | Search fields, status filter, sort options and default, page size, page resets: same as HEAD. Selection now clears when search, a filter value or Clear filters changes (FX4). Export selected receives the whole filtered list, so it and Send reminder target the same people |
| Reminders | Same targets (selection, or all pending when nothing is selected), same `sendReminders` arguments, reload after. Not-configured email is now detected before the confirm so the confirm can say so (FX5; HEAD: after); email-only still stops with the same message; failures listed in a dialog |
| Submitted list | Sort options/default and page reset as HEAD; row tap and ⋮ View / PDF / Excel / Print / Timeline map to the same handlers |
| Detail panel | Hides questions that the survey's visibility rules hide for this alumnus (FX6). Consistent with stored data: submit already drops hidden answers (`SurveyService` → `pruneHiddenAnswers`), and the single-response export lists the same visible questions. Edge case, not changed: the export re-checks visibility after a second prune, the panel does not; they can differ only with rule chains three questions deep. CHED: official form behind the toggle; same `ChedGtsForm` read-only |
| Export dialog | Same `SurveyExportChoice` result (report, format, batch/course only when cohort filters show), same Download enable rule (`_canContinue`), same format reset when the report changes |
| Fillable ZIP | Same order: web guard → personal-data confirm → batch limit (now 0c confirm; Cancel stops, Continue takes the first 100) → progress → build → close → download → log. Progress dialog: `showAdminDialogSurface` uses `showDialog`'s root navigator, so the existing `Navigator.of(context, rootNavigator: true).pop()` still closes it; `PopScope(canPop: false)` stops Esc and the barrier closing it mid-build |
| Formal report | Same service calls; discard prompt on Close / Esc / Regenerate when edited (FX8, tested in R4) |

**Findings:** none needing a code change.

**Code changed in E:** none. The last test run (end of Phase D) stands: `flutter analyze lib/features/admin/surveys test/admin_surveys` — no issues; `flutter test test/admin_surveys` — 73 passed.

**Deferred to the testing phase (live; several need a QA survey and write data):** publish / re-publish / close / duplicate on a QA survey including the zero-audience and question-problem blocks; reminders (in-app, email configured and not); selection clearing on real filters; each export and print path in the browser; fillable ZIP above and below 100 responses, including Cancel at the batch limit; formal report with AI on and off; detail panel on a survey with real visibility rules; timeline panel; refresh failure strip; full test suite.

---

## F. Completion report (Phase F — 2026-10-15)

**Screen:** Survey Responses (in-page panel of Surveys, menu index 10; opened from the Surveys list, returns to it). **Status:** visually complete for the manuscript (UI-first mode); responsive and functional checks were **code-level only**; live QA and regression **outstanding** (later testing phase). Awaiting owner sign-off.

| Item | Summary |
|---|---|
| Files changed | `surveys/presentation/admin_survey_responses_page.dart` (now 3,670 lines), `surveys/widgets/admin_survey_analytics_panel.dart`, `surveys/widgets/admin_survey_response_detail_sheet.dart`, `surveys/widgets/admin_survey_response_timeline_sheet.dart`, `surveys/widgets/admin_survey_export_dialog.dart`, `surveys/widgets/admin_survey_formal_report_dialog.dart`, `surveys/widgets/admin_survey_ui.dart` (Responses-only widgets). New tests: `test/admin_surveys/survey_responses_widgets_test.dart` (27), `test/admin_surveys/survey_responses_dialogs_test.dart` (10) |
| Reused | `showAdminConfirmDialog`, `showAdminDialogSurface`, `AdminStateView.error`, `AdminButtonStyles`, `AdminColors` / `AdminSurfaces` / `AdminText`, `DirectoryKpiRow` + `AdminKpiCard`, `DirectoryToolbarFilterChip` + `showAdminOptionPicker`, `SurveyStatusChip.fromSurvey`, `surveyStatusText`, `surveyWindowText`, `surveyFriendlyError`, `surveyPublishProblems`, `SurveyEditorSection`, `ClassicSurveyVisibility.visibleQuestions`, `AdminDataTable` / `AdminPaginationBar` / `AdminSearchField` (unchanged) |
| Created (feature-local) | `SurveyWorkspaceShortcuts`, `SurveyResponsesSkeleton` (overview / table), `SurveyResponsesTableFrame`; page-level `surveyReminderConfirmMessage`, `surveyReminderSummary`, `surveyResponseMetaLine`, `surveyExportErrorMessage` (`@visibleForTesting`); private `_OverviewPublishProblemsDialog`, `_ReminderFailuresDialog`, `_UnansweredStrip`, `_ReportRow`; `surveyFormalReportDialogForTest`. Restyled in place (Responses-only per `rg`): `SurveyResponsesWorkspaceHeader`, `SurveyWorkspaceSegmentedNav`, `SurveySectionCard`, `SurveyEmptyState` |
| UI/UX changes | §C1: header "Window ended" chip + window line; KPI row (Assigned · Submitted · Pending · Completion; Pending/Submitted open their tabs); one left card (state button, Edit survey · Duplicate, Outputs, Details with friendly status / Window / formatted audience); trend dates + bar tooltips; matching skeletons; error view. §C2: sort as a toolbar chip, Clear selection, reminder confirm/result wording, failures dialog. §C3: TIME TO SUBMIT header + cell tooltip, sort chip, detail meta line, local unanswered strip, CHED official form behind a toggle. §C4: 520 px export dialog with one scroll, Details on every row, in-row "Needs submitted responses"; 0c fillable dialogs; formal report on tokens. Token SnackBars throughout |
| Fixes | FX1 shortcuts ignore typing; FX2 Overview publish checks + Close confirm; FX3 Duplicate guard; FX4 selection cleared on filter/search change; FX5 email-not-set-up stated; FX6 detail panel respects visibility rules; FX7 friendly errors (all 14 raw places); FX8 formal-report discard prompt; D1 table overflow at 768 (local horizontal scroll below 720 px) |
| Responsive | Overview two panes ≥ 900 px content, one column below; KPI 4-up / 2×2; toolbars wrap; tables scroll horizontally below 720 px; detail (560 px) and timeline (480 px) side panels at ≥ 700 px viewport, bottom sheets below (§D) |
| Preserved | All service and export calls and their order (plus the approved read-only `countAudience`), analytics calculations and cache, export routing and cohort scoping, personal-data confirmations, fillable batch limit (100) and progress flow, reminder targets and arguments, sort options, filters, pagination, table columns (only the DURATION header renamed), header ⋮ menu, tab keys, back target (§E) |
| Tests performed | `flutter analyze lib/features/admin/surveys test/admin_surveys`: no issues. `flutter test test/admin_surveys`: 73 passed (37 Responses + 18 Editor + 18 list). Temporary table measurement (deleted); running-app log scan (still only the 4 older unattributed overflows). **Not run:** full suite, browser view, any live action, export, reminder or AI call. The page itself is not rendered in tests (needs Supabase); tests cover its widgets, dialogs and text helpers |
| Approved deviations / judgment calls | §C1 (left card sizes to content; "Assigned alumni" kept in Details; Responses copy of the Editor's problems dialog; Re-publish wording "… The survey reopens for them. Existing submissions are kept."); §C2 (selection clears only when a picker value changes; Esc clears it only with Pending search text; email-only send stops before the confirm; the "one toolbar row at ≥ 1,050 px" was not done); §C3 (TIME TO SUBMIT tooltip on cells, column 90 → 116 px; official-form toggle persists across sections; full device summary in the meta line); §C4 (blocked note kept under the formats too; taller dialog; lazy formal-report service; partial ZIP in warning colour; `dart format` re-wrap of the two dialog files) |
| Corrections to earlier sections | §A7 and §B4 said the tables fall back to row cards below 900 px — they don't (they are table rows; §D). §C3's "768 bottom sheet" was the side panel (§D) |
| Remaining | Live verification list in §E and §D; audit item 17 part "how many already got reminders" not shown in the confirm; Overview Outputs still duplicate the header ⋮ menu (kept by design, item 11); `SurveyCallout` keeps its old style (Editor uses it; Responses now uses a local strip); 4 unattributed overflow entries in the running-app log; three-level visibility-rule chains may differ between the detail panel and the single-response export (§E); code health unchanged (single large state class, one `_isExportingChed` flag for all exports, legacy menu values) |

