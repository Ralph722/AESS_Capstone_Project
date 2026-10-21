import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Card frame for a chart: title, population/period caption, optional
/// chart-local control, dot legend and an empty state.
///
/// Series colors are chosen by the caller.
class AdminChartCard extends StatelessWidget {
  const AdminChartCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.trailing,
    this.legend = const [],
    this.infoTooltip,
    this.chartHeight,
    this.expandChart = false,
    this.isEmpty = false,
    this.emptyMessage = 'No data for this period',
    this.padding = const EdgeInsets.all(16),
  });

  final String title;

  /// Population and period, e.g. "Cumulative alumni, last 12 months".
  final String? caption;
  final Widget? trailing;
  final List<(String, Color)> legend;
  final String? infoTooltip;
  final Widget child;
  final double? chartHeight;

  /// Chart fills the card's remaining height; the card needs bounded height.
  final bool expandChart;
  final bool isEmpty;
  final String emptyMessage;
  final EdgeInsetsGeometry padding;

  static const double _stackTrailingBelow = 420;

  @override
  Widget build(BuildContext context) {
    final body = isEmpty
        ? AdminStateView.empty(
            title: emptyMessage,
            icon: Icons.insert_chart_outlined_rounded,
            compact: true,
          )
        : child;

    return Container(
      decoration: AdminSurfaces.card(),
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              trailing != null && constraints.maxWidth < _stackTrailingBelow;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: expandChart ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (stack) ...[
                _buildTitleBlock(),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTitleBlock()),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
              if (legend.isNotEmpty && !isEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final (label, color) in legend)
                      _LegendDot(label: label, color: color),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (expandChart)
                Expanded(child: body)
              else if (chartHeight != null)
                SizedBox(height: chartHeight, child: body)
              else
                body,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.sectionTitle,
                ),
              ),
            ),
            if (infoTooltip != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: infoTooltip!,
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AdminColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: AdminText.caption),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: AdminText.caption)),
      ],
    );
  }
}
