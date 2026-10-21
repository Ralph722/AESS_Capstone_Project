import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/alumni/profile/data/profile_change_diff.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';

TracerProfile _profile({
  String civilStatus = 'Single',
  String mobileNumber = '09170000000',
  DateTime? birthDate,
  String employmentStatus = '',
}) {
  return TracerProfile(
    uid: 'u1',
    email: 'juan@example.com',
    displayName: 'Juan Santos',
    studentId: '2023304878',
    program: 'BSIT',
    batchYear: '2023',
    yearGraduated: '2023',
    mobileNumber: mobileNumber,
    civilStatus: civilStatus,
    birthDate: birthDate ?? DateTime(2000, 1, 1),
    employmentStatus: employmentStatus,
  );
}

void main() {
  group('tracerProfileFieldDiff', () {
    test('empty when nothing changed', () {
      expect(tracerProfileFieldDiff(_profile(), _profile()), isEmpty);
    });

    test('ignores whitespace-only differences', () {
      final diff = tracerProfileFieldDiff(
        _profile(mobileNumber: '09170000000'),
        _profile(mobileNumber: '  09170000000 '),
      );
      expect(diff, isEmpty);
    });

    test('captures changed fields with old and new values', () {
      final diff = tracerProfileFieldDiff(
        _profile(),
        _profile(civilStatus: 'Married', employmentStatus: 'Employed'),
      );
      expect(diff.keys, ['civilStatus', 'employmentStatus']);
      expect(diff['civilStatus'], {'from': 'Single', 'to': 'Married'});
      expect(diff['employmentStatus'], {'from': '', 'to': 'Employed'});
    });

    test('formats birth dates for display', () {
      final diff = tracerProfileFieldDiff(
        _profile(),
        _profile(birthDate: DateTime(2001, 5, 4)),
      );
      expect(diff['birthDate'], {'from': 'Jan 1, 2000', 'to': 'May 4, 2001'});
    });
  });

  group('labels', () {
    test('every diff field has a label', () {
      final diff = tracerProfileFieldDiff(
        _profile(),
        _profile(civilStatus: 'Married', employmentStatus: 'Employed'),
      );
      for (final key in diff.keys) {
        expect(profileFieldLabels[key], isNotNull, reason: key);
      }
    });

    test('source labels fall back to Profile', () {
      expect(profileChangeSourceLabel('tracer'), 'Tracer');
      expect(profileChangeSourceLabel('onboarding'), 'Onboarding');
      expect(profileChangeSourceLabel(null), 'Profile');
      expect(profileChangeSourceLabel('unknown'), 'Profile');
    });

    test('photo change carries no image data', () {
      final changes = profilePhotoChange('profile');
      expect(changes['source'], 'profile');
      expect(changes['fields'], {
        'photo': {'from': '', 'to': ''},
      });
    });
  });
}
