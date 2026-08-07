import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';
import 'package:alumni_system/features/surveys/data/survey_report_analytics.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Result of a formal survey narrative report generation.
class SurveyFormalReportResult {
  const SurveyFormalReportResult({
    required this.body,
    required this.usedAi,
    required this.generatedAt,
    this.disclaimer =
        'AI draft based on system survey data — review before official use.',
  });

  final String body;
  final bool usedAi;
  final DateTime generatedAt;
  final String disclaimer;
}

/// Builds grounded facts and a formal institutional paragraph report for one survey.
class SurveyFormalReportService {
  SurveyFormalReportService({AiAssistantService? ai})
      : _ai = ai ?? AiAssistantService();

  final AiAssistantService _ai;

  static const _systemInstruction = '''
You are an institutional research writer for a university alumni office.
Write formal, clear English suitable for a memo to administrators or CHED-related
briefing. Use ONLY the factual numbers and findings provided. Do not invent
percentages, counts, or conclusions not supported by the data. If the sample
is small or incomplete, say so. Do not use markdown headings with #; use plain
paragraphs with clear section titles on their own lines in Title Case.
''';

  Future<SurveyFormalReportResult> generate({
    required Survey survey,
    required List<SurveyQuestion> questions,
    required List<SurveyParticipant> participants,
    required List<SurveyResponse> responses,
  }) async {
    final facts = buildFactsBundle(
      survey: survey,
      questions: questions,
      participants: participants,
      responses: responses,
    );
    final fallback = buildHeuristicReport(facts);
    final generatedAt = DateTime.now();

    if (!AiConfig.isConfigured) {
      return SurveyFormalReportResult(
        body: fallback,
        usedAi: false,
        generatedAt: generatedAt,
        disclaimer:
            'Metric-based draft (AI key not configured) — review before official use.',
      );
    }

    try {
      final text = await _ai.sendMessage(
        isAdmin: true,
        history: const [],
        maxOutputTokens: 4096,
        temperature: 0.35,
        systemInstructionOverride: _systemInstruction,
        userMessage: buildUserPrompt(facts),
      );
      final cleaned = text.trim();
      if (cleaned.isEmpty) {
        return SurveyFormalReportResult(
          body: fallback,
          usedAi: false,
          generatedAt: generatedAt,
          disclaimer:
              'AI returned empty text — showing metric-based draft. Review before official use.',
        );
      }
      return SurveyFormalReportResult(
        body: cleaned,
        usedAi: true,
        generatedAt: generatedAt,
      );
    } catch (e) {
      return SurveyFormalReportResult(
        body: '$fallback\n\n(Note: AI unavailable — $e)',
        usedAi: false,
        generatedAt: generatedAt,
        disclaimer:
            'Metric-based draft (AI unavailable) — review before official use.',
      );
    }
  }

  /// Structured facts used for prompting and heuristic fallback.
  static Map<String, dynamic> buildFactsBundle({
    required Survey survey,
    required List<SurveyQuestion> questions,
    required List<SurveyParticipant> participants,
    required List<SurveyResponse> responses,
  }) {
    final participation =
        SurveyReportAnalytics.participationFromParticipants(participants);
    final submitted = responses
        .where((r) => r.status == SurveyResponseStatus.submitted)
        .toList();
    final aggregates = survey.isChedGtsBuiltin
        ? SurveyReportAnalytics.aggregateChedResponses(responses: submitted)
        : SurveyReportAnalytics.aggregateResponses(
            questions: questions,
            responses: submitted,
          );

    final findings = <String>[];
    final scored = <({int answered, String line})>[];
    for (final agg in aggregates) {
      if (agg.answeredCount <= 0) continue;
      if (agg.choicePercentages.isNotEmpty) {
        final top = agg.choicePercentages.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final best = top.first;
        scored.add((
          answered: agg.answeredCount,
          line:
              '${agg.prompt}: most common answer “${best.key}” '
              '(${best.value.toStringAsFixed(0)}% of ${agg.answeredCount} answers).',
        ));
      } else if (agg.scaleAverage != null) {
        scored.add((
          answered: agg.answeredCount,
          line:
              '${agg.prompt}: average ${agg.scaleAverage!.toStringAsFixed(1)} '
              '(${agg.answeredCount} answers).',
        ));
      }
    }
    scored.sort((a, b) => b.answered.compareTo(a.answered));
    for (final s in scored.take(8)) {
      findings.add(s.line);
    }

    final rate = participation.assigned == 0
        ? 0.0
        : participation.completed / participation.assigned;

    return {
      'title': survey.title.trim().isEmpty ? 'Untitled survey' : survey.title,
      'description': survey.description.trim(),
      'kind': survey.isChedGtsBuiltin
          ? 'Official CHED Graduate Tracer Study (GTS)'
          : (survey.isFromTemplate ? 'CHED template-based survey' : 'Custom survey'),
      'status': survey.archived ? 'archived' : survey.status.name,
      'createdAt': DateFormat.yMMMd().format(survey.createdAt),
      'assigned': participation.assigned,
      'completed': participation.completed,
      'pending': participation.pending,
      'responseRatePct': (rate * 100).toStringAsFixed(1),
      'submittedResponses': submitted.length,
      'findings': findings,
      'isChed': survey.isChedGtsBuiltin,
    };
  }

  static String buildUserPrompt(Map<String, dynamic> facts) {
    final findings = (facts['findings'] as List).cast<String>();
    final buf = StringBuffer()
      ..writeln('Write a formal survey report using ONLY these facts.')
      ..writeln()
      ..writeln('Required sections (plain text titles, then paragraphs):')
      ..writeln('1. Purpose and Scope')
      ..writeln('2. Participation')
      ..writeln('3. Key Findings')
      ..writeln('4. Implications')
      ..writeln('5. Limitations')
      ..writeln('6. Recommended Next Steps')
      ..writeln()
      ..writeln('Facts:')
      ..writeln('- Survey title: ${facts['title']}')
      ..writeln('- Survey kind: ${facts['kind']}')
      ..writeln('- Status: ${facts['status']}')
      ..writeln('- Created: ${facts['createdAt']}')
      ..writeln('- Description: ${facts['description']}')
      ..writeln('- Assigned alumni: ${facts['assigned']}')
      ..writeln('- Submitted / completed: ${facts['completed']}')
      ..writeln('- Pending: ${facts['pending']}')
      ..writeln('- Response rate: ${facts['responseRatePct']}%')
      ..writeln('- Submitted response records: ${facts['submittedResponses']}')
      ..writeln('- Key findings from answers:');
    if (findings.isEmpty) {
      buf.writeln('  (No question-level aggregates available yet.)');
    } else {
      for (final f in findings) {
        buf.writeln('  • $f');
      }
    }
    buf
      ..writeln()
      ..writeln(
        'Tone: formal institutional English. Keep roughly 450–800 words. '
        'Do not invent statistics beyond the facts above.',
      );
    return buf.toString();
  }

  static String buildHeuristicReport(Map<String, dynamic> facts) {
    final findings = (facts['findings'] as List).cast<String>();
    final title = facts['title'] as String;
    final kind = facts['kind'] as String;
    final assigned = facts['assigned'];
    final completed = facts['completed'];
    final pending = facts['pending'];
    final rate = facts['responseRatePct'];
    final created = facts['createdAt'];
    final isChed = facts['isChed'] as bool;

    final buf = StringBuffer()
      ..writeln('Purpose and Scope')
      ..writeln()
      ..writeln(
        'This report summarizes results for “$title” ($kind), created on $created. '
        'It is intended for alumni office briefing and internal coordination'
        '${isChed ? ' in support of graduate tracer monitoring' : ''}.',
      )
      ..writeln()
      ..writeln('Participation')
      ..writeln()
      ..writeln(
        'A total of $assigned alumni were assigned to this survey. '
        'Of these, $completed have submitted responses '
        '(response rate $rate%), while $pending assignments remain pending.',
      )
      ..writeln()
      ..writeln('Key Findings')
      ..writeln();
    if (findings.isEmpty) {
      buf.writeln(
        'Question-level distributions are not yet available because there are '
        'insufficient submitted responses to summarize.',
      );
    } else {
      for (final f in findings.take(6)) {
        buf.writeln('• $f');
      }
    }
    buf
      ..writeln()
      ..writeln('Implications')
      ..writeln()
      ..writeln(
        completed == 0
            ? 'Without submitted responses, outcome interpretation should wait '
                'until participation improves.'
            : 'The participation and answer patterns above provide an initial '
                'basis for office discussion. Findings should be read together '
                'with pending follow-up and any related tracer profile gaps.',
      )
      ..writeln()
      ..writeln('Limitations')
      ..writeln()
      ..writeln(
        'This draft is generated from system aggregates only. It does not '
        'replace full response exports or official CHED templates. '
        'Small response counts or high pending rates limit generalizability.',
      )
      ..writeln()
      ..writeln('Recommended Next Steps')
      ..writeln()
      ..writeln(
        pending != 0
            ? '1. Send reminders to pending assignees.\n'
                '2. Review question summaries after additional responses arrive.\n'
                '3. Export the formal report or management pack for filing after review.'
            : '1. Review question summaries and employment-related items where applicable.\n'
                '2. Share this draft with office leadership after editorial review.\n'
                '3. Archive or close the wave when reporting requirements are complete.',
      );
    return buf.toString().trim();
  }

  static Future<Uint8List> toPdf({
    required String surveyTitle,
    required String body,
    required String disclaimer,
    required DateTime generatedAt,
    required bool usedAi,
  }) async {
    final doc = pw.Document();
    final stamp = DateFormat.yMMMd().add_jm().format(generatedAt);
    final paragraphs = body
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Formal Survey Report',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              surveyTitle,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.blueGrey700,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Generated $stamp · ${usedAi ? 'AI-assisted draft' : 'Metric-based draft'}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.blueGrey300),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    disclaimer,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          for (final block in paragraphs) {
            final lines = block.split('\n');
            final maybeTitle = lines.first.trim();
            final isTitle = lines.length == 1 &&
                maybeTitle.length < 60 &&
                !maybeTitle.endsWith('.') &&
                RegExp(r'^[A-Za-z].*').hasMatch(maybeTitle);

            if (isTitle) {
              widgets.add(pw.SizedBox(height: 10));
              widgets.add(
                pw.Text(
                  maybeTitle,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 4));
            } else {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    block,
                    style: const pw.TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      color: PdfColors.grey800,
                    ),
                    textAlign: pw.TextAlign.justify,
                  ),
                ),
              );
            }
          }
          return widgets;
        },
      ),
    );
    return doc.save();
  }
}
