import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_templates.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_tab_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gts_fixtures.dart';

GtsRespondent _r(
  String user,
  String wave,
  String status, {
  String course = 'BSIT',
  String year = '2023',
  bool onRoster = true,
}) => GtsRespondent(
  userId: user,
  surveyId: wave,
  course: course,
  yearGraduated: year,
  onActiveRoster: onRoster,
  answers: {'ched_16': status},
);

void main() {
  final waves = <TracerWave>[
    (
      surveyId: 'w1',
      respondents: [
        _r('a', 'w1', 'No'),
        _r('b', 'w1', 'Yes'),
        _r('off', 'w1', 'No', onRoster: false),
      ],
    ),
    (
      surveyId: 'w2',
      respondents: [_r('a', 'w2', 'Yes'), _r('c', 'w2', 'Never Employed')],
    ),
  ];

  test('all waves: each graduate once, from their latest wave', () {
    final row = TracerTabStats(waves: waves).employment;
    expect(row.answered, 3);
    expect(TracerTabStats.yes(row), 2);
  });

  test('one wave: that wave only', () {
    final row = TracerTabStats(waves: waves, surveyId: 'w1').employment;
    expect(row.answered, 2);
    expect(TracerTabStats.yes(row), 1);
  });

  test('graduates off the roster are not counted', () {
    final row = TracerTabStats(waves: waves, surveyId: 'w1').employment;
    expect(row.respondents, 2);
  });

  test('course and batch filters ignore case', () {
    final stats = TracerTabStats(
      waves: [
        (
          surveyId: 'w1',
          respondents: [
            _r('a', 'w1', 'Yes'),
            _r('b', 'w1', 'Yes', course: 'BSCS'),
            _r('c', 'w1', 'Yes', year: '2024'),
          ],
        ),
      ],
      course: 'bsit',
      batch: '2023',
    );
    expect(stats.employment.respondents, 1);
  });

  test('per-wave employment keeps each wave\'s own answers, oldest first', () {
    final byWave = TracerTabStats(waves: waves).employmentByWave();
    expect([for (final w in byWave) w.surveyId], ['w1', 'w2']);
    expect([for (final w in byWave) TracerTabStats.yes(w.row)], [1, 1]);
    expect([for (final w in byWave) w.row.answered], [2, 2]);
  });

  test('employed-only cards count item 16 = Yes graduates', () {
    final stats = TracerTabStats(
      waves: [(surveyId: 'w1', respondents: gtsFixtures())],
    );
    final types = stats.run('ched_18', employedOnly: true).total;
    expect(types.respondents, TracerTabStats.yes(stats.employment));
  });

  test('groups under 5 answers are small', () {
    final row = TracerTabStats(waves: waves).employment;
    expect(row.isSmall, isTrue);
    final big = TracerTabStats(
      waves: [(surveyId: 'w1', respondents: gtsFixtures())],
    ).employment;
    expect(big.isSmall, isFalse);
  });

  test('employment by course matches the builder template', () {
    final respondents = gtsFixtures(surveyId: 'w1');
    final stats = TracerTabStats(
      waves: [(surveyId: 'w1', respondents: respondents)],
      surveyId: 'w1',
    );
    final tab = stats.run('ched_16', groupBy: GtsFieldDictionary.course);
    final builder = GtsReportEngine.run(
      GtsReportTemplates.byKey('employment_by_course')!.forWaves(['w1']),
      respondents,
    );
    List<List<Object>> table(GtsReportResult r) => [
      for (final row in [...r.rows, r.total])
        [...row.groupValues, row.answered, ...row.counts.values],
    ];
    expect(table(tab), table(builder));
  });

  test('membersOf lists the graduates behind a group', () {
    final stats = TracerTabStats(waves: waves);
    expect(
      [
        for (final r in stats.membersOf(GtsFieldDictionary.course, 'BSIT'))
          r.userId,
      ]..sort(),
      ['a', 'b', 'c'],
    );
  });
}
