import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

enum DssPriority { critical, high, medium, low, watch }

extension DssPriorityX on DssPriority {
  String get label => switch (this) {
    DssPriority.critical => 'Critical',
    DssPriority.high => 'High',
    DssPriority.medium => 'Medium',
    DssPriority.low => 'Low',
    DssPriority.watch => 'Watch',
  };

  /// Higher is more urgent.
  int get rank => switch (this) {
    DssPriority.critical => 4,
    DssPriority.high => 3,
    DssPriority.medium => 2,
    DssPriority.low => 1,
    DssPriority.watch => 0,
  };
}

class DssPriorityReason {
  const DssPriorityReason(this.text, [this.points = 0]);

  final String text;
  final int points;

  String get display => points == 0 ? text : '$text (+$points)';
}

class DssPriorityResult {
  const DssPriorityResult({
    required this.level,
    required this.score,
    required this.reasons,
  });

  final DssPriority level;
  final int score;
  final List<DssPriorityReason> reasons;
}

/// Deterministic priority of a flag, from facts it already holds. Every
/// point comes with a reason. AI never sets or changes it.
abstract final class DssPriorityCalc {
  static const notStartedDays = 30;
  static const affectedMin = 10;

  static DssPriorityResult of(DssFlag f, {required DateTime now}) {
    final n = f.validAnswers;
    if (f.status == DssFlagStatus.watch || !f.isFinding) {
      return DssPriorityResult(
        level: DssPriority.watch,
        score: 0,
        reasons: [
          DssPriorityReason(
            'Too few valid answers for a finding ($n); monitored only',
          ),
        ],
      );
    }
    if (f.ruleCategory == DssRuleCategory.opportunity) {
      return const DssPriorityResult(
        level: DssPriority.low,
        score: 0,
        reasons: [DssPriorityReason('Opportunity, not a problem')],
      );
    }

    final reasons = <DssPriorityReason>[];
    final severity = f.severity ?? DssSeverity.warning;
    reasons.add(
      DssPriorityReason('Rule severity: ${severity.label}', switch (severity) {
        DssSeverity.critical => 3,
        DssSeverity.warning => 2,
        DssSeverity.info => 1,
      }),
    );

    final below = switch (f.ruleOperator ?? 'gte') {
      'lt' || 'lte' => true,
      _ => false,
    };
    final margin = below
        ? f.thresholdSnapshot - f.metricValue
        : f.metricValue - f.thresholdSnapshot;
    final relative = f.thresholdSnapshot == 0
        ? (margin > 0 ? double.infinity : 0.0)
        : margin / f.thresholdSnapshot.abs();
    final (distance, distancePoints) = relative + 1e-9 >= 0.5
        ? ('far past', 2)
        : relative + 1e-9 >= 0.2
        ? ('well past', 1)
        : ('just past', 0);
    reasons.add(
      DssPriorityReason(
        '${f.metricLabelFor(f.metricValue)} against a threshold of '
        '${f.metricLabelFor(f.thresholdSnapshot)}: $distance',
        distancePoints,
      ),
    );

    switch (f.evidenceStrength) {
      case DssEvidenceStrength.strong:
        reasons.add(DssPriorityReason('Strong evidence: $n valid answers', 1));
      case DssEvidenceStrength.limited:
        reasons.add(DssPriorityReason('Limited evidence: $n valid answers'));
      case _:
        break;
    }

    switch (f.certainty) {
      case DssCertainty.confirmed:
        reasons.add(
          const DssPriorityReason(
            'Confirmed: the whole 95% range is past the threshold',
            1,
          ),
        );
      case DssCertainty.possible:
        reasons.add(
          const DssPriorityReason(
            'Possible: the 95% range overlaps the threshold',
          ),
        );
      case null:
        break;
    }

    final affected = _affected(f);
    if (affected != null) {
      reasons.add(
        DssPriorityReason(
          f.isDataQuality
              ? '$affected alumni in the group have not answered'
              : '$affected alumni affected',
          affected >= affectedMin ? 1 : 0,
        ),
      );
    }

    if (f.status == DssFlagStatus.open) {
      final days = now.difference(f.createdAt).inDays;
      if (days >= notStartedDays) {
        reasons.add(DssPriorityReason('Not started for $days days', 1));
      }
    }

    final score = reasons.fold<int>(0, (sum, r) => sum + r.points);
    return DssPriorityResult(
      level: score >= 7
          ? DssPriority.critical
          : score >= 5
          ? DssPriority.high
          : score >= 3
          ? DssPriority.medium
          : DssPriority.low,
      score: score,
      reasons: reasons,
    );
  }

  /// Most urgent first; ties go to the higher score, then the older flag.
  static int compare(DssFlag a, DssFlag b, {required DateTime now}) {
    final pa = of(a, now: now);
    final pb = of(b, now: now);
    final byLevel = pb.level.rank.compareTo(pa.level.rank);
    if (byLevel != 0) return byLevel;
    final byScore = pb.score.compareTo(pa.score);
    if (byScore != 0) return byScore;
    return a.createdAt.compareTo(b.createdAt);
  }

  /// Alumni behind a rate finding; null where a count has no meaning
  /// (trends, salary gap).
  static int? _affected(DssFlag f) {
    if (f.isDataQuality) {
      final eligible = f.eligibleN;
      if (eligible == null) return null;
      return (eligible - f.sampleN).clamp(0, eligible);
    }
    if (f.isTrend || f.ruleId == 'SALARY_STAGNATION') return null;
    return (f.metricValue * f.validAnswers).round();
  }
}
