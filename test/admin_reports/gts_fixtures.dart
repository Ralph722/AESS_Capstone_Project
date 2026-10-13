import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

const gtsFixtureIndustries = [
  'Agriculture, Hunting and Forestry',
  'Fishing',
  'Mining and Quarrying',
  'Manufacturing',
  'Electricity, Gas and Water Supply',
  'Construction',
  'Hotels and Restaurants',
  'Transport Storage and Communication',
  'Financial Intermediation',
  'Real Estate, Renting and Business Activities',
  'Education',
  'Health and Social Work',
];

/// [count] roster-linked graduates split over [courses] and [years], plus
/// two graduates the DSS would not count (off the roster, no course).
List<GtsRespondent> gtsFixtures({
  int count = 40,
  List<String> courses = const ['BSIT', 'BSCS'],
  List<String> years = const ['2023', '2024'],
  String surveyId = 'w1',
}) {
  final out = <GtsRespondent>[];
  for (var i = 0; i < count; i++) {
    final employed = i % 4 != 0;
    final status = employed
        ? ChedGtsBuiltin.yes
        : (i % 8 == 0 ? ChedGtsBuiltin.no : ChedGtsBuiltin.neverEmployed);
    final firstJob = i % 3 != 0;
    out.add(
      GtsRespondent(
        userId: 'u$i',
        surveyId: surveyId,
        course: courses[(i * courses.length) ~/ count],
        yearGraduated: years[i % years.length],
        onActiveRoster: true,
        answers: {
          'ched_16': status,
          if (employed) ...{
            'ched_18': i % 5 == 0 ? 'Contractual' : 'Regular or Permanent',
            'ched_20': gtsFixtureIndustries[i % gtsFixtureIndustries.length],
            'ched_21': 'Local',
            'ched_22': firstJob ? ChedGtsBuiltin.yes : ChedGtsBuiltin.no,
            if (firstJob)
              'ched_24a': i % 2 == 0 ? ChedGtsBuiltin.yes : ChedGtsBuiltin.no,
          },
        },
      ),
    );
  }
  out
    ..add(
      GtsRespondent(
        userId: 'off-roster',
        surveyId: surveyId,
        course: courses.first,
        answers: const {'ched_16': 'No'},
      ),
    )
    ..add(
      GtsRespondent(
        userId: 'no-course',
        surveyId: surveyId,
        onActiveRoster: true,
        answers: const {'ched_16': 'No'},
      ),
    );
  return out;
}
