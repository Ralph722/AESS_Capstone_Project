import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
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
      if (answered == 0 && eligible > 0) {
        return 'No alumni in $cohort have answered $survey yet, although '
            '$eligible ${eligible == 1 ? 'is' : 'are'} on the roster.';
      }
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

  /// Suggestions for the owner office field; admins may type any name.
  static const officeSuggestions = [
    'Alumni Affairs Office',
    'Career Development & Placement Office',
    'Office of the Dean / Program Chair',
    'Curriculum Committee',
    'Guidance & Counseling Office',
    'Industry Linkages / OJT Office',
    "Registrar's Office",
  ];

  /// Cause that picks the playbook steps, from facts stored on the flag.
  /// Null when the rule has no causes or the facts are split evenly.
  static ({String key, String label})? playbookCause(DssFlag flag) {
    int count(dynamic v) => v is num ? v.toInt() : 0;
    final q17 = flag.evidence['q17'];
    switch (flag.ruleId) {
      case 'DATA_QUALITY_LOW':
        return switch (evidenceReason(flag)) {
          'sparse' => (key: 'sparse', label: 'Too few responses so far'),
          'low_rate' => (key: 'low_rate', label: 'Low response rate'),
          'both' => (
            key: 'both',
            label: 'Low response rate and too few responses',
          ),
          _ => null,
        };
      case 'UNEMPLOYMENT_HIGH':
        if (q17 is! Map) return null;
        final seeking = count(q17['seeking']);
        final notSeeking = count(q17['not_seeking']);
        final total = seeking + notSeeking + count(q17['reason_unknown']);
        if (seeking > notSeeking) {
          return (
            key: 'seeking',
            label:
                'Most are looking for work ($seeking of $total not employed)',
          );
        }
        if (notSeeking > seeking) {
          return (
            key: 'not_seeking',
            label:
                'Most are not looking for work ($notSeeking of $total not '
                'employed: further study, family, health or did not look)',
          );
        }
        return null;
      case 'SEEKING_WORK_HIGH':
        final reasons = q17 is Map ? q17['reasons'] : null;
        if (reasons is! Map) return null;
        final noJob = count(reasons['No job opportunity']);
        final noExperience = count(reasons['Lack of work experience']);
        if (noJob > noExperience) {
          return (
            key: 'no_opportunity',
            label:
                'Most cite no job opportunity ($noJob, against $noExperience '
                'citing lack of work experience)',
          );
        }
        if (noExperience > noJob) {
          return (
            key: 'lack_experience',
            label:
                'Most cite lack of work experience ($noExperience, against '
                '$noJob citing no job opportunity)',
          );
        }
        return null;
      default:
        return null;
    }
  }

  static List<DssPlaybookStep> displayPlaybook(DssFlag flag) {
    final steps = flag.playbook;
    if (steps.any((s) => s.cause != null)) {
      final detected = playbookCause(flag)?.key;
      final cause = detected != null && steps.any((s) => s.cause == detected)
          ? detected
          : 'default';
      return steps.where((s) => s.cause == null || s.cause == cause).toList();
    }
    if (flag.ruleId == 'DATA_QUALITY_LOW') {
      return switch (evidenceReason(flag)) {
        'sparse' => const [
          DssPlaybookStep(
            step:
                'Check how many alumni in this course/batch are on the roster and assigned to the survey.',
          ),
          DssPlaybookStep(
            step:
                'Invite more alumni to complete the tracer (announcement or message).',
          ),
          DssPlaybookStep(
            step:
                'Wait until more responses arrive, then click Refresh insights.',
          ),
        ],
        'low_rate' || 'both' => const [
          DssPlaybookStep(
            step:
                'Open Surveys and see who has not completed this tracer wave.',
          ),
          DssPlaybookStep(
            step: 'Send a reminder announcement or message to non-respondents.',
          ),
          DssPlaybookStep(
            step:
                'After more alumni submit, refresh Program Insights before reviewing employment flags.',
          ),
        ],
        _ => flag.playbook,
      };
    }
    return flag.playbook;
  }

  static String metricLabel(DssFlag flag) => switch (flag.ruleId) {
    'DATA_QUALITY_LOW' => 'Response rate',
    'UNEMPLOYMENT_HIGH' => 'Not currently employed',
    'SEEKING_WORK_HIGH' => 'Looking for work',
    'RELATEDNESS_LOW' => 'Course / curriculum mismatch',
    'RELATEDNESS_HIGH' => 'Course / curriculum alignment',
    'UNDEREMPLOYMENT' => 'Rank / clerical roles',
    'TIME_TO_JOB_LONG' => 'Took 1+ years to first job',
    'SALARY_STAGNATION' => 'Salary gap vs peers',
    'UNEMPLOYMENT_TREND_UP' => 'Change in not employed vs previous wave',
    _ => 'Measured value',
  };

  static String metricValueLabel(DssFlag flag) {
    if (flag.evidenceStrength == DssEvidenceStrength.insufficient) {
      return DssEvidenceStrength.insufficient.label;
    }
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
    if (flag.evidenceStrength == DssEvidenceStrength.insufficient) return null;
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
    final base = n == 1 ? '1 response' : '$n responses';
    if (flag.isDataQuality) return base;
    final valid = flag.validAnswers;
    if (valid == n) return base;
    return '$base · $valid answered this question';
  }

  /// "Watch — 7 answers (a finding needs 10)".
  static String? evidenceLabel(DssFlag flag) {
    final strength = flag.evidenceStrength;
    if (strength == null) return null;
    final n = flag.validAnswers;
    final answers = n == 1 ? '1 answer' : '$n answers';
    return switch (strength) {
      DssEvidenceStrength.insufficient =>
        '${strength.label} — $answers (needs at least '
            '${DssPolicy.notEnoughBelow} to show a rate)',
      DssEvidenceStrength.watch =>
        '${strength.label} — $answers (a finding needs '
            '${DssPolicy.findingGate(flag.ruleMinN)})',
      DssEvidenceStrength.limited =>
        '${strength.label} — $answers (strong from ${DssPolicy.strongFrom})',
      DssEvidenceStrength.strong => '${strength.label} — $answers',
    };
  }

  /// What the evidence level means for the reader.
  static String? evidenceHint(DssFlag flag) => switch (flag.evidenceStrength) {
    DssEvidenceStrength.insufficient =>
      'Too few alumni answered this question to show a rate. This is not a '
          'finding; collect more responses before drawing conclusions.',
    DssEvidenceStrength.watch =>
      'Small sample: the value crossed the threshold, but too few alumni '
          'answered to treat it as a finding. Keep an eye on it after more '
          'responses arrive.',
    DssEvidenceStrength.limited =>
      'A finding, but based on a modest number of answers. Read the likely '
          'range before acting.',
    DssEvidenceStrength.strong || null => null,
  };

  /// Warns when few people on the roster answered at all.
  static String? coverageNote(DssFlag flag) {
    if (!flag.coverageWarning) return null;
    final rate = flag.groupResponseRate;
    final pct = rate == null ? '' : ' (${(rate * 100).toStringAsFixed(0)}%)';
    return 'Low coverage$pct: fewer than '
        '${(DssPolicy.lowCoverageBelow * 100).toStringAsFixed(0)}% of this '
        'group\'s roster answered, so the result may not represent everyone.';
  }

  /// Q17 reasons of the not-employed respondents behind the flag.
  static String? notEmployedReasonsNote(DssFlag flag) {
    final q17 = flag.evidence['q17'];
    if (q17 is! Map) return null;
    int n(String key) => (q17[key] as num?)?.toInt() ?? 0;
    final total = n('seeking') + n('not_seeking') + n('reason_unknown');
    if (total == 0) return null;
    final parts = [
      '${n('seeking')} looking for work',
      '${n('not_seeking')} not looking',
      if (n('reason_unknown') > 0) '${n('reason_unknown')} gave no reason',
    ];
    final reasons = q17['reasons'];
    final ticked = reasons is Map && reasons.isNotEmpty
        ? (reasons.entries.toList()..sort(
                (a, b) =>
                    ((b.value as num?) ?? 0).compareTo((a.value as num?) ?? 0),
              ))
              .map((e) => '${e.key} (${e.value})')
              .join(', ')
        : null;
    return 'Why not employed (Q17), $total ${total == 1 ? 'person' : 'people'}: '
        '${parts.join(', ')}.'
        '${ticked == null ? '' : ' Reasons ticked: $ticked.'}';
  }

  /// Which roster the response rate was measured against.
  static String? rosterBasisNote(DssFlag flag) => switch (flag.rosterBasis) {
    'open_wave' => 'Roster counted while this wave is open.',
    'snapshot' => 'Roster as saved while this wave was open.',
    'current' =>
      'This closed wave has no saved roster, so today\'s roster is used. '
          'The rate may differ from what it was when the wave closed.',
    _ => null,
  };

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
        final name = !isCourse || e.key == DssPolicy.batchNotRecorded
            ? '${e.key}'
            : 'Batch ${e.key}';
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
    final hasUnrecorded =
        isCourse &&
        small is Map &&
        small.containsKey(DssPolicy.batchNotRecorded);
    return 'Combined across $scope because $shown '
        '${parts.length == 1 ? 'was' : 'were each'} below the minimum$minText '
        'responses'
        '${hasUnrecorded ? ' (alumni without a recorded batch only count at course level)' : ''}.';
  }

  /// Where the measured value comes from, so admins know why it can differ
  /// from the dashboard or the directory.
  static String sourceLabel(DssFlag flag) => switch (flag.ruleId) {
    'DATA_QUALITY_LOW' =>
      'Response rate = CHED GTS submissions ÷ everyone on the roster for this group, registered or not.',
    'UNEMPLOYMENT_HIGH' =>
      'Based on CHED GTS answers (Q16 "Are you presently employed?"), counting only alumni who answered Q16. "No" and "Never Employed" both count, including alumni in further study or not looking for work.',
    'SEEKING_WORK_HIGH' =>
      'Based on CHED GTS answers (Q16 and Q17). Looking for work = not employed with "No job opportunity" or "Lack of work experience" (and not "Did not look for a job"), out of everyone employed or looking for work. Further study, family and health reasons are left out, like the official unemployment rate.',
    'RELATEDNESS_LOW' || 'RELATEDNESS_HIGH' =>
      'Based on CHED GTS answers (Q24 first job related to course, Q32 curriculum relevant).',
    'UNDEREMPLOYMENT' =>
      'Based on CHED GTS answers (Q30 job level) from presently employed respondents.',
    'TIME_TO_JOB_LONG' =>
      'Based on CHED GTS answers (Q29 time to land first job). "Others" answers have no time period, so they are not counted.',
    'SALARY_STAGNATION' =>
      'Based on CHED GTS answers (Q31 first-job salary), compared with the other courses in the same wave.',
    'UNEMPLOYMENT_TREND_UP' =>
      'Based on CHED GTS answers (Q16) for the same group in this wave and the previous published wave.',
    _ => 'Based on CHED GTS answers.',
  };

  static String confidenceLabel(DssFlag flag) {
    final strength = flag.evidenceStrength;
    if (strength != null && !strength.isFinding) return strength.label;
    if (flag.coverageWarning) return 'Limited — low response coverage';
    if (strength == DssEvidenceStrength.limited ||
        flag.confidence == DssConfidence.low) {
      return 'Limited — modest number of answers';
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
      'SEEKING_WORK_HIGH' => const [
        'Job board / posting push',
        'Job fair / Career Center outreach',
        'Work-readiness / experience program',
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
    switch (flag.evidenceStrength) {
      case DssEvidenceStrength.insufficient:
        return 'Saved before the sample-size policy: fewer than '
            '${DssPolicy.notEnoughBelow} alumni answered, so it is not a finding.';
      case DssEvidenceStrength.watch:
        return 'Listed to watch: the value crossed the rule threshold, but '
            'fewer than ${DssPolicy.findingGate(flag.ruleMinN)} alumni '
            'answered, so it is not a finding yet.';
      default:
        break;
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
    final name = dssRuleDisplayName(flag.ruleId, flag.ruleName ?? '').trim();
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
    final floor = DssPolicy.minNFloor(rule.category);
    if (rule.ruleId == 'DATA_QUALITY_LOW') {
      return 'Also flag when fewer than this many alumni have answered '
          '(at least $floor; 1 flags groups with no answers)';
    }
    if (rule.category == DssRuleCategory.trend) {
      return 'Both waves need at least this many answers for the group '
          '(at least $floor)';
    }
    return 'Answers needed for a finding (at least $floor). Groups with '
        '${DssPolicy.notEnoughBelow} to one below this are listed as Watch; '
        'fewer than ${DssPolicy.notEnoughBelow} show "Not enough data"';
  }

  /// Label of an outcome success metric (`dss_interventions.success_metric`).
  static String outcomeMetricLabel(String metric) => switch (metric) {
    'response_rate' => 'Response rate',
    'unemployment_rate' => 'Not currently employed',
    'seeking_work_rate' => 'Looking for work',
    'unrelated_or_irrelevant_rate' => 'Course / curriculum mismatch',
    'related_and_relevant_rate' => 'Course / curriculum alignment',
    'clerical_among_employed_rate' => 'Rank / clerical roles',
    'long_time_to_first_job_rate' => 'Took 1+ years to first job',
    'salary_peer_gap' => 'Salary gap vs peers',
    _ => 'Measured value',
  };

  /// "31%" for a share, "1.5 brackets" for the salary gap.
  static String outcomeValue(String metric, double? value) {
    if (value == null) return 'no value';
    if (metric == 'salary_peer_gap') {
      return '${value.toStringAsFixed(1)} brackets';
    }
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  static String outcomeOperator(String operator) => switch (operator) {
    'lt' => 'below',
    'lte' => 'at or below',
    'gt' => 'above',
    _ => 'at least',
  };

  /// e.g. "Not currently employed below 25% in the next tracer wave".
  static String successTest(DssIntervention i) =>
      '${outcomeMetricLabel(i.successMetric)} '
      '${outcomeOperator(i.successOperator)} '
      '${outcomeValue(i.successMetric, i.successTarget)} '
      'in the next tracer wave';

  /// e.g. "40% (2025 wave, 12 answers)".
  static String outcomeBaseline(DssIntervention i) {
    final parts = [
      if (i.baselineSurveyTitle.trim().isNotEmpty) i.baselineSurveyTitle.trim(),
      if (i.baselineN != null) _answers(i.baselineN!),
    ];
    final value = outcomeValue(i.successMetric, i.baselineValue);
    return parts.isEmpty ? value : '$value (${parts.join(', ')})';
  }

  /// What the next wave showed, or why there is no result yet.
  static String outcomeFollowup(DssIntervention i) {
    final wave = i.followupSurveyTitle?.trim() ?? '';
    switch (i.outcomeStatus) {
      case DssOutcomeStatus.notEvaluated:
        return 'Not checked yet.';
      case DssOutcomeStatus.pendingFollowup:
        return wave.isEmpty
            ? 'Waiting for a tracer wave published after '
                  '${dssDateValue(i.startedOn)}.'
            : 'Waiting for $wave to close.';
      case DssOutcomeStatus.noComparableData:
        return '$wave: fewer than ${DssPolicy.notEnoughBelow} valid answers '
            'for this group, so there is nothing to compare.';
      case DssOutcomeStatus.inconclusive:
        return '$wave: ${outcomeValue(i.successMetric, i.followupValue)} '
            'from only ${_answers(i.followupN ?? 0)}, too few to judge.';
      case DssOutcomeStatus.successful:
      case DssOutcomeStatus.partiallySuccessful:
      case DssOutcomeStatus.unsuccessful:
        return '$wave: ${outcomeValue(i.successMetric, i.followupValue)} '
            'from ${_answers(i.followupN ?? 0)}.';
    }
  }

  static String outcomeHint(DssOutcomeStatus status) => switch (status) {
    DssOutcomeStatus.notEvaluated => 'The outcome has not been checked yet.',
    DssOutcomeStatus.pendingFollowup =>
      'Judged from the first tracer wave published after the intervention '
          'started, once that wave closes.',
    DssOutcomeStatus.successful => 'The next wave met the target.',
    DssOutcomeStatus.partiallySuccessful =>
      'The target was not met, but the next wave moved at least 5 points '
          '(0.5 salary brackets) toward it.',
    DssOutcomeStatus.unsuccessful =>
      'The next wave did not meet the target or move clearly toward it.',
    DssOutcomeStatus.inconclusive =>
      'The next wave has too few valid answers for this group to judge.',
    DssOutcomeStatus.noComparableData =>
      'The next wave has no comparable result for this group.',
  };

  /// Shown with every judged outcome.
  static const outcomeCaveat =
      'An observed change between waves, not proof that the intervention '
      'caused it.';

  static String _answers(int n) => n == 1 ? '1 answer' : '$n answers';
}
