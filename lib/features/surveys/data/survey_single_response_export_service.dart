import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/data/classic_survey_visibility.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// One row in a single-response export (section + question + answer).
class SingleResponseAnswerRow {
  const SingleResponseAnswerRow({
    required this.section,
    required this.question,
    required this.answer,
    this.itemNumber,
  });

  final String section;
  final String question;
  final String answer;
  final String? itemNumber;
}

/// Per-alumni survey response export (PDF, Excel, print).
class SurveySingleResponseExportService {
  SurveySingleResponseExportService._();

  static List<SingleResponseAnswerRow> buildAnswerRows({
    required Survey survey,
    required SurveyResponse response,
    required List<SurveyQuestion> questions,
    required SurveyParticipant participant,
  }) {
    if (survey.isChedGtsBuiltin) {
      return _buildChedRows(response.answers);
    }
    return _buildClassicRows(
      questions: questions,
      answers: response.answers,
      rules: survey.visibilityRules,
    );
  }

  static List<SingleResponseAnswerRow> _buildChedRows(
    Map<String, dynamic> answers,
  ) {
    final visible = ChedGtsVisibility.visibleItemIds(answers);
    final rows = <SingleResponseAnswerRow>[];
    for (final item in ChedGtsBuiltin.items) {
      if (!visible.contains(item.id)) continue;
      if (item.isOthersSpecify) continue;
      rows.add(
        SingleResponseAnswerRow(
          section: item.sectionTitle,
          question: item.prompt,
          answer: _formatAnswer(answers[item.id]),
          itemNumber: item.chedNumber,
        ),
      );
    }
    return rows;
  }

  static List<SingleResponseAnswerRow> _buildClassicRows({
    required List<SurveyQuestion> questions,
    required Map<String, dynamic> answers,
    required Map<String, SurveyVisibilityRule> rules,
  }) {
    final pruned = ClassicSurveyVisibility.pruneHiddenAnswers(
      questions: questions,
      answers: answers,
      rules: rules,
    );
    final visible = ClassicSurveyVisibility.visibleQuestions(
      questions: questions,
      answers: pruned,
      rules: rules,
    )..sort((a, b) => a.order.compareTo(b.order));

    return [
      for (final q in visible)
        SingleResponseAnswerRow(
          section: q.sectionLabel.isEmpty ? 'General information' : q.sectionLabel,
          question: q.prompt,
          answer: _formatAnswer(pruned[q.id]),
          itemNumber: q.chedItemNumber,
        ),
    ];
  }

  static String _formatAnswer(dynamic value) {
    final text = formatSurveyAnswerValue(value);
    return text.isEmpty ? '—' : text;
  }

  static Future<Uint8List> toPdf({
    required Survey survey,
    required SurveyResponse response,
    required List<SurveyQuestion> questions,
    required SurveyParticipant participant,
    List<SingleResponseAnswerRow>? rows,
  }) async {
    final answerRows = rows ??
        buildAnswerRows(
          survey: survey,
          response: response,
          questions: questions,
          participant: participant,
        );
    final fmt = DateFormat.yMMMd().add_jm();
    final submitted = response.submittedAt ?? response.updatedAt;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              survey.title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              'Individual response export · ${fmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.blue900),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            'Alumni information',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 6),
          _pdfMetaTable([
            ['Name', participant.displayName],
            ['Email', participant.email],
            ['Student ID', participant.studentId ?? '—'],
            ['Program', participant.program.isEmpty ? '—' : participant.program],
            [
              'Batch',
              participant.batchYear.isEmpty ? '—' : participant.batchYear,
            ],
            ['Submitted', fmt.format(submitted)],
            ['Device', response.deviceSummary],
          ]),
          pw.SizedBox(height: 14),
          pw.Text(
            'Answers',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 6),
          _pdfAnswerTable(answerRows),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _pdfMetaTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(2.8),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  row[0],
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 9)),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _pdfAnswerTable(List<SingleResponseAnswerRow> rows) {
    if (rows.isEmpty) {
      return pw.Text(
        'No visible answers recorded.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(2.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _pdfHeaderCell('Section'),
            _pdfHeaderCell('Question'),
            _pdfHeaderCell('Answer'),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              _pdfBodyCell(row.section),
              _pdfBodyCell(
                row.itemNumber == null || row.itemNumber!.isEmpty
                    ? row.question
                    : '${row.itemNumber}. ${row.question}',
              ),
              _pdfBodyCell(row.answer),
            ],
          ),
      ],
    );
  }

  static pw.Widget _pdfHeaderCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget _pdfBodyCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      );

  static Uint8List toExcel({
    required Survey survey,
    required SurveyResponse response,
    required List<SurveyQuestion> questions,
    required SurveyParticipant participant,
    List<SingleResponseAnswerRow>? rows,
  }) {
    final answerRows = rows ??
        buildAnswerRows(
          survey: survey,
          response: response,
          questions: questions,
          participant: participant,
        );
    final fmt = DateFormat.yMMMd().add_jm();
    final submitted = response.submittedAt ?? response.updatedAt;
    final book = Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    if (defaultSheet != null) {
      book.delete(defaultSheet);
    }

    final meta = book['Metadata'];
    meta.appendRow([
      'Field',
      'Value',
    ]);
    for (final entry in [
      ['Survey', survey.title],
      ['Alumni name', participant.displayName],
      ['Email', participant.email],
      ['Student ID', participant.studentId ?? '—'],
      ['Program', participant.program],
      ['Batch', participant.batchYear],
      ['Submitted', fmt.format(submitted)],
      ['Device', response.deviceSummary],
      ['Status', response.status.name],
    ]) {
      meta.appendRow([
        entry[0],
        entry[1],
      ]);
    }

    final answers = book['Answers'];
    answers.appendRow([
      'Section',
      'Item #',
      'Question',
      'Answer',
    ]);
    for (final row in answerRows) {
      answers.appendRow([
        row.section,
        row.itemNumber ?? '',
        row.question,
        row.answer,
      ]);
    }

    return Uint8List.fromList(book.encode()!);
  }

  static Future<void> printPdf({
    required Uint8List pdfBytes,
    required String documentName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: documentName,
    );
  }

  static String fileBaseName(SurveyParticipant participant) {
    final name = participant.displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final safe = name.isEmpty ? 'alumni' : name;
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'survey_response_${safe}_$stamp';
  }
}
