import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/data/institutional_gts_participation_quality_service.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

Survey _wave(String id, String title) {
  final now = DateTime(2026, 1, 1);
  return Survey(
    id: id,
    title: title,
    description: '',
    status: SurveyStatus.published,
    createdBy: 'admin',
    createdAt: now,
    kind: ChedGtsBuiltin.kind,
    templateKey: ChedGtsBuiltin.templateKey,
    assignmentCount: 10,
  );
}

SurveyResponse _resp(String surveyId, String userId, {String? employed}) {
  final now = DateTime(2026, 2, 1);
  return SurveyResponse(
    surveyId: surveyId,
    userId: userId,
    status: SurveyResponseStatus.submitted,
    answers: {
      if (employed != null) 'ched_16': employed,
    },
    submittedAt: now,
    updatedAt: now,
  );
}

void main() {
  test('participation quality covers waves and missing answers', () {
    final w1 = _wave('w1', 'Wave A');
    final w2 = _wave('w2', 'Wave B');
    final report = InstitutionalGtsParticipationQualityService.build(
      waves: [w1, w2],
      responsesBySurveyId: {
        'w1': [
          _resp('w1', 'u1', employed: ChedGtsBuiltin.yes),
          _resp('w1', 'u2'),
        ],
        'w2': [
          _resp('w2', 'u3', employed: ChedGtsBuiltin.no),
        ],
      },
      assignedBySurveyId: const {'w1': 4, 'w2': 6},
      batchFilter: '2024',
    );

    expect(report.assigned, 10);
    expect(report.submitted, 3);
    expect(report.pending, 7);
    expect(report.responseRate.percent, 30);
    expect(report.waveRows, hasLength(2));
    expect(report.scopeLabel, contains('2024'));

    final employed = report.missingRows.firstWhere(
      (r) => r.questionId == 'ched_16',
    );
    expect(employed.answered, 2);
    expect(employed.missing, 1);
    expect(employed.submitted, 3);
  });

  test('excel and csv exports are non-empty', () {
    final w1 = _wave('w1', 'Wave');
    final report = InstitutionalGtsParticipationQualityService.build(
      waves: [w1],
      responsesBySurveyId: {
        'w1': [_resp('w1', 'u1', employed: ChedGtsBuiltin.yes)],
      },
      assignedBySurveyId: const {'w1': 2},
    );
    final excel = InstitutionalGtsParticipationQualityService.toExcel(report);
    final csv = InstitutionalGtsParticipationQualityService.toCsvBytes(report);
    expect(excel.length, greaterThan(100));
    expect(String.fromCharCodes(csv), contains('coverage'));
    expect(String.fromCharCodes(csv), contains('missing'));
  });
}
