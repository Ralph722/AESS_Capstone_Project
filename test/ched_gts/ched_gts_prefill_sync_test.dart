import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mergeIntoProfile updates Section A, B.12, and item 16 '
      'but keeps the official program and year', () {
    const current = TracerProfile(
      uid: 'u1',
      email: 'old@school.edu',
      displayName: 'Old Name',
      studentId: '2023001',
      program: 'BSIT',
      batchYear: '2023',
      yearGraduated: '2023',
      address: 'Old Address',
      mobileNumber: '09000000000',
      employmentStatus: GtsConstants.unemployed,
    );

    final synced = ChedGtsPrefill.mergeIntoProfile(
      current: current,
      answers: {
        'ched_1': 'New Name',
        'ched_2': 'New Address',
        'ched_3': 'new@school.edu',
        'ched_5': '09111111111',
        'ched_6': 'Single',
        'ched_7': 'Male',
        'ched_8': '2000-05-15',
        'ched_9': 'Region 10',
        'ched_10': 'Misamis Occidental',
        'ched_11': 'City',
        'ched_12': [
          {
            'Degree(s) & Specialization(s)': 'BS Computer Science',
            'College or University': GtsConstants.defaultCollegeUniversity,
            'Year Graduated': '2024',
            'Honor(s) or Award(s) Received': 'Cum Laude',
          },
        ],
        'ched_16': ChedGtsBuiltin.yes,
      },
    );

    expect(synced.displayName, 'New Name');
    expect(synced.address, 'New Address');
    expect(synced.email, 'new@school.edu');
    expect(synced.mobileNumber, '09111111111');
    expect(synced.civilStatus, 'Single');
    expect(synced.gender, 'Male');
    expect(synced.birthDate?.year, 2000);
    expect(synced.regionOfOrigin, 'Region 10');
    expect(synced.province, 'Misamis Occidental');
    expect(synced.locationOfResidence, 'City');
    expect(synced.program, 'BSIT');
    expect(synced.yearGraduated, '2023');
    expect(synced.batchYear, '2023');
    expect(synced.honorsAwards, 'Cum Laude');
    expect(synced.employmentStatus, GtsConstants.employed);
    expect(synced.studentId, '2023001');
  });
}
