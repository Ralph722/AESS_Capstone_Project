import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_validator.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';

/// Group label for respondents the group-by item was not shown to.
const gtsNotAskedLabel = 'Not asked';

/// Group label for respondents who left the group-by item blank.
const gtsNotAnsweredLabel = 'Not answered';

/// Category holding everything outside a report's top N.
const gtsAllOtherLabel = 'All other answers';

/// One number in a report: a category count over one row's denominator.
class GtsReportCell {
  const GtsReportCell({
    required this.count,
    required this.denominator,
    required this.calculation,
  });

  final int count;
  final int denominator;
  final GtsCalculation calculation;

  bool get isShare => switch (calculation) {
    GtsCalculation.shareOfAnswered ||
    GtsCalculation.shareOfEligible ||
    GtsCalculation.shareOfAllRespondents => true,
    _ => false,
  };

  /// Share hidden because fewer than [DssPolicy.notEnoughBelow] answers.
  bool get isSuppressed => isShare && denominator < DssPolicy.notEnoughBelow;

  /// 0-1, or null when this is not a share or is suppressed.
  double? get share => isShare && !isSuppressed
      ? DssProportion(hits: count, total: denominator).rate
      : null;

  /// 95% Wilson range, the same method the DSS uses.
  ({double low, double high})? get interval =>
      share == null ? null : DssMetrics.wilson(count, denominator);
}

/// One row of a report: all respondents, or one group-by combination.
class GtsReportRow {
  const GtsReportRow({
    required this.groupValues,
    required this.distribution,
    required this.counts,
    required this.calculation,
    this.median,
  });

  /// Display value per group-by field; empty for the all-respondents row.
  final List<String> groupValues;
  final GtsDistribution distribution;

  /// Count per displayed category, including [gtsAllOtherLabel].
  final Map<String, int> counts;
  final GtsCalculation calculation;
  final GtsMedianBracket? median;

  int get respondents => distribution.respondents;
  int get answered => distribution.answered;

  /// Denominator of every share in this row.
  int get denominator => distribution.denominator(calculation);

  DssEvidenceStrength get evidence => DssPolicy.strength(denominator);

  /// Fewer than [DssPolicy.notEnoughBelow] graduates behind this row's
  /// numbers. Its counts are hidden as well as its shares, so a share cannot
  /// be worked back out and no graduate can be picked out.
  bool get isSmall =>
      switch (calculation) {
        GtsCalculation.count || GtsCalculation.answeredCount => respondents,
        GtsCalculation.medianBracket => median?.n ?? 0,
        _ => denominator,
      } <
      DssPolicy.notEnoughBelow;

  GtsReportCell cell(String category) => GtsReportCell(
    count: counts[category] ?? 0,
    denominator: denominator,
    calculation: calculation,
  );
}

/// The single calculated result behind the preview, charts and every export.
class GtsReportResult {
  const GtsReportResult({
    required this.config,
    required this.measure,
    required this.groupFields,
    required this.validation,
    required this.categories,
    required this.hiddenCategories,
    required this.rows,
    required this.total,
    required this.generatedAt,
    this.waveLabels = const {},
  });

  final GtsReportConfig config;
  final GtsField measure;
  final List<GtsField> groupFields;

  /// Warnings and notes to print with the numbers.
  final GtsReportValidation validation;

  /// Displayed categories in display order; [gtsAllOtherLabel] last when
  /// a top N folded the rest.
  final List<String> categories;

  /// Categories folded into [gtsAllOtherLabel].
  final List<String> hiddenCategories;

  /// One row per group-by combination with respondents, in natural order.
  /// Empty when the report is not grouped.
  final List<GtsReportRow> rows;

  /// All respondents in scope after filters.
  final GtsReportRow total;
  final DateTime generatedAt;

  /// Survey id to wave name.
  final Map<String, String> waveLabels;

  String waveLabel(String surveyId) => waveLabels[surveyId] ?? surveyId;

  bool get isGrouped => groupFields.isNotEmpty;
  bool get isEmpty => total.respondents == 0;

  /// The same numbers under another report title.
  GtsReportResult retitled(String title) => GtsReportResult(
    config: config.copyWith(title: title),
    measure: measure,
    groupFields: groupFields,
    validation: validation,
    categories: categories,
    hiddenCategories: hiddenCategories,
    rows: rows,
    total: total,
    generatedAt: generatedAt,
    waveLabels: waveLabels,
  );
}

/// Runs a validated [GtsReportConfig] over respondents. Counting comes from
/// [GtsStats]; rates and sample-size rules from the DSS.
abstract final class GtsReportEngine {
  /// [waveLabels] maps survey ids to display names for the wave group-by.
  /// Throws [ArgumentError] when the config has validation errors.
  static GtsReportResult run(
    GtsReportConfig config,
    Iterable<GtsRespondent> respondents, {
    Map<String, String> waveLabels = const {},
    DateTime? now,
  }) {
    final validation = GtsReportValidator.validate(config);
    if (!validation.isValid) {
      throw ArgumentError(
        validation.of(GtsIssueSeverity.error).first.message,
        'config',
      );
    }
    final measure = GtsFieldDictionary.byKey(config.measure)!;
    final groupFields = [
      for (final k in config.groupBy) GtsFieldDictionary.byKey(k)!,
    ];

    final waves = config.surveyIds.toSet();
    final filters = [
      for (final f in config.filters)
        (field: GtsFieldDictionary.byKey(f.field)!, values: f.values.toSet()),
    ];
    final inScope = <GtsRespondent>[
      for (final r in respondents)
        if (waves.contains(r.surveyId) &&
            (config.population == GtsPopulation.allRespondents ||
                r.isRosterLinked) &&
            filters.every((f) => _matches(f.field, r, f.values)))
          r,
    ];

    final totalDist = GtsStats.distribution(
      measure,
      inScope,
      gridColumn: config.gridColumn,
    );
    final (:shown, :hidden) = _pickCategories(config, totalDist);

    GtsReportRow row(List<String> groupValues, List<GtsRespondent> members) {
      final dist = identical(members, inScope)
          ? totalDist
          : GtsStats.distribution(
              measure,
              members,
              gridColumn: config.gridColumn,
            );
      final counts = {for (final c in shown) c: dist.count(c)};
      if (hidden.isNotEmpty) {
        counts[gtsAllOtherLabel] = _countAny(
          measure,
          members,
          hidden.toSet(),
          config.gridColumn,
        );
      }
      return GtsReportRow(
        groupValues: groupValues,
        distribution: dist,
        counts: counts,
        calculation: config.calculation,
        median: config.calculation == GtsCalculation.medianBracket
            ? GtsStats.medianBracket(dist)
            : null,
      );
    }

    final rows = <GtsReportRow>[];
    if (groupFields.isNotEmpty) {
      final groups =
          <String, ({List<String> keys, List<GtsRespondent> members})>{};
      for (final r in inScope) {
        final keys = [for (final f in groupFields) _groupValue(f, r)];
        groups
            .putIfAbsent(keys.join('\u0000'), () => (keys: keys, members: []))
            .members
            .add(r);
      }
      final ordered = groups.values.toList()
        ..sort((a, b) {
          for (var i = 0; i < groupFields.length; i++) {
            final c = _compareGroupValue(
              groupFields[i],
              config,
              a.keys[i],
              b.keys[i],
            );
            if (c != 0) return c;
          }
          return 0;
        });
      for (final g in ordered) {
        final labels = [
          for (var i = 0; i < groupFields.length; i++)
            groupFields[i].source == GtsFieldSource.wave
                ? waveLabels[g.keys[i]] ?? g.keys[i]
                : g.keys[i],
        ];
        rows.add(row(labels, g.members));
      }
    }

    return GtsReportResult(
      config: config,
      measure: measure,
      groupFields: groupFields,
      validation: validation,
      categories: [...shown, if (hidden.isNotEmpty) gtsAllOtherLabel],
      hiddenCategories: hidden,
      rows: rows,
      total: row(const [], inScope),
      generatedAt: now ?? DateTime.now(),
      waveLabels: waveLabels,
    );
  }

  /// Answered and picked any of [values]; respondents not asked never match.
  static bool _matches(GtsField field, GtsRespondent r, Set<String> values) {
    final answer = GtsStats.read(field, r);
    return answer.isAnswered && answer.values.any(values.contains);
  }

  static String _groupValue(GtsField field, GtsRespondent r) {
    final answer = GtsStats.read(field, r);
    return switch (answer.state) {
      GtsAnswerState.notAsked => gtsNotAskedLabel,
      GtsAnswerState.missing => gtsNotAnsweredLabel,
      GtsAnswerState.answered => answer.values.first,
    };
  }

  /// Respondents who picked at least one of [values] (multi-select safe).
  static int _countAny(
    GtsField field,
    List<GtsRespondent> members,
    Set<String> values,
    String? gridColumn,
  ) => members.where((r) {
    final answer = GtsStats.read(field, r, gridColumn: gridColumn);
    return answer.isAnswered && answer.values.any(values.contains);
  }).length;

  /// Categories to show (sorted) and those folded by the top N.
  static ({List<String> shown, List<String> hidden}) _pickCategories(
    GtsReportConfig config,
    GtsDistribution total,
  ) {
    final natural = [for (final c in total.categories) c.label];
    var shown = natural;
    var hidden = <String>[];
    final topN = config.topN;
    if (topN != null && natural.length > topN + 1) {
      final byCount = [...natural]
        ..sort((a, b) => _byCountThenNatural(total, natural, a, b));
      final keep = byCount.take(topN).toSet();
      shown = [
        for (final c in natural)
          if (keep.contains(c)) c,
      ];
      hidden = [
        for (final c in natural)
          if (!keep.contains(c)) c,
      ];
    }

    final direction = config.sortDescending ? -1 : 1;
    int key(String a, String b) => switch (config.sortBy) {
      GtsSortBy.natural => 0,
      GtsSortBy.label => a.toLowerCase().compareTo(b.toLowerCase()),
      GtsSortBy.count ||
      GtsSortBy.share => total.count(a).compareTo(total.count(b)),
    };
    final sorted = [...shown]
      ..sort((a, b) {
        final c = direction * key(a, b);
        if (c != 0) return c;
        final n = natural.indexOf(a) - natural.indexOf(b);
        return config.sortBy == GtsSortBy.natural ? direction * n : n;
      });
    return (shown: sorted, hidden: hidden);
  }

  /// Largest count first; ties keep questionnaire order.
  static int _byCountThenNatural(
    GtsDistribution total,
    List<String> natural,
    String a,
    String b,
  ) {
    final c = total.count(b).compareTo(total.count(a));
    return c != 0 ? c : natural.indexOf(a) - natural.indexOf(b);
  }

  /// Waves in selection order, answers in questionnaire order, years
  /// chronologically, anything else alphabetically; "Unknown", "Not
  /// answered" and "Not asked" last.
  static int _compareGroupValue(
    GtsField field,
    GtsReportConfig config,
    String a,
    String b,
  ) {
    int rank(String v) => switch (v) {
      gtsNotAskedLabel => 3,
      gtsNotAnsweredLabel => 2,
      gtsUnknownLabel => 1,
      _ => 0,
    };
    final r = rank(a).compareTo(rank(b));
    if (r != 0 || rank(a) != 0) return r;

    int byIndex(List<String> order) {
      final ia = order.indexOf(a);
      final ib = order.indexOf(b);
      if (ia >= 0 && ib >= 0) return ia - ib;
      if (ia >= 0) return -1;
      if (ib >= 0) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    }

    if (field.source == GtsFieldSource.wave) return byIndex(config.surveyIds);
    if (field.valueClass == GtsValueClass.year) {
      final ya = int.tryParse(a);
      final yb = int.tryParse(b);
      if (ya != null && yb != null) return ya.compareTo(yb);
    }
    return byIndex(field.options);
  }
}
