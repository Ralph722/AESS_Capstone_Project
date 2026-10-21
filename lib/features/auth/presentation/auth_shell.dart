import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    required this.title,
    required this.subtitle,
    required this.form,
    this.backLabel = 'Back',
    this.showBackButton = true,
  });

  /// Screen heading, placed by the shell so each layout can position it.
  final String title;

  /// Supporting line under [title].
  final String subtitle;

  /// The fields and actions for this screen.
  final Widget form;

  /// Label for the return affordance shown when this screen was pushed.
  final String backLabel;

  /// Whether a pushed screen shows the back pill. Screens with their own
  /// in-form return link can turn it off.
  final bool showBackButton;

  static const double _splitBreakpoint = 900;
  static const double _formMaxWidth = 400;

  /// Inner padding of the desktop form card.
  static const double _cardPadding = 36;

  /// Space between the desktop card and the screen edge.
  static const double _cardGutter = 48;

  /// How far the mobile form sheet rides up over the brand hero.
  static const double _sheetOverlap = 26;

  /// The mobile sheet never starts lower than this share of the screen.
  static const double _maxHeroFraction = 0.36;

  @override
  Widget build(BuildContext context) {
    // Register is pushed on top of Login, so a pop returns to sign-in.
    final canReturn = showBackButton && Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _splitBreakpoint;
          if (wide) {
            final cardColumnWidth = math.min(
              _formMaxWidth + 2 * _cardPadding + 2 * _cardGutter,
              constraints.maxWidth * 0.55,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                const _BrandBackdrop(),
                SafeArea(
                  child: Row(
                    children: [
                      const Expanded(child: _BrandMessage()),
                      SizedBox(
                        width: cardColumnWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pinned so it stays reachable on long forms.
                            if (canReturn)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  _cardGutter,
                                  PortalTheme.space4,
                                  _cardGutter,
                                  0,
                                ),
                                child: _HeroBackButton(label: backLabel),
                              ),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _cardGutter,
                                    vertical: PortalTheme.space5,
                                  ),
                                  child: _FadeSlideIn(
                                    child: _DesktopFormCard(
                                      maxWidth:
                                          _formMaxWidth + 2 * _cardPadding,
                                      padding: _cardPadding,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _FormHeading(
                                            title: title,
                                            subtitle: subtitle,
                                            titleSize: 28,
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
                    ],
                  ),
                ),
              ],
            );
          }

          final viewportHeight = constraints.maxHeight;
          return _MobileAuthLayout(
            viewportHeight: viewportHeight,
            minHeroHeight: (viewportHeight * 0.28).clamp(150.0, 240.0),
            maxHeroHeight: viewportHeight * _maxHeroFraction,
            overlap: _sheetOverlap,
            hero: _MobileHero(canReturn: canReturn, backLabel: backLabel),
            sheet: _MobileFormSheet(
              title: title,
              subtitle: subtitle,
              form: form,
            ),
          );
        },
      ),
    );
  }
}

/// White form card floating over the campus photo on wide layouts.
class _DesktopFormCard extends StatelessWidget {
  const _DesktopFormCard({
    required this.maxWidth,
    required this.padding,
    required this.child,
  });

  final double maxWidth;
  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 48,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: padding + 20,
          ),
          child: child,
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
    required this.title,
    required this.subtitle,
    required this.titleSize,
  });

  final String title;
  final String subtitle;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

/// Full-screen campus photo with the navy tint, behind the desktop card.
class _BrandBackdrop extends StatelessWidget {
  const _BrandBackdrop();

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
                const ColoredBox(color: PortalTheme.navy),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                PortalTheme.navy.withValues(alpha: 0.86),
                PortalTheme.navy.withValues(alpha: 0.74),
                PortalTheme.navy.withValues(alpha: 0.66),
              ],
              stops: const [0, 0.5, 1],
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
      ],
    );
  }
}

/// Logo and brand copy on the left of the desktop card.
class _BrandMessage extends StatelessWidget {
  const _BrandMessage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Small windows keep the headline and drop the extras.
        final roomy = box.maxHeight >= 720;
        final narrow = box.maxWidth < 440;
        return _content(roomy: roomy, narrow: narrow);
      },
    );
  }

  Widget _content({required bool roomy, required bool narrow}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 40, 24, 36),
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
              Flexible(
                child: Text(
                  'ALUMNI ENGAGEMENT AND SUPPORT SYSTEM',
                  style: PortalTheme.meta.copyWith(
                    color: PortalTheme.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontSize: 11.5,
                  ),
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
                fontSize: narrow ? 24 : 30,
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
          if (roomy) ...[
            const SizedBox(height: PortalTheme.space5),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _BrandPoint(icon: Icons.assignment_outlined, label: 'Surveys'),
                _BrandPoint(
                  icon: Icons.route_outlined,
                  label: 'Graduate tracer',
                ),
                _BrandPoint(icon: Icons.event_outlined, label: 'Events'),
                _BrandPoint(icon: Icons.work_outline, label: 'Jobs'),
              ],
            ),
          ],
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
              const ColoredBox(color: PortalTheme.navy),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PortalTheme.navy.withValues(alpha: 0.55),
                PortalTheme.navy.withValues(alpha: 0.8),
                PortalTheme.navy.withValues(alpha: 0.97),
              ],
              stops: const [0, 0.55, 1],
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
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          PortalTheme.space5,
          22,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: _FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

/// Phone layout: the hero takes whatever height the sheet leaves free, up to
/// its cap, so short forms sit in the upper part of tall phones while the
/// primary button stays on screen. Long forms scroll the hero away with the
/// page.
class _MobileAuthLayout extends StatefulWidget {
  const _MobileAuthLayout({
    required this.viewportHeight,
    required this.minHeroHeight,
    required this.maxHeroHeight,
    required this.overlap,
    required this.hero,
    required this.sheet,
  });

  final double viewportHeight;
  final double minHeroHeight;
  final double maxHeroHeight;
  final double overlap;
  final Widget hero;
  final Widget sheet;

  @override
  State<_MobileAuthLayout> createState() => _MobileAuthLayoutState();
}

class _MobileAuthLayoutState extends State<_MobileAuthLayout> {
  final _scrolled = ValueNotifier(false);

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.viewPaddingOf(context).top;
    // Keep room to scroll the focused field above the keyboard. The scaffold
    // already shrinks when inset; extra padding covers cases where it does not.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.depth == 0) _scrolled.value = n.metrics.pixels > 0;
              return false;
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: keyboard),
              child: _HeroSheetLayout(
                viewportHeight: widget.viewportHeight,
                minHeroHeight: widget.minHeroHeight,
                maxHeroHeight: widget.maxHeroHeight,
                overlap: widget.overlap,
                children: [widget.hero, widget.sheet],
              ),
            ),
          ),
          // Keeps the light status-bar icons readable once the hero has
          // scrolled out from under them.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: statusBar,
            child: IgnorePointer(
              child: ValueListenableBuilder<bool>(
                valueListenable: _scrolled,
                builder: (context, scrolled, _) => AnimatedOpacity(
                  opacity: scrolled ? 1 : 0,
                  duration: PortalTheme.fast,
                  child: const ColoredBox(color: PortalTheme.navy),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stacks the mobile hero and form sheet inside a scroll view, giving the hero
/// the height the sheet leaves free within [minHeroHeight]..[maxHeroHeight].
class _HeroSheetLayout extends MultiChildRenderObjectWidget {
  const _HeroSheetLayout({
    required this.viewportHeight,
    required this.minHeroHeight,
    required this.maxHeroHeight,
    required this.overlap,
    required super.children,
  }) : assert(children.length == 2);

  final double viewportHeight;
  final double minHeroHeight;
  final double maxHeroHeight;
  final double overlap;

  @override
  _RenderHeroSheet createRenderObject(BuildContext context) {
    return _RenderHeroSheet(
      viewportHeight: viewportHeight,
      minHeroHeight: minHeroHeight,
      maxHeroHeight: maxHeroHeight,
      overlap: overlap,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderHeroSheet renderObject) {
    renderObject
      ..viewportHeight = viewportHeight
      ..minHeroHeight = minHeroHeight
      ..maxHeroHeight = maxHeroHeight
      ..overlap = overlap;
  }
}

class _HeroSheetParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderHeroSheet extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeroSheetParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeroSheetParentData> {
  _RenderHeroSheet({
    required double viewportHeight,
    required double minHeroHeight,
    required double maxHeroHeight,
    required double overlap,
  }) : _viewportHeight = viewportHeight,
       _minHeroHeight = minHeroHeight,
       _maxHeroHeight = maxHeroHeight,
       _overlap = overlap;

  double _viewportHeight;
  set viewportHeight(double value) {
    if (value == _viewportHeight) return;
    _viewportHeight = value;
    markNeedsLayout();
  }

  double _minHeroHeight;
  set minHeroHeight(double value) {
    if (value == _minHeroHeight) return;
    _minHeroHeight = value;
    markNeedsLayout();
  }

  double _maxHeroHeight;
  set maxHeroHeight(double value) {
    if (value == _maxHeroHeight) return;
    _maxHeroHeight = value;
    markNeedsLayout();
  }

  double _overlap;
  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeroSheetParentData) {
      child.parentData = _HeroSheetParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final hero = firstChild!;
    final sheet = lastChild!;

    // Let the sheet size to its content first (no max-height cap). A tight
    // height used to stretch short forms overflowed long ones (e.g. reset
    // password) by a few dozen pixels on phones.
    sheet.layout(
      BoxConstraints(minWidth: width, maxWidth: width),
      parentUsesSize: true,
    );
    var sheetHeight = sheet.size.height;

    final maxHero = math.max(_minHeroHeight, _maxHeroHeight);
    final heroHeight = (_viewportHeight - sheetHeight + _overlap).clamp(
      _minHeroHeight,
      maxHero,
    );
    hero.layout(BoxConstraints.tightFor(width: width, height: heroHeight));

    final sheetTop = heroHeight - _overlap;
    // Short forms: grow the sheet to the bottom without capping taller forms.
    final fillHeight = _viewportHeight - sheetTop;
    if (sheetHeight < fillHeight) {
      sheet.layout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: fillHeight,
        ),
        parentUsesSize: true,
      );
      sheetHeight = sheet.size.height;
    }
    (hero.parentData! as _HeroSheetParentData).offset = Offset.zero;
    (sheet.parentData! as _HeroSheetParentData).offset = Offset(0, sheetTop);

    // Prefer content height over parent max so the outer scroll view can
    // scroll instead of clipping the form Column.
    final contentHeight = math.max(_viewportHeight, sheetTop + sheetHeight);
    size = Size(width, contentHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
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
