import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  });

  final Widget child;

  /// Content is scrolling underneath, so the shadow deepens.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PortalTheme.fast,
      curve: PortalTheme.ease,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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

/// Search/filter card pinned at the top of a [CustomScrollView]. The list
/// scrolls behind it and fades out in the gap under the app bar.
class PortalFloatingFilterHeader extends StatefulWidget {
  const PortalFloatingFilterHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  /// Contents of the card.
  final Widget child;
  final EdgeInsets padding;

  @override
  State<PortalFloatingFilterHeader> createState() =>
      _PortalFloatingFilterHeaderState();
}

class _PortalFloatingFilterHeaderState
    extends State<PortalFloatingFilterHeader> {
  ScrollPosition? _position;
  bool _lifted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _position) return;
    _position?.removeListener(_onScroll);
    _position = position?..addListener(_onScroll);
    _lifted = _isLifted();
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  bool _isLifted() {
    final p = _position;
    return p != null &&
        p.hasPixels &&
        p.hasContentDimensions &&
        p.pixels > p.minScrollExtent + 0.5;
  }

  void _onScroll() {
    if (_isLifted() == _lifted) return;
    // Positions can notify mid-layout, when a rebuild is not allowed.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
    } else {
      _sync();
    }
  }

  void _sync() {
    final lifted = _isLifted();
    if (mounted && lifted != _lifted) setState(() => _lifted = lifted);
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.padding;
    return PinnedHeaderSliver(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: pad.top + 28,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _lifted ? 1 : 0,
                duration: PortalTheme.fast,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        PortalTheme.pageBg,
                        PortalTheme.pageBg.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: pad,
            child: PortalFloatingCard(lifted: _lifted, child: widget.child),
          ),
        ],
      ),
    );
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
