import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_data_service.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';

GtsRespondent person(
  String id, {
  String wave = 'w1',
  String course = 'BSIT',
  String year = '2024',
  bool roster = true,
  Map<String, dynamic> answers = const {},
}) => GtsRespondent(
  userId: id,
  surveyId: wave,
  course: course,
  yearGraduated: year,
  onActiveRoster: roster,
  answers: answers,
);

Map<String, dynamic> employed({String place = 'Local', String? firstJob}) => {
  'ched_16': 'Yes',
  'ched_21': place,
  'ched_22': ?firstJob,
};

void main() {
  const q16 = GtsReportConfig(surveyIds: ['w1'], measure: 'ched_16');
  final when = DateTime(2026, 10, 12);

  final people = [
    for (var i = 0; i < 6; i++)
      person('a$i', answers: employed(place: i < 4 ? 'Local' : 'Abroad')),
    person('b1', year: '2023', answers: {'ched_16': 'No'}),
    person(
      'b2',
      year: '2023',
      answers: employed(firstJob: 'Yes'),
    ),
    person('c1', course: '', year: '', answers: {'ched_16': 'Never Employed'}),
    person('d1', roster: false, answers: {'ched_16': 'No'}),
    person('w2', wave: 'w2', answers: {'ched_16': 'No'}),
  ];

  GtsReportResult run(GtsReportConfig c, [List<GtsRespondent>? input]) =>
      GtsReportEngine.run(
        c,
        input ?? people,
        waveLabels: const {'w1': '2025 tracer', 'w2': '2026 tracer'},
        now: when,
      );

  test('counts one wave and matches the DSS unemployment rate', () {
    final r = run(q16);
    expect(r.isGrouped, isFalse);
    expect(r.rows, isEmpty);
    expect(r.generatedAt, when);
    expect(r.categories, ['Yes', 'No', 'Never Employed']);
    expect(r.total.counts, {'Yes': 7, 'No': 2, 'Never Employed': 1});
    expect(r.total.denominator, 10);

    final dss = DssMetrics.unemployment(
      people.where((p) => p.surveyId == 'w1').map((p) => p.answers),
    )!;
    final notEmployed =
        r.total.cell('No').count + r.total.cell('Never Employed').count;
    expect(notEmployed, dss.hits);
    expect(r.total.denominator, dss.total);

    final yes = r.total.cell('Yes');
    expect(yes.share, closeTo(0.7, 1e-9));
    expect(yes.interval, DssMetrics.wilson(7, 10));
    expect(r.total.evidence, DssEvidenceStrength.limited);
  });

  test('roster-linked population matches the DSS (course required)', () {
    final r = run(q16.copyWith(population: GtsPopulation.rosterLinked));
    expect(r.total.respondents, 8, reason: 'drops c1 (no course), d1');
  });

  test('filters keep only matching graduates who were asked', () {
    final r = run(
      q16.copyWith(
        filters: const [
          GtsReportFilter(field: 'ched_21', values: ['Abroad']),
        ],
      ),
    );
    expect(r.total.respondents, 2);
    expect(r.total.counts['Yes'], 2);
    expect(r.validation.has('filter_conditional'), isTrue);
  });

  test('groups by year in order with Unknown last and hides small shares', () {
    final r = run(q16.copyWith(groupBy: ['year_graduated']));
    expect(r.rows.map((x) => x.groupValues.single), [
      '2023',
      '2024',
      'Unknown',
    ]);
    final y2023 = r.rows.first;
    expect(y2023.respondents, 2);
    expect(y2023.cell('No').isSuppressed, isTrue);
    expect(y2023.cell('No').share, isNull);
    expect(y2023.cell('No').count, 1, reason: 'counts stay visible');
    expect(y2023.evidence, DssEvidenceStrength.insufficient);

    final y2024 = r.rows[1];
    expect(y2024.respondents, 7);
    expect(y2024.cell('Yes').share, closeTo(6 / 7, 1e-9));
    expect(r.total.respondents, 10, reason: 'total row is not grouped');
  });

  test('wave group uses selection order and wave names', () {
    final r = run(
      const GtsReportConfig(
        surveyIds: ['w2', 'w1'],
        measure: 'ched_16',
        groupBy: ['survey'],
      ),
    );
    expect(r.rows.map((x) => x.groupValues.single), [
      '2026 tracer',
      '2025 tracer',
    ]);
    expect(r.rows.first.respondents, 1);
  });

  test('conditional group-by keeps not-asked and blank groups last', () {
    final r = run(q16.copyWith(groupBy: ['ched_22']));
    expect(r.rows.map((x) => x.groupValues.single), [
      'Yes',
      gtsNotAnsweredLabel,
      gtsNotAskedLabel,
    ]);
    expect(r.rows[1].respondents, 6, reason: 'employed, item 22 blank');
    expect(r.rows[2].respondents, 3, reason: 'not employed, never asked');
  });

  test('two group-bys nest in order', () {
    final r = run(q16.copyWith(groupBy: ['course', 'year_graduated']));
    expect(r.rows.map((x) => x.groupValues), [
      ['BSIT', '2023'],
      ['BSIT', '2024'],
      ['Unknown', 'Unknown'],
    ]);
  });

  test('top N folds the rest and counts each graduate once', () {
    List<String> reasons(int i) => switch (i % 4) {
      0 => ['No job opportunity'],
      1 => ['No job opportunity', 'Lack of work experience'],
      2 => ['Health-related reason(s)', 'Did not look for a job'],
      _ => ['Advance or further study'],
    };
    final input = [
      for (var i = 0; i < 8; i++)
        person('r$i', answers: {'ched_16': 'No', 'ched_17': reasons(i)}),
    ];
    final r = run(
      const GtsReportConfig(
        surveyIds: ['w1'],
        measure: 'ched_17',
        topN: 2,
        sortBy: GtsSortBy.count,
        sortDescending: true,
      ),
      input,
    );
    expect(r.categories, [
      'No job opportunity',
      'Advance or further study',
      gtsAllOtherLabel,
    ]);
    expect(r.hiddenCategories, contains('Did not look for a job'));
    expect(r.total.counts['No job opportunity'], 4);
    expect(r.total.counts['Advance or further study'], 2);
    expect(
      r.total.counts[gtsAllOtherLabel],
      4,
      reason:
          'r1 and r5 also lacked experience; r2 and r6 had two folded '
          'reasons but count once',
    );
  });

  test('sorting by label and keeping questionnaire order on ties', () {
    final byLabel = run(q16.copyWith(sortBy: GtsSortBy.label));
    expect(byLabel.categories, ['Never Employed', 'No', 'Yes']);

    final byCount = run(
      q16.copyWith(sortBy: GtsSortBy.count, sortDescending: true),
    );
    expect(byCount.categories, ['Yes', 'No', 'Never Employed']);

    final reversed = run(q16.copyWith(sortDescending: true));
    expect(reversed.categories, ['Never Employed', 'No', 'Yes']);
  });

  test('median bracket per group', () {
    final input = [
      person('m1', answers: {...employed(), 'ched_31': 'Below P5,000.00'}),
      person(
        'm2',
        answers: {
          ...employed(),
          'ched_31': 'P10,000.00 to less than P15,000.00',
        },
      ),
      person(
        'm3',
        answers: {
          ...employed(),
          'ched_31': 'P10,000.00 to less than P15,000.00',
        },
      ),
    ];
    final r = run(
      const GtsReportConfig(
        surveyIds: ['w1'],
        measure: 'ched_31',
        calculation: GtsCalculation.medianBracket,
      ),
      input,
    );
    expect(r.total.median!.label, 'P10,000.00 to less than P15,000.00');
    expect(r.total.cell('Below P5,000.00').share, isNull);
  });

  test('invalid configs are refused', () {
    expect(() => run(q16.copyWith(measure: 'ched_3')), throwsArgumentError);
  });

  test('view rows: latest submission per graduate per wave', () {
    final list = GtsReportDataService.respondentsFromRows([
      {
        'response_id': 'r1',
        'survey_id': 'w1',
        'user_id': 'u1',
        'submitted_at': '2026-01-01T00:00:00Z',
        'on_active_roster': true,
        'course': 'BSIT',
        'year_graduated': '2024',
        'answers': {'ched_16': 'No'},
      },
      {
        'response_id': 'r2',
        'survey_id': 'w1',
        'user_id': 'u1',
        'submitted_at': '2026-02-01T00:00:00Z',
        'on_active_roster': true,
        'course': 'BSIT',
        'year_graduated': '2024',
        'answers': {'ched_16': 'Yes'},
      },
      {
        'response_id': 'r3',
        'survey_id': 'w2',
        'user_id': 'u1',
        'submitted_at': '2025-01-01T00:00:00Z',
        'on_active_roster': false,
        'course': '',
        'year_graduated': '',
        'answers': null,
      },
      {'response_id': 'r4', 'survey_id': 'w1', 'user_id': null},
    ]);
    expect(list, hasLength(2));
    final w1 = list.firstWhere((r) => r.surveyId == 'w1');
    expect(w1.answers['ched_16'], 'Yes');
    expect(w1.isRosterLinked, isTrue);
    final w2 = list.firstWhere((r) => r.surveyId == 'w2');
    expect(w2.answers, isEmpty);
    expect(w2.isRosterLinked, isFalse);
  });

  test('an empty scope still returns a result', () {
    final r = run(q16, const []);
    expect(r.isEmpty, isTrue);
    expect(r.total.cell('Yes').isSuppressed, isTrue);
  });
}
