import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

TracerProfile _profile({
  String name = 'Jane Doe',
  String employmentStatus = GtsConstants.employed,
}) {
  return TracerProfile(
    uid: 'u1',
    email: 'jane@school.edu',
    displayName: name,
    studentId: '2024001',
    program: 'BSIT',
    batchYear: '2024',
    yearGraduated: '2024',
    address: 'Cagayan de Oro',
    mobileNumber: '09171234567',
    telephoneNumber: '088-111',
    civilStatus: 'Single',
    gender: 'Female',
    birthDate: DateTime(1999, 4, 12),
    regionOfOrigin: 'Region 10',
    province: 'Misamis Oriental',
    locationOfResidence: 'City',
    collegeUniversity: GtsConstants.defaultCollegeUniversity,
    employmentStatus: employmentStatus,
  );
}

EmploymentRecord _employment() {
  return EmploymentRecord(
    id: 'e1',
    userId: 'u1',
    userName: 'Jane Doe',
    userEmail: 'jane@school.edu',
    schoolId: 's1',
    employmentStatus: GtsConstants.employed,
    position: 'Software Engineer',
    industry: 'Education',
    employmentType: 'Full-time',
    salaryRange: 'P20,000.00 to less than P25,000.00',
    country: 'Philippines',
    contactNumber: '09171234567',
  );
}

SurveyResponseWithMeta _meta({
  required String surveyId,
  required Map<String, dynamic> answers,
  DateTime? submittedAt,
  String title = 'CHED GTS',
}) {
  return SurveyResponseWithMeta(
    response: SurveyResponse(
      surveyId: surveyId,
      userId: 'u1',
      answers: answers,
      status: SurveyResponseStatus.submitted,
      submittedAt: submittedAt ?? DateTime(2026, 1, 15),
      updatedAt: DateTime(2026, 1, 15),
    ),
    surveyTitle: title,
  );
}

void main() {
  group('ChedGtsAnswerAssembler.assemble', () {
    test('uses live profile when no submission', () {
      final result = ChedGtsAnswerAssembler.assemble(
        profile: _profile(),
        employment: _employment(),
      );

      expect(result.source, ChedGtsAnswerSource.liveProfileFallback);
      expect(result.answers['ched_1'], 'Jane Doe');
      expect(result.answers['ched_16'], ChedGtsBuiltin.yes);
      expect(result.answers['ched_19'], 'Software Engineer');
      expect(result.notes, isNotEmpty);
    });

    test('prefers submitted snapshot over live profile values', () {
      final result = ChedGtsAnswerAssembler.assemble(
        submittedAnswers: {
          'ched_1': 'Submitted Name',
          'ched_16': ChedGtsBuiltin.neverEmployed,
          'ched_17': ['Did not look for a job'],
          'ched_34': 'Improve labs',
        },
        profile: _profile(),
        employment: _employment(),
        surveyId: 's-ched',
        surveyTitle: 'Official CHED',
        submittedAt: DateTime(2026, 2, 1),
      );

      expect(result.source, ChedGtsAnswerSource.merged);
      expect(result.answers['ched_1'], 'Submitted Name');
      expect(result.answers['ched_16'], ChedGtsBuiltin.neverEmployed);
      // Hidden employed-path answers from live fill must be pruned.
      expect(result.answers.containsKey('ched_19'), isFalse);
      expect(result.answers['ched_17'], ['Did not look for a job']);
      // Gaps filled from profile (e.g. address) while snapshot wins on name.
      expect(result.answers['ched_2'], 'Cagayan de Oro');
      expect(result.surveyId, 's-ched');
      expect(result.submittedAt, DateTime(2026, 2, 1));
    });

    test('submittedSnapshot when fillGapsFromProfile is false', () {
      final result = ChedGtsAnswerAssembler.assemble(
        submittedAnswers: {
          'ched_1': 'Only Snapshot',
          'ched_16': ChedGtsBuiltin.yes,
          'ched_34': 'N/A',
        },
        profile: _profile(),
        fillGapsFromProfile: false,
      );

      expect(result.source, ChedGtsAnswerSource.submittedSnapshot);
      expect(result.answers['ched_1'], 'Only Snapshot');
      expect(result.answers.containsKey('ched_2'), isFalse);
    });

    test('returns empty when nothing available', () {
      final result = ChedGtsAnswerAssembler.assemble();
      expect(result.source, ChedGtsAnswerSource.empty);
      expect(result.hasAnswers, isFalse);
    });

    test('output is ready for Phase 0 PDF mapper', () {
      final assembled = ChedGtsAnswerAssembler.assemble(
        submittedAnswers: {
          'ched_1': 'Ralph Jezron A. Juab',
          'ched_6': 'Single',
          'ched_7': 'Male',
          'ched_9': 'ARMM',
          'ched_16': ChedGtsBuiltin.no,
          'ched_17': ['Advance or further study'],
          'ched_34': 'More mentoring',
        },
        profile: _profile(name: 'Should Not Win'),
      );

      final mapped = ChedGtsPdfMapper.mapAnswers(assembled.answers);
      expect(mapped.values['fullName'], 'Ralph Jezron A. Juab');
      expect(mapped.values['civilStatus'], '/single');
      expect(mapped.values['sex'], '/male');
      expect(mapped.values['region'], 'ARMM');
      expect(mapped.values['employmentStatus'], '/unemployed');
      expect(mapped.values['unemployedReasons__further-study'], '/Yes');
    });
  });

  group('ChedGtsAnswerAssembler.assembleFromLoaded', () {
    test('picks newest ched_* submission among history', () {
      final older = _meta(
        surveyId: 's1',
        submittedAt: DateTime(2025, 1, 1),
        answers: {
          'ched_1': 'Older',
          'ched_16': ChedGtsBuiltin.yes,
          'ched_34': 'a',
        },
      );
      final newer = _meta(
        surveyId: 's2',
        submittedAt: DateTime(2026, 6, 1),
        answers: {
          'ched_1': 'Newer',
          'ched_16': ChedGtsBuiltin.no,
          'ched_17': ['No job opportunity'],
          'ched_34': 'b',
        },
      );
      final custom = _meta(
        surveyId: 's3',
        submittedAt: DateTime(2026, 7, 1),
        title: 'Custom campus survey',
        answers: {
          'q_uuid_1': 'not ched',
        },
      );

      final result = ChedGtsAnswerAssembler.assembleFromLoaded(
        submittedResponses: [older, custom, newer],
        profile: _profile(),
      );

      expect(result.answers['ched_1'], 'Newer');
      expect(result.surveyId, 's2');
      expect(result.source, ChedGtsAnswerSource.merged);
    });

    test('pins surveyId when provided', () {
      final a = _meta(
        surveyId: 'wave-a',
        submittedAt: DateTime(2026, 6, 1),
        answers: {'ched_1': 'Wave A', 'ched_16': ChedGtsBuiltin.yes},
      );
      final b = _meta(
        surveyId: 'wave-b',
        submittedAt: DateTime(2026, 7, 1),
        answers: {'ched_1': 'Wave B', 'ched_16': ChedGtsBuiltin.yes},
      );

      final result = ChedGtsAnswerAssembler.assembleFromLoaded(
        submittedResponses: [a, b],
        surveyId: 'wave-a',
        fillGapsFromProfile: false,
      );

      expect(result.answers['ched_1'], 'Wave A');
      expect(result.surveyId, 'wave-a');
    });
  });

  group('ChedGtsAnswerAssembler.looksLikeChedGtsAnswers', () {
    test('detects builtin keys', () {
      expect(
        ChedGtsAnswerAssembler.looksLikeChedGtsAnswers({'ched_1': 'x'}),
        isTrue,
      );
      expect(
        ChedGtsAnswerAssembler.looksLikeChedGtsAnswers({'q1': 'x'}),
        isFalse,
      );
    });
  });
}
