import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_validator.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

/// Rows of typed cells: [String], [int], [double] (percent) or null.
class GtsReportTable {
  const GtsReportTable(this.headers, this.rows);

  final List<String> headers;
  final List<List<Object?>> rows;
}

/// Layout shared by the preview and every export, so they all print the
/// same numbers, labels and notes from one [GtsReportResult].
abstract final class GtsReportTables {
  /// Group cell of the all-respondents row.
  static const allGraduates = 'All graduates';

  static const answerHeader = 'Answer';

  static String calculationLabel(GtsCalculation c) => switch (c) {
    GtsCalculation.count => 'Count',
    GtsCalculation.shareOfAnswered => 'Share of graduates who answered',
    GtsCalculation.shareOfEligible => 'Share of graduates who were asked',
    GtsCalculation.shareOfAllRespondents => 'Share of all graduates',
    GtsCalculation.medianBracket => 'Median bracket',
    GtsCalculation.answeredCount => 'Number of answers',
  };

  static String populationLabel(GtsPopulation p) => switch (p) {
    GtsPopulation.allRespondents => 'All respondents',
    GtsPopulation.rosterLinked =>
      'Graduates on the active roster with a course (same as the DSS)',
  };

  static String title(GtsReportResult r) {
    final t = r.config.title.trim();
    return t.isNotEmpty ? t : r.measure.numberedLabel;
  }

  static String questionLabel(GtsReportResult r) {
    final column = r.config.gridColumn;
    return column == null
        ? r.measure.numberedLabel
        : '${r.measure.numberedLabel} - $column';
  }

  /// One plain sentence describing what the report shows, e.g. "Share of
  /// graduates who answered item 16 (presently employed), by course, 2026
  /// tracer."
  static String sentence(GtsReportResult r) {
    final c = r.config;
    final m = r.measure;
    final number = m.chedNumber;
    final item = number == null
        ? _lowerFirst(m.label)
        : 'item $number (${_lowerFirst(m.label)})';
    final byAnswer = number == null ? item : 'answer to $item';
    final lead = switch (c.calculation) {
      GtsCalculation.shareOfAnswered =>
        number == null
            ? 'Share of graduates by $item'
            : 'Share of graduates who answered $item',
      GtsCalculation.count => 'Number of graduates by $byAnswer',
      GtsCalculation.shareOfEligible =>
        'Share of graduates who were asked $item',
      GtsCalculation.shareOfAllRespondents =>
        'Share of all graduates by $byAnswer',
      GtsCalculation.medianBracket => 'Middle bracket (median) of $item',
      GtsCalculation.answeredCount => 'Number of graduates who answered $item',
    };
    final groups = [
      for (final f in r.groupFields)
        if (f.source != GtsFieldSource.wave) _lowerFirst(f.label),
    ];
    final waves = [for (final id in c.surveyIds) r.waveLabel(id)];
    return [
      lead,
      ?c.gridColumn,
      if (groups.isNotEmpty) 'by ${groups.join(' and ')}',
      for (final f in c.filters) ?filterSentence(f, r.waveLabel, lead: false),
      if (c.population == GtsPopulation.allRespondents)
        'counting every response',
      if (c.topN case final n?) 'top $n answers',
      if (waves.length > 1)
        'compared across ${_orList(waves, 'and')}'
      else if (waves.isNotEmpty)
        waves.single,
    ].join(', ').trimRight().replaceFirst(RegExp(r'\.?$'), '.');
  }

  /// "Only graduates whose 16. Presently employed is Yes or No."; null for
  /// an unknown field. Without [lead] it starts lower-case and has no full
  /// stop, for use inside [sentence].
  static String? filterSentence(
    GtsReportFilter f,
    String Function(String surveyId) waveLabel, {
    bool lead = true,
  }) {
    final field = GtsFieldDictionary.byKey(f.field);
    if (field == null) return null;
    final values = field.source == GtsFieldSource.wave
        ? f.values.map(waveLabel).toList()
        : f.values;
    final verb = field.valueClass == GtsValueClass.multiSelect
        ? 'includes'
        : 'is';
    final text =
        'only graduates whose ${field.numberedLabel} $verb '
        '${values.isEmpty ? '…' : _orList(values, 'or')}';
    return lead ? 'O${text.substring(1)}.' : text;
  }

  static String _orList(List<String> values, String word) => values.length < 2
      ? values.join()
      : '${values.take(values.length - 1).join(', ')} $word ${values.last}';

  static String _lowerFirst(String s) =>
      s.length > 1 && s[1].toLowerCase() == s[1] && s[1].toUpperCase() != s[1]
      ? '${s[0].toLowerCase()}${s.substring(1)}'
      : s;

  /// "About this report" lines.
  static List<(String, String)> about(GtsReportResult r) {
    final c = r.config;
    String values(GtsField f, List<String> v) => f.source == GtsFieldSource.wave
        ? v.map(r.waveLabel).join(', ')
        : v.join(', ');
    final filters = [
      for (final f in c.filters)
        if (GtsFieldDictionary.byKey(f.field) case final field?)
          '${field.label}: ${values(field, f.values)}',
    ];
    return [
      ('Report', title(r)),
      if (c.description.trim().isNotEmpty)
        ('Description', c.description.trim()),
      ('Question', questionLabel(r)),
      ('Calculation', calculationLabel(c.calculation)),
      ('Tracer waves', c.surveyIds.map(r.waveLabel).join('; ')),
      ('Population', populationLabel(c.population)),
      (
        'Grouped by',
        r.groupFields.isEmpty
            ? 'Not grouped'
            : r.groupFields.map((f) => f.label).join(', then '),
      ),
      ('Filters', filters.isEmpty ? 'None' : filters.join('; ')),
      ('Graduates in report', '${r.total.respondents}'),
      ('Generated', DateFormat('MMM d, y h:mm a').format(r.generatedAt)),
    ];
  }

  /// Warnings first, then how the numbers were calculated.
  static List<String> notes(GtsReportResult r) => [
    if (r.isEmpty) 'No graduates matched this report.',
    for (final i in r.validation.of(GtsIssueSeverity.warning)) i.message,
    for (final i in r.validation.of(GtsIssueSeverity.note)) i.message,
    if (r.hiddenCategories.isNotEmpty)
      '"$gtsAllOtherLabel" combines: ${r.hiddenCategories.join('; ')}.',
  ];

  /// One line per group and answer; the all-graduates rows come last.
  static GtsReportTable main(GtsReportResult r) {
    final groupHeaders = [for (final f in r.groupFields) f.label];
    final rows = [...r.rows, r.total];
    List<Object?> groupCells(GtsReportRow row) => row.groupValues.isEmpty
        ? List.filled(r.groupFields.length, allGraduates)
        : row.groupValues;

    switch (r.config.calculation) {
      case GtsCalculation.medianBracket:
        return GtsReportTable(
          [...groupHeaders, 'Median bracket', 'Answers', 'Sample size'],
          [
            for (final row in rows) [...groupCells(row), ..._medianCells(row)],
          ],
        );
      case GtsCalculation.answeredCount:
        return GtsReportTable(
          [...groupHeaders, 'Answered', 'Asked', 'Graduates'],
          [
            for (final row in rows)
              [
                ...groupCells(row),
                ...row.isSmall
                    ? const [null, null, null]
                    : [
                        row.answered,
                        row.distribution.eligible,
                        row.respondents,
                      ],
              ],
          ],
        );
      case GtsCalculation.count:
        return GtsReportTable(
          [...groupHeaders, answerHeader, 'Count'],
          [
            for (final row in rows)
              for (final c in r.categories)
                [...groupCells(row), c, _count(row, c)],
          ],
        );
      case GtsCalculation.shareOfAnswered:
      case GtsCalculation.shareOfEligible:
      case GtsCalculation.shareOfAllRespondents:
        return GtsReportTable(
          [
            ...groupHeaders,
            answerHeader,
            'Count',
            'Base',
            'Share (%)',
            '95% range low (%)',
            '95% range high (%)',
            'Sample size',
          ],
          [
            for (final row in rows)
              for (final c in r.categories)
                [...groupCells(row), c, ..._shareCells(row, c)],
          ],
        );
    }
  }

  static List<Object?> _medianCells(GtsReportRow row) {
    final n = row.median?.n ?? 0;
    final strength = DssPolicy.strength(n);
    return [
      row.isSmall ? strength.label : row.median!.label,
      row.isSmall ? null : n,
      strength.label,
    ];
  }

  static int? _count(GtsReportRow row, String category) =>
      row.isSmall ? null : row.cell(category).count;

  static List<Object?> _shareCells(GtsReportRow row, String category) {
    final cell = row.cell(category);
    final range = cell.interval;
    return [
      _count(row, category),
      row.isSmall ? null : cell.denominator,
      _percent(cell.share),
      _percent(range?.low),
      _percent(range?.high),
      row.evidence.label,
    ];
  }

  /// Groups as rows, answers as columns; null for ungrouped reports and
  /// for medians and answer counts.
  static GtsReportTable? crosstab(GtsReportResult r) {
    final calc = r.config.calculation;
    if (!r.isGrouped ||
        calc == GtsCalculation.medianBracket ||
        calc == GtsCalculation.answeredCount) {
      return null;
    }
    final shares = calc != GtsCalculation.count;
    return GtsReportTable(
      [
        for (final f in r.groupFields) f.label,
        shares ? 'Base' : 'Graduates',
        for (final c in r.categories) shares ? '$c (%)' : c,
      ],
      [
        for (final row in [...r.rows, r.total])
          [
            if (row.groupValues.isEmpty)
              for (final _ in r.groupFields) allGraduates
            else
              ...row.groupValues,
            row.isSmall
                ? null
                : shares
                ? row.denominator
                : row.respondents,
            for (final c in r.categories)
              shares ? _percent(row.cell(c).share) : _count(row, c),
          ],
      ],
    );
  }

  /// Cell text for PDF and preview; a missing share reads as "-".
  static String display(Object? value) => switch (value) {
    null => '-',
    double v => v.toStringAsFixed(1),
    _ => value.toString(),
  };

  static double? _percent(double? fraction) =>
      fraction == null ? null : (fraction * 1000).round() / 10;
}
