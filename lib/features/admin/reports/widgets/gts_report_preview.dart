import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_tables.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_validator.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';

/// On-screen report: warnings, chart, table and notes from one result, the
/// same layout the PDF, Excel and CSV exports print.
class GtsReportPreview extends StatelessWidget {
  const GtsReportPreview({super.key, required this.result});

  /// Group lines the on-screen table adds at a time.
  static const rowStep = 200;

  final GtsReportResult result;

  @override
  Widget build(BuildContext context) {
    final chart = GtsChartData.of(result);
    final warnings = [
      for (final i in result.validation.of(GtsIssueSeverity.warning)) i.message,
    ];
    final showTable = result.config.showTable || chart == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          GtsReportTables.title(result),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AdminReportsTheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${GtsReportTables.questionLabel(result)} · '
          '${result.total.respondents} graduates',
          style: const TextStyle(
            fontSize: 12,
            color: AdminReportsTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          GtsReportTables.sentence(result),
          key: const ValueKey('gts-report-sentence'),
          style: const TextStyle(fontSize: 13),
        ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _WarningBox(warnings),
        ],
        const SizedBox(height: 16),
        if (result.isEmpty)
          const Text('No graduates matched this report.')
        else ...[
          if (chart != null) ...[
            GtsReportChartView(data: chart),
            const SizedBox(height: 16),
          ],
          if (showTable)
            _ResultTable(GtsReportTables.main(result), key: ObjectKey(result)),
        ],
        const SizedBox(height: 8),
        _AboutAndNotes(result),
      ],
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox(this.messages);

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AdminReportsTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in messages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AdminReportsTheme.gold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminReportsTheme.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultTable extends StatefulWidget {
  const _ResultTable(this.table, {super.key});

  final GtsReportTable table;

  @override
  State<_ResultTable> createState() => _ResultTableState();
}

class _ResultTableState extends State<_ResultTable> {
  var _limit = GtsReportPreview.rowStep;

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    bool isTotal(List<Object?> row) =>
        row.isNotEmpty && row.first == GtsReportTables.allGraduates;
    final groupRows = table.rows.where((r) => !isTotal(r)).toList();
    final capped = groupRows.length > _limit;
    final rows = capped
        ? [...groupRows.take(_limit), ...table.rows.where(isTotal)]
        : table.rows;
    final numeric = [
      for (var i = 0; i < table.headers.length; i++)
        rows.any((r) => r[i] is num),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _table(table, rows, numeric),
        if (capped) ...[
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                'Showing the first $_limit of ${groupRows.length} group '
                'lines and the All graduates totals. Downloads contain every '
                'line.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _limit += GtsReportPreview.rowStep),
                child: Text(
                  'Show ${math.min(GtsReportPreview.rowStep, groupRows.length - _limit)} more',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _table(
    GtsReportTable table,
    List<List<Object?>> rows,
    List<bool> numeric,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(AdminReportsTheme.surface),
          headingRowHeight: 38,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 44,
          columnSpacing: 20,
          headingTextStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminReportsTheme.primary,
          ),
          dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
          columns: [
            for (var i = 0; i < table.headers.length; i++)
              DataColumn(label: Text(table.headers[i]), numeric: numeric[i]),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                color: row.first == GtsReportTables.allGraduates
                    ? const WidgetStatePropertyAll(AdminReportsTheme.surface)
                    : null,
                cells: [
                  for (final c in row) DataCell(Text(GtsReportTables.display(c))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutAndNotes extends StatelessWidget {
  const _AboutAndNotes(this.result);

  final GtsReportResult result;

  @override
  Widget build(BuildContext context) {
    final notes = [
      for (final i in result.validation.of(GtsIssueSeverity.note)) i.message,
      if (result.hiddenCategories.isNotEmpty)
        '"$gtsAllOtherLabel" combines: ${result.hiddenCategories.join('; ')}.',
    ];
    const muted = TextStyle(fontSize: 12, color: AdminReportsTheme.textMuted);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: const Text(
        'About this report',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      children: [
        for (final (label, value) in GtsReportTables.about(result))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        if (notes.isNotEmpty) const SizedBox(height: 8),
        for (final n in notes) Text('• $n', style: muted),
      ],
    );
  }
}

/// Draws [GtsChartData] in the chart type it was built for.
class GtsReportChartView extends StatelessWidget {
  const GtsReportChartView({super.key, required this.data});

  final GtsChartData data;

  @override
  Widget build(BuildContext context) {
    final legend = data.series.length > 1 || data.type == GtsChartType.donut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (data.type) {
          GtsChartType.horizontalBar => _HorizontalBars(data),
          GtsChartType.stackedBar => _StackedBars(data),
          GtsChartType.donut => SizedBox(height: 240, child: _Donut(data)),
          GtsChartType.line => SizedBox(height: 280, child: _Line(data)),
          _ => SizedBox(height: 280, child: _VerticalBars(data)),
        },
        if (legend) ...[
          const SizedBox(height: 10),
          _Legend(
            data.type == GtsChartType.donut
                ? data.labels
                : [for (final s in data.series) s.name],
          ),
        ],
        if (data.hasHiddenValues)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Groups with too few answers are left out of the chart '
              '("Not enough data").',
              style: TextStyle(
                fontSize: 11,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ),
        if (data.omittedNote case final note?)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              note,
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

Color _color(int i) => Color(gtsChartColor(i));

const _axisStyle = TextStyle(fontSize: 10, color: AdminReportsTheme.textMuted);

class _Legend extends StatelessWidget {
  const _Legend(this.names);

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (var i = 0; i < names.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _color(i),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(names[i], style: const TextStyle(fontSize: 11)),
            ],
          ),
      ],
    );
  }
}

double _niceMax(GtsChartData data) => data.isPercent
    ? math.min(100, math.max(10, (data.maxValue / 10).ceil() * 10.0))
    : math.max(4, data.maxValue * 1.15);

Widget _bottomLabel(List<String> labels, double value) {
  final i = value.toInt();
  if (i < 0 || i >= labels.length || value != i.toDouble()) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      labels[i],
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _axisStyle,
    ),
  );
}

FlTitlesData _titles(GtsChartData data, double maxY) => FlTitlesData(
  topTitles: const AxisTitles(),
  rightTitles: const AxisTitles(),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 34,
      interval: maxY / 4,
      getTitlesWidget: (value, meta) => Text(
        data.isPercent ? '${value.round()}%' : value.round().toString(),
        style: _axisStyle,
      ),
    ),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 24,
      interval: 1,
      getTitlesWidget: (value, meta) => _bottomLabel(data.labels, value),
    ),
  ),
);

FlGridData _grid(double maxY) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: maxY / 4,
  getDrawingHorizontalLine: (_) => const FlLine(
    color: AdminReportsTheme.border,
    strokeWidth: 1,
    dashArray: [4, 4],
  ),
);

class _VerticalBars extends StatelessWidget {
  const _VerticalBars(this.data);

  final GtsChartData data;

  @override
  Widget build(BuildContext context) {
    final maxY = _niceMax(data);
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / math.max(1, data.labels.length);
        final rodWidth = (slot * 0.7 / data.series.length).clamp(4.0, 28.0);
        return BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AdminReportsTheme.primary,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      '${data.labels[group.x]}\n'
                      '${data.series[rodIndex].name}: '
                      '${data.format(data.series[rodIndex].values[group.x])}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ),
              ),
            ),
            gridData: _grid(maxY),
            borderData: FlBorderData(show: false),
            titlesData: _titles(data, maxY),
            barGroups: [
              for (var i = 0; i < data.labels.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    for (var s = 0; s < data.series.length; s++)
                      BarChartRodData(
                        toY: data.series[s].values[i] ?? 0,
                        width: rodWidth,
                        color: data.series.length == 1 ? _color(0) : _color(s),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
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

class _Line extends StatelessWidget {
  const _Line(this.data);

  final GtsChartData data;

  @override
  Widget build(BuildContext context) {
    final maxY = _niceMax(data);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, data.labels.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: _grid(maxY),
        borderData: FlBorderData(show: false),
        titlesData: _titles(data, maxY),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AdminReportsTheme.primary,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${data.series[s.barIndex].name}: '
                  '${data.format(s.y)}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (var s = 0; s < data.series.length; s++)
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.labels.length; i++)
                  data.series[s].values[i] == null
                      ? FlSpot.nullSpot
                      : FlSpot(i.toDouble(), data.series[s].values[i]!),
              ],
              color: _color(s),
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut(this.data);

  final GtsChartData data;

  @override
  Widget build(BuildContext context) {
    final values = data.series.first.values;
    final total = values.fold<double>(0, (s, v) => s + (v ?? 0));
    return PieChart(
      PieChartData(
        centerSpaceRadius: 56,
        sectionsSpace: 2,
        sections: [
          for (var i = 0; i < values.length; i++)
            if ((values[i] ?? 0) > 0)
              PieChartSectionData(
                value: values[i],
                color: _color(i),
                radius: 44,
                title: total == 0 || values[i]! / total < 0.06
                    ? ''
                    : data.format(values[i]),
                titleStyle: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: i == 3 || i == 5 ? Colors.black87 : Colors.white,
                ),
              ),
        ],
      ),
      swapAnimationDuration: Duration.zero,
    );
  }
}

class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars(this.data);

  final GtsChartData data;

  @override
  Widget build(BuildContext context) {
    final maxX = _niceMax(data);
    return Column(
      children: [
        for (var i = 0; i < data.labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 200,
                  child: Text(
                    data.labels[i],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      for (var s = 0; s < data.series.length; s++)
                        _BarLine(
                          value: data.series[s].values[i],
                          max: maxX,
                          color: _color(s),
                          label: data.format(data.series[s].values[i]),
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
}

class _BarLine extends StatelessWidget {
  const _BarLine({
    required this.value,
    required this.max,
    required this.color,
    required this.label,
  });

  final double? value;
  final double max;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fraction = value == null || max <= 0
        ? 0.0
        : (value! / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  width: math.max(fraction * c.maxWidth, value == null ? 0 : 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: value == null
                    ? AdminReportsTheme.textMuted
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedBars extends StatelessWidget {
  const _StackedBars(this.data);

  final GtsChartData data;

  @override
  Widget build(BuildContext context) {
    double sum(int i) =>
        data.series.fold<double>(0, (s, x) => s + (x.values[i] ?? 0));
    final widest = [
      for (var i = 0; i < data.labels.length; i++) sum(i),
    ].fold<double>(data.isPercent ? 100 : 1, math.max);
    return Column(
      children: [
        for (var i = 0; i < data.labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Text(
                    data.labels[i],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: sum(i) == 0
                      ? const Text(
                          'Not enough data',
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminReportsTheme.textMuted,
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, c) => Row(
                            children: [
                              for (var s = 0; s < data.series.length; s++)
                                if ((data.series[s].values[i] ?? 0) > 0)
                                  Tooltip(
                                    message:
                                        '${data.series[s].name}: '
                                        '${data.format(data.series[s].values[i])}',
                                    child: Container(
                                      height: 16,
                                      width:
                                          c.maxWidth *
                                          data.series[s].values[i]! /
                                          widest,
                                      color: _color(s),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
