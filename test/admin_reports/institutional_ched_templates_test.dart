import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/application/institutional_ched_templates.dart';
import 'package:alumni_system/features/admin/reports/data/institutional_cohort_comparison_service.dart';
import 'package:alumni_system/features/admin/reports/data/institutional_gts_summary_service.dart';
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
  required String employed,
  String? related,
  String? curriculum,
}) {
  final now = DateTime(2026, 2, 1);
  return SurveyResponse(
    surveyId: surveyId,
    userId: userId,
    status: SurveyResponseStatus.submitted,
    answers: {
      'ched_16': employed,
      if (related != null) 'ched_24a': related,
      if (curriculum != null) 'ched_32': curriculum,
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
  test('employment template fields are distinct from institutional summary', () {
    final employment = InstitutionalChedTemplates.fieldsFor(
      InstitutionalChedTemplates.graduateEmployment,
    );
    final summary = InstitutionalChedTemplates.fieldsFor(
      InstitutionalChedTemplates.institutionalSummary,
    );
    expect(employment.map((e) => e.questionId), containsAll(['ched_16', 'ched_21']));
    expect(employment.length, lessThan(summary.length));
  });

  test('outcome presets build titled summaries', () {
    final w = _wave('w1');
    final summary = InstitutionalGtsSummaryService.build(
      waves: [w],
      responsesBySurveyId: {
        'w1': [_resp('w1', 'u1', employed: ChedGtsBuiltin.yes)],
      },
      assigned: 1,
      submitted: 1,
      pending: 0,
      fields: InstitutionalChedTemplates.fieldsFor(
        InstitutionalChedTemplates.alumniDemographics,
      ),
      reportTitle: InstitutionalChedTemplates.reportTitle(
        InstitutionalChedTemplates.alumniDemographics,
      ),
    );
    expect(summary.reportTitle, 'Alumni Demographics Report');
  });

  test('program cohort comparison groups by course', () {
    final w = _wave('w1');
    final report = InstitutionalCohortComparisonService.build(
      waves: [w],
      responsesBySurveyId: {
        'w1': [
          _resp(
            'w1',
            'u1',
            employed: ChedGtsBuiltin.yes,
            related: ChedGtsBuiltin.yes,
            curriculum: ChedGtsBuiltin.yes,
          ),
          _resp(
            'w1',
            'u2',
            employed: ChedGtsBuiltin.no,
            related: ChedGtsBuiltin.no,
            curriculum: ChedGtsBuiltin.no,
          ),
        ],
      },
      memberByAuth: {
        'u1': _member('u1', course: 'BSIT', batch: '2024'),
        'u2': _member('u2', course: 'BSCS', batch: '2024'),
      },
      dimension: InstitutionalCompareDimension.course,
    );
    expect(report.rows, hasLength(2));
    expect(report.rows.first.respondents, 1);
    final excel = InstitutionalCohortComparisonService.toExcel(report);
    expect(excel.length, greaterThan(100));
  });
}
