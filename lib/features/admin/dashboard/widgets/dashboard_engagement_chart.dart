import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_activity_trend.dart';
import 'package:alumni_system/shared/widgets/admin/admin_chart_card.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// "Portal activity" card: daily audit-log actions over time (admin dashboard).
class DashboardEngagementTrendChart extends StatelessWidget {
  const DashboardEngagementTrendChart({
    super.key,
    required this.trend,
    this.isLoading = false,
    this.failed = false,
    this.onRetry,
    this.expand = false,
    this.chartHeight = 200,
    this.onViewReports,
  });

  final DashboardActivityTrend trend;
  final bool isLoading;

  /// The last load failed and there is no trend to show.
  final bool failed;
  final VoidCallback? onRetry;

  /// Fill the parent's height (parent must be bounded).
  final bool expand;
  final double chartHeight;
  final VoidCallback? onViewReports;

  static const _line = AdminColors.primary;

  @override
  Widget build(BuildContext context) {
    final peak = trend.peakPoint;
    final maxVal = trend.maxCount;
    final noPoints = trend.points.isEmpty;

    final Widget body;
    var isEmpty = false;
    if (isLoading && noPoints) {
      body = const AdminStateView.loading(
        label: 'Loading activity trend…',
        compact: true,
      );
    } else if (failed && noPoints) {
      body = AdminStateView.error(
        title: "Couldn't load activity trend",
        onRetry: onRetry,
        compact: true,
      );
    } else if (trend.isEmpty) {
      isEmpty = true;
      body = const SizedBox.shrink();
    } else {
      body = Semantics(
        container: true,
        label: _summary(peak),
        child: ExcludeSemantics(child: _buildChart(maxVal, peak)),
      );
    }

    return AdminChartCard(
      title: 'Portal activity',
      caption: 'Daily actions logged in the system (last 90 days)',
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLoading && maxVal > 0)
            Text(
              'Max: $maxVal',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary,
              ),
            ),
          if (onViewReports != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onViewReports,
              style: TextButton.styleFrom(
                foregroundColor: AdminColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
              ),
              child: const Text(
                'Reports',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
      isEmpty: isEmpty,
      emptyMessage: 'No activity recorded yet',
      expandChart: expand,
      chartHeight: expand ? null : chartHeight,
      child: body,
    );
  }

  String _summary(DashboardTrendPoint? peak) {
    final base = 'Portal activity, last ${trend.points.length} days';
    if (peak == null || peak.count == 0) return base;
    return '$base, peak ${peak.count} actions on '
        '${DateFormat.yMMMd().format(peak.date)}';
  }

  Widget _buildChart(int maxVal, DashboardTrendPoint? peak) {
    final spots = <FlSpot>[];
    for (var i = 0; i < trend.points.length; i++) {
      spots.add(FlSpot(i.toDouble(), trend.points[i].count.toDouble()));
    }

    final maxY = (maxVal == 0 ? 1 : maxVal).toDouble();
    final yPad = maxY * 0.12;
    final chartMaxY = maxY + yPad;

    final labelStep = _xLabelStep(trend.points.length);
    final lastIndex = trend.points.length - 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: lastIndex.toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: chartMaxY / 4,
          verticalInterval: labelStep.toDouble(),
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: AdminColors.border, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              const FlLine(color: AdminColors.surface, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: chartMaxY / 4,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxY + 0.01) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _formatYAxis(value),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.textSecondary,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labelStep.toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (!showXLabel(i, lastIndex, labelStep)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MM/dd').format(trend.points[i].date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) {
              return touched.map((bar) {
                final i = bar.x.round();
                if (i < 0 || i >= trend.points.length) return null;
                final p = trend.points[i];
                return LineTooltipItem(
                  '${DateFormat.yMMMd().format(p.date)}\n${p.count} actions',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        extraLinesData: peak != null && peak.count > 0
            ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: peak.count.toDouble(),
                    color: AdminAccents.gold.color,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textSecondary,
                      ),
                      labelResolver: (_) => 'Peak: ${peak.count}',
                    ),
                  ),
                ],
              )
            : const ExtraLinesData(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.22,
            preventCurveOverShooting: true,
            color: _line,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: trend.points.length <= 24,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: _line,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AdminAccents.sky.color.withValues(alpha: 0.28),
                  AdminAccents.sky.color.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  /// Ticks every [step] points plus the last point (today). The regular tick
  /// just before the last one is skipped when the two labels would collide.
  @visibleForTesting
  static bool showXLabel(int i, int lastIndex, int step) {
    if (i < 0 || i > lastIndex) return false;
    if (i == lastIndex) return true;
    if (i % step != 0) return false;
    return lastIndex - i >= step * 0.6;
  }

  static int _xLabelStep(int pointCount) {
    if (pointCount <= 12) return 1;
    if (pointCount <= 30) return 3;
    if (pointCount <= 60) return 7;
    return 14;
  }

  static String _formatYAxis(double value) {
    final v = value.round();
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return '$v';
  }
}
