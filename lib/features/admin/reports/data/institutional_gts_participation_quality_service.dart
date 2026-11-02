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

class InstitutionalWaveParticipationRow {
  const InstitutionalWaveParticipationRow({
    required this.waveTitle,
    required this.assigned,
    required this.submitted,
    required this.pending,
  });

  final String waveTitle;
  final int assigned;
  final int submitted;
  final int pending;

  ReportRate get responseRate => ReportMetrics.responseRate(
        submittedRespondents: submitted,
        eligibleAlumni: assigned,
      );
}

class InstitutionalMissingAnswerRow {
  const InstitutionalMissingAnswerRow({
    required this.questionId,
    required this.label,
    required this.answered,
    required this.missing,
    required this.submitted,
  });

  final String questionId;
  final String label;
  final int answered;
  final int missing;
  final int submitted;

  ReportRate get answerRate => ReportRate(
        hits: answered,
        total: submitted,
        hitsLabel: 'answered',
        totalLabel: 'submitted respondents',
      );

  ReportRate get missingRate => ReportRate(
        hits: missing,
        total: submitted,
        hitsLabel: 'missing',
        totalLabel: 'submitted respondents',
      );
}

/// Coverage + missing-answer quality for Official CHED GTS institutional scope.
class InstitutionalGtsParticipationQualityReport {
  const InstitutionalGtsParticipationQualityReport({
    required this.generatedAt,
    required this.waveRows,
    required this.missingRows,
    required this.assigned,
    required this.submitted,
    required this.pending,
    this.batchFilter,
    this.courseFilter,
  });

  final DateTime generatedAt;
  final List<InstitutionalWaveParticipationRow> waveRows;
  final List<InstitutionalMissingAnswerRow> missingRows;
  final int assigned;
  final int submitted;
  final int pending;
  final String? batchFilter;
  final String? courseFilter;

  ReportRate get responseRate => ReportMetrics.responseRate(
        submittedRespondents: submitted,
        eligibleAlumni: assigned,
      );

  String get scopeLabel {
    final waves = waveRows.map((w) => w.waveTitle).toList(growable: false);
    return [
      if (waves.isEmpty)
        'No waves'
      else if (waves.length == 1)
        waves.first
      else
        '${waves.length} Official CHED waves',
      batchFilter ?? 'All batches',
      courseFilter ?? 'All courses',
    ].join(' | ');
  }
}

abstract final class InstitutionalGtsParticipationQualityService {
  static InstitutionalGtsParticipationQualityReport build({
    required List<Survey> waves,
    required Map<String, List<SurveyResponse>> responsesBySurveyId,
    required Map<String, int> assignedBySurveyId,
    String? batchFilter,
    String? courseFilter,
    List<ChedWaveComparisonFieldSpec> fields =
        ChedOutcomesSummary.outcomeFields,
  }) {
    final waveRows = <InstitutionalWaveParticipationRow>[];
    var assigned = 0;
    var submitted = 0;
    final allSubmitted = <SurveyResponse>[];

    for (final survey in waves) {
      final title =
          survey.title.trim().isEmpty ? 'Untitled wave' : survey.title.trim();
      final waveAssigned = assignedBySurveyId[survey.id] ?? survey.assignmentCount;
      final waveSubmitted = (responsesBySurveyId[survey.id] ?? const [])
          .where((r) => r.status == SurveyResponseStatus.submitted)
          .toList(growable: false);
      final wavePending =
          (waveAssigned - waveSubmitted.length).clamp(0, waveAssigned);
      waveRows.add(
        InstitutionalWaveParticipationRow(
          waveTitle: title,
          assigned: waveAssigned,
          submitted: waveSubmitted.length,
          pending: wavePending,
        ),
      );
      assigned += waveAssigned;
      submitted += waveSubmitted.length;
      allSubmitted.addAll(waveSubmitted);
    }

    final pending = (assigned - submitted).clamp(0, assigned);
    final aggregates = SurveyReportAnalytics.aggregateChedResponses(
      responses: allSubmitted,
    );
    final byId = <String, SurveyQuestionAggregate>{
      for (final a in aggregates) a.questionId: a,
    };

    final missingRows = <InstitutionalMissingAnswerRow>[];
    for (final spec in fields) {
      final agg = byId[spec.questionId];
      final answered = agg?.answeredCount ?? 0;
      final total = agg?.totalResponses ?? allSubmitted.length;
      final missing = agg?.skippedCount ?? (total - answered).clamp(0, total);
      missingRows.add(
        InstitutionalMissingAnswerRow(
          questionId: spec.questionId,
          label: spec.shortLabel,
          answered: answered,
          missing: missing,
          submitted: total,
        ),
      );
    }
    missingRows.sort((a, b) {
      final cmp = b.missing.compareTo(a.missing);
      if (cmp != 0) return cmp;
      return a.label.compareTo(b.label);
    });

    return InstitutionalGtsParticipationQualityReport(
      generatedAt: DateTime.now(),
      waveRows: waveRows,
      missingRows: missingRows,
      assigned: assigned,
      submitted: submitted,
      pending: pending,
      batchFilter: batchFilter,
      courseFilter: courseFilter,
    );
  }

  static Future<Uint8List> toPdf(
    InstitutionalGtsParticipationQualityReport report,
  ) async {
    final doc = pw.Document();
    final stamp = DateFormat.yMMMMEEEEd().add_jm().format(report.generatedAt);
    final rate = report.responseRate;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: AessPdfTheme.pageMargin,
        header: (ctx) => AessPdfHeader.build(
          title: 'GTS Participation and Data Quality',
          subtitle: report.scopeLabel,
          generationDate: stamp,
          classification: 'OFFICIAL REPORT',
        ),
        footer: (ctx) => AessPdfFooter.build(ctx),
        build: (ctx) => [
          AessPdfTable.sectionHeading(
            '1. Coverage',
            subtitle:
                'Response rate = submitted / assigned for the selected Official '
                'CHED waves. Cohort filters apply to submitted respondents; '
                'assigned counts remain wave assignment totals.',
          ),
          AessPdfKpiGrid.build(
            items: [
              AessKpiItem(label: 'Assigned', value: '${report.assigned}'),
              AessKpiItem(
                label: 'Submitted',
                value: '${report.submitted}',
                isHighlight: true,
              ),
              AessKpiItem(label: 'Pending', value: '${report.pending}'),
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
            PdfSafeText.sanitize(rate.coverageNote),
            style: AessPdfTheme.caption,
          ),
          pw.SizedBox(height: 14),
          AessPdfTable.sectionHeading(
            '2. Participation by wave',
            subtitle: 'Pending = assigned - submitted (floored at zero).',
          ),
          if (report.waveRows.isEmpty)
            pw.Text(
              'No Official CHED waves in scope.',
              style: AessPdfTheme.tableCellMuted,
            )
          else
            AessPdfTable.build(
              headers: const [
                'Wave',
                'Assigned',
                'Submitted',
                'Pending',
                'Response %',
              ],
              rows: [
                for (final w in report.waveRows)
                  [
                    w.waveTitle,
                    '${w.assigned}',
                    '${w.submitted}',
                    '${w.pending}',
                    '${w.responseRate.percent.toStringAsFixed(1)}%',
                  ],
              ],
            ),
          pw.SizedBox(height: 14),
          AessPdfTable.sectionHeading(
            '3. Missing answers among submitted respondents',
            subtitle:
                'Missing = submitted respondents with no usable answer for the '
                'item. Skip-logic items can legitimately show high missing rates.',
          ),
          if (report.missingRows.isEmpty)
            pw.Text(
              'No submitted respondents to assess.',
              style: AessPdfTheme.tableCellMuted,
            )
          else
            AessPdfTable.build(
              headers: const [
                'Item',
                'Answered',
                'Missing',
                'Submitted',
                'Missing %',
              ],
              rows: [
                for (final m in report.missingRows)
                  [
                    m.label,
                    '${m.answered}',
                    '${m.missing}',
                    '${m.submitted}',
                    m.submitted == 0
                        ? '-'
                        : '${m.missingRate.percent.toStringAsFixed(1)}%',
                  ],
              ],
            ),
        ],
      ),
    );
    return doc.save();
  }

  static Uint8List toExcel(InstitutionalGtsParticipationQualityReport report) {
    const coverage = 'Coverage';
    const waves = 'By wave';
    const missing = 'Missing answers';
    final book = Excel.createExcel();
    final def = book.getDefaultSheet();
    if (def != null && def != coverage) {
      book[def].appendRow([
        'Sheets: $coverage, $waves, $missing',
      ]);
    }

    final cover = book[coverage];
    cover.appendRow(['GTS Participation and Data Quality']);
    cover.appendRow(['Scope', report.scopeLabel]);
    cover.appendRow(['Generated', report.generatedAt.toIso8601String()]);
    cover.appendRow([]);
    cover.appendRow(['Metric', 'Value', 'Denominator note']);
    cover.appendRow(['Assigned', report.assigned, 'Wave assignment totals']);
    cover.appendRow([
      'Submitted',
      report.submitted,
      'Submitted respondents in scope',
    ]);
    cover.appendRow(['Pending', report.pending, 'Assigned - submitted']);
    cover.appendRow([
      'Response rate %',
      report.responseRate.percent,
      report.responseRate.coverageNote,
    ]);

    final waveSheet = book[waves];
    waveSheet.appendRow([
      'Wave',
      'Assigned',
      'Submitted',
      'Pending',
      'Response %',
    ]);
    for (final w in report.waveRows) {
      waveSheet.appendRow([
        w.waveTitle,
        w.assigned,
        w.submitted,
        w.pending,
        w.responseRate.percent,
      ]);
    }

    final missSheet = book[missing];
    missSheet.appendRow([
      'Question id',
      'Item',
      'Answered',
      'Missing',
      'Submitted',
      'Missing %',
      'Answered %',
    ]);
    for (final m in report.missingRows) {
      missSheet.appendRow([
        m.questionId,
        m.label,
        m.answered,
        m.missing,
        m.submitted,
        m.missingRate.percent,
        m.answerRate.percent,
      ]);
    }

    book.setDefaultSheet(coverage);
    final encoded = book.save();
    if (encoded == null) throw StateError('Excel encode returned null');
    return Uint8List.fromList(encoded);
  }

  static Uint8List toCsvBytes(
    InstitutionalGtsParticipationQualityReport report,
  ) {
    final buf = StringBuffer();
    buf.writeln('section,key,value,note');
    buf.writeln(
      [
        'coverage',
        'assigned',
        report.assigned,
        CsvSafe.cell('Wave assignment totals'),
      ].join(','),
    );
    buf.writeln(
      [
        'coverage',
        'submitted',
        report.submitted,
        CsvSafe.cell('Submitted respondents in scope'),
      ].join(','),
    );
    buf.writeln(
      [
        'coverage',
        'pending',
        report.pending,
        CsvSafe.cell('Assigned - submitted'),
      ].join(','),
    );
    buf.writeln(
      [
        'coverage',
        'response_rate_pct',
        report.responseRate.percent.toStringAsFixed(1),
        CsvSafe.cell(report.responseRate.coverageNote),
      ].join(','),
    );
    for (final w in report.waveRows) {
      buf.writeln(
        [
          'wave',
          CsvSafe.cell(w.waveTitle),
          w.submitted,
          CsvSafe.cell(
            'assigned=${w.assigned};pending=${w.pending};'
            'rate=${w.responseRate.percent.toStringAsFixed(1)}%',
          ),
        ].join(','),
      );
    }
    for (final m in report.missingRows) {
      buf.writeln(
        [
          'missing',
          CsvSafe.cell(m.questionId),
          m.missing,
          CsvSafe.cell(
            '${m.label};answered=${m.answered};submitted=${m.submitted};'
            'missing_pct=${m.missingRate.percent.toStringAsFixed(1)}%',
          ),
        ].join(','),
      );
    }
    return Uint8List.fromList(utf8.encode('\uFEFF${buf.toString()}'));
  }
}
