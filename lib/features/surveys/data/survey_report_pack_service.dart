import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/surveys/data/survey_report_analytics.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

/// Professional multi-section survey report packs (Phase 6).
///
/// Sections: Executive, Survey, Participation, Audience, Question, Response,
/// Insights, Recommendations — exportable as PDF, Excel, or CSV.
class SurveyReportPackService {
  SurveyReportPackService._();

  static SurveyReportPack buildPortfolioPack({
    required AdminReportsAnalytics analytics,
    List<SurveyReportRollup> rollups = const [],
  }) {
    final active = analytics.surveys.where((s) => !s.archived).toList();
    final ratePct = (analytics.surveyResponseRate * 100);
    final insights = <String>[];
    final recommendations = <String>[];

    insights.add(
      'Portfolio completion rate is ${ratePct.toStringAsFixed(0)}% '
      '(${analytics.totalSurveyResponses} submitted of '
      '${analytics.totalSurveyAssignments} assignments).',
    );
    insights.add(
      '${analytics.publishedSurveys} published, ${analytics.draftSurveys} draft, '
      '${analytics.closedSurveys} closed, ${analytics.archivedSurveys} archived.',
    );
    if (analytics.pendingSurveyAssignments > 0) {
      insights.add(
        '${analytics.pendingSurveyAssignments} alumni still have pending '
        'survey assignments.',
      );
    }

    if (ratePct < 50 && analytics.totalSurveyAssignments > 0) {
      recommendations.add(
        'Completion is below 50%. Send reminders on published waves and '
        'review audience targeting (program/batch filters).',
      );
    } else if (ratePct >= 80) {
      recommendations.add(
        'Strong completion. Archive closed waves and document lessons for '
        'the next tracer cycle.',
      );
    }
    if (analytics.draftSurveys > 0) {
      recommendations.add(
        '${analytics.draftSurveys} draft survey(s) await publish — finish '
        'audience/schedule and publish when ready.',
      );
    }
    if (analytics.pendingSurveyAssignments > 20) {
      recommendations.add(
        'Large pending backlog — use Remind pending from each wave, then '
        're-assign if new alumni matched the audience.',
      );
    }
    if (rollups.isNotEmpty) {
      final skipped = <SurveyQuestionAggregate>[];
      for (final r in rollups) {
        skipped.addAll(SurveyReportAnalytics.mostSkipped(r.aggregates, limit: 2));
      }
      skipped.sort((a, b) {
        final ra = a.totalResponses == 0 ? 0.0 : a.skippedCount / a.totalResponses;
        final rb = b.totalResponses == 0 ? 0.0 : b.skippedCount / b.totalResponses;
        return rb.compareTo(ra);
      });
      if (skipped.isNotEmpty) {
        insights.add(
          'Highest skip rate among summarized questions: '
          '"${skipped.first.prompt}" '
          '(${((skipped.first.skippedCount / skipped.first.totalResponses) * 100).toStringAsFixed(0)}%).',
        );
        recommendations.add(
          'Review high-skip questions for clarity, required flags, or '
          'conditional visibility.',
        );
      }
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        'Continue monitoring weekly completion and keep Official CHED GTS '
        'waves locked to the built-in template.',
      );
    }

    final surveyRows = active
        .map((s) {
          final assigned = analytics.assignmentCount(s);
          final submitted = analytics.submittedResponseCount(s);
          final r = assigned == 0 ? 0.0 : (submitted / assigned) * 100;
          return SurveyPackSurveyRow(
            title: s.title.isEmpty ? 'Untitled' : s.title,
            status: s.archived ? 'archived' : s.status.name,
            kind: s.isChedGtsBuiltin
                ? 'Official CHED'
                : (s.isFromTemplate ? 'CHED preset' : 'Custom'),
            assigned: assigned,
            submitted: submitted,
            completionPct: r,
          );
        })
        .toList()
      ..sort((a, b) => b.submitted.compareTo(a.submitted));

    final questionRows = <SurveyPackQuestionRow>[];
    for (final rollup in rollups) {
      for (final a in rollup.aggregates.take(12)) {
        questionRows.add(
          SurveyPackQuestionRow(
            surveyTitle: rollup.survey.title,
            prompt: a.prompt,
            type: a.type.name,
            answered: a.answeredCount,
            total: a.totalResponses,
            skipped: a.skippedCount,
            detail: _questionDetail(a),
          ),
        );
      }
    }

    return SurveyReportPack(
      title: 'Survey Management Report Pack',
      subtitle: 'Institutional survey portfolio',
      generatedAt: DateTime.now(),
      executiveBullets: [
        'Active surveys (non-archived): ${active.length}',
        'Published: ${analytics.publishedSurveys}',
        'Assignments: ${analytics.totalSurveyAssignments}',
        'Submitted responses: ${analytics.totalSurveyResponses}',
        'Pending: ${analytics.pendingSurveyAssignments}',
        'Completion rate: ${ratePct.toStringAsFixed(1)}%',
      ],
      surveyRows: surveyRows,
      participation: SurveyParticipationSnapshot(
        assigned: analytics.totalSurveyAssignments,
        notStarted: 0,
        inProgress: analytics.pendingSurveyAssignments,
        completed: analytics.totalSurveyResponses,
      ),
      participationNote:
          'Portfolio funnel uses submitted responses as completed and '
          'pending assignments as in-progress/not-started combined.',
      audienceBuckets: const [],
      audienceNote:
          'Open a single survey’s Responses → Overview for course/batch '
          'audience analytics, or export a per-survey pack.',
      questionRows: questionRows,
      responseRows: const [],
      responseNote:
          'Per-respondent extracts are available from each survey’s export '
          'menu (CSV / CHED Excel). This pack focuses on management summaries.',
      insights: insights,
      recommendations: recommendations,
    );
  }

  static SurveyReportPack buildSurveyPack({
    required Survey survey,
    required List<SurveyParticipant> participants,
    required List<SurveyQuestion> questions,
    required List<SurveyResponse> responses,
  }) {
    final participation =
        SurveyReportAnalytics.participationFromParticipants(participants);
    final byProgram = SurveyReportAnalytics.audienceByProgram(participants);
    final byBatch = SurveyReportAnalytics.audienceByBatch(participants);
    final reminders = SurveyReportAnalytics.reminderStats(participants);
    final submitted = responses
        .where((r) => r.status == SurveyResponseStatus.submitted)
        .toList();
    final aggregates = survey.isChedGtsBuiltin
        ? SurveyReportAnalytics.aggregateChedResponses(responses: submitted)
        : SurveyReportAnalytics.aggregateResponses(
            questions: questions,
            responses: submitted,
          );
    final skipped = SurveyReportAnalytics.mostSkipped(aggregates, limit: 5);

    final insights = <String>[
      'Completion rate ${participation.completionRate.toStringAsFixed(0)}% '
          '(${participation.completed}/${participation.assigned}).',
      'Funnel: ${participation.notStarted} not started, '
          '${participation.inProgress} in progress, '
          '${participation.completed} completed.',
      if (reminders.totalRemindersSent > 0)
        '${reminders.totalRemindersSent} reminders sent to '
            '${reminders.assignmentsWithReminders} alumni; '
            '${reminders.completedAfterReminder} completed after reminder.',
    ];
    final recommendations = <String>[];
    if (participation.completionRate < 50 && participation.assigned > 0) {
      recommendations.add(
        'Send reminders to pending alumni and confirm program/batch targeting.',
      );
    }
    if (participation.notStarted > participation.inProgress &&
        participation.notStarted > 5) {
      recommendations.add(
        'Many assignees have not started — push an in-app notification wave.',
      );
    }
    if (skipped.isNotEmpty) {
      insights.add(
        'Most skipped: "${skipped.first.prompt}" '
        '(${((skipped.first.skippedCount / skipped.first.totalResponses) * 100).toStringAsFixed(0)}%).',
      );
      recommendations.add(
        'Clarify or conditionally hide high-skip items before the next wave.',
      );
    }
    if (survey.openAt != null || survey.closeAt != null) {
      insights.add(
        'Schedule window: '
        '${survey.openAt != null ? DateFormat.yMMMd().add_jm().format(survey.openAt!) : "open"}'
        ' → '
        '${survey.closeAt != null ? DateFormat.yMMMd().add_jm().format(survey.closeAt!) : "no close"}.',
      );
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        'Maintain current outreach cadence and export CHED Excel for registrar filing when ready.',
      );
    }

    final responseRows = submitted.take(200).map((r) {
      SurveyParticipant? p;
      for (final x in participants) {
        if (x.assignment.userId == r.userId) {
          p = x;
          break;
        }
      }
      return SurveyPackResponseRow(
        name: p?.displayName ?? r.userId,
        program: p?.program ?? '',
        batch: p?.batchYear ?? '',
        submittedAt: r.submittedAt ?? r.updatedAt,
        answerCount: r.answers.values
            .where((v) => v != null && v.toString().trim().isNotEmpty)
            .length,
      );
    }).toList();

    return SurveyReportPack(
      title: survey.title.isEmpty ? 'Survey Report Pack' : survey.title,
      subtitle: survey.isChedGtsBuiltin
          ? 'Official CHED GTS wave report'
          : 'Survey management report',
      generatedAt: DateTime.now(),
      executiveBullets: [
        'Status: ${survey.archived ? "archived" : survey.status.name}',
        'Kind: ${survey.isChedGtsBuiltin ? "Official CHED" : (survey.isFromTemplate ? "CHED preset" : "Custom")}',
        'Assigned: ${participation.assigned}',
        'Submitted: ${participation.completed}',
        'Pending: ${participation.pending}',
        'Completion: ${participation.completionRate.toStringAsFixed(1)}%',
      ],
      surveyRows: [
        SurveyPackSurveyRow(
          title: survey.title,
          status: survey.archived ? 'archived' : survey.status.name,
          kind: survey.isChedGtsBuiltin
              ? 'Official CHED'
              : (survey.isFromTemplate ? 'CHED preset' : 'Custom'),
          assigned: participation.assigned,
          submitted: participation.completed,
          completionPct: participation.completionRate,
        ),
      ],
      participation: participation,
      participationNote: null,
      audienceBuckets: [...byProgram, ...byBatch],
      audienceNote:
          'First blocks are by course/program; later rows may be batch years '
          '(see Question section for item-level stats).',
      audienceByProgram: byProgram,
      audienceByBatch: byBatch,
      questionRows: [
        for (final a in aggregates)
          SurveyPackQuestionRow(
            surveyTitle: survey.title,
            prompt: a.prompt,
            type: a.type.name,
            answered: a.answeredCount,
            total: a.totalResponses,
            skipped: a.skippedCount,
            detail: _questionDetail(a),
          ),
      ],
      responseRows: responseRows,
      responseNote: submitted.length > 200
          ? 'Showing first 200 of ${submitted.length} submitted responses.'
          : null,
      insights: insights,
      recommendations: recommendations,
    );
  }

  static String _questionDetail(SurveyQuestionAggregate a) {
    if (a.choicePercentages.isNotEmpty) {
      final top = a.choicePercentages.entries.toList()
        ..sort((x, y) => y.value.compareTo(x.value));
      return top
          .take(3)
          .map((e) => '${e.key} ${e.value.toStringAsFixed(0)}%')
          .join('; ');
    }
    if (a.scaleAverage != null) {
      return 'avg ${a.scaleAverage!.toStringAsFixed(1)} '
          '(${a.scaleMinObserved}–${a.scaleMaxObserved})';
    }
    if (a.textAnswerCount > 0) {
      return '${a.textAnswerCount} text answers';
    }
    return '';
  }

  static String toCsv(SurveyReportPack pack) {
    final b = StringBuffer();
    b.writeln('Section,Field,Value');
    b.writeln(_csv('Executive', 'Title', pack.title));
    b.writeln(_csv('Executive', 'Subtitle', pack.subtitle));
    b.writeln(
      _csv(
        'Executive',
        'Generated',
        DateFormat.yMMMd().add_jm().format(pack.generatedAt),
      ),
    );
    for (final line in pack.executiveBullets) {
      b.writeln(_csv('Executive', 'KPI', line));
    }
    b.writeln('');
    b.writeln('Survey,Status,Kind,Assigned,Submitted,Completion_%');
    for (final r in pack.surveyRows) {
      b.writeln(
        '${_esc(r.title)},${_esc(r.status)},${_esc(r.kind)},'
        '${r.assigned},${r.submitted},${r.completionPct.toStringAsFixed(1)}',
      );
    }
    b.writeln('');
    b.writeln('Participation,Assigned,NotStarted,InProgress,Completed,Rate_%');
    final p = pack.participation;
    b.writeln(
      'Funnel,${p.assigned},${p.notStarted},${p.inProgress},'
      '${p.completed},${p.completionRate.toStringAsFixed(1)}',
    );
    b.writeln('');
    b.writeln('Audience,Label,Assigned,Completed,Rate_%');
    for (final a in pack.audienceByProgram) {
      b.writeln(
        'Program,${_esc(a.label)},${a.assigned},${a.completed},'
        '${a.completionRate.toStringAsFixed(1)}',
      );
    }
    for (final a in pack.audienceByBatch) {
      b.writeln(
        'Batch,${_esc(a.label)},${a.assigned},${a.completed},'
        '${a.completionRate.toStringAsFixed(1)}',
      );
    }
    b.writeln('');
    b.writeln('Question,Survey,Type,Answered,Total,Skipped,Detail');
    for (final q in pack.questionRows) {
      b.writeln(
        '${_esc(q.prompt)},${_esc(q.surveyTitle)},${_esc(q.type)},'
        '${q.answered},${q.total},${q.skipped},${_esc(q.detail)}',
      );
    }
    b.writeln('');
    b.writeln('Response,Name,Program,Batch,SubmittedAt,AnswerFields');
    for (final r in pack.responseRows) {
      b.writeln(
        '${_esc(r.name)},${_esc(r.program)},${_esc(r.batch)},'
        '${DateFormat.yMMMd().add_jm().format(r.submittedAt)},${r.answerCount}',
      );
    }
    b.writeln('');
    for (final i in pack.insights) {
      b.writeln(_csv('Insights', 'Item', i));
    }
    for (final r in pack.recommendations) {
      b.writeln(_csv('Recommendations', 'Item', r));
    }
    return b.toString();
  }

  static String _csv(String section, String field, String value) =>
      '${_esc(section)},${_esc(field)},${_esc(value)}';

  static String _esc(String v) {
    final s = v.replaceAll('"', '""');
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"$s"';
    }
    return s;
  }

  static Future<Uint8List> toPdf(SurveyReportPack pack) async {
    final doc = pw.Document();
    final date = DateFormat.yMMMMEEEEd().add_jm().format(pack.generatedAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              pack.title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              '${pack.subtitle} · $date',
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
          _pdfH2('1. Executive Summary'),
          ...pack.executiveBullets.map(
            (b) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Bullet(text: b, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
          pw.SizedBox(height: 12),
          _pdfH2('2. Survey Summary'),
          _pdfTable(
            headers: const [
              'Title',
              'Status',
              'Kind',
              'Assigned',
              'Submitted',
              'Rate %',
            ],
            rows: [
              for (final r in pack.surveyRows)
                [
                  r.title,
                  r.status,
                  r.kind,
                  '${r.assigned}',
                  '${r.submitted}',
                  r.completionPct.toStringAsFixed(0),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          _pdfH2('3. Participation Summary'),
          if (pack.participationNote != null)
            pw.Text(
              pack.participationNote!,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: const [
              'Assigned',
              'Not started',
              'In progress',
              'Completed',
              'Rate %',
            ],
            rows: [
              [
                '${pack.participation.assigned}',
                '${pack.participation.notStarted}',
                '${pack.participation.inProgress}',
                '${pack.participation.completed}',
                pack.participation.completionRate.toStringAsFixed(0),
              ],
            ],
          ),
          pw.SizedBox(height: 12),
          _pdfH2('4. Audience Summary'),
          if (pack.audienceByProgram.isEmpty && pack.audienceByBatch.isEmpty)
            pw.Text(
              pack.audienceNote ?? 'No audience breakdown in this pack.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else ...[
            if (pack.audienceByProgram.isNotEmpty) ...[
              pw.Text(
                'By course / program',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              _pdfTable(
                headers: const ['Program', 'Assigned', 'Completed', 'Rate %'],
                rows: [
                  for (final a in pack.audienceByProgram)
                    [
                      a.label,
                      '${a.assigned}',
                      '${a.completed}',
                      a.completionPctLabel,
                    ],
                ],
              ),
              pw.SizedBox(height: 8),
            ],
            if (pack.audienceByBatch.isNotEmpty) ...[
              pw.Text(
                'By batch year',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              _pdfTable(
                headers: const ['Batch', 'Assigned', 'Completed', 'Rate %'],
                rows: [
                  for (final a in pack.audienceByBatch)
                    [
                      a.label,
                      '${a.assigned}',
                      '${a.completed}',
                      a.completionPctLabel,
                    ],
                ],
              ),
            ],
          ],
          pw.SizedBox(height: 12),
          _pdfH2('5. Question Summary'),
          if (pack.questionRows.isEmpty)
            pw.Text(
              'No question aggregates available.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else
            _pdfTable(
              headers: const [
                'Question',
                'Type',
                'Answered',
                'Skipped',
                'Detail',
              ],
              rows: [
                for (final q in pack.questionRows.take(40))
                  [
                    q.prompt,
                    q.type,
                    '${q.answered}/${q.total}',
                    '${q.skipped}',
                    q.detail,
                  ],
              ],
            ),
          pw.SizedBox(height: 12),
          _pdfH2('6. Response Summary'),
          if (pack.responseNote != null)
            pw.Text(
              pack.responseNote!,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          if (pack.responseRows.isEmpty)
            pw.Text(
              'No per-respondent rows in this pack.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else
            _pdfTable(
              headers: const [
                'Name',
                'Program',
                'Batch',
                'Submitted',
                'Fields',
              ],
              rows: [
                for (final r in pack.responseRows.take(80))
                  [
                    r.name,
                    r.program,
                    r.batch,
                    DateFormat.yMMMd().format(r.submittedAt),
                    '${r.answerCount}',
                  ],
              ],
            ),
          pw.SizedBox(height: 12),
          _pdfH2('7. Insights'),
          ...pack.insights.map(
            (i) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Bullet(text: i, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
          pw.SizedBox(height: 12),
          _pdfH2('8. Recommendations'),
          ...pack.recommendations.map(
            (i) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Bullet(text: i, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfH2(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
      );

  static pw.Widget _pdfTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) {
      return pw.Text('—', style: const pw.TextStyle(fontSize: 10));
    }
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 8,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
    );
  }

  static Uint8List toExcel(SurveyReportPack pack) {
    final excel = Excel.createExcel();

    void sheet(String name, List<List<dynamic>> rows) {
      final s = excel[name];
      for (final row in rows) {
        s.appendRow(row);
      }
    }

    // The excel package cannot safely delete/rename its default sheet
    // (crashes on the underlying archive), so the workbook used to open on a
    // blank "Sheet1" and looked empty. Fill it with a pointer note and make
    // Executive the active tab instead.
    final def = excel.getDefaultSheet();
    if (def != null && def != 'Executive') {
      sheet(def, [
        [pack.title],
        [pack.subtitle],
        ['Generated', DateFormat.yMMMd().add_jm().format(pack.generatedAt)],
        [''],
        ['Data is on the tabs: Executive, Survey_Summary, Participation,'],
        ['Audience, Questions, Responses, Insights, Recommendations.'],
      ]);
    }

    sheet('Executive', [
      ['Title', pack.title],
      ['Subtitle', pack.subtitle],
      ['Generated', DateFormat.yMMMd().add_jm().format(pack.generatedAt)],
      ['KPI'],
      ...pack.executiveBullets.map((b) => [b]),
    ]);

    sheet('Survey_Summary', [
      ['Title', 'Status', 'Kind', 'Assigned', 'Submitted', 'Completion_%'],
      for (final r in pack.surveyRows)
        [
          r.title,
          r.status,
          r.kind,
          r.assigned,
          r.submitted,
          r.completionPct.toStringAsFixed(1),
        ],
    ]);

    final p = pack.participation;
    sheet('Participation', [
      ['Assigned', 'NotStarted', 'InProgress', 'Completed', 'Rate_%'],
      [
        p.assigned,
        p.notStarted,
        p.inProgress,
        p.completed,
        p.completionRate.toStringAsFixed(1),
      ],
      if (pack.participationNote != null) ['Note', pack.participationNote],
    ]);

    sheet('Audience', [
      ['Dimension', 'Label', 'Assigned', 'Completed', 'Rate_%'],
      for (final a in pack.audienceByProgram)
        [
          'Program',
          a.label,
          a.assigned,
          a.completed,
          a.completionRate.toStringAsFixed(1),
        ],
      for (final a in pack.audienceByBatch)
        [
          'Batch',
          a.label,
          a.assigned,
          a.completed,
          a.completionRate.toStringAsFixed(1),
        ],
    ]);

    sheet('Questions', [
      ['Survey', 'Prompt', 'Type', 'Answered', 'Total', 'Skipped', 'Detail'],
      for (final q in pack.questionRows)
        [
          q.surveyTitle,
          q.prompt,
          q.type,
          q.answered,
          q.total,
          q.skipped,
          q.detail,
        ],
    ]);

    sheet('Responses', [
      ['Name', 'Program', 'Batch', 'SubmittedAt', 'AnswerFields'],
      for (final r in pack.responseRows)
        [
          r.name,
          r.program,
          r.batch,
          DateFormat.yMMMd().add_jm().format(r.submittedAt),
          r.answerCount,
        ],
    ]);

    sheet('Insights', [
      ['Insight'],
      ...pack.insights.map((i) => [i]),
    ]);

    sheet('Recommendations', [
      ['Recommendation'],
      ...pack.recommendations.map((r) => [r]),
    ]);

    excel.setDefaultSheet('Executive');

    final bytes = excel.save();
    if (bytes == null) {
      return Uint8List.fromList(utf8.encode(''));
    }
    return Uint8List.fromList(bytes);
  }
}

class SurveyReportPack {
  SurveyReportPack({
    required this.title,
    required this.subtitle,
    required this.generatedAt,
    required this.executiveBullets,
    required this.surveyRows,
    required this.participation,
    required this.questionRows,
    required this.responseRows,
    required this.insights,
    required this.recommendations,
    this.participationNote,
    this.audienceBuckets = const [],
    this.audienceNote,
    this.audienceByProgram = const [],
    this.audienceByBatch = const [],
    this.responseNote,
  });

  final String title;
  final String subtitle;
  final DateTime generatedAt;
  final List<String> executiveBullets;
  final List<SurveyPackSurveyRow> surveyRows;
  final SurveyParticipationSnapshot participation;
  final String? participationNote;
  final List<SurveyAudienceBucket> audienceBuckets;
  final String? audienceNote;
  final List<SurveyAudienceBucket> audienceByProgram;
  final List<SurveyAudienceBucket> audienceByBatch;
  final List<SurveyPackQuestionRow> questionRows;
  final List<SurveyPackResponseRow> responseRows;
  final String? responseNote;
  final List<String> insights;
  final List<String> recommendations;
}

class SurveyPackSurveyRow {
  const SurveyPackSurveyRow({
    required this.title,
    required this.status,
    required this.kind,
    required this.assigned,
    required this.submitted,
    required this.completionPct,
  });

  final String title;
  final String status;
  final String kind;
  final int assigned;
  final int submitted;
  final double completionPct;
}

class SurveyPackQuestionRow {
  const SurveyPackQuestionRow({
    required this.surveyTitle,
    required this.prompt,
    required this.type,
    required this.answered,
    required this.total,
    required this.skipped,
    required this.detail,
  });

  final String surveyTitle;
  final String prompt;
  final String type;
  final int answered;
  final int total;
  final int skipped;
  final String detail;
}

class SurveyPackResponseRow {
  const SurveyPackResponseRow({
    required this.name,
    required this.program,
    required this.batch,
    required this.submittedAt,
    required this.answerCount,
  });

  final String name;
  final String program;
  final String batch;
  final DateTime submittedAt;
  final int answerCount;
}

extension on SurveyAudienceBucket {
  String get completionPctLabel => completionRate.toStringAsFixed(0);
}
