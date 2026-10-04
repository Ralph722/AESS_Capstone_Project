import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

/// Human-friendly DSS wording for admin UI (avoids jargon like "n", "metric").
abstract final class DssCopy {
  static String displayTitle(DssFlag flag) {
    final reason = evidenceReason(flag);
    if (flag.ruleId == 'DATA_QUALITY_LOW') {
      return switch (reason) {
        'sparse' => 'Too few survey responses',
        'low_rate' => 'Low survey response rate',
        'both' => 'Weak survey coverage',
        _ => _fallbackTitle(flag),
      };
    }
    return _fallbackTitle(flag);
  }

  static String displayHeadline(DssFlag flag) {
    final cohort = flag.cohortLabel;
    final survey = flag.surveyTitle.trim().isEmpty
        ? 'the tracer survey'
        : '"${flag.surveyTitle.trim()}"';
    if (flag.ruleId == 'DATA_QUALITY_LOW') {
      final reason = evidenceReason(flag);
      final answered = flag.sampleN;
      final eligible = flag.eligibleN ?? answered;
      final rate = (flag.metricValue * 100).toStringAsFixed(0);
      return switch (reason) {
        'sparse' =>
          '$answered alumni in $cohort answered $survey. '
              'That is too few responses to reliably judge employment outcomes yet'
              '${eligible > answered ? ' (roster size in this group: $eligible)' : ''}.',
        'low_rate' =>
          'Only $rate% of alumni in $cohort answered $survey '
              '($answered of $eligible). Response coverage is below the target.',
        'both' =>
          '$cohort has weak survey coverage for $survey: '
              '$answered of $eligible answered ($rate%). '
              'Collect more responses before using employment outcome flags.',
        _ => flag.body,
      };
    }
    if (flag.body.trim().isNotEmpty) return flag.body;
    return '${displayTitle(flag)} for $cohort.';
  }

  static String displayRecommendedAction(DssFlag flag) {
    if (flag.ruleId == 'DATA_QUALITY_LOW') {
      return switch (evidenceReason(flag)) {
        'sparse' =>
          'Collect more tracer responses from this course/batch before acting on employment or curriculum findings.',
        'low_rate' =>
          'Send reminders to alumni who have not submitted the tracer survey, then refresh insights.',
        'both' =>
          'Improve survey participation for this cohort (reminders + follow-up), then refresh insights before using outcome flags.',
        _ => flag.recommendedAction,
      };
    }
    return flag.recommendedAction;
  }

  static List<DssPlaybookStep> displayPlaybook(DssFlag flag) {
    if (flag.ruleId == 'DATA_QUALITY_LOW') {
      return switch (evidenceReason(flag)) {
        'sparse' => const [
          DssPlaybookStep(
            step: 'Check how many alumni in this course/batch are on the roster and assigned to the survey.',
          ),
          DssPlaybookStep(
            step: 'Invite more alumni to complete the tracer (announcement or message).',
          ),
          DssPlaybookStep(
            step: 'Wait until more responses arrive, then click Refresh insights.',
          ),
        ],
        'low_rate' || 'both' => const [
          DssPlaybookStep(
            step: 'Open Surveys and see who has not completed this tracer wave.',
          ),
          DssPlaybookStep(
            step: 'Send a reminder announcement or message to non-respondents.',
          ),
          DssPlaybookStep(
            step: 'After more alumni submit, refresh Program Insights before reviewing employment flags.',
          ),
        ],
        _ => flag.playbook,
      };
    }
    return flag.playbook;
  }

  static String metricLabel(DssFlag flag) => switch (flag.ruleId) {
    'DATA_QUALITY_LOW' => 'Response rate',
    'UNEMPLOYMENT_HIGH' => 'Not employed',
    'RELATEDNESS_LOW' => 'Course / curriculum mismatch',
    'RELATEDNESS_HIGH' => 'Course / curriculum alignment',
    'UNDEREMPLOYMENT' => 'Rank / clerical roles',
    'TIME_TO_JOB_LONG' => 'Took 1+ years to first job',
    'SALARY_STAGNATION' => 'Salary gap vs peers',
    'UNEMPLOYMENT_TREND_UP' => 'Change in not employed vs previous wave',
    _ => 'Measured value',
  };

  static String metricValueLabel(DssFlag flag) {
    if (flag.ruleId == 'SALARY_STAGNATION') {
      final gap = flag.metricValue;
      if (gap <= 0) return 'At or above peers';
      return '${gap.toStringAsFixed(1)} bracket(s) below peers';
    }
    final value = flag.isTrend
        ? formatPoints(flag.metricValue)
        : '${(flag.metricValue * 100).toStringAsFixed(0)}%';
    final range = rangeLabel(flag);
    return range == null ? value : '$value ($range)';
  }

  /// "likely 18–41%" (or "likely +3 to +21 pts" for trends) from the stored
  /// 95% margin of error.
  static String? rangeLabel(DssFlag flag) {
    final low = flag.ciLow;
    final high = flag.ciHigh;
    if (low == null || high == null) return null;
    if (flag.isTrend) {
      String signed(double v) {
        final pts = (v * 100).round();
        return pts > 0 ? '+$pts' : (pts < 0 ? '−${pts.abs()}' : '0');
      }

      return 'likely ${signed(low)} to ${signed(high)} pts';
    }
    return 'likely ${(low * 100).toStringAsFixed(0)}–'
        '${(high * 100).toStringAsFixed(0)}%';
  }

  /// "12% → 30%" between the previous and current wave (trend flags only).
  static String? trendLabel(DssFlag flag) {
    final before = flag.evidence['previous_rate'];
    final now = flag.evidence['current_rate'];
    if (before is! num || now is! num) return null;
    final title = flag.evidence['previous_survey_title']?.toString() ?? '';
    return '${(before * 100).toStringAsFixed(0)}% → '
        '${(now * 100).toStringAsFixed(0)}%'
        '${title.trim().isEmpty ? '' : ' (since "${title.trim()}")'}';
  }

  static String certaintyHint(DssFlag flag) {
    final pct = (flag.thresholdSnapshot * 100).toStringAsFixed(0);
    final opportunity = flag.ruleCategory == DssRuleCategory.opportunity;
    if (flag.isTrend) {
      return switch (flag.certainty) {
        DssCertainty.confirmed =>
          'Confirmed: even the smallest likely rise is at least $pct points.',
        DssCertainty.possible =>
          'Possible: the measured rise is at least $pct points, but with '
              'these group sizes the real change could be smaller. More '
              'responses would settle it.',
        null => '',
      };
    }
    return switch (flag.certainty) {
      DssCertainty.confirmed =>
        'Confirmed: even the most favourable end of the likely range '
            '${opportunity ? 'still reaches' : 'is still past'} the $pct% threshold.',
      DssCertainty.possible =>
        'Possible: the measured value crosses $pct%, but the likely range '
            'also includes values on the other side. More responses would '
            'settle it.',
      null => '',
    };
  }

  static String thresholdLabel(DssFlag flag) {
    if (flag.ruleId == 'SALARY_STAGNATION') {
      return 'Flag when gap ≥ ${flag.thresholdSnapshot.toStringAsFixed(0)} bracket(s)';
    }
    if (flag.ruleId == 'DATA_QUALITY_LOW') {
      final reason = evidenceReason(flag);
      final ratePct = (flag.thresholdSnapshot * 100).toStringAsFixed(0);
      if (reason == 'sparse') {
        return 'Flag when responses are below the minimum set in Rules';
      }
      if (reason == 'both') {
        return 'Flag when rate is below $ratePct% or responses are too few';
      }
      return 'Flag when response rate is below $ratePct%';
    }
    final pct = (flag.thresholdSnapshot * 100).toStringAsFixed(0);
    if (flag.isTrend) {
      return 'Flag when it rises by $pct points or more since the previous wave';
    }
    return 'Flag when this reaches $pct% or higher';
  }

  static String responsesLabel(DssFlag flag) {
    final n = flag.sampleN;
    return n == 1 ? '1 response' : '$n responses';
  }

  /// Whole active roster for the group (registered or not); this is the
  /// response-rate denominator.
  static String rosterLabel(DssFlag flag) {
    final e = flag.eligibleN;
    if (e == null) return 'Roster size unavailable';
    final base = e == 1 ? '1 on roster' : '$e on roster';
    final registered = flag.evidence['registered_roster'];
    if (registered is num) return '$base (${registered.toInt()} registered)';
    return base;
  }

  /// Why a flag covers a whole course or the institution instead of one
  /// course × batch. Null for course × batch flags.
  static String? rollupNote(DssFlag flag) {
    if (flag.cohortLevel == DssCohortLevel.batch) return null;
    final minN = flag.evidence['min_responses_required'];
    final small = flag.evidence['small_groups'];
    final isCourse = flag.cohortLevel == DssCohortLevel.course;
    final parts = <String>[];
    if (small is Map) {
      for (final e in small.entries) {
        final n = e.value is num ? (e.value as num).toInt() : 0;
        final name = isCourse ? 'Batch ${e.key}' : '${e.key}';
        parts.add('$name ($n ${n == 1 ? 'response' : 'responses'})');
      }
    }
    final scope = isCourse
        ? 'all batches of ${flag.course}'
        : 'the whole institution';
    if (parts.isEmpty) {
      return 'Combined across $scope because the smaller groups had too few '
          'responses to judge on their own.';
    }
    final shown = parts.length > 4
        ? '${parts.take(4).join(', ')} and ${parts.length - 4} more'
        : parts.join(', ');
    final minText = minN is num ? ' of ${minN.toInt()}' : '';
    return 'Combined across $scope because $shown '
        '${parts.length == 1 ? 'was' : 'were each'} below the minimum$minText '
        'responses.';
  }

  /// Where the measured value comes from, so admins know why it can differ
  /// from the dashboard (employment records) or the directory.
  static String sourceLabel(DssFlag flag) => switch (flag.ruleId) {
    'DATA_QUALITY_LOW' =>
      'Response rate = CHED GTS submissions ÷ everyone on the roster for this group, registered or not.',
    'UNEMPLOYMENT_HIGH' =>
      'Based on CHED GTS answers (Q16 "Are you presently employed?"). The dashboard uses employment records, so totals can differ.',
    'RELATEDNESS_LOW' || 'RELATEDNESS_HIGH' =>
      'Based on CHED GTS answers (Q24 first job related to course, Q32 curriculum relevant).',
    'UNDEREMPLOYMENT' =>
      'Based on CHED GTS answers (Q30 job level) from presently employed respondents.',
    'TIME_TO_JOB_LONG' =>
      'Based on CHED GTS answers (Q29 time to land first job).',
    'SALARY_STAGNATION' =>
      'Based on CHED GTS answers (Q31 first-job salary), compared with the other courses in the same wave.',
    'UNEMPLOYMENT_TREND_UP' =>
      'Based on CHED GTS answers (Q16) for the same group in this wave and the previous published wave.',
    _ => 'Based on CHED GTS answers.',
  };

  static String confidenceLabel(DssFlag flag) {
    if (flag.confidence == DssConfidence.low || flag.sampleN < 20) {
      return 'Limited — small group';
    }
    return 'Good enough for review';
  }

  /// Interventions that make sense for this rule. Always ends with Other.
  static List<String> interventionsForRule(String ruleId) {
    final options = switch (ruleId) {
      'DATA_QUALITY_LOW' => const [
        'Survey reminder campaign',
        'Announcement to non-respondents',
        'Roster / survey assignment cleanup',
        'Extended survey window / follow-up',
      ],
      'UNEMPLOYMENT_HIGH' => const [
        'Job fair / Career Center outreach',
        'Career counseling session',
        'Job board / posting push',
        'Employer partnership review',
      ],
      'RELATEDNESS_LOW' => const [
        'Curriculum committee review',
        'Industry alignment workshop',
        'Alumni mentor matching',
        'OJT / internship partnership',
      ],
      'RELATEDNESS_HIGH' => const [
        'Document successful practices',
        'Share findings with other programs',
        'Invite alumni mentors from cohort',
      ],
      'UNDEREMPLOYMENT' => const [
        'Career counseling session',
        'Upskilling / certification workshop',
        'Industry mentoring',
        'Curriculum pathway review',
      ],
      'TIME_TO_JOB_LONG' => const [
        'OJT / internship partnership',
        'Earlier career counseling for current students',
        'Job fair / Career Center outreach',
        'Employer partnership review',
      ],
      'SALARY_STAGNATION' => const [
        'Employer partnership review',
        'Industry alignment workshop',
        'Curriculum salary-pathway review',
        'Career counseling session',
      ],
      'UNEMPLOYMENT_TREND_UP' => const [
        'Job board / posting push',
        'Job fair / Career Center outreach',
        'Career counseling session',
        'Employer partnership review',
      ],
      _ => const [
        'Survey reminder campaign',
        'Job fair / Career Center outreach',
        'Curriculum committee review',
        'Career counseling session',
      ],
    };
    return [...options, 'Other'];
  }

  static String whyFlagged(DssFlag flag) {
    if (flag.ruleId == 'DATA_QUALITY_LOW') {
      return switch (evidenceReason(flag)) {
        'sparse' =>
          'Raised because too few alumni have answered yet (not because the response rate is low).',
        'low_rate' =>
          'Raised because the share of alumni who answered is below the target in Rules.',
        'both' =>
          'Raised because response coverage is weak: low participation and too few answers overall.',
        _ => 'Raised as a data-quality check before trusting outcome findings.',
      };
    }
    return switch (flag.certainty) {
      DssCertainty.confirmed =>
        'Raised because the measured value clearly crossed the rule threshold, even allowing for the margin of error.',
      DssCertainty.possible =>
        'Raised because the measured value crossed the rule threshold, but the margin of error is wide. Treat it as a possible issue.',
      null =>
        'Raised because the measured value crossed the rule threshold with enough responses.',
    };
  }

  static String evidenceReason(DssFlag flag) {
    final raw = flag.evidence['reason']?.toString();
    if (raw == 'sparse' || raw == 'low_rate' || raw == 'both') return raw!;
    // Backward-compatible inference for older flags.
    if (flag.ruleId == 'DATA_QUALITY_LOW') {
      final sparse = flag.evidence['sparse_sample'] == true;
      final lowRate = flag.metricValue < flag.thresholdSnapshot;
      if (sparse && lowRate) return 'both';
      if (sparse) return 'sparse';
      if (lowRate) return 'low_rate';
      // Old flags with 100% rate were almost always sparse-min-n triggers.
      if (flag.metricValue >= 0.999) return 'sparse';
    }
    return 'unknown';
  }

  static String _fallbackTitle(DssFlag flag) {
    final name = (flag.ruleName ?? '').trim();
    if (name.isNotEmpty) return name;
    return flag.title.split(':').first.trim().isEmpty
        ? flag.ruleId
        : flag.title.split(':').first.trim();
  }

  static String settingsThresholdHint(DssRule rule) {
    if (rule.ruleId == 'SALARY_STAGNATION') {
      return 'Bracket gap vs the other programs in the wave';
    }
    if (rule.ruleId == 'DATA_QUALITY_LOW') {
      return 'Flag when response rate is below this %';
    }
    if (rule.category == DssRuleCategory.trend) {
      return 'Flag when the share rises by this many points vs the previous wave';
    }
    return 'Flag when the measured % reaches this value';
  }

  static String settingsMinResponsesHint(DssRule rule) {
    if (rule.ruleId == 'DATA_QUALITY_LOW') {
      return 'Also flag when fewer than this many alumni have answered';
    }
    if (rule.category == DssRuleCategory.trend) {
      return 'Both waves need at least this many answers for the group';
    }
    return 'Do not raise this flag until at least this many alumni answered';
  }
}
