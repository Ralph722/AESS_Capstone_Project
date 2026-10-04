import 'package:alumni_system/features/admin/dss/application/dss_impact.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_rollup.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Deterministic DSS evaluation over CHED GTS responses × roster cohorts.
class DssEvaluationService {
  DssEvaluationService({
    DssRepository? repository,
    SurveyService? surveyService,
    AlumniMemberService? memberService,
  }) : _repo = repository ?? DssRepository(),
       _surveys = surveyService ?? SurveyService(),
       _members = memberService ?? AlumniMemberService();

  final DssRepository _repo;
  final SurveyService _surveys;
  final AlumniMemberService _members;

  Future<DssEvaluationResult> evaluateAll({
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Loading rules…');
    final rules = await _repo.listRules();
    final enabled = {for (final r in rules.where((r) => r.enabled)) r.ruleId: r};
    if (enabled.isEmpty) {
      return const DssEvaluationResult(
        cohortsEvaluated: 0,
        flagsRaisedOrUpdated: 0,
        message: 'No enabled DSS rules.',
      );
    }

    onProgress?.call('Loading roster…');
    final members = await _members.getAllMembers();
    final active = members.where((m) => !m.isDeactivated).toList();
    final byAuth = _byAuth(active);
    final roster = _Roster.from(active);

    onProgress?.call('Loading surveys…');
    final surveys = await _surveys.getAllSurveys();
    final chedWaves = surveys
        .where(
          (s) =>
              !s.archived &&
              s.isChedGtsBuiltin &&
              (s.status == SurveyStatus.published ||
                  s.status == SurveyStatus.closed),
        )
        .toList();

    var cohorts = 0;
    var rolledUpGroups = 0;
    var upserts = 0;
    var wavesWithResponses = 0;
    var responsesScanned = 0;
    final waves = <_WaveData>[];

    for (final survey in chedWaves) {
      onProgress?.call('Evaluating ${survey.title}…');
      final responses = await _surveys.getSurveyResponses(survey.id);
      if (responses.isEmpty) {
        continue;
      }
      wavesWithResponses++;
      responsesScanned += responses.length;

      final buckets = <String, _CohortBucket>{};
      for (final r in responses) {
        final member = byAuth[r.userId];
        final course = _courseOf(member);
        final batch = _batchOf(member);
        buckets
            .putIfAbsent(
              DssRollup.batchKey(course, batch),
              () => _CohortBucket(course: course, batchYear: batch),
            )
            .responses
            .add(r);
      }

      final sizes = <String, Map<String, int>>{};
      for (final b in buckets.values) {
        sizes.putIfAbsent(b.course, () => {})[b.batchYear] = b.responses.length;
      }
      final plans = <String, DssRollupPlan>{
        for (final r in enabled.values)
          if (r.category == DssRuleCategory.outcome ||
              r.category == DssRuleCategory.opportunity)
            r.ruleId: DssRollup.plan(sizes, r.minN),
      };
      waves.add(
        _WaveData(survey: survey, responses: responses, buckets: buckets),
      );

      final ctx = _WaveContext(
        survey: survey,
        enabled: enabled,
        sizes: sizes,
        salaryByCourse: _salaryRanksByCourse(
          buckets.values.map(
            (b) => (course: b.course, responses: b.responses),
          ),
        ),
        minNForOutcomes: _minNForOutcomes(enabled),
      );

      final groups = <_Group>[];
      for (final b in buckets.values) {
        cohorts++;
        final counts = roster.batch(b.course, b.batchYear);
        final group = _Group(
          level: DssCohortLevel.batch,
          course: b.course,
          batchYear: b.batchYear,
          label: '${b.course} · Batch ${b.batchYear}',
          responses: b.responses,
          eligible: counts?.total ?? b.responses.length,
          registered: counts?.registered ?? 0,
        );
        upserts += await _raiseDataQuality(ctx, group);
        groups.add(group);
      }

      final rolledCourses = {for (final p in plans.values) ...p.courses};
      for (final course in rolledCourses) {
        final counts = roster.course(course);
        final sample = [
          for (final b in buckets.values)
            if (b.course == course) ...b.responses,
        ];
        groups.add(
          _Group(
            level: DssCohortLevel.course,
            course: course,
            batchYear: DssRollup.all,
            label: '$course (all batches)',
            responses: sample,
            eligible: counts.total,
            registered: counts.registered,
          ),
        );
      }
      if (plans.values.any((p) => p.institution)) {
        groups.add(
          _Group(
            level: DssCohortLevel.institution,
            course: DssRollup.all,
            batchYear: DssRollup.all,
            label: 'the whole institution',
            responses: responses,
            eligible: roster.total,
            registered: roster.registered,
          ),
        );
      }
      rolledUpGroups += groups
          .where((g) => g.level != DssCohortLevel.batch)
          .length;

      for (final group in groups) {
        bool allowed(String ruleId) {
          final plan = plans[ruleId];
          if (plan == null) return false;
          return switch (group.level) {
            DssCohortLevel.batch => plan.includesBatch(
              group.course,
              group.batchYear,
            ),
            DssCohortLevel.course => plan.courses.contains(group.course),
            DssCohortLevel.institution =>
              plan.institution && ruleId != 'SALARY_STAGNATION',
          };
        }

        upserts += await _raiseOutcomes(ctx, group, allowed);
      }
    }

    final trendRule = enabled['UNEMPLOYMENT_TREND_UP'];
    if (trendRule != null && waves.length > 1) {
      onProgress?.call('Comparing tracer waves…');
      upserts += await _raiseTrends(trendRule, waves, roster);
    }

    final buffer = StringBuffer()
      ..write(
        'Evaluated $cohorts cohort(s) across $wavesWithResponses of '
        '${chedWaves.length} CHED wave(s) '
        '($responsesScanned submitted response(s)). ',
      );
    if (rolledUpGroups > 0) {
      buffer.write(
        'Small groups were combined into $rolledUpGroups course or '
        'institution-wide group(s). ',
      );
    }
    buffer.write('$upserts flag(s) raised or updated.');
    if (upserts == 0) {
      buffer.write(
        ' No group met an enabled rule yet — lower Threshold (%) and '
        'Min. responses on Rules, click Save on each rule, then Refresh again.',
      );
    }
    if (chedWaves.isEmpty) {
      buffer.write(
        ' No published/closed CHED GTS surveys were found.',
      );
    }
    return DssEvaluationResult(
      cohortsEvaluated: cohorts,
      flagsRaisedOrUpdated: upserts,
      message: buffer.toString(),
      chedWaves: chedWaves.length,
      wavesWithResponses: wavesWithResponses,
      responsesScanned: responsesScanned,
    );
  }

  /// Response-rate / sparse-sample check, per course × batch only.
  Future<int> _raiseDataQuality(_WaveContext ctx, _Group group) async {
    final rule = ctx.enabled['DATA_QUALITY_LOW'];
    if (rule == null) return 0;
    final sample = group.responses;
    final eligible = group.eligible;
    final responseRate = group.responseRate;
    final crossesRate = DssMetrics.crosses(
      rule.operator,
      responseRate,
      rule.threshold,
    );
    final crossesSparse = rule.minN > 0 && sample.length < rule.minN;
    if (!crossesRate && !crossesSparse) return 0;

    final survey = ctx.survey;
    final cohortText = group.label;
    final reason = crossesRate && crossesSparse
        ? 'both'
        : crossesSparse
            ? 'sparse'
            : 'low_rate';
    final ratePct = (responseRate * 100).toStringAsFixed(0);
    final String title;
    final String body;
    final String action;
    switch (reason) {
      case 'sparse':
        title = 'Too few survey responses: $cohortText';
        body =
            '${sample.length} alumni in $cohortText '
            'answered "${survey.title}". That is below the minimum of '
            '${rule.minN} responses needed before outcome findings '
            'are reliable'
            '${eligible > sample.length ? ' (roster in this group: $eligible)' : ''}.';
        action =
            'Collect more tracer responses from this course/batch before acting on employment or curriculum findings.';
      case 'low_rate':
        title = 'Low survey response rate: $cohortText';
        body =
            'Only $ratePct% of alumni on the roster for $cohortText '
            'answered "${survey.title}" (${sample.length} of $eligible). '
            'Coverage is below the ${(rule.threshold * 100).toStringAsFixed(0)}% target.';
        action =
            'Send reminders to alumni who have not submitted the tracer survey, then refresh insights.';
      default:
        title = 'Weak survey coverage: $cohortText';
        body =
            '$cohortText has weak coverage for '
            '"${survey.title}": ${sample.length} of $eligible on the roster '
            'answered ($ratePct%). '
            'Raise participation before trusting employment outcome flags.';
        action =
            'Improve survey participation for this cohort, then refresh insights before using outcome flags.';
    }
    await _repo.upsertActiveFlag(
      _flagRow(
        rule: rule,
        group: group,
        survey: survey,
        metricValue: responseRate,
        confidence: DssConfidence.ok,
        evidence: {
          'response_rate': responseRate,
          'respondents': sample.length,
          'eligible_roster': eligible,
          'registered_roster': group.registered,
          'roster_scope': 'whole_roster',
          'reason': reason,
          if (crossesSparse) 'sparse_sample': true,
          'min_responses_required': rule.minN,
        },
        body: body,
        titleOverride: title,
        recommendedActionOverride: action,
      ),
    );
    return 1;
  }

  /// Outcome and opportunity rules for one group; [allowed] says which rules
  /// the roll-up plan assigns to this group.
  Future<int> _raiseOutcomes(
    _WaveContext ctx,
    _Group group,
    bool Function(String ruleId) allowed,
  ) async {
    final sample = group.responses;
    final answers = sample.map((r) => r.answers).toList();
    final cohortText = group.label;
    final dataQuality = ctx.enabled['DATA_QUALITY_LOW'];
    final lowData =
        sample.length < ctx.minNForOutcomes ||
        (dataQuality != null &&
            DssMetrics.crosses(
              dataQuality.operator,
              group.responseRate,
              dataQuality.threshold,
            ));
    // Low confidence when the sample is below the typical reporting floor (20).
    final confidence =
        lowData || sample.length < 20 ? DssConfidence.low : DssConfidence.ok;
    var upserts = 0;

    Future<void> maybeRaise(
      String ruleId,
      double? metric,
      Map<String, dynamic> evidence,
      String body, {
      DssProportion? share,
    }) async {
      final rule = ctx.enabled[ruleId];
      if (rule == null || metric == null || !allowed(ruleId)) return;
      if (sample.length < rule.minN) return;
      if (!DssMetrics.crosses(rule.operator, metric, rule.threshold)) {
        return;
      }
      final interval = share == null
          ? null
          : DssMetrics.wilson(share.hits, share.total);
      await _repo.upsertActiveFlag(
        _flagRow(
          rule: rule,
          group: group,
          survey: ctx.survey,
          metricValue: metric,
          confidence: confidence,
          evidence: {
            ...evidence,
            'registered_roster': group.registered,
            'source': 'ched_gts',
            if (interval != null) ...{
              'ci_low': interval.low,
              'ci_high': interval.high,
              'ci_level': 0.95,
              'certainty': DssMetrics.certainty(
                rule.operator,
                rule.threshold,
                interval,
              ),
            },
            ..._rollupEvidence(ctx, group, rule),
          },
          body: body,
        ),
      );
      upserts++;
    }

    final unemployment = DssMetrics.unemployment(answers);
    if (unemployment != null) {
      await maybeRaise(
        'UNEMPLOYMENT_HIGH',
        unemployment.rate,
        {
          'question': 'ched_16',
          'not_employed': unemployment.hits,
          'answered': unemployment.total,
          'breakdown': DssMetrics.employmentBreakdown(answers),
        },
        '${_pct1(unemployment.rate)} of ${unemployment.total} '
        'respondents in $cohortText are not presently employed.',
        share: unemployment,
      );
    }

    final relatedness = DssMetrics.relatedness(answers);
    if (relatedness != null) {
      final mismatch = relatedness.mismatchShare;
      final suggestions = relatedness.mismatchSuggestions;
      await maybeRaise(
        'RELATEDNESS_LOW',
        mismatch.rate,
        {
          'questions': ['ched_24a', 'ched_32'],
          'mismatch_count': mismatch.hits,
          'answered': mismatch.total,
          'suggestion_count': suggestions.length,
          'suggestion_themes': DssMetrics.themeHints(suggestions),
          'suggestion_samples': suggestions.take(5).toList(),
        },
        '${_pct1(mismatch.rate)} of ${mismatch.total} '
        'respondents report course/curriculum mismatch for $cohortText.',
        share: mismatch,
      );

      final aligned = relatedness.alignedShare;
      await maybeRaise(
        'RELATEDNESS_HIGH',
        aligned.rate,
        {
          'questions': ['ched_24a', 'ched_32'],
          'aligned_count': aligned.hits,
          'answered': aligned.total,
        },
        '${_pct1(aligned.rate)} of ${aligned.total} '
        'respondents report strong course/curriculum alignment for '
        '$cohortText.',
        share: aligned,
      );
    }

    final clerical = DssMetrics.clerical(answers);
    if (clerical != null) {
      await maybeRaise(
        'UNDEREMPLOYMENT',
        clerical.rate,
        {
          'question': 'ched_30',
          'clerical': clerical.hits,
          'employed_with_level': clerical.total,
        },
        '${_pct1(clerical.rate)} of ${clerical.total} '
        'employed respondents report Rank/Clerical roles ($cohortText).',
        share: clerical,
      );
    }

    final longWait = DssMetrics.longTimeToFirstJob(answers);
    if (longWait != null) {
      await maybeRaise(
        'TIME_TO_JOB_LONG',
        longWait.rate,
        {
          'question': 'ched_29',
          'long_count': longWait.hits,
          'answered': longWait.total,
          'breakdown': DssMetrics.counts(DssMetrics.timeToJobAnswers(answers)),
        },
        '${_pct1(longWait.rate)} of ${longWait.total} '
        'respondents took 1+ years to land a first job ($cohortText).',
        share: longWait,
      );
    }

    if (group.level != DssCohortLevel.institution) {
      final ranks = DssMetrics.salaryRanks(answers);
      final peerMedian = DssMetrics.peerMedianExcluding(
        ctx.salaryByCourse,
        group.course,
      );
      final gap = DssMetrics.salaryGap(ranks, peerMedian);
      if (gap != null) {
        await maybeRaise(
          'SALARY_STAGNATION',
          gap,
          {
            'question': 'ched_31',
            'cohort_median_rank': DssMetrics.median(
              ranks.map((e) => e.toDouble()),
            ),
            'peer_median_rank': peerMedian,
            'peer_scope': 'other_courses',
            'answered': ranks.length,
            'note':
                'Gap is the median salary rank of other courses in this wave '
                'minus the cohort median; ≥1 means at least one bracket below.',
          },
          'First-job salary for $cohortText is '
          '${gap.toStringAsFixed(1)} bracket(s) below the median of other '
          'courses in this wave.',
        );
      }
    }

    return upserts;
  }

  /// Which smaller groups were combined, so the detail page can explain it.
  static Map<String, dynamic> _rollupEvidence(
    _WaveContext ctx,
    _Group group,
    DssRule rule,
  ) => switch (group.level) {
    DssCohortLevel.batch => const {},
    DssCohortLevel.course => {
      'rolled_up': true,
      'small_groups': DssRollup.smallBatches(ctx.sizes, group.course, rule.minN),
      'min_responses_required': rule.minN,
    },
    DssCohortLevel.institution => {
      'rolled_up': true,
      'small_groups': DssRollup.smallCourses(ctx.sizes, rule.minN),
      'min_responses_required': rule.minN,
    },
  };

  /// UNEMPLOYMENT_TREND_UP: each wave against the wave before it, for the
  /// same groups (rolled up when a group is too small in either wave).
  Future<int> _raiseTrends(
    DssRule rule,
    List<_WaveData> waves,
    _Roster roster,
  ) async {
    final ordered = [...waves]
      ..sort((a, b) => waveDate(a.survey).compareTo(waveDate(b.survey)));
    var upserts = 0;

    for (var i = 1; i < ordered.length; i++) {
      final prev = ordered[i - 1];
      final curr = ordered[i];
      final plan = DssRollup.planChange(curr.sizes, prev.sizes, rule.minN);

      final pairs = <({_Group group, List<SurveyResponse> previous})>[];
      for (final key in plan.batches) {
        final c = curr.buckets[key]!;
        final counts = roster.batch(c.course, c.batchYear);
        pairs.add((
          group: _Group(
            level: DssCohortLevel.batch,
            course: c.course,
            batchYear: c.batchYear,
            label: '${c.course} · Batch ${c.batchYear}',
            responses: c.responses,
            eligible: counts?.total ?? c.responses.length,
            registered: counts?.registered ?? 0,
          ),
          previous: prev.buckets[key]!.responses,
        ));
      }
      for (final course in plan.courses) {
        final counts = roster.course(course);
        pairs.add((
          group: _Group(
            level: DssCohortLevel.course,
            course: course,
            batchYear: DssRollup.all,
            label: '$course (all batches)',
            responses: curr.forCourse(course),
            eligible: counts.total,
            registered: counts.registered,
          ),
          previous: prev.forCourse(course),
        ));
      }
      if (plan.institution) {
        pairs.add((
          group: _Group(
            level: DssCohortLevel.institution,
            course: DssRollup.all,
            batchYear: DssRollup.all,
            label: 'the whole institution',
            responses: curr.responses,
            eligible: roster.total,
            registered: roster.registered,
          ),
          previous: prev.responses,
        ));
      }

      for (final pair in pairs) {
        final group = pair.group;
        final now = DssMetrics.unemployment(
          group.responses.map((r) => r.answers),
        );
        final before = DssMetrics.unemployment(
          pair.previous.map((r) => r.answers),
        );
        if (now == null || before == null) continue;
        if (now.total < rule.minN || before.total < rule.minN) continue;
        final change = now.rate - before.rate;
        if (!DssMetrics.crosses(rule.operator, change, rule.threshold)) {
          continue;
        }
        final interval = DssMetrics.changeInterval(now, before);
        final small = group.level == DssCohortLevel.batch
            ? const <String, int>{}
            : _smallComparable(curr, prev, group, rule.minN);

        await _repo.upsertActiveFlag(
          _flagRow(
            rule: rule,
            group: group,
            survey: curr.survey,
            metricValue: change,
            confidence: now.total < 20 || before.total < 20
                ? DssConfidence.low
                : DssConfidence.ok,
            evidence: {
              'question': 'ched_16',
              'source': 'ched_gts',
              'previous_survey_id': prev.survey.id,
              'previous_survey_title': prev.survey.title,
              'previous_rate': before.rate,
              'previous_not_employed': before.hits,
              'previous_answered': before.total,
              'current_rate': now.rate,
              'current_not_employed': now.hits,
              'current_answered': now.total,
              'registered_roster': group.registered,
              'ci_low': interval.low,
              'ci_high': interval.high,
              'ci_level': 0.95,
              'certainty': DssMetrics.certainty(
                rule.operator,
                rule.threshold,
                interval,
              ),
              if (group.level != DssCohortLevel.batch) ...{
                'rolled_up': true,
                'small_groups': small,
                'min_responses_required': rule.minN,
              },
            },
            body:
                'Not employed rose from ${_pct0(before.rate)} '
                '(${before.total} answers in "${prev.survey.title}") to '
                '${_pct0(now.rate)} (${now.total} answers in '
                '"${curr.survey.title}") for ${group.label}: '
                '${formatPoints(change)}.',
          ),
        );
        upserts++;
      }
    }
    return upserts;
  }

  /// Smaller groups that were combined for a rolled-up trend flag, sized by
  /// the smaller of the two waves (groups missing from a wave are omitted).
  static Map<String, int> _smallComparable(
    _WaveData curr,
    _WaveData prev,
    _Group group,
    int minN,
  ) {
    final out = <String, int>{};
    if (group.level == DssCohortLevel.course) {
      final cur = curr.sizes[group.course] ?? const {};
      final old = prev.sizes[group.course] ?? const {};
      for (final b in cur.keys.where(old.containsKey)) {
        final n = cur[b]! < old[b]! ? cur[b]! : old[b]!;
        if (n < minN) out[b] = n;
      }
    } else {
      for (final c in curr.sizes.keys.where(prev.sizes.containsKey)) {
        int total(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);
        final a = total(curr.sizes[c]!);
        final b = total(prev.sizes[c]!);
        final n = a < b ? a : b;
        if (n < minN) out[c] = n;
      }
    }
    return out;
  }

  /// Chronological order of waves (first publish, then open date, then
  /// creation), matching the CHED wave comparison report.
  static DateTime waveDate(Survey s) => s.publishedAt ?? s.openAt ?? s.createdAt;

  /// Recompute the metric for an existing flag's cohort (impact follow-up).
  Future<DssMetricSnapshot> recomputeMetricForFlag(DssFlag flag) async {
    final rules = await _repo.listRules();
    final rule = rules.cast<DssRule?>().firstWhere(
      (r) => r?.ruleId == flag.ruleId,
      orElse: () => null,
    );
    if (rule == null) {
      return const DssMetricSnapshot(sampleN: 0);
    }

    final members = await _members.getAllMembers();
    final active = members.where((m) => !m.isDeactivated).toList();
    final byAuth = _byAuth(active);
    final roster = _Roster.from(active);
    final responses = await _surveys.getSurveyResponses(flag.surveyId);

    final sample = responses
        .where((r) => inFlagGroup(flag, byAuth[r.userId]))
        .toList();
    final answers = sample.map((r) => r.answers).toList();
    final eligible = switch (flag.cohortLevel) {
      DssCohortLevel.institution => roster.total,
      DssCohortLevel.course => roster.course(flag.course).total,
      DssCohortLevel.batch =>
        roster.batch(flag.course, flag.batchYear)?.total ?? 0,
    };

    if (sample.isEmpty && flag.ruleId != 'DATA_QUALITY_LOW') {
      return DssMetricSnapshot(sampleN: 0, eligibleN: eligible);
    }

    double? value;
    switch (flag.ruleId) {
      case 'DATA_QUALITY_LOW':
        value = eligible == 0 ? 0 : sample.length / eligible;
      case 'UNEMPLOYMENT_HIGH':
        value = DssMetrics.unemployment(answers)?.rate;
      case 'RELATEDNESS_LOW':
        value = DssMetrics.relatedness(answers)?.mismatchShare.rate;
      case 'RELATEDNESS_HIGH':
        value = DssMetrics.relatedness(answers)?.alignedShare.rate;
      case 'UNDEREMPLOYMENT':
        value = DssMetrics.clerical(answers)?.rate;
      case 'TIME_TO_JOB_LONG':
        value = DssMetrics.longTimeToFirstJob(answers)?.rate;
      case 'SALARY_STAGNATION':
        final salaryByCourse = _salaryRanksByCourse(
          responses.map(
            (r) => (course: _courseOf(byAuth[r.userId]), responses: [r]),
          ),
        );
        value = DssMetrics.salaryGap(
          DssMetrics.salaryRanks(answers),
          DssMetrics.peerMedianExcluding(salaryByCourse, flag.course),
        );
      case 'UNEMPLOYMENT_TREND_UP':
        final previousId = flag.evidence['previous_survey_id']?.toString();
        if (previousId == null || previousId.isEmpty) break;
        final previous = await _surveys.getSurveyResponses(previousId);
        final before = DssMetrics.unemployment(
          previous
              .where((r) => inFlagGroup(flag, byAuth[r.userId]))
              .map((r) => r.answers),
        );
        final now = DssMetrics.unemployment(answers);
        if (now != null && before != null) value = now.rate - before.rate;
      default:
        value = null;
    }

    return DssMetricSnapshot(
      metricValue: value,
      sampleN: sample.length,
      eligibleN: eligible,
    );
  }

  /// Survey answers from respondents in [flag]'s group (same wave).
  Future<List<Map<String, dynamic>>> answersForFlag(DssFlag flag) async {
    final members = await _members.getAllMembers();
    final byAuth = _byAuth(members.where((m) => !m.isDeactivated).toList());
    final responses = await _surveys.getSurveyResponses(flag.surveyId);
    return responses
        .where((r) => inFlagGroup(flag, byAuth[r.userId]))
        .map((r) => r.answers)
        .toList();
  }

  /// Whether roster member [m] belongs to the group [flag] describes.
  static bool inFlagGroup(DssFlag flag, AlumniMember? m) =>
      switch (flag.cohortLevel) {
        DssCohortLevel.institution => m != null,
        DssCohortLevel.course => m != null && _courseOf(m) == flag.course,
        DssCohortLevel.batch =>
          m != null &&
              _courseOf(m) == flag.course &&
              _batchOf(m) == flag.batchYear,
      };

  static Map<String, AlumniMember> _byAuth(List<AlumniMember> active) => {
    for (final m in active)
      if (m.authUid != null && m.authUid!.trim().isNotEmpty)
        m.authUid!.trim(): m,
  };

  static Map<String, List<int>> _salaryRanksByCourse(
    Iterable<({String course, List<SurveyResponse> responses})> groups,
  ) {
    final out = <String, List<int>>{};
    for (final g in groups) {
      final ranks = DssMetrics.salaryRanks(g.responses.map((r) => r.answers));
      if (ranks.isEmpty) continue;
      out.putIfAbsent(g.course, () => []).addAll(ranks);
    }
    return out;
  }

  static String _courseOf(AlumniMember? m) {
    final c = m?.course.trim() ?? '';
    return c.isEmpty ? 'Unknown' : c;
  }

  static String _batchOf(AlumniMember? m) {
    final b = m?.batchYear.trim() ?? '';
    return b.isEmpty ? 'Unknown' : b;
  }

  static String _pct1(double rate) => '${(rate * 100).toStringAsFixed(1)}%';

  static String _pct0(double rate) => '${(rate * 100).toStringAsFixed(0)}%';

  int _minNForOutcomes(Map<String, DssRule> enabled) {
    var min = 20;
    for (final r in enabled.values) {
      if (r.category == DssRuleCategory.outcome && r.minN < min) {
        min = r.minN;
      }
    }
    return min;
  }

  Map<String, dynamic> _flagRow({
    required DssRule rule,
    required _Group group,
    required Survey survey,
    required double metricValue,
    required DssConfidence confidence,
    required Map<String, dynamic> evidence,
    required String body,
    String? titleOverride,
    String? recommendedActionOverride,
  }) {
    final title = titleOverride ?? '${rule.name}: ${group.label}';
    return {
      'rule_id': rule.ruleId,
      'cohort_level': group.level.dbValue,
      'course': group.course,
      'batch_year': group.batchYear,
      'survey_id': survey.id,
      'survey_title': survey.title,
      'metric_value': metricValue,
      'threshold_snapshot': rule.threshold,
      'sample_n': group.responses.length,
      'eligible_n': group.eligible,
      'confidence': confidence.dbValue,
      'title': title,
      'body': body,
      'recommended_action':
          recommendedActionOverride ?? rule.recommendedAction,
      'evidence': evidence,
      'baseline_value': metricValue,
    };
  }
}

class DssEvaluationResult {
  const DssEvaluationResult({
    required this.cohortsEvaluated,
    required this.flagsRaisedOrUpdated,
    required this.message,
    this.chedWaves = 0,
    this.wavesWithResponses = 0,
    this.responsesScanned = 0,
  });

  final int cohortsEvaluated;
  final int flagsRaisedOrUpdated;
  final String message;
  final int chedWaves;
  final int wavesWithResponses;
  final int responsesScanned;
}

class _CohortBucket {
  _CohortBucket({required this.course, required this.batchYear});

  final String course;
  final String batchYear;
  final List<SurveyResponse> responses = [];
}

/// One wave's responses, kept for comparing consecutive waves.
class _WaveData {
  _WaveData({
    required this.survey,
    required this.responses,
    required this.buckets,
  });

  final Survey survey;
  final List<SurveyResponse> responses;

  /// `course|batch` → responses.
  final Map<String, _CohortBucket> buckets;

  /// course → batch → respondent count.
  late final Map<String, Map<String, int>> sizes = () {
    final out = <String, Map<String, int>>{};
    for (final b in buckets.values) {
      out.putIfAbsent(b.course, () => {})[b.batchYear] = b.responses.length;
    }
    return out;
  }();

  List<SurveyResponse> forCourse(String course) => [
    for (final b in buckets.values)
      if (b.course == course) ...b.responses,
  ];
}

/// One group evaluated in a wave (course × batch, whole course or
/// institution).
class _Group {
  const _Group({
    required this.level,
    required this.course,
    required this.batchYear,
    required this.label,
    required this.responses,
    required this.eligible,
    required this.registered,
  });

  final DssCohortLevel level;
  final String course;
  final String batchYear;
  final String label;
  final List<SurveyResponse> responses;

  /// Whole active roster for the group (registered or not).
  final int eligible;
  final int registered;

  double get responseRate =>
      eligible <= 0 ? 0.0 : responses.length / eligible;
}

class _WaveContext {
  const _WaveContext({
    required this.survey,
    required this.enabled,
    required this.sizes,
    required this.salaryByCourse,
    required this.minNForOutcomes,
  });

  final Survey survey;
  final Map<String, DssRule> enabled;
  final Map<String, Map<String, int>> sizes;
  final Map<String, List<int>> salaryByCourse;
  final int minNForOutcomes;
}

typedef _Counts = ({int total, int registered});

/// Active roster counts by course × batch, course and institution. These
/// are the response-rate denominators.
class _Roster {
  _Roster._(this._byBatch, this._byCourse, this.total, this.registered);

  factory _Roster.from(List<AlumniMember> active) {
    final byBatch = <String, _Counts>{};
    final byCourse = <String, _Counts>{};
    var total = 0;
    var registered = 0;
    _Counts add(_Counts? prev, bool reg) => (
      total: (prev?.total ?? 0) + 1,
      registered: (prev?.registered ?? 0) + (reg ? 1 : 0),
    );
    for (final m in active) {
      final course = DssEvaluationService._courseOf(m);
      final batch = DssEvaluationService._batchOf(m);
      final reg =
          m.isRegisteredUser || (m.authUid?.trim().isNotEmpty ?? false);
      final key = DssRollup.batchKey(course, batch);
      byBatch[key] = add(byBatch[key], reg);
      byCourse[course] = add(byCourse[course], reg);
      total++;
      if (reg) registered++;
    }
    return _Roster._(byBatch, byCourse, total, registered);
  }

  final Map<String, _Counts> _byBatch;
  final Map<String, _Counts> _byCourse;
  final int total;
  final int registered;

  _Counts? batch(String course, String batch) =>
      _byBatch[DssRollup.batchKey(course, batch)];

  _Counts course(String course) =>
      _byCourse[course] ?? (total: 0, registered: 0);
}
