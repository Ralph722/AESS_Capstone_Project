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
  test('audience packs expose non-overlapping core field sets', () {
    final t1 = InstitutionalChedTemplates.fieldsFor(
      InstitutionalChedTemplates.employmentEmployability,
    ).map((e) => e.questionId).toSet();
    final t2 = InstitutionalChedTemplates.fieldsFor(
      InstitutionalChedTemplates.curriculumCompetency,
    ).map((e) => e.questionId).toSet();
    final t3 = InstitutionalChedTemplates.fieldsFor(
      InstitutionalChedTemplates.industryPlacement,
    ).map((e) => e.questionId).toSet();
    final t4 = InstitutionalChedTemplates.fieldsFor(
      InstitutionalChedTemplates.careerMobility,
    ).map((e) => e.questionId).toSet();

    expect(
      t1,
      containsAll(['ched_16', 'ched_18', 'ched_21', 'ched_24a', 'ched_29']),
    );
    expect(t2, containsAll(['ched_15b', 'ched_32', 'ched_33']));
    expect(t3, containsAll(['ched_20', 'ched_28', 'ched_31']));
    expect(t4, containsAll(['ched_17', 'ched_23', 'ched_27']));
    // T1 and T3 both include place-of-work / industry themes intentionally;
    // T1 now carries Q21 while T3 keeps Q20/Q21 for placement staff.
    expect(t1.intersection(t4), isEmpty);
    expect(t3.intersection(t4), isEmpty);
  });

  test('compliance pack excel includes cohort comparison sheet', () {
    final w = _wave('w1');
    final summary = InstitutionalGtsSummaryService.build(
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
      assigned: 2,
      submitted: 2,
      pending: 0,
      fields: InstitutionalChedTemplates.fieldsFor(
        InstitutionalChedTemplates.chedComplianceMaster,
      ),
      reportTitle: InstitutionalChedTemplates.reportTitle(
        InstitutionalChedTemplates.chedComplianceMaster,
      ),
    );
    final cohort = InstitutionalCohortComparisonService.build(
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
        'u2': _member('u2', course: 'BSCS', batch: '2023'),
      },
      dimension: InstitutionalCompareDimension.batch,
    );
    final excel = InstitutionalGtsSummaryService.toExcel(
      summary,
      cohortComparison: cohort,
    );
    expect(excel.length, greaterThan(100));
    final csv = InstitutionalGtsSummaryService.toCsvBytes(
      summary,
      cohortComparison: cohort,
    );
    final csvText = String.fromCharCodes(csv);
    expect(csvText, contains('Comparison'));
    expect(csvText, contains('2024'));
  });

  test('compliance master builds titled summaries', () {
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
        InstitutionalChedTemplates.chedComplianceMaster,
      ),
      reportTitle: InstitutionalChedTemplates.reportTitle(
        InstitutionalChedTemplates.chedComplianceMaster,
      ),
    );
    expect(
      summary.reportTitle,
      'CHED Compliance & Accreditation Master Summary',
    );
    expect(summary.fields.length, greaterThan(10));
  });

  test('program cohort comparison service still groups by course', () {
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
