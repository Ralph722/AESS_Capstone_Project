import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/reports/widgets/admin_reports_kpi.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';

/// Category colours for bento charts: AESS navy ramp with a gold accent.
abstract final class ReportsBentoPalette {
  static const series = <Color>[
    AdminReportsTheme.primary,
    AdminReportsTheme.gold,
    Color(0xFF2563EB),
    Color(0xFFD97706),
    Color(0xFF38BDF8),
    Color(0xFF64748B),
    Color(0xFFCBD5E1),
  ];

  static Color at(int index) => series[index % series.length];
}

Color reportsStatusColor(ReportsKpiStatus status) => switch (status) {
  ReportsKpiStatus.positive => AdminReportsTheme.success,
  ReportsKpiStatus.neutral => AdminReportsTheme.textMuted,
  ReportsKpiStatus.watch => AdminReportsTheme.warning,
  ReportsKpiStatus.attention => AdminReportsTheme.danger,
};

String reportsCompactNumber(num value) {
  final v = value.abs();
  if (v >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (v >= 10000) return '${(value / 1000).toStringAsFixed(0)}k';
  if (v >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.round().toString();
}

// ── Layout ──────────────────────────────────────────────────────────────────

class ReportsBentoRow {
  const ReportsBentoRow({
    required this.children,
    required this.flex,
    this.naturalHeight = 280,
    this.fitWeight = 1,
  }) : assert(children.length == flex.length);

  final List<Widget> children;
  final List<int> flex;

  /// Height used when the grid scrolls instead of fitting the viewport.
  final double naturalHeight;

  /// Share of the leftover viewport height when fitting.
  final double fitWeight;
}

/// KPI strip + rows of unequal columns. Fills [fitHeight] exactly on wide
/// screens when every row can stay at least [minRowHeight]; otherwise rows
/// use their natural heights and the page scrolls.
class ReportsBentoGrid extends StatelessWidget {
  const ReportsBentoGrid({
    super.key,
    required this.kpis,
    required this.rows,
    this.fitHeight,
    this.kpiHeight = 164,
    this.minRowHeight = 190,
    this.gap = AdminReportsTheme.gutter,
    this.wideBreakpoint = 1000,
    this.mediumBreakpoint = 640,
  });

  final List<Widget> kpis;
  final List<ReportsBentoRow> rows;
  final double? fitHeight;
  final double kpiHeight;
  final double minRowHeight;
  final double gap;
  final double wideBreakpoint;
  final double mediumBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= wideBreakpoint;
        final medium = !wide && width >= mediumBreakpoint;

        final hasKpis = kpis.isNotEmpty;
        var heights = [for (final r in rows) r.naturalHeight];
        final fit = fitHeight;
        if (wide && fit != null && rows.isNotEmpty) {
          final remaining = hasKpis
              ? fit - kpiHeight - gap * rows.length
              : fit - gap * (rows.length - 1);
          final totalWeight = rows.fold<double>(0, (s, r) => s + r.fitWeight);
          final fitted = [
            for (final r in rows) remaining * r.fitWeight / totalWeight,
          ];
          if (fitted.every((h) => h >= minRowHeight)) heights = fitted;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasKpis) _kpiSection(wide: wide, medium: medium),
            for (var i = 0; i < rows.length; i++) ...[
              if (hasKpis || i > 0) SizedBox(height: gap),
              _row(rows[i], heights[i], wide: wide, medium: medium),
            ],
          ],
        );
      },
    );
  }

  Widget _kpiSection({required bool wide, required bool medium}) {
    if (wide) return _equalRow(kpis, kpiHeight);
    if (medium) {
      return Column(
        children: [
          for (var i = 0; i < kpis.length; i += 2) ...[
            if (i > 0) SizedBox(height: gap),
            _equalRow(kpis.sublist(i, math.min(i + 2, kpis.length)), kpiHeight),
          ],
        ],
      );
    }
    return _stack(kpis, kpiHeight);
  }

  Widget _row(
    ReportsBentoRow row,
    double height, {
    required bool wide,
    required bool medium,
  }) {
    if (wide) {
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < row.children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(flex: row.flex[i], child: row.children[i]),
            ],
          ],
        ),
      );
    }
    if (medium && row.children.length > 1) {
      return Column(
        children: [
          SizedBox(height: row.naturalHeight, child: row.children.first),
          SizedBox(height: gap),
          _equalRow(row.children.sublist(1), row.naturalHeight),
        ],
      );
    }
    return _stack(row.children, row.naturalHeight);
  }

  Widget _equalRow(List<Widget> children, double height) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }

  Widget _stack(List<Widget> children, double height) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          SizedBox(height: height, child: children[i]),
        ],
      ],
    );
  }
}

// ── Card chrome ─────────────────────────────────────────────────────────────

BoxDecoration _bentoDecoration() => BoxDecoration(
  color: AdminReportsTheme.card,
  borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
  border: Border.all(color: AdminReportsTheme.border),
  boxShadow: AdminReportsTheme.cardShadow,
);

/// Chart / list card: title and caption top-left, legend or actions
/// top-right, body fills the remaining height.
class ReportsBentoCard extends StatelessWidget {
  const ReportsBentoCard({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.details,
    this.trailing,
  });

  final String title;
  final String? caption;
  final String? details;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final captionText = caption;
    final detailsText = details;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      decoration: _bentoDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AdminReportsTheme.textPrimary,
                      ),
                    ),
                    if (captionText != null && captionText.isNotEmpty)
                      Text(
                        captionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AdminReportsTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (detailsText != null && detailsText.isNotEmpty)
                ReportsDetailsButton(title: title, body: detailsText),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class ReportsLegendDot extends StatelessWidget {
  const ReportsLegendDot({
    super.key,
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dashed ? 12 : 8,
          height: dashed ? 2 : 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AdminReportsTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── KPI card ────────────────────────────────────────────────────────────────

class ReportsStatRow {
  const ReportsStatRow(this.label, this.value);

  final String label;
  final String value;
}

/// Headline KPI: accent strip, big value with a context pill, and a short
/// breakdown underneath.
class ReportsStatCard extends StatelessWidget {
  const ReportsStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.pillLabel,
    this.pillColor,
    this.rows = const [],
    this.details,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? pillLabel;
  final Color? pillColor;
  final List<ReportsStatRow> rows;
  final String? details;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = pillLabel;
    final pillTint = pillColor ?? AdminReportsTheme.textMuted;
    final detailsText = details;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(icon, size: 14, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AdminReportsTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (detailsText != null && detailsText.isNotEmpty)
                      ReportsDetailsButton(title: label, body: detailsText),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.5,
                            color: AdminReportsTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (pill != null && pill.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: pillTint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          pill,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: pillTint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rows[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminReportsTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rows[i].value,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminReportsTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _bentoDecoration(),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
            child: body,
          ),
        ),
      ),
    );
  }
}

// ── Donut ───────────────────────────────────────────────────────────────────

class ReportsDonutEntry {
  const ReportsDonutEntry({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Donut with a centred total and a legend (count + share) beside it.
class ReportsDonutBreakdown extends StatelessWidget {
  const ReportsDonutBreakdown({
    super.key,
    required this.entries,
    required this.centerValue,
    required this.centerLabel,
  });

  final List<ReportsDonutEntry> entries;
  final String centerValue;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final visible = entries.where((e) => e.value > 0).toList();
    final total = visible.fold<int>(0, (s, e) => s + e.value);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth >= 260;
        final size = side
            ? math.min(constraints.maxHeight, constraints.maxWidth * 0.46)
            : math.min(constraints.maxHeight, constraints.maxWidth);

        final donut = SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  centerSpaceRadius: size * 0.30,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final e in visible)
                      PieChartSectionData(
                        color: e.color,
                        value: e.value.toDouble(),
                        showTitle: false,
                        radius: size * 0.16,
                      ),
                  ],
                ),
                swapAnimationDuration: Duration.zero,
              ),
              SizedBox(
                width: size * 0.52,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerValue,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AdminReportsTheme.textPrimary,
                        ),
                      ),
                      Text(
                        centerLabel,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AdminReportsTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (!side) return Center(child: donut);

        return Row(
          children: [
            donut,
            const SizedBox(width: 14),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < visible.length; i++) ...[
                        if (i > 0) const SizedBox(height: 7),
                        _legendRow(visible[i], total),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _legendRow(ReportsDonutEntry e, int total) {
    final pct = total == 0 ? 0 : e.value / total * 100;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            e.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AdminReportsTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${e.value}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminReportsTheme.textPrimary,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${pct.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              color: AdminReportsTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Trend (area / line) ─────────────────────────────────────────────────────

class ReportsTrendSeries {
  const ReportsTrendSeries({
    required this.label,
    required this.color,
    required this.values,
    this.filled = true,
  });

  final String label;
  final Color color;
  final List<double> values;

  /// Filled series draw a soft gradient area; others draw a dashed line.
  final bool filled;
}

class ReportsTrendChart extends StatelessWidget {
  const ReportsTrendChart({
    super.key,
    required this.labels,
    required this.series,
    this.maxY,
    this.valueSuffix = '',
    this.showDots = false,
    this.tooltipBuilder,
  });

  final List<String> labels;
  final List<ReportsTrendSeries> series;

  /// Fixed axis ceiling (e.g. 100 for percentages); auto when null.
  final double? maxY;
  final String valueSuffix;
  final bool showDots;

  /// Custom tooltip text for (seriesIndex, pointIndex).
  final String Function(int series, int index)? tooltipBuilder;

  @override
  Widget build(BuildContext context) {
    final maxValue = series
        .expand((s) => s.values)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = this.maxY ?? math.max(4.0, maxValue * 1.15);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(0, labels.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AdminReportsTheme.primary,
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  tooltipBuilder?.call(s.barIndex, s.spotIndex) ??
                      '${series[s.barIndex].label}: '
                          '${s.y.round()}$valueSuffix',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AdminReportsTheme.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Text(
                  '${reportsCompactNumber(value)}$valueSuffix',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AdminReportsTheme.textMuted,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                if (labels.length > 8 && i.isOdd) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AdminReportsTheme.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              spots: [
                for (var i = 0; i < s.values.length; i++)
                  FlSpot(i.toDouble(), s.values[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: s.color,
              barWidth: s.filled ? 2.5 : 2,
              dashArray: s.filled ? null : const [5, 4],
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: showDots,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 3.5,
                      color: s.color,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: s.filled,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    s.color.withValues(alpha: 0.22),
                    s.color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

// ── Column bars ─────────────────────────────────────────────────────────────

class ReportsColumnChart extends StatelessWidget {
  const ReportsColumnChart({
    super.key,
    required this.labels,
    required this.values,
    this.tooltipLabels,
    this.color = AdminReportsTheme.primary,
    this.highlightColor = AdminReportsTheme.gold,
  });

  final List<String> labels;
  final List<int> values;

  /// Full category names for tooltips when [labels] are abbreviated.
  final List<String>? tooltipLabels;
  final Color color;

  /// Applied to the tallest bar.
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(0, math.max);
    final maxY = math.max(4.0, maxValue * 1.2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / math.max(1, values.length);
        final barWidth = (slot * 0.5).clamp(8.0, 26.0);
        return BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AdminReportsTheme.primary,
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      '${(tooltipLabels ?? labels)[group.x]}\n'
                      '${rod.toY.round()}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AdminReportsTheme.border,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max) return const SizedBox.shrink();
                    return Text(
                      reportsCompactNumber(value),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AdminReportsTheme.textMuted,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AdminReportsTheme.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i].toDouble(),
                      width: barWidth,
                      color: values[i] == maxValue && maxValue > 0
                          ? highlightColor
                          : color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          swapAnimationDuration: Duration.zero,
        );
      },
    );
  }
}

// ── Horizontal bars / progress ──────────────────────────────────────────────

class _Track extends StatelessWidget {
  const _Track({required this.fraction, required this.color, this.height = 8});

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AdminReportsTheme.surface),
            ),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportsFunnelStep {
  const ReportsFunnelStep({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Stepped horizontal bars; each step shows its share of the first step.
class ReportsFunnelBars extends StatelessWidget {
  const ReportsFunnelBars({super.key, required this.steps});

  final List<ReportsFunnelStep> steps;

  /// Below this height per step, label and bar share one line.
  static const double _stackedStepHeight = 44;

  @override
  Widget build(BuildContext context) {
    final base = steps.isEmpty ? 0 : steps.first.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxHeight >= steps.length * _stackedStepHeight;
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in steps)
              stacked
                  ? _stackedStep(s, base)
                  : _inlineStep(s, base, constraints.maxWidth * 0.38),
          ],
        );
      },
    );
  }

  double _fraction(ReportsFunnelStep s, int base) =>
      base == 0 ? 0 : s.value / base;

  Widget _label(ReportsFunnelStep s) => Text(
    s.label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AdminReportsTheme.textSecondary,
    ),
  );

  List<Widget> _figures(ReportsFunnelStep s, int base) => [
    Text(
      '${s.value}',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AdminReportsTheme.textPrimary,
      ),
    ),
    SizedBox(
      width: 40,
      child: Text(
        base == 0 ? '—' : '${(_fraction(s, base) * 100).toStringAsFixed(0)}%',
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 11,
          color: AdminReportsTheme.textMuted,
        ),
      ),
    ),
  ];

  Widget _stackedStep(ReportsFunnelStep s, int base) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _label(s)),
            ..._figures(s, base),
          ],
        ),
        const SizedBox(height: 5),
        _Track(fraction: _fraction(s, base), color: s.color, height: 10),
      ],
    );
  }

  Widget _inlineStep(ReportsFunnelStep s, int base, double labelWidth) {
    return Row(
      children: [
        SizedBox(width: labelWidth, child: _label(s)),
        const SizedBox(width: 8),
        Expanded(
          child: _Track(fraction: _fraction(s, base), color: s.color),
        ),
        const SizedBox(width: 8),
        ..._figures(s, base),
      ],
    );
  }
}

class ReportsProgressItem {
  const ReportsProgressItem({
    required this.label,
    required this.detail,
    required this.fraction,
    required this.color,
    this.onTap,
  });

  final String label;
  final String detail;
  final double fraction;
  final Color color;
  final VoidCallback? onTap;
}

/// Target-style progress rows (label, detail, %, bar). Scrolls inside the
/// card when there are more rows than fit.
class ReportsProgressList extends StatelessWidget {
  const ReportsProgressList({super.key, required this.items});

  final List<ReportsProgressItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final item = items[i];
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: item.label,
                      waitDuration: const Duration(milliseconds: 500),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AdminReportsTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.45,
                    ),
                    child: Text(
                      item.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminReportsTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(item.fraction * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                  if (item.onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AdminReportsTheme.textMuted,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _Track(fraction: item.fraction, color: item.color),
          ],
        );
        final onTap = item.onTap;
        if (onTap == null) return body;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: body,
          ),
        );
      },
    );
  }
}

// ── Grouped bars ────────────────────────────────────────────────────────────

class ReportsBarSeries {
  const ReportsBarSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<int> values;
}

/// Side-by-side bars per category (e.g. answered vs employed per wave).
class ReportsGroupedBarChart extends StatelessWidget {
  const ReportsGroupedBarChart({
    super.key,
    required this.labels,
    required this.series,
    this.tooltipTitles,
    this.tooltipFooter,
    this.onGroupTap,
  });

  final List<String> labels;
  final List<ReportsBarSeries> series;

  /// Full category names for tooltips when [labels] are abbreviated.
  final List<String>? tooltipTitles;

  /// Extra tooltip line per category (e.g. a rate).
  final String Function(int index)? tooltipFooter;
  final ValueChanged<int>? onGroupTap;

  @override
  Widget build(BuildContext context) {
    final maxValue = series.expand((s) => s.values).fold<int>(0, math.max);
    final maxY = math.max(4.0, maxValue * 1.2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / math.max(1, labels.length);
        final rodWidth = (slot * 0.28).clamp(5.0, 14.0);
        return BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                final tap = onGroupTap;
                if (tap == null || event is! FlTapDownEvent) return;
                final spot = response?.spot;
                if (spot != null) tap(spot.touchedBarGroupIndex);
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AdminReportsTheme.primary,
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final title = (tooltipTitles ?? labels)[group.x];
                  final footer = tooltipFooter?.call(group.x);
                  return BarTooltipItem(
                    '$title\n${series[rodIndex].label}: ${rod.toY.round()}'
                    '${footer == null ? '' : '\n$footer'}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: AdminReportsTheme.border,
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max) return const SizedBox.shrink();
                    return Text(
                      reportsCompactNumber(value),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AdminReportsTheme.textMuted,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AdminReportsTheme.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < labels.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 3,
                  barRods: [
                    for (final s in series)
                      BarChartRodData(
                        toY: s.values[i].toDouble(),
                        width: rodWidth,
                        color: s.color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          swapAnimationDuration: Duration.zero,
        );
      },
    );
  }
}

// ── 100% split bars ─────────────────────────────────────────────────────────

class ReportsSplitItem {
  const ReportsSplitItem({required this.label, required this.entries});

  final String label;
  final List<ReportsDonutEntry> entries;

  int get total => entries.fold<int>(0, (s, e) => s + e.value);
}

/// One stacked 100% bar per question, with a share legend under each bar.
class ReportsSplitBars extends StatelessWidget {
  const ReportsSplitBars({super.key, required this.items});

  final List<ReportsSplitItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final item = items[i];
        final total = item.total;
        final shares = [
          for (final e in item.entries)
            if (e.value > 0) e,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminReportsTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'n = $total',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AdminReportsTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: total == 0
                    ? const ColoredBox(color: AdminReportsTheme.surface)
                    : Row(
                        children: [
                          for (final e in shares)
                            Expanded(
                              flex: e.value,
                              child: ColoredBox(color: e.color),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 4),
            if (total == 0)
              const Text(
                'No answers yet',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AdminReportsTheme.textMuted,
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  for (final e in shares)
                    ReportsLegendDot(
                      color: e.color,
                      label:
                          '${e.label} ${(e.value / total * 100).toStringAsFixed(0)}%',
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

// ── Segmented toggle ────────────────────────────────────────────────────────

class ReportsSegmentedToggle extends StatelessWidget {
  const ReportsSegmentedToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AdminReportsTheme.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: i == selected
                          ? AdminReportsTheme.card
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: i == selected
                          ? AdminReportsTheme.cardShadow
                          : null,
                    ),
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i == selected
                            ? AdminReportsTheme.primary
                            : AdminReportsTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
