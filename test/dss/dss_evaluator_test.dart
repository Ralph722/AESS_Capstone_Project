// DSS Phase 1 guardrails on the demo dataset (docs/demo-data-plan.md):
// sample-size policy and group mapping, without a database.
import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/demo_data/demo_dataset.dart';
import '../../tool/demo_data/demo_scenarios.dart';

DssRule _rule(
  String id,
  DssRuleCategory category,
  String operator,
  double threshold,
  int minN,
) => DssRule(
  ruleId: id,
  name: id,
  description: '',
  metricKey: '',
  operator: operator,
  threshold: threshold,
  minN: minN,
  enabled: true,
  severity: DssSeverity.warning,
  recommendedAction: '',
  playbook: const [],
  category: category,
  sortOrder: 0,
);

/// Seeded thresholds with the policy minimums ([outcomeMin] for outcome and
/// opportunity rules).
List<DssRule> _rules({int outcomeMin = 10}) => [
  _rule('DATA_QUALITY_LOW', DssRuleCategory.dataQuality, 'lt', 0.40, 1),
  _rule('UNEMPLOYMENT_HIGH', DssRuleCategory.outcome, 'gte', 0.25, outcomeMin),
  _rule('RELATEDNESS_LOW', DssRuleCategory.outcome, 'gte', 0.40, outcomeMin),
  _rule('UNDEREMPLOYMENT', DssRuleCategory.outcome, 'gte', 0.35, outcomeMin),
  _rule('TIME_TO_JOB_LONG', DssRuleCategory.outcome, 'gte', 0.40, outcomeMin),
  _rule('SALARY_STAGNATION', DssRuleCategory.outcome, 'gte', 1.0, outcomeMin),
  _rule(
    'RELATEDNESS_HIGH',
    DssRuleCategory.opportunity,
    'gte',
    0.75,
    outcomeMin,
  ),
  _rule('UNEMPLOYMENT_TREND_UP', DssRuleCategory.trend, 'gte', 0.10, 10),
];

void main() {
  final dataset = DemoDataset.build();
  final wave = {for (final w in demoWaves) w.key: w};

  final roster = [
    for (final m in dataset.rosterMembers)
      AlumniMember(
        id: m.key,
        fullName: m.fullName,
        course: m.course,
        studentId: m.studentId,
        batchYear: m.batch ?? '',
        authUid: m.hasAccount ? m.key : null,
        isRegisteredUser: m.hasAccount,
      ),
  ];

  List<DssWaveInput> waves() => [
    for (final w in demoWaves)
      DssWaveInput(
        survey: Survey(
          id: w.id,
          title: w.title,
          description: '',
          status: w.status == 'closed'
              ? SurveyStatus.closed
              : SurveyStatus.published,
          openAt: w.openAt,
          closeAt: w.closeAt,
          createdBy: 'admin',
          createdAt: w.openAt,
          publishedAt: w.openAt,
          kind: 'ched_gts_builtin',
        ),
        responses: [
          for (final r in dataset.responses.where((r) => r.waveKey == w.key))
            SurveyResponse(
              surveyId: w.id,
              userId: r.memberKey,
              answers: r.answers,
              status: SurveyResponseStatus.submitted,
              submittedAt: r.submittedAt,
              updatedAt: r.submittedAt,
            ),
        ],
      ),
  ];

  DssEvaluation run({
    int outcomeMin = 10,
    List<DssCohortSnapshot> snapshots = const [],
  }) => DssEvaluator(
    rules: _rules(outcomeMin: outcomeMin),
    roster: roster,
    now: demoSnapshot,
    snapshots: snapshots,
  ).run(waves());

  final result = run();

  Iterable<Map<String, dynamic>> rows({
    String? rule,
    String? course,
    String? batch,
    String? waveKey,
    DssCohortLevel? level,
  }) => result.flagRows.where(
    (r) =>
        (rule == null || r['rule_id'] == rule) &&
        (course == null || r['course'] == course) &&
        (batch == null || r['batch_year'] == batch) &&
        (waveKey == null || r['survey_id'] == wave[waveKey]!.id) &&
        (level == null || r['cohort_level'] == level.dbValue),
  );

  String strengthOf(Map<String, dynamic> row) =>
      (row['evidence'] as Map)['evidence_strength'] as String;

  bool isOutcome(Map<String, dynamic> row) =>
      row['rule_id'] != 'DATA_QUALITY_LOW';

  test('BTLED-IA 2024 (7 answers) is Watch, never a finding', () {
    final ia = rows(
      course: 'BTLED-IA',
      batch: '2024',
      level: DssCohortLevel.batch,
    ).where(isOutcome).toList();
    expect(ia.map((r) => r['rule_id']), contains('UNEMPLOYMENT_HIGH'));
    for (final r in ia) {
      expect(strengthOf(r), 'watch');
      expect(r['confidence'], 'low');
      expect(r['body'] as String, startsWith('Watch (small sample): '));
    }
  });

  test('BFPT 2022 (4) and BFPT 2023 (1) raise no outcome rows', () {
    for (final batch in ['2022', '2023']) {
      expect(
        rows(
          course: 'BFPT',
          batch: batch,
          level: DssCohortLevel.batch,
        ).where(isOutcome),
        isEmpty,
      );
    }
    expect(result.notEnoughData, greaterThan(0));
  });

  test('BFPT 2024 with zero responses gets a data-quality check', () {
    final dq = rows(
      rule: 'DATA_QUALITY_LOW',
      course: 'BFPT',
      batch: '2024',
    ).toList();
    expect(dq, hasLength(1), reason: 'newest wave only');
    expect(dq.single['survey_id'], wave['w2026']!.id);
    expect(dq.single['sample_n'], 0);
    expect(dq.single['eligible_n'], 15);
  });

  test('BTLED-ICT 2024 has no Q29 finding from 3 valid answers', () {
    expect(
      rows(rule: 'TIME_TO_JOB_LONG', course: 'BTLED-ICT', batch: '2024'),
      isEmpty,
    );
    final unemployment = rows(
      rule: 'UNEMPLOYMENT_HIGH',
      course: 'BTLED-ICT',
      batch: '2024',
    ).single;
    expect(strengthOf(unemployment), 'limited');
    expect((unemployment['evidence'] as Map)['valid_answers'], 20);
  });

  test('BTLED-HE 2024: Q29 "Others" leaves 9 valid answers (Watch)', () {
    final q29 = rows(
      rule: 'TIME_TO_JOB_LONG',
      course: 'BTLED-HE',
      batch: '2024',
      waveKey: 'w2025',
    ).single;
    final evidence = q29['evidence'] as Map;
    expect(evidence['valid_answers'], 9);
    expect(evidence['others_excluded'], 1);
    expect(strengthOf(q29), 'watch');

    final mismatch = rows(
      rule: 'RELATEDNESS_LOW',
      course: 'BTLED-HE',
      batch: '2024',
      waveKey: 'w2025',
    ).single;
    expect(strengthOf(mismatch), 'limited');
  });

  test('a stricter rule minimum of 20 turns 12 answers into Watch', () {
    final strict = run(outcomeMin: 20);
    final mismatch = strict.flagRows.singleWhere(
      (r) =>
          r['rule_id'] == 'RELATEDNESS_LOW' &&
          r['course'] == 'BTLED-HE' &&
          r['batch_year'] == '2024' &&
          r['survey_id'] == wave['w2025']!.id,
    );
    expect(strengthOf(mismatch), 'watch');
  });

  test('batch not recorded never forms a batch group', () {
    for (final r in result.flagRows) {
      if (r['cohort_level'] != DssCohortLevel.batch.dbValue) continue;
      expect(r['batch_year'], isNot('Batch not recorded'));
      expect((r['batch_year'] as String).trim(), isNotEmpty);
    }
  });

  test('off-roster respondents are left out of every group', () {
    expect(result.unclassified, 3);
    final rosterRespondents = dataset.responses
        .where((r) => r.waveKey == 'w2025' && dataset.isHosted(r.memberKey))
        .length;
    for (final r in rows(waveKey: 'w2025', level: DssCohortLevel.institution)) {
      expect(r['sample_n'], lessThanOrEqualTo(rosterRespondents));
    }
    expect(result.message, contains('3 response(s) from alumni without'));
  });

  test('response rates: open wave queues snapshots, closed waves say which '
      'roster they used', () {
    expect(result.snapshots, isNotEmpty);
    expect(result.snapshots.map((s) => s.surveyId).toSet(), {
      wave['w2026']!.id,
    });
    expect(
      result.snapshots.any((s) => s.batchYear == 'Batch not recorded'),
      isTrue,
    );
    final w2026 = rows(waveKey: 'w2026').first;
    expect((w2026['evidence'] as Map)['roster_basis'], 'open_wave');
    final w2025 = rows(waveKey: 'w2025').first;
    expect((w2025['evidence'] as Map)['roster_basis'], 'current');
  });

  test('saved snapshots are used for closed waves', () {
    final saved = run(
      snapshots: [
        DssCohortSnapshot(
          surveyId: wave['w2025']!.id,
          course: 'BTLED-IA',
          batchYear: '2024',
          rosterCount: 70,
          registeredCount: 10,
          capturedAt: DateTime.utc(2025, 8, 1),
        ),
      ],
    );
    final dq = saved.flagRows.singleWhere(
      (r) =>
          r['rule_id'] == 'DATA_QUALITY_LOW' &&
          r['course'] == 'BTLED-IA' &&
          r['survey_id'] == wave['w2025']!.id,
    );
    expect(dq['eligible_n'], 70);
    expect((dq['evidence'] as Map)['roster_basis'], 'snapshot');
  });

  test('low coverage is flagged on outcome evidence', () {
    final bsit2024 = rows(
      course: 'BSIT',
      batch: '2024',
      waveKey: 'w2025',
    ).where(isOutcome).toList();
    expect(bsit2024, isNotEmpty);
    for (final r in bsit2024) {
      expect((r['evidence'] as Map)['coverage_warning'], isTrue);
      expect(r['confidence'], 'low');
    }
  });

  test('evidence strength is never a top-level row key', () {
    for (final r in result.flagRows) {
      expect(r.containsKey('evidence_strength'), isFalse);
    }
  });

  test('SEEKING_WORK_HIGH is off unless the rule is enabled', () {
    expect(rows(rule: 'SEEKING_WORK_HIGH'), isEmpty);
  });

  test('SEEKING_WORK_HIGH: BTLED-ICT 2024 counts only the labour force', () {
    final seeking = DssEvaluator(
      rules: [
        ..._rules(),
        _rule('SEEKING_WORK_HIGH', DssRuleCategory.outcome, 'gte', 0.15, 10),
      ],
      roster: roster,
      now: demoSnapshot,
    ).run(waves());
    final row = seeking.flagRows.singleWhere(
      (r) =>
          r['rule_id'] == 'SEEKING_WORK_HIGH' &&
          r['course'] == 'BTLED-ICT' &&
          r['batch_year'] == '2024',
    );
    final evidence = row['evidence'] as Map;
    expect(evidence['seeking'], 13);
    expect(evidence['labour_force'], 16);
    expect(evidence['valid_answers'], 16);
    expect(row['metric_value'], closeTo(13 / 16, 1e-9));
    final q17 = evidence['q17'] as Map;
    expect(q17['seeking'], 13);
    expect(q17['not_seeking'], 4);

    final unemployment = seeking.flagRows.singleWhere(
      (r) =>
          r['rule_id'] == 'UNEMPLOYMENT_HIGH' &&
          r['course'] == 'BTLED-ICT' &&
          r['batch_year'] == '2024',
    );
    expect((unemployment['evidence'] as Map)['valid_answers'], 20);
    expect(unemployment['title'], startsWith('Not currently employed: '));
    expect(
      unemployment['body'] as String,
      contains('13 of them are looking for work'),
    );
  });

  test('running twice gives the same result', () {
    final evaluator = DssEvaluator(
      rules: _rules(),
      roster: roster,
      now: demoSnapshot,
    );
    final a = evaluator.run(waves());
    final b = evaluator.run(waves());
    expect(b.flagRows.length, a.flagRows.length);
    expect(b.snapshots.length, a.snapshots.length);
    expect(b.unclassified, a.unclassified);
    expect(b.checked, a.checked);
    expect(b.suppressed.length, a.suppressed.length);
  });

  group('finding identity (Phase 4)', () {
    String keyOf(Map<String, dynamic> r) => dssFindingKey(
      r['rule_id'] as String,
      r['cohort_level'] as String,
      r['course'] as String,
      r['batch_year'] as String,
    );

    test('Watch rows carry status watch; all others open', () {
      for (final r in result.flagRows) {
        final watch =
            isOutcome(r) && strengthOf(r) == DssEvidenceStrength.watch.dbValue;
        expect(r['status'], watch ? 'watch' : 'open', reason: keyOf(r));
      }
      expect(result.flagRows.where((r) => r['status'] == 'watch'), isNotEmpty);
    });

    test('every raised row is recorded as checked in its wave', () {
      for (final r in result.flagRows) {
        expect(result.checked[keyOf(r)], contains(r['survey_id']));
      }
    });

    test('BTLED-IA 2024 unemployment is checked in every wave it was '
        'judged, crossed or not', () {
      final key = dssFindingKey(
        'UNEMPLOYMENT_HIGH',
        'batch',
        'BTLED-IA',
        '2024',
      );
      final raisedIn = rows(
        rule: 'UNEMPLOYMENT_HIGH',
        course: 'BTLED-IA',
        batch: '2024',
        level: DssCohortLevel.batch,
      ).map((r) => r['survey_id']).toSet();
      expect(result.checked[key], containsAll(raisedIn));
    });

    test(
      'measures under 5 answers are suppressed, never checked or raised',
      () {
        expect(result.suppressed, isNotEmpty);
        expect(result.suppressed.length, result.notEnoughData);
        final raised = {
          for (final r in result.flagRows) '${keyOf(r)}@${r['survey_id']}',
        };
        for (final s in result.suppressed) {
          expect(s.validAnswers, lessThan(5));
          expect(raised, isNot(contains('${s.findingKey}@${s.surveyId}')));
          expect(
            result.checked[s.findingKey] ?? const {},
            isNot(contains(s.surveyId)),
          );
        }
      },
    );
  });
}
