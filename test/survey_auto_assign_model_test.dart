import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> row({Map<String, dynamic> data = const {}}) => {
        'id': 's1',
        'title': 'Tracer 2026',
        'status': 'published',
        'created_by': 'admin',
        'created_at': '2026-01-01T00:00:00Z',
        'data': data,
      };

  group('Survey.autoAssignNewAlumni', () {
    test('defaults to true when the key is absent', () {
      expect(Survey.fromSupabaseRow(row()).autoAssignNewAlumni, isTrue);
    });

    test('reads an explicit opt-out', () {
      final s = Survey.fromSupabaseRow(
        row(data: {'autoAssignNewAlumni': false}),
      );
      expect(s.autoAssignNewAlumni, isFalse);
    });

    test('round-trips through toSupabaseRow and copyWith', () {
      final s = Survey.fromSupabaseRow(row())
          .copyWith(autoAssignNewAlumni: false);
      final out = s.toSupabaseRow(createdBySupabaseId: 'admin');
      expect((out['data'] as Map)['autoAssignNewAlumni'], isFalse);
      expect(Survey.fromSupabaseRow(out).autoAssignNewAlumni, isFalse);
    });
  });
}
