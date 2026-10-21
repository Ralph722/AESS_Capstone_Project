import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';

Map<String, dynamic> _row(String user, String survey, [String? status]) => {
  'user_id': user,
  'survey_id': survey,
  if (status != null) 'status': status,
};

void main() {
  group('SurveyService.chedProgressFromRows', () {
    test('counts assigned and submitted waves per user', () {
      final progress = SurveyService.chedProgressFromRows(
        assignments: [
          _row('u1', 's1', 'completed'),
          _row('u1', 's2', 'inProgress'),
          _row('u2', 's1', 'notStarted'),
        ],
        responses: [_row('u1', 's1')],
      );
      expect(progress['u1'], (assigned: 2, submitted: 1));
      expect(progress['u2'], (assigned: 1, submitted: 0));
    });

    test('a completed assignment counts as submitted without a response', () {
      final progress = SurveyService.chedProgressFromRows(
        assignments: [_row('u1', 's1', 'completed')],
        responses: const [],
      );
      expect(progress['u1'], (assigned: 1, submitted: 1));
    });

    test('a submission without an assignment counts both ways', () {
      final progress = SurveyService.chedProgressFromRows(
        assignments: const [],
        responses: [_row('u1', 's1')],
      );
      expect(progress['u1'], (assigned: 1, submitted: 1));
    });

    test('duplicate rows and blank ids are ignored', () {
      final progress = SurveyService.chedProgressFromRows(
        assignments: [
          _row('u1', 's1', 'completed'),
          _row('u1', 's1', 'completed'),
          _row('', 's1', 'completed'),
          _row('u1', ''),
        ],
        responses: [_row('u1', 's1'), _row('u1', 's1')],
      );
      expect(progress, {
        'u1': (assigned: 1, submitted: 1),
      });
    });

    test('empty input gives an empty map', () {
      expect(
        SurveyService.chedProgressFromRows(
          assignments: const [],
          responses: const [],
        ),
        isEmpty,
      );
    });
  });
}
