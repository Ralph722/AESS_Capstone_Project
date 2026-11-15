import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:alumni_system/core/pdf/aess_pdf_components.dart';
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/reports/application/report_metrics.dart';
import 'package:alumni_system/features/admin/reports/application/report_percent_format.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// One exam name with how many distinct alumni listed it (Q13).
class ProfessionalExamNameCount {
  const ProfessionalExamNameCount({
    required this.examName,
    required this.alumniCount,
  });

  final String examName;
  final int alumniCount;
}

/// Course cut: submitted vs passed ≥1 exam.
class ProfessionalExamCourseRow {
  const ProfessionalExamCourseRow({
    required this.course,
    required this.submitted,
    required this.passedAtLeastOne,
  });

  final String course;
  final int submitted;
  final int passedAtLeastOne;

  ReportRate get passRate => ReportRate(
        hits: passedAtLeastOne,
        total: submitted,
        hitsLabel: 'passed ≥1 exam',
        totalLabel: 'submitted respondents',
      );
}

/// Anonymized detail row (no alumni name) for Excel.
class ProfessionalExamDetailRow {
  const ProfessionalExamDetailRow({
    required this.examName,
    required this.dateTaken,
    required this.rating,
    required this.course,
    required this.batch,
  });

  final String examName;
  final String dateTaken;
  final String rating;
  final String course;
  final String batch;
}

/// Institutional pack for CHED Q13 — Professional Examination(s) Passed.
class InstitutionalProfessionalExamsReport {
  const InstitutionalProfessionalExamsReport({
    required this.generatedAt,
    required this.waveTitles,
    required this.submitted,
    required this.passedAtLeastOne,
    required this.noneListed,
    required this.examRows,
    required this.totalExamRows,
    required this.byCourse,
    required this.detailRows,
    this.batchFilter,
    this.courseFilter,
  });

  final DateTime generatedAt;
  final List<String> waveTitles;
  final int submitted;
  final int passedAtLeastOne;
  final int noneListed;
  final List<ProfessionalExamNameCount> examRows;
  final int totalExamRows;
  final List<ProfessionalExamCourseRow> byCourse;
  final List<ProfessionalExamDetailRow> detailRows;
  final String? batchFilter;
  final String? courseFilter;

  ReportRate get passRate => ReportRate(
        hits: passedAtLeastOne,
        total: submitted,
        hitsLabel: 'passed ≥1 exam',
        totalLabel: 'submitted respondents',
      );

  String get scopeLabel {
    final parts = <String>[
      if (waveTitles.isEmpty)
        'No waves'
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

abstract final class InstitutionalProfessionalExamsService {
  static const examNameColumn = 'Name of Examination';
  static const dateColumn = 'Date Taken';
  static const ratingColumn = 'Rating';

  static InstitutionalProfessionalExamsReport build({
    required List<Survey> waves,
    required Map<String, List<SurveyResponse>> responsesBySurveyId,
    required Map<String, AlumniMember> memberByAuth,
    String? batchFilter,
    String? courseFilter,
  }) {
    var submitted = 0;
    var passed = 0;
    var totalExamRows = 0;
    final examAlumni = <String, Set<String>>{};
    final examDisplay = <String, String>{};
    final courseSubmitted = <String, int>{};
    final coursePassed = <String, int>{};
    final details = <ProfessionalExamDetailRow>[];

    for (final survey in waves) {
      final rows = responsesBySurveyId[survey.id] ?? const <SurveyResponse>[];
      for (final r in rows) {
        if (r.status != SurveyResponseStatus.submitted) continue;
        submitted++;
        final member = memberByAuth[r.userId];
        final courseLabel = _courseLabel(member);
        courseSubmitted[courseLabel] = (courseSubmitted[courseLabel] ?? 0) + 1;

        final exams = _examNames(r.answers['ched_13']);
        if (exams.isEmpty) continue;

        passed++;
        coursePassed[courseLabel] = (coursePassed[courseLabel] ?? 0) + 1;
        totalExamRows += exams.length;

        final seenInResponse = <String>{};
        for (final exam in exams) {
          final key = _normalizeKey(exam.name);
          if (key.isEmpty) continue;
          examDisplay.putIfAbsent(key, () => exam.name);
          if (seenInResponse.add(key)) {
            (examAlumni[key] ??= <String>{}).add(r.userId);
          }
          details.add(
            ProfessionalExamDetailRow(
              examName: exam.name,
              dateTaken: exam.dateTaken,
              rating: exam.rating,
              course: courseLabel,
              batch: _batchLabel(member),
            ),
          );
        }
      }
    }

    final examRows = [
      for (final e in examAlumni.entries)
        ProfessionalExamNameCount(
          examName: examDisplay[e.key] ?? e.key,
          alumniCount: e.value.length,
        ),
    ]..sort((a, b) {
        final c = b.alumniCount.compareTo(a.alumniCount);
        if (c != 0) return c;
        return a.examName.toLowerCase().compareTo(b.examName.toLowerCase());
      });

    final byCourse = [
      for (final course in courseSubmitted.keys)
        ProfessionalExamCourseRow(
          course: course,
          submitted: courseSubmitted[course]!,
          passedAtLeastOne: coursePassed[course] ?? 0,
        ),
    ]..sort((a, b) {
        final c = b.passedAtLeastOne.compareTo(a.passedAtLeastOne);
        if (c != 0) return c;
        return a.course.toLowerCase().compareTo(b.course.toLowerCase());
      });

    return InstitutionalProfessionalExamsReport(
      generatedAt: DateTime.now(),
      waveTitles: [
        for (final w in waves)
          w.title.trim().isEmpty ? 'Untitled wave' : w.title.trim(),
      ],
      submitted: submitted,
      passedAtLeastOne: passed,
      noneListed: (submitted - passed).clamp(0, submitted),
      examRows: examRows,
      totalExamRows: totalExamRows,
      byCourse: byCourse,
      detailRows: details,
      batchFilter: batchFilter,
      courseFilter: courseFilter,
    );
  }

  static Future<Uint8List> toPdf(
    InstitutionalProfessionalExamsReport report,
  ) async {
    await AessPdfHeader.ensureLoaded();
    final doc = pw.Document();
    final stamp =
        DateFormat.yMMMMEEEEd().add_jm().format(report.generatedAt);
    final rate = report.passRate;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: AessPdfTheme.pageMargin,
        header: (ctx) => AessPdfHeader.build(
          title: 'Professional Exams & Licensure Overview',
          subtitle: report.scopeLabel,
          generationDate: stamp,
          classification: 'OFFICIAL REPORT',
        ),
        footer: (ctx) => AessPdfFooter.build(ctx),
        build: (ctx) => [
          AessPdfTable.sectionHeading(
            '1. Summary',
            subtitle:
                'Based on CHED GTS item 13 (Professional Examination(s) Passed). '
                'Blank means no exam was listed — not that the alumnus failed.',
          ),
          AessPdfTable.build(
            headers: const ['Metric', 'Value'],
            rows: [
              ['Tracer answers in scope', '${report.submitted}'],
              [
                'Passed at least one exam (Q13)',
                '${report.passedAtLeastOne} '
                    '(${formatReportPercentPoints(rate.percent)})',
              ],
              [
                'No exam listed / left blank',
                '${report.noneListed} '
                    '(${formatReportPercent(
                      report.submitted == 0
                          ? 0
                          : report.noneListed / report.submitted,
                    )})',
              ],
              ['Total exam rows listed', '${report.totalExamRows}'],
            ],
          ),
          pw.SizedBox(height: 14),
          AessPdfTable.sectionHeading('2. Exams passed (breakdown)'),
          if (report.examRows.isEmpty)
            pw.Text(
              PdfSafeText.sanitize(
                'No examination names listed in this scope.',
              ),
              style: AessPdfTheme.caption,
            )
          else
            AessPdfTable.build(
              headers: const [
                'Name of examination',
                'Alumni',
                'Share of those who listed an exam',
              ],
              rows: [
                for (final e in report.examRows)
                  [
                    e.examName,
                    '${e.alumniCount}',
                    report.passedAtLeastOne == 0
                        ? '-'
                        : formatReportPercent(
                            e.alumniCount / report.passedAtLeastOne,
                          ),
                  ],
              ],
            ),
          if (report.byCourse.length > 1) ...[
            pw.SizedBox(height: 14),
            AessPdfTable.sectionHeading('3. By course'),
            AessPdfTable.build(
              headers: const [
                'Course',
                'Answers',
                'Passed ≥1 exam',
                'Rate',
              ],
              rows: [
                for (final c in report.byCourse)
                  [
                    c.course,
                    '${c.submitted}',
                    '${c.passedAtLeastOne}',
                    c.submitted == 0
                        ? '-'
                        : formatReportPercentPoints(c.passRate.percent),
                  ],
              ],
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static Uint8List toExcel(InstitutionalProfessionalExamsReport report) {
    const summary = 'Summary';
    const exams = 'Exam breakdown';
    const byCourse = 'By course';
    const detail = 'Detail (no names)';
    final book = Excel.createExcel();
    final def = book.getDefaultSheet();
    if (def != null && def != summary) {
      book[def].appendRow([
        'Sheets: $summary, $exams, $byCourse, $detail',
      ]);
    }

    final cover = book[summary];
    cover.appendRow(['Professional Exams & Licensure Overview']);
    cover.appendRow(['Scope', report.scopeLabel]);
    cover.appendRow(['Generated', report.generatedAt.toIso8601String()]);
    cover.appendRow([
      'Note',
      'CHED GTS Q13 — Professional Examination(s) Passed. '
          'Blank means none listed.',
    ]);
    cover.appendRow([]);
    cover.appendRow(['Metric', 'Value']);
    cover.appendRow(['Tracer answers in scope', report.submitted]);
    cover.appendRow([
      'Passed at least one exam',
      report.passedAtLeastOne,
    ]);
    cover.appendRow([
      'Pass rate %',
      report.passRate.percent,
    ]);
    cover.appendRow(['No exam listed', report.noneListed]);
    cover.appendRow(['Total exam rows', report.totalExamRows]);

    final examSheet = book[exams];
    examSheet.appendRow([
      'Name of examination',
      'Alumni',
      'Share of those who listed an exam %',
    ]);
    for (final e in report.examRows) {
      examSheet.appendRow([
        e.examName,
        e.alumniCount,
        report.passedAtLeastOne == 0
            ? null
            : (100.0 * e.alumniCount / report.passedAtLeastOne),
      ]);
    }

    final courseSheet = book[byCourse];
    courseSheet.appendRow([
      'Course',
      'Answers',
      'Passed ≥1 exam',
      'Rate %',
    ]);
    for (final c in report.byCourse) {
      courseSheet.appendRow([
        c.course,
        c.submitted,
        c.passedAtLeastOne,
        c.passRate.percent,
      ]);
    }

    final detailSheet = book[detail];
    detailSheet.appendRow([
      'Exam',
      'Date taken',
      'Rating',
      'Course',
      'Batch',
    ]);
    for (final d in report.detailRows) {
      detailSheet.appendRow([
        d.examName,
        d.dateTaken,
        d.rating,
        d.course,
        d.batch,
      ]);
    }

    book.setDefaultSheet(summary);
    final encoded = book.save();
    if (encoded == null) throw StateError('Excel encode returned null');
    return Uint8List.fromList(encoded);
  }

  static Uint8List toCsvBytes(InstitutionalProfessionalExamsReport report) {
    final buf = StringBuffer();
    buf.writeln('section,key,value,note');
    buf.writeln(
      [
        'summary',
        'submitted',
        report.submitted,
        CsvSafe.cell('Tracer answers in scope'),
      ].join(','),
    );
    buf.writeln(
      [
        'summary',
        'passed_at_least_one',
        report.passedAtLeastOne,
        CsvSafe.cell('Q13 listed ≥1 exam name'),
      ].join(','),
    );
    buf.writeln(
      [
        'summary',
        'pass_rate_pct',
        report.passRate.percent.toStringAsFixed(1),
        CsvSafe.cell(report.passRate.coverageNote),
      ].join(','),
    );
    buf.writeln(
      [
        'summary',
        'none_listed',
        report.noneListed,
        CsvSafe.cell('No exam name in Q13'),
      ].join(','),
    );
    for (final e in report.examRows) {
      buf.writeln(
        [
          'exam',
          CsvSafe.cell(e.examName),
          e.alumniCount,
          CsvSafe.cell('distinct alumni'),
        ].join(','),
      );
    }
    for (final c in report.byCourse) {
      buf.writeln(
        [
          'course',
          CsvSafe.cell(c.course),
          c.passedAtLeastOne,
          CsvSafe.cell(
            'submitted=${c.submitted};rate=${c.passRate.percent.toStringAsFixed(1)}%',
          ),
        ].join(','),
      );
    }
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }

  static String _courseLabel(AlumniMember? m) {
    final c = m?.course.trim() ?? '';
    return c.isEmpty ? 'Unknown course' : c;
  }

  static String _batchLabel(AlumniMember? m) {
    final b = m?.batchYear.trim() ?? '';
    return b.isEmpty ? 'Unknown batch' : b;
  }

  static String _normalizeKey(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static List<({String name, String dateTaken, String rating})> _examNames(
    dynamic raw,
  ) {
    if (raw is! List) return const [];
    final out = <({String name, String dateTaken, String rating})>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final name = _cell(row, examNameColumn);
      if (name.isEmpty) continue;
      out.add((
        name: name,
        dateTaken: _cell(row, dateColumn),
        rating: _cell(row, ratingColumn),
      ));
    }
    return out;
  }

  static String _cell(Map row, String key) {
    final v = row[key];
    if (v == null) return '';
    return v.toString().trim();
  }
}
