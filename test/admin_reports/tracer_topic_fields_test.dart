import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/application/tracer_tab_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

/// Ensures the Tracer topic redesign's added CHED measures aggregate.
void main() {
  GtsRespondent respondent(String uid, Map<String, dynamic> answers) {
    return GtsRespondent(
      userId: uid,
      surveyId: 'w1',
      course: 'BSIT',
      yearGraduated: '2024',
      onActiveRoster: true,
      answers: {
        'ched_16': ChedGtsBuiltin.yes,
        ...answers,
      },
    );
  }

  late TracerTabStats stats;

  setUp(() {
    stats = TracerTabStats(
      waves: [
        (
          surveyId: 'w1',
          respondents: [
            for (var i = 0; i < 6; i++)
              respondent('u$i', {
                'ched_22': ChedGtsBuiltin.yes,
                'ched_27': '1 to 6 months',
                'ched_28': 'Walk-in',
                'ched_23': ['Salaries and benefits'],
                'ched_24b': ['Career challenge'],
                'ched_25': ['Proximity to residence'],
                'ched_32': ChedGtsBuiltin.yes,
                'ched_33': ['Communication skills', 'Problem-solving skills'],
                'ched_15b': 'For professional development',
              }),
          ],
        ),
      ],
      surveyId: 'w1',
    );
  });

  test('school-to-work measures answer (Q22, Q27, Q28)', () {
    expect(stats.run('ched_22', employedOnly: true).total.answered, 6);
    expect(stats.run('ched_27', employedOnly: true).total.answered, 6);
    expect(stats.run('ched_28', employedOnly: true).total.answered, 6);
  });

  test('curriculum measures answer (Q32, Q33)', () {
    expect(stats.run('ched_32', employedOnly: true).total.answered, 6);
    expect(stats.run('ched_33').total.answered, greaterThan(0));
  });

  test('placement mobility measures answer (Q23, Q25, Q26)', () {
    // Stay reasons require first-job path; accepting requires related=Yes;
    // changing requires related=No (or not first job).
    final stay = TracerTabStats(
      waves: [
        (
          surveyId: 'w1',
          respondents: [
            for (var i = 0; i < 6; i++)
              respondent('s$i', {
                'ched_22': ChedGtsBuiltin.yes,
                'ched_23': ['Salaries and benefits'],
                'ched_24a': ChedGtsBuiltin.yes,
              }),
          ],
        ),
      ],
      surveyId: 'w1',
    );
    final accept = TracerTabStats(
      waves: [
        (
          surveyId: 'w1',
          respondents: [
            for (var i = 0; i < 6; i++)
              respondent('a$i', {
                'ched_22': ChedGtsBuiltin.yes,
                'ched_24a': ChedGtsBuiltin.yes,
                'ched_24b': ['Career challenge'],
              }),
          ],
        ),
      ],
      surveyId: 'w1',
    );
    final change = TracerTabStats(
      waves: [
        (
          surveyId: 'w1',
          respondents: [
            for (var i = 0; i < 6; i++)
              respondent('c$i', {
                'ched_22': ChedGtsBuiltin.yes,
                'ched_24a': ChedGtsBuiltin.no,
                'ched_25': ['Proximity to residence'],
              }),
          ],
        ),
      ],
      surveyId: 'w1',
    );
    expect(stay.run('ched_23').total.answered, greaterThan(0));
    expect(accept.run('ched_24b').total.answered, greaterThan(0));
    expect(change.run('ched_25').total.answered, greaterThan(0));
  });

  test('studies measure answers (Q15b)', () {
    expect(stats.run('ched_15b').total.answered, 6);
  });
}
