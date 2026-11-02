import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// One answer column in a submitted-responses spreadsheet.
class SurveyResponseExportColumn {
  const SurveyResponseExportColumn({
    required this.id,
    required this.header,
  });

  /// Lookup key in `survey_responses.answers` (question id or `ched_*`).
  final String id;

  /// Spreadsheet column title shown to administrators.
  final String header;
}

/// Resolves which answer columns a submitted-responses export should include.
///
/// Official CHED GTS waves do not seed `survey_questions`; answers live under
/// stable `ched_*` keys from [ChedGtsBuiltin]. Custom surveys use the provided
/// [SurveyQuestion] rows.
abstract final class SurveyResponseExportColumns {
  /// Roster columns shared by CSV / Excel response extracts.
  static const rosterHeaders = <String>[
    'Name',
    'Email',
    'Program',
    'Batch',
    'Status',
    'Submitted At',
  ];

  /// Answer columns for [survey], preferring builtin CHED items when applicable.
  static List<SurveyResponseExportColumn> forSurvey({
    required Survey survey,
    required List<SurveyQuestion> questions,
  }) {
    if (survey.isChedGtsBuiltin) {
      return [
        for (final item in ChedGtsBuiltin.items)
          SurveyResponseExportColumn(
            id: item.id,
            header: _chedHeader(item),
          ),
      ];
    }
    return [
      for (final q in questions)
        SurveyResponseExportColumn(
          id: q.id,
          header: q.prompt.trim().isEmpty ? q.id : q.prompt.trim(),
        ),
    ];
  }

  static String _chedHeader(ChedGtsItem item) {
    final number = item.chedNumber.trim();
    final prompt = item.prompt.trim();
    if (number.isEmpty) return prompt.isEmpty ? item.id : prompt;
    if (prompt.isEmpty) return '[$number]';
    return '[$number] $prompt';
  }

  /// Human-readable cell value for one answer key.
  static String cellValue(Map<String, dynamic> answers, String answerId) =>
      formatSurveyAnswerValue(answers[answerId]);
}
