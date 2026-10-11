// DSS Phase 7: intervention outcomes (models, wording, success-test
// defaults, the outcome card and the decision dialog). Outcomes are judged
// on the server; see supabase/regression/phase17_dss_outcomes.sql.
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/dss_outcome_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DssFlag _flag({
  String ruleId = 'UNEMPLOYMENT_HIGH',
  String status = 'open',
  String operator = 'gte',
  String category = 'outcome',
  double threshold = 0.25,
  Map<String, dynamic> evidence = const {},
}) => DssFlag.fromSupabaseRow({
  'id': 'f1',
  'rule_id': ruleId,
  'cohort_level': 'batch',
  'course': 'BSIT',
  'batch_year': '2024',
  'survey_id': 'w',
  'status': status,
  'metric_value': 0.4,
  'threshold_snapshot': threshold,
  'sample_n': 20,
  'title': 't',
  'evidence': {
    'valid_answers': 20,
    'evidence_strength': 'limited',
    ...evidence,
  },
  'created_at': '2026-10-01T00:00:00Z',
  'updated_at': '2026-10-01T00:00:00Z',
  'dss_rules': {
    'name': ruleId,
    'severity': 'warning',
    'operator': operator,
    'min_n': 10,
    'category': category,
    'playbook': const [],
  },
});

DssIntervention _intervention({
  String id = 'i1',
  String status = 'pending_followup',
  String metric = 'unemployment_rate',
  String operator = 'lt',
  double target = 0.25,
  double? baseline = 0.4,
  int? baselineN = 12,
  String? followupTitle,
  double? followupValue,
  int? followupN,
  String? decision,
  String? decisionNote,
  String? escalatedTo,
  String type = 'Job fair / Career Center outreach',
  String createdAt = '2026-10-05T00:00:00Z',
}) => DssIntervention.fromSupabaseRow({
  'id': id,
  'flag_id': 'f1',
  'finding_key': 'UNEMPLOYMENT_HIGH|batch|BSIT|2024',
  'rule_id': 'UNEMPLOYMENT_HIGH',
  'intervention_type': type,
  'description': 'Job fair with three employers',
  'expected_outcome': 'Fewer not employed',
  'success_metric': metric,
  'success_operator': operator,
  'success_target': target,
  'started_on': '2026-10-05',
  'baseline_survey_title': '2025 wave',
  'baseline_value': baseline,
  'baseline_n': baselineN,
  'followup_survey_title': followupTitle,
  'followup_value': followupValue,
  'followup_n': followupN,
  'outcome_status': status,
  'decision': decision,
  'decision_note': decisionNote,
  'escalated_to': escalatedTo,
  'decided_by_name': decision == null ? null : 'Dr. Admin',
  'decided_at': decision == null ? null : '2027-07-01T00:00:00Z',
  'created_by_name': 'Admin',
  'created_at': createdAt,
});

Future<void> _pumpCard(
  WidgetTester tester, {
  required DssFlag flag,
  List<DssIntervention> interventions = const [],
  DssOutcomeCheck? check,
  bool canRecord = true,
  void Function(DssIntervention, DssOutcomeDecision)? onDecide,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DssOutcomeCard(
            flag: flag,
            interventions: interventions,
            check: check,
            busy: false,
            canRecord: canRecord,
            onRecord: () {},
            onCheck: (_) {},
            onEditPlan: (_) {},
            onDecide: onDecide ?? (_, _) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('outcome status and decision', () {
    test('database values round-trip', () {
      for (final s in DssOutcomeStatus.values) {
        expect(DssOutcomeStatusX.fromDb(s.dbValue), s);
      }
      for (final d in DssOutcomeDecision.values) {
        expect(DssOutcomeDecisionX.fromDb(d.dbValue), d);
      }
      expect(DssOutcomeDecision.continueWork.dbValue, 'continue');
      expect(DssOutcomeStatusX.fromDb('bogus'), DssOutcomeStatus.notEvaluated);
      expect(DssOutcomeStatusX.tryFromDb('bogus'), isNull);
    });

    test('the seven statuses from the plan, two of them not final', () {
      expect(DssOutcomeStatus.values.map((s) => s.label), [
        'Not evaluated',
        'Pending follow-up',
        'Successful',
        'Partially successful',
        'Unsuccessful',
        'Inconclusive',
        'No comparable data',
      ]);
      expect(DssOutcomeStatus.values.where((s) => !s.isFinal), [
        DssOutcomeStatus.notEvaluated,
        DssOutcomeStatus.pendingFollowup,
      ]);
    });

    test('outcome notes parse', () {
      expect(DssNoteEventTypeX.fromDb('outcome'), DssNoteEventType.outcome);
      expect(DssNoteEventType.outcome.label, 'Outcome');
      expect(DssNoteEventType.impact.label, 'Coverage re-check');
    });
  });

  group('DssIntervention', () {
    test('parses a row with before and after values', () {
      final i = _intervention(
        status: 'partially_successful',
        followupTitle: '2026 wave',
        followupValue: 0.3,
        followupN: 18,
      );
      expect(i.baselineValue, 0.4);
      expect(i.baselineN, 12);
      expect(i.followupValue, 0.3);
      expect(i.followupN, 18);
      expect(i.startedOn, DateTime(2026, 10, 5));
      expect(i.outcomeStatus, DssOutcomeStatus.partiallySuccessful);
    });

    test('decide only after a final outcome; plan edits only before', () {
      final pending = _intervention();
      expect(pending.canDecide, isFalse);
      expect(pending.canEditPlan, isTrue);

      final judged = _intervention(status: 'unsuccessful');
      expect(judged.canDecide, isTrue);
      expect(judged.canEditPlan, isFalse);

      final decided = _intervention(
        status: 'unsuccessful',
        decision: 'modify',
        decisionNote: 'Switch to mentoring',
      );
      expect(decided.isDecided, isTrue);
      expect(decided.canDecide, isFalse);
      expect(decided.canEditPlan, isFalse);
      expect(decided.decision, DssOutcomeDecision.modify);
    });

    test('an open-wave check is a preview', () {
      final check = DssOutcomeCheck.fromJson({
        'outcome_status': 'pending_followup',
        'preview_status': 'successful',
        'provisional': true,
        'followup_survey_title': '2026 wave',
        'followup_value': 0.1,
        'followup_n': 12,
      });
      expect(check.outcomeStatus, DssOutcomeStatus.pendingFollowup);
      expect(check.previewStatus, DssOutcomeStatus.successful);
      expect(check.provisional, isTrue);
      expect(check.followupN, 12);
    });
  });

  group('wording', () {
    test('success test, baseline and values', () {
      final i = _intervention();
      expect(
        DssCopy.successTest(i),
        'Not currently employed below 25% in the next tracer wave',
      );
      expect(DssCopy.outcomeBaseline(i), '40% (2025 wave, 12 answers)');
      expect(DssCopy.outcomeValue('salary_peer_gap', 1), '1.0 brackets');
      expect(DssCopy.outcomeValue('response_rate', null), 'no value');
    });

    test('next-wave line for each state', () {
      expect(
        DssCopy.outcomeFollowup(_intervention()),
        'Waiting for a tracer wave published after 2026-10-05.',
      );
      expect(
        DssCopy.outcomeFollowup(_intervention(followupTitle: '2026 wave')),
        'Waiting for 2026 wave to close.',
      );
      expect(
        DssCopy.outcomeFollowup(
          _intervention(
            status: 'successful',
            followupTitle: '2026 wave',
            followupValue: 0.1,
            followupN: 10,
          ),
        ),
        '2026 wave: 10% from 10 answers.',
      );
      expect(
        DssCopy.outcomeFollowup(
          _intervention(
            status: 'inconclusive',
            followupTitle: '2026 wave',
            followupValue: 0.5,
            followupN: 6,
          ),
        ),
        '2026 wave: 50% from only 6 answers, too few to judge.',
      );
      expect(
        DssCopy.outcomeFollowup(
          _intervention(
            status: 'no_comparable_data',
            followupTitle: '2026 wave',
            followupN: 3,
          ),
        ),
        contains('fewer than 5 valid answers'),
      );
    });

    test('outcome wording is not causal', () {
      expect(DssCopy.outcomeCaveat, contains('not proof'));
      expect(
        DssCopy.outcomeHint(DssOutcomeStatus.partiallySuccessful),
        contains('at least 5 points'),
      );
      for (final s in DssOutcomeStatus.values) {
        expect(DssCopy.outcomeHint(s).toLowerCase(), isNot(contains('caused')));
      }
    });
  });

  group('success-test defaults (mirror of the server)', () {
    test('problem rules: below the threshold', () {
      final d = dssOutcomeDefaults(_flag());
      expect(
        (d.metric, d.operator, d.target),
        ('unemployment_rate', 'lt', 0.25),
      );
    });

    test('data quality: response rate at least the threshold', () {
      final d = dssOutcomeDefaults(
        _flag(
          ruleId: 'DATA_QUALITY_LOW',
          operator: 'lt',
          category: 'data_quality',
          threshold: 0.4,
        ),
      );
      expect((d.metric, d.operator, d.target), ('response_rate', 'gte', 0.4));
    });

    test('strengths: stay at or above the threshold', () {
      final d = dssOutcomeDefaults(
        _flag(
          ruleId: 'RELATEDNESS_HIGH',
          category: 'opportunity',
          threshold: 0.75,
        ),
      );
      expect(
        (d.metric, d.operator, d.target),
        ('related_and_relevant_rate', 'gte', 0.75),
      );
    });

    test('trend: back to the previous wave', () {
      final d = dssOutcomeDefaults(
        _flag(
          ruleId: 'UNEMPLOYMENT_TREND_UP',
          category: 'trend',
          threshold: 0.1,
          evidence: {'previous_rate': 0.12, 'current_rate': 0.3},
        ),
      );
      expect(
        (d.metric, d.operator, d.target),
        ('unemployment_rate', 'lte', 0.12),
      );
    });

    test('target input', () {
      expect(dssParseOutcomeTarget('unemployment_rate', '25'), 0.25);
      expect(dssParseOutcomeTarget('unemployment_rate', '25%'), 0.25);
      expect(dssParseOutcomeTarget('unemployment_rate', '150'), isNull);
      expect(dssParseOutcomeTarget('unemployment_rate', 'abc'), isNull);
      expect(dssParseOutcomeTarget('salary_peer_gap', '-0.5'), -0.5);
      expect(dssParseOutcomeTarget('salary_peer_gap', '11'), isNull);
    });
  });

  group('DssOutcomeCard', () {
    testWidgets('closed flag without interventions: legacy', (tester) async {
      await _pumpCard(tester, flag: _flag(status: 'resolved'));
      expect(find.text('Not evaluated (legacy)'), findsOneWidget);
      expect(find.text('Record intervention'), findsOneWidget);
    });

    testWidgets('open flag without interventions', (tester) async {
      await _pumpCard(tester, flag: _flag());
      expect(
        find.textContaining('No intervention recorded yet'),
        findsOneWidget,
      );
      expect(find.text('Record intervention'), findsOneWidget);
      expect(find.text('Not evaluated (legacy)'), findsNothing);
    });

    testWidgets('pending: check and edit, no decision yet', (tester) async {
      await _pumpCard(
        tester,
        flag: _flag(status: 'in_progress'),
        interventions: [_intervention()],
      );
      expect(find.text('Pending follow-up'), findsOneWidget);
      expect(find.text('Check outcome'), findsOneWidget);
      expect(find.text('Edit plan'), findsOneWidget);
      expect(find.text('Resolve'), findsNothing);
      expect(find.text('Record intervention'), findsNothing);
      expect(find.textContaining('not proof'), findsNothing);
    });

    testWidgets('open follow-up wave shows a preview', (tester) async {
      await _pumpCard(
        tester,
        flag: _flag(status: 'in_progress'),
        interventions: [_intervention(followupTitle: '2026 wave')],
        check: const DssOutcomeCheck(
          outcomeStatus: DssOutcomeStatus.pendingFollowup,
          previewStatus: DssOutcomeStatus.successful,
          provisional: true,
          followupSurveyTitle: '2026 wave',
          followupValue: 0.1,
          followupN: 12,
        ),
      );
      expect(find.textContaining('Preview, not final'), findsOneWidget);
      expect(find.textContaining('"Successful"'), findsOneWidget);
      expect(find.text('Resolve'), findsNothing);
    });

    testWidgets('failed follow-up: four decisions', (tester) async {
      final calls = <DssOutcomeDecision>[];
      await _pumpCard(
        tester,
        flag: _flag(status: 'resolved'),
        interventions: [
          _intervention(
            status: 'unsuccessful',
            followupTitle: '2026 wave',
            followupValue: 0.38,
            followupN: 20,
          ),
        ],
        onDecide: (_, d) => calls.add(d),
      );
      expect(find.text('Unsuccessful'), findsOneWidget);
      expect(find.textContaining('not proof'), findsOneWidget);
      for (final label in ['Resolve', 'Continue', 'Modify', 'Escalate']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Edit plan'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.tap(find.text('Escalate'));
      expect(calls, [
        DssOutcomeDecision.continueWork,
        DssOutcomeDecision.escalate,
      ]);
    });

    testWidgets('successful follow-up can be resolved', (tester) async {
      final calls = <DssOutcomeDecision>[];
      await _pumpCard(
        tester,
        flag: _flag(status: 'in_progress'),
        interventions: [
          _intervention(
            status: 'successful',
            followupTitle: '2026 wave',
            followupValue: 0.1,
            followupN: 30,
          ),
        ],
        onDecide: (_, d) => calls.add(d),
      );
      expect(find.text('Successful'), findsOneWidget);
      await tester.tap(find.text('Resolve'));
      expect(calls, [DssOutcomeDecision.resolve]);
    });

    testWidgets('insufficient follow-up still allows a decision', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        flag: _flag(status: 'in_progress'),
        interventions: [
          _intervention(
            status: 'no_comparable_data',
            followupTitle: '2026 wave',
            followupN: 3,
          ),
        ],
      );
      expect(find.text('No comparable data'), findsOneWidget);
      expect(find.textContaining('not proof'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('decided: decision shown, earlier interventions listed', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        flag: _flag(status: 'in_progress'),
        interventions: [
          _intervention(
            id: 'i2',
            type: 'Career counseling session',
            status: 'inconclusive',
            followupTitle: '2027 wave',
            followupValue: 0.3,
            followupN: 7,
            decision: 'escalate',
            decisionNote: 'Needs the dean.',
            escalatedTo: 'Office of the VP',
            createdAt: '2027-08-01T00:00:00Z',
          ),
          _intervention(
            status: 'unsuccessful',
            followupTitle: '2026 wave',
            followupValue: 0.38,
            followupN: 20,
            decision: 'continue',
            decisionNote: 'Keep going.',
          ),
        ],
      );
      expect(
        find.textContaining('Decision: Escalate to Office of the VP.'),
        findsOneWidget,
      );
      expect(find.text('Resolve'), findsNothing);
      expect(find.text('Check outcome'), findsNothing);
      expect(
        find.text('Earlier interventions on this finding'),
        findsOneWidget,
      );
      expect(find.textContaining('· Continue'), findsOneWidget);
      expect(find.text('Record intervention'), findsOneWidget);
    });
  });

  testWidgets('decision dialog needs a note', (tester) async {
    DssDecisionDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDssDecisionDialog(
                  context,
                  flag: _flag(),
                  intervention: _intervention(status: 'unsuccessful'),
                  decision: DssOutcomeDecision.escalate,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Escalate');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Escalate to office (optional)'),
      ' Office of the VP ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Note (required)'),
      'Needs the VP.',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(result?.note, 'Needs the VP.');
    expect(result?.office, 'Office of the VP');
    expect(result?.type, isNull);
    expect(result?.target, isNull);
  });
}
