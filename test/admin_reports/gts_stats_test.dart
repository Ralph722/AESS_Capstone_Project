import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';

void main() {
  GtsField field(String key) => GtsFieldDictionary.byKey(key)!;

  const current = '30.2. Current or Present Job';
  const respondents = [
    GtsRespondent(
      userId: 'u1',
      surveyId: 'w1',
      course: 'BSIT',
      yearGraduated: '2024',
      answers: {
        'ched_16': 'Yes',
        'ched_18': 'Regular or Permanent',
        'ched_22': 'Yes',
        'ched_24a': 'Yes',
        'ched_29': 'Less than a month',
        'ched_30': {
          'Professional, Technical or Supervisory': {current: true},
        },
        'ched_31': 'P10,000.00 to less than P15,000.00',
        'ched_32': 'Yes',
        'ched_33': ['Communication skills', 'Information Technology skills'],
        'ched_34': 'More internships',
      },
    ),
    GtsRespondent(
      userId: 'u2',
      surveyId: 'w1',
      course: 'BSIT',
      yearGraduated: '2023',
      answers: {
        'ched_16': 'Yes',
        'ched_18': 'Part-time',
        'ched_22': 'No',
        // Left over from an earlier edit; item 24 is hidden when 22 = No.
        'ched_24a': 'Yes',
        'ched_29': '1 to 6 months',
        'ched_31': 'P15,000.00 to less than P20,000.00',
        'ched_32': 'No',
        'ched_15a': [
          {'Title of Training or Advance Study': 'CCNA'},
        ],
      },
    ),
    GtsRespondent(
      userId: 'u3',
      surveyId: 'w1',
      course: 'BSCS',
      answers: {
        'ched_16': 'No',
        'ched_17': ['No job opportunity', 'Lack of work experience'],
        'ched_15a': [
          {'Title of Training or Advance Study': '  '},
        ],
      },
    ),
    GtsRespondent(
      userId: 'u4',
      surveyId: 'w1',
      yearGraduated: '2024',
      answers: {'ched_16': 'Never Employed'},
    ),
    GtsRespondent(
      userId: 'u5',
      surveyId: 'w1',
      course: 'BSIT',
      answers: {
        'ched_16': 'Yes',
        'ched_22': 'Yes',
        'ched_29': 'Others, please specify',
        'ched_31': 'P10,000.00 to less than P15,000.00',
      },
    ),
  ];

  group('distribution', () {
    test('item 16 counts match the DSS employment breakdown', () {
      final d = GtsStats.distribution(field('ched_16'), respondents);
      expect(d.categories.map((c) => c.label), ['Yes', 'No', 'Never Employed']);
      expect(d.categories.map((c) => c.count), [3, 1, 1]);
      expect((d.respondents, d.eligible, d.answered), (5, 5, 5));

      final answers = respondents.map((r) => r.answers);
      expect({
        for (final c in d.categories) c.label: c.count,
      }, DssMetrics.employmentBreakdown(answers));
      final dss = DssMetrics.unemployment(answers)!;
      final notEmployed = d.count('No') + d.count('Never Employed');
      expect(notEmployed, dss.hits);
      expect(d.answered, dss.total);
    });

    test('skip logic separates not asked from missing', () {
      final d = GtsStats.distribution(field('ched_24a'), respondents);
      expect(d.eligible, 2, reason: 'u1 and u5 have item 22 = Yes');
      expect(d.answered, 1);
      expect(d.missing, 1);
      expect(d.notAsked, 3);
      expect(d.count('Yes'), 1, reason: 'u2\'s hidden answer is ignored');
    });

    test('multi-select counts each pick once per respondent', () {
      final d = GtsStats.distribution(field('ched_17'), respondents);
      expect(d.eligible, 2);
      expect(d.answered, 1);
      expect(d.sharesCanExceed100, isTrue);
      expect(
        d.share('No job opportunity', GtsCalculation.shareOfAnswered).rate,
        1.0,
      );
      expect(
        d.share('No job opportunity', GtsCalculation.shareOfEligible).rate,
        0.5,
      );
    });

    test('values outside the option list are kept after the options', () {
      final d = GtsStats.distribution(field('ched_18'), respondents);
      expect(d.categories.last.label, 'Part-time');
      expect(d.count('Part-time'), 1);
      expect(d.count('Regular or Permanent'), 1);
      expect(d.answered, 2);
      expect(d.eligible, 3);
    });

    test('grid column counts the ticked row', () {
      final d = GtsStats.distribution(
        field('ched_30'),
        respondents,
        gridColumn: current,
      );
      expect(d.count('Professional, Technical or Supervisory'), 1);
      expect(d.answered, 1);
      expect(d.eligible, 3);
      expect(d.sharesCanExceed100, isFalse);
    });

    test('roster fields group with Unknown last and years in order', () {
      final byCourse = GtsStats.distribution(field('course'), respondents);
      expect(byCourse.categories.map((c) => c.label), [
        'BSCS',
        'BSIT',
        'Unknown',
      ]);
      expect(byCourse.count('BSIT'), 3);

      final byYear = GtsStats.distribution(
        field('year_graduated'),
        respondents,
      );
      expect(byYear.categories.map((c) => c.label), [
        '2023',
        '2024',
        'Unknown',
      ]);
      expect(byYear.count('Unknown'), 2);
    });

    test('open text and tables only count answers', () {
      final text = GtsStats.distribution(field('ched_34'), respondents);
      expect(text.answered, 1);
      expect(text.categories, isEmpty);

      final table = GtsStats.distribution(field('ched_15a'), respondents);
      expect(table.answered, 1, reason: 'blank rows do not count');
    });
  });

  group('median bracket', () {
    test('splits across two brackets and leaves out Others', () {
      final d = GtsStats.distribution(field('ched_29'), respondents);
      final m = GtsStats.medianBracket(d)!;
      expect(m.n, 2);
      expect(m.label, 'Between Less than a month and 1 to 6 months');
    });

    test('single middle bracket', () {
      final d = GtsStats.distribution(field('ched_31'), respondents);
      final m = GtsStats.medianBracket(d)!;
      expect(m.n, 3);
      expect(m.label, 'P10,000.00 to less than P15,000.00');
    });

    test('only for ordinal fields', () {
      final d = GtsStats.distribution(field('ched_16'), respondents);
      expect(GtsStats.medianBracket(d), isNull);
    });
  });

  group('evidence', () {
    test('uses DSS sample-size labels and suppression', () {
      final q16 = GtsStats.distribution(field('ched_16'), respondents);
      expect(
        q16.evidence(GtsCalculation.shareOfAnswered),
        DssEvidenceStrength.watch,
      );
      expect(q16.isSuppressed(GtsCalculation.shareOfAnswered), isFalse);

      final q24 = GtsStats.distribution(field('ched_24a'), respondents);
      expect(
        q24.evidence(GtsCalculation.shareOfAnswered),
        DssEvidenceStrength.insufficient,
      );
      expect(q24.isSuppressed(GtsCalculation.shareOfAnswered), isTrue);
    });

    test('ranges match the DSS Wilson interval', () {
      final d = GtsStats.distribution(field('ched_16'), respondents);
      expect(
        d.interval('Yes', GtsCalculation.shareOfAnswered),
        DssMetrics.wilson(3, 5),
      );
    });
  });

  test('read reuses a precomputed visible set', () {
    final r = respondents[1];
    final a = GtsStats.read(field('ched_24a'), r, visible: const {});
    expect(a.state, GtsAnswerState.notAsked);
    final b = GtsStats.read(field('ched_24a'), r, visible: const {'ched_24a'});
    expect(b.values, ['Yes']);
  });
}
