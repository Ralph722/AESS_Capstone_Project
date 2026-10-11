import 'package:alumni_system/core/utils/calendar_date.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarDate.toDb', () {
    test('keeps the picked day of a local date', () {
      expect(CalendarDate.toDb(DateTime(2000, 5, 10)), '2000-05-10');
    });

    test('keeps the day of a UTC date', () {
      expect(CalendarDate.toDb(DateTime.utc(2000, 5, 10)), '2000-05-10');
    });

    test('ignores the time of day', () {
      expect(CalendarDate.toDb(DateTime(1999, 1, 1, 23, 59)), '1999-01-01');
    });

    test('null stays null', () {
      expect(CalendarDate.toDb(null), isNull);
    });
  });

  group('birthday round trip', () {
    test('tracer submit keeps the answered birthday', () {
      var profile = const TracerProfile(
        uid: 'u1',
        email: 'a@b.test',
        displayName: 'Test Alumnus',
        studentId: '2020-0001',
        program: 'BSIT',
        batchYear: '2020',
        yearGraduated: '2020',
      );
      for (var i = 0; i < 3; i++) {
        profile = ChedGtsPrefill.mergeIntoProfile(
          current: profile,
          answers: {'ched_8': '2000-05-10'},
        );
        final row = profile.toSupabaseRow();
        expect(row['birth_date'], '2000-05-10');
        profile = TracerProfile.fromSupabaseRow(row);
      }
    });

    test('roster row keeps the picked birthday', () {
      final member = AlumniMember(
        id: 'm1',
        fullName: 'Test Alumnus',
        course: 'BSIT',
        studentId: '2020-0001',
        createdAt: DateTime(2024),
        birthDate: DateTime(2000, 5, 10),
      );
      expect(member.toSupabaseRow()['birth_date'], '2000-05-10');
    });
  });
}
