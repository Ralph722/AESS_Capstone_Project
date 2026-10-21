# AESS Admin Portal — Initial Audit & Redesign Plan

Status: **PROPOSED — awaiting approval.** No production UI was changed during this audit.
Date: 2026-10-14. Process rules: [`AESS_ADMIN_REDESIGN_MASTER.md`](AESS_ADMIN_REDESIGN_MASTER.md). Live status: [`AESS_ADMIN_REDESIGN_PROGRESS.md`](AESS_ADMIN_REDESIGN_PROGRESS.md).

Evidence basis: direct inspection of the reference image and of the files cited below (routing, shell, shared admin widgets, per-feature theme classes, entry points of every admin module), plus repo-wide `rg` counts. Screens marked "light inspection" had their header/layout/tab code read, not every line. Nothing was run in a browser during this audit.

---

## 1. Reference Design Principles

Recorded in [`AESS_ADMIN_REDESIGN_MASTER.md` Part II](AESS_ADMIN_REDESIGN_MASTER.md#part-ii--reference-design-principles) (R1–R12). Summary: calm grey canvas with white cards; strict equal-gutter grid (4 → 2 → 3 cards per row); small accent card titles with large bold values plus a caption; compact charts inside the card they explain with dot legends; a restrained two-color palette used consistently; only one emphasized card; label/value pair grids for secondary figures; underline section tabs; quiet sidebar with one active indicator; identity cluster top-right; three rows of useful content above the fold.

---

## 2. Complete Admin Screen Inventory

### How admin "routes" actually work

There are **no named/URL routes** inside the admin portal. `AuthGate` (`lib/features/auth/presentation/auth_gate.dart:169`) and `LoginScreen` (`login_page.dart:273`) open `AdminDashboardWeb` for `users.role = 'admin'`. `AdminDashboardWeb` (`lib/features/admin/dashboard/presentation/admin_dashboard_page.dart`) is one `Scaffold` = sidebar + top header + an `IndexedStack` keyed by **menu index**. Indices: `0,1,2,4,5,6,7,9,10,11,12,13,14,15` (3 and 8 are unused legacy gaps). Sub-screens open as **in-page panels** (state switch inside the module), **dialogs/side panels** (`showAdminDialogSurface` / `showAdminSidePanel`), or, in two cases, a pushed `MaterialPageRoute`.

Sidebar groups (from `kAdminNavSections`, `admin_dashboard_shell.dart:124`): **Overview** (Dashboard) · **Alumni** (Alumni Directory, Surveys, Reports & Analytics, Program Insights) · **Community** (Events, Announcements, Forum, Messages) · **Careers** (Job Postings) · **System** (Activity Logs, Archives, Feedback, AI Assistant).

### Inventory

LOC = approximate lines of presentation code (screen + its dedicated widgets). Complexity reflects size, number of interactions, and regression risk.

| # | Screen | Actual Route | Purpose | Current Layout | Shared Components | Complexity |
|---|---|---|---|---|---|---|
| G1 | **Admin shell** (sidebar + top header) | `AdminDashboardWeb` wrapper for all indices | Navigation, global search, Ctrl/⌘ K command palette, Quick Actions, notifications panel, account menu, logout | Navy gradient sidebar 264px / 72px mini-rail (auto-collapses < 1100px); white header with right-aligned controls only (no page title) | `kAdminNavSections`, `kAdminQuickActions`, private `_AdminSidebarLayout`/`_AdminChrome` tokens, `PortalTheme` (import), `NotificationService` streams | Very high (3,712 + 490 LOC; realtime listeners, push sync, notification routing) |
| G2 | Account dialogs: My profile · Change password · Help | Profile menu / command palette (`_kChangePasswordCommand = -1`) | View identity/role, change password, help text | Default `AlertDialog`s; change-password uses `ChangePasswordForm` | `change_password_form.dart`, `showAuthFeedback` | Low |
| G3 | Notification Preferences | Pushed `MaterialPageRoute` from notifications panel | Per-type notification settings | Full-screen route (leaves the shell) | `NotificationPreferencesScreen` (shared with alumni app) | Low–Medium (light inspection) |
| 1 | **Dashboard** | Index 0 → `AdminDashboardHome` | At-a-glance health: roster, tracer, survey, employment KPIs; engagement trend; community; quick actions; active events; recent audit activity | Navy gradient banner (date + 3 stats) → 4 KPI cards → 3-column fixed-height body (engagement + community / quick-action grid / feed panels). Non-scrolling "single screen" mode when content ≥ 900 × 520 | `DashboardCompactKpi`, `DashboardPanel`, `DashboardQuickAction`, `DashboardEngagementChart`, `AdminDashboardHomeSkeleton`, `AdminDensity` | Medium (691 + 599 + 255 LOC; data computed in `admin_dashboard_page.dart`) |
| 2 | **Alumni Directory** (Official Alumni Roster) | Index 2 → `AdminAlumniMembersScreen` (10-line wrapper) → `admin_alumni_directory_page.dart` | Search/filter roster, add/import/export, deactivate/delete, open member | `DirectoryPageHeader` → `DirectoryStatsGrid` → `DirectoryToolbarCard` → table (wide) / cards (narrow) + pagination; detail opens as split panel | `AdminPageHeader`, `AdminDataTable`, `AdminPaginationBar`, all `Directory*` widgets, `AdminDirectoryListSkeleton` | High (1,141 + 2,627 + 559 LOC). Already the **reference implementation** of the density rule |
| 3 | Alumni Member Detail | In-page panel of index 2 (`AdminAlumniMemberDetailPanel`) | Roster record, linked GTS profile, tracer response snapshots, activity | Header card + `TabBar` (Profile info · Tracer responses · Activity logs) | `MemberDetailHeader/Section/InfoRow/ActivityTile`, `EmploymentStatusBanner`, `AdminMemberDetailSkeleton` | High (1,382 LOC) |
| 4 | Add alumni chooser / import / edit dialogs | Dialogs from index 2 (`showAlumniAddChooserDialog`, …) | Add single member, Excel import, edit | Dialogs | `showAdminDialogSurface`, `alumni_roster_import_service.dart` | Medium (559 LOC) |
| 5 | **Surveys** list | Index 10 → `AdminSurveysScreen` | Manage tracer surveys: search, status/kind filters, sort, card actions (edit, responses, duplicate, export, remind, re-assign, close, archive, delete) | `SurveyPageHeader` → toolbar → card rows | `SurveyListCard`, `SurveyStatusChip`, `SurveyKindChip`, `DirectoryToolbarCard`, `AdminSurveyTheme` | Medium (842 + shared 1,117 LOC) |
| 6 | Survey Editor (incl. CHED GTS template picker, preview) | In-page panel of index 10 (`AdminSurveyEditorScreen`, `admin_surveys_page.dart:809`) | Create/edit survey details, schedule, audience, questions; Save / Publish / Re-assign | `SurveyEditorScaffold` + sticky action bar; preview side-by-side on wide screens | `SurveyQuestionEditor`, `AdminSurveyTemplatePicker`, `AdminSurveyPreviewSheet`, `admin_form_fields.dart` | High (1,190 + 784 + 328 + 226 LOC) |
| 7 | Survey Responses workspace | In-page panel of index 10 (`AdminSurveyResponsesScreen`, `:820`) | Funnel/analytics, pending (reminders), submitted (view answers, per-response PDF/Excel/print), exports, formal report, timeline | `SurveyResponsesWorkspaceHeader` + `SurveyWorkspaceSegmentedNav` (Overview · Pending · Submitted) + table + side sheets | `AdminDataTable`, `AdminPaginationBar`, `AdminSearchField`, `AdminSurveyAnalyticsPanel`, export / formal-report / detail / timeline dialogs | Very high (3,046 + 904 + 984 + 358 + 527 + 511 LOC) |
| 8 | **Reports & Analytics** (GTS analytics) | Index 9 → `AdminReportsScreen` | Tabs: **Overview** (system pulse) · **Tracer** (employment outcomes) · **Survey** (response health) · **Downloads** (report packs) · **Builder** (CHED GTS report builder: summary/charts mode + alumni list mode, saved reports, wave comparison) | `ReportsPageHeader` (own header) → pinned custom `TabBar` → cohort filter bar (Tracer/Survey tabs) → bento grids of KPI + charts | `ReportsKpiCard`, `reports_bento.dart`, `AdminReportsTheme`, `ReportsBentoPalette`, `GtsReportBuilder`, `GtsAlumniListPanel`, `GtsSavedReportsBar`, `ReportsDownloadsPanel` | Very high (4,482 LOC page + ~7k LOC widgets; widget tests exist) |
| 9 | **Program Insights** (DSS) flag list | Index 15 → `AdminDssScreen` | Review system-generated findings: filter by status/evidence/due, sort by priority/severity/sample | `DssPageHeader` (History / Settings actions) → toolbar → `DssFlagListCard` rows; `_DssPanel { list, detail, history, settings }` switches in-page | `DirectoryToolbarCard`, `Dss*Chip`, `DssInsightBanner`, `AdminDssTheme` | Medium (875 + 461 LOC) |
| 10 | DSS Flag detail | In-page panel of index 15 (`AdminDssDetailPanel`) | Evidence, priority, accountability, actions (send reminders, send matching jobs, announcement), outcomes | Long single column of sections/cards | `DssOutcomeCard`, `dss_accountability_cards.dart`, `dss_action_dialogs.dart`, `showAdminAnnouncementEditor` | Very high (2,353 + 842 + 619 + 353 LOC) |
| 11 | DSS History | In-page panel of index 15 | Past evaluations/flags | List | `AdminDssTheme` | Medium (635 LOC) |
| 12 | DSS Settings | In-page panel of index 15 | DSS thresholds/policy settings | Form | `AdminDssTheme` | Low–Medium (337 LOC) |
| 13 | **Events** | Index 1 → `AdminEventsScreen` | CRUD, archive/cancel/delete events; List ↔ Calendar views | `AdminPageHeader` → KPI strip → toolbar → card rows or month calendar | `DirectoryToolbarCard`, `EventsMonthCalendar`, `AdminEventsListSkeleton`, `AdminEventTheme` | High (1,033 LOC) |
| 14 | Event editor | Dialog from index 1 (`showAdminEventEditorDialog`) | Create/edit event | Dialog form with `AdminFormSection`s | `showAdminDialogSurface`, `AdminFormSection` | Medium (740 LOC) |
| 15 | Event detail | Side panel from index 1 (`showAdminEventDetail`) | Tabs: Overview · Agenda · Attendance · Comments · Analytics | Side panel + `TabBar` | `showAdminSidePanel` | Medium (680 LOC) |
| 16 | Event comments moderation | Dialog (from event detail **and** from notification panel) | Moderate comments/replies | Dialog; uses off-brand navy + `withOpacity` | `AdminEventCommentsDialog` | Medium (567 LOC) |
| 17 | **Announcements** + editor | Index 11 → `AdminAnnouncementsScreen`; editor = side panel (`showAdminAnnouncementEditor`, also opened from DSS detail) | List by status; compose with audience (programs + batch years) and audience count; Save draft / Publish; archive/delete | `AdminPageHeader` → toolbar → card rows; editor side panel | `DirectoryToolbarCard`, `AdminAnnouncementTheme` | Medium (440 + 783 + 282 LOC) |
| 18 | **Forum Moderation** | Index 12 → `AdminForumScreen` | Modes: Discussions · Reports; lock/pin/delete topics; handle reports | `AdminPageHeader` → mode switch → toolbar → list | `DirectoryToolbarCard`, `AdminForumTheme` | Medium (1,089 + 93 LOC) |
| 19 | **Messages** | Index 6 → `AdminMessagesScreen(hideAppBar: true)` (`lib/features/messages/…`) | All alumni conversations; search/filter/sort; send text/image; read state; alumni profile pane | Three panes: inbox 340px · thread · profile 280px (tablet: inbox 300px) | `AdminMessageTheme`, `AdminInboxToolbar`, `AdminMessagesLayoutSkeleton`; shares models/services with alumni messaging | High (1,150+ LOC page + ~650 LOC UI; realtime) — light inspection |
| 20 | **Job Postings** | Index 5 → `AdminJobManagement` | Manage postings: status filters, add/edit (dialog), archive/activate, delete, interested alumni → Messages deep-link | `AdminPageHeader` → KPI strip → toolbar → `AdminJobCard` rows | `DirectoryToolbarCard`, `showAdminDialogSurface`, `AdminJobTheme`, `MessageOpenBus` | Medium–High (632 + 1,634 LOC) |
| 21 | **Activity Logs** | Index 7 → `AdminActivityLogsScreen` | Filterable audit trail (action, user, status, date range, search) | `AdminPageHeader` → filters → `AdminDataTable` + `AdminPaginationBar` | `AdminSearchField`, `DirectoryDateFilterChip`, `AdminActivityLogSkeleton` | Medium (753 LOC) |
| 22 | **Archives** | Index 4 → `AdminArchivesScreen` (rebuilt on every visit) | Archived Events · Job Postings · Surveys: restore / permanently delete | One white card with a **navy header block** containing pill tabs; legacy styling (8 forbidden-hex uses, 43 Material color uses, 7 `withOpacity`) | Almost none of the shared admin kit | Medium (928 LOC) |
| 23 | **Feedback** list | Index 14 → `AdminFeedbackScreen` | Alumni feedback tickets; filter by status and category | Ad-hoc 22px title + "N open" pill → two chip rows → `Card(ListTile)` list; shows raw `Error: ${snapshot.error}` | `DirectoryToolbarFilterChip`, `PortalCardListSkeleton` (alumni skeleton) | Low (189 LOC) |
| 24 | Feedback detail | Pushed full-screen `MaterialPageRoute` (from list and from notification panel) | Read ticket, change status, write admin response | Full-screen `Scaffold` + `AppBar` (**sidebar/header disappear**) | `DropdownButtonFormField` | Low (250 LOC) |
| 25 | **AI Assistant** (admin) | Index 13 → `AiAssistantScreen(isAdmin: true)` (`lib/features/ai/…`) | Chat with admin-oriented prompt via `ai-assist` Edge Function | **Alumni-portal chrome**: `PortalAppBar` "Admin AI Assistant", `PortalContentFrame` chat column | `PortalTheme`, `PortalAppBar` (shared with alumni app) | Low (≈370 LOC, shared) |

Not admin screens (excluded): alumni `MainNavigation` tabs, onboarding, alumni survey taking, alumni profile. The CHED GTS PDF export (`ched_gts_pdf_export/`) is a service layer invoked from Survey Responses/Reports, not a screen.

**Documentation discrepancy:** `docs/full-system-overview.md` §6 is stale — it omits index 15 (Program Insights), names the sidebar group "Alumni & tracer", and lists Reports sections as "Overview · Alumni & tracer · Surveys · Export" whereas code has Overview · Tracer · Survey · Downloads · Builder. The code above is authoritative.

---

## 3. Current Shared Components

| Component | File | Used by |
|---|---|---|
| `AdminDensity` (spacing, control, table, KPI, form tokens; `shellPaddingForWidth`, `pageInsetsForWidth`) | `lib/shared/widgets/admin/admin_density.dart` | Shell and nearly every admin screen |
| `AdminPageHeader` (title, subtitle, actions, `below`) | `lib/shared/widgets/admin/admin_page_header.dart` | Directory, Surveys, DSS, Announcements, Activity Logs, Forum, Events, Jobs (8). **Not** Dashboard, Reports, Archives, Feedback, Messages, AI |
| `AdminDataTable`, `AdminDataHeader`, `AdminDataRow`, `AdminTableBadge`, `AdminTableIdentityCell`, `AdminTableTextCell`, `AdminTableTheme` | `lib/shared/widgets/admin/admin_data_table.dart` | Directory, Survey Responses, Activity Logs |
| `AdminPaginationBar` | `admin_pagination.dart` | Directory, Survey Responses, Activity Logs |
| `AdminSearchField`, `AdminHoverShell` | `admin_search_field.dart` | Survey Responses, Activity Logs |
| `AdminFormSection`, `AdminFormRow`, `AdminFormActionsBar` | `admin_form_layout.dart` | Event editor, alumni-side `add_job_dialog.dart` |
| `showAdminDialogSurface`, `showAdminSidePanel`, `showAdminOptionPicker` | `admin_surface.dart` | Jobs, Events, Announcements, Directory, Surveys (5 dialogs) **and alumni-side** `forum_composer_page.dart`, `message_reaction_picker.dart` |
| Skeletons (`AdminDashboardHomeSkeleton`, `AdminDirectoryListSkeleton`, `AdminEventsListSkeleton`, `AdminReportsSkeleton`, `AdminActivityLogSkeleton`, `AdminArchiveListSkeleton`, `AdminFormEditorSkeleton`, `AdminMessagesLayoutSkeleton`, `SurveyResponsesWorkspaceSkeleton`, `AdminMemberDetailSkeleton`) | `admin_skeletons.dart` | Most screens |
| Directory kit: `DirectoryToolbarCard`, `DirectoryFilterField`, `DirectoryToolbarFilterChip`, `DirectoryActiveFilterChip`, `DirectoryDate/DateRange/TimeFilterChip`, `DirectoryStatCard`, `DirectoryStatsGrid`, `DirectoryResultsBar`, `DirectoryEmptyState` | `lib/features/admin/roster/widgets/alumni_directory_ui.dart` (feature folder) | Toolbar used by Jobs, Events, DSS, Announcements, Forum, Surveys, Directory; filter chips by Feedback, Activity Logs |
| `AdminDirectoryTheme` (de-facto admin color/radius/shadow tokens) | same file | Aliased by 9 feature theme classes (below) |
| Shell-only: `kAdminNavSections`, `kAdminQuickActions`, `AdminDashboardSidebar`, `AdminDashboardTopHeader`, command palette | `admin_dashboard_shell.dart` | Shell |
| Alumni-portal kit used in admin: `PortalTheme`, `PortalAppBar`, `PortalCardListSkeleton`, `PortalEmptyState`/`PortalErrorState`, `PortalOverlayTheme` (suspended while admin is mounted) | `lib/shared/widgets/user/*` | AI Assistant, Feedback, shell imports |
| `AessLogo` (SVG wordmark for light backgrounds) | `lib/shared/widgets/aess_logo.dart` | Not used in admin shell (shell uses `assets/images/system_logo.png`) |

---

## 4. Existing Design System (as implemented)

**Brand source:** `UstpColors` (`lib/core/constants/ustp_colors.dart`) — Blue `#1A1851`, Gold `#FCB315`, Black `#151515`, Grey `#B3B3B3`, Orange `#FF6418`, Light orange `#FF9718`, Dark navy `#031C2E`, Mid blue `#0D4A77`, Sky blue `#329DEA`. Repo rule `.cursor/rules/ustp-brand-colors.mdc` forbids `0xFF090A4F`/`0xFFFFD700` as navy/gold and forbids hard-coded brand hex in widgets.

**Admin tokens actually used:**

| Concern | Where | Values |
|---|---|---|
| Colors | `AdminDirectoryTheme` | primary `#1A1851` (literal, equals USTP Blue), gold **`#FBBF24`** (not USTP Gold), background `#F8FAFC`, surface `#F1F5F9`, card white, border `#E5E7EB`, text `#0F172A` / `#64748B` / `#94A3B8`, success `#16A34A`/`#DCFCE7`, warning `#EA580C`/`#FFF7ED`, info `#1A1851`/`#E8E7F2`, danger `#DC2626`/`#FEE2E2` |
| Colors (duplicate literals) | `AdminTableTheme` | Same values re-typed as literals |
| Shell colors | `_AdminSidebarLayout`, `_AdminChrome`, `AdminDashboardWeb` | navy **`#090A4F`**, navyDeep `#1A1B5E`, gold **`#FFD700`** (all forbidden), shell background `#F4F6FA` (differs from `#F8FAFC`) |
| Chart palette | `ReportsBentoPalette` | `#1A1851`, `#4F46E5`, `#818CF8`, `#FBBF24`, `#0EA5E9`, `#C7D2FE`, `#94A3B8` (indigo/sky — not USTP) |
| Spacing | `AdminDensity` | 8 / 12 / 16 / 24; sectionGap 16; gridGap 12; cardPadding 12; listItemGap 8 |
| Radius | `AdminDirectoryTheme` | 8 / 12 / 16; cards use 16; shell panels 10; dialogs 16; dashboard 12 |
| Shadows | `AdminDirectoryTheme.cardShadow` | `#0F172A` @ 5%, blur 10, y 2 (hover 10%, blur 20, y 6) |
| Type | `AdminDensity` | page title 20 / subtitle 13 / section 14 / KPI value 22 / KPI label 12. In practice: titles 18, 20, 22; tab labels 13 vs 13.5; no shared `TextStyle`s |
| Controls | `AdminDensity` / directory | button 36, toolbar control 40, header control 38, min tap 36 |
| Breakpoints | various | sidebar auto-collapse < 1100; header compact < 1100, tight < 900; `AdminPageHeader` narrow < 768; stats 4-col ≥ 900, 2-col ≥ 560; desktop split ≥ 900; dialog vs sheet ≥ 700 |

**Feature theme classes** (each mostly re-exports `AdminDirectoryTheme`): `AdminSurveyTheme`, `AdminEventTheme`, `AdminJobTheme`, `AdminDssTheme`, `AdminForumTheme`, `AdminAnnouncementTheme`, `AdminReportsTheme`, `AdminMessageTheme`, plus `AdminTableTheme` and `ReportsBentoPalette`. Button styles are duplicated per feature (`eventFilledButtonStyle`, `jobFilledButtonStyle`, `dssFilledButtonStyle`, `forumFilledButtonStyle`, … identical definitions).

---

## 5. Current UI/UX Problems

Ordered by impact. Counts are from `rg` across `lib/features/admin`, `lib/shared/widgets/admin`, and the admin message/AI files.

1. **Off-brand colors in the most visible chrome.** The sidebar, avatar, dashboard banner and KPI accents, Archives header, Activity Logs, Feedback, and event dialogs use forbidden `#090A4F` / `#FFD700` (46 matching lines in 12 files). `AdminDirectoryTheme.gold` is Tailwind amber `#FBBF24`, not USTP Gold. Dashboard KPIs use Material `Colors.indigo/teal/green`; Reports charts use indigo/sky. Result: two different navies and three golds on one screen.
2. **No single design-token home.** The de-facto token set lives in a feature folder (`roster/widgets/alumni_directory_ui.dart`); 10 feature classes re-alias it; `AdminTableTheme` re-types it; the shell has its own private tokens. 220+ lines with `Color(0x…)` literals and 230+ lines with Material `Colors.blue/orange/green/teal/indigo/…` across admin files.
3. **Header gives no location context.** `AdminDashboardTopHeader` starts with a `Spacer` — the left two-thirds of the bar is empty. The `AdminPageHeader` doc comment claims "the top-header title already signals location", but no such title exists. Page titles therefore live in 6 different header implementations.
4. **Inconsistent page headers.** `AdminPageHeader` (8 screens) vs `ReportsPageHeader` (Reports) vs gradient banner (Dashboard) vs navy block (Archives) vs ad-hoc 22px `Text` (Feedback) vs alumni `PortalAppBar` (AI Assistant) vs full-screen `AppBar` (Feedback detail).
5. **Five tab styles.** Reports pinned custom tabs; Survey workspace segmented nav (13.5/w700, label indicator); Member detail tabs (13/w600, full indicator); Event detail default `TabBar`; Archives pill tabs on navy.
6. **Duplicated widgets with drifting looks:** 3 KPI cards (`DirectoryStatCard`, `DashboardCompactKpi`, `ReportsKpiCard`, plus `DashboardMiniStat`/`DashboardStatChip`), 4+ empty states (`DirectoryEmptyState`, `SurveyEmptyState`, `ReportsSectionEmptyState`, `PortalEmptyState`, plain `Center(Text)`), 6 identical button-style helpers.
7. **Developer-facing error text.** About 70 lines in admin presentation files interpolate raw exceptions into UI text (regex count; a few may be log-only) (`'Error: ${snapshot.error}'`, `'Error loading dashboard metrics: $e'`), heaviest in Survey Responses (11), Surveys (8), Archives (7), Survey Editor (7), DSS detail (5).
8. **Dashboard specifics.** Roster and Registered counts appear twice (banner + KPI row); Quick Actions appear twice (header menu + 4-tile grid); fixed non-scrolling layout (`NeverScrollableScrollPhysics`) whenever content ≥ 900 × 520 — at 1366 × 768 this is likely to cramp the three body columns (to be verified in QA, not yet tested); the banner is decorative rather than actionable.
9. **Feedback detail leaves the shell.** Opening a ticket pushes a full-screen route; sidebar and header vanish, unlike every other module's in-page/side-panel detail.
10. **AI Assistant uses alumni chrome** (`PortalAppBar`, portal background), visually unlike every other admin page.
11. **Header search advertises unbuilt features**: "Alumni, events & surveys search coming soon".
12. **Archives is the least modernized screen**: legacy navy block header, pill tabs, `withOpacity`, generic `AlertDialog` confirmations titled "Delete Event" (vs "Delete event?" elsewhere).
13. **Contrast risks:** `textMuted #94A3B8` on white ≈ 2.6:1 and `warning #EA580C` on white ≈ 3.6:1 — both below WCAG AA for small text; muted is used for hints/captions widely.
14. **Shared tables/pagination under-adopted** (3 screens). Card rows are correct for task queues per `.cursor/rules/admin-ui-density.mdc`, but Feedback and Archives use neither the table nor the card-row kit.
15. **Dialog chrome inconsistent:** default `AlertDialog` (account dialogs, Archives, Feedback) vs `showAdminDialogSurface` (radius 16) vs shell panels (radius 10). `PortalOverlayTheme` is deliberately suspended in admin, so Material defaults leak through.
16. **Analyzer baseline:** 23 issues in admin/messages/AI code (deprecated `withOpacity`, deprecated `DropdownButtonFormField.value`, a missing widget key, …). Full list not captured; re-run before Phase 0 to record exactly.

Not problems (keep): density tokens and the Directory/Surveys pattern are sound; sidebar collapse, keyboard shortcuts, semantics labels, ESC-to-close surfaces and focus scopes are already thoughtfully implemented.

---

## 6. Proposed AESS Admin Design System

Principle: **evolve, don't replace.** Promote the existing `AdminDirectoryTheme` + `AdminDensity` into one shared admin token source built on `UstpColors`; keep every existing class name as an alias so no screen breaks; then migrate screens one at a time.

### 6.1 Colors (proposed token → value)

| Token | Value | Notes |
|---|---|---|
| `primary` | `UstpColors.blue` `#1A1851` | Unchanged value; reference the constant instead of a literal |
| `primaryTint` | `#E8E7F2` | Existing `infoBg`/`rowSelected`; selected rows, active nav background on light surfaces |
| `secondary` | `UstpColors.midBlue` `#0D4A77` | Secondary emphasis, links, second chart series |
| `accent` | `UstpColors.gold` `#FCB315` | Sparing: active sidebar indicator, single highlight; never body text on white |
| Chart series | blue `#1A1851`, mid blue `#0D4A77`, sky `#329DEA`, gold `#FCB315`, light orange `#FF9718`, orange `#FF6418`, grey `#B3B3B3` | USTP-only; fixed order so a series keeps its color everywhere |
| `pageBackground` | one value (proposed `#F4F6FA`, currently used by the shell) | Replaces the `#F4F6FA` / `#F8FAFC` split |
| `surface` / `surfaceMuted` | white / `#F1F5F9` | |
| `border` / `divider` | `#E5E7EB` | |
| `textPrimary` / `textSecondary` | `#0F172A` / `#64748B` | Secondary passes AA (≈4.8:1) |
| `textMuted` | `#94A3B8` | Restrict to placeholders/disabled; captions move to `textSecondary` (approval item) |
| success | `#16A34A` on `#DCFCE7` | Use `#15803D` for small text (AA) |
| warning | `#EA580C` on `#FFF7ED` | Use `#C2410C` for small text (AA) |
| danger | `#DC2626` on `#FEE2E2` | |
| info | `primary` on `primaryTint` | |
| Sidebar | `UstpColors.blue` → `UstpColors.darkNavy` (or flat blue), active = gold 3px indicator + white 8% tint | Replaces `#090A4F`/`#1A1B5E`/`#FFD700` |

Status is always shown with text or an icon as well as color.

### 6.2 Typography (Flutter default font, existing sizes consolidated)

| Role | Size / weight | Existing source |
|---|---|---|
| Page title | 20 / w700, -0.4 tracking | `AdminDensity.titleFontSize` |
| Page subtitle | 13 / w400, `textSecondary` | `subtitleFontSize` |
| Section title | 15 / w700 | new value between 14 and 16 (approval) |
| Card title | 13 / w600 `textPrimary` (reference R3 uses accent color — optional `primary`) | — |
| Body / table body | 13–14 / w400 | |
| Table header | 12 / w600 `textSecondary` | |
| Caption / helper | 12 / w400 `textSecondary` | |
| KPI value | 24 / w700 (22 in dense strips) | `kpiValueFontSize` 22 |
| KPI label | 12 / w600 | `kpiLabelFontSize` |
| Button | 13.5 / w600 | |
| Tab | 13.5 / w600 active, w500 inactive | unifies 13 vs 13.5 |

Minimum text size 12 for content; 11 only for badges/counters.

### 6.3 Shape, elevation, spacing

Radius: 8 controls/chips/buttons · 12 cards and panels · 16 dialogs/side panels. Cards: white + 1px `border` + `cardShadow` (existing). Spacing: keep `AdminDensity` (8/12/16/24); page gutter 16; card padding 16 for KPI/chart cards (12 for dense list rows).

### 6.4 Component set (reuse first)

| Component | Proposal | Built from |
|---|---|---|
| Page header | `AdminPageHeader` everywhere; Reports/Dashboard/Archives/Feedback/AI adopt it | existing |
| Section header | small shared `AdminSectionHeader` (title, optional caption, trailing actions) | new, thin |
| Card | `AdminCard` (decoration helper = current `surfaceCard`) | existing helper |
| KPI card | one `AdminKpiCard` (title, value, unit, caption/denominator, optional trend, optional embedded chart, optional onTap) replacing the three variants via adapters | merge `ReportsKpiCard` + `DashboardCompactKpi` + `DirectoryStatCard` |
| Chart container | `AdminChartCard` (title, caption with population/period, chart-local toggles, dot legend) | from `reports_bento.dart` patterns |
| Tabs | one `AdminTabBar` (underline, icon optional, count badge) | from `SurveyWorkspaceSegmentedNav` |
| Toolbar / filters | keep `DirectoryToolbarCard` family; move to `shared/widgets/admin` (re-export from old path) | existing |
| Table + pagination | keep `AdminDataTable` / `AdminPaginationBar` | existing |
| Status badge / chip | `AdminTableBadge` generalized as `AdminStatusBadge` (text + color + optional icon) | existing |
| Buttons | one `AdminButtons.filled/outlined/text/danger` style set replacing six per-feature copies | existing duplicates |
| Dialogs, side panels, pickers | keep `showAdminDialogSurface` / `showAdminSidePanel`; add `showAdminConfirmDialog` (title ends with "?", destructive variant) | existing |
| States | `AdminStateView.loading/empty/error` — friendly message, optional retry where a retry already exists, technical detail behind "Show details" | consolidates 4+ empty states |
| Skeletons | keep `admin_skeletons.dart` | existing |

---

## 7. Recommended Sidebar and Header Improvements

**Sidebar** (`AdminDashboardSidebar`)
- Replace hard-coded navy/gold with `UstpColors`; flat brand navy (or subtle blue → dark navy) instead of the off-brand gradient.
- Active item: 3px gold leading indicator + light tint + bold label; inactive items 80% white; consistent outlined icons (current set is consistent already).
- Brand block: show AESS identity (currently "Alumni Portal / Admin"). `AessLogo` is navy-on-light, so on navy use the existing `system_logo.png` tile plus "AESS Admin" text — **wording requires approval**.
- Optional: live count badges on Messages / Surveys / Feedback using data the shell **already loads** (`metrics.unreadMessages`, `pendingSurveyAssignments`, `openFeedback`) — presentation only, but changes the sidebar's inputs (approval).
- Optional regrouping (approval): "Alumni" → **Alumni** (Directory) + **Tracer & Insights** (Surveys, Reports & Analytics, Program Insights). Indices unchanged.
- Keep collapse behavior, tooltips, semantics, Logout footer.

**Header** (`AdminDashboardTopHeader`)
- Add current page title on the left with a small section breadcrumb ("Alumni › Surveys"), derived from `kAdminNavSections` — fills the empty space and gives every page location context (reference R10). Page bodies then drop their duplicate large title or demote it (decided per screen in Phase B).
- Keep search, Ctrl/⌘ K, Quick Actions, notification bell, profile menu exactly as they work today.
- At ≥ 1440px show name + "Administrator" beside the avatar (reference R10).
- Remove or reword the "search coming soon" hint (approval).
- Fixed height ~56px, aligned with the sidebar brand block.

---

## 8. Recommended Screen Implementation Order

Order chosen by dependency (shared kit first), visibility, reuse value, and risk. GTS terminology mapping: "GTS / Tracer" = Surveys (official CHED GTS is a survey kind) and Member Detail tracer tab; "GTS Analytics" = Reports & Analytics (Tracer tab + Builder).

| Step | Scope | Why here |
|---|---|---|
| 0a | Tokens: shared admin theme on `UstpColors`, aliases kept | Everything depends on it; near-zero layout risk |
| 0b | Shell: sidebar + header | Visible on every screen; fixes brand drift once |
| 0c | Shared components: `AdminKpiCard`, `AdminChartCard`, `AdminTabBar`, `AdminSectionHeader`, `AdminStateView`, `showAdminConfirmDialog`, unified button styles | Needed by Dashboard/Reports/DSS; built once |
| 1 | Dashboard | Landing page, closest to reference; proves the KPI/chart patterns |
| 2 | Alumni Directory | Reference implementation — light alignment pass validates tokens |
| 3 | Alumni Member Detail | Same module; adopts shared tabs |
| 4 | Surveys list | GTS/Tracer core loop |
| 5 | Survey Editor | Forms; CHED GTS locked-question handling |
| 6 | Survey Responses | Largest table/export workflow; split into sub-phases (Overview / Pending / Submitted / export dialogs) |
| 7 | Reports & Analytics | GTS analytics; split by tab (Overview → Tracer → Survey → Downloads → Builder); widget tests guard Builder |
| 8 | Program Insights list | DSS; reuses KPI/chart/chips |
| 9 | DSS Flag detail, History, Settings | Highest DSS complexity after list patterns exist |
| 10 | Events (+ editor, detail, comments) | Community |
| 11 | Announcements (+ editor) | Small; reuses Events patterns |
| 12 | Job Postings | Reuses list patterns |
| 13 | Forum Moderation | |
| 14 | Messages | Realtime three-pane; shared with alumni messaging code |
| 15 | Feedback list + detail | Quick win; detail-in-shell needs approval |
| 16 | Activity Logs | Already uses table kit; light pass |
| 17 | Archives | Biggest visual debt but low usage; full restyle |
| 18 | AI Assistant (admin variant) | Must not alter alumni chat |
| 19 | Account dialogs + Notification Preferences | Final consistency sweep |

---

## 9. Phase-by-Phase Plan for Every Existing Admin Screen

Every screen follows **A audit → B proposal → C implement → D responsive QA → E functional regression → F completion report**, each gated by approval. Below: the screen-specific focus for each phase (A/B content) and the regression checklist for E.

| # | Screen | Phase A/B focus (likely proposal direction) | Phase E must re-verify |
|---|---|---|---|
| 1 | Dashboard | Remove duplication (banner vs KPIs, quick-action grid vs header menu — approval); 4 KPI cards with denominators; engagement trend chart card; "Needs attention" single emphasized card using existing attention counts; recent activity + active events side by side; scrollable layout with above-the-fold priority at 1366×768 | KPI taps navigate to the same indices; refresh; live unread/feedback updates; skeleton on first load |
| 2 | Alumni Directory | Token alignment only; header/toolbar/table rhythm consistent with new header; keep table/cards switch | Search, every filter, reset, sort, pagination, add/import/export, deactivate/delete, open detail, memory eviction on leave |
| 3 | Member Detail | Shared tabs; label/value grids (R7) for profile; tracer snapshots readable; activity list | Tabs, mark-viewed, tracer snapshot rendering, PDF export if present, close/back |
| 4 | Surveys list | Status/kind chips via shared badge; action menu grouping (routine vs destructive) | All card actions, filters, sort, catalog refresh listener |
| 5 | Survey Editor | Sectioned form (Details · Schedule · Audience · Questions), required markers, sticky actions, CHED-locked explanation | Validation, save draft, publish, re-assign, preview, template picker, unsaved-changes handling |
| 6 | Survey Responses | Shared tabs, KPI strip with denominators, export dialog clarity (configure → preview → export) | Reminders, per-response exports, CSV/CHED Excel/pack, formal report, timeline, pagination |
| 7 | Reports & Analytics | `AdminPageHeader` + shared tabs; chart cards with population/period captions; USTP chart palette; cohort filter clarity; Builder steps | All tab calculations unchanged; filters; downloads; builder modes, saved reports, wave comparison; `test/admin_reports/*` pass |
| 8 | Program Insights list | KPI summary of flag states; list rows showing metric, population, course/batch, period, trigger, priority | Filters/sort, open detail/history/settings, AI boundary unchanged |
| 9 | DSS detail / History / Settings | Evidence block (metric, threshold, population, period) vs "Recommendation (system)" vs "Actions taken (admin)" clearly separated | Status changes, reminders, matching jobs, announcement editor, outcomes, settings save; `test/dss/*` pass |
| 10 | Events + editor/detail/comments | Brand fixes in dialogs; shared tabs in detail; calendar/list toggle consistency | CRUD, archive/cancel/delete confirmations, notify on create, comments moderation from both entry points |
| 11 | Announcements + editor | Audience section clarity; status badges | Draft/publish, audience count, archive/delete, DSS-originated open |
| 12 | Job Postings | Shared buttons/badges; interested list | Add/edit/archive/activate/delete, Messages deep-link |
| 13 | Forum Moderation | Mode switch as shared tabs; report severity badges | Lock/pin/delete, reports handling, cache rebuild on revisit |
| 14 | Messages | Pane headers, unread styling, profile pane label/value grid | Realtime, send text/image, read state, deep-link open, unread badge |
| 15 | Feedback list + detail | Toolbar card + card rows; friendly errors; detail as side panel (approval) | Filters, live open count, status change, admin response, notification-panel entry |
| 16 | Activity Logs | Light pass to shared header/tabs/states | Filters, date range, search, pagination, row detail |
| 17 | Archives | Replace navy block with `AdminPageHeader` + shared tabs with counts; card rows; shared confirm dialog | Restore/delete for events, jobs, surveys; counts |
| 18 | AI Assistant | Admin-only chrome branch (`isAdmin`) using `AdminPageHeader`; alumni path untouched | Send, suggestions, loading, errors; alumni AI Help unchanged |
| 19 | Account dialogs, Notification Preferences | Shared dialog chrome | Password change flow, sign-out-others result, preferences save |

Per screen, Phase B must include the **CURRENT DATA → CURRENT COMPONENT → PROPOSED COMPONENT** mapping and a text wireframe.

QA method (Phase D): run the admin web build locally and capture screenshots at 1920×1080, 1600×900, 1440×900, 1366×768 with the browser tool; this needs a runnable local environment and an admin test account (see approval item 14).

---

## 10. Shared-Component Dependencies and Risks

| Shared item | Dependents | Risk | Mitigation |
|---|---|---|---|
| `admin_dashboard_shell.dart` (sidebar/header) | All 25 screens | Header `initState` starts notification streams, registers `NotificationRouter` admin handler, calls `PushService.syncForSignedInUser()`, installs a global Ctrl/⌘ K key handler. Restructuring could duplicate listeners or break deep links | Presentation-only edits inside existing build methods; no changes to lifecycle code; verify notification taps for messages/feedback/event comments |
| `AdminDashboardWeb` IndexedStack + page cache | All screens | Cache eviction rules (Directory evicted, Surveys/Forum rebuilt, Dashboard/Archives always rebuilt) are behavior | Do not touch `_onMenuSelected`/`_pageOrder`/`_buildPageForMenu` |
| `AdminDirectoryTheme` | Directory, Surveys, Events, Jobs, DSS, Forum, Announcements, Reports, Messages (+ their themes) | Changing values restyles 9 modules at once | Phase 0a keeps values identical except approved brand fixes; screenshot each module after |
| `AdminDensity` | Nearly all | Spacing changes ripple everywhere | No value changes without approval |
| `AdminPageHeader` | 8 screens | Layout change affects all headers | Additive params only |
| `DirectoryToolbarCard` family | 7 modules + Feedback/Activity chips | Same | Move with re-exports; no API change |
| `admin_surface.dart` | Admin dialogs **and alumni** forum composer + message reaction picker | Restyling surfaces changes alumni UI (out of scope) | Do not change defaults; add admin-only parameters if needed |
| `AdminDataTable` / `AdminPaginationBar` | Directory, Survey Responses, Activity Logs | Column/row metrics affect three dense screens | Token-level only |
| `PortalTheme` / `PortalAppBar` / `PortalOverlayTheme` | Entire alumni app | Any change hits alumni mobile/web | Never modify for admin; branch on `isAdmin` in admin call sites |
| `AdminMessagesScreen`, `AiAssistantScreen`, `NotificationPreferencesScreen` | Live under shared features | Alumni counterparts share services/models | UI edits confined to admin widgets/branches |
| Widget tests `test/admin_reports/gts_alumni_list_panel_test.dart`, `gts_report_builder_test.dart` | Reports Builder | Text/finder changes can break tests | Run before/after; update finders only for approved label changes |
| No widget tests for shell/dashboard | — | Regressions only caught manually | Manual Phase E checklists + screenshots |

---

## 11. Items Requiring Approval

1. **Overall plan and order** in §8 (including splitting Survey Responses and Reports into sub-phases).
2. **Token consolidation:** create one shared admin theme file in `lib/shared/widgets/admin/` built on `UstpColors`, keeping all existing theme classes as aliases (no duplicate system).
3. **Brand color corrections** (visible change): `#090A4F` → USTP Blue `#1A1851`; `#FFD700` and `#FBBF24` → USTP Gold `#FCB315`; Material indigo/teal/green dashboard accents → USTP palette.
4. **Chart palette** restricted to USTP colors (chart meaning unchanged; colors change).
5. **Unified page background** (`#F4F6FA` vs `#F8FAFC`).
6. **Contrast fixes:** captions from `textMuted` to `textSecondary`; darker success/warning text shades.
7. **Header:** add page title + breadcrumb; show name/role at wide widths.
8. **Sidebar:** flat navy vs gradient; gold active indicator; brand label wording ("Alumni Portal / Admin" → e.g. "AESS Admin"); optional count badges; optional regrouping into "Alumni" + "Tracer & Insights".
9. **Potential Content Simplification — Requires Approval:**
   - Dashboard banner stats duplicating KPI cards (Roster, Registered, Surveys %).
   - Dashboard quick-action grid duplicating the header Quick Actions menu.
   - Header search hint "Alumni, events & surveys search coming soon".
   - Sidebar Logout duplicating profile-menu Logout (recommend **keep**).
   - Per-page large titles once the header shows the page title (decide per screen).
10. **Feedback detail inside the shell** (side panel instead of full-screen route) — navigation behavior change.
11. **Friendly error messages** replacing raw exception text (details available behind "Show details"; logging unchanged).
12. **AI Assistant admin chrome** via an `isAdmin` branch (alumni UI untouched).
13. **Enabling `PortalOverlayTheme` for admin popups** — global effect on every admin menu/dialog; recommend deferring and using `showAdminConfirmDialog` instead.
14. **QA environment:** confirm how to run the admin portal locally (e.g. `flutter run -d chrome` or `web-server`) and provide/confirm a non-production admin test account for screenshots and regression checks.
15. **Docs:** permission to correct the stale admin section of `docs/full-system-overview.md` (documentation only).

### Future UX / Feature Recommendations (not in scope — record only)

- Entity search in the header (alumni, events, surveys) — categories are already reserved in `AdminSearchCategory`.
- URL-addressable admin pages (browser back/refresh/deep links) — a routing change.
- Saved filter presets on list screens; bulk actions in Directory/Archives.
- Dashboard trend comparisons (period over period) — would need new calculations.
- Separate unrelated cleanup: the 23 analyzer infos (deprecations) can be fixed opportunistically when a screen is touched.
