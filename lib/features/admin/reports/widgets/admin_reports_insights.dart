import 'package:flutter/material.dart';
import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

enum ReportsInsightKind {
  executiveSummary,
  keyFindings,
  recommendations,
  participation,
  employment,
  ched,
}

/// Navigation targets for insight card action buttons.
enum ReportsInsightAction {
  openAlumniTracer,
  openSurveys,
  openParticipation,
  openExportEmployment,
  openExportHub,
  openRosterModule,
  openSurveysModule,
}

class ReportsInsightCardData {
  const ReportsInsightCardData({
    required this.kind,
    required this.title,
    required this.body,
    required this.icon,
    this.isPlaceholder = false,
    this.isLoading = false,
    this.isError = false,
    this.actionLabel,
    this.action,
  });

  final ReportsInsightKind kind;
  final String title;
  final String body;
  final IconData icon;
  final bool isPlaceholder;
  final bool isLoading;
  final bool isError;
  final String? actionLabel;
  final ReportsInsightAction? action;

  ReportsInsightCardData copyWith({
    String? title,
    String? body,
    bool? isPlaceholder,
    bool? isLoading,
    bool? isError,
    String? actionLabel,
    ReportsInsightAction? action,
    bool clearAction = false,
  }) {
    return ReportsInsightCardData(
      kind: kind,
      title: title ?? this.title,
      body: body ?? this.body,
      icon: icon,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
      actionLabel: clearAction ? null : (actionLabel ?? this.actionLabel),
      action: clearAction ? null : (action ?? this.action),
    );
  }
}

/// Default deep-link actions attached by insight kind.
(String label, ReportsInsightAction action)? insightActionForKind(
  ReportsInsightKind kind,
) => switch (kind) {
  ReportsInsightKind.executiveSummary => (
    'Open report center',
    ReportsInsightAction.openExportHub,
  ),
  ReportsInsightKind.keyFindings => (
    'View tracer intelligence',
    ReportsInsightAction.openAlumniTracer,
  ),
  ReportsInsightKind.recommendations => (
    'Open roster',
    ReportsInsightAction.openRosterModule,
  ),
  ReportsInsightKind.participation => (
    'View surveys',
    ReportsInsightAction.openSurveys,
  ),
  ReportsInsightKind.employment => (
    'Export employment',
    ReportsInsightAction.openExportEmployment,
  ),
  ReportsInsightKind.ched => (
    'Open surveys',
    ReportsInsightAction.openSurveysModule,
  ),
};

/// Builds metric-based placeholder insights (no Gemini call).
List<ReportsInsightCardData> buildHeuristicReportInsights(
  AdminReportsAnalytics a, {
  int chedPublished = 0,
  int chedResponses = 0,
}) {
  final regPct = (a.registrationRate * 100).toStringAsFixed(0);
  final tracerPct = (a.tracerCompletionRate * 100).toStringAsFixed(0);
  final surveyPct = (a.surveyResponseRate * 100).toStringAsFixed(0);
  final empPct = a.reportEmploymentCount == 0
      ? '0'
      : (a.employmentRateAmongSubmissions * 100).toStringAsFixed(0);

  return [
    ReportsInsightCardData(
      kind: ReportsInsightKind.executiveSummary,
      title: 'Executive summary',
      icon: Icons.auto_awesome_outlined,
      isPlaceholder: true,
      body:
          'Portfolio snapshot: $regPct% of roster registered, $tracerPct% tracer-complete '
          'among registered alumni, $surveyPct% survey completion, and $empPct% employed '
          'among employment submissions. Tap Generate AI insights for a narrative brief.',
    ),
    ReportsInsightCardData(
      kind: ReportsInsightKind.keyFindings,
      title: 'Key findings',
      icon: Icons.flag_outlined,
      isPlaceholder: true,
      body: [
        if (a.registeredWithoutTracerComplete > 0)
          '${a.registeredWithoutTracerComplete} registered alumni still need a complete tracer profile.',
        if (a.pendingSurveyAssignments > 0)
          '${a.pendingSurveyAssignments} survey assignments are still pending.',
        if (a.publishedSurveys == 0) 'No published surveys are currently live.',
        if (a.registeredWithoutTracerComplete == 0 &&
            a.pendingSurveyAssignments == 0)
          'No major gaps flagged from current KPIs — keep monitoring waves as they publish.',
      ].join(' '),
    ),
    ReportsInsightCardData(
      kind: ReportsInsightKind.recommendations,
      title: 'Recommendations',
      icon: Icons.lightbulb_outline,
      isPlaceholder: true,
      body: [
        if (a.registeredWithoutTracerComplete > 0)
          'Send a tracer reminder to registered alumni with incomplete profiles.',
        if (a.pendingSurveyAssignments > 0)
          'Follow up on pending survey assignees before closing the current wave.',
        if (a.surveyResponseRate < 0.5 && a.totalSurveyAssignments > 0)
          'Review survey audience targeting and reminder cadence to lift completion.',
        if (a.registeredWithoutTracerComplete == 0 &&
            a.pendingSurveyAssignments == 0)
          'Export a Tracer & Survey KPIs pack for registrar / CHED reporting.',
      ].join(' '),
    ),
    ReportsInsightCardData(
      kind: ReportsInsightKind.participation,
      title: 'Participation insights',
      icon: Icons.poll_outlined,
      isPlaceholder: true,
      body:
          '${a.totalSurveyResponses} submitted responses across ${a.totalSurveyAssignments} '
          'assignments ($surveyPct% rate). ${a.publishedSurveys} published and '
          '${a.draftSurveys} draft surveys in the portfolio.',
    ),
    ReportsInsightCardData(
      kind: ReportsInsightKind.employment,
      title: 'Employment highlights',
      icon: Icons.work_outline,
      isPlaceholder: true,
      body:
          '${a.reportEmploymentCount} employment submissions on file; '
          '${a.employedCount} employed ($empPct% of submissions). '
          'Use Employment analytics for industry mix.',
    ),
    ReportsInsightCardData(
      kind: ReportsInsightKind.ched,
      title: 'CHED highlights',
      icon: Icons.verified_outlined,
      isPlaceholder: true,
      body: chedPublished == 0
          ? 'No Official CHED GTS waves are published yet. Create one from Surveys when ready.'
          : '$chedPublished Official CHED GTS wave(s) with $chedResponses submitted response(s) in scope.',
    ),
  ];
}

String buildReportsInsightsPrompt(
  AdminReportsAnalytics a, {
  required int chedPublished,
  required int chedResponses,
}) {
  return '''
You are assisting a university alumni office with an executive analytics brief.
Using ONLY the metrics below, write a concise dashboard insight pack.

Return exactly 6 short sections with these headings (plain text, no markdown fences):
1) Executive summary
2) Key findings
3) Recommendations
4) Participation insights
5) Employment highlights
6) CHED highlights

Keep each section to 2–4 sentences. Be practical. Do not invent numbers.

METRICS:
- Roster total: ${a.rosterTotal}
- Registered on roster: ${a.registeredOnRoster}
- Registration rate: ${(a.registrationRate * 100).toStringAsFixed(1)}%
- Tracer complete: ${a.tracerCompleteCount}
- Tracer completion rate (of registered): ${(a.tracerCompletionRate * 100).toStringAsFixed(1)}%
- Registered without complete tracer: ${a.registeredWithoutTracerComplete}
- Employment submissions: ${a.reportEmploymentCount}
- Employed among submissions: ${a.employedCount} (${(a.employmentRateAmongSubmissions * 100).toStringAsFixed(1)}%)
- Published surveys: ${a.publishedSurveys}
- Draft surveys: ${a.draftSurveys}
- Survey assignments: ${a.totalSurveyAssignments}
- Survey responses: ${a.totalSurveyResponses}
- Survey response rate: ${(a.surveyResponseRate * 100).toStringAsFixed(1)}%
- Pending survey assignments: ${a.pendingSurveyAssignments}
- Official CHED published waves: $chedPublished
- Official CHED submitted responses (rollup scope): $chedResponses
''';
}

/// Section heading synonyms, ordered longest-first so specific phrases win.
const _insightHeadings = <(ReportsInsightKind, String)>[
  (ReportsInsightKind.executiveSummary, 'executive summary'),
  (ReportsInsightKind.keyFindings, 'key findings'),
  (ReportsInsightKind.keyFindings, 'key finding'),
  (ReportsInsightKind.recommendations, 'recommendations'),
  (ReportsInsightKind.recommendations, 'recommendation'),
  (ReportsInsightKind.participation, 'participation insights'),
  (ReportsInsightKind.participation, 'participation'),
  (ReportsInsightKind.employment, 'employment highlights'),
  (ReportsInsightKind.employment, 'employment'),
  (ReportsInsightKind.ched, 'ched highlights'),
  (ReportsInsightKind.ched, 'ched'),
];

/// Detects a section heading at the START of a line (after markdown/numbering)
/// and returns any same-line content after the heading.
(ReportsInsightKind, String)? _matchInsightHeading(String line) {
  final hadMarkdown = RegExp(r'^\s*(#{1,6}\s|\*\*|__)').hasMatch(line);
  var s = line.replaceAll(RegExp(r'[*_#`]'), '').trim();
  final numbering = RegExp(
    r'^(section\s+)?\d{1,2}\s*[).:\-–—]?\s*',
    caseSensitive: false,
  );
  final hadNumbering = s.startsWith(numbering);
  s = s.replaceFirst(numbering, '');
  final lower = s.toLowerCase();
  for (final (kind, keyword) in _insightHeadings) {
    if (!lower.startsWith(keyword)) continue;
    var rest = s.substring(keyword.length).trim();
    final hadDelimiter = RegExp(r'^[:\-–—]').hasMatch(rest);
    rest = rest.replaceFirst(RegExp(r'^[:\-–—.]+\s*'), '');
    // Only treat as a heading when the line looks like one — bare title,
    // markdown/numbered heading, or "Heading: content". Plain sentences that
    // happen to start with a keyword stay in the current section body.
    if (rest.isEmpty || hadMarkdown || hadNumbering || hadDelimiter) {
      return (kind, rest);
    }
    return null;
  }
  return null;
}

List<ReportsInsightCardData> parseAiInsightResponse(
  String raw, {
  List<ReportsInsightCardData>? fallback,
}) {
  final placeholders = <ReportsInsightKind, (String, IconData)>{
    ReportsInsightKind.executiveSummary: (
      'Executive summary',
      Icons.auto_awesome_outlined,
    ),
    ReportsInsightKind.keyFindings: ('Key findings', Icons.flag_outlined),
    ReportsInsightKind.recommendations: (
      'Recommendations',
      Icons.lightbulb_outline,
    ),
    ReportsInsightKind.participation: (
      'Participation insights',
      Icons.poll_outlined,
    ),
    ReportsInsightKind.employment: (
      'Employment highlights',
      Icons.work_outline,
    ),
    ReportsInsightKind.ched: ('CHED highlights', Icons.verified_outlined),
  };

  final bodies = <ReportsInsightKind, StringBuffer>{
    for (final k in ReportsInsightKind.values) k: StringBuffer(),
  };

  ReportsInsightKind? current;
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final heading = _matchInsightHeading(trimmed);
    if (heading != null) {
      current = heading.$1;
      if (heading.$2.isNotEmpty) {
        final buf = bodies[current]!;
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(heading.$2);
      }
      continue;
    }
    if (current != null) {
      final buf = bodies[current]!;
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(
        trimmed
            .replaceFirst(RegExp(r'^[-•\d.)\s]+'), '')
            .replaceAll(RegExp(r'[*_#`]'), ''),
      );
    }
  }

  // Nothing matched at all — surface the raw narrative rather than losing it.
  final nothingParsed = bodies.values.every((b) => b.isEmpty);
  if (nothingParsed && raw.trim().isNotEmpty) {
    bodies[ReportsInsightKind.executiveSummary]!.write(
      raw.trim().replaceAll(RegExp(r'[*_#`]'), ''),
    );
  }

  final fallbackByKind = <ReportsInsightKind, ReportsInsightCardData>{
    if (fallback != null)
      for (final c in fallback) c.kind: c,
  };

  return [
    for (final kind in ReportsInsightKind.values)
      if (bodies[kind]!.isNotEmpty)
        ReportsInsightCardData(
          kind: kind,
          title: placeholders[kind]!.$1,
          icon: placeholders[kind]!.$2,
          body: bodies[kind]!.toString(),
          isPlaceholder: false,
          actionLabel:
              fallbackByKind[kind]?.actionLabel ??
              insightActionForKind(kind)?.$1,
          action:
              fallbackByKind[kind]?.action ?? insightActionForKind(kind)?.$2,
        )
      else
        ReportsInsightCardData(
          kind: kind,
          title: placeholders[kind]!.$1,
          icon: placeholders[kind]!.$2,
          body:
              fallbackByKind[kind]?.body ??
              'No content returned for this section.',
          isPlaceholder: true,
          actionLabel:
              fallbackByKind[kind]?.actionLabel ??
              insightActionForKind(kind)?.$1,
          action:
              fallbackByKind[kind]?.action ?? insightActionForKind(kind)?.$2,
        ),
  ];
}

/// Loads Gemini narrative insights via [AiAssistantService], with heuristics fallback.
Future<List<ReportsInsightCardData>> generateReportInsights({
  required AdminReportsAnalytics analytics,
  required List<Survey> surveys,
  AiAssistantService? service,
}) async {
  final ched = surveys.where((s) => !s.archived && s.isChedGtsBuiltin).toList();
  final chedPublished = ched
      .where((s) => s.status == SurveyStatus.published)
      .length;
  final chedResponses = ched.fold<int>(
    0,
    (sum, s) => sum + analytics.submittedResponseCount(s),
  );

  final heuristics = buildHeuristicReportInsights(
    analytics,
    chedPublished: chedPublished,
    chedResponses: chedResponses,
  );

  if (!AiConfig.isEnabled) {
    return heuristics
        .map(
          (c) => c.copyWith(
            body:
                '${c.body}\n\n(AI turned off — showing metric-based placeholders.)',
          ),
        )
        .toList();
  }

  try {
    final ai = service ?? AiAssistantService();
    final text = await ai.sendMessage(
      task: AiTask.reportsInsights,
      userMessage: buildReportsInsightsPrompt(
        analytics,
        chedPublished: chedPublished,
        chedResponses: chedResponses,
      ),
    );
    return parseAiInsightResponse(text, fallback: heuristics);
  } catch (e) {
    return heuristics
        .map(
          (c) => c.copyWith(
            isError: true,
            body: '${c.body}\n\n(AI unavailable: $e — showing placeholders.)',
          ),
        )
        .toList();
  }
}

/// Executive Insights panel for Reports & Analytics.
class ReportsInsightsPanel extends StatelessWidget {
  const ReportsInsightsPanel({
    super.key,
    required this.cards,
    required this.isGenerating,
    required this.onGenerate,
    this.onInsightAction,
    this.isAiGenerated = false,
  });

  final List<ReportsInsightCardData> cards;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final ValueChanged<ReportsInsightAction>? onInsightAction;

  /// True when the latest cards came from a Gemini narrative (not KPI preview).
  final bool isAiGenerated;

  @override
  Widget build(BuildContext context) {
    ReportsInsightCardData? summaryCard;
    final supporting = <ReportsInsightCardData>[];
    for (final c in cards) {
      if (c.kind == ReportsInsightKind.executiveSummary &&
          summaryCard == null) {
        summaryCard = c;
      } else if (c.kind != ReportsInsightKind.executiveSummary) {
        supporting.add(c);
      }
    }

    Widget? featuredCard;
    if (summaryCard != null) {
      final featured = summaryCard;
      final action = featured.action;
      featuredCard = _InsightCard(
        data: featured,
        loading: isGenerating,
        featured: true,
        onAction: action == null || onInsightAction == null
            ? null
            : () => onInsightAction!(action),
      );
    }

    return ReportsSectionShell(
      icon: Icons.auto_awesome_outlined,
      title: 'AI insights',
      subtitle: 'Optional brief — expand for takeaways.',
      initiallyExpanded: false,
      actions: [
        ReportsSectionAction(
          label: isGenerating ? 'Generating…' : 'Generate AI insights',
          icon: isGenerating ? Icons.hourglass_top : Icons.auto_awesome,
          onPressed: isGenerating ? null : onGenerate,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightsStatusStrip(
            isAiGenerated: isAiGenerated,
            isGenerating: isGenerating,
            apiConfigured: AiConfig.isEnabled,
          ),
          if (!AiConfig.isEnabled)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Text(
                'AI is turned off in this build. Placeholders use live KPIs.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AdminReportsTheme.warning,
                ),
              ),
            ),
          if (featuredCard != null) ...[
            featuredCard,
            const SizedBox(height: AdminReportsTheme.gutter),
          ],
          if (supporting.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final cols =
                    constraints.maxWidth >= AdminDensity.statsFourColMin
                    ? 3
                    : constraints.maxWidth >= AdminDensity.statsTwoColMin
                    ? 2
                    : 1;
                final gutter = AdminReportsTheme.gutter;

                Widget cardFor(ReportsInsightCardData card) => _InsightCard(
                  data: card,
                  loading: isGenerating,
                  onAction: card.action == null || onInsightAction == null
                      ? null
                      : () => onInsightAction!(card.action!),
                );

                final rows = <Widget>[];
                for (var i = 0; i < supporting.length; i += cols) {
                  final rowCards = supporting.skip(i).take(cols).toList();
                  if (rows.isNotEmpty) rows.add(SizedBox(height: gutter));
                  rows.add(
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var j = 0; j < cols; j++) ...[
                            if (j > 0) SizedBox(width: gutter),
                            Expanded(
                              child: j < rowCards.length
                                  ? cardFor(rowCards[j])
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InsightsStatusStrip extends StatelessWidget {
  const _InsightsStatusStrip({
    required this.isAiGenerated,
    required this.isGenerating,
    required this.apiConfigured,
  });

  final bool isAiGenerated;
  final bool isGenerating;
  final bool apiConfigured;

  @override
  Widget build(BuildContext context) {
    final label = isGenerating
        ? 'Generating narrative…'
        : isAiGenerated
        ? 'AI-generated brief'
        : 'KPI preview · generate for a full narrative';
    final color = isGenerating
        ? AdminReportsTheme.primary
        : isAiGenerated
        ? AdminReportsTheme.success
        : AdminReportsTheme.textSecondary;
    final icon = isGenerating
        ? Icons.hourglass_top
        : isAiGenerated
        ? Icons.auto_awesome
        : Icons.insights_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (apiConfigured && !isGenerating)
            Text(
              isAiGenerated ? 'Ready to regenerate' : 'Ready to generate',
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminReportsTheme.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.data,
    required this.loading,
    this.onAction,
    this.featured = false,
  });

  final ReportsInsightCardData data;
  final bool loading;
  final VoidCallback? onAction;
  final bool featured;

  Color get _accent => switch (data.kind) {
    ReportsInsightKind.executiveSummary => AdminReportsTheme.primary,
    ReportsInsightKind.keyFindings => const Color(0xFFB45309),
    ReportsInsightKind.recommendations => const Color(0xFF0F766E),
    ReportsInsightKind.participation => const Color(0xFF4338CA),
    ReportsInsightKind.employment => const Color(0xFF15803D),
    ReportsInsightKind.ched => const Color(0xFF1D4ED8),
  };

  @override
  Widget build(BuildContext context) {
    final showLoading = loading || data.isLoading;
    final minH = featured ? 168.0 : 148.0;

    return Container(
      constraints: BoxConstraints(minHeight: minH),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(
          color: data.isError
              ? AdminReportsTheme.danger.withValues(alpha: 0.35)
              : featured
              ? _accent.withValues(alpha: 0.28)
              : AdminReportsTheme.border,
        ),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: featured ? 5 : 3, color: _accent),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(featured ? 18 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: featured ? 36 : 32,
                            height: featured ? 36 : 32,
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              data.icon,
                              size: featured ? 18 : 16,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              data.title,
                              style: TextStyle(
                                fontSize: featured ? 15.5 : 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: featured ? -0.2 : 0,
                                color: AdminReportsTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (data.isPlaceholder)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AdminReportsTheme.surface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Preview',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AdminReportsTheme.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: featured ? 14 : 10),
                      if (showLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: LinearProgressIndicator(minHeight: 3),
                        )
                      else
                        Text(
                          data.body,
                          style: TextStyle(
                            fontSize: featured ? 14 : 12.5,
                            height: featured ? 1.55 : 1.45,
                            fontWeight: featured
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: featured
                                ? AdminReportsTheme.textPrimary
                                : AdminReportsTheme.textSecondary,
                          ),
                        ),
                      if (!showLoading &&
                          onAction != null &&
                          (data.actionLabel?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onAction,
                            icon: const Icon(Icons.arrow_forward, size: 14),
                            label: Text(data.actionLabel!),
                            style: TextButton.styleFrom(
                              foregroundColor: _accent,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
