import 'dart:math' as math;

import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_rollup.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// One CHED GTS wave and its submitted responses (one per alumnus).
class DssWaveInput {
  const DssWaveInput({required this.survey, required this.responses});

  final Survey survey;
  final List<SurveyResponse> responses;
}

/// Roster size of one course × batch saved while a wave was open
/// (`dss_wave_cohort_snapshots`), so later response rates use the roster of
/// that time instead of today's.
class DssCohortSnapshot {
  const DssCohortSnapshot({
    required this.surveyId,
    required this.course,
    required this.batchYear,
    required this.rosterCount,
    required this.registeredCount,
    required this.capturedAt,
  });

  factory DssCohortSnapshot.fromSupabaseRow(Map<String, dynamic> row) =>
      DssCohortSnapshot(
        surveyId: (row['survey_id'] ?? '').toString(),
        course: (row['course'] ?? '').toString(),
        batchYear: (row['batch_year'] ?? '').toString(),
        rosterCount: (row['roster_count'] as num?)?.toInt() ?? 0,
        registeredCount: (row['registered_count'] as num?)?.toInt() ?? 0,
        capturedAt:
            DateTime.tryParse(row['captured_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  final String surveyId;
  final String course;
  final String batchYear;
  final int rosterCount;
  final int registeredCount;
  final DateTime capturedAt;

  Map<String, dynamic> toSupabaseRow() => {
    'survey_id': surveyId,
    'course': course,
    'batch_year': batchYear,
    'roster_count': rosterCount,
    'registered_count': registeredCount,
    'captured_at': capturedAt.toUtc().toIso8601String(),
  };
}

typedef DssRosterCounts = ({int total, int registered});

/// Active roster counts by course × batch ("Batch not recorded" when
/// missing), summed per course and for the institution. These are the
/// response-rate denominators. Records without a course are left out, the
/// same as their responses.
class DssRoster {
  DssRoster._(this._byBatch) {
    for (final e in _byBatch.entries) {
      final course = e.key.split('|').first;
      final prev = _byCourse[course];
      _byCourse[course] = (
        total: (prev?.total ?? 0) + e.value.total,
        registered: (prev?.registered ?? 0) + e.value.registered,
      );
      total += e.value.total;
      registered += e.value.registered;
    }
  }

  factory DssRoster.fromMembers(Iterable<AlumniMember> active) {
    final byBatch = <String, DssRosterCounts>{};
    for (final m in active) {
      final group = DssPolicy.groupOf(m);
      if (group == null) continue;
      final key = DssRollup.batchKey(
        group.course,
        DssPolicy.batchLabel(group.batch),
      );
      final reg = m.isRegisteredUser || (m.authUid?.trim().isNotEmpty ?? false);
      final prev = byBatch[key];
      byBatch[key] = (
        total: (prev?.total ?? 0) + 1,
        registered: (prev?.registered ?? 0) + (reg ? 1 : 0),
      );
    }
    return DssRoster._(byBatch);
  }

  factory DssRoster.fromSnapshots(Iterable<DssCohortSnapshot> rows) =>
      DssRoster._({
        for (final r in rows)
          DssRollup.batchKey(r.course, r.batchYear): (
            total: r.rosterCount,
            registered: r.registeredCount,
          ),
      });

  final Map<String, DssRosterCounts> _byBatch;
  final _byCourse = <String, DssRosterCounts>{};
  int total = 0;
  int registered = 0;

  DssRosterCounts? batch(String course, String batch) =>
      _byBatch[DssRollup.batchKey(course, batch)];

  DssRosterCounts course(String course) =>
      _byCourse[course] ?? (total: 0, registered: 0);

  /// Every course × batch on the roster.
  Iterable<({String course, String batch, DssRosterCounts counts})>
  get groups => _byBatch.entries.map((e) {
    final i = e.key.indexOf('|');
    return (
      course: e.key.substring(0, i),
      batch: e.key.substring(i + 1),
      counts: e.value,
    );
  });

  List<DssCohortSnapshot> snapshot(String surveyId, DateTime at) => [
    for (final g in groups)
      DssCohortSnapshot(
        surveyId: surveyId,
        course: g.course,
        batchYear: g.batch,
        rosterCount: g.counts.total,
        registeredCount: g.counts.registered,
        capturedAt: at,
      ),
  ];
}

/// A group measure skipped because fewer than 5 alumni answered it.
typedef DssSuppressedMeasure = ({
  String findingKey,
  String surveyId,
  int validAnswers,
});

/// What one evaluation run produced. Nothing is written yet.
class DssEvaluation {
  const DssEvaluation({
    required this.flagRows,
    this.checked = const {},
    this.suppressed = const [],
    required this.snapshots,
    required this.cohortsEvaluated,
    required this.rolledUpGroups,
    required this.chedWaves,
    required this.wavesWithResponses,
    required this.responsesScanned,
    required this.watch,
    required this.notEnoughData,
    required this.unclassified,
  });

  /// `dss_flags` rows to insert or refresh (findings, Watch items and
  /// data-quality checks).
  final List<Map<String, dynamic>> flagRows;

  /// Finding key → waves where the finding was checked with at least Watch
  /// evidence (or, for data quality, where the group was checked), whether
  /// or not it crossed the threshold.
  final Map<String, Set<String>> checked;

  /// Measures left out for having fewer than 5 answers.
  final List<DssSuppressedMeasure> suppressed;

  /// Roster counts to save for waves that are still open.
  final List<DssCohortSnapshot> snapshots;
  final int cohortsEvaluated;
  final int rolledUpGroups;
  final int chedWaves;
  final int wavesWithResponses;
  final int responsesScanned;

  /// Rows in [flagRows] with 5–9 valid answers (Watch, not findings).
  final int watch;

  /// Group measures skipped because fewer than 5 alumni answered.
  final int notEnoughData;

  /// Responses left out of every group (no roster record or no course).
  final int unclassified;

  String get message => describe(
    cohortsEvaluated: cohortsEvaluated,
    rolledUpGroups: rolledUpGroups,
    chedWaves: chedWaves,
    wavesWithResponses: wavesWithResponses,
    responsesScanned: responsesScanned,
    flagRows: flagRows.length,
    watch: watch,
    notEnoughData: notEnoughData,
    unclassified: unclassified,
  );

  /// The run summary shown after Refresh, from counts alone (the server
  /// evaluation returns the same counts).
  static String describe({
    required int cohortsEvaluated,
    required int rolledUpGroups,
    required int chedWaves,
    required int wavesWithResponses,
    required int responsesScanned,
    required int flagRows,
    required int watch,
    required int notEnoughData,
    required int unclassified,
  }) {
    final b = StringBuffer(
      'Evaluated $cohortsEvaluated group(s) across $wavesWithResponses of '
      '$chedWaves CHED wave(s) ($responsesScanned submitted response(s)). ',
    );
    if (rolledUpGroups > 0) {
      b.write(
        'Small groups were combined into $rolledUpGroups course or '
        'institution-wide group(s). ',
      );
    }
    b.write('${flagRows - watch} group result(s) met a rule');
    if (watch > 0) {
      b.write(', plus $watch for Watch (too few answers for a finding)');
    }
    b.write('.');
    if (notEnoughData > 0) {
      b.write(
        ' $notEnoughData group measure(s) had fewer than '
        '${DssPolicy.notEnoughBelow} answers and were not judged.',
      );
    }
    if (unclassified > 0) {
      b.write(
        ' $unclassified response(s) from alumni without a roster course '
        'were left out of group results.',
      );
    }
    if (flagRows == 0) b.write(' No group met an enabled rule.');
    if (chedWaves == 0) {
      b.write(' No published/closed CHED GTS surveys were found.');
    }
    return b.toString();
  }
}

/// Deterministic DSS evaluation over CHED GTS responses × roster groups,
/// applying the Part 3 sample-size and group-mapping policies. Pure: the
/// caller loads the data and saves [DssEvaluation.flagRows].
class DssEvaluator {
  DssEvaluator({
    required List<DssRule> rules,
    required List<AlumniMember> roster,
    required this.now,
    List<DssCohortSnapshot> snapshots = const [],
  }) : _enabled = {for (final r in rules.where((r) => r.enabled)) r.ruleId: r},
       _byAuth = {
         for (final m in roster)
           if (m.authUid != null && m.authUid!.trim().isNotEmpty)
             m.authUid!.trim(): m,
       },
       _roster = DssRoster.fromMembers(roster),
       _snapshots = _bySurvey(snapshots);

  final DateTime now;
  final Map<String, DssRule> _enabled;
  final Map<String, AlumniMember> _byAuth;
  final DssRoster _roster;
  final Map<String, List<DssCohortSnapshot>> _snapshots;

  final _rows = <Map<String, dynamic>>[];
  final _checked = <String, Set<String>>{};
  final _suppressed = <DssSuppressedMeasure>[];
  final _toSnapshot = <DssCohortSnapshot>[];
  var _cohorts = 0;
  var _rolledUp = 0;
  var _watch = 0;
  var _notEnough = 0;
  var _unclassified = 0;

  /// Chronological order of waves (first publish, then open date, then
  /// creation), matching the CHED wave comparison report.
  static DateTime waveDate(Survey s) =>
      s.publishedAt ?? s.openAt ?? s.createdAt;

  static Map<String, List<DssCohortSnapshot>> _bySurvey(
    List<DssCohortSnapshot> rows,
  ) {
    final out = <String, List<DssCohortSnapshot>>{};
    for (final r in rows) {
      out.putIfAbsent(r.surveyId, () => []).add(r);
    }
    return out;
  }

  DssEvaluation run(List<DssWaveInput> waves) {
    _rows.clear();
    _checked.clear();
    _suppressed.clear();
    _toSnapshot.clear();
    _cohorts = _rolledUp = _watch = _notEnough = _unclassified = 0;
    final newest = waves.isEmpty
        ? null
        : waves.reduce(
            (a, b) => waveDate(b.survey).isAfter(waveDate(a.survey)) ? b : a,
          );
    final withResponses = <_WaveData>[];
    var responsesScanned = 0;

    for (final wave in waves) {
      final isNewest = identical(wave, newest);
      if (wave.responses.isEmpty && !isNewest) continue;
      final data = _waveData(wave);
      if (wave.responses.isNotEmpty) {
        withResponses.add(data);
        responsesScanned += wave.responses.length;
      }
      if (_enabled.isEmpty) continue;
      _evaluateWave(data, isNewest: isNewest);
    }

    final trendRule = _enabled['UNEMPLOYMENT_TREND_UP'];
    if (trendRule != null && withResponses.length > 1) {
      _raiseTrends(trendRule, withResponses);
    }

    return DssEvaluation(
      flagRows: List.unmodifiable(_rows),
      checked: {
        for (final e in _checked.entries) e.key: {...e.value},
      },
      suppressed: List.unmodifiable(_suppressed),
      snapshots: List.unmodifiable(_toSnapshot),
      cohortsEvaluated: _cohorts,
      rolledUpGroups: _rolledUp,
      chedWaves: waves.length,
      wavesWithResponses: withResponses.length,
      responsesScanned: responsesScanned,
      watch: _watch,
      notEnoughData: _notEnough,
      unclassified: _unclassified,
    );
  }

  /// Whether [s] still accepts responses at [now] (its roster is today's).
  static bool acceptsResponses(Survey s, DateTime now) =>
      !s.archived &&
      s.status == SurveyStatus.published &&
      (s.openAt == null || !now.isBefore(s.openAt!)) &&
      (s.closeAt == null || !now.isAfter(s.closeAt!));

  _WaveData _waveData(DssWaveInput wave) {
    final survey = wave.survey;
    final saved = _snapshots[survey.id];
    final DssRoster roster;
    final String basis;
    if (acceptsResponses(survey, now)) {
      roster = _roster;
      basis = 'open_wave';
      _toSnapshot.addAll(_roster.snapshot(survey.id, now));
    } else if (saved != null && saved.isNotEmpty) {
      roster = DssRoster.fromSnapshots(saved);
      basis = 'snapshot';
    } else {
      roster = _roster;
      basis = 'current';
    }

    final buckets = <String, _Bucket>{};
    for (final r in wave.responses) {
      final group = DssPolicy.groupOf(_byAuth[r.userId]);
      if (group == null) {
        _unclassified++;
        continue;
      }
      final batch = DssPolicy.batchLabel(group.batch);
      buckets
          .putIfAbsent(
            DssRollup.batchKey(group.course, batch),
            () => _Bucket(course: group.course, batch: batch),
          )
          .responses
          .add(r);
    }
    return _WaveData(
      survey: survey,
      buckets: buckets,
      roster: roster,
      rosterBasis: basis,
    );
  }

  void _evaluateWave(_WaveData w, {required bool isNewest}) {
    final batchGroups = [
      for (final b in w.buckets.values)
        if (b.batch != DssPolicy.batchNotRecorded)
          w.batchGroup(b.course, b.batch, b.responses),
    ];

    final quality = [...batchGroups];
    if (isNewest) {
      final date = waveDate(w.survey);
      for (final g in w.roster.groups) {
        if (g.batch == DssPolicy.batchNotRecorded || g.counts.total < 1) {
          continue;
        }
        if (w.buckets.containsKey(DssRollup.batchKey(g.course, g.batch))) {
          continue;
        }
        if (!DssPolicy.expectedToAnswer(w.survey, date, g.course, g.batch)) {
          continue;
        }
        quality.add(w.batchGroup(g.course, g.batch, const []));
      }
    }
    _cohorts += quality.length;
    for (final g in quality) {
      _raiseDataQuality(w, g);
    }

    final plans = <String, DssRollupPlan>{
      for (final r in _enabled.values)
        if (r.category == DssRuleCategory.outcome ||
            r.category == DssRuleCategory.opportunity)
          r.ruleId: DssRollup.plan(w.sizes, DssPolicy.ruleMin(r)),
    };
    final groups = <_Group>[
      ...batchGroups,
      for (final course in {for (final p in plans.values) ...p.courses})
        w.courseGroup(course),
      if (plans.values.any((p) => p.institution)) w.institutionGroup(),
    ];
    _rolledUp += groups.where((g) => g.level != DssCohortLevel.batch).length;

    final salaryByCourse = _salaryRanksByCourse(w.buckets.values);
    for (final group in groups) {
      bool allowed(String ruleId) {
        final plan = plans[ruleId];
        if (plan == null) return false;
        return switch (group.level) {
          DssCohortLevel.batch => true,
          DssCohortLevel.course => plan.courses.contains(group.course),
          DssCohortLevel.institution =>
            plan.institution && ruleId != 'SALARY_STAGNATION',
        };
      }

      _raiseOutcomes(w, group, allowed, salaryByCourse);
    }
  }

  /// Response-rate / too-few-responses check, per course × batch only. Fires
  /// at any response count, including zero.
  void _raiseDataQuality(_WaveData w, _Group group) {
    final rule = _enabled['DATA_QUALITY_LOW'];
    if (rule == null) return;
    _markChecked(rule, group, w.survey);
    final minN = DssPolicy.ruleMin(rule);
    final sample = group.responses;
    final eligible = group.eligible;
    final responseRate = group.responseRate ?? 0.0;
    final crossesRate = DssMetrics.crosses(
      rule.operator,
      responseRate,
      rule.threshold,
    );
    final crossesSparse = sample.length < minN;
    if (!crossesRate && !crossesSparse) return;

    final survey = w.survey;
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
            '$minN responses needed before outcome findings '
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
    _rows.add(
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
          'roster_basis': group.rosterBasis,
          'reason': reason,
          if (crossesSparse) 'sparse_sample': true,
          'min_responses_required': minN,
        },
        body: body,
        titleOverride: title,
        recommendedActionOverride: action,
      ),
    );
  }

  /// Outcome and opportunity rules for one group; [allowed] says which
  /// rules the roll-up plan assigns to it.
  void _raiseOutcomes(
    _WaveData w,
    _Group group,
    bool Function(String ruleId) allowed,
    Map<String, List<int>> salaryByCourse,
  ) {
    final answers = group.responses.map((r) => r.answers).toList();
    final cohortText = group.label;

    void maybeRaise(
      String ruleId,
      double? metric,
      int validAnswers,
      Map<String, dynamic> evidence,
      String body, {
      DssProportion? share,
    }) {
      final rule = _enabled[ruleId];
      if (rule == null || metric == null || !allowed(ruleId)) return;
      final strength = DssPolicy.strength(validAnswers, minN: rule.minN);
      if (strength == DssEvidenceStrength.insufficient) {
        _suppress(rule, group, w.survey, validAnswers);
        return;
      }
      _markChecked(rule, group, w.survey);
      if (!DssMetrics.crosses(rule.operator, metric, rule.threshold)) return;
      final interval = share == null
          ? null
          : DssMetrics.wilson(share.hits, share.total);
      _rows.add(
        _flagRow(
          rule: rule,
          group: group,
          survey: w.survey,
          metricValue: metric,
          confidence: _confidence(strength, group),
          evidence: {
            ...evidence,
            ..._sampleEvidence(group, validAnswers, strength),
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
            ..._rollupEvidence(w, group, rule),
          },
          body: _watchPrefix(strength, body),
        ),
      );
      if (strength == DssEvidenceStrength.watch) _watch++;
    }

    final unemployment = DssMetrics.unemployment(answers);
    final reasons = DssMetrics.notEmployedBreakdown(answers);
    if (unemployment != null) {
      maybeRaise(
        'UNEMPLOYMENT_HIGH',
        unemployment.rate,
        unemployment.total,
        {
          'question': 'ched_16',
          'not_employed': unemployment.hits,
          'answered': unemployment.total,
          'breakdown': DssMetrics.employmentBreakdown(answers),
          'q17': reasons.toEvidence(),
        },
        '${_pct1(unemployment.rate)} of ${unemployment.total} '
            'respondents in $cohortText are not currently employed'
            '${unemployment.hits > 0 ? '; ${reasons.seeking} of them '
                      '${reasons.seeking == 1 ? 'is' : 'are'} looking for work' : ''}.',
        share: unemployment,
      );
    }

    final seeking = DssMetrics.seekingWork(answers);
    if (seeking != null) {
      maybeRaise(
        'SEEKING_WORK_HIGH',
        seeking.rate,
        seeking.total,
        {
          'questions': ['ched_16', 'ched_17'],
          'seeking': seeking.hits,
          'labour_force': seeking.total,
          'q17': reasons.toEvidence(),
        },
        '${_pct1(seeking.rate)} of ${seeking.total} respondents in '
            '$cohortText who are employed or looking for work are looking for '
            'work (no job opportunity or lack of work experience).',
        share: seeking,
      );
    }

    final relatedness = DssMetrics.relatedness(answers);
    if (relatedness != null) {
      final mismatch = relatedness.mismatchShare;
      final suggestions = relatedness.mismatchSuggestions;
      maybeRaise(
        'RELATEDNESS_LOW',
        mismatch.rate,
        mismatch.total,
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
      maybeRaise(
        'RELATEDNESS_HIGH',
        aligned.rate,
        aligned.total,
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
      maybeRaise(
        'UNDEREMPLOYMENT',
        clerical.rate,
        clerical.total,
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
      final others = DssMetrics.timeToJobOthers(answers);
      maybeRaise(
        'TIME_TO_JOB_LONG',
        longWait.rate,
        longWait.total,
        {
          'question': 'ched_29',
          'long_count': longWait.hits,
          'answered': longWait.total,
          'breakdown': DssMetrics.counts(DssMetrics.timeToJobAnswers(answers)),
          if (others > 0) 'others_excluded': others,
        },
        '${_pct1(longWait.rate)} of ${longWait.total} '
            'respondents took 1+ years to land a first job ($cohortText).',
        share: longWait,
      );
    }

    if (group.level != DssCohortLevel.institution) {
      final ranks = DssMetrics.salaryRanks(answers);
      final peerMedian = DssMetrics.peerMedianExcluding(
        salaryByCourse,
        group.course,
      );
      final gap = DssMetrics.salaryGap(ranks, peerMedian);
      if (gap != null) {
        maybeRaise(
          'SALARY_STAGNATION',
          gap,
          ranks.length,
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
  }

  /// UNEMPLOYMENT_TREND_UP: each wave against the wave before it, for the
  /// same groups (rolled up when a group is too small in either wave). The
  /// sample-size policy applies to the smaller of the two waves.
  void _raiseTrends(DssRule rule, List<_WaveData> waves) {
    final minN = DssPolicy.ruleMin(rule);
    final ordered = [...waves]
      ..sort((a, b) => waveDate(a.survey).compareTo(waveDate(b.survey)));

    for (var i = 1; i < ordered.length; i++) {
      final prev = ordered[i - 1];
      final curr = ordered[i];
      final plan = DssRollup.planChange(curr.sizes, prev.sizes, minN);

      final pairs = <({_Group group, List<SurveyResponse> previous})>[
        for (final e in curr.buckets.entries)
          if (e.value.batch != DssPolicy.batchNotRecorded &&
              prev.buckets.containsKey(e.key))
            (
              group: curr.batchGroup(
                e.value.course,
                e.value.batch,
                e.value.responses,
              ),
              previous: prev.buckets[e.key]!.responses,
            ),
        for (final course in plan.courses)
          (group: curr.courseGroup(course), previous: prev.forCourse(course)),
        if (plan.institution)
          (group: curr.institutionGroup(), previous: prev.classified),
      ];

      for (final pair in pairs) {
        final group = pair.group;
        final now = DssMetrics.unemployment(
          group.responses.map((r) => r.answers),
        );
        final before = DssMetrics.unemployment(
          pair.previous.map((r) => r.answers),
        );
        if (now == null || before == null) continue;
        final n = math.min(now.total, before.total);
        final strength = DssPolicy.strength(n, minN: rule.minN);
        if (strength == DssEvidenceStrength.insufficient) {
          _suppress(rule, group, curr.survey, n);
          continue;
        }
        _markChecked(rule, group, curr.survey);
        final change = now.rate - before.rate;
        if (!DssMetrics.crosses(rule.operator, change, rule.threshold)) {
          continue;
        }
        final interval = DssMetrics.changeInterval(now, before);
        final small = group.level == DssCohortLevel.batch
            ? const <String, int>{}
            : _smallComparable(curr, prev, group, minN);

        _rows.add(
          _flagRow(
            rule: rule,
            group: group,
            survey: curr.survey,
            metricValue: change,
            confidence: _confidence(strength, group),
            evidence: {
              'question': 'ched_16',
              'previous_survey_id': prev.survey.id,
              'previous_survey_title': prev.survey.title,
              'previous_rate': before.rate,
              'previous_not_employed': before.hits,
              'previous_answered': before.total,
              'current_rate': now.rate,
              'current_not_employed': now.hits,
              'current_answered': now.total,
              ..._sampleEvidence(group, n, strength),
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
                'min_responses_required': minN,
              },
            },
            body: _watchPrefix(
              strength,
              'Not employed rose from ${_pct0(before.rate)} '
              '(${before.total} answers in "${prev.survey.title}") to '
              '${_pct0(now.rate)} (${now.total} answers in '
              '"${curr.survey.title}") for ${group.label}: '
              '${formatPoints(change)}.',
            ),
          ),
        );
        if (strength == DssEvidenceStrength.watch) _watch++;
      }
    }
  }

  static String _keyOf(DssRule rule, _Group group) => dssFindingKey(
    rule.ruleId,
    group.level.dbValue,
    group.course,
    group.batchYear,
  );

  void _markChecked(DssRule rule, _Group group, Survey survey) =>
      _checked.putIfAbsent(_keyOf(rule, group), () => {}).add(survey.id);

  void _suppress(DssRule rule, _Group group, Survey survey, int answers) {
    _notEnough++;
    _suppressed.add((
      findingKey: _keyOf(rule, group),
      surveyId: survey.id,
      validAnswers: answers,
    ));
  }

  /// Sample facts every outcome, opportunity and trend row carries.
  static Map<String, dynamic> _sampleEvidence(
    _Group group,
    int validAnswers,
    DssEvidenceStrength strength,
  ) {
    final rate = group.responseRate;
    return {
      'source': 'ched_gts',
      'valid_answers': validAnswers,
      'not_answered': math.max(0, group.responses.length - validAnswers),
      'evidence_strength': strength.dbValue,
      'registered_roster': group.registered,
      'roster_basis': group.rosterBasis,
      if (rate != null) 'response_rate': rate,
      if (rate != null && rate < DssPolicy.lowCoverageBelow)
        'coverage_warning': true,
    };
  }

  /// Low unless the evidence is strong and the group's coverage is fine.
  static DssConfidence _confidence(DssEvidenceStrength strength, _Group group) {
    final rate = group.responseRate;
    final lowCoverage = rate != null && rate < DssPolicy.lowCoverageBelow;
    return strength == DssEvidenceStrength.strong && !lowCoverage
        ? DssConfidence.ok
        : DssConfidence.low;
  }

  static String _watchPrefix(DssEvidenceStrength strength, String body) =>
      strength == DssEvidenceStrength.watch
      ? 'Watch (small sample): $body'
      : body;

  /// Which smaller groups were combined, so the detail page can explain it.
  static Map<String, dynamic> _rollupEvidence(
    _WaveData w,
    _Group group,
    DssRule rule,
  ) {
    final minN = DssPolicy.ruleMin(rule);
    return switch (group.level) {
      DssCohortLevel.batch => const {},
      DssCohortLevel.course => {
        'rolled_up': true,
        'small_groups': DssRollup.smallBatches(w.sizes, group.course, minN),
        'min_responses_required': minN,
      },
      DssCohortLevel.institution => {
        'rolled_up': true,
        'small_groups': DssRollup.smallCourses(w.sizes, minN),
        'min_responses_required': minN,
      },
    };
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
        final n = math.min(cur[b]!, old[b]!);
        if (n < minN || b == DssPolicy.batchNotRecorded) out[b] = n;
      }
    } else {
      for (final c in curr.sizes.keys.where(prev.sizes.containsKey)) {
        int total(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);
        final n = math.min(total(curr.sizes[c]!), total(prev.sizes[c]!));
        if (n < minN) out[c] = n;
      }
    }
    return out;
  }

  static Map<String, List<int>> _salaryRanksByCourse(
    Iterable<_Bucket> buckets,
  ) {
    final out = <String, List<int>>{};
    for (final b in buckets) {
      final ranks = DssMetrics.salaryRanks(b.responses.map((r) => r.answers));
      if (ranks.isEmpty) continue;
      out.putIfAbsent(b.course, () => []).addAll(ranks);
    }
    return out;
  }

  static String _pct1(double rate) => '${(rate * 100).toStringAsFixed(1)}%';

  static String _pct0(double rate) => '${(rate * 100).toStringAsFixed(0)}%';

  static Map<String, dynamic> _flagRow({
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
      'title': titleOverride ?? '${rule.displayName}: ${group.label}',
      'body': body,
      'recommended_action': recommendedActionOverride ?? rule.recommendedAction,
      'evidence': evidence,
      'baseline_value': metricValue,
      'status':
          evidence['evidence_strength'] == DssEvidenceStrength.watch.dbValue
          ? DssFlagStatus.watch.dbValue
          : DssFlagStatus.open.dbValue,
    };
  }
}

class _Bucket {
  _Bucket({required this.course, required this.batch});

  final String course;

  /// The roster batch, or [DssPolicy.batchNotRecorded].
  final String batch;
  final List<SurveyResponse> responses = [];
}

/// One wave's classified responses and the roster used for its rates.
class _WaveData {
  _WaveData({
    required this.survey,
    required this.buckets,
    required this.roster,
    required this.rosterBasis,
  });

  final Survey survey;

  /// `course|batch` → responses (respondents with a roster course only).
  final Map<String, _Bucket> buckets;
  final DssRoster roster;

  /// `open_wave`, `snapshot` or `current` (closed wave, today's roster).
  final String rosterBasis;

  /// course → batch → respondent count.
  late final Map<String, Map<String, int>> sizes = () {
    final out = <String, Map<String, int>>{};
    for (final b in buckets.values) {
      out.putIfAbsent(b.course, () => {})[b.batch] = b.responses.length;
    }
    return out;
  }();

  List<SurveyResponse> get classified => [
    for (final b in buckets.values) ...b.responses,
  ];

  List<SurveyResponse> forCourse(String course) => [
    for (final b in buckets.values)
      if (b.course == course) ...b.responses,
  ];

  _Group batchGroup(
    String course,
    String batch,
    List<SurveyResponse> responses,
  ) {
    final counts = roster.batch(course, batch);
    return _Group(
      level: DssCohortLevel.batch,
      course: course,
      batchYear: batch,
      label: '$course · Batch $batch',
      responses: responses,
      eligible: counts?.total ?? responses.length,
      registered: counts?.registered ?? 0,
      rosterBasis: rosterBasis,
    );
  }

  _Group courseGroup(String course) {
    final counts = roster.course(course);
    return _Group(
      level: DssCohortLevel.course,
      course: course,
      batchYear: DssRollup.all,
      label: '$course (all batches)',
      responses: forCourse(course),
      eligible: counts.total,
      registered: counts.registered,
      rosterBasis: rosterBasis,
    );
  }

  _Group institutionGroup() => _Group(
    level: DssCohortLevel.institution,
    course: DssRollup.all,
    batchYear: DssRollup.all,
    label: 'the whole institution',
    responses: classified,
    eligible: roster.total,
    registered: roster.registered,
    rosterBasis: rosterBasis,
  );
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
    required this.rosterBasis,
  });

  final DssCohortLevel level;
  final String course;
  final String batchYear;
  final String label;
  final List<SurveyResponse> responses;

  /// Whole active roster for the group (registered or not).
  final int eligible;
  final int registered;
  final String rosterBasis;

  /// Null when the group has no roster count to divide by.
  double? get responseRate =>
      eligible <= 0 ? null : responses.length / eligible;
}
