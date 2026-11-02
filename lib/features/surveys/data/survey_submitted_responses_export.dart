import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;

import 'package:alumni_system/features/surveys/data/survey_response_export_columns.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Builds submitted-response spreadsheets for one survey.
///
/// Official CHED waves use [ChedGtsBuiltin] field columns even when
/// `survey_questions` is empty.
abstract final class SurveySubmittedResponsesExport {
  static List<SurveyParticipant> submittedOnly(
    List<SurveyParticipant> participants,
  ) =>
      participants
          .where((p) => !p.isPending && p.response != null)
          .toList(growable: false);

  static String buildCsv({
    required Survey survey,
    required List<SurveyQuestion> questions,
    required List<SurveyParticipant> participants,
  }) {
    final columns = SurveyResponseExportColumns.forSurvey(
      survey: survey,
      questions: questions,
    );
    final submitted = submittedOnly(participants);
    final buffer = StringBuffer();
    final headers = [
      ...SurveyResponseExportColumns.rosterHeaders.map(_csvEscape),
      ...columns.map((c) => _csvEscape(c.header)),
    ];
    buffer.writeln(headers.join(','));

    for (final p in submitted) {
      final r = p.response!;
      final row = <String>[
        _csvEscape(p.displayName),
        _csvEscape(p.email),
        _csvEscape(p.program),
        _csvEscape(p.batchYear),
        _csvEscape(p.assignment.status.name),
        _csvEscape(r.submittedAt?.toIso8601String() ?? ''),
        ...columns.map(
          (c) => _csvEscape(
            SurveyResponseExportColumns.cellValue(r.answers, c.id),
          ),
        ),
      ];
      buffer.writeln(row.join(','));
    }
    return buffer.toString();
  }

  static Uint8List buildExcelBytes({
    required Survey survey,
    required List<SurveyQuestion> questions,
    required List<SurveyParticipant> participants,
  }) {
    final columns = SurveyResponseExportColumns.forSurvey(
      survey: survey,
      questions: questions,
    );
    final submitted = submittedOnly(participants);
    const responsesSheet = 'Responses';
    final book = Excel.createExcel();
    // The excel package cannot rename/delete its default sheet safely.
    final def = book.getDefaultSheet();
    if (def != null && def != responsesSheet) {
      book[def].appendRow([
        'Submitted responses are on the "$responsesSheet" sheet.',
      ]);
    }
    final sheet = book[responsesSheet];
    sheet.appendRow([
      ...SurveyResponseExportColumns.rosterHeaders,
      ...columns.map((c) => c.header),
    ]);
    for (final p in submitted) {
      final response = p.response!;
      sheet.appendRow([
        p.displayName,
        p.email,
        p.program,
        p.batchYear,
        p.assignment.status.name,
        response.submittedAt?.toIso8601String() ?? '',
        ...columns.map(
          (c) => SurveyResponseExportColumns.cellValue(response.answers, c.id),
        ),
      ]);
    }
    book.setDefaultSheet(responsesSheet);
    final encoded = book.save();
    if (encoded == null) {
      throw StateError('Excel encode returned null');
    }
    return Uint8List.fromList(encoded);
  }

  static String _csvEscape(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
