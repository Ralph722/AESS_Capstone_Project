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

    // Name stays locked to the verified record unless marriage opt-in.
    expect(synced.displayName, 'Old Name');
    final renamed = ChedGtsPrefill.mergeIntoProfile(
      current: current,
      answers: {'ched_1': 'New Name', 'ched_6': 'Married'},
      allowNameChange: true,
    );
    expect(renamed.displayName, 'New Name');
    expect(synced.address, 'New Address');
    // Contacts are saved only after verification.
    expect(synced.email, 'old@school.edu');
    expect(synced.mobileNumber, '09000000000');
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

  test('Q3 is prefilled from the contact email, falling back to the login', () {
    const base = TracerProfile(
      uid: 'u1',
      email: 'login@school.edu',
      displayName: 'Ana',
      studentId: '2023001',
      program: 'BSIT',
      batchYear: '2023',
      yearGraduated: '2023',
    );
    expect(ChedGtsPrefill.fromProfile(base)['ched_3'], 'login@school.edu');

    final withContact = TracerProfile.fromSupabaseRow({
      'id': 'u1',
      'email': 'login@school.edu',
      'contact_email': 'ana@gmail.com',
      'display_name': 'Ana',
    });
    expect(withContact.contactEmail, 'ana@gmail.com');
    expect(ChedGtsPrefill.fromProfile(withContact)['ched_3'], 'ana@gmail.com');
    expect(
      withContact.copyWith(displayName: 'Ana R').contactEmail,
      'ana@gmail.com',
    );
  });

  test('mergeIntoProfile writes back Q18 and Q19 when employed and clears Q17', () {
    const current = TracerProfile(
      uid: 'u1',
      email: 'alumni@ustp.edu.ph',
      displayName: 'Carlos',
      studentId: '2020101',
      program: 'BSIT',
      batchYear: '2020',
      yearGraduated: '2020',
      employmentStatus: GtsConstants.unemployed,
      notEmployedReasons: ['Lack of work experience'],
    );

    final synced = ChedGtsPrefill.mergeIntoProfile(
      current: current,
      answers: {
        'ched_16': ChedGtsBuiltin.yes,
        'ched_18': 'Contractual',
        'ched_19': 'Frontend Engineer',
      },
    );

    expect(synced.employmentStatus, GtsConstants.employed);
    expect(synced.employmentType, 'Contractual');
    expect(synced.employmentOccupation, 'Frontend Engineer');
    expect(synced.notEmployedReasons, isEmpty);
    expect(synced.employmentSource, 'ched_gts');
    expect(synced.employmentUpdatedAt, isNotNull);
  });

  test('mergeIntoProfile writes back Q17 when unemployed and clears Q18/Q19', () {
    const current = TracerProfile(
      uid: 'u1',
      email: 'alumni@ustp.edu.ph',
      displayName: 'Diana',
      studentId: '2020102',
      program: 'BSIT',
      batchYear: '2020',
      yearGraduated: '2020',
      employmentStatus: GtsConstants.employed,
      employmentType: 'Regular or Permanent',
      employmentOccupation: 'QA Specialist',
    );

    final synced = ChedGtsPrefill.mergeIntoProfile(
      current: current,
      answers: {
        'ched_16': ChedGtsBuiltin.no,
        'ched_17': ['Advance or further study', 'Other reason(s), please specify'],
        'ched_17_other': 'Reviewing for master degree entrance',
      },
    );

    expect(synced.employmentStatus, GtsConstants.unemployed);
    expect(synced.employmentType, isEmpty);
    expect(synced.employmentOccupation, isEmpty);
    expect(synced.notEmployedReasons, [
      'Advance or further study',
      'Other reason(s), please specify',
    ]);
    expect(synced.notEmployedReasonOther, 'Reviewing for master degree entrance');
    expect(synced.employmentSource, 'ched_gts');
  });

  test('TracerProfile fromSupabaseRow and toSupabaseRow preserve employment follow-ups', () {
    final now = DateTime.now().toUtc();
    final profile = TracerProfile.fromSupabaseRow({
      'id': 'u1',
      'email': 'test@ustp.edu.ph',
      'display_name': 'Test User',
      'student_id': '2020999',
      'program': 'BSIT',
      'year_graduated': '2020',
      'employment_status': 'Employed',
      'employment_type': 'Regular or Permanent',
      'employment_occupation': 'Systems Analyst',
      'not_employed_reasons': <dynamic>[],
      'not_employed_reason_other': '',
      'employment_source': 'onboarding',
      'employment_updated_at': now.toIso8601String(),
    });

    expect(profile.employmentStatus, 'Employed');
    expect(profile.employmentType, 'Regular or Permanent');
    expect(profile.employmentOccupation, 'Systems Analyst');
    expect(profile.employmentSource, 'onboarding');
    expect(profile.employmentUpdatedAt?.year, now.year);

    final row = profile.toSupabaseRow();
    expect(row['employment_type'], 'Regular or Permanent');
    expect(row['employment_occupation'], 'Systems Analyst');
    expect(row['employment_source'], 'onboarding');
    expect(row['employment_updated_at'], isNotNull);
  });
}
