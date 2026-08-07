import 'package:flutter/material.dart';

const Color _skeletonBase = Color(0xFFE4E7EE);
const Color _skeletonHighlight = Color(0xFFF2F4F8);

/// Drives shimmer animation for descendant [Skeleton] widgets.
class ShimmerScope extends StatefulWidget {
  const ShimmerScope({super.key, required this.child});

  final Widget child;

  static Animation<double>? animationOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ShimmerInherited>();
    return scope?.animation;
  }

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerInherited(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerInherited extends InheritedWidget {
  const _ShimmerInherited({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_ShimmerInherited oldWidget) =>
      oldWidget.animation != animation;
}

/// Single shimmering placeholder bar/block.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final animation = ShimmerScope.animationOf(context);
    final radius = borderRadius ?? BorderRadius.circular(6);

    if (animation == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: _skeletonBase, borderRadius: radius),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1.2 + 2.4 * t, 0),
              end: Alignment(-0.2 + 2.4 * t, 0),
              colors: const [_skeletonBase, _skeletonHighlight, _skeletonBase],
            ),
          ),
        );
      },
    );
  }
}
