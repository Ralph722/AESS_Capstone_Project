# Alumni Directory (menu index 2) — Phases A–F

Date: 2026-10-14. Parent: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §8–§9. Builds on Phase 0 ([0a](AESS_ADMIN_REDESIGN_PHASE0A_TOKENS.md), [0b](AESS_ADMIN_REDESIGN_PHASE0B_SHELL.md), [0c](AESS_ADMIN_REDESIGN_PHASE0C_COMPONENTS.md)) and the closed [Dashboard](AESS_ADMIN_REDESIGN_DASHBOARD.md).

Scope: the list screen and its dialogs (add chooser, add/edit, delete/deactivate, Excel import, CHED GTS batch export). The **Member Detail panel** is the next screen in the approved order and is only audited here where the list hands over to it.

Evidence: code inspection of the files below; live read-only screenshots from earlier QA rounds (`%TEMP%\aess_qa\0b-1366-nav-02-directory.png` after the 0b shell, `1920-02-directory.png` from 0a — Directory content unchanged since, 0c pixel-verified); a standalone run of the page-count formula (outside the repo). No new live session was opened for this audit.

---

## A1. Purpose and user

Admins maintain the **official alumni roster** that registration is validated against (name + course + ID must match). Common tasks: find a person, check registration/activity status, add one member, bulk-import from Excel, correct an entry, deactivate/remove, export CHED GTS PDFs, open a member's detail.

## A2. Files

| File | Role | LOC |
|---|---|---:|
| `features/admin/roster/presentation/admin_alumni_members_page.dart` | Index-2 wrapper → `AdminAlumniDirectoryScreen` | 12 |
| `features/admin/roster/presentation/admin_alumni_directory_page.dart` | State, loading, filters, dialogs, CRUD handlers, layout | 1,200 |
| `features/admin/roster/widgets/alumni_directory_ui.dart` | `AdminDirectoryTheme` + Directory kit (header, KPI, toolbar, filters, results bar, empty state, table row, card row, row menu) + Member Detail widgets (from line 2049) | ~2,765 |
| `features/admin/roster/widgets/admin_alumni_directory_dialogs.dart` | Add chooser, CHED bulk export dialog | ~590 |
| `features/admin/roster/data/alumni_member_service.dart` | Supabase reads/writes, `filterAndSort` (unchanged by this work) | — |
| Shared: `admin_data_table.dart`, `admin_pagination.dart`, `admin_page_header.dart`, `admin_surface.dart`, `admin_density.dart`, `admin_skeletons.dart` (`AdminDirectoryListSkeleton`), `dashboard/widgets/admin_instant_content.dart` | | |

## A3. Data and sources (must not change)

| Data | Source |
|---|---|
| Roster list (incl. deactivated) | `AlumniMemberService.getAllMembers(includeDeactivated: true)` — one load after first frame; reloaded after every write |
| KPI counts | Computed in page (`_recomputeDerivedStats`): On roster = **all** rows incl. deactivated; Registered / Not registered / Active (30 d) / Profile updates = non-deactivated only |
| Visible list | `filterAndSort(…, hideDeactivated: true)` — search (debounced 300 ms), course, batch, registration, activity (7/30/90/inactive 90 d+), sort (6 options) |
| Pagination | Client-side, `adminPaginate` / `adminClampPage` / `adminPageCount`; sizes 25/50/100 |
| Status badge (table) | Deactivated → "Active" (registered + active within the selected activity window, default 30 d) → "Registered" → "Not registered" |
| Writes | `createMember`, `updateRosterMember`, `deactivateMember`, `reactivateMember`, `deleteMember`, `removeRegisteredMemberAccount`, `AlumniRosterImportService.importRows`, CHED `ChedGtsPdfBatchExportService.buildZip` + log; audit rows via `AuditService.logAction` |

## A4. Interactions (all preserved in any redesign)

Header: **Export** (CHED GTS PDF ZIP; disabled while loading/exporting/empty; web only) · **Add Alumni** (chooser → Add manually / Import from file). KPI cards: Registered, Not registered, Active (30d) tap → set that filter (On roster and Profile updates not tappable). Toolbar: search + clear, Refresh, 5 dropdowns, Reset (only when filters active), removable active-filter chips. Rows: tap → Member Detail (replaces the whole page body; header/KPIs/toolbar hidden); ⋯ menu → View details, Edit roster entry, Delete / deactivate (or Reactivate). Pagination: Rows size, previous/next. Empty states: "No alumni on the roster yet" (+ Add Alumni) and "No matches" (+ Clear filters). Keep-alive mixin; image cache cleared on dispose.

## A5. Layout today (from screenshots)

Page title "Official Alumni Roster" + subtitle + Export / Add Alumni → 4 KPI cards (5th "Profile updates" only when > 0) → toolbar card (full-width search + refresh; second row of 5 fixed-width dropdowns) → "Showing N of M alumni" line → table (≥ 900 px content width; card rows below) → pagination footer.

- **1366×768:** fixed chrome above the table ≈ 230 px; 6 of 8 rows visible, table scrolls; email truncated.
- **1920×1080:** all 8 rows plus a large empty table area; columns very spread out; right ~60 % of the filter row empty.

## A6. Problems and opportunities

**Functional defects found (pre-existing — not styling; fixing needs approval):**

1. **Page count off by one** — answers the open "Page 1 of 2" item. `adminPageCount` (`admin_pagination.dart:26`) does `((total + size − 1) / size).ceil()`; `/` is floating-point, so the extra `size − 1` is not truncated. Verified: 8 → 2 pages (expected 1), 25 → 2 (1), 50 → 3 (2); correct only for 1, 26, 51…. Effect: "Next" stays enabled and leads to an empty page showing "Showing 26–8 of 8". Fix is one operator (`~/`), but the helper is **shared by Directory, Activity Logs and Survey Responses**.
2. **Deactivated members are unreachable.** The list always hides them and no other admin screen calls `reactivateMember`, so the row menu's "Reactivate" item and the "Deactivated" badge can never show. A deactivated person can't be reactivated from the UI. Showing them needs a new filter option → feature-level change, **requires approval**.
3. **Add/Edit dialog validates only after closing.** Empty name/ID or a bad year → dialog closes, red SnackBar "Exception: Full name and ID number are required.", typed values lost. Master §8 asks to preserve input after failure. Fix = keep dialog open and validate in-form (same rules as the service) — behavior change, **requires approval**.
4. **Raw errors shown to admins:** `'$e'` SnackBars ("Exception: …", "Error loading roster: Exception: Error fetching members: …"), "CHED GTS batch export failed: $e". Reactivate has no try/catch (unhandled error) and no audit log (behavior — note only).
5. **Refresh gives no feedback after the first load:** `_loadMembers` only sets `_isLoading` when the list is empty, so the refresh icon never spins on later refreshes.

**Information / consistency:**

6. **Naming mismatch:** sidebar + header breadcrumb say "Alumni Directory"; page title says "Official Alumni Roster". Subtitle "Manage registered alumni records." is inaccurate (most rows are *not* registered).
7. **"On roster" vs list total disagree when deactivated rows exist:** KPI counts all rows, results line / list exclude deactivated. On live data equal (8) because none are deactivated.
8. **Table hides information the card view shows:** "Tracer complete" badge and the separate "Registered" + "Active recently" badges exist only in card rows; the table shows one status. **Batch / year graduated** is a filter but is not displayed in either view.
9. **Duplicate counts:** "Showing 8 of 8 alumni" above the table and "Showing 1–8 of 8" in the footer; "Profile updates" KPI and "N pending review" pill show the same number.
10. **Export label is vague** — button says "Export" but produces a CHED GTS PDF ZIP.
11. **5th KPI** ("Profile updates") wraps alone onto a second row at ≥ 900 px.

**Visual / design-system:**

12. Not yet on 0c components: `DirectoryStatCard` (vs `AdminKpiCard`), header buttons and dialog buttons (vs `AdminButtonStyles`), delete dialog (custom `Dialog`, radius 20, `Colors.red.shade600`), import-issues and CHED progress dialogs (plain `AlertDialog`), empty states (vs `AdminStateView`), section label styles (vs `AdminText`).
13. Off-token colors: SnackBars `#FF6B6B` / `#4CAF50`; `Colors.red.shade400/600`, `Colors.grey.shade300/600/700`; table "Registered" badge bg literal `#E8E7F2` (= `infoBg` value).
14. Filter dropdown floating labels are 11 px scaled to ≈ 8 px when floated (hard to read). `DirectoryFilterField` is used across most admin modules and several dialogs (A8) → shared change.
15. Mixed radii: table/toolbar 12, card rows 16, add/edit fields 12, delete dialog 20, chooser 16.
16. Status uses color + text (OK); the green avatar dot duplicates "Active" (color-only signal, but redundant with the badge, so acceptable).
17. Wide screens: table columns spread far apart and lots of unused row space at 1920; at 1366 the KPI strip + toolbar + results line use ~40 % of the content height.

## A7. Responsive notes (code)

Table ≥ 900 px content width (`desktopSplitMin`), card rows below; card rows switch to stacked layout < 900 px card width. KPI grid 4 / 2 / 1 columns at ≥ 900 / ≥ 560 / < 560. Filter widths 148 / 136 / half / full at ≥ 1100 / ≥ 820 / ≥ 560 / < 560. Pagination stacks < 560 px. At the reference sizes (1366–1920) the table layout is always used.

## A8. Shared-component dependencies and risks

| Component | Other users | Risk if changed |
|---|---|---|
| `adminPageCount` / `AdminPaginationBar` | Activity Logs, Survey Responses | Fixing item 1 changes their page counts too (correctly) |
| `DirectoryToolbarCard`, `DirectoryActiveFilterChip` | Surveys, Events, Jobs, DSS (+ History), Announcements, Forum (+ filter chips in Feedback / Activity Logs) | Any visual change restyles all of them — needs separate approval |
| `DirectoryFilterField` | The modules above **plus** Reports filter bar, Activity Logs, CHED wave comparison dialog, survey export dialog, survey analytics panel, CHED bulk export dialog | Same; widest reach of the kit |
| `AdminDataTable` / `AdminDataRow` | Activity Logs, Survey Responses | Column/row metrics affect three dense screens |
| `DirectoryStatCard` / `DirectoryStatsGrid` | Surveys, Events, Jobs, DSS (+ History), Forum, Announcements | Swapping to `AdminKpiCard` must be done in the Directory page only, not by changing these classes |
| `AdminDirectoryTheme` | Aliased by 8 feature themes | Do not change values |
| `AdminInstantContent` / `AdminDirectoryListSkeleton` | Several list screens | Prefer local use |

Other risks: Member Detail replaces the page body (keep that transition intact); keep-alive and cache eviction rules in `AdminDashboardWeb`; no existing tests cover this screen, so Phase C would need new widget tests first.

## A9. Decisions needed before Phase B

- Whether the B proposal may include the functional fixes 1–5 (each separately approvable), or stay purely visual and list them as follow-ups.
- Whether shared toolbar/filter changes (item 14) are in scope now or deferred to a separate shared-component approval.

**Owner answers (2026-10-14):** audit approved; functional fixes 1–5 go into the proposal (each separately approvable); shared changes: owner leans to "change" and asked for a recommendation (B3); Phase B authorized.

---

## B. Proposal (2026-10-14) — not implemented

### B1. Proposed layout (desktop, content width ≥ 1100 — 1366×768 and up)

```
Alumni Directory                                   [⤓ Export CHED GTS] [+ Add Alumni]
Official roster used to validate alumni registration.
┌ On roster ───┐┌ Registered ──┐┌ Not registered ┐┌ Active (30d) ─┐[┌ Profile updates ┐]
│ 8            ││ 3            ││ 5              ││ 3             │ │ 2               │
│ Total alumni ││ Signed in to ││ Awaiting app   ││ Recently      │ │ Pending admin   │
│ records      ││ the app      ││ signup         ││ active users  │ │ review          │
└──────────────┘└──────────────┘└────────────────┘└───────────────┘ └─────────────────┘
┌ toolbar ──────────────────────────────────────────────────────────────────────────┐
│ [🔍 Search by name, ID…      ] [Course▾][Batch▾][Registration▾][Activity▾][Sort▾] [Reset] [↻] │
│ (Search: ana ✕) (Course: BSIT ✕)                                                     │
└───────────────────────────────────────────────────────────────────────────────────┘
Showing 8 of 8 alumni                                       ☐ Show deactivated
┌───────────────────────────────────────────────────────────────────────────────────┐
│ NAME              COURSE  BATCH  STUDENT ID   EMAIL         LAST ACTIVE  TRACER    STATUS     ⋯ │
│ (C) Catherine Jala BSIT   2024   2023303030   pedregos…     Oct 4 11:04  Complete  Active     ⋯ │
│ (K) Kevin Torres   BTLED  —      T4WV7W1IA0   —             —            —         Not reg.   ⋯ │
│ …                                                                                   │
│ Showing 1–8 of 8                                         Rows 25 ▾   ‹  Page 1 of 1  › │
└───────────────────────────────────────────────────────────────────────────────────┘
```

Below 1100 px content width the toolbar keeps today's two rows; below 900 px the table switches to today's card rows (unchanged breakpoints). KPI strip: one equal-width row of 4 (or 5 when "Profile updates" shows) at ≥ 900 px; 2 / 1 columns below, as today.

### B2. CURRENT DATA → CURRENT COMPONENT → PROPOSED COMPONENT

| Current data | Current component | Proposed |
|---|---|---|
| Title / subtitle | `DirectoryPageHeader` "Official Alumni Roster" / "Manage registered alumni records." | Same `AdminPageHeader`; wording W1 |
| Export, Add Alumni | `_HeaderActions` (local button styles) | Same buttons on `AdminButtonStyles.outlined/filled`; Export label W2 + tooltip |
| 4–5 KPI figures + tap-to-filter | `DirectoryStatCard` in `DirectoryStatsGrid` (4-col wrap → 5th card alone) | `AdminKpiCard(dense)` built in the Directory page only, same labels/values/captions/taps; one row of 4 or 5. "On roster" caption adds "incl. N deactivated" only when N > 0 (explains item 7; value unchanged) |
| Search, refresh, 5 filters, Reset, chips | `DirectoryToolbarCard` (2 rows) | Same widget; **opt-in** single row at ≥ 1100 px (SH3) |
| Filter labels | `DirectoryFilterField` (≈ 8 px floated label) | Legible label (SH2) |
| "Showing N of M alumni" + "N pending review" pill | `DirectoryResultsBar` | Same row; pill kept (S1); new "Show deactivated" checkbox on the right (F2) |
| Table: Name (+ "Profile updated"), Course, Student ID, Email, Last active, Status | `AdminDataTable` + `DirectoryMemberTableRow` | Same + **Batch** (`effectiveBatchYear`, "—" if empty) and **Tracer** ("Complete" badge / "—" from `tracerProfileComplete`) columns — data already loaded and shown in card rows / filters (D1); email gets a hover tooltip with the full address |
| Card rows (< 900 px) | `DirectoryMemberCard` | Unchanged except tokens; add Batch to its meta grid (D1) |
| Row menu | `_MemberMenu` | Unchanged items; tokens only |
| Pagination | `AdminPaginationBar` | Unchanged look; correct page count (F1) |
| Empty states | `DirectoryEmptyState` (used by 7 screens) | `AdminStateView.empty` in this page only; same titles, text and actions |
| Loading | `AdminInstantContent` + `AdminDirectoryListSkeleton` | Unchanged |
| Add/Edit dialog | Custom dialog, validates after closing | Same fields/labels; tokens; F3 |
| Delete / deactivate dialog | Custom `Dialog` r20, `Colors.red` | `showAdminDialogSurface` + `AdminButtonStyles` (Cancel · Deactivate · Remove account/Delete in danger red), same three outcomes and text; focus starts on Cancel |
| Add chooser, CHED bulk export dialog, CHED progress, Import issues | Mixed dialog chrome | Token/typography alignment only (radius 12, `AdminText`); progress dialog stays non-dismissible |
| SnackBars | `#FF6B6B` / `#4CAF50`, raw `'$e'` | `AdminColors.danger` / `success`; friendly text (F4) |

### B3. Shared components — recommendation (owner asked)

Principle (Master §6, §18): prefer one shared fix over per-screen copies, but don't restyle other screens before their own audit. So: **fix defects globally, add layout changes as opt-in.**

| # | Change | Reach | Recommendation |
|---|---|---|---|
| SH1 | `adminPageCount`: `/` → `~/` (= F1) | Directory, Activity Logs, Survey Responses | **Global.** It's a bug; other screens only get correct page counts. Unit tests added |
| SH2 | `DirectoryFilterField.decoration`: floated label readable (~11 px rendered, `textSecondary`, w600) | Every `DirectoryFilterField` + the date/time/range filter chips (Surveys, Events, Jobs, DSS, Announcements, Forum, Reports filter bar, Activity Logs, 4 dialogs) | **Global.** Accessibility fix; label sits on the border, so control heights don't change. Phase D screenshots each affected list screen at 1366×768 |
| SH3 | `DirectoryToolbarCard`: new optional `singleRowMinWidth` (default off) — search, filters, Reset and Refresh on one row when wide enough | Directory only (others unchanged until their phases) | **Opt-in.** Saves one toolbar row (~50 px) at 1366×768 |
| — | `DirectoryStatCard`/`StatsGrid`, `DirectoryEmptyState`, `DirectoryResultsBar`, `AdminDataTable` metrics | 7 screens | **Don't change.** Directory switches to the 0c components locally; others migrate in their own phases |

### B4. Functional fixes (each separately approvable)

| # | Fix | How (no schema / service / RLS change) | Risk |
|---|---|---|---|
| F1 | Correct page count | SH1 | Low; affects 3 screens (correctly) |
| F2 | Deactivated members viewable and reactivatable | Page-local "Show deactivated" checkbox → passes `hideDeactivated: false` to the existing `filterAndSort`. Deactivated rows then show the existing "Deactivated" badge, muted name, and the existing "Reactivate" menu item. Counts as an active filter (chip "Including deactivated", cleared by Reset). KPIs unchanged | Low–medium; first time admins can reactivate from the UI (the service method already exists) |
| F3 | Add/Edit keeps input on errors | Dialog stays open; inline field errors using the **same rules as the service** (name and ID required; course from list; year optional 4 digits). Save runs from the dialog with a busy button (no double submit); duplicate-ID message shown inside the dialog. Same service calls, same audit rows, same success SnackBar | Medium — dialog flow restructured; covered by new widget tests |
| F4a | Friendly error text | Strip "Exception: " and wrap in plain sentences (e.g. "Couldn't load the roster. Check your connection and try Refresh."); token colors | Low |
| F4b | Reactivate error handling | try/catch + friendly SnackBar (today an error is unhandled) | Low |
| F4c | Reactivate audit row `REACTIVATE_ROSTER` | Same `AuditService.logAction` pattern as deactivate | **Behavior addition** (new log rows) — owner decision |
| F5 | Refresh shows busy state | Page-local refreshing flag drives the toolbar spinner; list stays visible during refresh | Low |

### B5. Wording — requires approval

- W1: title "Official Alumni Roster" → **"Alumni Directory"** (matches sidebar/breadcrumb); subtitle → **"Official roster used to validate alumni registration."**
- W2: "Export" → **"Export CHED GTS"**, tooltip "Download CHED GTS PDFs as a ZIP".

### B6. Data display — requires approval

- D1: show **Batch** and **Tracer** in the table (Batch also in card rows). Existing loaded fields; no new query.

### B7. Potential Content Simplification — Requires Approval

- S1: "N pending review" pill duplicates the "Profile updates" KPI. **Recommendation: keep both** (pill is visible next to the list when the KPI is scrolled away on small screens). Listed only for completeness.
- The "Showing N of M alumni" line and the footer "Showing 1–8 of 8" look alike but mean different things (filtered of total vs current page range) — **keep both**.

### B8. Unchanged functionality

All queries and writes (A3), filter/sort logic, debounce, KPI tap-to-filter, Member Detail hand-over (body replacement, `ValueKey`, update callback), keep-alive, cache clear on dispose, import parsing and issue list, CHED export limits/progress/download/logging, delete vs remove-account rules, audit rows (except F4c if approved), web-only guards, breakpoints.

### B9. Responsive behavior

1366×768: header + KPI row + single-row toolbar + results line ≈ 50 px less than today → about one more table row visible (estimate; measured in Phase D). 1440 / 1600 / 1920: same layout; the two extra columns use space that is empty today. 1024×768: two-row toolbar (as today), table. < 900 px: card rows (as today).

### B10. Risks

- SH2 restyles filter labels on most admin screens — visual only, verified by screenshots in Phase D.
- F3 changes when the dialog closes; tests cover success, validation, duplicate and service-error paths.
- F2 makes deactivated rows visible on demand; Reset and Member Detail must handle them (detail opens as today).
- No live writes during QA (read-only policy): F2/F3/F4 write paths are verified with widget tests and code inspection, not live — unless the owner allows a test record.

### B11. Usability rationale

Same name as the sidebar; every loaded field is visible in the main view; less chrome above the table; readable filters; correct pagination; errors that tell the admin what to do; no dead "Reactivate" path; no lost typing.

### B12. Files expected to change in Phase C (if approved)

`admin_alumni_directory_page.dart`, `alumni_directory_ui.dart` (Directory header/table/card/toolbar opt-in/filter label), `admin_alumni_directory_dialogs.dart` (tokens), `shared/widgets/admin/admin_pagination.dart` (SH1). New tests: `test/admin_directory/` (pagination unit tests, table row columns, KPI strip, Show deactivated, add/edit validation, delete dialog outcomes, no overflow at 1024–1920).

### B13. Future UX / Feature Recommendations (not proposed)

Column-header sorting; bulk select/actions (row widgets already have unused checkbox hooks); a "Profile updates" quick filter; Excel import template download.

**Owner decision (2026-10-14):** every item approved (base layout, SH1–SH3, F1–F5 incl. F4c, W1, W2, D1, S1). Phase C authorized.

---

## C. Implementation record (2026-10-14)

### C1. Files changed

| File | Change |
|---|---|
| `shared/widgets/admin/admin_pagination.dart` | SH1/F1: one line, `adminPageCount` uses `~/` |
| `roster/widgets/alumni_directory_ui.dart` | SH2: `DirectoryFilterField.decoration` gains `floatingLabelStyle` (14.5 → renders ≈ 11 px, w600); SH3: `DirectoryToolbarCard.singleRowMinWidth` (default null = unchanged tree); W1/W2 header text + `AdminButtonStyles` + export tooltip; new `DirectoryKpiRow`; table columns + Batch / Tracer cells + email tooltip; table "Registered" badge bg `AdminColors.infoBg` (same value as the old literal); Batch in card rows |
| `roster/widgets/admin_alumni_directory_dialogs.dart` | New `showRosterEntryDialog` / `RosterEntryDialog` (F3) and `showRosterRemoveDialog` / `RosterRemoveDialog` (`showAdminDialogSurface`, `AdminButtonStyles`, Cancel focused); chooser and CHED dialog titles 17/w700, CHED buttons on `AdminButtonStyles`; `directoryDialogTitle` / `directoryAlertDialogShape` for the two `AlertDialog`s |
| `roster/presentation/admin_alumni_directory_page.dart` | `AdminKpiCard(dense)` in `DirectoryKpiRow` ("On roster" caption adds "incl. N deactivated" when N > 0); toolbar opts into single row at ≥ 1000 px content width (filters 136 px there); F2 "Show deactivated" checkbox + chip + Reset + results total; F3 save runs from the dialog; F4a `_friendlyError` (service sentences shown, wrapped technical errors replaced); F4b/F4c `_reactivate` with try/catch and `REACTIVATE_ROSTER` audit row (description `reactivate: <name>`, role admin — same pattern as deactivate); F5 `_isRefreshing` spinner; `AdminStateView.empty` with the same texts/actions; SnackBars on `AdminColors`; progress / import-issues dialogs restyled |
| Tests (new) | `test/admin_directory/pagination_test.dart`, `directory_widgets_test.dart`, `directory_dialogs_test.dart` (31 tests) |

`dart format` was applied to the three roster files (some line re-wrapping in untouched code; formatting only). The shared pagination file has only the one-line change.

### C2. Deviations from B (presentation only)

1. Dialog radius stays **16** (existing `showAdminDialogSurface` / confirm-dialog standard), not 12 as written in B2.
2. **Height saving smaller than estimated (B9).** Widget-test measurement at 1070 px: single-row toolbar 60 px vs 108 px (−48), but `AdminKpiCard(dense)` row 128 px vs old `DirectoryStatCard` row 96 px (+32) → net ≈ −16 px, not ≈ −50 px. Live figures to be measured in Phase D. Options for the owner: accept; or keep the shared KPI card but drop its caption line on this page (needs approval — information change); or a shared `AdminKpiCard` compact variant (shared change, needs approval).
3. In single-row mode, Reset sits at the end of the active-chip row (it only appears when chips exist).
4. Add/Edit: the close (×) button is disabled while saving; Esc / outside tap still close the dialog (as before), and the page then still shows the success message and reloads if the save completed.

### C3. Not changed

Service/repository/model files, queries, RLS, filter/sort logic (`filterAndSort` called with its existing `hideDeactivated` parameter), KPI calculations, Member Detail panel and hand-over, keep-alive/cache rules, import parsing, CHED export rules, delete/remove-account rules, existing audit rows. `DirectoryStatCard`, `DirectoryStatsGrid`, `DirectoryEmptyState`, `DirectoryResultsBar` and `AdminDataTable` untouched (still used by other screens).

### C4. Checks run

- `flutter analyze` (admin scope + `test/admin_shared`, `test/admin_dashboard`, `test/admin_directory`): 19 info, all pre-existing; none in changed files.
- `flutter test test/admin_directory`: 31 passed (page count 1/8/24/25/26/50/51/100, clamp, "Page 1 of 1" + Next disabled; column order; Batch/Tracer/email tooltip/dash/Deactivated cells; no overflow with long name at 1024/1366/1920; card Batch; KPI row 5-in-a-row equal height, 2/1-column wrap, tap; toolbar default two rows, opt-in single row, narrow fallback, Reset + chips in both modes; filter field height still 40 and floated label style; header texts, callbacks, export disabled; add/edit inline errors, year rule, error banner keeps input, busy + single submit + close true, edit pre-fill, Cancel; remove dialog choices, focus on Cancel, Delete-only for unregistered, Esc).
- `flutter test` (full suite): **925 passed** (894 + 31), 3 skipped, 0 failed.
- Not yet done: live responsive QA (Phase D) and live functional regression (Phase E).

**Owner decision (2026-10-14):** C accepted including the smaller height saving (C2.2 — accepted as is). Phase D authorized. One test roster record allowed for Phase E.

---

## D. Responsive QA (2026-10-14)

**Method (actually tested):** `flutter build web --release`, served locally, headless Chrome via DevTools protocol, live Supabase, signed in as `admin@gmail.com`. Viewport set with device-metrics override; screenshots viewed one by one. Interactions done with scripted mouse/keyboard events. **No data was written** — every dialog was cancelled or closed with Esc; the one validation check used an empty Full name so the save could not run.

### D1. Viewports

| Viewport | Result |
|---|---|
| 1920×1080 | Single-row toolbar; all 8 rows visible; columns readable; full emails shown; empty table area below rows (8 records only). Pass |
| 1600×900 | Single-row toolbar; all 8 rows; no truncation. Pass |
| 1440×900 | Single-row toolbar; all 8 rows; long email truncated with ellipsis. Pass |
| 1366×768 | Single-row toolbar; labels readable; Batch and Tracer columns; "Page 1 of 1"; 6 rows fully visible (same count as before — net saving ≈ 16 px, accepted in C2.2). Measured from screenshot: toolbar ≈ 60 px. Search hint truncated ("Search by name, ID number, cour…") — see D3.1. Pass with note |
| 1024×768 (not a reference size; sidebar collapses) | Two-row toolbar (as designed); table used; **NAME column truncates names to ~9 characters** ("Catherine…", "Kevin Mat…") because the two new fixed columns take its space — see D3.2 |

### D2. Interactions at 1366×768 (live, read-only)

| Check | Result |
|---|---|
| Email hover tooltip | Full address shown; row hover highlight. Pass |
| "Show deactivated" toggle | Checkbox ticks; "Including deactivated" chip + Reset appear in the chip row; total stays 8 (no deactivated records live). Pass |
| Reset | Clears toggle, chip row disappears. Pass |
| Course filter | Menu lists 5 courses; BTLED-ICT → "Showing 2 of 8", chip "Course: BTLED-ICT", footer "Showing 1–2 of 2". Pass |
| No-match state | Search "zzqqxx" → `AdminStateView` "No matches" + "Clear filters"; both chips shown; focus ring on search visible. Clear filters restores all 8. Pass |
| Row ⋯ menu | View details / Edit roster entry / Delete / deactivate. Pass |
| Edit dialog | Radius 16 surface, icon title, fields pre-filled; empty Full name + Save → inline "Enter the full name.", dialog stays open, no overlap; Cancel closes, row unchanged. Pass |
| Remove dialog — unregistered | "Delete roster entry?", Cancel (focused) + red Delete; Esc closes, no change. Pass |
| Remove dialog — registered | "Remove registered alumni?", full explanation, Cancel / Deactivate / red Remove account; Esc closes. Pass |
| Add chooser → Add manually | Chooser opens; "Add to official roster" form, empty fields, Course defaults to BSIT; Esc closes. Pass |
| CHED export dialog | Live preview 8 / 3 / 5, Export ZIP (3); Cancel closes. Pass — see D3.3 |
| Refresh | Spinner inside the refresh button; table stays on screen. Pass |

### D3. Findings (not fixed — owner decision needed)

1. **Search hint truncated at 1366** (single-row toolbar). Option: shorter hint, e.g. "Search name, ID, course, email…" (wording change).
2. **1024×768 name truncation** (regression from D1 columns; 1024 is outside the master's reference sizes). Tried switching to card rows below 1000 px — rejected and reverted: the card layout at that width is the stacked phone layout (one record per screen). Options: (a) accept (not a reference size); (b) narrower fixed columns below ~1100 px table width (Directory-only, ~44 px back to NAME — partial help); (c) show email as a second line under the name and drop the EMAIL column below ~1100 px (layout change).
3. **Add chooser and CHED export dialogs have a lavender (Material 3 tint) background**, while the new Edit/Remove dialogs are white; CHED "Cancel" outline is barely visible on that tint. Pre-existing (not changed in C). Option: `backgroundColor: AdminColors.card` + `surfaceTintColor: transparent` on those two Directory dialogs (feature-local, 2 lines each).

### D4. Other screens using `DirectoryFilterField` (SH2 floating-label change), 1366×768

Surveys, Reports & Analytics (Overview and Tracer cohort filters), Program Insights (list and History), Events, Announcements, Forum, Job Postings, Activity Logs: floated labels readable (≈ 11 px), no clipping or overlap, field heights unchanged. Activity Logs: 200 records → "Page 1 of 8" (correct). Survey Responses page count: not re-checked live (covered by `adminPageCount` unit tests).

### D5. Not tested

Keyboard-only full tab order; screen reader; Import from file (would write data); real save / deactivate / reactivate / delete (Phase E).

**Owner decision (2026-10-14):** D3.1 shorten hint; D3.2 accept (1024 not a reference size); D3.3 make both dialogs white. Apply, re-check, then Phase E with one test record.

### D6. Follow-up fixes (applied 2026-10-14)

| Item | Change | Verified |
|---|---|---|
| D3.1 | Directory page passes `searchHint: 'Search name, ID, course, email…'` to `DirectoryToolbarCard` (shared default unchanged, other screens unaffected) | Live 1366×768: hint fully visible |
| D3.3 | Add chooser and CHED export `Dialog`s: `backgroundColor: AdminColors.card`, `surfaceTintColor: Colors.transparent` | Live: both white; CHED Cancel outline visible |

`flutter analyze lib/features/admin/roster`: no issues. `flutter test test/admin_directory`: 31 passed.

---

## E. Functional regression (2026-10-14)

**Method (actually tested):** same live setup as D (release build, headless Chrome, live Supabase, `admin@gmail.com`, 1366×768). One test roster record, as allowed by the owner: **"QA Test Record", BSIT, ID `QATEST0001`, year 2020 → 2021**. The record was **deleted at the end**; roster back to 8 (3 registered / 5 not registered).

### E1. Results

| # | Check | Result |
|---|---|---|
| 1 | Add manually (chooser → form → Add member) | "Saving…" with fields, × and Cancel disabled; green SnackBar "QA Test Record added to roster"; list reloads; On roster 8 → 9, Not registered 5 → 6; "Showing 9 of 9", footer "Showing 1–9 of 9", "Page 1 of 1". Pass |
| 2 | Duplicate (same ID in lower case + BSIT) | Dialog stays open; red banner "An alumni with this ID number and course already exists."; typed values kept; nothing written. Pass (F3, F4a) |
| 3 | Search "QA Test" | 1 of 9; chip shown; Batch column shows 2020. Pass |
| 4 | Edit (year 2020 → 2021) | Fields pre-filled; "Roster entry updated"; Batch shows 2021; search kept after reload. Pass |
| 5 | View details | Member Detail opens (roster record: name, course, ID, Batch 2021, added date); Activity logs tab lists UPDATE_ROSTER_MEMBER and CREATE_ROSTER_MEMBER (SUCCESS); × returns to the list with search kept. Pass |
| 6 | Delete (unregistered → "Delete roster entry?" → Delete) | "QA Test Record removed from roster"; counts back to 8 / 5; no-match state with Clear filters. Pass |
| 7 | Audit trail (Activity Logs screen) | DELETE_ROSTER "delete: QA Test Record", UPDATE_ROSTER_MEMBER, CREATE_ROSTER_MEMBER — all Admin, SUCCESS. Pass |
| 8 | KPI tap "Not registered" | Registration filter set; chip "Registration: Not Registered"; 5 of 8. Pass |
| 9 | Rows per page 25 → 50 → 25 | Selector works; "Page 1 of 1" throughout. Pass |
| 10 | Sort Name Z–A | Order reversed (Ralph … Juan …). Pass |
| 11 | Filters, Show deactivated, Reset, Clear filters, Refresh, all dialogs (open/cancel) | Covered live in D2. Pass |

### E2. Not tested live (and why)

- **Deactivate / Reactivate (F2, F4b, F4c):** the UI offers Deactivate only for members with a registered app account; the test record is unregistered, and no registered test account exists. Live data has no deactivated members, so the Reactivate menu item cannot appear. Covered by widget tests and code inspection only.
- **Remove registered account:** destructive (anonymizes a real account); not run.
- **Import from file:** would write rows; not run (code path unchanged except dialog styling).
- **CHED export ZIP download:** dialog and live preview checked; actual export not run (no data change, but writes an audit row and downloads files).
- **Friendly error messages for load/save failures (F4a):** only the duplicate message was triggered live; network/service failures covered by widget tests.
- **Multi-page pagination:** only 8 rows live and minimum page size is 25; covered by `adminPageCount` unit tests; Activity Logs multi-page ("Page 1 of 8") seen live in D4.

### E3. Observations (no change made)

- CHED export dialog ignores Esc and outside clicks (`barrierDismissible: false`) — original behavior, unchanged.
- Changing Sort does not add a chip (sort is not a filter) — original behavior.

### E4. Data written during E

1 roster row created → updated → deleted. 3 activity-log rows (create, update, delete) remain, as normal audit history. Each sign-in also adds an "Admin logged in" row.

---

## F. Completion report (2026-10-14) — signed off by owner 2026-10-14 (screen closed)

**Screen:** Alumni Directory (menu index 2) — list, toolbar, table/card rows, add/edit, remove, add chooser, CHED export, import-issues and progress dialogs. Member Detail panel not redesigned (separate screen).

### F1. Files changed

| File | Scope |
|---|---|
| `lib/shared/widgets/admin/admin_pagination.dart` | One line: `adminPageCount` uses integer division (SH1, global) |
| `lib/features/admin/roster/widgets/alumni_directory_ui.dart` | Header text/buttons, `DirectoryKpiRow`, toolbar opt-in single row (SH3), filter floating label (SH2, global), table columns + Batch/Tracer/email tooltip, card Batch item |
| `lib/features/admin/roster/widgets/admin_alumni_directory_dialogs.dart` | New add/edit and remove dialogs; chooser + CHED dialog titles, buttons, white background; shared title/shape helpers for the two `AlertDialog`s |
| `lib/features/admin/roster/presentation/admin_alumni_directory_page.dart` | KPI cards, Show deactivated, in-dialog save, friendly errors, reactivate try/catch + audit row, refresh busy state, empty states, SnackBar colors, Directory search hint |
| `test/admin_directory/` (new) | `pagination_test.dart`, `directory_widgets_test.dart`, `directory_dialogs_test.dart` — 31 tests |

### F2. Components reused / created

- **Reused (0c / existing):** `AdminKpiCard` (dense), `AdminStateView.empty`, `AdminButtonStyles` (filled / outlined / danger), `showAdminDialogSurface`, `AdminColors`, `AdminDataTable` / `AdminDataRow` / `AdminTableBadge`, `AdminPaginationBar`, `DirectoryToolbarCard`, `DirectoryFilterField`, `DirectoryResultsBar`.
- **Created (feature-local):** `DirectoryKpiRow`, `RosterEntryDialog` + `showRosterEntryDialog` + `RosterEntryInput`, `RosterRemoveDialog` + `showRosterRemoveDialog` + `RosterRemoveAction`, `directoryDialogTitle`, `directoryAlertDialogShape`.
- **Shared components changed:** `adminPageCount` (fix), `DirectoryFilterField.decoration` (label size), `DirectoryToolbarCard.singleRowMinWidth` (opt-in, default off).

### F3. UI/UX changes

Title "Alumni Directory" + accurate subtitle; "Export CHED GTS" with tooltip; 4 KPI cards on the shared card in one equal-height row; single-row toolbar at ≥ 1000 px content width with readable filter labels; Batch and Tracer columns, full email on hover; "Show deactivated" toggle with chip; dialogs on one style (radius 16, white, icon titles, shared buttons); inline validation and error banner in add/edit; friendly error text; Refresh spinner; shared empty states; correct page count.

### F4. Responsive

1920 / 1600 / 1440 / 1366: single-row toolbar, table, no overflow. 1024: two-row toolbar, table (names truncate — accepted). < 900 px content: card rows (unchanged). Breakpoints unchanged.

### F5. Functionality preserved

All Supabase queries and writes, RLS, roles, filter/sort logic, debounce, KPI tap-to-filter, Member Detail hand-over, keep-alive/cache, import parsing, CHED export rules, delete vs remove-account rules, existing audit rows. Service, repository and model files untouched. Approved behavior changes: F1 page count, F2 show deactivated, F3 in-dialog validation/save, F4a friendly errors, F4b/F4c reactivate error handling + audit row, F5 refresh busy state.

### F6. Tests actually performed

- `flutter analyze` (admin scope + admin tests): 19 info, all pre-existing; Directory files and tests: **no issues**.
- `flutter test` (full suite, final code): **925 passed, 3 skipped, 0 failed**; `test/admin_directory`: 31 passed.
- Live browser QA (§D): 5 viewports, interactions, 8 other screens using the filter field.
- Live regression with one test record (§E): add, duplicate, search, edit, detail, delete, audit rows, KPI tap, rows per page, sort — all pass; record deleted.

### F7. Issues found / remaining

- Names truncate at 1024×768 (accepted; non-reference size).
- Not verified live: deactivate, reactivate, remove registered account, import, CHED ZIP export, network-error messages (widget tests / code inspection only — §E2).
- Original behavior kept: CHED export dialog ignores Esc / outside click.

### F8. Approved deviations

Dialog radius 16 (not 12); net height saving ≈ 16 px (not ≈ 50 px); Reset at end of the chip row in single-row mode; × disabled while saving; Directory-only search hint; chooser and CHED dialogs white.

**Owner decision (2026-10-14):** Alumni Directory **signed off as implemented** — screen closed. Member Detail Phase A audit authorized.
