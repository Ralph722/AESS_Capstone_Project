import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/application/dss_finding_sync.dart';
import 'package:alumni_system/features/admin/dss/application/dss_impact.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Loads CHED GTS responses and the roster, runs [DssEvaluator] and saves
/// what it raised.
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

  /// Refresh. Runs `dss_evaluate_all` on the server and falls back to the
  /// in-app engine when the function is missing or fails. A run already in
  /// progress, or a caller who is not an admin, is reported instead.
  Future<DssEvaluationResult> evaluateAll({
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Evaluating on the server…');
    try {
      final counts = await _repo.evaluateOnServer();
      if (counts != null) return DssEvaluationResult.fromServer(counts);
    } catch (e) {
      if (!fallsBackOn(e)) rethrow;
      debugPrint('DSS server evaluation failed, using the app engine: $e');
    }
    return evaluateInApp(onProgress: onProgress);
  }

  /// Whether a failed server run should be redone by the in-app engine.
  /// Not when another run holds the lock (both would write) or the caller
  /// lacks admin rights (the app engine would fail the same way).
  static bool fallsBackOn(Object error) =>
      !(error is PostgrestException &&
          (error.code == '55P03' || error.code == '42501'));

  /// The in-app engine: loads everything, runs [DssEvaluator] and saves
  /// through [DssRepository.syncFindings].
  Future<DssEvaluationResult> evaluateInApp({
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Loading rules…');
    final rules = await _repo.listRules();
    if (!rules.any((r) => r.enabled)) {
      return const DssEvaluationResult(
        cohortsEvaluated: 0,
        flagsRaisedOrUpdated: 0,
        message: 'No enabled DSS rules.',
      );
    }

    onProgress?.call('Loading roster…');
    final members = await _members.getAllMembers();
    final active = members.where((m) => !m.isDeactivated).toList();

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

    final waves = <DssWaveInput>[];
    for (final survey in chedWaves) {
      onProgress?.call('Reading ${survey.title}…');
      waves.add(
        DssWaveInput(
          survey: survey,
          responses: await _surveys.getSurveyResponses(survey.id),
        ),
      );
    }
    final snapshots = await _repo.listCohortSnapshots(
      chedWaves.map((s) => s.id).toList(),
    );

    onProgress?.call('Evaluating rules…');
    final evaluation = DssEvaluator(
      rules: rules,
      roster: active,
      now: DateTime.now(),
      snapshots: snapshots,
    ).run(waves);

    onProgress?.call('Saving insights…');
    final saved = await _repo.syncFindings(
      evaluation: evaluation,
      waveDates: {for (final s in chedWaves) s.id: waveDate(s)},
    );
    if (evaluation.snapshots.isNotEmpty) {
      await _repo.saveCohortSnapshots(evaluation.snapshots);
    }

    return DssEvaluationResult(
      cohortsEvaluated: evaluation.cohortsEvaluated,
      flagsRaisedOrUpdated: saved.legacy
          ? evaluation.flagRows.length
          : saved.raised + saved.updated,
      message: evaluation.message + saved.message,
      chedWaves: evaluation.chedWaves,
      wavesWithResponses: evaluation.wavesWithResponses,
      responsesScanned: evaluation.responsesScanned,
    );
  }

  /// Chronological order of waves (first publish, then open date, then
  /// creation), matching the CHED wave comparison report.
  static DateTime waveDate(Survey s) => DssEvaluator.waveDate(s);

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
    final roster = DssRoster.fromMembers(active);
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
      case 'SEEKING_WORK_HIGH':
        value = DssMetrics.seekingWork(answers)?.rate;
      case 'RELATEDNESS_LOW':
        value = DssMetrics.relatedness(answers)?.mismatchShare.rate;
      case 'RELATEDNESS_HIGH':
        value = DssMetrics.relatedness(answers)?.alignedShare.rate;
      case 'UNDEREMPLOYMENT':
        value = DssMetrics.clerical(answers)?.rate;
      case 'TIME_TO_JOB_LONG':
        value = DssMetrics.longTimeToFirstJob(answers)?.rate;
      case 'SALARY_STAGNATION':
        final salaryByCourse = <String, List<int>>{};
        for (final r in responses) {
          final group = DssPolicy.groupOf(byAuth[r.userId]);
          if (group == null) continue;
          salaryByCourse
              .putIfAbsent(group.course, () => [])
              .addAll(DssMetrics.salaryRanks([r.answers]));
        }
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

  /// Whether roster member [m] belongs to the group [flag] describes, under
  /// the group-mapping policy (no course: no group; no batch: course only).
  static bool inFlagGroup(DssFlag flag, AlumniMember? m) {
    final group = DssPolicy.groupOf(m);
    if (group == null) return false;
    return switch (flag.cohortLevel) {
      DssCohortLevel.institution => true,
      DssCohortLevel.course => group.course == flag.course,
      DssCohortLevel.batch =>
        group.course == flag.course &&
            group.batch != null &&
            group.batch == flag.batchYear,
    };
  }

  static Map<String, AlumniMember> _byAuth(List<AlumniMember> active) => {
    for (final m in active)
      if (m.authUid != null && m.authUid!.trim().isNotEmpty)
        m.authUid!.trim(): m,
  };
}

class DssEvaluationResult {
  const DssEvaluationResult({
    required this.cohortsEvaluated,
    required this.flagsRaisedOrUpdated,
    required this.message,
    this.chedWaves = 0,
    this.wavesWithResponses = 0,
    this.responsesScanned = 0,
    this.onServer = false,
  });

  /// From the counts `dss_evaluate_all` returns; the message reads the same
  /// as an in-app run.
  factory DssEvaluationResult.fromServer(Map<String, dynamic> counts) {
    int read(String k) => (counts[k] as num?)?.toInt() ?? 0;
    if (counts['no_rules'] == true) {
      return DssEvaluationResult(
        cohortsEvaluated: 0,
        flagsRaisedOrUpdated: 0,
        message: counts['message']?.toString() ?? 'No enabled DSS rules.',
        onServer: true,
      );
    }
    final saved = DssSyncSummary(
      raised: read('raised'),
      updated: read('updated'),
      superseded: read('superseded'),
      skippedNewerWave: read('skipped_newer_wave'),
      skippedClosed: read('skipped_closed'),
    );
    return DssEvaluationResult(
      cohortsEvaluated: read('cohorts_evaluated'),
      flagsRaisedOrUpdated: saved.raised + saved.updated,
      message:
          DssEvaluation.describe(
            cohortsEvaluated: read('cohorts_evaluated'),
            rolledUpGroups: read('rolled_up_groups'),
            chedWaves: read('ched_waves'),
            wavesWithResponses: read('waves_with_responses'),
            responsesScanned: read('responses_scanned'),
            flagRows: read('flag_rows'),
            watch: read('watch'),
            notEnoughData: read('not_enough_data'),
            unclassified: read('unclassified'),
          ) +
          saved.message,
      chedWaves: read('ched_waves'),
      wavesWithResponses: read('waves_with_responses'),
      responsesScanned: read('responses_scanned'),
      onServer: true,
    );
  }

  final int cohortsEvaluated;
  final int flagsRaisedOrUpdated;
  final String message;
  final int chedWaves;
  final int wavesWithResponses;
  final int responsesScanned;

  /// Whether the server evaluation (`dss_evaluate_all`) did the work.
  final bool onServer;
}
