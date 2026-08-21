import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/reports/application/ched_wave_comparison.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/data/survey_report_analytics.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

/// One choice row inside a CHED outcomes field block (always includes n + %).
class ChedOutcomeChoiceRow {
  const ChedOutcomeChoiceRow({
    required this.label,
    required this.count,
    required this.percent,
  });

  final String label;
  final int count;
  final double percent;
}

/// Aggregated distribution for one crucial CHED item.
class ChedOutcomeFieldBlock {
  const ChedOutcomeFieldBlock({
    required this.questionId,
    required this.label,
    required this.answeredCount,
    required this.rows,
    this.highlightLabel,
    this.highlightPercent,
  });

  final String questionId;
  final String label;
  final int answeredCount;
  final List<ChedOutcomeChoiceRow> rows;
  final String? highlightLabel;
  final double? highlightPercent;
}

/// Single-wave CHED tracer outcomes summary for the Responses workspace.
class ChedOutcomesSummary {
  const ChedOutcomesSummary({
    required this.survey,
    required this.generatedAt,
    required this.assigned,
    required this.submitted,
    required this.pending,
    required this.fields,
  });

  final Survey survey;
  final DateTime generatedAt;
  final int assigned;
  final int submitted;
  final int pending;
  final List<ChedOutcomeFieldBlock> fields;

  double get completionRate =>
      assigned == 0 ? 0 : (submitted / assigned) * 100;

  /// Fields used for this wave summary (slightly broader than wave-compare core).
  static const outcomeFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_16',
      shortLabel: 'Presently employed',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_17',
      shortLabel: 'Reasons not employed',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_18',
      shortLabel: 'Present employment status',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_21',
      shortLabel: 'Place of work',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_22',
      shortLabel: 'First job after college',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_24a',
      shortLabel: 'Job related to course',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_29',
      shortLabel: 'Time to first job',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_31',
      shortLabel: 'Initial monthly earning',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_32',
      shortLabel: 'Curriculum relevant to first job',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_15b',
      shortLabel: 'Reasons for further studies',
    ),
  ];
}

/// Builds printable / downloadable CHED outcomes summaries for one tracer wave.
abstract final class SurveyChedOutcomesSummaryService {
  static ChedOutcomesSummary build({
    required Survey survey,
    required List<SurveyParticipant> participants,
    required List<SurveyResponse> responses,
    List<ChedWaveComparisonFieldSpec> fields = ChedOutcomesSummary.outcomeFields,
  }) {
    final submitted = participants.where((p) => !p.isPending).length;
    final assigned = participants.length;
    final pending = participants.where((p) => p.isPending).length;

    final submittedResponses = responses
        .where((r) => r.status == SurveyResponseStatus.submitted)
        .toList(growable: false);

    final aggregates = SurveyReportAnalytics.aggregateChedResponses(
      responses: submittedResponses,
    );
    final byId = <String, SurveyQuestionAggregate>{
      for (final a in aggregates) a.questionId: a,
    };

    final blocks = <ChedOutcomeFieldBlock>[];
    for (final spec in fields) {
      final agg = byId[spec.questionId];
      final answered = agg?.answeredCount ?? 0;
      final pct = agg?.choicePercentages ?? const <String, double>{};
      final rows = <ChedOutcomeChoiceRow>[];
      if (answered > 0) {
        final ordered = pct.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final e in ordered) {
          final count = ((e.value / 100) * answered).round();
          rows.add(
            ChedOutcomeChoiceRow(
              label: e.key,
              count: count,
              percent: e.value,
            ),
          );
        }
      }

      double? highlightPct;
      final highlight = spec.highlightOption;
      if (highlight != null && answered > 0) {
        highlightPct = pct[highlight];
      }

      blocks.add(
        ChedOutcomeFieldBlock(
          questionId: spec.questionId,
          label: spec.shortLabel,
          answeredCount: answered,
          rows: rows,
          highlightLabel: highlight,
          highlightPercent: highlightPct,
        ),
      );
    }

    return ChedOutcomesSummary(
      survey: survey,
      generatedAt: DateTime.now(),
      assigned: assigned,
      submitted: submitted,
      pending: pending,
      fields: blocks,
    );
  }

  static Future<Uint8List> toPdf(ChedOutcomesSummary summary) async {
    final doc = pw.Document();
    final stamp = DateFormat.yMMMMEEEEd().add_jm().format(summary.generatedAt);
    final title = summary.survey.title.trim().isEmpty
        ? 'CHED GTS outcomes'
        : summary.survey.title.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              PdfSafeText.sanitize('CHED tracer outcomes summary'),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              PdfSafeText.sanitize('$title · $stamp'),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.blue900),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[
            pw.Text(
              PdfSafeText.sanitize('Participation'),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            _pdfTable(
              headers: const [
                'Assigned',
                'Submitted',
                'Pending',
                'Completion %',
              ],
              rows: [
                [
                  '${summary.assigned}',
                  '${summary.submitted}',
                  '${summary.pending}',
                  summary.completionRate.toStringAsFixed(0),
                ],
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              PdfSafeText.sanitize(
                'Rates below always include sample size (n). '
                'Treat percentages as directional when n is small.',
              ),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 14),
          ];

          for (final field in summary.fields) {
            widgets.add(
              pw.Text(
                PdfSafeText.sanitize(field.label),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 3));
            if (field.answeredCount == 0) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    'No answers yet (n=0)',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              );
              continue;
            }
            final highlight = field.highlightLabel != null &&
                    field.highlightPercent != null
                ? 'Highlight “${field.highlightLabel}”: '
                    '${field.highlightPercent!.toStringAsFixed(0)}% '
                    '(n=${field.answeredCount})'
                : 'Answered n=${field.answeredCount}';
            widgets.add(
              pw.Text(
                PdfSafeText.sanitize(highlight),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            );
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(
              _pdfTable(
                headers: const ['Option', 'Count', '%'],
                rows: [
                  for (final r in field.rows)
                    [
                      r.label,
                      '${r.count}',
                      r.percent.toStringAsFixed(0),
                    ],
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 12));
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  static Uint8List toExcel(ChedOutcomesSummary summary) {
    final book = Excel.createExcel();
    final def = book.getDefaultSheet();
    if (def != null && def != 'Summary') {
      book.rename(def, 'Summary');
    }
    final summarySheet = book['Summary'];
    summarySheet.appendRow(['Survey', summary.survey.title]);
    summarySheet.appendRow([
      'Generated',
      DateFormat.yMMMd().add_jm().format(summary.generatedAt),
    ]);
    summarySheet.appendRow(['Assigned', summary.assigned]);
    summarySheet.appendRow(['Submitted', summary.submitted]);
    summarySheet.appendRow(['Pending', summary.pending]);
    summarySheet.appendRow([
      'Completion_%',
      summary.completionRate.toStringAsFixed(1),
    ]);

    final detail = book['Outcomes'];
    detail.appendRow([
      'Question_ID',
      'Label',
      'Option',
      'Count',
      'Percent',
      'Answered_n',
    ]);
    for (final field in summary.fields) {
      if (field.rows.isEmpty) {
        detail.appendRow([
          field.questionId,
          field.label,
          '(no answers)',
          0,
          0,
          field.answeredCount,
        ]);
        continue;
      }
      for (final r in field.rows) {
        detail.appendRow([
          field.questionId,
          field.label,
          r.label,
          r.count,
          double.parse(r.percent.toStringAsFixed(1)),
          field.answeredCount,
        ]);
      }
    }

    final encoded = book.encode();
    if (encoded == null) {
      throw StateError('Excel encode returned null');
    }
    return Uint8List.fromList(encoded);
  }

  static String toCsv(ChedOutcomesSummary summary) {
    final buf = StringBuffer();
    String esc(String v) {
      final s = v.replaceAll('"', '""');
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"$s"';
      }
      return s;
    }

    buf.writeln('Survey,${esc(summary.survey.title)}');
    buf.writeln(
      'Generated,${esc(DateFormat.yMMMd().add_jm().format(summary.generatedAt))}',
    );
    buf.writeln('Assigned,${summary.assigned}');
    buf.writeln('Submitted,${summary.submitted}');
    buf.writeln('Pending,${summary.pending}');
    buf.writeln(
      'Completion_%,${summary.completionRate.toStringAsFixed(1)}',
    );
    buf.writeln('');
    buf.writeln('Question_ID,Label,Option,Count,Percent,Answered_n');
    for (final field in summary.fields) {
      if (field.rows.isEmpty) {
        buf.writeln(
          '${esc(field.questionId)},${esc(field.label)},(no answers),0,0,${field.answeredCount}',
        );
        continue;
      }
      for (final r in field.rows) {
        buf.writeln(
          '${esc(field.questionId)},${esc(field.label)},${esc(r.label)},'
          '${r.count},${r.percent.toStringAsFixed(1)},${field.answeredCount}',
        );
      }
    }
    return buf.toString();
  }

  static Uint8List toCsvBytes(ChedOutcomesSummary summary) {
    return Uint8List.fromList(utf8.encode('\uFEFF${toCsv(summary)}'));
  }

  static pw.Widget _pdfTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers.map(PdfSafeText.sanitize).toList(),
      data: [
        for (final row in rows)
          row.map(PdfSafeText.sanitize).toList(),
      ],
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
  }
}
