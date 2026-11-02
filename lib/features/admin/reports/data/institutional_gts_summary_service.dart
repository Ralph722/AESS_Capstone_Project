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
import 'package:alumni_system/features/surveys/data/survey_ched_outcomes_summary_service.dart';
import 'package:alumni_system/features/surveys/data/survey_report_analytics.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

/// Institutional (cross-wave) CHED GTS summary for Downloads.
class InstitutionalGtsSummary {
  const InstitutionalGtsSummary({
    required this.generatedAt,
    required this.waveTitles,
    required this.assigned,
    required this.submitted,
    required this.pending,
    required this.fields,
    this.reportTitle = 'CHED GTS Institutional Summary',
    this.sectionTwoTitle = 'Graduate outcome distributions',
    this.batchFilter,
    this.courseFilter,
  });

  final DateTime generatedAt;
  final List<String> waveTitles;
  final int assigned;
  final int submitted;
  final int pending;
  final List<ChedOutcomeFieldBlock> fields;
  final String reportTitle;
  final String sectionTwoTitle;
  final String? batchFilter;
  final String? courseFilter;

  ReportRate get responseRate => ReportMetrics.responseRate(
        submittedRespondents: submitted,
        eligibleAlumni: assigned,
      );

  String get scopeLabel {
    final parts = <String>[
      if (waveTitles.isEmpty) 'No waves'
      else if (waveTitles.length == 1)
        waveTitles.first
      else
        '${waveTitles.length} Official CHED waves',
      batchFilter ?? 'All batches',
      courseFilter ?? 'All courses',
    ];
    return parts.join(' | ');
  }
}

/// Builds aggregated Official CHED outcomes across a selected institutional scope.
abstract final class InstitutionalGtsSummaryService {
  static InstitutionalGtsSummary build({
    required List<Survey> waves,
    required Map<String, List<SurveyResponse>> responsesBySurveyId,
    required int assigned,
    required int submitted,
    required int pending,
    String? batchFilter,
    String? courseFilter,
    List<ChedWaveComparisonFieldSpec> fields =
        ChedOutcomesSummary.outcomeFields,
    String reportTitle = 'CHED GTS Institutional Summary',
    String sectionTwoTitle = 'Graduate outcome distributions',
  }) {
    final allResponses = <SurveyResponse>[
      for (final survey in waves)
        ...?responsesBySurveyId[survey.id]?.where(
          (r) => r.status == SurveyResponseStatus.submitted,
        ),
    ];

    final aggregates = SurveyReportAnalytics.aggregateChedResponses(
      responses: allResponses,
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
          final count = rawCount ?? ((percent / 100) * answered).round();
          rows.add(
            ChedOutcomeChoiceRow(
              label: label,
              count: count,
              percent: percent,
            ),
          );
        }
      }

      blocks.add(
        ChedOutcomeFieldBlock(
          questionId: spec.questionId,
          label: spec.shortLabel,
          answeredCount: answered,
          rows: rows,
          highlightLabel: spec.highlightOption,
          highlightPercent: spec.highlightOption == null
              ? null
              : pct[spec.highlightOption!],
        ),
      );
    }

    return InstitutionalGtsSummary(
      generatedAt: DateTime.now(),
      waveTitles: [
        for (final w in waves)
          w.title.trim().isEmpty ? 'Untitled wave' : w.title.trim(),
      ],
      assigned: assigned,
      submitted: submitted,
      pending: pending,
      fields: blocks,
      reportTitle: reportTitle,
      sectionTwoTitle: sectionTwoTitle,
      batchFilter: batchFilter,
      courseFilter: courseFilter,
    );
  }

  static Future<Uint8List> toPdf(InstitutionalGtsSummary summary) async {
    final doc = pw.Document();
    final stamp = DateFormat.yMMMMEEEEd().add_jm().format(summary.generatedAt);
    final rate = summary.responseRate;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: AessPdfTheme.pageMargin,
        header: (ctx) => AessPdfHeader.build(
          title: summary.reportTitle,
          subtitle: summary.scopeLabel,
          generationDate: stamp,
          classification: 'OFFICIAL REPORT',
        ),
        footer: (ctx) => AessPdfFooter.build(ctx),
        build: (ctx) {
          final widgets = <pw.Widget>[
            AessPdfTable.sectionHeading(
              '1. Coverage',
              subtitle:
                  'Response rate = submitted / assigned in the selected scope. '
                  'Unanswered outcome items are not treated as No.',
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
                  label: 'Response rate',
                  value: '${rate.percent.toStringAsFixed(1)}%',
                  isHighlight: true,
                ),
              ],
              columns: 4,
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              PdfSafeText.sanitize(
                'Waves: ${summary.waveTitles.isEmpty ? '-' : summary.waveTitles.join('; ')}',
              ),
              style: AessPdfTheme.caption,
            ),
            pw.SizedBox(height: 14),
            AessPdfTable.sectionHeading(
              '2. ${summary.sectionTwoTitle}',
              subtitle:
                  'Official CHED GTS indicators pooled across the selected waves. '
                  'Percentages use answered counts (n) as the denominator.',
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
              AessPdfTable.build(
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

  static Uint8List toExcel(InstitutionalGtsSummary summary) {
    const summarySheet = 'Summary';
    const outcomesSheet = 'Outcomes';
    final book = Excel.createExcel();
    final def = book.getDefaultSheet();
    if (def != null && def != summarySheet) {
      book[def].appendRow(['Institutional GTS sheets: $summarySheet, $outcomesSheet']);
    }

    final cover = book[summarySheet];
    cover.appendRow([summary.reportTitle]);
    cover.appendRow(['Scope', summary.scopeLabel]);
    cover.appendRow(['Generated', summary.generatedAt.toIso8601String()]);
    cover.appendRow(['Assigned', summary.assigned]);
    cover.appendRow(['Submitted', summary.submitted]);
    cover.appendRow(['Pending', summary.pending]);
    cover.appendRow([
      'Response rate %',
      summary.responseRate.percent.toStringAsFixed(1),
    ]);
    cover.appendRow(['Waves', summary.waveTitles.join('; ')]);

    final outcomes = book[outcomesSheet];
    outcomes.appendRow([
      'Question',
      'Option',
      'Count',
      'Percent of answered',
      'Answered n',
    ]);
    for (final field in summary.fields) {
      if (field.rows.isEmpty) {
        outcomes.appendRow([field.label, '(no answers)', 0, 0, 0]);
        continue;
      }
      for (final row in field.rows) {
        outcomes.appendRow([
          field.label,
          row.label,
          row.count,
          row.percent,
          field.answeredCount,
        ]);
      }
    }
    book.setDefaultSheet(summarySheet);
    final encoded = book.save();
    if (encoded == null) throw StateError('Excel encode returned null');
    return Uint8List.fromList(encoded);
  }

  static Uint8List toCsvBytes(InstitutionalGtsSummary summary) {
    final buf = StringBuffer();
    buf.writeln('section,key,value');
    buf.writeln('Coverage,scope,${CsvSafe.cell(summary.scopeLabel)}');
    buf.writeln('Coverage,assigned,${summary.assigned}');
    buf.writeln('Coverage,submitted,${summary.submitted}');
    buf.writeln('Coverage,pending,${summary.pending}');
    buf.writeln(
      'Coverage,response_rate_pct,${summary.responseRate.percent.toStringAsFixed(1)}',
    );
    for (final field in summary.fields) {
      for (final row in field.rows) {
        buf.writeln(
          'Outcomes,${CsvSafe.cell(field.label)} / ${CsvSafe.cell(row.label)},'
          '${row.count} (${row.percent.toStringAsFixed(1)}% of ${field.answeredCount})',
        );
      }
    }
    return Uint8List.fromList(utf8.encode('\uFEFF${buf.toString()}'));
  }
}
