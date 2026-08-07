/// Desktop-first density tokens for the Admin Portal.
///
/// Phase 2 of the density pass: one spacing scale so pages, cards, sections,
/// and tables share the same rhythm without redesigning brand colors.
///
/// Target: more content visible at Chrome 100% on 1366–1920 while keeping
/// readable type and ≥36px primary control heights.
library;

import 'package:flutter/material.dart';

/// Canonical spacing / control / page-chrome metrics for admin screens.
abstract final class AdminDensity {
  // —— Spacing scale (8px base, denser than the old 8/16/24/32) ——
  static const double space1 = 8;
  static const double space2 = 12;
  static const double space3 = 16;
  static const double space4 = 24;

  /// Preferred gap between major page sections (header → stats → toolbar).
  static const double sectionGap = space3;

  /// Gap between sibling cards in a grid.
  static const double gridGap = space2;

  /// Inner padding for standard surface cards.
  static const double cardPadding = 12;

  /// Vertical gap between list cards.
  static const double listItemGap = 8;

  // —— Responsive content (inside shell + sidebar) ——
  /// Content width at which KPI/stat grids prefer 4 columns.
  static const double statsFourColMin = 900;

  /// Content width at which KPI/stat grids prefer 2 columns.
  static const double statsTwoColMin = 560;

  /// Content width for dashboard dual-pane / table layouts.
  static const double desktopSplitMin = 900;

  // —— Controls ——
  /// Primary / toolbar button min height (WCAG 2.2 AA pointer target floor
  /// for densified desktop chrome; denser than Material's default 48).
  static const double buttonHeight = 36;

  /// Compact chip / badge visual height (non-primary). Prefer [minTapTarget]
  /// for anything the user must click or activate with the keyboard.
  static const double controlHeight = 32;

  /// Minimum interactive hit/focus box for icon buttons and dense controls.
  static const double minTapTarget = buttonHeight;

  static const Size minTapSize = Size(minTapTarget, minTapTarget);

  /// Shared [IconButton] style: dense look, ≥36×36 hit target, clear focus.
  static ButtonStyle iconButtonStyle({
    Color? foregroundColor,
    Color? backgroundColor,
  }) {
    return IconButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      minimumSize: minTapSize,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.all(8),
    );
  }

  // —— Page chrome ——
  /// Shell content inset around IndexedStack pages (wide desktop).
  static const double shellPaddingWide = 16;

  /// Shell content inset on narrower admin windows.
  static const double shellPaddingNarrow = 12;

  /// Extra horizontal padding pages may add inside the shell (avoid stacking
  /// large values on top of [shellPaddingWide]).
  static const double pagePaddingWide = 12;
  static const double pagePaddingStandard = 8;
  static const double pagePaddingNarrow = 4;

  static const double pagePaddingVertical = 8;

  // —— Typography rhythm (defaults; screens may override) ——
  static const double titleFontSize = 20;
  static const double subtitleFontSize = 13;
  static const double sectionTitleFontSize = 14;

  // —— Tables ——
  static const double tableHeaderHeight = 36;
  static const double tableRowMinHeight = 40;
  static const double tableHorizontalPadding = 12;
  static const double tableCellGap = 10;

  // —— KPI / metric cards ——
  static const double kpiCardPadding = 12;
  static const double kpiValueFontSize = 22;
  static const double kpiLabelFontSize = 12;
  static const double kpiIconBox = 32;
  static const double kpiIconSize = 18;
  static const double kpiMinHeight = 72;
  static const double reportsKpiHeight = 120;

  // —— Forms / dialogs ——
  static const double formSectionPadding = 14;
  static const double formFieldGap = 12;
  static const EdgeInsets formActionsPadding =
      EdgeInsets.fromLTRB(16, 8, 16, 8);
  static const EdgeInsets dialogInsetPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 16);

  /// Shell padding based on viewport width.
  static EdgeInsets shellPaddingForWidth(double width) {
    final p = width < 1100 ? shellPaddingNarrow : shellPaddingWide;
    return EdgeInsets.all(p);
  }

  /// Page-local horizontal padding (in addition to shell). Keep small.
  static double pageHorizontalForWidth(double width) {
    if (width >= 1400) return pagePaddingWide;
    if (width >= 1024) return pagePaddingStandard;
    if (width >= 768) return pagePaddingStandard;
    return pagePaddingNarrow;
  }

  static EdgeInsets pageInsetsForWidth(double width) {
    return EdgeInsets.fromLTRB(
      pageHorizontalForWidth(width),
      pagePaddingVertical,
      pageHorizontalForWidth(width),
      pagePaddingVertical,
    );
  }
}
