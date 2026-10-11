// DSS Phase 2: Q17 reasons for not being employed. Same fixtures as
// supabase/regression/phase13_dss_q17.sql so Dart and SQL agree.
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixtures = <Map<String, dynamic>>[
  {'ched_16': 'Yes'},
  {
    'ched_16': 'Yes',
    'ched_17': ['No job opportunity'],
  },
  {
    'ched_16': 'No',
    'ched_17': ['No job opportunity'],
  },
  {
    'ched_16': 'Never Employed',
    'ched_17': [' Lack of work experience ', ''],
  },
  {'ched_16': 'No', 'ched_17': 'No job opportunity'},
  {
    'ched_16': 'No',
    'ched_17': ['No job opportunity', 'Did not look for a job'],
  },
  {
    'ched_16': 'No',
    'ched_17': ['Advance or further study'],
  },
  {
    'ched_16': 'No',
    'ched_17': ['Other reason(s), please specify'],
    'ched_17_other': 'Caregiving',
  },
  {'ched_16': 'No'},
  {'ched_29': 'Less than a month'},
];

DssFlag _flag(String ruleId, Map<String, dynamic> evidence) => DssFlag(
  id: 'f',
  ruleId: ruleId,
  course: 'BSIT',
  batchYear: '2099',
  cohortLevel: DssCohortLevel.batch,
  surveyId: 's',
  surveyTitle: 'GTS',
  metricValue: 0.6,
  thresholdSnapshot: 0.15,
  sampleN: 10,
  confidence: DssConfidence.low,
  status: DssFlagStatus.open,
  title: 'High unemployment: BSIT 2099',
  body: '',
  recommendedAction: '',
  evidence: evidence,
  createdAt: DateTime(2026, 10, 11),
  updatedAt: DateTime(2026, 10, 11),
);

void main() {
  group('labour status (Q16 + Q17)', () {
    test('each fixture is classified', () {
      expect(_fixtures.map(DssMetrics.labourStatus).toList(), [
        DssLabourStatus.employed,
        DssLabourStatus.employed,
        DssLabourStatus.seeking,
        DssLabourStatus.seeking,
        DssLabourStatus.seeking,
        DssLabourStatus.notSeeking,
        DssLabourStatus.notSeeking,
        DssLabourStatus.notSeeking,
        DssLabourStatus.reasonUnknown,
        null,
      ]);
    });

    test('"Did not look for a job" wins over a looking reason', () {
      expect(
        DssMetrics.labourStatus({
          'ched_16': 'Never Employed',
          'ched_17': ['Lack of work experience', 'Did not look for a job'],
        }),
        DssLabourStatus.notSeeking,
      );
    });

    test('a looking reason counts even with a non-looking one', () {
      expect(
        DssMetrics.labourStatus({
          'ched_16': 'No',
          'ched_17': [
            'Family concern and decided not to find a job',
            'No job opportunity',
          ],
        }),
        DssLabourStatus.seeking,
      );
    });

    test('Q17 reasons are ignored for employed respondents', () {
      expect(
        DssMetrics.labourStatus({
          'ched_16': 'Yes',
          'ched_17': ['Did not look for a job'],
        }),
        DssLabourStatus.employed,
      );
    });
  });

  group('seeking work rate', () {
    test('looking for work among employed + looking (matches SQL)', () {
      final p = DssMetrics.seekingWork(_fixtures)!;
      expect(p.hits, 3);
      expect(p.total, 5);
      expect(p.rate, closeTo(0.6, 1e-9));
    });

    test('not-employed share keeps its meaning', () {
      final p = DssMetrics.unemployment(_fixtures)!;
      expect(p.hits, 7);
      expect(p.total, 9);
    });

    test('null when nobody is employed or looking', () {
      expect(
        DssMetrics.seekingWork([
          {
            'ched_16': 'No',
            'ched_17': ['Advance or further study'],
          },
          {'ched_16': 'No'},
        ]),
        isNull,
      );
    });

    test('breakdown counts people and ticked reasons', () {
      final b = DssMetrics.notEmployedBreakdown(_fixtures);
      expect(b.seeking, 3);
      expect(b.notSeeking, 3);
      expect(b.reasonUnknown, 1);
      expect(b.notEmployed, 7);
      expect(b.reasons['No job opportunity'], 3);
      expect(b.reasons['Lack of work experience'], 1);
      expect(b.reasons.containsKey(''), isFalse);
    });
  });

  group('labels', () {
    test('UNEMPLOYMENT_HIGH shows as "Not currently employed"', () {
      expect(
        dssRuleDisplayName('UNEMPLOYMENT_HIGH', 'High unemployment'),
        'Not currently employed',
      );
      expect(
        dssRuleDisplayName('SEEKING_WORK_HIGH', 'Many alumni looking for work'),
        'Many alumni looking for work',
      );
      final f = _flag('UNEMPLOYMENT_HIGH', const {'answered': 12});
      expect(DssCopy.displayTitle(f), 'Not currently employed');
      expect(DssCopy.metricLabel(f), 'Not currently employed');
    });

    test('seeking-work source explains the labour-force denominator', () {
      final f = _flag('SEEKING_WORK_HIGH', const {'valid_answers': 5});
      expect(DssCopy.metricLabel(f), 'Looking for work');
      expect(DssCopy.sourceLabel(f), contains('employed or looking for work'));
      expect(
        DssCopy.interventionsForRule('SEEKING_WORK_HIGH'),
        contains('Work-readiness / experience program'),
      );
    });

    test('Q17 note summarises the reasons', () {
      final b = DssMetrics.notEmployedBreakdown(_fixtures);
      final note = DssCopy.notEmployedReasonsNote(
        _flag('UNEMPLOYMENT_HIGH', {'answered': 9, 'q17': b.toEvidence()}),
      )!;
      expect(note, startsWith('Why not employed (Q17), 7 people: '));
      expect(
        note,
        contains('3 looking for work, 3 not looking, 1 gave no reason'),
      );
      expect(note, contains('No job opportunity (3)'));
    });

    test('no Q17 note on flags saved before Phase 2', () {
      expect(
        DssCopy.notEmployedReasonsNote(
          _flag('UNEMPLOYMENT_HIGH', const {'answered': 9}),
        ),
        isNull,
      );
    });
  });
}
