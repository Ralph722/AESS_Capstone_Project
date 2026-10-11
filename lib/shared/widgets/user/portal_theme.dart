import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/ustp_colors.dart';

/// Shared alumni / user-portal visual tokens (USTP brand).
///
/// Prefer these over hard-coded colors in feature UI.
/// Feature themes (Forum, Jobs, Messages) should alias these values.
abstract final class PortalTheme {
  // —— Brand (official values live in [UstpColors]) ——
  /// USTP Blue (primary)
  static const Color navy = UstpColors.blue;
  /// Deep secondary for gradients / dark accents
  static const Color navyDeep = UstpColors.darkNavy;
  /// Mid secondary blue
  static const Color navyMid = UstpColors.midBlue;
  /// Soft brand blue (chips, links)
  static const Color sky = UstpColors.skyBlue;
  /// USTP Gold (accent — use sparingly)
  static const Color gold = UstpColors.gold;
  /// Warm secondary accents
  static const Color ember = UstpColors.orange;
  static const Color amber = UstpColors.lightOrange;

  // —— Surfaces ——
  /// Soft cool page wash (navy-tinted, not flat gray).
  static const Color pageBg = Color(0xFFF4F6FA);
  static const Color surfaceMuted = Color(0xFFF1F3F5);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE1E5EA);
  static const Color borderStrong = Color(0xFFD1D5DB);

  // —— Text ——
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnNavy = Colors.white;

  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color badge = Color(0xFFE11D48);

  // —— Geometry ——
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;

  static const double space1 = 8;
  static const double space2 = 12;
  static const double space3 = 16;
  static const double space4 = 20;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double space7 = 40;

  /// Global app-bar / page-header toolbar height (all portal screens).
  static const double headerHeight = 56;
  static const double headerHPad = 16;
  static const double headerIconSize = 22;
  static const double headerActionSize = 40;

  // —— Motion ——
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Curve ease = Curves.easeOutCubic;

  static const LinearGradient navyGradient = LinearGradient(
    colors: [navy, navyMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [navy, navyDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // —— Typography ——
  static const TextStyle display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.15,
    color: textPrimary,
  );

  static const TextStyle pageTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
    color: navy,
  );

  static const TextStyle pageTitleOnDark = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
    color: textOnNavy,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.25,
    color: textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: textSecondary,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: textMuted,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static ButtonStyle primaryButton({bool dense = false}) =>
      FilledButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: textOnNavy,
        disabledBackgroundColor: navy.withValues(alpha: 0.35),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 14 : 20,
          vertical: dense ? 10 : 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: button,
        elevation: 0,
      );

  static ButtonStyle secondaryButton({bool dense = false}) =>
      OutlinedButton.styleFrom(
        foregroundColor: navy,
        side: const BorderSide(color: borderStrong),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 14 : 20,
          vertical: dense ? 10 : 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: button,
      );

  static ButtonStyle ghostButton({bool dense = false}) => TextButton.styleFrom(
        foregroundColor: navy,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 14,
          vertical: dense ? 8 : 10,
        ),
        textStyle: button,
      );

  static ButtonStyle goldAccentButton({bool dense = false}) =>
      FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: navy,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 14 : 20,
          vertical: dense ? 10 : 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: button,
        elevation: 0,
      );
}

/// Clipped rounded card with Material elevation (no BoxDecoration shadow).
/// Avoids grey square leftovers at rounded corners on Flutter web.
class PortalCardShell extends StatelessWidget {
  const PortalCardShell({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.color = Colors.white,
    this.borderColor,
    this.borderWidth = 1,
    this.elevation = 1.25,
    this.shadowColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final double elevation;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(PortalTheme.radiusLg);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(
        color: borderColor ?? PortalTheme.border.withValues(alpha: 0.7),
        width: borderWidth,
      ),
    );

    final content =
        padding == null ? child : Padding(padding: padding!, child: child);

    return Material(
      color: color,
      elevation: elevation,
      shadowColor: shadowColor ?? Colors.black.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              customBorder: shape,
              child: content,
            ),
    );
  }
}
