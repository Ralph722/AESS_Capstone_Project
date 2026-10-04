import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Shared visual shell for Login / Registration.
///
/// Wide viewports: photographic brand panel + clean form column.
/// Narrow viewports: form-first layout with compact brand mark.
/// UI chrome only — does not own authentication logic.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.form,
    this.backLabel = 'Back',
  });

  /// Short label above the heading on wide layouts (e.g. "Sign in").
  final String eyebrow;

  /// Screen heading, placed by the shell so each layout can position it.
  final String title;

  /// Supporting line under [title].
  final String subtitle;

  /// The fields and actions for this screen.
  final Widget form;

  /// Label for the return affordance shown when this screen was pushed.
  final String backLabel;

  static const double _splitBreakpoint = 900;
  static const double _formMaxWidth = 440;

  /// How far the mobile form sheet rides up over the brand hero.
  static const double _sheetOverlap = 26;

  @override
  Widget build(BuildContext context) {
    // Register is pushed on top of Login, so a pop returns to sign-in.
    final canReturn = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _splitBreakpoint;
          if (wide) {
            // Cap the photo panel so it never dominates ultra-wide monitors.
            final brandWidth = (constraints.maxWidth * 0.54).clamp(
              460.0,
              820.0,
            );

            return Row(
              children: [
                SizedBox(width: brandWidth, child: const _BrandPanel()),
                Expanded(
                  child: ColoredBox(
                    color: Colors.white,
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Pinned so it stays reachable on long forms.
                          if (canReturn) _DesktopBackBar(label: backLabel),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  PortalTheme.space6,
                                  canReturn
                                      ? PortalTheme.space3
                                      : PortalTheme.space6,
                                  PortalTheme.space6,
                                  PortalTheme.space6,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: _formMaxWidth,
                                  ),
                                  child: _FadeSlideIn(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _FormHeading(
                                          eyebrow: eyebrow,
                                          title: title,
                                          subtitle: subtitle,
                                          titleSize: 30,
                                        ),
                                        const SizedBox(
                                          height: PortalTheme.space5,
                                        ),
                                        form,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final heroHeight = (constraints.maxHeight * 0.28).clamp(150.0, 240.0);

          // Hero stays pinned; only the sheet scrolls, so branding and the
          // back button remain visible on long forms.
          return ColoredBox(
            color: Colors.white,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: heroHeight,
                  child: _MobileHero(
                    canReturn: canReturn,
                    backLabel: backLabel,
                  ),
                ),
                Positioned(
                  top: heroHeight - _sheetOverlap,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _MobileFormSheet(
                    title: title,
                    subtitle: subtitle,
                    form: form,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Always-visible return path at the top of the desktop form column.
class _DesktopBackBar extends StatelessWidget {
  const _DesktopBackBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PortalTheme.space5,
        PortalTheme.space4,
        PortalTheme.space5,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(label),
          style: PortalTheme.ghostButton(dense: true).copyWith(
            foregroundColor: const WidgetStatePropertyAll(PortalTheme.navy),
          ),
        ),
      ),
    );
  }
}

/// Entrance transition shared by both layouts.
class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: PortalTheme.normal,
      curve: PortalTheme.ease,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _FormHeading extends StatelessWidget {
  const _FormHeading({
    this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.titleSize,
  });

  final String? eyebrow;
  final String title;
  final String subtitle;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final label = eyebrow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Container(
                width: 22,
                height: 3,
                decoration: BoxDecoration(
                  color: PortalTheme.gold,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: PortalTheme.meta.copyWith(
                  color: PortalTheme.navyMid,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Text(
          title,
          style: PortalTheme.display.copyWith(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            color: PortalTheme.navy,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: PortalTheme.bodySecondary.copyWith(height: 1.45)),
      ],
    );
  }
}

/// Anchors the desktop form column so it doesn't float in empty white space.
/// Campus photo + navy tint overlay with concise brand messaging.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/auth_campus_hero.png',
            fit: BoxFit.cover,
            // Bias left so the white building on the photo's left edge stays visible.
            alignment: const Alignment(-0.55, -0.1),
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: PortalTheme.navyDeep),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PortalTheme.navy.withValues(alpha: 0.68),
                PortalTheme.navyDeep.withValues(alpha: 0.74),
                PortalTheme.navyMid.withValues(alpha: 0.58),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.26),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(44, 40, 44, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _OfficialLogo(width: 132),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        color: PortalTheme.gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ALUMNI ENGAGEMENT AND SUPPORT SYSTEM',
                      style: PortalTheme.meta.copyWith(
                        color: PortalTheme.gold,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Stay connected to campus life, careers, and your alumni community.',
                    style: PortalTheme.sectionTitle.copyWith(
                      color: Colors.white,
                      fontSize: 30,
                      height: 1.24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Text(
                    'Surveys, graduate tracing, and campus engagement in one portal.',
                    style: PortalTheme.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      height: 1.55,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const SizedBox(height: PortalTheme.space5),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _BrandPoint(
                      icon: Icons.assignment_outlined,
                      label: 'Surveys',
                    ),
                    _BrandPoint(
                      icon: Icons.route_outlined,
                      label: 'Graduate tracer',
                    ),
                    _BrandPoint(icon: Icons.event_outlined, label: 'Events'),
                    _BrandPoint(icon: Icons.work_outline, label: 'Jobs'),
                  ],
                ),
                const SizedBox(height: PortalTheme.space6),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                const SizedBox(height: PortalTheme.space3),
                Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'University of Science and Technology of Southern Philippines',
                        style: PortalTheme.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact campus-photo banner that anchors the mobile layout.
class _MobileHero extends StatelessWidget {
  const _MobileHero({required this.canReturn, required this.backLabel});

  final bool canReturn;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/auth_campus_hero.png',
          fit: BoxFit.cover,
          alignment: const Alignment(-0.55, -0.1),
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: PortalTheme.navyDeep),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PortalTheme.navy.withValues(alpha: 0.86),
                PortalTheme.navyDeep.withValues(alpha: 0.9),
                PortalTheme.navyMid.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) {
              // The hero shrinks when the keyboard is up; drop the tagline and
              // tighten the mark instead of overflowing.
              final compact = box.maxHeight < 200;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  canReturn ? 8 : 16,
                  20,
                  compact ? 30 : 38,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canReturn)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _HeroBackButton(label: backLabel),
                      ),
                    const Spacer(),
                    Center(child: _OfficialLogo(width: compact ? 108 : 136)),
                    const Spacer(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeroBackButton extends StatelessWidget {
  const _HeroBackButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.maybePop(context),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back, size: 18, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                label,
                style: PortalTheme.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded white surface that carries the heading and form on mobile.
class _MobileFormSheet extends StatelessWidget {
  const _MobileFormSheet({
    required this.title,
    required this.subtitle,
    required this.form,
  });

  final String title;
  final String subtitle;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PortalTheme.radius2xl),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F0B1B33),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          18,
          22,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: _FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PortalTheme.navy.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: PortalTheme.space5),
              _FormHeading(title: title, subtitle: subtitle, titleSize: 24),
              const SizedBox(height: PortalTheme.space5),
              form,
            ],
          ),
        ),
      ),
    );
  }
}

/// Official AESS SVG wordmark — original USTP navy and gold, unmodified.
///
/// A blurred white silhouette sits behind the mark so the navy letterforms
/// separate from the campus photo without a solid plate behind them.
class _OfficialLogo extends StatelessWidget {
  const _OfficialLogo({required this.width});

  final double width;

  /// Intrinsic SVG aspect from the cropped viewBox (780×320).
  static const double _aspect = 780 / 320;

  @override
  Widget build(BuildContext context) {
    final height = width / _aspect;

    Widget mark({ColorFilter? filter}) => SvgPicture.asset(
      'assets/images/aess_logo.svg',
      width: width,
      height: height,
      fit: BoxFit.fill,
      allowDrawingOutsideViewBox: true,
      clipBehavior: Clip.none,
      colorFilter: filter,
      placeholderBuilder: (_) => SizedBox(width: width, height: height),
    );

    final silhouette = mark(
      filter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );

    Widget glow(double sigma, double scale) => ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: Transform.scale(scale: scale, child: silhouette),
    );

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Wide soft glow, then a tight pass that acts as the outline edge.
          glow(width * 0.055, 1.05),
          glow(width * 0.018, 1.03),
          mark(),
        ],
      ),
    );
  }
}

class _BrandPoint extends StatelessWidget {
  const _BrandPoint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: PortalTheme.gold),
          const SizedBox(width: 7),
          Text(
            label,
            style: PortalTheme.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Canonical auth input style — mirrors portal forms with clearer focus.
InputDecoration authFieldDecoration({
  required String label,
  IconData? icon,
  bool enabled = true,
  String? helperText,
  Widget? suffixIcon,
}) {
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: PortalTheme.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      color: PortalTheme.navy,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    helperText: helperText,
    helperStyle: PortalTheme.caption.copyWith(fontSize: 12),
    prefixIcon: icon == null
        ? null
        : Icon(
            icon,
            size: 20,
            color: enabled ? PortalTheme.navy : PortalTheme.textMuted,
          ),
    suffixIcon: suffixIcon,
    filled: true,
    // Soft tint keeps fields legible on the white form surfaces.
    fillColor: enabled ? const Color(0xFFF8F9FC) : PortalTheme.surfaceMuted,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: outline(PortalTheme.border),
    enabledBorder: outline(PortalTheme.border),
    disabledBorder: outline(PortalTheme.border.withValues(alpha: 0.6)),
    focusedBorder: outline(PortalTheme.navy, 1.6),
    errorBorder: outline(PortalTheme.danger.withValues(alpha: 0.55)),
    focusedErrorBorder: outline(PortalTheme.danger, 1.6),
  );
}

/// Primary CTA used by both auth screens.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return PortalTheme.navy.withValues(alpha: 0.45);
          }
          if (states.contains(WidgetState.pressed)) {
            return PortalTheme.navyDeep;
          }
          if (states.contains(WidgetState.hovered)) {
            return PortalTheme.gold;
          }
          return PortalTheme.navy;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) &&
              !states.contains(WidgetState.disabled)) {
            return PortalTheme.navy;
          }
          return Colors.white;
        }),
        elevation: const WidgetStatePropertyAll(0),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(label),
    );
  }
}

/// Floating themed SnackBar using portal status tokens.
void showAuthFeedback(
  BuildContext context,
  String message, {
  bool error = true,
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: PortalTheme.body.copyWith(color: Colors.white),
        ),
        backgroundColor: error ? PortalTheme.danger : PortalTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        ),
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
}
