/// Shared color and surface tokens for the Admin Portal.
///
/// Brand colors come from [UstpColors] (USTP Branding Manual); neutrals and
/// status colors are the established admin values. Spacing and control sizes
/// live in [AdminDensity]. Feature themes (`AdminDirectoryTheme`,
/// `AdminSurveyTheme`, …) alias these tokens.
library;

import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/ustp_colors.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

abstract final class AdminColors {
  // —— Brand ——
  static const Color primary = UstpColors.blue;
  static const Color primaryTint = Color(0xFFE8E7F2);
  static const Color secondary = UstpColors.midBlue;
  static const Color darkNavy = UstpColors.darkNavy;

  /// USTP Gold. Highlights only; not for body text on white.
  static const Color accent = UstpColors.gold;

  // —— Neutrals ——
  /// Content canvas behind cards and tables.
  static const Color background = Color(0xFFF4F6FA);

  /// Shell scaffold behind the sidebar/header layout.
  static const Color shellBackground = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFF1F5F9);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color rowHover = Color(0xFFF1F5F9);

  // —— Text ——
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // —— Status ——
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFEA580C);
  static const Color warningBg = Color(0xFFFFF7ED);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color info = primary;
  static const Color infoBg = primaryTint;
}

/// A USTP colour plus the tint and foreground used on that tint.
@immutable
class AdminAccent {
  const AdminAccent({
    required this.color,
    required this.onTint,
    this.tintAlpha = 0.12,
  });

  /// Strips, bars, dots and chart strokes.
  final Color color;

  /// Text and icons placed on [tint]; always readable on it.
  final Color onTint;

  final double tintAlpha;

  /// Light background for icon chips, tiles and date badges.
  Color get tint =>
      Color.alphaBlend(color.withValues(alpha: tintAlpha), Colors.white);
}

/// Accent palette for dashboard cards, built only from [UstpColors].
abstract final class AdminAccents {
  static const AdminAccent blue = AdminAccent(
    color: UstpColors.blue,
    onTint: UstpColors.blue,
    tintAlpha: 0.1,
  );
  static const AdminAccent sky = AdminAccent(
    color: UstpColors.skyBlue,
    onTint: UstpColors.midBlue,
  );
  static const AdminAccent midBlue = AdminAccent(
    color: UstpColors.midBlue,
    onTint: UstpColors.midBlue,
    tintAlpha: 0.1,
  );

  /// Gold is too light for text or icons, so its foreground is USTP Blue.
  static const AdminAccent gold = AdminAccent(
    color: UstpColors.gold,
    onTint: UstpColors.blue,
    tintAlpha: 0.2,
  );

  /// Orange text on its own tint is below 4.5:1, so its foreground is USTP Blue.
  static const AdminAccent orange = AdminAccent(
    color: UstpColors.orange,
    onTint: UstpColors.blue,
  );
}

abstract final class AdminSurfaces {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get cardShadowHover => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.1),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// Standard white card with large radius, crisp neutral border and soft shadow.
  static BoxDecoration card({bool hovered = false}) => BoxDecoration(
    color: AdminColors.card,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: AdminColors.border),
    boxShadow: hovered ? cardShadowHover : cardShadow,
  );
}

/// System-wide overlay defaults for menus, dropdowns and dialogs across the
/// Admin Portal. Applied via MaterialApp builder when staff / admin views
/// are mounted.
abstract final class AdminOverlayTheme {
  static ThemeData apply(ThemeData base) {
    const menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      side: BorderSide(color: AdminColors.border),
    );

    final menuStyle = MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(6),
      shadowColor: const WidgetStatePropertyAll(Color(0x1F0F172A)),
      shape: const WidgetStatePropertyAll(menuShape),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
    );

    return base.copyWith(
      popupMenuTheme: const PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Color(0x1F0F172A),
        shape: menuShape,
        menuPadding: EdgeInsets.symmetric(vertical: 6),
        position: PopupMenuPosition.under,
        textStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AdminColors.textPrimary,
        ),
      ),
      menuTheme: MenuThemeData(style: menuStyle),
      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: const Color(0x260F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AdminColors.border),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AdminColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13.5,
          color: AdminColors.textSecondary,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      ),
    );
  }
}

/// Admin text styles (Flutter default font). Captions use
/// [AdminColors.textSecondary]; [AdminColors.textMuted] is too low-contrast
/// for small text on white.
abstract final class AdminText {
  static const TextStyle pageTitle = TextStyle(
    fontSize: AdminDensity.titleFontSize,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AdminColors.textPrimary,
  );

  static const TextStyle pageSubtitle = TextStyle(
    fontSize: AdminDensity.subtitleFontSize,
    color: AdminColors.textSecondary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AdminColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: AdminColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AdminColors.textSecondary,
  );

  static const TextStyle kpiValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    color: AdminColors.textPrimary,
  );

  static const TextStyle kpiValueDense = TextStyle(
    fontSize: AdminDensity.kpiValueFontSize,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    color: AdminColors.textPrimary,
  );

  static const TextStyle kpiLabel = TextStyle(
    fontSize: AdminDensity.kpiLabelFontSize,
    fontWeight: FontWeight.w600,
    color: AdminColors.textSecondary,
  );

  static const TextStyle tab = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  static const TextStyle tabActive = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );
}
