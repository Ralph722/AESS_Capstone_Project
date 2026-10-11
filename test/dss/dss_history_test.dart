import 'package:alumni_system/features/admin/dss/application/dss_history.dart';
import 'package:alumni_system/features/admin/dss/application/dss_report_card.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:flutter_test/flutter_test.dart';

DssIntervention _iv(
  String id, {
  String type = 'Job fair',
  String ruleId = 'UNEMPLOYMENT_HIGH',
  String status = 'not_evaluated',
  String flagId = 'f1',
  String findingKey = 'UNEMPLOYMENT_HIGH|batch|BSIT|2024',
  double? followupValue,
  String? decision,
}) => DssIntervention.fromSupabaseRow({
  'id': id,
  'flag_id': flagId,
  'finding_key': findingKey,
  'rule_id': ruleId,
  'intervention_type': type,
  'success_metric': 'unemployment_rate',
  'success_operator': 'lt',
  'success_target': 0.25,
  'started_on': '2026-10-05',
  'baseline_survey_title': '2025 wave',
  'baseline_value': 0.4,
  'baseline_n': 20,
  'followup_value': followupValue,
  'followup_n': followupValue == null ? null : 18,
  'outcome_status': status,
  'decision': decision,
  'created_at': '2026-10-05T00:00:00Z',
});

DssFlag _flag(String id, {String status = 'open', String course = 'BSIT'}) =>
    DssFlag.fromSupabaseRow({
      'id': id,
      'rule_id': 'UNEMPLOYMENT_HIGH',
      'cohort_level': 'batch',
      'course': course,
      'batch_year': '2024',
      'survey_id': 'w',
      'status': status,
      'metric_value': 0.5,
      'threshold_snapshot': 0.25,
      'sample_n': 20,
      'title': 't',
      'evidence': {'valid_answers': 20, 'evidence_strength': 'limited'},
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z',
      'dss_rules': {
        'name': 'High unemployment',
        'severity': 'critical',
        'operator': 'gte',
        'min_n': 10,
        'category': 'outcome',
        'playbook': const [],
      },
    });

Map<String, dynamic> _event(
  String run,
  String outcome,
  String reason, {
  String trigger = 'manual',
  String at = '2026-10-11T10:00:00Z',
}) => {
  'run_id': run,
  'run_trigger': trigger,
  'outcome': outcome,
  'reason': reason,
  'created_at': at,
};

void main() {
  group('intervention outcomes', () {
    test('counts each outcome and groups types ignoring case and spaces', () {
      final s = DssOutcomeSummary.from([
        _iv('1', status: 'successful'),
        _iv('2', type: ' job  FAIR ', status: 'unsuccessful'),
        _iv('3', type: 'Curriculum review', ruleId: 'RELATEDNESS_LOW'),
        _iv('4', status: 'pending_followup'),
        _iv('5', type: '', status: 'no_comparable_data'),
      ]);
      expect(s.overall.total, 5);
      expect(s.overall.waiting, 2);
      expect(s.overall.judged, 2);
      expect(s.byType.keys.toList(), [
        'Job fair',
        'Curriculum review',
        'Not specified',
      ]);
      final fair = s.byType['Job fair']!;
      expect(fair.total, 3);
      expect(fair.count(DssOutcomeStatus.successful), 1);
      expect(fair.count(DssOutcomeStatus.unsuccessful), 1);
      expect(fair.waiting, 1);
      expect(s.byRule.keys.toList(), ['UNEMPLOYMENT_HIGH', 'RELATEDNESS_LOW']);
      expect(s.byRule['UNEMPLOYMENT_HIGH']!.total, 4);
    });

    test('nothing recorded', () {
      final s = DssOutcomeSummary.from(const []);
      expect(s.isEmpty, isTrue);
      expect(s.byType, isEmpty);
    });
  });

  group('evaluation runs', () {
    test('groups events by run, newest first, with their counts', () {
      final runs = DssEvaluationRun.fromEvents([
        _event('a', 'raised', 'finding', at: '2026-10-10T19:25:00Z',
            trigger: 'scheduled'),
        _event('a', 'raised', 'watch', at: '2026-10-10T19:25:00Z',
            trigger: 'scheduled'),
        _event('a', 'suppressed', 'not_enough_data',
            at: '2026-10-10T19:25:00Z', trigger: 'scheduled'),
        _event('b', 'updated', 'refreshed'),
        _event('b', 'superseded', 'newer_wave_raised'),
        _event('b', 'suppressed', 'newer_wave'),
        _event('b', 'suppressed', 'closed_in_wave'),
      ]);
      expect(runs.map((r) => r.runId), ['b', 'a']);
      final b = runs.first;
      expect(b.scheduled, isFalse);
      expect(b.triggerLabel, 'Manual Refresh');
      expect(
        [b.raised, b.updated, b.superseded, b.skipped, b.notEnoughData],
        [0, 1, 1, 2, 0],
      );
      final a = runs.last;
      expect(a.triggerLabel, 'Nightly');
      expect([a.raised, a.notEnoughData], [2, 1]);
      expect(a.at, DateTime.utc(2026, 10, 10, 19, 25));
    });

    test('keeps the latest runs only', () {
      final runs = DssEvaluationRun.fromEvents([
        for (var i = 1; i <= 25; i++)
          _event(
            'r$i',
            'updated',
            'refreshed',
            at: DateTime.utc(2026, 10, i).toIso8601String(),
          ),
      ]);
      expect(runs.length, 20);
      expect(runs.first.runId, 'r25');
      expect(runs.last.runId, 'r6');
    });
  });

  group('institution report card', () {
    final now = DateTime(2026, 10, 11);

    test('lists the most urgent findings across programs and outcomes', () {
      final flags = [
        for (var i = 0; i < 20; i++)
          _flag('f$i', course: i.isEven ? 'BSIT' : 'BSED'),
        _flag('c1', status: 'resolved'),
      ];
      final data = DssReportCardData(
        course: 'Whole institution (all programs)',
        generatedAt: now,
        waves: const [],
        flags: flags,
        actions: const [],
        institution: true,
        interventions: [
          _iv('1', flagId: 'c1', status: 'successful', followupValue: 0.2,
              decision: 'resolve'),
          _iv('2', flagId: 'gone', type: 'Coaching'),
        ],
      );
      expect(data.activeFlags.length, 20);
      expect(data.outcomes.overall.total, 2);
      expect(data.flagOf(data.interventions.first)?.id, 'c1');
      expect(data.flagOf(data.interventions.last), isNull);
    });

    test('PDF builds for the institution and for a program', () async {
      final flags = [for (var i = 0; i < 20; i++) _flag('f$i')];
      final interventions = [
        _iv('1', status: 'successful', followupValue: 0.2, decision: 'resolve'),
        _iv('2', flagId: 'gone', type: 'Coaching'),
      ];
      final institution = await DssReportCardPdf.build(
        DssReportCardData(
          course: 'Whole institution (all programs)',
          generatedAt: now,
          waves: const [],
          flags: flags,
          actions: const [],
          institution: true,
          interventions: interventions,
        ),
      );
      final program = await DssReportCardPdf.build(
        DssReportCardData(
          course: 'BSIT',
          generatedAt: now,
          waves: const [],
          flags: flags,
          actions: const [],
          interventions: interventions,
        ),
      );
      expect(String.fromCharCodes(institution.take(4)), '%PDF');
      expect(String.fromCharCodes(program.take(4)), '%PDF');
      expect(institution, isNot(equals(program)));
    });
  });
}
