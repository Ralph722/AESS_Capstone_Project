import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/application/institutional_ched_templates.dart';
import 'package:alumni_system/features/admin/reports/data/institutional_professional_exams_service.dart';
import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

Survey _wave(String id) {
  final now = DateTime(2026, 1, 1);
  return Survey(
    id: id,
    title: 'Wave $id',
    description: '',
    status: SurveyStatus.published,
    createdBy: 'admin',
    createdAt: now,
    kind: ChedGtsBuiltin.kind,
    templateKey: ChedGtsBuiltin.templateKey,
  );
}

SurveyResponse _resp(
  String surveyId,
  String userId, {
  List<Map<String, String>>? exams,
}) {
  final now = DateTime(2026, 2, 1);
  return SurveyResponse(
    surveyId: surveyId,
    userId: userId,
    status: SurveyResponseStatus.submitted,
    answers: {
      if (exams != null) 'ched_13': exams,
    },
    submittedAt: now,
    updatedAt: now,
  );
}

AlumniMember _member(String uid, {required String course, required String batch}) {
  return AlumniMember(
    id: uid,
    studentId: uid,
    fullName: 'Alumni $uid',
    course: course,
    batchYear: batch,
    authUid: uid,
  );
}

void main() {
  test('catalog exposes professional exams downloads preset', () {
    final entry = AessReportCatalog.byDownloadsPresetId(
      InstitutionalChedTemplates.professionalExams,
    );
    expect(entry, isNotNull);
    expect(entry!.id, 'downloads.professional_exams');
    expect(
      InstitutionalChedTemplates.isInstitutionalChedPreset(
        InstitutionalChedTemplates.professionalExams,
      ),
      isTrue,
    );
    expect(
      InstitutionalChedTemplates.isOutcomePreset(
        InstitutionalChedTemplates.professionalExams,
      ),
      isFalse,
    );
  });

  test('build tallies passers and exam-name mix from Q13', () {
    final w = _wave('w1');
    final report = InstitutionalProfessionalExamsService.build(
      waves: [w],
      responsesBySurveyId: {
        'w1': [
          _resp(
            'w1',
            'u1',
            exams: [
              {
                'Name of Examination': 'LET',
                'Date Taken': '2025-03',
                'Rating': '82.5',
              },
              {
                'Name of Examination': 'Civil Service Professional',
                'Date Taken': '2024-11',
                'Rating': '85',
              },
            ],
          ),
          _resp(
            'w1',
            'u2',
            exams: [
              {
                'Name of Examination': 'let',
                'Date Taken': '2025-01',
                'Rating': '80',
              },
            ],
          ),
          _resp('w1', 'u3'),
          _resp('w1', 'u4', exams: const []),
        ],
      },
      memberByAuth: {
        'u1': _member('u1', course: 'BTLED-ICT', batch: '2024'),
        'u2': _member('u2', course: 'BSIT', batch: '2024'),
        'u3': _member('u3', course: 'BSIT', batch: '2023'),
        'u4': _member('u4', course: 'BTLED-HE', batch: '2024'),
      },
    );

    expect(report.submitted, 4);
    expect(report.passedAtLeastOne, 2);
    expect(report.noneListed, 2);
    expect(report.totalExamRows, 3);

    final byName = {
      for (final e in report.examRows) e.examName.toLowerCase(): e.alumniCount,
    };
    expect(byName['let'], 2);
    expect(byName['civil service professional'], 1);

    final bsit = report.byCourse.firstWhere((c) => c.course == 'BSIT');
    expect(bsit.submitted, 2);
    expect(bsit.passedAtLeastOne, 1);

    expect(report.detailRows, hasLength(3));
    expect(report.detailRows.any((d) => d.examName == 'LET'), isTrue);
  });

  test('excel and csv encode without throwing', () {
    final w = _wave('w1');
    final report = InstitutionalProfessionalExamsService.build(
      waves: [w],
      responsesBySurveyId: {
        'w1': [
          _resp(
            'w1',
            'u1',
            exams: [
              {'Name of Examination': 'LET', 'Date Taken': '', 'Rating': ''},
            ],
          ),
        ],
      },
      memberByAuth: {
        'u1': _member('u1', course: 'BSIT', batch: '2024'),
      },
    );

    final xlsx = InstitutionalProfessionalExamsService.toExcel(report);
    expect(xlsx.length, greaterThan(100));
    final csv = InstitutionalProfessionalExamsService.toCsvBytes(report);
    final text = String.fromCharCodes(csv);
    expect(text, contains('passed_at_least_one'));
    expect(text, contains('LET'));
  });
}
