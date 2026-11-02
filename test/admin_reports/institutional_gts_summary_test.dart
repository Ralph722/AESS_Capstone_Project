import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/data/institutional_gts_summary_service.dart';
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
  );
}

SurveyResponse _response(String surveyId, String userId, String employed) {
  final now = DateTime(2026, 2, 1);
  return SurveyResponse(
    surveyId: surveyId,
    userId: userId,
    status: SurveyResponseStatus.submitted,
    answers: {'ched_16': employed},
    submittedAt: now,
    updatedAt: now,
  );
}

void main() {
  test('institutional summary pools CHED answers across waves', () {
    final w1 = _wave('w1', 'Wave 2025');
    final w2 = _wave('w2', 'Wave 2026');
    final summary = InstitutionalGtsSummaryService.build(
      waves: [w1, w2],
      responsesBySurveyId: {
        'w1': [
          _response('w1', 'u1', ChedGtsBuiltin.yes),
          _response('w1', 'u2', ChedGtsBuiltin.no),
        ],
        'w2': [
          _response('w2', 'u3', ChedGtsBuiltin.yes),
        ],
      },
      assigned: 10,
      submitted: 3,
      pending: 7,
      batchFilter: '2024',
    );

    expect(summary.waveTitles, ['Wave 2025', 'Wave 2026']);
    expect(summary.responseRate.percent, 30);
    expect(summary.scopeLabel, contains('2 Official CHED waves'));
    expect(summary.scopeLabel, contains('2024'));
    final employed = summary.fields.firstWhere((f) => f.questionId == 'ched_16');
    expect(employed.answeredCount, 3);
    final yes = employed.rows.firstWhere((r) => r.label == ChedGtsBuiltin.yes);
    expect(yes.count, 2);
  });

  test('institutional summary excel/csv bytes are non-empty', () {
    final w1 = _wave('w1', 'Wave');
    final summary = InstitutionalGtsSummaryService.build(
      waves: [w1],
      responsesBySurveyId: {
        'w1': [_response('w1', 'u1', ChedGtsBuiltin.yes)],
      },
      assigned: 1,
      submitted: 1,
      pending: 0,
    );
    final excel = InstitutionalGtsSummaryService.toExcel(summary);
    final csv = InstitutionalGtsSummaryService.toCsvBytes(summary);
    expect(excel.length, greaterThan(100));
    expect(String.fromCharCodes(csv), contains('Coverage'));
  });
}
