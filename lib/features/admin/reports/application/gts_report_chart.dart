import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_tables.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

/// Series colours (ARGB) shared by the screen and PDF charts; same ramp as
/// the reports dashboard.
const gtsChartColors = <int>[
  0xFF1A1851,
  0xFF4F46E5,
  0xFF818CF8,
  0xFFFBBF24,
  0xFF0EA5E9,
  0xFFC7D2FE,
  0xFF94A3B8,
];

int gtsChartColor(int index) => gtsChartColors[index % gtsChartColors.length];

class GtsChartSeries {
  const GtsChartSeries(this.name, this.values);

  final String name;

  /// One value per label; null when hidden ("Not enough data").
  final List<double?> values;
}

/// Chart-ready numbers from a [GtsReportResult]. Labels run along the axis;
/// each series is one colour.
class GtsChartData {
  const GtsChartData({
    required this.type,
    required this.labels,
    required this.series,
    required this.isPercent,
    this.omitted = 0,
  });

  /// Most labels a chart draws; the table always lists every group.
  static const maxLabels = 40;

  final GtsChartType type;
  final List<String> labels;
  final List<GtsChartSeries> series;

  /// Values are shares in percent (0-100); otherwise counts.
  final bool isPercent;

  /// Labels left out after [maxLabels].
  final int omitted;

  /// Note printed under a chart that stops at [maxLabels]; null otherwise.
  String? get omittedNote => omitted == 0
      ? null
      : 'The chart shows the first ${labels.length} of '
            '${labels.length + omitted}; the table lists every line.';

  String get valueLabel => isPercent ? 'Share (%)' : 'Graduates';

  bool get hasHiddenValues => series.any((s) => s.values.any((v) => v == null));

  double get maxValue => series
      .expand((s) => s.values)
      .fold<double>(0, (m, v) => v != null && v > m ? v : m);

  String format(double? value) {
    if (value == null) return 'Not enough data';
    return isPercent
        ? '${value.toStringAsFixed(1)}%'
        : value.round().toString();
  }

  /// Builds the chart for [result.config.chart]; null for tables and
  /// medians. At most [maxLabels] labels, in table order.
  static GtsChartData? of(GtsReportResult result) {
    final data = _of(result);
    if (data == null || data.labels.length <= maxLabels) return data;
    return GtsChartData(
      type: data.type,
      labels: data.labels.take(maxLabels).toList(),
      series: [
        for (final s in data.series)
          GtsChartSeries(s.name, s.values.take(maxLabels).toList()),
      ],
      isPercent: data.isPercent,
      omitted: data.labels.length - maxLabels,
    );
  }

  static GtsChartData? _of(GtsReportResult result) {
    final config = result.config;
    if (config.chart == GtsChartType.table ||
        config.calculation == GtsCalculation.medianBracket) {
      return null;
    }
    final percent = switch (config.calculation) {
      GtsCalculation.count || GtsCalculation.answeredCount => false,
      _ => true,
    };
    double? value(GtsReportRow row, String category) {
      final cell = row.cell(category);
      if (!percent) return row.isSmall ? null : cell.count.toDouble();
      final share = cell.share;
      return share == null ? null : (share * 1000).round() / 10;
    }

    if (config.calculation == GtsCalculation.answeredCount) {
      if (!result.isGrouped) {
        final d = result.total.distribution;
        final hide = result.total.isSmall;
        return GtsChartData(
          type: config.chart,
          labels: const ['Answered', 'Left blank', 'Not asked'],
          series: [
            GtsChartSeries('Graduates', [
              for (final n in [d.answered, d.missing, d.notAsked])
                hide ? null : n.toDouble(),
            ]),
          ],
          isPercent: false,
        );
      }
      return GtsChartData(
        type: config.chart,
        labels: [for (final r in result.rows) r.groupValues.join(' / ')],
        series: [
          GtsChartSeries('Answered', [
            for (final r in result.rows)
              r.isSmall ? null : r.answered.toDouble(),
          ]),
        ],
        isPercent: false,
      );
    }

    if (!result.isGrouped) {
      return GtsChartData(
        type: config.chart,
        labels: result.categories,
        series: [
          GtsChartSeries(GtsReportTables.allGraduates, [
            for (final c in result.categories) value(result.total, c),
          ]),
        ],
        isPercent: percent,
      );
    }
    return GtsChartData(
      type: config.chart,
      labels: [for (final r in result.rows) r.groupValues.join(' / ')],
      series: [
        for (final c in result.categories)
          GtsChartSeries(c, [for (final r in result.rows) value(r, c)]),
      ],
      isPercent: percent,
    );
  }
}
