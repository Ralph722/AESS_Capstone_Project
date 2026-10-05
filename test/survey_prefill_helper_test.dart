import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/data/survey_prefill_helper.dart';
import 'package:flutter_test/flutter_test.dart';

EmploymentRecord _record({
  required String employmentStatus,
  String? employmentType,
  String? position,
}) {
  return EmploymentRecord(
    id: '1',
    userId: 'u1',
    userName: 'Test User',
    userEmail: 'test@example.com',
    schoolId: 'S1',
    employmentStatus: employmentStatus,
    contactNumber: '09123456789',
    employmentType: employmentType,
    position: position,
  );
}

void main() {
  group('SurveyPrefillHelper', () {
    test('unemployed maps to No for presently employed', () {
      final record = _record(employmentStatus: 'Unemployed');
      expect(SurveyPrefillHelper.isEmployed(record), isFalse);
      expect(SurveyPrefillHelper.presentlyEmployed(record), 'No');
      final values = SurveyPrefillHelper.valuesFromEmployment(record);
      expect(values['employment.presentlyEmployed'], 'No');
      expect(values['employment.position'], isNull);
    });

    test('employed maps to Yes and includes job fields', () {
      final record = _record(
        employmentStatus: 'Employed',
        employmentType: 'Full-time',
        position: 'Developer',
      );
      expect(SurveyPrefillHelper.isEmployed(record), isTrue);
      expect(SurveyPrefillHelper.presentlyEmployed(record), 'Yes');
      final values = SurveyPrefillHelper.valuesFromEmployment(record);
      expect(values['employment.presentlyEmployed'], 'Yes');
      expect(values['employment.employmentStatus'], 'Regular or Permanent');
      expect(values['employment.position'], 'Developer');
    });

    test('never employed is not employed and keeps its CHED answer', () {
      final record = _record(employmentStatus: 'Never Employed');
      expect(SurveyPrefillHelper.isEmployed(record), isFalse);
      expect(SurveyPrefillHelper.presentlyEmployed(record), 'Never Employed');
    });

    test('CHED Q18 answers from GTS rows map back unchanged', () {
      for (final type in const [
        'Regular or Permanent',
        'Temporary',
        'Casual',
        'Contractual',
        'Self-employed',
      ]) {
        final record = _record(
          employmentStatus: 'Employed',
          employmentType: type,
        );
        expect(SurveyPrefillHelper.employmentStatusType(record), type);
      }
    });

    test('matchOption does not map No to Permanent', () {
      final options = [
        'Regular or Permanent',
        'Contractual',
        'Yes',
        'No',
        'Never Employed',
      ];
      expect(
        SurveyPrefillHelper.matchOption('No', options),
        'No',
      );
    });
  });
}
