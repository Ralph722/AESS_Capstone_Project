# Phase 0c — Shared Admin Components: Audit & Proposal

Status: **CLOSED 2026-10-14** (owner sign-off after C/D/E below). Approved as scoped, with section title 15px and default cancel label "Cancel".
Date: 2026-10-14. Parent plan: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §6.2, §6.4, §8 step 0c.
Builds on: `AdminColors` / `AdminSurfaces` (0a), `AdminDensity`, `showAdminDialogSurface`, `AdminTableBadge`.

Goal: build the shared building blocks **once**, in `lib/shared/widgets/admin/`, so each later screen phase can adopt them instead of re-inventing. **0c does not restyle any screen.** The only existing code touched is the six duplicated button-style helpers, which would delegate to the shared style with identical values (zero visual change).

---

## A. Audit — duplicates today (counts from `rg`, admin + messages + AI code)

| Kind | Existing variants (call sites) | Notes |
|---|---|---|
| KPI / stat card | `DirectoryStatCard` (42, via `DirectoryStatsGrid` 11) · `ReportsStatCard` (12, bento) · `DashboardCompactKpi` (5) · `ReportsKpiCard` (1) · `DashboardStatChip` (2) · `DashboardMiniStat` (1) · private `_MiniStat`, `_StatPill` | Props overlap: label, value, icon, accent, caption/description, onTap. Only `ReportsStatCard` has label/value rows + status pill; only `ReportsKpiCard` has growth % + sparkline |
| Empty / error / loading | `ReportsChartEmptyState` (31) · `DirectoryEmptyState` (13) · `SurveyEmptyState` (5) · `MessageEmptyState` (2) · `ReportsSectionEmptyState` (1) · many plain `Center(Text(...))` | No shared **error** view: ≈ 70 lines interpolate raw exceptions into UI text (Audit §5.7) |
| Tabs | `TabBar(` (8 direct uses) · `SurveyWorkspaceSegmentedNav` (2; underline, label indicator, 2.5px) · `ReportsSegmentedToggle` (3; segmented) · Reports pinned tabs · Archives pill tabs · Member detail `_TabCountBadge` | Five visual styles (Audit §5.5) |
| Section header | `SurveyInlinePanelHeader` (3) · private `_SectionTitle`, `_PanelHeader`, `_SkeletonSectionTitle` · ad-hoc `Row(Text, Spacer, actions)` | No shared one |
| Confirm dialog | `AlertDialog(` in **24 files** (41 uses); two near-identical private helpers: Surveys `_confirmAction` ("Cancel"), Events `_confirm` ("Keep"); destructive color re-typed (`#DC2626` literal vs `AdminSurveyTheme.danger`) | `showAdminDialogSurface` (14 uses) exists but isn't used for confirms |
| Button styles | `{survey,event,job,forum,dss,announcement}{Filled,Outlined}ButtonStyle` — 12 functions, **identical bodies** (min height `buttonHeight`, padding 16/14, radius `radiusSm`, elevation 0); `announcementFilledButtonStyle` adds a `foreground` param | 80 call sites total |
| Typography | No shared `TextStyle`s; titles 18/20/22, tabs 13 vs 13.5 (Audit §4) | 0a deferred typography to 0c |

---

## B. Proposal — new shared files (no screen adopts them in 0c)

All in `lib/shared/widgets/admin/`, colors from `AdminColors`, radii/shadows from `AdminSurfaces`, spacing from `AdminDensity`.

### B1. Typography — `AdminText` (added to `admin_theme.dart`)

| Token | Style | Source |
|---|---|---|
| `pageTitle` | 20 / w700 / -0.4, `textPrimary` | `AdminDensity.titleFontSize` |
| `pageSubtitle` | 13 / w400, `textSecondary` | `subtitleFontSize` |
| `sectionTitle` | **15** / w700, `textPrimary` | new value between existing 14 and 16 — **approval Q2** |
| `cardTitle` | 13 / w600, `textPrimary` | |
| `body` | 13 / w400, `textPrimary` | |
| `caption` | 12 / w400, **`textSecondary`** | captions on `textSecondary` (≈ 4.8:1) instead of `textMuted` (≈ 2.6:1) — new components only |
| `kpiValue` / `kpiLabel` | 24 / w700 · 12 / w600 | `kpiValueFontSize` (22) kept for dense strips |
| `tab` / `tabActive` | 13.5 / w500 · 13.5 / w600 | unifies 13 vs 13.5 |

### B2. `AdminButtonStyles` — `admin_buttons.dart`

`filled({Color? background, Color foreground = Colors.white})`, `outlined()`, `danger()` (= filled with `AdminColors.danger`). Bodies copied **verbatim** from the existing helpers.
The 12 feature helpers become one-line delegates (`=> AdminButtonStyles.filled(background: background)`), so their 80 call sites are untouched and render identically. *This is the only edit to existing files in 0c.*

### B3. `AdminKpiCard` — `admin_kpi_card.dart`

Reference R3/R4: small label, big value, optional embedded chart.

```
┌──────────────────────────────────────────┐
│ [icon] LABEL                  [pill]     │
│ 24px VALUE   ▲ 12% vs last month         │
│ caption / denominator (e.g. "3 of 8")    │
│ ── optional rows: label ........ value   │
│ ── optional embedded chart (Widget)      │
└──────────────────────────────────────────┘
```

Props: `label`, `value`, `icon`, `accent`, `caption?`, `pill? (label, tone)`, `trend? (percent, comparison)`, `rows` (label/value), `chart?` (any widget), `onTap?`, `dense` (22px value). Hover = `AdminSurfaces.card(hovered:)`; semantics label "label, value, caption". Superset of `DirectoryStatCard` + `ReportsStatCard` + `ReportsKpiCard` + `DashboardCompactKpi` so each can migrate in its own screen phase without losing information.

### B4. `AdminChartCard` — `admin_chart_card.dart`

Title + caption (**population and period**, e.g. "Cumulative alumni, last 12 months"), optional trailing (chart-local toggle, R12), optional dot legend (`List<(label, color)>`), info tooltip, chart `child`, and `isEmpty` + `emptyMessage` → renders `AdminStateView.empty` inside the card. **Does not choose series colors** (chart palette = Audit item 4, still open for the Reports phase).

### B5. `AdminSectionHeader` — `admin_section_header.dart`

`title`, `caption?`, `leadingIcon?`, `trailing` actions; uses `AdminText.sectionTitle` / `caption`. Wraps to two lines at narrow widths instead of overflowing.

### B6. `AdminTabBar` — `admin_tab_bar.dart`

Underline tabs (R8), modeled on `SurveyWorkspaceSegmentedNav` (label-sized 2.5px indicator, `primary`): tabs = `AdminTabSpec(label, icon?, count?)`. Works with a `TabController` **or** `selectedIndex` + `onSelected`, so screens keep their existing tab state. Count badge reuses `_TabCountBadge` visuals. Scrollable when tabs overflow.

### B7. `AdminStateView` — `admin_state_view.dart`

- `.loading({label})` — spinner + optional label (skeletons stay in `admin_skeletons.dart`).
- `.empty({icon, title, message, primaryAction, secondaryAction})` — superset of `DirectoryEmptyState` / `SurveyEmptyState` / `ReportsSectionEmptyState`; `compact: true` variant = `ReportsChartEmptyState`.
- `.error({title = "Something went wrong", message, details, onRetry})` — friendly text; the technical `details` string only behind a "Show details" expander. Retry button only when the screen passes an existing retry callback.
  - *Replacing raw exception text on any screen is still Audit item 11 and is decided per screen; 0c only provides the component.*

### B8. `showAdminConfirmDialog` — `admin_confirm_dialog.dart`

`Future<bool> showAdminConfirmDialog(context, {title, message, confirmLabel, cancelLabel = 'Cancel', destructive = false, icon?})` built on `showAdminDialogSurface` (maxWidth 440, radius 16), Esc/barrier = cancel, focus on Cancel for destructive actions, destructive button = `AdminButtonStyles.danger()`. Returns `false` on dismiss. Convention: titles end with "?" ("Delete event?"). Adoption (Archives, Events, Surveys, …) happens per screen; wording changes in each screen's Phase B.

### B9. Not created (reuse)

`AdminPageHeader` (10 uses) — kept; additive params only if a screen needs them. `AdminTableBadge` — reused as the status badge (tone presets can be added in a screen phase if needed). `AdminDataTable` / `AdminPaginationBar` / `admin_skeletons.dart` — unchanged.

---

## C. Files

| File | Change |
|---|---|
| `lib/shared/widgets/admin/admin_theme.dart` | + `AdminText` |
| `lib/shared/widgets/admin/admin_buttons.dart` | new |
| `admin_kpi_card.dart`, `admin_chart_card.dart`, `admin_section_header.dart`, `admin_tab_bar.dart`, `admin_state_view.dart`, `admin_confirm_dialog.dart` | new |
| 6 feature `*_ui.dart` files (surveys, events, jobs, forum, dss, announcements) | button helpers → one-line delegates (identical values) |
| `test/admin_shared/*_test.dart` | new widget tests for each component |

No screen file changes. No changes to `admin_surface.dart` defaults (shared with alumni UI).

## D. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Button delegation changes a pixel somewhere | Low | Bodies copied verbatim; diff review; spot screenshots of Surveys, Events, Jobs, Forum, Program Insights, Announcements |
| Components designed without a consumer drift from real needs | Medium | Props are the union of the existing variants (§A); Dashboard phase is the first consumer and may adjust them |
| Unused code in the build | Certain until adopted | Tree-shaken in release; covered by widget tests |
| `AdminText` diverges from `AdminDensity` font sizes | Low | `AdminText` reads the existing `AdminDensity` constants where they exist |

## E. Verification plan

- Widget tests per component: renders all optional parts; tap/selection callbacks; confirm dialog returns true/false/false-on-dismiss; error view hides details until expanded; no overflow at 320 / 768 / 1366 px widths; semantics labels present.
- `flutter analyze` (same folders): no new issues vs 19 info.
- `flutter test`: 815 + new tests pass, 3 skipped.
- Phase D: screenshots of the 6 screens using the delegated button helpers (Surveys, Events, Jobs, Forum, Program Insights, Announcements) at 1366×768 to confirm no visual change (release build, live, read-only).

## F. Unchanged functionality

No data, routing, permission, calculation, export, notification, or text changes on any screen.

---

## Approval questions

1. Approve 0c as scoped (create shared components + delegate the 12 button helpers; no screen adoption)?
2. Section title size: 15px (new) or keep 14px (`AdminDensity.sectionTitleFontSize`)?
3. Confirm dialog default cancel label: "Cancel" (Surveys) or "Keep" (Events)?

**Answers (2026-10-14):** 1 approved and implement · 2 **15px** · 3 **"Cancel"**.

---

## C. Implementation record

| File | What was done |
|---|---|
| `admin_theme.dart` | `AdminText` added as specified in B1. Additive: `kpiValueDense` (22px, `AdminDensity.kpiValueFontSize`) used by `AdminKpiCard(dense: true)` |
| `admin_buttons.dart` | `AdminButtonStyles.filled / outlined / danger` — bodies copied from the feature helpers, reading `AdminColors`, `AdminDensity.buttonHeight` (36), `AdminSurfaces.radiusSm` (8). All six feature themes alias exactly these tokens, so values are identical |
| 6 feature `*_ui.dart` | The 12 helpers are now one-line delegates + one import each; names, signatures and the 80 call sites unchanged (`announcementFilledButtonStyle` still passes `foreground`) |
| `admin_kpi_card.dart` | `AdminKpiCard` as B3, plus small value types: `AdminTone` (neutral/info/success/warning/danger → `AdminColors` fg/bg), `AdminKpiPill`, `AdminKpiTrend(percent, comparison, positiveIsGood = true)`. Hover lift only when `onTap` is set. One combined semantics label: label, value, pill, trend, caption, rows |
| `admin_chart_card.dart` | `AdminChartCard` as B4; optional `chartHeight`; trailing control moves under the title below 420px card width; legend hidden when empty |
| `admin_section_header.dart` | `AdminSectionHeader(title, caption, leadingIcon, actions)`; actions wrap under the title below 480px (`stackBelow`) |
| `admin_tab_bar.dart` | `AdminTabBar` as B6. `isScrollable: true` (default) = left-aligned, scrolls when it overflows; `false` = evenly spaced like Surveys today. In `selectedIndex` mode the bar follows the screen's state (snaps back if the screen ignores a tap) |
| `admin_state_view.dart` | `AdminStateView.loading / empty / error` as B7, with `AdminStateAction(label, onPressed, icon)` for buttons |
| `admin_confirm_dialog.dart` | `showAdminConfirmDialog` as B8 (+ public `AdminConfirmDialogBody`). Non-destructive: focus on the confirm button; destructive: focus on Cancel, red confirm |
| `test/admin_shared/` | 6 test files + harness, 39 tests |

Small deviations from the B text, all inside the new files (no screen affected):
- Tab count badge copies the Surveys `_CountBadge` visuals (selected/unselected states, "999+" cap) rather than the Member Detail `_TabCountBadge`, because the tab bar itself is modeled on the Surveys nav.
- Active tab weight is w600 per the approved B1 table; the existing Surveys nav still uses w700 until Surveys adopts the shared bar.

No screen file adopts the new components. `admin_surface.dart` unchanged.

## D. QA (release build, live Supabase, `admin@gmail.com`, read-only, 1366×768)

Surveys, Program Insights, Events, Announcements, Forum and Job Postings list views were captured and pixel-compared with the Phase 0b screenshots of the same screens:
- Every screen differs only inside the header search field (x 885–1162, y 16–33; 1,976 px) — the approved search-field fix made after the 0b screenshots.
- That region matches the post-fix screenshot exactly (0 px difference) on all six.
- Everything else, including all buttons using the delegated styles, is pixel-identical.

Nothing was created, edited, deleted, sent or exported; no detail views were opened. Signing in wrote one "Admin logged in" activity-log row (normal behavior).

## E. Regression

| Check | Result |
|---|---|
| `flutter analyze lib/features/admin lib/shared/widgets/admin lib/features/messages lib/features/ai test/admin_shared` | 19 info, all pre-existing; no new issues |
| `flutter test test/admin_shared` | 39 passed |
| `flutter test` (full suite) | 854 passed (815 + 39), 3 skipped, 0 failed |

No data, routing, permission, calculation, export, notification or text change.
