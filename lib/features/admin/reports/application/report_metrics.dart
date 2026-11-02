/// Shared reporting rates and denominator rules for AESS exports.
///
/// Principles (institutional + survey-specific reports):
/// - Unanswered questions are never treated as "No".
/// - Percentages always name their denominator.
/// - Salary bands are never averaged by midpoint.
/// - Multi-select shares may sum to more than 100%.
class ReportRate {
  const ReportRate({
    required this.hits,
    required this.total,
    required this.hitsLabel,
    required this.totalLabel,
  });

  final int hits;
  final int total;
  final String hitsLabel;
  final String totalLabel;

  double get ratio => total <= 0 ? 0 : hits / total;

  /// Percentage on a 0–100 scale.
  double get percent => ratio * 100;

  bool get hasDenominator => total > 0;

  String get coverageNote =>
      '$hitsLabel $hits of $totalLabel $total'
      '${hasDenominator ? '' : ' (no denominator)'}';
}

/// Pure metric helpers reused by survey exports and institutional downloads.
abstract final class ReportMetrics {
  /// Unique submitted respondents ÷ eligible alumni in the defined cohort.
  static ReportRate responseRate({
    required int submittedRespondents,
    required int eligibleAlumni,
  }) {
    return ReportRate(
      hits: submittedRespondents < 0 ? 0 : submittedRespondents,
      total: eligibleAlumni < 0 ? 0 : eligibleAlumni,
      hitsLabel: 'submitted respondents',
      totalLabel: 'eligible alumni',
    );
  }

  /// Employed respondents ÷ respondents with a valid employment-status answer.
  ///
  /// Does not treat unanswered Q16 as unemployed, and does not fold further
  /// study into unemployment.
  static ReportRate employmentRate({
    required int employedRespondents,
    required int answeredEmploymentStatus,
  }) {
    return ReportRate(
      hits: employedRespondents < 0 ? 0 : employedRespondents,
      total: answeredEmploymentStatus < 0 ? 0 : answeredEmploymentStatus,
      hitsLabel: 'employed',
      totalLabel: 'answered employment status',
    );
  }

  /// Option count ÷ answered count for one question (never ÷ submitted when
  /// the question was unanswered).
  static ReportRate optionShare({
    required int optionCount,
    required int answeredCount,
    String optionLabel = 'selected',
  }) {
    return ReportRate(
      hits: optionCount < 0 ? 0 : optionCount,
      total: answeredCount < 0 ? 0 : answeredCount,
      hitsLabel: optionLabel,
      totalLabel: 'answered',
    );
  }

  /// Prefer raw counts over reconstructing n from a rounded percentage.
  static int countFromShare({
    required int optionCount,
    required double ignoredRoundedPercent,
  }) =>
      optionCount < 0 ? 0 : optionCount;

  /// Clamp a non-negative integer used as a population size.
  static int nonNegative(int value) => value < 0 ? 0 : value;
}
