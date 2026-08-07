import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

SurveyResponseWithMeta _meta({
  required String surveyId,
  required Map<String, dynamic> answers,
  required DateTime submittedAt,
  String title = 'CHED',
}) {
  return SurveyResponseWithMeta(
    response: SurveyResponse(
      surveyId: surveyId,
      userId: 'u1',
      answers: answers,
      status: SurveyResponseStatus.submitted,
      submittedAt: submittedAt,
      updatedAt: submittedAt,
    ),
    surveyTitle: title,
  );
}

void main() {
  group('ChedGtsPdfPersonExportService.chedWaves', () {
    test('keeps only ched_* submissions newest first', () {
      final waves = ChedGtsPdfPersonExportService.chedWaves([
        _meta(
          surveyId: 'old',
          submittedAt: DateTime(2025, 1, 1),
          answers: {'ched_1': 'A'},
        ),
        _meta(
          surveyId: 'custom',
          submittedAt: DateTime(2026, 6, 1),
          answers: {'q1': 'x'},
          title: 'Custom',
        ),
        _meta(
          surveyId: 'new',
          submittedAt: DateTime(2026, 5, 1),
          answers: {'ched_1': 'B'},
        ),
      ]);

      expect(waves.map((w) => w.response.surveyId), ['new', 'old']);
    });
  });

  group('ChedGtsPdfPersonExportService file naming via fill engine', () {
    test('suggestFileName remains stable for audit metadata', () {
      expect(
        ChedGtsPdfFillEngine.suggestFileName(
          displayName: 'Jane Doe',
          surveyLabel: 'CHED GTS',
          when: DateTime(2026, 7, 25),
        ),
        'GTS-Jane-Doe-CHED-GTS-2026-07-25.pdf',
      );
    });
  });
}
