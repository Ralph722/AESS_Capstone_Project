# Dashboard (menu index 0) — Phase A Audit & Phase B Proposal

Status: **Revision 2 implemented, QA'd and regression-tested 2026-10-14 — awaiting owner sign-off (§R5).** First revision C/D/E done and accepted visually ("Everything looks good"); its §C2 content description is superseded by §R.

## R. Revision 2 — content change requested by owner (2026-10-14)

Owner request: replace the KPI cards (redundant), replace Community and Shortcuts with statistics from Directory, Surveys (tracer first), Reports & Analytics and Program Insights; make "Upcoming events" show all dated items; balance figures and avoid redundancy.

Finding raised: the old "Tracer complete" KPI counted alumni with a complete *profile* (`users.tracer_profile_complete`), not CHED tracer submissions — it contradicted Reports' "Tracer reach".

**Approved decisions:**
- KPI row: **Alumni registered** (registered ÷ roster) · **Tracer response** (current CHED GTS, submitted ÷ registered — same definition as Reports) · **Employment rate** (Reports definition) · **Program Insights** (open findings, critical count, overdue actions).
- Bottom row: **Programs at a glance** (per-program alumni, registered %, tracer %) · **Other surveys** (non-tracer surveys: published/drafts, response rate, lowest response, responses to review) · **Upcoming & deadlines**.
- Upcoming & deadlines (owner: "all of them if possible", my recommendation accepted): event dates (registration deadline shown on the event's row, not as a separate row), survey closing dates, job application deadlines, Program Insights action due/review dates; next 30 days; overdue items pinned on top; open items only.
- Title-row chips (Roster / Registered / Surveys %): **remove**.
- Community counts and Shortcuts: removed from the Dashboard (still available on their own pages / sidebar).
- Extra **read-only** data loading approved (reuse existing services and Reports calculations; no schema changes, no writes; loads after first paint).
- Portal activity chart and Recent activity: unchanged.
- To verify during implementation: Reports showed "Tracer reach 0%" next to "CHED GTS 1/3" — check which is correct on live data before reusing; report, don't silently change.

### R1. Implementation

| File | Change |
|---|---|
| `lib/features/admin/dashboard/application/dashboard_insights.dart` (new) | Pure calculations: `DashboardInsights.build` (reuses `AdminReportsAnalytics` for employment and survey counts, `buildTracerCoverage` for tracer response — the same code Reports uses), per-program stats, other-survey summary, Program Insights counts (open/in-progress findings via `DssFlag.isFinding`, as the Program Insights page counts them; critical by rule severity; overdue via `DssFlag.isOverdue`), dated items; `buildDashboardAgenda` (30-day window, overdue first, one row per event) |
| `admin_dashboard_page.dart` | New `_loadInsights()` (read-only): `getAllMembers`, `getAllSurveys`, `countAssignmentsBySurvey`/`countSubmittedResponsesBySurvey` (active registered), `getAllEmploymentRecords`, `getJobsByStatus('active')`, `DssRepository.listFlags(limit: 500)` (failure isolated — only the Program Insights figures blank), and `getSurveyResponses` for each published/closed CHED wave with submissions (tracer submitters, as Reports does). Runs on first load, Refresh and return-to-Dashboard; passes `insights`/`insightsFailed` to the home widget |
| `admin_dashboard_home.dart` | New KPI row, Programs at a glance, Other surveys, Upcoming & deadlines; title chips removed; Community and Shortcuts removed. Chart and Recent activity unchanged |
| `admin_dashboard_widgets.dart` | `DashboardHeaderStat` removed (chips gone); `DashboardCommunityStat` renamed `DashboardStatTile` (used by Other surveys) |
| `admin_skeletons.dart` | Dashboard skeleton: chip placeholders removed |
| Tests | `test/admin_dashboard/admin_dashboard_home_test.dart` rewritten (31); new `dashboard_insights_test.dart` (9) |

No services, repositories, models, queries or database objects were changed; nothing writes.

Small decisions made during implementation (presentation only):
- Tracer response = registered alumni who submitted **any** published/closed CHED tracer wave ÷ registered — exactly Reports' "Tracer reach", so both screens always agree. The current tracer (newest published) is used for the "Closes …" pill only.
- "New responses to review" was **not** added to Other surveys: the only existing count covers all surveys including the tracer (and already drives the header bell), so it would have been mislabelled/redundant.
- "Upcoming & deadlines" has no "View all" (items belong to different pages); each row opens its own page (event → Events, survey/tracer → Surveys, job → Job Postings, insight → Program Insights).

### R2. Live QA (read-only, `admin@gmail.com`, release build, service worker cleared)

Live figures: Alumni registered **38%** (3 of 8) · Tracer response **33%** (1 of 3) · Employment rate **100%** (1 of 1) · Program Insights findings **2** (1 open · 1 in progress) · Programs BSIT 5 / 60% / 33%, BTLED-ICT 2 / 0% / —, BTLED-HE 1 / 0% / — · Other surveys: Published 3, Drafts 1, Response rate 22% (2 of 9), Lowest "test 3" 0% · Agenda: 3 events (Oct 15, 26, 30) and job "Testing" (deadline Oct 30).

Cross-checks on the source pages: Reports & Analytics → Tracer reach 33% / Took tracer 1, Employment rate 100% / 1 record (match); Program Insights → Open 1, In progress 1 (match); Job Postings → "Testing" deadline Oct 30, 2026 (match); Surveys → 8 published / 3 drafts in total, i.e. 5 published + 2 draft CHED tracers excluded from "Other surveys" (consistent).

**Tracer reach 0% explained:** Reports first renders "Tracer reach 0% / Took tracer 0" while its tracer submissions are still loading, then updates to 33% / 1 (observed at ~6 s vs ~36 s). The data is correct; the 0% is a loading-state display on the Reports page (shows 0 instead of a placeholder) — logged for the Reports phase, not changed here.

| Viewport | Result |
|---|---|
| 1366×768 | Single screen, no page scroll, no overflow. Fixed during QA: "Response rate" tile label was truncated (tile value no longer takes a fixed share of the width) |
| 1440×900 | All cards complete; agenda shows 4 items |
| 1600×900, 1920×1080 | No overflow; zoomed check of the chart at 1920 shows no dip below the baseline (an apparent overlap in the downscaled screenshot was an artefact) |
| 1024×768 (rail) | Scroll layout; activity + agenda side by side, then programs + other surveys |

Click-through (read-only): Program Insights KPI → Program Insights; job row → Job Postings; Other surveys "View all" → Surveys; sidebar → Dashboard (figures reload). Nothing created, edited, deleted, sent, exported or marked read; sign-in log rows only.

### R3. Regression

| Check | Result |
|---|---|
| `flutter analyze` (admin scope + `test/admin_shared` + `test/admin_dashboard`) | 19 info, all pre-existing; 0 errors/warnings; none in Dashboard files |
| `flutter test test/admin_dashboard` | 40 passed: no overflow at 6 sizes with long program/survey/deadline titles; layout switch; new KPIs and cards; removed items absent; agenda order (overdue first); all navigation targets; loading/failed/partial (Program Insights only) / empty states; Refresh busy; semantics; calculation unit tests (tracer definition, deactivated excluded, employment one-per-person, program sort/Unknown, other surveys exclude tracer and archived, findings counting incl. Watch/insufficient evidence, overdue, deadlines skip past/closed/draft/resolved, event registration deadline merge) |
| `flutter test` (full suite) | **894 passed, 3 skipped, 0 failed** |
| `git status` | No service/repository/model files changed |

Not verified live: a Program Insights load failure or an overdue/critical finding (none on live data — covered by widget tests); survey closing dates (no live survey has a close date in the window).

### R4. Performance note

The Dashboard now also loads the roster list, surveys, employment records, active jobs, Program Insights flags and the tracer responses (answers included, via the existing `getSurveyResponses`) — the same reads Reports performs. It runs after first paint and in parallel; KPI 1 and the chart/activity do not wait for it. If the roster or tracer responses grow large, a lighter "submitter IDs only" query would be the next step (would be a new service method — needs approval).

### R5. Owner decisions requested

1. Accept revision 2 as implemented, or list changes.
2. Authorize the next screen (**Alumni Directory**) for Phase A audit + B proposal only.

**Approval decisions (2026-10-14):**
- Base layout and visual changes B1–B7: **approved as proposed**.
- S1 (remove banner Roster/Registered/Surveys % chips): **not approved** → the three figures stay, shown as compact chips in the page-title row.
- S2 (drop "Max: 44"): **not approved** → "Max: 44" and the "Peak: 44" line label both stay.
- S3a (keep all 8 quick actions as a compact "Shortcuts" card): **approved**. S3b rejected.
- L1 (Community label changes): **not approved** → labels stay "Events", "Upcoming", "Jobs", "Announcements", "Forum", "Registered".
- L2 ("Announce" → "Announcements", "All" → "View all", "Quick actions" → "Shortcuts"): **approved**.
- Optional: **O1 Refresh button, O2 loading/failed states + friendly error text, O5 delete unused widget classes — approved** (on my recommendation). O3 "Needs attention" and O4 chart link change — **not included** (recorded as future ideas).
Date: 2026-10-14. Parent: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §8–§9. Builds on Phase 0 ([0a](AESS_ADMIN_REDESIGN_PHASE0A_TOKENS.md), [0b](AESS_ADMIN_REDESIGN_PHASE0B_SHELL.md), [0c](AESS_ADMIN_REDESIGN_PHASE0C_COMPONENTS.md)).

Evidence: code inspection of the files below, plus live read-only screenshots (release build, `admin@gmail.com`) at 1024×768, 1366×768, 1440×900 and 1920×1080 taken during 0b/0c. Phase 0c changed nothing on this screen (pixel-verified), so those screenshots are current. 1600×900 not yet captured (planned for Phase D).

---

## A. Audit

### A1. Purpose and user

Landing page for USTP alumni-office admins after sign-in. Common tasks: check the state of the roster, tracer and survey response rates; see what happened recently; see upcoming events; jump to a work area.

### A2. Files

| File | Role |
|---|---|
| `lib/features/admin/dashboard/presentation/admin_dashboard_home.dart` (692 lines) | Layout and all dashboard sections (stateless; receives data) |
| `lib/features/admin/dashboard/widgets/admin_dashboard_widgets.dart` (600) | `DashboardCompactKpi`, `DashboardStatChip`, `DashboardPanel` (used); `DashboardInsightCard`, `DashboardMiniStat`, `DashboardQuickAction`, `DashboardProgressInsight` (**unused anywhere**) |
| `lib/features/admin/dashboard/widgets/dashboard_engagement_chart.dart` (256) | "Portal activity" line chart (`fl_chart`) |
| `lib/features/admin/dashboard/application/admin_dashboard_metrics.dart` | `AdminDashboardMetrics` value object + derived rates |
| `lib/features/admin/dashboard/application/dashboard_activity_trend.dart` | Daily buckets from audit logs |
| `lib/features/admin/dashboard/presentation/admin_dashboard_page.dart` | **Data loading** (`_loadCriticalMetrics`, `_loadFeedPanels`, live listeners), routing — *not to be changed by this phase* |
| `lib/shared/widgets/admin/admin_skeletons.dart` → `AdminDashboardHomeSkeleton` | First-load skeleton |

### A3. Data and sources (unchanged by this phase)

| Data | Source (page state) | Shown where today |
|---|---|---|
| `rosterTotal`, `registeredOnRoster`, `tracerCompleteCount` | `AlumniMemberService.getDashboardRosterCounts()` (active roster; tracer completion from `users`) | Banner "Roster", "Registered"; KPI "Alumni roster" + caption; KPI "Tracer complete"; Community "Registered" |
| `unclaimedRoster` = roster − registered | derived | KPI "Alumni roster" caption |
| `tracerCompletionRate` = complete ÷ registered | derived | KPI "Tracer complete" value + "x of y registered alumni" |
| `totalSurveyResponses`, `totalSurveyAssignments` | `SurveyService.getAdminDashboardSurveyStats()` (non-archived surveys, active registered alumni) | Banner "Surveys %"; KPI "Survey completion" value + "x of y responses" |
| `surveyResponseRate` = responses ÷ assignments | derived | as above |
| `employmentSubmissions` | `IdTracerService.getActiveRegisteredRecordsCount()` (tracer employment view rows of active registered alumni) | KPI "Employment records" |
| `activeEventsCount`, `upcomingEventsCount` | `EventService.getActiveEvents()` length; dated today or later | Community "Events", "Upcoming" |
| `activeJobs` | `JobService.getActiveJobsCount()` | Community "Jobs" |
| `publishedAnnouncements` | `AnnouncementService.countPublishedAnnouncements()` | Community "Announcements" |
| `forumTopics` | `ForumService.getTopicCount()` | Community "Forum" |
| Recent activity (8 rows) | `AuditService.getAllAuditLogs(limit: 8)` | "Recent activity" — shows **3** (wide) / 4 (narrow) of the 8 loaded |
| Activity trend (90 daily buckets) | `getAllAuditLogs(limit: 500)` → `DashboardActivityTrend.fromAuditLogs` | "Portal activity" chart, "Max", "Peak" |
| Upcoming events | `activeEvents` filtered to today or later, sorted by date | "Upcoming events" — shows **2** (wide) / 3 (narrow) |
| `unreadMessages`, `openFeedback`, `pendingSurveyAssignments` (= unread survey responses), `registeredWithoutTracer` → `attentionCount` | listeners + stats | **Not on the Dashboard**; only the header bell badge (`attentionCount`) |
| `publishedSurveys`, `totalEvents`, `archivedEventsCount`, `totalJobs`, `portalAccounts`, `registrationRate` | loaded / derived | Not shown anywhere on the Dashboard |

### A4. Interactions

| Element | Action |
|---|---|
| KPI cards | Roster → Directory (2); Tracer complete → Reports (9); Survey completion → Surveys (10); Employment → Reports (9) |
| "Reports" link on the chart | Reports & Analytics (9). *Note: the chart's data comes from audit logs, which live in Activity Logs (7).* |
| Community tiles | Events/Upcoming → Events (1); Jobs → Job Postings (5); Announcements → (11); Forum → (12); Registered → Directory (2) |
| Quick actions (8 tiles) | Roster 2, Surveys 10, Reports 9, Events 1, Messages 6, Announce 11, Forum 12, Feedback 14 — all plain navigation (also reachable from the sidebar; the header "+ New" menu covers create actions) |
| "All" (activity / events) | Activity Logs (7) / Events (1) |
| Chart | Hover tooltip: date + "n actions" |
| Pull-to-refresh | `RefreshIndicator` → `_loadAllData` (touch/trackpad drag only; **no mouse-reachable refresh**) |
| Returning to Dashboard | Page reloads metrics and feeds (`_refreshDashboardOnReturn`) |

### A5. Layout today

- **≥ 900px wide and ≥ 520px tall:** a fixed-height "single screen" (no page scroll): navy gradient banner → 4 KPIs → three columns (flex 5/4/5): [Portal activity over Community] · [Quick actions] · [Recent activity over Upcoming events].
- **Otherwise:** one scrolling column in the same order.
- Measured at 1366×768 (content area ≈ 1102×700): banner 84px, KPI row 80px, columns ≈ 500px.

### A6. Problems (from screenshots + code)

| # | Problem | Evidence |
|---|---|---|
| P1 | Large empty areas: Quick actions tiles fill ≈ 35% of their panel (≈ 330px empty at 1366×768; more at 1920); Community tiles stretch to ≈ 70–150px tall for a one-line count; Recent activity shows 3 rows of 8 loaded with empty space below | 1366/1440/1920 shots |
| P2 | Duplicated figures: banner "Roster 8 / Registered 3 / Surveys 23%" repeat KPI values; "Registered" appears 3× (banner, KPI caption, Community); "Max: 44" and "Peak: 44" are always the same number (`maxCount == peakPoint.count`) | code + shots |
| P3 | Banner title "Dashboard overview" now repeats the header location "Overview / Dashboard" (0b); gradient partner `#1A2B6B` is off-brand (deferred from 0a to this phase); it is the heaviest element on the page but holds no unique data except the date | `_buildCompactHeader` |
| P4 | Colour noise: 11 Material colours (`indigo`, `teal`, `green`, `blue`, `orange`, `deepOrange`, `brown`, `deepPurple`, `pink`, `redAccent`, chart `#22C55E`) used as decoration, not meaning (R5). Chart green reads as "success" | code |
| P5 | Chart x-axis: last two date labels overlap ("10/0910/14") at every width | all shots |
| P6 | Inconsistent text sizes: `FittedBox` shrinks Quick-action and Community labels to fit (at 1024px "Messages", "Announce", "Feedback" render smaller than "Roster"); 9–11px greys (`grey.shade600`) on white | 1024 shot, code |
| P7 | Card styles differ from the 0a/0c system: border + shadow together, radius 12, panel titles 16 bold navy vs `AdminText.sectionTitle` 15 | code |
| P8 | States: KPIs paint **0** before metrics arrive (indistinguishable from a real zero); metric load failure shows a SnackBar with the raw exception (`'Error loading dashboard metrics: $e'`, Audit §11 item 11); feed failure is swallowed and shows "No activity yet" / "No upcoming events" (failed looks like empty) | `admin_dashboard_page.dart` |
| P9 | No mouse-reachable refresh on desktop (pull-to-refresh only) | code |
| P10 | Accessibility: KPI cards and tiles have no combined semantics label; "All" links are ambiguous to screen readers; chart has no text summary | code |
| P11 | Labels that under-describe the data: "Events" = *active* events; "Announcements" = *published*; "Forum" = *topics*; "Announce" truncated; "All" | code |
| P12 | Dead code: 4 unused widget classes (≈ 330 lines) in `admin_dashboard_widgets.dart` | `rg` |

Not a UI problem, recorded for the owner: the trend is built from the latest **500** audit-log rows but is labelled "last 90 days"; if more than 500 actions happen in 90 days the older days would read as zero. Changing this is a data-loading change — **not** proposed here (see "Future").

### A7. Risks

- Single-screen layout relies on `Expanded`/fixed heights; any new content must still fit at 1366×768 without clipping.
- `admin_dashboard_page.dart` holds data loading, listeners and routing for the whole admin app — edits there must be presentation-only and minimal.
- Live data volumes differ (8 roster rows today); layout must hold with long event titles and long activity descriptions.

---

## B. Proposal

### B1. Proposed layout (desktop, ≥ 900 × 520 — fits 1366×768 without scrolling)

Reference principles: R1 calm canvas, R2 equal-gutter grid, R3 label small/value big, R5 restrained palette, R7 label/value grids, R11 above-the-fold, R12 chart-local controls.

```
┌ Header (0b): Overview / Dashboard                     [search] [+ New] [bell] [AD] ┐
│                                                                                    │
│ Dashboard overview                                                 [⟳ Refresh]*   │  AdminPageHeader
│ Wed, Oct 14                                                                        │  (title 20, date 13)
│                                                                                    │
│ ┌ Alumni roster ──┐ ┌ Tracer complete ┐ ┌ Survey completion ┐ ┌ Employment rec. ┐ │  4 × AdminKpiCard
│ │ 8               │ │ 100%            │ │ 23%               │ │ 1               │ │  (equal width,
│ │ 3 registered ·  │ │ 3 of 3 regist-  │ │ 5 of 22 responses │ │ Tracer employ-  │ │   same targets)
│ │ 5 unclaimed     │ │ ered alumni     │ │                   │ │ ment submissions│ │
│ └─────────────────┘ └─────────────────┘ └───────────────────┘ └─────────────────┘ │
│                                                                                    │
│ ┌ Portal activity ─────────────────────── Peak 44 · [Reports] ┐ ┌ Recent activity ┐│  row 2 (flex)
│ │ Daily actions logged in the system, last 90 days           │ │ • Admin logged… ││  chart: AdminChartCard
│ │  ▁▂█▁▁▃▁▁▁▁▁█▁▂▃▁▂   (USTP Blue line, light fill)           │ │ • …  (as many of││  activity: up to 8
│ │ 07/17   07/31   08/14   08/28   09/11   09/25   10/09       │ │   the 8 loaded  ││  loaded rows that fit
│ └─────────────────────────────────────────────────────────────┘ │   rows as fit)  ││
│                                                                 │      [View all] ││
│ ┌ Community ───────────────┐ ┌ Shortcuts ──────────────┐ ┌ Upcoming events ──────┐│  row 3 (flex)
│ │ Active events       8    │ │ [Roster]   [Surveys]    │ │ OCT 15  Test Event    ││  Community: 2×3
│ │ Upcoming events     3    │ │ [Reports]  [Events]     │ │ OCT 26  dawd          ││  label/value grid
│ │ Active jobs         1    │ │ [Messages] [Announce-   │ │ (as many as fit)      ││  Shortcuts: 8 compact
│ │ Published announc.  7    │ │            ments]       │ │            [View all] ││  neutral buttons
│ │ Forum topics        6    │ │ [Forum]    [Feedback]   │ │                       ││
│ │ Registered alumni   3    │ │                         │ │                       ││
│ └──────────────────────────┘ └─────────────────────────┘ └───────────────────────┘│
└────────────────────────────────────────────────────────────────────────────────────┘
 * needs approval (Q3)
```

Grid: row 2 = chart (2/3 width) + Recent activity (1/3); row 3 = three equal cards. Gutters `AdminDensity.gridGap` (12). Rows 2 and 3 split the remaining height ≈ 55/45, so nothing is left as a large empty panel; at 1920×1080 the extra height goes to the chart and lists (more rows of the data already loaded), not to stretched tiles.

**Narrow / short screens (< 900px wide or < 520px tall):** same single scrolling column as today, new order: KPIs (2×2) → Portal activity → Recent activity → Upcoming events → Community → Shortcuts.

### B2. CURRENT DATA → CURRENT COMPONENT → PROPOSED COMPONENT

| Data | Current | Proposed |
|---|---|---|
| Date | Banner, white on navy | `AdminPageHeader` subtitle |
| "Dashboard overview" | Banner title 22 | `AdminPageHeader` title 20 (same words) |
| Roster / Registered / Surveys % (banner chips) | Banner stat chips | **Removed from the banner only** — same values remain in the KPI cards (and Community). *Requires approval (S1)* |
| Alumni roster, registered, unclaimed | `DashboardCompactKpi` | `AdminKpiCard` value + caption (unchanged text) |
| Tracer complete %, x of y | `DashboardCompactKpi` | `AdminKpiCard` |
| Survey completion %, x of y | `DashboardCompactKpi` | `AdminKpiCard` |
| Employment records + caption | `DashboardCompactKpi` | `AdminKpiCard` |
| Activity series, tooltip, y/x axes, Peak line + label, caption, "Reports" link | Chart inside `DashboardPanel`-like box | `AdminChartCard` (title, caption with population + period, trailing "Reports" link); chart body unchanged except colours and the x-label fix |
| "Max: 44" | Header text | Shown once as "Peak 44" in the card header; the dashed peak line stays. *"Max" removal requires approval (S2)* |
| Community 6 counts + tap targets | 6 tall coloured tiles | 2×3 label/value grid (R7), each row tappable to the same page; labels clarified (L1) |
| 8 quick actions + targets | 4×2 coloured tiles in a mostly empty panel | "Shortcuts" card, 8 compact neutral buttons (icon + full label), same targets. *Keep vs remove = S3* |
| Recent activity rows (description or action+resource, date) | 3 of 8 shown | As many of the 8 loaded rows as fit (≥ 3 at 1366×768), same fields; "View all" |
| Upcoming events (month, day, title) | 2 shown | As many as fit from the already-loaded list, same fields; "View all" |
| Empty texts ("No activity yet", "No upcoming events", "No activity recorded yet", "Loading activity trend…") | Plain grey text | `AdminStateView` compact, same wording |
| First-load skeleton | `AdminDashboardHomeSkeleton` | Same component, re-proportioned to the new grid |
| Pull-to-refresh | `RefreshIndicator` | Kept |

Nothing is removed except the three banner duplicates (S1) and the duplicate "Max" text (S2), both only with approval.

### B3. Visual changes (no data / logic change)

1. Banner → plain `AdminPageHeader` on the page background (removes `#1A2B6B` gradient — the last off-brand navy partner from 0a).
2. Cards: `AdminSurfaces.card()` (white, soft shadow, radius 16, no border) everywhere; panel titles `AdminText.sectionTitle` (15/w700, `textPrimary`) with the existing icons in `textSecondary`.
3. Colour: icons and KPI icon boxes use `AdminColors.primary` on `primaryTint`; the 11 decorative Material colours are removed. Meaning is carried by icon + label, never colour alone. Chart line/fill: USTP Blue (`AdminColors.primary`) with a light tint; peak line dashed `textMuted`, label `textSecondary`.
4. Chart x-axis: skip the final date label when it would collide with the previous tick (fixes "10/0910/14"); tooltip unchanged.
5. Text: no `FittedBox` shrinking; minimum 12px for labels, 11px only for axis ticks; greys → `textSecondary`.
6. Accessibility: KPI cards get one spoken label ("Alumni roster, 8, 3 registered · 5 unclaimed"); "View all" links say what they open ("View all activity", "View all events"); chart gets a text summary for screen readers built from the existing trend values (e.g. "Portal activity, last 90 days, peak 44 actions on <peak date>"); visible focus on all tappable items.

### B4. Components

- **Reused (0c):** `AdminKpiCard`, `AdminChartCard`, `AdminStateView`, `AdminText`, `AdminSurfaces`, `AdminButtonStyles`; existing `AdminPageHeader`.
- **Replaced on this screen:** `DashboardCompactKpi` → `AdminKpiCard`; `DashboardStatChip` grid → label/value rows; `DashboardPanel` → restyled to the shared card + section title (kept as the Dashboard's panel wrapper, local to this feature).
- **Not changed:** `AdminDashboardHome` constructor (same inputs: `isLoading`, `metrics`, `activeEvents`, `recentActivity`, `activityTrend`, `onMenuSelected`, `onRefresh`), so `admin_dashboard_page.dart` needs **no** edits for B1–B4.

### B5. Unchanged functionality

All queries, services, metrics, derived rates, the 500-row trend input, live listeners, routing targets (every tap goes to the same menu index), refresh-on-return, pull-to-refresh, header bell `attentionCount`, and number formatting (`toStringAsFixed(0)` percentages, `MMM d` dates).

### B6. Risks

| Risk | Mitigation |
|---|---|
| Fixed-height grid clips at some size | Phase D at 1366×768, 1440×900, 1600×900, 1920×1080, 1024×768 + widget tests at those sizes with long titles |
| Showing more activity/event rows changes perceived "summary" | Rows come from the same already-loaded lists; counts capped at what is loaded (8 activity rows) |
| Colour removal reduces scannability | Icons + labels stay; layout groups (KPIs / activity / community / shortcuts) do the separating |

### B7. Usability rationale

The first screen answers "how are we doing" (4 KPIs with denominators), "what is happening" (activity trend + latest actions + next events) and "where do I go" (community counts + shortcuts) in three rows without scrolling at 1366×768, with one visual language shared with the rest of the portal.

### B8. Potential Content Simplification — Requires Approval

- **S1** Remove the banner's Roster / Registered / Surveys % chips (same values stay in the KPI cards).
- **S2** Show the activity maximum once ("Peak 44") instead of "Max: 44" + "Peak: 44".
- **S3** Quick actions: **(a) keep all 8 as a compact "Shortcuts" card (recommended)**, or (b) remove them (all 8 are sidebar destinations).

### B9. Wording — Requires Approval

- **L1** Community labels: "Events" → "Active events", "Upcoming" → "Upcoming events", "Jobs" → "Active jobs", "Announcements" → "Published announcements", "Forum" → "Forum topics", "Registered" → "Registered alumni".
- **L2** "Announce" → "Announcements"; "All" → "View all"; section "Quick actions" → "Shortcuts" (they only navigate; "+ New" holds the create actions).

### B10. Optional — use existing data/functions, each needs approval (not in the base proposal)

- **O1 Refresh button** in the page header calling the existing `onRefresh` (`_loadAllData`) — gives mouse users the refresh that pull-to-refresh provides.
- **O2 Loading/failed states** — show KPI placeholders until the first metrics load instead of "0"; show a compact error with "Try again" (existing loaders) when the feed load fails instead of "No activity yet"; replace the raw-exception SnackBar text with "Couldn't load dashboard figures. Try again." Requires two presentation-only flags in `admin_dashboard_page.dart` (no query change).
- **O3 "Needs attention" card** listing counts already loaded but not shown — unread messages, open feedback, new survey responses, registered alumni without a tracer — each linking to its existing page. Would be the one emphasised card (R6). New *presentation* of existing data; no new queries.
- **O4 Chart link** to Activity Logs (the chart's data source) instead of Reports & Analytics.
- **O5 Delete the 4 unused widget classes** (`DashboardInsightCard`, `DashboardMiniStat`, `DashboardQuickAction`, `DashboardProgressInsight`).

### B11. Future UX / Feature Recommendations (not proposed)

- Trend accuracy: query daily counts for 90 days instead of the latest 500 rows (data-loading change).
- Registration rate (`registrationRate`, already derived) as a KPI pill.
- Period selector (30/90 days) on the activity chart.

### B12. Files expected to change in Phase C (if approved)

`admin_dashboard_home.dart`, `admin_dashboard_widgets.dart`, `dashboard_engagement_chart.dart`, `admin_skeletons.dart` (`AdminDashboardHomeSkeleton` only); `admin_dashboard_page.dart` **only** if O2 is approved; new `test/admin_dashboard/` widget tests.

---

## C. Implementation record (2026-10-14)

### C1. Files changed

| File | Change |
|---|---|
| `lib/features/admin/dashboard/presentation/admin_dashboard_home.dart` | Rewritten layout (B1–B7 as approved, with S1/S2/L1 **not** applied). Constructor keeps all previous inputs; adds optional `metricsLoaded` (default `true`), `metricsFailed`, `feedsFailed` (default `false`) for O2 |
| `lib/features/admin/dashboard/widgets/admin_dashboard_widgets.dart` | `DashboardPanel` restyled (shared card, 15px section title); new small local widgets `DashboardViewAllButton`, `DashboardHeaderStat`, `DashboardCommunityStat`, `DashboardRefreshButton`. Removed: `DashboardCompactKpi`, `DashboardStatChip` (replaced on this screen by `AdminKpiCard` and the label/value rows) and the 4 unused classes (O5). `rg` confirmed no other references |
| `lib/features/admin/dashboard/widgets/dashboard_engagement_chart.dart` | Wrapped in `AdminChartCard`; USTP Blue line/fill; dashed `textMuted` peak line; x-label collision rule (`showXLabel`); 11px ticks; screen-reader summary; loading/error/empty states. Tooltip, axes, data and "Reports" link unchanged |
| `lib/features/admin/dashboard/presentation/admin_dashboard_page.dart` | O2 only: three flags (`metricsLoaded`, `metricsFailed`, `feedsFailed`) set in the existing success/catch branches and passed to the home widget; SnackBar text → "Couldn't load dashboard figures. Try again." (raw error now goes to `debugPrint`); feed failures now set `feedsFailed` instead of being silently swallowed. No query, listener, routing or refresh logic changed |
| `lib/shared/widgets/admin/admin_skeletons.dart` | `AdminDashboardHomeSkeleton` only — re-proportioned to the new grid |
| `lib/shared/widgets/admin/admin_chart_card.dart` (0c) | Added optional `expandChart` (default `false`, so other uses are unaffected): lets the chart fill a fixed-height grid cell |
| `lib/features/admin/dashboard/widgets/admin_dashboard_shell.dart` | Whitespace-only reformat from `dart format` (no logic change) |
| `test/admin_dashboard/admin_dashboard_home_test.dart` | New — 25 widget tests |

### C2. What the screen shows now

- **Title row:** `AdminPageHeader` "Dashboard overview" + date; on the right the three kept figures as compact chips (Roster, Registered, Surveys %) and a **Refresh** button (O1; disabled with "Refreshing…" while `_loadAllData` runs).
- **KPI row:** 4 × `AdminKpiCard` — same values, captions and tap targets (Roster → Directory, Tracer → Reports, Survey → Surveys, Employment → Reports).
- **Middle row:** Portal activity chart (2/3 width; "Max: N" and "Reports" in the card header, dashed "Peak: N" line kept) + Recent activity (all 8 loaded rows, scrolls if they don't fit; "View all" → Activity Logs).
- **Bottom row:** Community (6 counts, labels unchanged, same targets) · Shortcuts (8 compact buttons, "Announcements" in full, same targets) · Upcoming events ("View all" → Events).
- **States (O2):** KPI values show "—" with "Loading…" until the first metrics load and "Couldn't load" on failure; feed failures show "Couldn't load recent activity" / "Couldn't load events" with "Try again" (calls the existing refresh) instead of the empty-state text; chart shows its own loading/error/empty states.

### C3. Deviations from the B proposal (all presentation-only)

1. Single-screen layout threshold is **≥ 1000 px wide** (content area) and ≥ 520 tall, not 900 — at 900–999 the three bottom cards became too narrow. Below that, the scroll layout places activity/events and community/shortcuts side by side from 700 px.
2. Bottom row has a fixed height of 200–260 px (45 % of the available height, never more than half) instead of a 55/45 flex split; this keeps all 8 activity rows visible at 1440×900 and avoids empty space in tall windows.
3. Community icons hide when a cell is narrower than 180 px so "Announcements" never truncates (seen at 1366×768 in QA round 1).
4. Chart line uses `preventCurveOverShooting: true`. The original curve (same smoothing 0.22) dipped **below 0** next to sharp spikes (visible at 07/17 and 09/11 in QA), which also overlapped the "09/11" axis label. The line is now slightly more angular but never shows negative values. Data unchanged.
5. `AdminChartCard.expandChart` added (see C1).

### C4. Not changed

All services and queries, the 500-row trend input, live listeners, refresh-on-return, pull-to-refresh, every navigation target, header bell `attentionCount`, number/date formatting, Community labels, "Max" text, the three title-row figures.

---

## D. Responsive QA (2026-10-14)

Method: `flutter build web --release` of the working tree, served locally, headless Chrome at exact viewports, **live** Supabase signed in as `admin@gmail.com`, read-only. One capture round turned out to show a cached older build (Flutter's service worker); for the final rounds the service worker was unregistered and its cache cleared, so the results below are from the final build. Screenshots kept locally outside the repo (`%TEMP%\aess_qa\dash-*`).

| Viewport | Layout | Result |
|---|---|---|
| 1366×768 (sidebar expanded) | Single screen | Everything fits without page scroll. Recent activity shows ~6½ of 8 rows (rest scroll inside the card). "Announcements" in Community and Shortcuts shown in full. No overflow |
| 1440×900 | Single screen | All 8 activity rows visible; all cards complete; no overflow |
| 1600×900 | Single screen | All 8 activity rows; no overflow |
| 1920×1080 | Single screen | No overflow; Community fits in 3 columns; extra height goes to the chart. Bottom cards have some spare space below their content (by design capped at 260 px) |
| 1024×768 (sidebar auto-collapsed) | Scroll layout | KPIs in one row, full-width chart, activity + events side by side; no overflow |

Read-only interaction check at 1440×900: Refresh → button disabled showing "Refreshing…", then back to "Refresh" with the same figures; Shortcut "Reports" → Reports & Analytics; Recent activity "View all" → Activity Logs; sidebar Dashboard → returns to the Dashboard with data reloaded. Nothing was created, edited, deleted, sent, exported or marked read. Each sign-in writes one "Admin logged in" activity-log row (normal behaviour; these rows appear in the screenshots).

Fixed during D: Community label truncation at 1366 (C3 item 3); bottom-row sizing / clipped activity at 1440 (C3 item 2); chart curve dipping below 0 (C3 item 4).

---

## E. Functional regression (2026-10-14)

| Check | Result |
|---|---|
| `flutter analyze lib/features/admin lib/shared/widgets/admin lib/features/messages lib/features/ai test/admin_shared test/admin_dashboard` | 19 issues, all info and all pre-existing; 0 errors, 0 warnings; none in Dashboard or shared-component files |
| `flutter test test/admin_dashboard` | 25 passed: no overflow at the content sizes for 1366, 1440, 1600, 1920 and 1024/768 (rail) including long titles and descriptions; single-screen vs scroll switch; all figures and labels preserved ("Max" kept, Community labels kept, "Announce" gone); every tap target routes to the same menu index as before; loading/failed/empty states; Refresh busy state; x-label rule; bottom-row height rule; semantics labels |
| `flutter test` (full suite) | **879 passed, 3 skipped, 0 failed** (854 + 25 new) |
| `git diff` of `admin_dashboard_page.dart` | Only the O2 flags, the friendlier SnackBar text and `debugPrint` calls; no query/listener/routing edits |
| `git status` | No service, repository or Supabase files modified; QA left no repo changes (`build/web` is git-ignored) |
| Live data check (D) | KPI values and captions identical to pre-redesign screenshots (8 / 100% / 23% / 1; 3 registered · 5 unclaimed; 3 of 3; 5 of 22); Community 8 / 3 / 1 / 7 / 6 / 3 identical |

Not verified: touch pull-to-refresh (no touch device in headless QA; the `RefreshIndicator` code path is unchanged); a real metrics-load failure on live (simulated in widget tests only).

---

## F. Completion report — signed off by owner 2026-10-14 (screen closed)

Done: B1–B7, S3a, L2, O1, O2, O5 as approved; S1, S2, L1, O3, O4 not applied. QA and regression above.

Owner decisions requested:
1. Accept the Dashboard as implemented (including deviations C3 1–5, notably the slightly more angular chart line), or list changes.
2. Authorize the next screen (**Alumni Directory**) for Phase A audit + B proposal only.

Future items (unchanged, not implemented): trend built from the latest 500 audit rows (data-loading change); O3 "Needs attention" card; O4 chart link to Activity Logs; registration-rate pill; chart period selector.
