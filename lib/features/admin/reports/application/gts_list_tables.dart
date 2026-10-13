import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/personal_data_notice.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_columns.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

/// One tally line: label, number of alumni and share of the total.
class GtsTallyLine {
  const GtsTallyLine(
    this.label,
    this.count,
    this.share, {
    this.isTotal = false,
    this.isRate = false,
  });

  final String label;

  /// "12", or "3 of 5" for rates.
  final String count;

  /// "20.0%"; "–" when there is no base; empty outside the total.
  final String share;
  final bool isTotal;
  final bool isRate;
}

/// Text shared by the on-screen list and its downloads.
abstract final class GtsListTables {
  static const defaultTitle = 'Alumni list';
  static const latestWave = 'Latest answer from any wave';
  static const totalLabel = 'Total alumni';
  static const responseRateLabel = 'Response rate (answered ÷ total)';
  static const employmentRateLabel =
      'Employment rate (employed ÷ answered item 16)';
  static const offRosterNote =
      'Graduates who answered without an active roster record are listed '
      'last and are not counted in the total.';

  static String title(GtsAlumniListResult result) {
    final t = result.config.title.trim();
    return t.isEmpty ? defaultTitle : t;
  }

  /// The wave the answers come from.
  static String scope(GtsAlumniListResult result) =>
      switch (result.config.surveyId) {
        final id? => result.waveLabel(id),
        null => latestWave,
      };

  static String percent(double? value) =>
      value == null ? '–' : '${(value * 100).toStringAsFixed(1)}%';

  static List<GtsTallyLine> tally(GtsListTally t) => [
    for (final s in t.lines)
      GtsTallyLine(
        s.label,
        '${t.count(s)}',
        s.onRoster ? percent(t.share(s)) : '',
      ),
    GtsTallyLine(
      totalLabel,
      '${t.total}',
      t.total == 0 ? '–' : '100%',
      isTotal: true,
    ),
    GtsTallyLine(
      responseRateLabel,
      '${t.answered} of ${t.total}',
      percent(t.responseRate),
      isRate: true,
    ),
    GtsTallyLine(
      employmentRateLabel,
      '${t.count(GtsTracerStatus.employed)} of ${t.answeredItem16}',
      percent(t.employmentRate),
      isRate: true,
    ),
  ];

  /// Subtotal heading for [result.config.subtotalBy].
  static String groupHeading(GtsListSubtotal by) => switch (by) {
    GtsListSubtotal.batch => 'Batch',
    GtsListSubtotal.course => 'Course',
    GtsListSubtotal.none => '',
  };

  /// Tally chart, or null when the list has no chart or nobody in it.
  static GtsChartData? chart(GtsAlumniListResult result) {
    final tally = result.tally;
    if (result.config.chart == GtsListChart.none || result.rows.isEmpty) {
      return null;
    }
    final lines = tally.lines;
    return GtsChartData(
      type: result.config.chart == GtsListChart.donut
          ? GtsChartType.donut
          : GtsChartType.horizontalBar,
      labels: [for (final s in lines) s.label],
      series: [
        GtsChartSeries('Alumni', [
          for (final s in lines) tally.count(s).toDouble(),
        ]),
      ],
      isPercent: false,
    );
  }

  static const tallyHeaders = ['Tracer status', 'Alumni', 'Share'];
  static const overallHeading = 'Overall';

  /// Tally blocks in print order: one per subtotal group, then overall.
  static List<(String, List<GtsTallyLine>)> tallyBlocks(
    GtsAlumniListResult result,
  ) {
    final by = groupHeading(result.config.subtotalBy);
    return [
      for (final g in result.groups) ('$by ${g.label}', tally(g.tally)),
      (result.groups.isEmpty ? 'Tally' : overallHeading, tally(result.tally)),
    ];
  }

  static List<GtsListColumn> columns(GtsAlumniListResult result) =>
      GtsListColumns.resolve(result.config);

  static List<String> headers(GtsAlumniListResult result) => [
    for (final c in columns(result)) c.header,
  ];

  /// Every row's cells, in [headers] order.
  static List<List<String>> rows(GtsAlumniListResult result) {
    final cols = columns(result);
    return [
      for (final r in result.rows)
        [
          for (final c in cols)
            GtsListColumns.cell(c, r, waveLabels: result.waveLabels),
        ],
    ];
  }

  static final _generated = DateFormat('d MMM yyyy, h:mm a');

  /// Label and value pairs printed above the list.
  static List<(String, String)> about(GtsAlumniListResult result) {
    final c = result.config;
    final sortColumn = switch (c.sortBy) {
      final key? => GtsListColumns.byKey(key),
      null => null,
    };
    return [
      ('Report', title(result)),
      if (c.description.trim().isNotEmpty) ('Description', c.description),
      ('Answers from', scope(result)),
      ('Alumni', '${result.tally.total} on the active roster'),
      ('Filters', filters(c)),
      (
        'Order',
        sortColumn == null
            ? 'Batch, then name${c.sortDescending ? ' (reversed)' : ''}'
            : '${sortColumn.header} (${c.sortDescending ? 'Z to A' : 'A to Z'})',
      ),
      ('Generated', _generated.format(result.generatedAt)),
      ('Privacy', personalDataNotice),
    ];
  }

  /// The filters as one sentence; "None" when everyone is listed.
  static String filters(GtsListConfig c) {
    final parts = [
      if (c.statuses.isNotEmpty)
        'Tracer status: ${c.statuses.map((s) => s.label).join(', ')}',
      if (c.courses.isNotEmpty) 'Course: ${c.courses.join(', ')}',
      if (c.batches.isNotEmpty) 'Batch: ${c.batches.join(', ')}',
      for (final f in c.answerFilters)
        '${GtsFieldDictionary.byKey(f.field)?.numberedLabel ?? f.field}: '
            '${f.values.isEmpty ? '(no answer picked)' : f.values.join(' or ')}',
    ];
    return parts.isEmpty ? 'None' : parts.join('; ');
  }

  /// Column headers with the full question wording.
  static List<(String, String)> columnNotes(GtsAlumniListResult result) => [
    for (final c in columns(result)) (c.header, c.description),
  ];
}
