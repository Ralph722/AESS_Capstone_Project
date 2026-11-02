import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:alumni_system/core/pdf/aess_pdf_components.dart';
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/features/admin/reports/application/report_metrics.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

enum InstitutionalCompareDimension { course, batch }

class InstitutionalCohortComparisonRow {
  const InstitutionalCohortComparisonRow({
    required this.label,
    required this.respondents,
    required this.answeredEmployment,
    required this.employed,
    required this.answeredRelated,
    required this.relatedYes,
    required this.answeredCurriculum,
    required this.curriculumYes,
  });

  final String label;
  final int respondents;
  final int answeredEmployment;
  final int employed;
  final int answeredRelated;
  final int relatedYes;
  final int answeredCurriculum;
  final int curriculumYes;

  ReportRate get employmentRate => ReportMetrics.employmentRate(
        employedRespondents: employed,
        answeredEmploymentStatus: answeredEmployment,
      );

  ReportRate get relatedRate => ReportMetrics.optionShare(
        optionCount: relatedYes,
        answeredCount: answeredRelated,
        optionLabel: 'related yes',
      );

  ReportRate get curriculumRate => ReportMetrics.optionShare(
        optionCount: curriculumYes,
        answeredCount: answeredCurriculum,
        optionLabel: 'curriculum yes',
      );
}

class InstitutionalCohortComparisonReport {
  const InstitutionalCohortComparisonReport({
    required this.generatedAt,
    required this.dimension,
    required this.waveTitles,
    required this.rows,
    this.batchFilter,
    this.courseFilter,
  });

  final DateTime generatedAt;
  final InstitutionalCompareDimension dimension;
  final List<String> waveTitles;
  final List<InstitutionalCohortComparisonRow> rows;
  final String? batchFilter;
  final String? courseFilter;

  String get scopeLabel {
    final dim = dimension == InstitutionalCompareDimension.course
        ? 'By course'
        : 'By graduation batch';
    return [
      dim,
      if (waveTitles.length == 1) waveTitles.first else '${waveTitles.length} waves',
      batchFilter ?? 'All batches',
      courseFilter ?? 'All courses',
    ].join(' | ');
  }
}

/// Side-by-side graduate outcomes by program or graduation cohort.
abstract final class InstitutionalCohortComparisonService {
  static InstitutionalCohortComparisonReport build({
    required List<Survey> waves,
    required Map<String, List<SurveyResponse>> responsesBySurveyId,
    required Map<String, AlumniMember> memberByAuth,
    required InstitutionalCompareDimension dimension,
    String? batchFilter,
    String? courseFilter,
  }) {
    final buckets = <String, _Acc>{};

    for (final survey in waves) {
      final responses = responsesBySurveyId[survey.id] ?? const [];
      for (final r in responses) {
        if (r.status != SurveyResponseStatus.submitted) continue;
        final member = memberByAuth[r.userId.trim()];
        final course = (member?.course ?? '').trim();
        final batch = () {
          final b = (member?.batchYear ?? '').trim();
          if (b.isNotEmpty) return b;
          return (member?.yearGraduated ?? '').trim();
        }();
        final key = dimension == InstitutionalCompareDimension.course
            ? (course.isEmpty ? 'Unspecified course' : course)
            : (batch.isEmpty ? 'Unspecified batch' : batch);
        final acc = buckets.putIfAbsent(key, _Acc.new);
        acc.respondents++;

        final employedRaw = formatSurveyAnswerValue(r.answers['ched_16']);
        if (employedRaw.isNotEmpty) {
          acc.answeredEmployment++;
          if (employedRaw == ChedGtsBuiltin.yes) acc.employed++;
        }
        final relatedRaw = formatSurveyAnswerValue(r.answers['ched_24a']);
        if (relatedRaw.isNotEmpty) {
          acc.answeredRelated++;
          if (relatedRaw == ChedGtsBuiltin.yes) acc.relatedYes++;
        }
        final currRaw = formatSurveyAnswerValue(r.answers['ched_32']);
        if (currRaw.isNotEmpty) {
          acc.answeredCurriculum++;
          if (currRaw == ChedGtsBuiltin.yes) acc.curriculumYes++;
        }
      }
    }

    final rows = buckets.entries
        .map(
          (e) => InstitutionalCohortComparisonRow(
            label: e.key,
            respondents: e.value.respondents,
            answeredEmployment: e.value.answeredEmployment,
            employed: e.value.employed,
            answeredRelated: e.value.answeredRelated,
            relatedYes: e.value.relatedYes,
            answeredCurriculum: e.value.answeredCurriculum,
            curriculumYes: e.value.curriculumYes,
          ),
        )
        .toList()
      ..sort((a, b) => b.respondents.compareTo(a.respondents));

    return InstitutionalCohortComparisonReport(
      generatedAt: DateTime.now(),
      dimension: dimension,
      waveTitles: [
        for (final w in waves)
          w.title.trim().isEmpty ? 'Untitled wave' : w.title.trim(),
      ],
      rows: rows,
      batchFilter: batchFilter,
      courseFilter: courseFilter,
    );
  }

  static Future<Uint8List> toPdf(InstitutionalCohortComparisonReport report) async {
    final doc = pw.Document();
    final stamp = DateFormat.yMMMMEEEEd().add_jm().format(report.generatedAt);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: AessPdfTheme.pageMargin,
        header: (ctx) => AessPdfHeader.build(
          title: 'Program and Cohort Comparison',
          subtitle: report.scopeLabel,
          generationDate: stamp,
          classification: 'OFFICIAL REPORT',
        ),
        footer: (ctx) => AessPdfFooter.build(ctx),
        build: (ctx) => [
          AessPdfTable.sectionHeading(
            '1. Comparison table',
            subtitle:
                'Rates use answered denominators only. Groups with small n should '
                'be treated as directional. Waves: ${report.waveTitles.join('; ')}',
          ),
          if (report.rows.isEmpty)
            pw.Text(
              'No submitted respondents in the selected scope.',
              style: AessPdfTheme.tableCellMuted,
            )
          else
            AessPdfTable.build(
              headers: const [
                'Group',
                'Respondents',
                'Employed %',
                'Emp. n',
                'Related %',
                'Rel. n',
                'Curriculum %',
                'Curr. n',
              ],
              rows: [
                for (final r in report.rows)
                  [
                    r.label,
                    '${r.respondents}',
                    r.answeredEmployment == 0
                        ? '-'
                        : '${r.employmentRate.percent.toStringAsFixed(1)}%',
                    '${r.answeredEmployment}',
                    r.answeredRelated == 0
                        ? '-'
                        : '${r.relatedRate.percent.toStringAsFixed(1)}%',
                    '${r.answeredRelated}',
                    r.answeredCurriculum == 0
                        ? '-'
                        : '${r.curriculumRate.percent.toStringAsFixed(1)}%',
                    '${r.answeredCurriculum}',
                  ],
              ],
            ),
        ],
      ),
    );
    return doc.save();
  }

  static Uint8List toExcel(InstitutionalCohortComparisonReport report) {
    const sheetName = 'Comparison';
    final book = Excel.createExcel();
    final def = book.getDefaultSheet();
    if (def != null && def != sheetName) {
      book[def].appendRow(['Comparison is on the "$sheetName" sheet.']);
    }
    final sheet = book[sheetName];
    sheet.appendRow(['Program and Cohort Comparison']);
    sheet.appendRow(['Scope', report.scopeLabel]);
    sheet.appendRow(['Generated', report.generatedAt.toIso8601String()]);
    sheet.appendRow([]);
    sheet.appendRow([
      'Group',
      'Respondents',
      'Employed',
      'Answered employment',
      'Employment %',
      'Related yes',
      'Answered related',
      'Related %',
      'Curriculum yes',
      'Answered curriculum',
      'Curriculum %',
    ]);
    for (final r in report.rows) {
      sheet.appendRow([
        r.label,
        r.respondents,
        r.employed,
        r.answeredEmployment,
        r.employmentRate.percent,
        r.relatedYes,
        r.answeredRelated,
        r.relatedRate.percent,
        r.curriculumYes,
        r.answeredCurriculum,
        r.curriculumRate.percent,
      ]);
    }
    book.setDefaultSheet(sheetName);
    final encoded = book.save();
    if (encoded == null) throw StateError('Excel encode returned null');
    return Uint8List.fromList(encoded);
  }

  static Uint8List toCsvBytes(InstitutionalCohortComparisonReport report) {
    final buf = StringBuffer();
    buf.writeln(
      'group,respondents,employed,answered_employment,employment_pct,'
      'related_yes,answered_related,related_pct,'
      'curriculum_yes,answered_curriculum,curriculum_pct',
    );
    for (final r in report.rows) {
      buf.writeln(
        [
          CsvSafe.cell(r.label),
          r.respondents,
          r.employed,
          r.answeredEmployment,
          r.employmentRate.percent.toStringAsFixed(1),
          r.relatedYes,
          r.answeredRelated,
          r.relatedRate.percent.toStringAsFixed(1),
          r.curriculumYes,
          r.answeredCurriculum,
          r.curriculumRate.percent.toStringAsFixed(1),
        ].join(','),
      );
    }
    return Uint8List.fromList(utf8.encode('\uFEFF${buf.toString()}'));
  }
}

class _Acc {
  int respondents = 0;
  int answeredEmployment = 0;
  int employed = 0;
  int answeredRelated = 0;
  int relatedYes = 0;
  int answeredCurriculum = 0;
  int curriculumYes = 0;
}
