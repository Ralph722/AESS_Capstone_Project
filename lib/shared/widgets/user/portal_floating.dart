import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Floating surfaces over scrolling content: the bottom nav pill and the
/// search/filter cards on Events, Jobs and Community.
abstract final class PortalFloating {
  /// Gap between a tab's last item and the top of the nav bar.
  static const double navGap = 12;

  static List<BoxShadow> shadow({bool lifted = false}) {
    return [
      BoxShadow(
        color: PortalTheme.navy.withValues(alpha: lifted ? 0.16 : 0.10),
        blurRadius: lifted ? 28 : 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Bottom padding for a tab's scroll view so its last item ends above the
  /// floating nav bar. The shell's `extendBody` already puts the nav bar
  /// height in [MediaQuery.paddingOf]; with the side rail it is just the
  /// safe area.
  static double bottomClearance(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + navGap;
}

/// White rounded card that looks lifted off the page.
class PortalFloatingCard extends StatelessWidget {
  const PortalFloatingCard({
    super.key,
    required this.child,
    this.lifted = false,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 12),
  });

  final Widget child;

  /// Content is scrolling underneath, so the shadow deepens.
  final bool lifted;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PortalTheme.fast,
      curve: PortalTheme.ease,
      padding: padding,
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.75)),
        boxShadow: PortalFloating.shadow(lifted: lifted),
      ),
      child: child,
    );
  }
}

/// Search/filter card pinned at the top of a [CustomScrollView].
///
/// When both [search] and [filters] are provided, the card collapses smoothly
/// on scroll: the search input (and optional [meta]) tucks away, leaving only
/// the [filters] row pinned at the top.
/// When scrolling back to the top, the search input smoothly re-expands.
class PortalFloatingFilterHeader extends StatelessWidget {
  const PortalFloatingFilterHeader({
    super.key,
    this.search,
    this.filters,
    this.meta,
    this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.floating = false,
  });

  final Widget? search;
  final Widget? filters;
  final Widget? meta;
  final Widget? child;
  final EdgeInsets padding;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    if (search != null && filters != null) {
      return SliverPersistentHeader(
        pinned: true,
        floating: floating,
        delegate: _CollapsibleFilterHeaderDelegate(
          search: search!,
          filters: filters!,
          meta: meta,
          padding: padding,
        ),
      );
    }

    final content = child ??
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (search != null) search!,
            if (filters != null) filters!,
            if (meta != null) ...[
              const SizedBox(height: 8),
              meta!,
            ],
          ],
        );

    return PinnedHeaderSliver(
      child: Padding(
        padding: padding,
        child: PortalFloatingCard(lifted: true, child: content),
      ),
    );
  }
}

class _CollapsibleFilterHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  _CollapsibleFilterHeaderDelegate({
    required this.search,
    required this.filters,
    this.meta,
    required this.padding,
  });

  final Widget search;
  final Widget filters;
  final Widget? meta;
  final EdgeInsets padding;

  @override
  double get minExtent => 66.0;

  @override
  double get maxExtent => meta != null ? 156.0 : 132.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final progress = range > 0 ? (shrinkOffset / range).clamp(0.0, 1.0) : 0.0;
    final lifted = progress > 0.02 || overlapsContent;

    final currentPad = EdgeInsets.lerp(
      padding,
      EdgeInsets.fromLTRB(padding.left, 6, padding.right, 6),
      progress,
    )!;

    final currentCardPad = EdgeInsets.lerp(
      const EdgeInsets.fromLTRB(14, 12, 14, 10),
      const EdgeInsets.fromLTRB(14, 8, 14, 8),
      progress,
    )!;

    return Padding(
      padding: currentPad,
      child: PortalFloatingCard(
        lifted: lifted,
        padding: currentCardPad,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: maxExtent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (progress < 0.98)
                ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: (1.0 - progress).clamp(0.0, 1.0),
                    child: Opacity(
                      opacity: (1.0 - progress * 2.2).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: progress > 0.3,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: search,
                        ),
                      ),
                    ),
                  ),
                ),
              filters,
              if (meta != null && progress < 0.98)
                ClipRect(
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    heightFactor: (1.0 - progress).clamp(0.0, 1.0),
                    child: Opacity(
                      opacity: (1.0 - progress * 2.5).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        ignoring: progress > 0.3,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: meta!,
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
    );
  }

  @override
  bool shouldRebuild(
    covariant _CollapsibleFilterHeaderDelegate oldDelegate,
  ) {
    return true;
  }
}

/// Page-colour fade behind the floating nav bar, so content dissolves only
/// once it scrolls under the bar. [navHeight] is the bar plus its bottom
/// margin.
class PortalNavFade extends StatelessWidget {
  const PortalNavFade({super.key, required this.navHeight});

  final double navHeight;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: navHeight,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PortalTheme.pageBg.withValues(alpha: 0),
                PortalTheme.pageBg.withValues(alpha: 0.9),
                PortalTheme.pageBg,
              ],
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opaque floating nav pill (solid card surface, not frosted glass).
class PortalFrostedPill extends StatelessWidget {
  const PortalFrostedPill({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return CustomPaint(
      painter: _OutsideShadowPainter(
        radius: radius,
        shadows: PortalFloating.shadow(),
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: PortalTheme.card,
          borderRadius: shape,
          border: Border.all(
            color: PortalTheme.border.withValues(alpha: 0.75),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Soft drop shadow painted only around a rounded rect, never inside it.
class _OutsideShadowPainter extends CustomPainter {
  const _OutsideShadowPainter({required this.radius, required this.shadows});

  final double radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(64))
      ..addRRect(rrect);
    canvas
      ..save()
      ..clipPath(outside);
    for (final shadow in shadows) {
      canvas.drawRRect(
        rrect.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutsideShadowPainter old) =>
      old.radius != radius || !listEquals(old.shadows, shadows);
}
