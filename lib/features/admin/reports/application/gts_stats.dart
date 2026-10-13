import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';

/// Label for respondents without a roster course or graduation year.
const gtsUnknownLabel = 'Unknown';

enum GtsAnswerState {
  /// Skip logic did not show the item to this respondent.
  notAsked,

  /// Shown but left blank.
  missing,

  answered,
}

/// One respondent's answer to one field, normalised to a list of values.
class GtsAnswer {
  const GtsAnswer._(this.state, this.values);

  static const notAsked = GtsAnswer._(GtsAnswerState.notAsked, []);
  static const missing = GtsAnswer._(GtsAnswerState.missing, []);

  factory GtsAnswer.answered(List<String> values) =>
      GtsAnswer._(GtsAnswerState.answered, values);

  final GtsAnswerState state;

  /// Chosen values: one for single choice, several for multi-select and
  /// grids, empty for open text and tables (only answered or not).
  final List<String> values;

  bool get isAnswered => state == GtsAnswerState.answered;
}

class GtsCategoryCount {
  const GtsCategoryCount(this.label, this.count);

  final String label;
  final int count;
}

/// Counts of one field over a set of respondents, with every denominator a
/// share can use.
class GtsDistribution {
  const GtsDistribution({
    required this.field,
    required this.categories,
    required this.respondents,
    required this.eligible,
    required this.answered,
    this.gridColumn,
  });

  final GtsField field;

  /// Grid column counted (e.g. "30.2. Current or Present Job"), if any.
  final String? gridColumn;

  /// Every allowed value in questionnaire order (zero counts included),
  /// then any other values found in the data.
  final List<GtsCategoryCount> categories;

  /// Respondents in scope.
  final int respondents;

  /// Respondents the item was shown to.
  final int eligible;

  /// Respondents who gave an answer.
  final int answered;

  int get notAsked => respondents - eligible;
  int get missing => eligible - answered;

  /// Multi-select and grids: one respondent can add to several categories,
  /// so shares can total over 100%.
  bool get sharesCanExceed100 =>
      field.valueClass == GtsValueClass.multiSelect ||
      (field.valueClass == GtsValueClass.grid && gridColumn == null);

  int count(String category) {
    for (final c in categories) {
      if (c.label == category) return c.count;
    }
    return 0;
  }

  /// Denominator [calculation] divides by.
  int denominator(GtsCalculation calculation) => switch (calculation) {
    GtsCalculation.shareOfEligible => eligible,
    GtsCalculation.shareOfAllRespondents => respondents,
    _ => answered,
  };

  DssProportion share(String category, GtsCalculation calculation) =>
      DssProportion(hits: count(category), total: denominator(calculation));

  /// 95% Wilson range, the same method the DSS uses.
  ({double low, double high}) interval(
    String category,
    GtsCalculation calculation,
  ) => DssMetrics.wilson(count(category), denominator(calculation));

  /// DSS sample-size label for the denominator behind [calculation].
  DssEvidenceStrength evidence(GtsCalculation calculation) =>
      DssPolicy.strength(denominator(calculation));

  /// Too few answers to show a share ("Not enough data").
  bool isSuppressed(GtsCalculation calculation) =>
      denominator(calculation) < DssPolicy.notEnoughBelow;
}

/// Middle bracket of an ordinal field. [lower] and [upper] differ when an
/// even number of answers splits across two brackets.
class GtsMedianBracket {
  const GtsMedianBracket({
    required this.lower,
    required this.upper,
    required this.n,
  });

  final String lower;
  final String upper;

  /// Answers that name a bracket ("Others" excluded).
  final int n;

  String get label => lower == upper ? lower : 'Between $lower and $upper';
}

/// Shared GTS counting for reports. Rates and sample-size rules come from
/// the DSS ([DssMetrics], [DssPolicy]) so both always agree.
abstract final class GtsStats {
  static final _visible = Expando<Set<String>>();

  /// CHED items [respondent] was asked, worked out once per answers map
  /// (answers are not changed after loading).
  static Set<String> visibleItems(GtsRespondent respondent) =>
      _visible[respondent.answers] ??= ChedGtsVisibility.visibleItemIds(
        respondent.answers,
      );

  /// [respondent]'s answer to [field]. Pass [visible] (from
  /// [ChedGtsVisibility.visibleItemIds]) when reading many fields of the
  /// same respondent.
  static GtsAnswer read(
    GtsField field,
    GtsRespondent respondent, {
    String? gridColumn,
    Set<String>? visible,
  }) {
    switch (field.source) {
      case GtsFieldSource.roster:
        final raw = field.key == GtsFieldDictionary.course
            ? respondent.course
            : respondent.yearGraduated;
        final v = raw.trim();
        return GtsAnswer.answered([v.isEmpty ? gtsUnknownLabel : v]);
      case GtsFieldSource.wave:
        return GtsAnswer.answered([respondent.surveyId]);
      case GtsFieldSource.chedAnswer:
        break;
    }

    final answers = respondent.answers;
    if (field.isConditional) {
      final shown = visible ?? visibleItems(respondent);
      if (!shown.contains(field.key)) return GtsAnswer.notAsked;
    }

    final raw = answers[field.key];
    GtsAnswer fromValues(List<String> values) =>
        values.isEmpty ? GtsAnswer.missing : GtsAnswer.answered(values);
    GtsAnswer fromFlag(bool hasAnswer) =>
        hasAnswer ? GtsAnswer.answered(const []) : GtsAnswer.missing;

    return switch (field.valueClass) {
      GtsValueClass.categorical ||
      GtsValueClass.ordinal => fromValues([?DssMetrics.single(raw)]),
      GtsValueClass.multiSelect => fromValues(_list(raw)),
      GtsValueClass.grid => fromValues(_gridValues(raw, gridColumn)),
      GtsValueClass.table => fromFlag(_tableHasRow(raw)),
      GtsValueClass.freeText ||
      GtsValueClass.date ||
      GtsValueClass.year => fromFlag((raw?.toString().trim() ?? '').isNotEmpty),
    };
  }

  static GtsDistribution distribution(
    GtsField field,
    Iterable<GtsRespondent> respondents, {
    String? gridColumn,
  }) {
    var total = 0;
    var eligible = 0;
    var answered = 0;
    final counts = <String, int>{};
    for (final r in respondents) {
      total++;
      final answer = read(field, r, gridColumn: gridColumn);
      if (answer.state == GtsAnswerState.notAsked) continue;
      eligible++;
      if (!answer.isAnswered) continue;
      answered++;
      for (final v in answer.values.toSet()) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
    }

    final known = field.valueClass == GtsValueClass.grid
        ? field.gridRows
        : field.options;
    final extra = counts.keys.where((k) => !known.contains(k)).toList()
      ..sort((a, b) => _compareExtra(field, a, b));
    return GtsDistribution(
      field: field,
      gridColumn: gridColumn,
      categories: [
        for (final k in [...known, ...extra])
          GtsCategoryCount(k, counts[k] ?? 0),
      ],
      respondents: total,
      eligible: eligible,
      answered: answered,
    );
  }

  /// Median bracket of an ordinal [distribution]; null when no answer names
  /// a bracket or the field is not ordinal.
  static GtsMedianBracket? medianBracket(GtsDistribution distribution) {
    final brackets = distribution.field.brackets;
    if (brackets.isEmpty) return null;
    final ranks = <double>[
      for (var i = 0; i < brackets.length; i++)
        for (var n = distribution.count(brackets[i]); n > 0; n--) i.toDouble(),
    ];
    if (ranks.isEmpty) return null;
    final mid = DssMetrics.median(ranks);
    return GtsMedianBracket(
      lower: brackets[mid.floor()],
      upper: brackets[mid.ceil()],
      n: ranks.length,
    );
  }

  static List<String> _list(dynamic raw) {
    final items = raw is List ? raw : [?raw];
    return [
      for (final v in items)
        if (v.toString().trim().isNotEmpty) v.toString().trim(),
    ];
  }

  /// Rows ticked in [column], or in any column when [column] is null.
  static List<String> _gridValues(dynamic raw, String? column) {
    if (raw is! Map) return const [];
    return [
      for (final e in raw.entries)
        if (e.value is Map &&
            (column == null
                ? (e.value as Map).values.any((c) => c == true)
                : (e.value as Map)[column] == true))
          e.key.toString(),
    ];
  }

  static bool _tableHasRow(dynamic raw) =>
      raw is List &&
      raw.any(
        (row) =>
            row is Map &&
            row.values.any((c) => c != null && c.toString().trim().isNotEmpty),
      );

  /// Years in order with "Unknown" last; anything else alphabetical.
  static int _compareExtra(GtsField field, String a, String b) {
    if (a == gtsUnknownLabel) return b == gtsUnknownLabel ? 0 : 1;
    if (b == gtsUnknownLabel) return -1;
    if (field.valueClass == GtsValueClass.year) {
      final ya = int.tryParse(a);
      final yb = int.tryParse(b);
      if (ya != null && yb != null) return ya.compareTo(yb);
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}
