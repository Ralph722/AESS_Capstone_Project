import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:alumni_system/core/pdf/aess_pdf_components.dart';
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/reports/application/ched_wave_comparison.dart';
import 'package:alumni_system/features/admin/reports/application/report_metrics.dart';
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
      final counts = agg?.choiceCounts ?? const <String, int>{};
      final rows = <ChedOutcomeChoiceRow>[];
      if (answered > 0) {
        final labels = <String>{...pct.keys, ...counts.keys}.toList()
          ..sort((a, b) => (pct[b] ?? 0).compareTo(pct[a] ?? 0));
        for (final label in labels) {
          final rawCount = counts[label];
          final percent = pct[label] ??
              ReportMetrics.optionShare(
                optionCount: rawCount ?? 0,
                answeredCount: answered,
              ).percent;
          // Prefer stored counts; fall back only for aggregates built without them.
          final count = rawCount ?? ((percent / 100) * answered).round();
          rows.add(
            ChedOutcomeChoiceRow(
              label: label,
              count: ReportMetrics.countFromShare(
                optionCount: count,
                ignoredRoundedPercent: percent,
              ),
              percent: percent,
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
    await AessPdfHeader.ensureLoaded();
    final doc = pw.Document();
    final stamp = DateFormat.yMMMMEEEEd().add_jm().format(summary.generatedAt);
    final title = summary.survey.title.trim().isEmpty
        ? 'CHED GTS outcomes'
        : summary.survey.title.trim();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: AessPdfTheme.pageMargin,
        header: (ctx) => AessPdfHeader.build(
          title: 'CHED Tracer Outcomes Summary',
          subtitle: title,
          generationDate: stamp,
          classification: 'OFFICIAL REPORT',
        ),
        footer: (ctx) => AessPdfFooter.build(ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[
            AessPdfTable.sectionHeading(
              '1. Wave Participation',
              subtitle:
                  'Rates include sample size (n). Treat percentages as directional when n is small.',
            ),
            AessPdfKpiGrid.build(
              items: [
                AessKpiItem(label: 'Assigned', value: '${summary.assigned}'),
                AessKpiItem(
                  label: 'Submitted',
                  value: '${summary.submitted}',
                  isHighlight: true,
                ),
                AessKpiItem(label: 'Pending', value: '${summary.pending}'),
                AessKpiItem(
                  label: 'Completion Rate',
                  value: '${summary.completionRate.toStringAsFixed(1)}%',
                  isHighlight: true,
                ),
              ],
              columns: 4,
            ),
            pw.SizedBox(height: 14),
            AessPdfTable.sectionHeading(
              '2. Key Outcome Distributions',
              subtitle: 'Official CHED GTS mandatory outcome indicators',
            ),
          ];

          for (final field in summary.fields) {
            final highlight = field.highlightLabel != null &&
                    field.highlightPercent != null
                ? 'Highlight: "${field.highlightLabel}" at ${field.highlightPercent!.toStringAsFixed(0)}% (n=${field.answeredCount})'
                : 'Sample size: n=${field.answeredCount}';

            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        PdfSafeText.sanitize(field.label),
                        style: AessPdfTheme.subSectionHeading,
                      ),
                    ),
                    pw.Text(
                      PdfSafeText.sanitize(highlight),
                      style: AessPdfTheme.caption,
                    ),
                  ],
                ),
              ),
            );

            if (field.answeredCount == 0) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    'No answers recorded yet (n=0)',
                    style: AessPdfTheme.tableCellMuted,
                  ),
                ),
              );
              continue;
            }

            widgets.add(
              _pdfTable(
                headers: const ['Option', 'Count (n)', 'Percentage (%)'],
                rows: [
                  for (final r in field.rows)
                    [
                      r.label,
                      '${r.count}',
                      '${r.percent.toStringAsFixed(1)}%',
                    ],
                ],
                columnWidths: AessPdfTable.chedOutcomesColumnWidths,
              ),
            );
            widgets.add(pw.SizedBox(height: 8));
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
    const esc = CsvSafe.cell;

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
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) {
    return AessPdfTable.build(
      headers: headers,
      rows: rows,
      columnWidths: columnWidths,
    );
  }
}
