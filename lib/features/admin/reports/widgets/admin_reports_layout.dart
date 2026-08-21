import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';

/// Design tokens for Reports & Analytics — mirrors the admin portal system.
abstract final class AdminReportsTheme {
  static const primary = AdminDirectoryTheme.primary;
  static const gold = AdminDirectoryTheme.gold;
  static const background = AdminDirectoryTheme.background;
  static const surface = AdminDirectoryTheme.surface;
  static const card = AdminDirectoryTheme.card;
  static const border = AdminDirectoryTheme.border;
  static const textPrimary = AdminDirectoryTheme.textPrimary;
  static const textSecondary = AdminDirectoryTheme.textSecondary;
  static const textMuted = AdminDirectoryTheme.textMuted;
  static const success = AdminDirectoryTheme.success;
  static const warning = AdminDirectoryTheme.warning;
  static const danger = AdminDirectoryTheme.danger;

  static const space1 = AdminDirectoryTheme.space1;
  static const space2 = AdminDirectoryTheme.space2;
  static const space3 = AdminDirectoryTheme.space3;
  static const space4 = AdminDirectoryTheme.space4;
  static const radiusMd = AdminDirectoryTheme.radiusMd;
  static const radiusLg = AdminDirectoryTheme.radiusLg;

  /// Standard gutter between sibling dashboard cards.
  static const gutter = space2;

  /// Vertical rhythm between major section blocks.
  static const sectionGap = space3;

  static List<BoxShadow> get cardShadow => AdminDirectoryTheme.cardShadow;

  static BoxDecoration surfaceCard({bool hovered = false}) =>
      AdminDirectoryTheme.surfaceCard(hovered: hovered);
}

/// Stretches dashboard content across the full available width.
class ReportsDashboardCanvas extends StatelessWidget {
  const ReportsDashboardCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, child: child);
  }
}

/// Workspace panel that wraps the active tab content.
class ReportsWorkspacePanel extends StatelessWidget {
  const ReportsWorkspacePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminReportsTheme.space3),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: child,
    );
  }
}

/// Analytics section block with title, description, actions, and optional collapse.
class ReportsSectionShell extends StatefulWidget {
  const ReportsSectionShell({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.actions = const [],
    required this.child,
    this.padded = true,
    this.showDivider = true,
    this.collapsible = true,
    this.initiallyExpanded = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> actions;
  final Widget child;
  final bool padded;
  final bool showDivider;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  State<ReportsSectionShell> createState() => _ReportsSectionShellState();
}

class _ReportsSectionShellState extends State<ReportsSectionShell>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.collapsible
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(AdminReportsTheme.radiusLg),
                bottom: Radius.circular(
                  _expanded ? 0 : AdminReportsTheme.radiusLg,
                ),
              ),
              child: Semantics(
                button: widget.collapsible,
                expanded: widget.collapsible ? _expanded : null,
                label: widget.collapsible
                    ? '${widget.title}. ${widget.subtitle ?? ''}. '
                          '${_expanded ? 'Expanded' : 'Collapsed'}. Double tap to toggle.'
                    : '${widget.title}. ${widget.subtitle ?? ''}',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.icon != null) ...[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AdminReportsTheme.primary.withValues(
                              alpha: 0.09,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.icon,
                            size: 18,
                            color: AdminReportsTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AdminReportsTheme.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (widget.subtitle != null &&
                                widget.subtitle!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.subtitle!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: AdminReportsTheme.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.actions.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: widget.actions,
                        ),
                      ],
                      if (widget.trailing != null) ...[
                        const SizedBox(width: 4),
                        widget.trailing!,
                      ],
                      if (widget.collapsible) ...[
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(
                            Icons.expand_more_rounded,
                            color: AdminReportsTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.collapsible)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.showDivider)
                            const Divider(
                              height: 1,
                              color: AdminReportsTheme.border,
                            ),
                          Padding(
                            padding: widget.padded
                                ? const EdgeInsets.fromLTRB(14, 14, 14, 14)
                                : EdgeInsets.zero,
                            child: widget.child,
                          ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showDivider)
                  const Divider(height: 1, color: AdminReportsTheme.border),
                Padding(
                  padding: widget.padded
                      ? const EdgeInsets.fromLTRB(14, 14, 14, 14)
                      : EdgeInsets.zero,
                  child: widget.child,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Destination tile used on Overview “Go to detail”.
class ReportsNavTile extends StatefulWidget {
  const ReportsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AdminReportsTheme.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  State<ReportsNavTile> createState() => _ReportsNavTileState();
}

class _ReportsNavTileState extends State<ReportsNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.06)
                  : AdminReportsTheme.surface,
              borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
              border: Border.all(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.28)
                    : AdminReportsTheme.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AdminReportsTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: AdminReportsTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: widget.color.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact text action used in [ReportsSectionShell.actions].
class ReportsSectionAction extends StatelessWidget {
  const ReportsSectionAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AdminReportsTheme.primary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Vertical stack of [ReportsSectionShell] blocks with standard section gaps.
class ReportsSectionStack extends StatelessWidget {
  const ReportsSectionStack({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AdminReportsTheme.sectionGap),
          children[i],
        ],
      ],
    );
  }
}

/// Responsive metric / card grid with consistent gutters.
class ReportsResponsiveGrid extends StatelessWidget {
  const ReportsResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 220,
    this.maxColumns = 4,
    this.gutter = AdminReportsTheme.gutter,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double minItemWidth;
  final int maxColumns;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var cols = (width / (minItemWidth + gutter)).floor().clamp(
          1,
          maxColumns,
        );
        if (width < 500) cols = 1;
        final itemWidth = cols == 1
            ? width
            : (width - (cols - 1) * gutter) / cols;
        return Wrap(
          spacing: gutter,
          runSpacing: gutter,
          children: [
            for (var i = 0; i < itemCount; i++)
              SizedBox(width: itemWidth, child: itemBuilder(context, i)),
          ],
        );
      },
    );
  }
}

/// Standard chart card heights for dashboard rhythm.
abstract final class ReportsChartHeights {
  static const hero = 360.0;
  static const standard = 300.0;
  static const compact = 260.0;
}

/// Chart / content card chrome shared by report visualizations.
class ReportsChartSurface extends StatelessWidget {
  const ReportsChartSurface({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.details,
    this.height,
    this.hero = false,
    this.padding = const EdgeInsets.all(AdminReportsTheme.space3),
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Methodology text shown via ⓘ next to the title.
  final String? details;
  final double? height;
  final bool hero;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final detailsText = details?.trim();
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
        border: Border.all(
          color: hero
              ? AdminReportsTheme.primary.withValues(alpha: 0.22)
              : AdminReportsTheme.border,
          width: hero ? 1.5 : 1,
        ),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (hero) ...[
                  Container(
                    width: 6,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AdminReportsTheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: hero ? 16 : 15,
                      fontWeight: FontWeight.w700,
                      color: AdminReportsTheme.textPrimary,
                    ),
                  ),
                ),
                if (detailsText != null && detailsText.isNotEmpty)
                  ReportsDetailsButton(title: title!, body: detailsText),
              ],
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AdminReportsTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AdminReportsTheme.space2),
          ],
          if (height != null) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// Compact ranked list used when a chart would be sparse (small n).
class ReportsRankedSummary extends StatelessWidget {
  const ReportsRankedSummary({
    super.key,
    required this.entries,
    this.totalLabel = 'responses',
    this.accent,
  });

  final List<MapEntry<String, int>> entries;
  final String totalLabel;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final color = accent ?? AdminReportsTheme.primary;
    if (entries.isEmpty || total == 0) {
      return const ReportsChartEmptyState(
        message: 'Not enough data yet',
        icon: Icons.bar_chart_outlined,
      );
    }
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    // Small-sample caution belongs on [ReportsSmallNBanner] only — keep this
    // widget to bars + a quiet count so cards stay compact.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$total $totalLabel',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AdminReportsTheme.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  entries[i].key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AdminReportsTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${entries[i].value}'
                '${total > 0 ? ' · ${(entries[i].value / total * 100).toStringAsFixed(0)}%' : ''}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: maxVal == 0 ? 0 : entries[i].value / maxVal,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.1),
              color: color.withValues(alpha: 0.85 - (i * 0.08).clamp(0, 0.45)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Empty state for chart cards (presentation only).
class ReportsChartEmptyState extends StatelessWidget {
  const ReportsChartEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.bar_chart_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AdminReportsTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminReportsTheme.border),
              ),
              child: Icon(icon, color: AdminReportsTheme.textMuted, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AdminReportsTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder matching chart card dimensions.
class ReportsChartSkeleton extends StatelessWidget {
  const ReportsChartSkeleton({
    super.key,
    this.height = ReportsChartHeights.standard,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AdminReportsTheme.space3),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 14,
            decoration: BoxDecoration(
              color: AdminReportsTheme.surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 10,
            decoration: BoxDecoration(
              color: AdminReportsTheme.surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminReportsTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive chart grid: hero+side, two-column, or stacked.
class ReportsChartGrid extends StatelessWidget {
  const ReportsChartGrid.heroSide({
    super.key,
    required this.hero,
    required this.side,
    this.breakpoint = 900,
    this.gutter = AdminReportsTheme.gutter,
    this.heroFlex = 3,
    this.sideFlex = 2,
  }) : left = null,
       right = null,
       _mode = _ChartGridMode.heroSide;

  const ReportsChartGrid.twoColumn({
    super.key,
    required Widget this.left,
    required Widget this.right,
    this.breakpoint = 900,
    this.gutter = AdminReportsTheme.gutter,
  }) : hero = null,
       side = null,
       heroFlex = 1,
       sideFlex = 1,
       _mode = _ChartGridMode.twoColumn;

  final Widget? hero;
  final Widget? side;
  final Widget? left;
  final Widget? right;
  final double breakpoint;
  final double gutter;
  final int heroFlex;
  final int sideFlex;
  final _ChartGridMode _mode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;
        if (_mode == _ChartGridMode.heroSide) {
          final h = hero!;
          final s = side!;
          if (!wide) {
            return Column(
              children: [
                h,
                SizedBox(height: gutter),
                s,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: heroFlex, child: h),
                SizedBox(width: gutter),
                Expanded(flex: sideFlex, child: s),
              ],
            ),
          );
        }

        final l = left!;
        final r = right!;
        if (!wide) {
          return Column(
            children: [
              l,
              SizedBox(height: gutter),
              r,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: l),
              SizedBox(width: gutter),
              Expanded(child: r),
            ],
          ),
        );
      },
    );
  }
}

enum _ChartGridMode { heroSide, twoColumn }
