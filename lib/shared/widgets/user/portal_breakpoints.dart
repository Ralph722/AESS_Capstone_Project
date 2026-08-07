import 'package:flutter/material.dart';

/// Alumni portal layout breakpoints (phone → tablet → wide web).
abstract final class PortalBreakpoints {
  /// Phones / compact.
  static const double compact = 600;

  /// Large phones / small tablets (two-column friendly).
  static const double medium = 840;

  /// Tablets / desktop web (rail + multi-column). Matches Forum ≥900.
  static const double expanded = 900;

  /// Max readable content width for single-column surfaces.
  static const double contentMax = 1100;

  /// Comfortable max for chat / forms on tablet.
  static const double chatMax = 760;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isCompact(double width) => width < compact;

  static bool isMedium(double width) => width >= compact && width < expanded;

  static bool isExpanded(double width) => width >= expanded;

  static bool useNavigationRail(double width) => width >= expanded;

  /// Quick-access / featured job grid columns.
  static int horizontalCardColumns(double width) {
    if (width >= expanded) return 3;
    if (width >= compact) return 2;
    return 1;
  }

  static int quickLinkColumns(double width) {
    if (width >= expanded) return 4;
    if (width >= compact) return 3;
    return 2;
  }

  static int eventListColumns(double width) {
    if (width >= expanded) return 2;
    return 1;
  }

  static EdgeInsets pagePadding(double width) {
    if (width >= expanded) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    }
    if (width >= compact) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  }
}

/// Centers [child] and caps width so tablet/web don't stretch endlessly.
class PortalContentFrame extends StatelessWidget {
  const PortalContentFrame({
    super.key,
    required this.child,
    this.maxWidth = PortalBreakpoints.contentMax,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
