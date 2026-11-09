import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/personal_data_notice.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_columns.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_chart.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

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

/// One block of the column tally: a heading and its lines.
class GtsTallySection {
  const GtsTallySection({
    required this.title,
    required this.lines,
    this.note,
    this.groupLines = const [],
  });

  final String title;
  final List<GtsTallyLine> lines;

  /// How the shares were calculated, when that is not obvious.
  final String? note;

  /// One line list per subtotal group, aligned with [lines] by label.
  final List<List<GtsTallyLine>> groupLines;

  GtsTallyLine? line(String label, [int? group]) {
    final source = group == null ? lines : groupLines[group];
    for (final l in source) {
      if (l.label == label) return l;
    }
    return null;
  }
}

/// Text shared by the on-screen list and its downloads.
abstract final class GtsListTables {
  static const defaultTitle = 'Alumni list';
  static const latestWave = 'Latest answer from any wave';
  static const totalLabel = 'Total alumni';
  static const responseRateLabel = 'Response rate (answered ÷ total)';
  static const employmentRateLabel =
      'Employment rate (answered Yes ÷ answered this question)';
  static const answeredQuestionLabel = 'Answered this question';
  static const offRosterNote =
      'Graduates who answered without an active alumni list record are listed '
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

  static const _rosterShareNote =
      'Shares are of alumni on the alumni list.';
  static const _questionShareNote =
      'Shares are of alumni on the alumni list who answered this '
      'question. Alumni who were not asked it are left out.';
  static const _multiShareNote =
      'Alumni may select more than one answer, so shares can add up to '
      'more than 100%. Each share is of alumni on the alumni list who '
      'answered this question.';

  /// Tally blocks for [rows], using only the columns in [config].
  /// Alumni count and the response rate are always included. Percentages
  /// for a question are included only when that column is selected and the
  /// question has categories. Off-roster responders are left out of every
  /// share.
  static List<GtsTallySection> sectionsFor({
    required GtsListTally tally,
    required List<GtsListRow> rows,
    required GtsListConfig config,
  }) {
    final blocks = <GtsTallySection>[
      GtsTallySection(
        title: 'Summary',
        note: _rosterShareNote,
        lines: [
          GtsTallyLine(
            totalLabel,
            '${tally.total}',
            tally.total == 0 ? '–' : '100%',
            isTotal: true,
          ),
          GtsTallyLine(
            responseRateLabel,
            '${tally.answered} of ${tally.total}',
            percent(tally.responseRate),
            isRate: true,
          ),
        ],
      ),
    ];
    final selected = {for (final c in GtsListColumns.resolve(config)) c.key};
    if (selected.contains(GtsListConfig.statusColumn)) {
      blocks.add(
        GtsTallySection(
          title: 'Tracer status',
          note: _rosterShareNote,
          lines: [
            GtsTallyLine(
              GtsListColumns.answeredLabel,
              '${tally.answered}',
              percent(tally.total == 0 ? null : tally.answered / tally.total),
            ),
            for (final s in [
              GtsTracerStatus.untrackedRegistered,
              GtsTracerStatus.untrackedNotRegistered,
            ])
              GtsTallyLine(
                s.label,
                '${tally.count(s)}',
                percent(tally.share(s)),
              ),
            if (tally.count(GtsTracerStatus.offRoster) > 0)
              GtsTallyLine(
                GtsTracerStatus.offRoster.label,
                '${tally.count(GtsTracerStatus.offRoster)}',
                '',
              ),
          ],
        ),
      );
    }
    for (final column in GtsListColumns.resolve(config)) {
      final item = column.item;
      if (item == null) continue;
      if (item.type != ChedGtsFieldType.single &&
          item.type != ChedGtsFieldType.multi) {
        continue;
      }
      blocks.add(_questionSection(column, rows, tally));
    }
    return blocks;
  }

  static GtsTallySection _questionSection(
    GtsListColumn column,
    List<GtsListRow> rows,
    GtsListTally tally,
  ) {
    final item = column.item!;
    var asked = 0;
    var answered = 0;
    final counts = <String, int>{};
    for (final row in rows) {
      if (!row.status.onRoster) continue;
      final labels = GtsListColumns.tallyCategories(column, row);
      if (labels == null) continue;
      asked++;
      if (labels.isEmpty) continue;
      answered++;
      for (final label in labels.toSet()) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    final lines = <GtsTallyLine>[
      for (final entry in ordered)
        GtsTallyLine(
          entry.key,
          '${entry.value}',
          percent(answered == 0 ? null : entry.value / answered),
        ),
      GtsTallyLine(
        answeredQuestionLabel,
        '$answered of $asked',
        percent(asked == 0 ? null : answered / asked),
        isRate: true,
      ),
      if (item.id == 'ched_16')
        GtsTallyLine(
          employmentRateLabel,
          '${tally.count(GtsTracerStatus.employed)} of ${tally.answeredItem16}',
          percent(tally.employmentRate),
          isRate: true,
        ),
    ];
    return GtsTallySection(
      title: column.header,
      note: item.type == ChedGtsFieldType.multi
          ? _multiShareNote
          : _questionShareNote,
      lines: lines,
    );
  }

  /// Subtotal heading for [result.config.subtotalBy].
  static String groupHeading(GtsListSubtotal by) => switch (by) {
    GtsListSubtotal.batch => 'Batch',
    GtsListSubtotal.course => 'Course',
    GtsListSubtotal.none => '',
  };

  /// Charts for the selected columns. Counts match [sections].
  /// At most [maxCharts] charts; the tally still lists every question.
  static const maxCharts = 12;

  static List<GtsChartData> charts(GtsAlumniListResult result) {
    if (!result.config.includeCharts || result.rows.isEmpty) return const [];
    final type = switch (result.config.chart) {
      GtsListChart.donut => GtsChartType.donut,
      GtsListChart.verticalBars => GtsChartType.bar,
      GtsListChart.bars => GtsChartType.horizontalBar,
      GtsListChart.none => GtsChartType.horizontalBar,
    };
    final out = <GtsChartData>[];
    void add(String title, List<GtsTallyLine> lines) {
      if (out.length >= maxCharts) return;
      final counted = [
        for (final l in lines)
          if (!l.isRate && !l.isTotal && (int.tryParse(l.count) ?? 0) > 0) l,
      ];
      if (counted.isEmpty) return;
      final capped = counted.length > GtsChartData.maxLabels;
      final shown = capped
          ? counted.take(GtsChartData.maxLabels).toList()
          : counted;
      out.add(
        GtsChartData(
          type: type,
          title: title,
          labels: [for (final l in shown) l.label],
          series: [
            GtsChartSeries('Alumni', [
              for (final l in shown) int.parse(l.count).toDouble(),
            ]),
          ],
          isPercent: false,
          omitted: capped ? counted.length - shown.length : 0,
        ),
      );
    }

    final tally = result.tally;
    add('Tracer coverage', [
      GtsTallyLine(GtsListColumns.answeredLabel, '${tally.answered}', ''),
      GtsTallyLine(
        GtsTracerStatus.untrackedRegistered.label,
        '${tally.count(GtsTracerStatus.untrackedRegistered)}',
        '',
      ),
      GtsTallyLine(
        GtsTracerStatus.untrackedNotRegistered.label,
        '${tally.count(GtsTracerStatus.untrackedNotRegistered)}',
        '',
      ),
      if (tally.count(GtsTracerStatus.offRoster) > 0)
        GtsTallyLine(
          GtsTracerStatus.offRoster.label,
          '${tally.count(GtsTracerStatus.offRoster)}',
          '',
        ),
    ]);
    for (final section in sectionsFor(
      tally: result.tally,
      rows: result.rows,
      config: result.config,
    )) {
      if (section.title == 'Summary' || section.title == 'Tracer status') {
        continue;
      }
      add(section.title, section.lines);
    }
    return out;
  }

  static const tallyHeaders = ['Category', 'Alumni', 'Share'];
  static const overallHeading = 'Overall';

  /// Tally sections in print order. Subtotal groups are aligned to the
  /// overall lines so a category missing from a group prints as zero.
  static List<GtsTallySection> sections(GtsAlumniListResult result) {
    final overall = sectionsFor(
      tally: result.tally,
      rows: result.rows,
      config: result.config,
    );
    if (result.groups.isEmpty) return overall;
    final perGroup = [
      for (final g in result.groups)
        sectionsFor(tally: g.tally, rows: g.rows, config: result.config),
    ];
    return [
      for (var i = 0; i < overall.length; i++)
        GtsTallySection(
          title: overall[i].title,
          note: overall[i].note,
          lines: overall[i].lines,
          groupLines: [
            for (final blocks in perGroup) _align(blocks[i].lines, overall[i].lines),
          ],
        ),
    ];
  }

  static List<GtsTallyLine> _align(
    List<GtsTallyLine> source,
    List<GtsTallyLine> template,
  ) {
    final byLabel = {for (final line in source) line.label: line};
    return [
      for (final line in template)
        byLabel[line.label] ??
            GtsTallyLine(
              line.label,
              line.isRate ? '0 of 0' : '0',
              '–',
              isRate: line.isRate,
              isTotal: line.isTotal,
            ),
    ];
  }

  static List<GtsListColumn> columns(GtsAlumniListResult result) =>
      GtsListColumns.displayColumns(result.config);

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
    final sortColumn = GtsListColumns.sortColumn(c);
    return [
      ('Report', title(result)),
      if (c.description.trim().isNotEmpty) ('Description', c.description),
      ('Answers from', scope(result)),
      ('Alumni', '${result.tally.total} on the alumni list'),
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
