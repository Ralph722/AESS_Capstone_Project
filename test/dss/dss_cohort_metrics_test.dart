// DSS Phase 3: Dart reference for dss_cohort_metrics. Same fixture and
// expected values as supabase/regression/phase14_dss_cohort_metrics.sql.
import 'package:alumni_system/features/admin/dss/application/dss_cohort_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 11, 12);

Map<String, dynamic> _q30(String level, {bool current = true}) => {
  level: {current ? DssMetrics.currentJobCol : DssMetrics.firstJobCol: true},
};

/// n → (course, batch, has account, answers or null when not responding).
final _fixture = <int, (String, String?, bool, Map<String, dynamic>?)>{
  1: (
    'P14T',
    '2099',
    true,
    {
      'ched_16': 'Yes',
      'ched_24a': 'Yes',
      'ched_32': 'Yes',
      'ched_29': 'Less than a month',
      'ched_31': 'P10,000.00 to less than P15,000.00',
      'ched_30': _q30('Rank or Clerical'),
    },
  ),
  2: (
    'P14T',
    '2099',
    true,
    {
      'ched_16': 'Yes',
      'ched_24a': 'No',
      'ched_29': '1 year to less than 2 years',
      'ched_31': 'P5,000.00 to less than P10,000.00',
      'ched_30': _q30('Professional, Technical or Supervisory'),
    },
  ),
  3: (
    'P14T',
    '2099',
    true,
    {
      'ched_16': 'No',
      'ched_17': ['No job opportunity'],
      'ched_29': 'Others, please specify',
      'ched_31': 'Below P5,000.00',
    },
  ),
  4: (
    'P14T',
    '2099',
    true,
    {
      'ched_16': 'Never Employed',
      'ched_17': ['Advance or further study'],
      'ched_32': 'No',
    },
  ),
  5: (
    'P14T',
    '2099',
    true,
    {
      'ched_16': 'No',
      'ched_17': ['Lack of work experience'],
      'ched_29': '2 years to less than 3 years',
    },
  ),
  6: (
    'P14T',
    '2099',
    true,
    {
      'ched_16': 'Yes',
      'ched_24a': 'Yes',
      'ched_32': 'Yes',
      'ched_31': 'P15,000.00 to less than P20,000.00',
      'ched_30': _q30('Rank or Clerical', current: false),
    },
  ),
  7: ('P14T', '2099', true, null),
  8: ('P14T', '2099', true, null),
  9: (
    'P14T',
    '2098',
    true,
    {'ched_16': 'Yes', 'ched_31': 'P20,000.00 to less than P25,000.00'},
  ),
  10: ('P14T', '2098', true, null),
  11: (
    'P14T',
    null,
    true,
    {
      'ched_16': 'No',
      'ched_17': ['Did not look for a job'],
    },
  ),
  12: ('P14T', '2097', false, null),
  14: (
    'P14U',
    '2099',
    true,
    {'ched_16': 'Yes', 'ched_31': 'P25,000.00 and above'},
  ),
};

String _uid(int n) => 'uid-$n';

final _roster = [
  for (final e in _fixture.entries)
    AlumniMember(
      id: 'm-${e.key}',
      fullName: 'P14 Alumnus ${e.key}',
      course: e.value.$1,
      studentId: 'P14-${e.key}',
      batchYear: e.value.$2 ?? '',
      authUid: e.value.$3 ? _uid(e.key) : null,
    ),
];

SurveyResponse _response(String surveyId, int n, Map<String, dynamic> a) =>
    SurveyResponse(
      surveyId: surveyId,
      userId: _uid(n),
      answers: a,
      status: SurveyResponseStatus.submitted,
      submittedAt: _now,
      updatedAt: _now,
    );

final _responses = [
  for (final e in _fixture.entries)
    if (e.value.$4 != null) _response('s14', e.key, e.value.$4!),
  // Respondent 13 has no roster record.
  _response('s14', 13, const {'ched_16': 'No'}),
];

Survey _survey({
  String id = 's14',
  SurveyStatus status = SurveyStatus.closed,
  DateTime? openAt,
  DateTime? closeAt,
}) => Survey(
  id: id,
  title: 'P14 GTS',
  description: '',
  status: status,
  openAt: openAt,
  closeAt: closeAt,
  createdBy: 'admin',
  createdAt: DateTime.utc(2026),
  kind: 'ched_gts_builtin',
);

DssRule _rule(String metricKey, int minN) => DssRule(
  ruleId: metricKey,
  name: metricKey,
  description: '',
  metricKey: metricKey,
  operator: 'gte',
  threshold: 0.25,
  minN: minN,
  enabled: false,
  severity: DssSeverity.warning,
  recommendedAction: '',
  playbook: const [],
  category: DssRuleCategory.outcome,
  sortOrder: 0,
);

void main() {
  final rules = [_rule('unemployment_rate', 10)];

  Map<String, DssCohortMetric> compute({
    Survey? survey,
    List<DssCohortSnapshot> snapshots = const [],
  }) => {
    for (final m in DssCohortMetrics.compute(
      survey: survey ?? _survey(),
      responses: _responses,
      roster: _roster,
      rules: rules,
      now: _now,
      snapshots: snapshots,
    ))
      m.key: m,
  };

  String fmt(DssCohortMetric? m) => m == null
      ? 'missing'
      : '${m.hits}/${m.total} '
            'v=${m.value?.toStringAsFixed(4)} '
            'n=${m.respondents} e=${m.eligible} '
            's=${m.evidenceStrength?.dbValue}';

  final rows = compute();

  test('batch P14T 2099', () {
    String r(String key) => fmt(rows['batch|P14T|2099|$key']);
    expect(r('response_rate'), '6/8 v=0.7500 n=6 e=8 s=null');
    expect(r('unemployment_rate'), '3/6 v=0.5000 n=6 e=8 s=watch');
    expect(r('seeking_work_rate'), '2/5 v=0.4000 n=6 e=8 s=watch');
    expect(
      r('unrelated_or_irrelevant_rate'),
      '2/4 v=0.5000 n=6 e=8 s=insufficient',
    );
    expect(
      r('related_and_relevant_rate'),
      '2/4 v=0.5000 n=6 e=8 s=insufficient',
    );
    expect(
      r('clerical_among_employed_rate'),
      '2/3 v=0.6667 n=6 e=8 s=insufficient',
    );
    expect(
      r('long_time_to_first_job_rate'),
      '2/3 v=0.6667 n=6 e=8 s=insufficient',
    );
    expect(r('salary_peer_gap'), 'null/4 v=3.5000 n=6 e=8 s=insufficient');
    final u = rows['batch|P14T|2099|unemployment_rate']!;
    expect(u.nonResponse, 0);
    expect(u.registered, 8);
    expect(u.rosterBasis, 'current');
    expect(u.coverageWarning, isFalse);
    expect(u.ciLow, closeTo(0.1876, 1e-4));
    expect(u.ciHigh, closeTo(0.8124, 1e-4));
    expect(rows['batch|P14T|2099|long_time_to_first_job_rate']!.nonResponse, 3);
    expect(rows['batch|P14T|2099|response_rate']!.nonResponse, isNull);
    expect(rows['batch|P14T|2099|salary_peer_gap']!.ciLow, isNull);
  });

  test(
    'course P14T counts the batch-less respondent, not the unlinked one',
    () {
      String r(String key) => fmt(rows['course|P14T|All|$key']);
      expect(r('response_rate'), '8/12 v=0.6667 n=8 e=12 s=null');
      expect(r('unemployment_rate'), '4/8 v=0.5000 n=8 e=12 s=watch');
      expect(r('seeking_work_rate'), '2/6 v=0.3333 n=8 e=12 s=watch');
      expect(r('salary_peer_gap'), 'null/5 v=3.0000 n=8 e=12 s=watch');
      expect(rows['course|P14T|All|response_rate']!.registered, 11);
    },
  );

  test('small and empty batches', () {
    expect(
      fmt(rows['batch|P14T|2098|response_rate']),
      '1/2 v=0.5000 n=1 e=2 s=null',
    );
    expect(
      fmt(rows['batch|P14T|2098|salary_peer_gap']),
      'null/1 v=1.0000 n=1 e=2 s=insufficient',
    );
    expect(
      fmt(rows['batch|P14T|2097|response_rate']),
      '0/1 v=0.0000 n=0 e=1 s=null',
    );
    expect(rows['batch|P14T|2097|response_rate']!.coverageWarning, isTrue);
    expect(rows['batch|P14T|2097|response_rate']!.registered, 0);
    expect(
      rows.keys.where((k) => k.startsWith('batch|P14T|2097|')),
      hasLength(1),
    );
    expect(rows.keys.where((k) => k.contains('Batch not recorded')), isEmpty);
  });

  test('peer salary uses the other courses', () {
    expect(
      fmt(rows['course|P14U|All|salary_peer_gap']),
      'null/1 v=-3.0000 n=1 e=1 s=insufficient',
    );
  });

  test('institution: classified respondents, no salary gap', () {
    expect(
      fmt(rows['institution|All|All|unemployment_rate']),
      '4/9 v=0.4444 n=9 e=13 s=watch',
    );
    expect(rows.containsKey('institution|All|All|salary_peer_gap'), isFalse);
  });

  test('evidence strength follows the strictest rule on the metric', () {
    final roster = [
      for (var i = 0; i < 12; i++)
        AlumniMember(
          id: 'v-$i',
          fullName: 'V $i',
          course: 'P14V',
          studentId: 'V-$i',
          batchYear: '2099',
          authUid: 'v-uid-$i',
        ),
    ];
    final responses = [
      for (var i = 0; i < 12; i++)
        SurveyResponse(
          surveyId: 's14',
          userId: 'v-uid-$i',
          answers: const {'ched_16': 'Yes'},
          status: SurveyResponseStatus.submitted,
          submittedAt: _now,
          updatedAt: _now,
        ),
    ];
    DssEvidenceStrength? strength(List<DssRule> rules) =>
        DssCohortMetrics.compute(
              survey: _survey(),
              responses: responses,
              roster: roster,
              rules: rules,
              now: _now,
            )
            .firstWhere((m) => m.key == 'batch|P14V|2099|unemployment_rate')
            .evidenceStrength;

    expect(strength(const []), DssEvidenceStrength.limited);
    expect(
      strength([_rule('unemployment_rate', 10)]),
      DssEvidenceStrength.limited,
    );
    expect(
      strength([
        _rule('unemployment_rate', 10),
        _rule('unemployment_rate', 40),
      ]),
      DssEvidenceStrength.watch,
    );
  });

  test('saved snapshot replaces the roster of a closed wave', () {
    final snap = compute(
      snapshots: [
        DssCohortSnapshot(
          surveyId: 's14',
          course: 'P14T',
          batchYear: '2099',
          rosterCount: 20,
          registeredCount: 10,
          capturedAt: _now,
        ),
      ],
    );
    final b = snap['batch|P14T|2099|response_rate']!;
    expect(b.rosterBasis, 'snapshot');
    expect(fmt(b), '6/20 v=0.3000 n=6 e=20 s=null');
    expect(b.coverageWarning, isFalse);
    expect(
      fmt(snap['course|P14T|All|response_rate']),
      '8/20 v=0.4000 n=8 e=20 s=null',
    );
    expect(
      fmt(snap['batch|P14T|2098|response_rate']),
      '1/1 v=1.0000 n=1 e=1 s=null',
    );
    expect(snap.containsKey('batch|P14T|2097|response_rate'), isFalse);
  });

  test('an open wave always uses today\'s roster', () {
    final open = compute(
      survey: _survey(
        status: SurveyStatus.published,
        openAt: _now.subtract(const Duration(days: 1)),
        closeAt: _now.add(const Duration(days: 1)),
      ),
      snapshots: [
        DssCohortSnapshot(
          surveyId: 's14',
          course: 'P14T',
          batchYear: '2099',
          rosterCount: 20,
          registeredCount: 10,
          capturedAt: _now,
        ),
      ],
    );
    expect(open['batch|P14T|2099|response_rate']!.rosterBasis, 'open_wave');
    expect(open['batch|P14T|2099|response_rate']!.eligible, 8);
  });

  test('row order: institution, courses, batches; metrics in key order', () {
    final list = DssCohortMetrics.compute(
      survey: _survey(),
      responses: _responses,
      roster: _roster,
      rules: rules,
      now: _now,
    );
    final groups = <String>[];
    for (final m in list) {
      final g = '${m.level.dbValue}|${m.course}|${m.batchYear}';
      if (groups.isEmpty || groups.last != g) groups.add(g);
    }
    expect(groups, [
      'institution|All|All',
      'course|P14T|All',
      'course|P14U|All',
      'batch|P14T|2097',
      'batch|P14T|2098',
      'batch|P14T|2099',
      'batch|P14U|2099',
    ]);
    expect(
      list
          .where((m) => m.course == 'P14T' && m.batchYear == '2099')
          .map((m) => m.metricKey),
      DssCohortMetrics.metricKeys,
    );
  });

  test('rows survive a round trip through the SQL row shape', () {
    for (final m in rows.values) {
      expect(DssCohortMetric.fromRow(m.toRow()).toRow(), m.toRow());
    }
  });
}
