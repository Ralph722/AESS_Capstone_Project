import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_report_card.dart';
import 'package:alumni_system/features/admin/dss/application/dss_rollup.dart';
import 'package:alumni_system/features/admin/dss/application/dss_suggestion_themes.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _a({
  String? q16,
  String? q24,
  String? q32,
  String? q29,
  String? q31,
  String? q34,
  String? level,
}) => {
  if (q16 != null) 'ched_16': q16,
  if (q24 != null) 'ched_24a': q24,
  if (q32 != null) 'ched_32': q32,
  if (q29 != null) 'ched_29': q29,
  if (q31 != null) 'ched_31': q31,
  if (q34 != null) 'ched_34': q34,
  if (level != null)
    'ched_30': {
      level: {DssMetrics.currentJobCol: true},
    },
};

void main() {
  group('salary', () {
    test('salaryRank orders brackets', () {
      expect(
        DssMetrics.salaryRank('Below P5,000.00'),
        lessThan(DssMetrics.salaryRank('P25,000.00 and above')),
      );
      expect(DssMetrics.salaryRank('unknown'), -1);
    });

    test('peer median excludes the cohort\'s own course', () {
      final byCourse = {
        'BSIT': [0, 0, 0, 0, 0],
        'BSCS': [3, 3],
        'BSED': [4],
      };
      // Including BSIT would give a median of 0; peers alone are 3, 3, 4.
      expect(DssMetrics.peerMedianExcluding(byCourse, 'BSIT'), 3);
      expect(DssMetrics.peerMedianExcluding({'BSIT': [1, 2]}, 'BSIT'), isNull);
    });

    test('salary gap is peer median minus cohort median', () {
      expect(DssMetrics.salaryGap([1, 1, 2], 3), 2);
      expect(DssMetrics.salaryGap([], 3), isNull);
      expect(DssMetrics.salaryGap([1], null), isNull);
    });
  });

  group('rates', () {
    test('unemployment counts No and Never Employed', () {
      final p = DssMetrics.unemployment([
        _a(q16: 'Yes'),
        _a(q16: 'No'),
        _a(q16: 'Never Employed'),
        _a(q16: 'Yes'),
        _a(),
      ])!;
      expect(p.hits, 2);
      expect(p.total, 4);
      expect(p.rate, 0.5);
      expect(DssMetrics.unemployment([_a()]), isNull);
    });

    test('aligned share is the complement of mismatch share', () {
      final r = DssMetrics.relatedness([
        _a(q24: 'Yes', q32: 'Yes'),
        _a(q24: 'No', q32: 'Yes', q34: 'More OJT hours'),
        _a(q32: 'Yes'),
        _a(q32: 'No'),
        _a(),
      ])!;
      expect(r.answered, 4);
      expect(r.mismatch, 2);
      expect(r.alignedShare.rate + r.mismatchShare.rate, closeTo(1, 1e-9));
      expect(r.mismatchSuggestions, ['More OJT hours']);
    });

    test('clerical counts only presently employed with a level', () {
      final p = DssMetrics.clerical([
        _a(q16: 'Yes', level: DssMetrics.clericalLevel),
        _a(q16: 'Yes', level: 'Professional, Technical or Supervisory'),
        _a(q16: 'No', level: DssMetrics.clericalLevel),
        _a(q16: 'Yes'),
      ])!;
      expect(p.hits, 1);
      expect(p.total, 2);
    });

    test('long time to first job uses 1+ year brackets', () {
      expect(
        DssMetrics.longTimeToJob.contains('1 year to less than 2 years'),
        isTrue,
      );
      expect(DssMetrics.longTimeToJob.contains('Less than a month'), isFalse);
      final p = DssMetrics.longTimeToFirstJob([
        _a(q29: 'Less than a month'),
        _a(q29: '1 year to less than 2 years'),
        _a(q29: '2 years to less than 3 years'),
        _a(q29: '1 to 6 months'),
      ])!;
      expect(p.rate, 0.5);
    });
  });

  group('margin of error', () {
    test('Wilson interval matches known values', () {
      final ci = DssMetrics.wilson(7, 25);
      expect(ci.low, closeTo(0.1428, 0.001));
      expect(ci.high, closeTo(0.4758, 0.001));
    });

    test('Wilson interval stays inside 0–1 at the extremes', () {
      final none = DssMetrics.wilson(0, 10);
      expect(none.low, 0);
      expect(none.high, closeTo(0.2775, 0.001));
      final all = DssMetrics.wilson(10, 10);
      expect(all.high, 1);
      expect(all.low, closeTo(0.7225, 0.001));
      expect(DssMetrics.wilson(0, 0), (low: 0.0, high: 1.0));
    });

    test('small groups get wider intervals', () {
      final small = DssMetrics.wilson(3, 10);
      final large = DssMetrics.wilson(30, 100);
      expect(small.high - small.low, greaterThan(large.high - large.low));
    });

    test('certainty uses the lower bound for gte rules', () {
      expect(
        DssMetrics.certainty('gte', 0.25, DssMetrics.wilson(7, 25)),
        'possible',
      );
      expect(
        DssMetrics.certainty('gte', 0.25, DssMetrics.wilson(30, 60)),
        'confirmed',
      );
    });

    test('certainty uses the upper bound for lt rules', () {
      expect(DssMetrics.certainty('lt', 0.4, (low: 0.1, high: 0.3)), 'confirmed');
      expect(DssMetrics.certainty('lt', 0.4, (low: 0.2, high: 0.5)), 'possible');
    });
  });

  group('roll-up', () {
    test('large batches stay at course × batch level', () {
      final plan = DssRollup.plan({
        'BSIT': {'2023': 25, '2024': 30},
      }, 20);
      expect(plan.batches, {'BSIT|2023', 'BSIT|2024'});
      expect(plan.courses, isEmpty);
      expect(plan.institution, isFalse);
    });

    test('small batches roll up to their course', () {
      final plan = DssRollup.plan({
        'BSIT': {'2023': 8, '2024': 7, '2025': 25},
      }, 20);
      expect(plan.batches, {'BSIT|2025'});
      expect(plan.courses, {'BSIT'});
      expect(plan.institution, isFalse);
    });

    test('small courses roll up to the institution', () {
      final sizes = {
        'BSIT': {'2023': 6, '2024': 5},
        'BSED': {'2024': 9},
        'BSBA': {'2023': 12, '2024': 10},
      };
      final plan = DssRollup.plan(sizes, 20);
      expect(plan.batches, isEmpty);
      expect(plan.courses, {'BSBA'});
      expect(plan.institution, isTrue);
      expect(DssRollup.smallCourses(sizes, 20), {'BSIT': 11, 'BSED': 9});
      expect(DssRollup.smallBatches(sizes, 'BSBA', 20), {
        '2023': 12,
        '2024': 10,
      });
    });

    test('institution is skipped when even the total is too small', () {
      final plan = DssRollup.plan({
        'BSIT': {'2023': 4},
        'BSED': {'2024': 5},
      }, 20);
      expect(plan.courses, isEmpty);
      expect(plan.institution, isFalse);
    });

    test('minimum of 0 never rolls up', () {
      final plan = DssRollup.plan({
        'BSIT': {'2023': 1},
      }, 0);
      expect(plan.batches, {'BSIT|2023'});
      expect(plan.courses, isEmpty);
      expect(plan.institution, isFalse);
    });
  });

  group('trends', () {
    test('change interval brackets the observed change', () {
      const now = DssProportion(hits: 15, total: 50);
      const before = DssProportion(hits: 5, total: 50);
      final ci = DssMetrics.changeInterval(now, before);
      // Newcombe hybrid score interval for 0.30 − 0.10.
      expect(ci.low, closeTo(0.044, 0.005));
      expect(ci.high, closeTo(0.345, 0.005));
      expect(DssMetrics.certainty('gte', 0.10, ci), 'possible');
      expect(DssMetrics.certainty('gte', 0.04, ci), 'confirmed');
    });

    test('pair plan compares batches surveyed in both waves', () {
      final plan = DssRollup.planChange(
        {
          'BSIT': {'2023': 12, '2024': 15},
        },
        {
          'BSIT': {'2023': 11, '2024': 10},
        },
        10,
      );
      expect(plan.batches, {'BSIT|2023', 'BSIT|2024'});
      expect(plan.courses, isEmpty);
      expect(plan.institution, isFalse);
    });

    test('batches in only one wave roll up to the course', () {
      final plan = DssRollup.planChange(
        {
          'BSIT': {'2023': 12, '2025': 9},
        },
        {
          'BSIT': {'2023': 11, '2024': 6},
        },
        10,
      );
      expect(plan.batches, {'BSIT|2023'});
      expect(plan.courses, {'BSIT'});
    });

    test('courses too small in either wave roll up to the institution', () {
      final plan = DssRollup.planChange(
        {
          'BSIT': {'2023': 4},
          'BSED': {'2023': 8},
        },
        {
          'BSIT': {'2023': 6},
          'BSED': {'2023': 5},
        },
        10,
      );
      expect(plan.batches, isEmpty);
      expect(plan.courses, isEmpty);
      expect(plan.institution, isTrue);
    });
  });

  group('report card', () {
    test('snapshot computes headline measures', () {
      final s = DssProgramSnapshot.from([
        _a(q16: 'Yes', q31: 'P15,000.00 to less than P20,000.00'),
        _a(q16: 'No', q31: 'P10,000.00 to less than P15,000.00'),
        _a(q16: 'Yes', q31: 'P15,000.00 to less than P20,000.00'),
      ], roster: 6);
      expect(s.responseRate, 0.5);
      expect(s.notEmployed!.hits, 1);
      expect(s.medianSalaryLabel, 'P15,000.00 to less than P20,000.00');
      expect(DssProgramSnapshot.from([], roster: 0).medianSalaryLabel, '-');
    });

    test('PDF builds with and without data', () async {
      final now = DateTime(2026, 10, 3);
      final snap = DssProgramSnapshot.from([
        _a(q16: 'No'),
        _a(q16: 'Yes'),
      ], roster: 4);
      final flag = DssFlag(
        id: 'f1',
        ruleId: 'UNEMPLOYMENT_HIGH',
        course: 'BSIT',
        batchYear: 'All',
        cohortLevel: DssCohortLevel.course,
        surveyId: 's1',
        surveyTitle: 'Wave 2',
        metricValue: 0.5,
        thresholdSnapshot: 0.25,
        sampleN: 2,
        confidence: DssConfidence.low,
        status: DssFlagStatus.open,
        title: 'High unemployment',
        body: '',
        recommendedAction: '',
        evidence: const {'ci_low': 0.09, 'ci_high': 0.91},
        createdAt: now,
        updatedAt: now,
      );
      final full = await DssReportCardPdf.build(
        DssReportCardData(
          course: 'BSIT',
          generatedAt: now,
          waves: [
            DssReportCardWave(
              title: 'Wave 1',
              date: now,
              program: snap,
              institution: snap,
            ),
            DssReportCardWave(
              title: 'Wave 2 \u2014 \u201cfinal\u201d',
              date: now,
              program: snap,
              institution: snap,
            ),
          ],
          flags: [flag],
          actions: [
            DssReportCardAction(
              flag: flag,
              note: DssFlagNote(
                id: 'n1',
                flagId: 'f1',
                authorName: 'Admin',
                note: 'Sent 3 job postings to 4 alumni.',
                createdAt: now,
                eventType: DssNoteEventType.action,
              ),
            ),
          ],
        ),
      );
      final empty = await DssReportCardPdf.build(
        DssReportCardData(
          course: 'BSED',
          generatedAt: now,
          waves: const [],
          flags: const [],
          actions: const [],
        ),
      );
      expect(String.fromCharCodes(full.take(4)), '%PDF');
      expect(full.length, greaterThan(empty.length));
    });
  });

  group('helpers', () {
    test('crosses respects operator', () {
      expect(DssMetrics.crosses('gte', 0.25, 0.25), isTrue);
      expect(DssMetrics.crosses('gt', 0.25, 0.25), isFalse);
      expect(DssMetrics.crosses('lt', 0.3, 0.4), isTrue);
      expect(DssMetrics.crosses('lte', 0.4, 0.4), isTrue);
    });

    test('single reads list and blank values', () {
      expect(DssMetrics.single(['Yes']), 'Yes');
      expect(DssMetrics.single([]), isNull);
      expect(DssMetrics.single('  '), isNull);
    });

    test('median handles odd and even lengths', () {
      expect(DssMetrics.median([3, 1, 2]), 2);
      expect(DssMetrics.median([1, 2, 3, 4]), 2.5);
    });
  });

  group('curriculum suggestions', () {
    test('skips placeholders and blank answers', () {
      final texts = DssMetrics.curriculumSuggestions([
        {'ched_34': 'More OJT hours'},
        {'ched_34': 'N/A'},
        {'ched_34': 'none.'},
        {'ched_34': '  '},
        {},
        {'ched_34': 'Update  the\nsoftware we use'},
      ]);
      expect(texts, ['More OJT hours', 'Update the software we use']);
    });

    test('keyword themes keep the indexes they cover', () {
      final themes = DssMetrics.keywordThemes([
        'Longer internship',
        'More OJT with companies',
        'Better English classes',
      ]);
      final ojt = themes.firstWhere((t) => t.label == 'Internships / OJT');
      expect(ojt.indexes, [0, 1]);
      expect(themes.first.label, 'Internships / OJT');
      expect(
        themes.any((t) => t.label == 'Communication and English'),
        isTrue,
      );
    });

    test('Q33 competency counts ignore the Other option', () {
      final counts = DssMetrics.usefulCompetencies([
        {'ched_33': ['Communication skills', 'Other skills, please specify']},
        {'ched_33': ['Communication skills', 'Problem-solving skills']},
        {'ched_33': 'Problem-solving skills'},
      ]);
      expect(counts, {'Communication skills': 2, 'Problem-solving skills': 2});
    });

    test('AI reply keeps only valid suggestion numbers', () {
      const raw = '```json\n{"themes":['
          '{"label":"**More OJT**","items":[1,3,3,99]},'
          '{"label":"Ghost theme","items":[0,42]},'
          '{"label":"Updated tools","items":["2"]},'
          '{"label":"more ojt","items":[2]}'
          ']}\n```';
      final themes = DssSuggestionThemeService.parseAiThemes(raw, 3);
      expect(themes.map((t) => t.label), ['More OJT', 'Updated tools']);
      expect(themes.first.indexes, [0, 2]);
      expect(themes.last.indexes, [1]);
    });

    test('AI reply that is not JSON yields no themes', () {
      expect(DssSuggestionThemeService.parseAiThemes('Sorry, no.', 3), isEmpty);
    });

    test('summary quotes come from the source texts', () {
      const summary = DssSuggestionSummary(
        respondents: 4,
        texts: ['A', 'B', 'C'],
        themes: [
          DssTheme(label: 'X', indexes: [0, 2]),
          DssTheme(label: 'Y', indexes: [2]),
        ],
        competencies: {},
      );
      expect(summary.quotes(summary.themes.first), ['A', 'C']);
      expect(summary.themed, 2);
    });
  });
}
