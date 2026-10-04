import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

/// Closed-loop impact verdict after resolve / recheck.
enum DssImpactVerdict {
  improved,
  unchanged,
  stillFlagged,
  insufficientData,
}

extension DssImpactVerdictX on DssImpactVerdict {
  String get dbValue => switch (this) {
    DssImpactVerdict.improved => 'improved',
    DssImpactVerdict.unchanged => 'unchanged',
    DssImpactVerdict.stillFlagged => 'still_flagged',
    DssImpactVerdict.insufficientData => 'insufficient_data',
  };

  String get label => switch (this) {
    DssImpactVerdict.improved => 'Improved',
    DssImpactVerdict.unchanged => 'Unchanged',
    DssImpactVerdict.stillFlagged => 'Still flagged',
    DssImpactVerdict.insufficientData => 'Need more data',
  };

  String get hint => switch (this) {
    DssImpactVerdict.improved =>
      'Metric moved in the right direction and no longer crosses the rule.',
    DssImpactVerdict.unchanged =>
      'Metric is similar to baseline and the issue is no longer active.',
    DssImpactVerdict.stillFlagged =>
      'Cohort still meets the rule threshold (or sample is still too small).',
    DssImpactVerdict.insufficientData =>
      'Not enough responses yet to judge impact — collect more, then recheck.',
  };

  static DssImpactVerdict? fromDb(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'improved':
        return DssImpactVerdict.improved;
      case 'unchanged':
        return DssImpactVerdict.unchanged;
      case 'still_flagged':
        return DssImpactVerdict.stillFlagged;
      case 'insufficient_data':
        return DssImpactVerdict.insufficientData;
      default:
        return null;
    }
  }
}

/// Snapshot returned when recomputing a flag metric for impact checks.
class DssMetricSnapshot {
  const DssMetricSnapshot({
    this.metricValue,
    required this.sampleN,
    this.eligibleN,
  });

  final double? metricValue;
  final int sampleN;
  final int? eligibleN;
}

abstract final class DssImpact {
  static const verifyDelay = Duration(days: 7);
  static const _eps = 0.005;

  static bool crosses(String operator, double value, double threshold) {
    switch (operator) {
      case 'gt':
        return value > threshold;
      case 'lt':
        return value < threshold;
      case 'lte':
        return value <= threshold;
      case 'gte':
      default:
        return value >= threshold;
    }
  }

  /// Higher metric is worse for typical outcome rules (gte/gt).
  /// Lower metric is worse for response-rate style rules (lt/lte).
  static DssImpactVerdict compute({
    required String ruleId,
    required String operator,
    required double threshold,
    required int minN,
    required DssRuleCategory category,
    required double? baseline,
    required double? followup,
    required int sampleN,
  }) {
    if (followup == null) return DssImpactVerdict.insufficientData;

    if (category == DssRuleCategory.opportunity) {
      if (baseline == null) {
        return crosses(operator, followup, threshold)
            ? DssImpactVerdict.improved
            : DssImpactVerdict.unchanged;
      }
      if (followup >= baseline + _eps) return DssImpactVerdict.improved;
      if ((followup - baseline).abs() <= _eps) {
        return DssImpactVerdict.unchanged;
      }
      return DssImpactVerdict.unchanged;
    }

    final stillSparse =
        ruleId == 'DATA_QUALITY_LOW' && minN > 0 && sampleN < minN;
    final stillMetric = crosses(operator, followup, threshold);
    if (stillSparse || stillMetric) {
      return DssImpactVerdict.stillFlagged;
    }

    if (baseline == null) return DssImpactVerdict.unchanged;

    final higherIsWorse = operator == 'gte' || operator == 'gt';
    final lowerIsWorse = operator == 'lte' || operator == 'lt';

    if (higherIsWorse) {
      if (followup < baseline - _eps) return DssImpactVerdict.improved;
      return DssImpactVerdict.unchanged;
    }
    if (lowerIsWorse) {
      if (followup > baseline + _eps) return DssImpactVerdict.improved;
      return DssImpactVerdict.unchanged;
    }
    return DssImpactVerdict.unchanged;
  }

  static String formatMetric(String ruleId, double value) {
    if (ruleId == 'SALARY_STAGNATION') {
      return value.toStringAsFixed(1);
    }
    if (ruleId == 'UNEMPLOYMENT_TREND_UP') return formatPoints(value);
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}
