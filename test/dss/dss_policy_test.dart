import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:flutter_test/flutter_test.dart';

DssRule _rule(
  String id, {
  DssRuleCategory category = DssRuleCategory.outcome,
  double threshold = 0.25,
  int minN = 10,
}) => DssRule(
  ruleId: id,
  name: id,
  description: '',
  metricKey: '',
  operator: 'gte',
  threshold: threshold,
  minN: minN,
  enabled: true,
  severity: DssSeverity.warning,
  recommendedAction: '',
  playbook: const [],
  category: category,
  sortOrder: 0,
);

DssFlag _flag({
  String ruleId = 'UNEMPLOYMENT_HIGH',
  int sampleN = 20,
  Map<String, dynamic> evidence = const {},
  int? ruleMinN,
  String? strengthColumn,
  DssFlagStatus status = DssFlagStatus.open,
}) => DssFlag(
  id: 'f',
  ruleId: ruleId,
  course: 'BSIT',
  batchYear: '2023',
  cohortLevel: DssCohortLevel.batch,
  surveyId: 's',
  surveyTitle: 'GTS',
  metricValue: 0.4,
  thresholdSnapshot: 0.25,
  sampleN: sampleN,
  confidence: DssConfidence.low,
  status: status,
  title: 'High unemployment: BSIT 2023',
  body: '',
  recommendedAction: '',
  evidence: evidence,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  ruleMinN: ruleMinN,
  evidenceStrengthRaw: strengthColumn,
);

AlumniMember _member({String course = 'BSIT', String batch = '2023'}) =>
    AlumniMember(
      id: 'm',
      fullName: 'A',
      course: course,
      studentId: '1',
      batchYear: batch,
    );

void main() {
  group('evidence strength boundaries', () {
    final cases = {
      0: DssEvidenceStrength.insufficient,
      4: DssEvidenceStrength.insufficient,
      5: DssEvidenceStrength.watch,
      9: DssEvidenceStrength.watch,
      10: DssEvidenceStrength.limited,
      29: DssEvidenceStrength.limited,
      30: DssEvidenceStrength.strong,
    };
    for (final e in cases.entries) {
      test('${e.key} valid answers -> ${e.value.label}', () {
        expect(DssPolicy.strength(e.key), e.value);
      });
    }

    test('a stricter rule minimum raises the finding gate only', () {
      expect(DssPolicy.strength(12, minN: 20), DssEvidenceStrength.watch);
      expect(DssPolicy.strength(20, minN: 20), DssEvidenceStrength.limited);
      expect(DssPolicy.strength(4, minN: 20), DssEvidenceStrength.insufficient);
      // A rule saved below the floor never lowers it.
      expect(DssPolicy.strength(7, minN: 1), DssEvidenceStrength.watch);
    });

    test('only limited and strong are findings', () {
      expect(DssEvidenceStrength.values.where((s) => s.isFinding), [
        DssEvidenceStrength.limited,
        DssEvidenceStrength.strong,
      ]);
    });
  });

  group('rule minimums', () {
    test('floors per category', () {
      expect(DssPolicy.minNFloor(DssRuleCategory.dataQuality), 1);
      for (final c in [
        DssRuleCategory.outcome,
        DssRuleCategory.opportunity,
        DssRuleCategory.trend,
      ]) {
        expect(DssPolicy.minNFloor(c), 10);
      }
    });

    test('rules saved below the floor are evaluated at the floor', () {
      expect(DssPolicy.ruleMin(_rule('UNEMPLOYMENT_HIGH', minN: 1)), 10);
      expect(DssPolicy.ruleMin(_rule('UNEMPLOYMENT_HIGH', minN: 20)), 20);
      expect(
        DssPolicy.ruleMin(
          _rule(
            'DATA_QUALITY_LOW',
            category: DssRuleCategory.dataQuality,
            minN: 0,
          ),
        ),
        1,
      );
    });
  });

  group('Settings validation', () {
    test('outcome rules need at least 10', () {
      final r = _rule('UNEMPLOYMENT_HIGH');
      expect(DssPolicy.ruleEditError(r, threshold: 0.25, minN: 9), isNotNull);
      expect(DssPolicy.ruleEditError(r, threshold: 0.25, minN: 10), isNull);
    });

    test('trend and opportunity rules need at least 10', () {
      for (final c in [DssRuleCategory.trend, DssRuleCategory.opportunity]) {
        final r = _rule('X', category: c);
        expect(DssPolicy.ruleEditError(r, threshold: 0.1, minN: 5), isNotNull);
      }
    });

    test('data quality accepts 1 but not 0', () {
      final r = _rule(
        'DATA_QUALITY_LOW',
        category: DssRuleCategory.dataQuality,
        threshold: 0.4,
      );
      expect(DssPolicy.ruleEditError(r, threshold: 0.4, minN: 0), isNotNull);
      expect(DssPolicy.ruleEditError(r, threshold: 0.4, minN: 1), isNull);
    });

    test('thresholds stay in range', () {
      final rate = _rule('UNEMPLOYMENT_HIGH');
      expect(
        DssPolicy.ruleEditError(rate, threshold: -0.1, minN: 10),
        isNotNull,
      );
      expect(
        DssPolicy.ruleEditError(rate, threshold: 1.2, minN: 10),
        isNotNull,
      );
      final salary = _rule('SALARY_STAGNATION', threshold: 1);
      expect(
        DssPolicy.ruleEditError(salary, threshold: 0, minN: 10),
        isNotNull,
      );
      expect(
        DssPolicy.ruleEditError(salary, threshold: 6, minN: 10),
        isNotNull,
      );
      expect(DssPolicy.ruleEditError(salary, threshold: 1, minN: 10), isNull);
    });
  });

  group('group mapping', () {
    test('course and batch known', () {
      final g = DssPolicy.groupOf(_member())!;
      expect((g.course, g.batch), ('BSIT', '2023'));
    });

    test('missing batch is "Batch not recorded" at course level only', () {
      final g = DssPolicy.groupOf(_member(batch: ' '))!;
      expect(g.batch, isNull);
      expect(DssPolicy.batchLabel(g.batch), 'Batch not recorded');
    });

    test('no roster record or no course is unclassified', () {
      expect(DssPolicy.groupOf(null), isNull);
      expect(DssPolicy.groupOf(_member(course: '  ')), isNull);
    });
  });

  group('flag model', () {
    test('stored column wins over evidence and derivation', () {
      final f = _flag(
        evidence: {'evidence_strength': 'limited', 'answered': 3},
        strengthColumn: 'watch',
      );
      expect(f.evidenceStrength, DssEvidenceStrength.watch);
      expect(f.isFinding, isFalse);
    });

    test('flags saved before the policy derive strength from their counts', () {
      final tiny = _flag(evidence: {'answered': 3, 'certainty': 'possible'});
      expect(tiny.evidenceStrength, DssEvidenceStrength.insufficient);
      expect(tiny.certainty, isNull);
      expect(DssCopy.metricValueLabel(tiny), 'Not enough data');
      expect(DssCopy.rangeLabel(tiny), isNull);

      final watch = _flag(evidence: {'answered': 7});
      expect(watch.evidenceStrength, DssEvidenceStrength.watch);

      final strong = _flag(evidence: {'answered': 40});
      expect(strong.evidenceStrength, DssEvidenceStrength.strong);
      expect(strong.isFinding, isTrue);
    });

    test('valid answers come from the metric, not the group size', () {
      final f = _flag(sampleN: 20, evidence: {'valid_answers': 3});
      expect(f.validAnswers, 3);
      expect(f.evidenceStrength, DssEvidenceStrength.insufficient);
      expect(
        DssCopy.responsesLabel(f),
        '20 responses · 3 answered this question',
      );
    });

    test('trend flags use the smaller wave', () {
      final f = _flag(
        ruleId: 'UNEMPLOYMENT_TREND_UP',
        evidence: {'current_answered': 25, 'previous_answered': 8},
      );
      expect(f.validAnswers, 8);
      expect(f.evidenceStrength, DssEvidenceStrength.watch);
    });

    test('data-quality flags have no evidence strength', () {
      final f = _flag(ruleId: 'DATA_QUALITY_LOW', sampleN: 0);
      expect(f.evidenceStrength, isNull);
      expect(f.isFinding, isTrue);
    });

    test('coverage and roster notes', () {
      final f = _flag(
        evidence: {
          'answered': 12,
          'response_rate': 0.2,
          'coverage_warning': true,
          'roster_basis': 'current',
        },
      );
      expect(DssCopy.coverageNote(f), contains('20%'));
      expect(DssCopy.rosterBasisNote(f), contains("today's roster"));
    });
  });
}
