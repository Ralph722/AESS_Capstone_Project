# Phase 0b — Admin Shell (Sidebar + Header Bar): Audit & Proposal

Status: **CLOSED 2026-10-14 (owner sign-off).** Approved: B1, B2.1–B2.4, brand label "AESS / Admin Portal", remove "coming soon" line; "OVERVIEW" heading kept. Follow-up search-field fix approved and done (§F).
Date: 2026-10-14. Parent plan: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §7, §8 step 0b, §11 items 7–9.
Builds on: Phase 0a tokens (`AdminColors`, `AdminSurfaces` in `lib/shared/widgets/admin/admin_theme.dart`).

Scope: the **sidebar** (`AdminDashboardSidebar`) and the **header bar** (`AdminDashboardTopHeader.build` row only).
Out of scope for 0b: search overlay panel, notification panel, command palette, profile/password/help dialogs (step 19 / 0c), page bodies, `AdminDashboardWeb` routing and page cache.

---

## A. Audit

### A1. Files and structure

| Piece | Location | Notes |
|---|---|---|
| Shell layout | `lib/features/admin/dashboard/presentation/admin_dashboard_page.dart` `build()` (l. 369–416) | `Scaffold(bg #F4F6FA)` → `Row[sidebar, Expanded(Column[header, Expanded(content)])]`; auto-collapse rail `< 1100px` unless user toggled |
| Nav model | `kAdminNavSections` (shell l. 125) | 5 sections, 14 items; indices must stay aligned with `_pageOrder` |
| Sidebar | `AdminDashboardSidebar` + `_SidebarSection`, `_SidebarItem`, `_CollapsedNavItem`, `_SidebarLogoMark`, `_SidebarAdminFooter` (l. 301–930) | Expanded 264px / collapsed 72px |
| Sidebar tokens | `_AdminSidebarLayout` (l. 330) | `navy = AdminColors.primary`, `navyDeep = #1A1B5E` (off-palette), `gold = AdminColors.accent`, item 40px, radius 8 |
| Header | `AdminDashboardTopHeader` (l. 932–3336) | `initState` wires notification streams, `NotificationRouter`, `PushService`, Ctrl/⌘ K — **not touched** |
| Header tokens | `_AdminChrome` (l. 346) | `surface #F4F6FA`, `border #E5E7EB` (same values as `AdminColors.shellBackground` / `border`), control 38px |

### A2. What already works (keep)

- Gold 3px active indicator, white tint + bold label on the active item; gold section label for the active section; hover/focus states; full semantics labels/hints; tooltips on the collapsed rail; collapse toggle; persistent Logout.
- Header: search with keyboard navigation, Ctrl/⌘ K palette, "New" quick actions, notification bell with combined badge, profile menu.

### A3. Problems (measured in Phase 0a QA screenshots + code)

| # | Problem | Evidence |
|---|---|---|
| P1 | **Header gives no location.** The left ~70% of the bar is an empty `Spacer`, although `selectedMenuItem` is already passed in with the doc comment "drives the header page title" | shell l. 949–950, 2714 |
| P2 | **Header and sidebar brand block are misaligned.** Header = 6 + 38 + 6 + 1px border = **51px**; sidebar brand block = 14 + 40 + 12 + 1px divider = **67px**, so the two horizontal lines don't meet | shell l. 482–526, 2706–2711; visible in all screenshots |
| P3 | **Sidebar doesn't fit at 1366×768.** Archives, Feedback, AI Assistant are below the fold; the list scrolls ≈ 130px | 0a QA `1366-sidebar-scrolled.png` |
| P4 | **Off-palette gradient partner** `#1A1B5E` (only remaining non-USTP color in the shell) | `_AdminSidebarLayout.navyDeep` |
| P5 | **Weak hierarchy in the rail.** Inactive labels/icons at 95% white are nearly as bright as the active item (reference R9 "quiet sidebar") | l. 842–846, 697–699 |
| P6 | **Identity only as initials.** Avatar "AD" with no name/role, even at 1920px (reference R10) | l. 3129–3163 |
| P7 | **Search panel advertises unbuilt feature**: "Alumni, events & surveys search coming soon" | l. 1697–1728 |
| P8 | Brand block reads "Alumni Portal / Admin" — not the system name (AESS) | l. 490–517 |

### A4. Current data → component (shell)

| Data / behavior | Current component | Kept as is? |
|---|---|---|
| Nav sections/items (`kAdminNavSections`) | `_SidebarSection` / `_SidebarItem` / `_CollapsedNavItem` | Yes (data unchanged) |
| `selectedMenuItem` | Active styling in sidebar; recent pages in header | Yes; **also** used for the new header title (P1) |
| Collapse state (`_sidebarCollapsedOverride`, `< 1100`) | `AnimatedContainer` width 264/72 | Yes |
| Logout callback | `_SidebarAdminFooter` + profile menu | Yes |
| Search hits, Ctrl/⌘ K | `_buildSearchField`, overlay, palette | Yes (only the "coming soon" line, if approved) |
| Quick actions (`kAdminQuickActions`) | "New" `PopupMenuButton` | Yes |
| Notification counts (`metrics.attentionCount + unread`) | Bell + badge | Yes |
| User name/email (`display_name` or email prefix) | Avatar initials + menu header | Yes; **also** shown beside the avatar at wide widths (P6) |

---

## B. Proposal

### B1. Header bar (`AdminDashboardTopHeader.build` row only)

Text wireframe (expanded, ≥ 1440px):

```
| Alumni  /  Alumni Directory                 [🔍 Search pages, sections…  Ctrl K] [+ New ▾] [🔔3] admin        [AD] |
|                                                                                                Administrator       |
```

1. **Location title (P1)** — replace the leading `Spacer` with a single-line title derived from `kAdminNavSections` using `selectedMenuItem`: section name (13px, `textSecondary`) + " / " + page label (15px w700, `textPrimary`), ellipsized; `Semantics(header: true)`. `< 1100px`: page label only. Fixed: height stays the same (no content-height loss).
   - Pure lookup of existing labels — no new routes, no state.
   - Pages keep their own body titles for now (temporary duplication). Demoting/removing body titles is decided **per screen** in its own phase (Audit §11 item 9).
2. **Identity (P6)** — at ≥ 1440px show the existing `name` (13px w600) and "Administrator" (11px `textSecondary`) to the left of the avatar, inside the same profile-menu tap target. Below 1440px: avatar only (as today).
3. **Height** — unchanged (51px incl. border). The sidebar adapts to it instead (B2.1), so page content keeps exactly the same height at every size.
4. **Tokens** — `_AdminChrome.surface` / `border` alias `AdminColors.shellBackground` / `AdminColors.border` (identical values). Hint/prefix-icon greys in the header search field → `AdminColors.textSecondary` (`#64748B` vs Material grey 600 `#757575`; barely visible).
5. **Unchanged:** search behavior and keyboard bindings, palette, quick actions, bell/badge logic, profile menu items and actions, every `initState`/`dispose` line.

### B2. Sidebar

1. **Align brand block to the header (P2)** — brand block height = header height (51px incl. divider); logo tile 40 → 34px. Collapsed rail: logo only in that block; the collapse toggle moves to the first row under the divider (same button, same tooltip/semantics).
2. **Fit all 14 items at 1366×768 (P3)** — compaction using existing `AdminDensity` minimums:

   | Element | Now | Proposed | Saves |
   |---|---|---|---|
   | Brand block | 67px | 51px | 16 |
   | Item height + gap | 40 + 2 | 36 + 2 (= `AdminDensity` button/min tap 36) | 56 |
   | Section heading padding / gap | 8 + 4 / 6 | 6 + 2 / 4 | 30 |
   | List vertical padding | 10 + 10 | 6 + 6 | 8 |
   | Logout footer | 10 + 40 + 12 | 8 + 36 + 8 | 10 |
   | **Total** | | | **≈ 120 of ≈ 130 needed** |

   That alone likely leaves the last item partly hidden at 768px. Optional **B2.2a** (content change, approval): drop the "OVERVIEW" heading above the single Dashboard item (Dashboard stays first; saves ≈ 22px → fits). If B2.2a is rejected, the sidebar keeps scrolling for the last item exactly as today. Final fit is verified in Phase D, not assumed.
3. **Flat USTP Blue (P4)** — sidebar background `AdminColors.primary` flat; remove `#1A1B5E`. Visually near-identical (gradient was `#1A1851 → #1A1B5E`).
4. **Quieter inactive items (P5)** — inactive label 95% → 80% white, inactive icon 95% → 72%; hover/focus → 100%. Contrast of 80% white on USTP Blue ≈ 11:1 (passes AAA). Active item, gold indicator, gold section label unchanged.
5. **Brand label (P8, approval)** — options: keep "Alumni Portal / Admin"; or **"AESS" / "Admin Portal"** (recommended; `system_logo.png` tile kept); semantics label updated to match.
6. **Unchanged:** `kAdminNavSections` data (labels, icons, indices, keywords), regrouping (not proposed), Logout placement/behavior, collapse behavior and breakpoint, tooltips, semantics, focus traversal.

### B3. Content simplification — requires approval

| Item | Proposal | Why |
|---|---|---|
| Search panel line "Alumni, events & surveys search coming soon" | Remove the line (search still lists pages/sections/commands) | Advertises a feature that doesn't exist |
| "OVERVIEW" sidebar heading (B2.2a) | Remove; Dashboard remains the first item | Needed to fit all items at 768px |

### B4. Deferred (not in 0b — recorded only)

- Sidebar count badges (unread messages, pending surveys, open feedback): needs a new `metrics` input to the sidebar — defer to a later approval.
- Regrouping into "Alumni" + "Tracer & Insights": not proposed.
- Search overlay, notification panel, command palette, account dialogs: token/visual pass in 0c / step 19.

### B5. Affected files

- `lib/features/admin/dashboard/widgets/admin_dashboard_shell.dart` — `_AdminSidebarLayout`, `_AdminChrome` constants; sidebar `build`, `_buildCollapsed`, `_buildExpanded`, `_SidebarSection`, `_SidebarItem`, `_CollapsedNavItem`, `_SidebarAdminFooter` (layout/colors only); header `build` row + `_buildProfileChip` (identity text); `_buildSearchFutureHint` call (only if B3 approved).
- No other files. `admin_dashboard_page.dart` is not edited.

### B6. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Header lifecycle (streams, router, push, Ctrl/⌘ K) disturbed | Low | Edits limited to `build`/widget-building methods; diff reviewed to confirm no `initState`/`dispose`/listener lines change |
| Header title overflows at narrow widths, squeezing search/actions | Medium | Title in `Flexible` with ellipsis; page-label-only `< 1100`; QA at 1024, 1366, 1440, 1920 |
| Sidebar still scrolls at 768px | Medium (if B2.2a rejected) | Same scrolling behavior as today; measured in QA |
| 36px items feel cramped | Low | Equals `AdminDensity` min tap/button height used across admin |
| Dashboard fixed layout affected | None expected | Header height and content area unchanged |

### B7. Verification plan

- `flutter analyze` (same folders as 0a): no new issues vs current 19 info.
- `flutter test` (full suite): 815 passed / 3 skipped expected.
- Diff check: no changes to `initState`, `dispose`, `didUpdateWidget`, listeners, `kAdminNavSections`, `kAdminQuickActions`, `_onMenuSelected`, `_pageOrder`.
- Phase D (release build, live, read-only): 1920×1080, 1440×900, 1366×768, 1024×768 (auto-collapsed rail); expanded + collapsed; header title correct on all 14 items; sidebar fit at 768.
- Phase E (read-only): navigate all 14 items; collapse/expand toggle; open/close search overlay and Ctrl/⌘ K palette; open the "New" menu (selecting only navigates); open/close notification panel (opening does not mark anything read — verified in code: only the explicit "Mark all read" / tile tap call `markAllAsRead` / `markAsRead`); open profile menu and "My profile" dialog. No password change, no "Mark all read", no notification taps that mark read.

### B8. Unchanged functionality

No changes to: routing/menu indices, page cache, data loading, metrics, notification streams/router/push, search/palette logic, quick-action targets, logout flow, permissions, or any page body.

---

## Approval decisions (2026-10-14)

| Item | Decision |
|---|---|
| B1 header title + identity at ≥ 1440 | Approved |
| B2.1–B2.4 sidebar alignment, compaction, flat USTP Blue, quieter inactive items | Approved |
| B2.5 brand label | "AESS" / "Admin Portal" |
| B3 "coming soon" search line | Remove — approved |
| B2.2a / B3 "OVERVIEW" heading | **Not approved — kept** |

---

## C. Implementation (2026-10-14)

Single file: `lib/features/admin/dashboard/widgets/admin_dashboard_shell.dart`.

- `_AdminSidebarLayout`: removed `navyDeep` (`#1A1B5E`); `itemHeight` = `AdminDensity.buttonHeight` (36); `sectionGap` 4; new `logoSize` 34, `inactiveLabelAlpha` 0.8, `inactiveIconAlpha` 0.72.
- `_AdminChrome`: `surface` / `border` alias `AdminColors.shellBackground` / `AdminColors.border` (same values); new `barPadV`, `barHeight` (50, header incl. its border) and `sidebarBrandHeight` (49 + 1px divider).
- Sidebar: flat `AdminColors.primary`; brand block `sidebarBrandHeight` with 34px logo, "AESS" / "Admin Portal" (semantics "AESS Admin Portal"); collapsed rail: logo block + toggle moved below the divider; list padding 6; section heading padding 6/2; footer 8/36/8; inactive label/icon alphas.
- Header: fixed `barHeight` container; `_buildLocationTitle` ("Section / Page", page only `< 1100`, from existing `_resolveNavItem`); `_buildProfileChip(showIdentity: width >= 1440)` shows name + "Administrator"; search hint/prefix icon → `AdminColors.textSecondary`; removed `_buildSearchFutureHint` and its call.
- Not touched (verified by diff): `initState`, `dispose`, `didUpdateWidget`, listeners, `HardwareKeyboard` handler, `NotificationRouter`, `PushService`, `kAdminNavSections`, `kAdminQuickActions`, search/palette logic, `admin_dashboard_page.dart`.

## D. Responsive QA (2026-10-14)

Release web build, live Supabase, `admin@gmail.com`, read-only, headless Chrome at exact viewports.

| Check | Result |
|---|---|
| 1366×768 expanded | **All 14 items visible without scrolling** (OVERVIEW heading kept); Logout pinned |
| Divider alignment | Pixel-measured: header border and sidebar divider both on row 49 (was 49 vs 66) |
| Content area | Header border row unchanged (49) → page content height identical to before |
| Header title | Correct "Section / Page" on all 14 pages (contact sheet) |
| 1440×900 / 1920×1080 | Identity "Admin / Administrator" beside avatar; expanded and collapsed rail render correctly |
| 1024×768 | Rail auto-collapsed; header shows page label only; search field and actions fit |
| Collapsed rail | Logo aligned with header; toggle below divider; tooltips/icons unchanged |

## E. Functional regression (2026-10-14)

| Check | Result |
|---|---|
| `flutter analyze` (admin, shared admin, messages, ai) | 19 info, all pre-existing (unchanged); `lib/features/admin/dashboard` re-run after the final 1px fix: no issues |
| `flutter test` (full suite) | 815 passed, 3 skipped (run before the final 1px brand-block constant change; analyzer re-run after it) |
| Sidebar navigation | All 14 items navigate to the correct page |
| Collapse / expand toggle | Works (expanded ↔ rail) |
| "New" quick actions menu | Opens with 4 entries; closed without selecting |
| Notification panel | Opens/closes; nothing marked read |
| Profile menu | Opens with name/email/role + 4 items; closed without selecting |
| Command palette | Opens (via "Ctrl K" chip / field click); closes with Esc |
| Inline search dropdown (`< 1100`) | Opens; ends after the page list — "coming soon" line gone |
| Ctrl/⌘ K keystroke | **Not conclusively verified** — synthetic key events in headless Chrome are unreliable; handler code unchanged |
| Not exercised (read-only constraint) | Logout, password change, notification taps, quick-action selection |

### Pre-existing issue found (not caused by 0b, not fixed)

At widths ≥ 1100px the "Ctrl K" chip inside the header search field is wrapped in `Center`, which expands to fill the suffix slot. The chip's tap area then covers the whole field: the placeholder text is invisible and **any click on the field opens the command palette instead of the inline search dropdown**. Same code at `HEAD` (handlers identical); also visible in the Phase 0a screenshots. A fix (shrink-wrap the chip) changes what a click on the field does, so it needs owner approval.

## F. Completion (2026-10-14)

- Owner signed off Phase 0b.
- **Search-field fix (approved):** `Center(widthFactor: 1, …)` around the "Ctrl K" chip so it only occupies its own width (min 44px). Verified at 1366×768 (release build, live, read-only): placeholder "Search pages, sections…" visible; clicking the field opens the inline search dropdown; clicking the chip opens the command palette; Esc closes it.
- After the fix: `flutter analyze lib/features/admin/dashboard` no issues; `flutter test` 815 passed / 3 skipped (this run includes the 1px brand-block fix).
