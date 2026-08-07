import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_activity_trend.dart';

/// Area line chart for portal activity over time (admin dashboard).
class DashboardEngagementTrendChart extends StatelessWidget {
  const DashboardEngagementTrendChart({
    super.key,
    required this.trend,
    this.isLoading = false,
    this.expand = false,
    this.onViewReports,
  });

  final DashboardActivityTrend trend;
  final bool isLoading;
  final bool expand;
  final VoidCallback? onViewReports;

  static const _chartGreen = Color(0xFF22C55E);
  static const _navy = Color(0xFF090A4F);

  @override
  Widget build(BuildContext context) {
    final peak = trend.peakPoint;
    final maxVal = trend.maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'Portal activity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
            ),
            if (!isLoading && maxVal > 0)
              Text(
                'Max: $maxVal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            if (onViewReports != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onViewReports,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Reports', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Daily actions logged in the system (last 90 days)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: isLoading && trend.points.isEmpty
              ? Center(
                  child: Text(
                    'Loading activity trend…',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : trend.isEmpty
                  ? Center(
                      child: Text(
                        'No activity recorded yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : _buildChart(maxVal, peak),
        ),
      ],
    );
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

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (trend.points.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: chartMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: chartMaxY / 4,
          verticalInterval: labelStep.toDouble(),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: Colors.grey.shade100,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
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
                if (i < 0 || i >= trend.points.length) {
                  return const SizedBox.shrink();
                }
                if (i % labelStep != 0 && i != trend.points.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MM/dd').format(trend.points[i].date),
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
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
                    color: _chartGreen.withValues(alpha: 0.85),
                    strokeWidth: 1,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF15803D),
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
            color: _chartGreen,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: trend.points.length <= 24,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: _chartGreen,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _chartGreen.withValues(alpha: 0.28),
                  _chartGreen.withValues(alpha: 0.04),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
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
