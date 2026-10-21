# Phase 0a — Shared Admin Tokens: Audit & Proposal

Status: **APPROVED 2026-10-14 (without the `gtsChartColors` option) — implemented (Phase C); responsive QA (Phase D) done at 1366×768 and 1920×1080; E/F closed 2026-10-14 (see §F).** Results are recorded in the progress file.
Date: 2026-10-14. Parent plan: [`AESS_ADMIN_REDESIGN_AUDIT.md`](AESS_ADMIN_REDESIGN_AUDIT.md) §8 step 0a.
Pre-approved inputs: overall plan; brand correction to `UstpColors` (Audit §11 item 3).
Still **not** approved (so excluded unless stated): chart palette change (item 4), page-background unification (item 5), contrast adjustments (item 6), sidebar/header layout (0b), shared components (0c).

---

## A. Audit

### A1. Where tokens live today

| Token source | File | Role | Consumers |
|---|---|---|---|
| `UstpColors` | `lib/core/constants/ustp_colors.dart` | Official palette | Only `PortalTheme` (alumni). **No admin file uses it** |
| `AdminDensity` | `lib/shared/widgets/admin/admin_density.dart` | Spacing, control sizes, table/KPI/form metrics | Nearly all admin files — keep as is |
| `AdminDirectoryTheme` | `lib/features/admin/roster/widgets/alumni_directory_ui.dart` (feature folder) | De-facto admin colors, radius, shadows, `surfaceCard()` | Imported by **29 files**; ~330 member references outside its file (top: `textSecondary` 24, `primary` 24, `border` 19, `textPrimary` 19, `infoBg` 16) |
| Alias classes | `AdminSurveyTheme`, `AdminEventTheme`, `AdminJobTheme`, `AdminDssTheme`, `AdminForumTheme`, `AdminAnnouncementTheme`, `AdminReportsTheme`, `AdminMessageTheme` | Re-export `AdminDirectoryTheme` members | Their own modules |
| `AdminTableTheme` | `lib/shared/widgets/admin/admin_data_table.dart` | Table colors — **same values re-typed as literals** | 5 files (table, pagination, Directory, Survey Responses, Activity Logs) |
| Shell private tokens | `_AdminSidebarLayout`, `_AdminChrome`, `_navy` in `admin_dashboard_shell.dart` | Sidebar/header colors | Shell only |
| File-private `_navy` / `_gold` | dashboard home, dashboard widgets, engagement chart, skeletons, feedback list/detail | Hard-coded `#090A4F` / `#FFD700` | Those files |
| Chart palettes | `ReportsBentoPalette` (`reports_bento.dart`), `gtsChartColors` (`gts_report_chart.dart`) | Series colors | Reports Overview/Tracer/Survey bento charts (20 refs); Builder preview **and PDF export** charts |

### A2. Off-brand brand-color literals (the approved fix)

| Value | Meaning today | Locations (admin scope) |
|---|---|---|
| `#090A4F` (forbidden navy) | "navy" | `admin_dashboard_shell.dart` (3 consts), `admin_dashboard_home.dart` (const + banner gradient), `admin_dashboard_widgets.dart`, `dashboard_engagement_chart.dart`, `admin_skeletons.dart`, `admin_feedback_page.dart`, `admin_feedback_detail_page.dart`, `admin_activity_logs_page.dart` (6), `admin_archives_page.dart` (8), `admin_event_editor_dialog.dart` (3), `admin_event_detail_panel.dart` (2), `admin_event_comments_dialog.dart` (9) |
| `#FFD700` (forbidden gold) | "gold" | shell (sidebar const, avatar gradient, profile-dialog chip), dashboard home, activity logs (2), event comments dialog (2) |
| `#FFC107` (Material amber) | gold gradient partner / highlight | shell avatar gradient, command-palette highlight |
| `#FBBF24` (Tailwind amber) | `AdminDirectoryTheme.gold` → also `AdminEventTheme.gold`, `AdminReportsTheme.gold` (18 uses) and `ReportsBentoPalette` | Directory, Events, Reports |
| `#FBBF24` in `gtsChartColors` | 4th chart series | Builder preview **and exported PDF charts** |
| `#090A4F` in `AppImage.placeholder` | Avatar placeholder tint | `lib/core/utils/app_image.dart` — **used across the alumni portal** |

Non-brand partner shades that are part of later phases, not this one: sidebar gradient end `#1A1B5E` (0b), dashboard banner gradient end `#1A2B6B` (Dashboard screen phase).

### A3. Other findings

- `AdminDirectoryTheme.primary` and `AdminTableTheme.primary` are already `#1A1851` (= USTP Blue) but as literals, not `UstpColors.blue`.
- Two page backgrounds coexist: `#F4F6FA` (shell `Scaffold`, `PortalTheme.pageBg`) and `#F8FAFC` (`AdminDirectoryTheme.background`, table header). Unification is a separate approval (item 5); 0a keeps both.
- No tests reference any of these colors or theme classes (`rg` over `test/`), so no test updates are expected.
- `DssTheme` in `dss_metrics.dart` is a data class for suggestion grouping, not a visual theme — out of scope.
- No existing class named `AdminColors`, `AdminSurfaces`, `AdminTheme`, or `AdminRadius`.

---

## B. Proposal

### B1. New shared token file (single source)

`lib/shared/widgets/admin/admin_theme.dart` — mirrors the `PortalTheme → UstpColors` precedent on the alumni side. Spacing stays in `AdminDensity` (not duplicated).

```dart
/// Admin portal colors. Brand values come from [UstpColors]; neutrals and
/// status colors are the existing admin values, unchanged.
abstract final class AdminColors {
  // Brand
  static const Color primary = UstpColors.blue;        // #1A1851 (unchanged value)
  static const Color primaryTint = Color(0xFFE8E7F2);  // existing infoBg / rowSelected
  static const Color secondary = UstpColors.midBlue;   // #0D4A77 (new name, no current users)
  static const Color accent = UstpColors.gold;         // #FCB315 (replaces #FFD700 / #FBBF24 / #FFC107)

  // Neutrals (existing values)
  static const Color background = Color(0xFFF8FAFC);   // content canvas
  static const Color shellBackground = Color(0xFFF4F6FA); // shell Scaffold
  static const Color surface = Color(0xFFF1F5F9);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color rowHover = Color(0xFFF1F5F9);

  // Text (existing values)
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status (existing values)
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFEA580C);
  static const Color warningBg = Color(0xFFFFF7ED);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color info = primary;
  static const Color infoBg = primaryTint;
}

/// Corner radii, shadows and the standard card decoration (existing values).
abstract final class AdminSurfaces {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static List<BoxShadow> get cardShadow => …;       // moved verbatim
  static List<BoxShadow> get cardShadowHover => …;  // moved verbatim
  static BoxDecoration card({bool hovered = false}) => …; // = current surfaceCard()
}
```

Typography tokens are deliberately **not** added in 0a; they arrive in 0c together with the components that use them (avoids unused tokens).

### B2. Re-point existing classes (no API change)

- `AdminDirectoryTheme`: every color/radius/shadow member becomes an alias of `AdminColors` / `AdminSurfaces`. All member names stay, so the 29 importing files compile unchanged. Only `gold` changes value (`#FBBF24` → `#FCB315`).
- `AdminTableTheme`: literals replaced by `AdminColors` aliases (identical values).
- The 8 feature alias classes are **not edited** — they alias `AdminDirectoryTheme`, so they inherit the fix. Migrating call sites to `AdminColors` directly happens opportunistically in each screen's own phase.

### B3. Brand-literal sweep (color constants only)

Replace in the 12 admin files listed in A2:
- `Color(0xFF090A4F)` → `AdminColors.primary`
- `Color(0xFFFFD700)`, `Color(0xFFFFC107)` → `AdminColors.accent`
- File-private `_navy` / `_gold` constants are redefined to point at `AdminColors` (call sites untouched).
- The 3 lines that combine the forbidden navy with deprecated `withOpacity(x)` become `AdminColors.primary.withValues(alpha: x)` (same visual result).

Strictly one-for-one constant substitution: no widget structure, layout, spacing, text, or behavior changes. Gradient partner shades `#1A1B5E` and `#1A2B6B` remain until their own phases.

### B4. Explicitly excluded (need separate decisions)

| Item | Why excluded | Choice offered |
|---|---|---|
| `gtsChartColors` `#FBBF24` | Also colors **exported PDF** charts; changing it alters generated documents | Optionally include as a gold-only fix (`#FBBF24` → `#FCB315`, near-identical hue) so Builder/PDF gold matches the on-screen bento gold |
| `AppImage.placeholder` `#090A4F` | Shared with the alumni portal (out of admin scope) | Leave; record for an alumni-side cleanup |
| Rest of chart palettes (indigo/sky) | Audit item 4 not approved | Decide later (Reports phase) |
| Background unification, contrast shades | Items 5–6 not approved | Decide in 0b/0c |

### B5. Visible effect (what the admin will notice)

| Area | Before | After |
|---|---|---|
| Sidebar, dashboard banner, Archives header, Activity Logs header, event dialogs, Feedback title, skeleton tint | Navy `#090A4F` | USTP Blue `#1A1851` (slightly lighter, a touch more violet). Sidebar gradient becomes nearly flat (`#1A1851` → `#1A1B5E`) |
| Sidebar "Admin" label, admin avatar, dashboard banner icons, activity-log highlights, comment badges | Lemon yellow `#FFD700` (+ amber `#FFC107`) | USTP Gold `#FCB315` (warmer, official) |
| Directory/Events/Reports gold accents and bento gold series | `#FBBF24` | `#FCB315` (barely distinguishable) |
| Everything else | — | Unchanged (identical values) |

Contrast check: USTP Gold on USTP Blue ≈ 9:1 (passes AA/AAA for the sidebar "Admin" label); white on USTP Blue ≈ 16:1.

### B6. Affected screens

All screens indirectly (shell colors). Directly edited files: 2 shared (`admin_theme.dart` new, `admin_data_table.dart`), `alumni_directory_ui.dart` (token block only), plus the 12 sweep files: shell, dashboard home, dashboard widgets, engagement chart, skeletons, feedback list, feedback detail, activity logs, archives, event editor, event detail panel, event comments dialog.

### B7. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `const` expressions break when a literal becomes a token | Low — all new tokens are `const` | `flutter analyze` must show no new issues vs baseline |
| Color shift perceived as "wrong" | Low–Medium (sidebar navy and gold are visible) | Approved brand direction; before/after screenshots in Phase D |
| Accidentally touching alumni UI | Low | `PortalTheme`, `AppImage`, `admin_surface.dart` defaults not edited |
| Touching files owned by later screen phases | Certain but limited | Color-constant lines only; logged so each screen's Phase A knows |

### B8. Verification plan

- **Before/after analyzer:** `flutter analyze` on the same folders — no new issues (baseline 23; expected to drop by 3 because of the `withOpacity` lines).
- **Tests:** `flutter test` (full suite) before and after — same results.
- **Grep proof:** zero `0xFF090A4F` / `0xFFFFD700` / `0xFFFFC107` / `0xFFFBBF24` left in `lib/features/admin`, `lib/shared/widgets/admin` (except `gtsChartColors` if excluded).
- **Phase D screenshots** at 1366×768 and 1920×1080 of shell + Dashboard, Directory, Reports Overview, Events, Activity Logs, Archives — requires the local run and the test admin account.

### B9. Unchanged functionality

No changes to: data fetching, services, streams, routing/menu indices, page cache, notifications, permissions, calculations, exports (unless the `gtsChartColors` option is approved — color only), text, layout, or spacing.

---

## F. Completion report (closed 2026-10-14, owner-approved)

| Phase | Evidence |
|---|---|
| C — implement | 1 new file (`admin_theme.dart`), 2 token aliases, 12-file brand sweep; `gtsChartColors` and `AppImage.placeholder` untouched as decided |
| D — responsive QA | Release web build, live data, `admin@gmail.com`, read-only. 1366×768 and 1920×1080: Login, Dashboard, Directory (list), Reports Overview, Events, Activity Logs, Archives, Feedback (list) render without errors/overflow. Pixel samples: avatar + active sidebar indicator exactly `#FCB315` |
| E — functional regression | Colors-only change. `flutter analyze` 19 info (all pre-existing, 4 fewer than baseline); `flutter test` 815 passed / 3 skipped (identical to baseline); sidebar navigation across 8 screens with live data loading. **Not exercised** (unchanged code paths, read-only QA constraint): create/edit/delete/export flows, notification taps, detail views |
| Deviations | None from the approved proposal |
| Follow-ups | Pre-existing observations logged in the progress file (Directory "Page 1 of 2" footer — to investigate read-only in the Directory phase; Dashboard 1920 empty space; Reports header fade; sidebar fold at 1366×768 → Phase 0b) |
