import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';

/// An explanation of one flag. [byAi] is false when the rule-based text is
/// shown instead (AI not configured, unavailable, or its reply rejected).
class DssAiExplanation {
  const DssAiExplanation({
    required this.text,
    required this.byAi,
    this.rejectedReason,
    this.unavailable = false,
  });

  final String text;
  final bool byAi;

  /// Why the AI reply was not used, when it failed the checks.
  final String? rejectedReason;

  /// The AI call failed (network, quota, empty reply).
  final bool unavailable;
}

/// AI explanation of a finding the rules already produced. AI only explains:
/// it never creates, detects, closes, resolves, ranks or prioritizes
/// findings, sets severity, or judges whether an intervention succeeded.
/// It receives computed facts only, and a reply that does not restate the
/// value and the number of answers, or that goes beyond explaining, is
/// discarded.
class DssAiService {
  DssAiService({AiAssistantService? ai, bool? available})
    : _ai = ai ?? AiAssistantService(),
      _available = available;

  final AiAssistantService _ai;
  final bool? _available;

  static bool get isAvailable => AiConfig.isEnabled;

  /// The rule-based explanation shown when AI is not used.
  static String fallbackText(DssFlag flag) =>
      '${DssCopy.whyFlagged(flag)} ${DssCopy.displayRecommendedAction(flag)}';

  Future<DssAiExplanation> explainFlag(DssFlag flag) async {
    final fallback = fallbackText(flag);
    if (!(_available ?? isAvailable)) {
      return DssAiExplanation(text: fallback, byAi: false);
    }
    String raw;
    try {
      raw = await _ai.sendMessage(
        task: AiTask.dssExplain,
        userMessage: factsPrompt(flag),
      );
    } catch (_) {
      return DssAiExplanation(text: fallback, byAi: false, unavailable: true);
    }
    final text = stripMarkdown(raw);
    if (!_looksComplete(text)) {
      return DssAiExplanation(text: fallback, byAi: false, unavailable: true);
    }
    final problem = checkReply(text, flag);
    if (problem != null) {
      return DssAiExplanation(
        text: fallback,
        byAi: false,
        rejectedReason: problem,
      );
    }
    return DssAiExplanation(text: text, byAi: true);
  }

  /// The facts sent to the AI (instructions are in the `dss_explain` task of
  /// the `ai-assist` Edge Function): computed values only, no names or answers.
  static String factsPrompt(DssFlag flag) {
    final evidence = DssCopy.evidenceLabel(flag);
    return [
      'Explain this finding for a non-technical admin.',
      'Finding: ${DssCopy.displayTitle(flag)}',
      'Group: ${flag.cohortLabel}',
      'Status: ${flag.status.label}'
          '${flag.isFinding ? '' : ' (not a finding yet: too few answers)'}',
      'Why it was raised: ${DssCopy.whyFlagged(flag)}',
      '${DssCopy.metricLabel(flag)}: ${DssCopy.metricValueLabel(flag)}',
      'Rule: ${DssCopy.thresholdLabel(flag)}',
      'Answers: ${answersCount(flag)} (${DssCopy.responsesLabel(flag)})',
      if (evidence != null) 'Evidence: $evidence',
      if (flag.certainty != null && flag.isFinding)
        'Certainty: ${flag.certainty!.label}',
      'Roster in group: ${flag.eligibleN ?? 'not available'}',
      'Fixed recommended action: ${DssCopy.displayRecommendedAction(flag)}',
      'Your reply must include the value '
          '"${requiredValueText(flag) ?? 'not shown'}" and the number of '
          'answers (${answersCount(flag)}).',
    ].join('\n');
  }

  /// Answers behind the value: respondents for data quality, otherwise
  /// valid answers to the measured question.
  static int answersCount(DssFlag flag) =>
      flag.isDataQuality ? flag.sampleN : flag.validAnswers;

  /// The value the reply must restate, as shown on the page; null when no
  /// rate is shown (fewer than 5 answers).
  static String? requiredValueText(DssFlag flag) {
    if (flag.evidenceStrength == DssEvidenceStrength.insufficient) return null;
    final v = flag.metricValue;
    if (flag.ruleId == 'SALARY_STAGNATION') {
      return v <= 0 ? null : '${v.toStringAsFixed(1)} bracket(s)';
    }
    if (flag.isTrend) return formatPoints(v);
    return '${(v * 100).toStringAsFixed(0)}%';
  }

  static final _decisionLanguage = <RegExp>[
    RegExp(r'\bprioriti[sz]'),
    RegExp(r'\b(high|higher|highest|top|low|lower|medium) priority\b'),
    RegExp(r'\bmost (urgent|important|pressing)\b'),
    RegExp(r'\brank(ed|ing|s)?\b'),
    RegExp(r'\bseverity\b'),
    RegExp(r'\b(is|as|be) (critical|severe|not serious|minor)\b'),
    RegExp(
      r'\b(resolve|close|dismiss|ignore|reopen|supersede)\s+(this|the)\s+'
      r'(flag|finding|alert|item|issue)\b',
    ),
    RegExp(r'\b(resolve|dismiss|ignore)\s+it\b'),
    RegExp(
      r'\b(should|must|can|could|may) be (resolved|closed|dismissed|ignored)\b',
    ),
    RegExp(r'\bmark(ed)? (it|this|the \w+) as\b'),
    RegExp(r'\b(false alarm|not a real (issue|problem|finding))\b'),
    RegExp(r'\b(succeeded|was successful|were successful|was unsuccessful)\b'),
    RegExp(r'\b(intervention|it|this) (worked|did not work|failed)\b'),
  ];

  /// Why [text] cannot be shown as an explanation of [flag], or null.
  static String? checkReply(String text, DssFlag flag) {
    final lower = text
        .toLowerCase()
        .replaceAll(RegExp(r'rank\s*(/|or|and)\s*clerical'), 'clerical');
    for (final re in _decisionLanguage) {
      if (re.hasMatch(lower)) {
        return 'it went beyond explaining (decision or priority wording)';
      }
    }
    if (!_mentionsValue(lower, flag)) {
      return 'it did not restate the measured value';
    }
    final n = answersCount(flag);
    if (!RegExp('(?<![\\d.])$n(?![\\d.]*\\d)').hasMatch(lower)) {
      return 'it did not restate the number of answers';
    }
    return null;
  }

  static bool _mentionsValue(String lower, DssFlag flag) {
    if (requiredValueText(flag) == null) return true;
    final v = flag.metricValue;
    if (flag.ruleId == 'SALARY_STAGNATION') {
      final one = v.toStringAsFixed(1).replaceAll('.', r'\.');
      final whole = v.toStringAsFixed(0);
      return RegExp('\\b($one|$whole)\\s*(bracket|salary bracket)')
          .hasMatch(lower);
    }
    final pts = (v * 100).abs();
    if (flag.isTrend) {
      final options = {pts.round().toString(), pts.toStringAsFixed(1)};
      return options.any(
        (o) => RegExp(
          '(?<![\\d.])${o.replaceAll('.', r'\.')}\\s*(pts|points|percentage points)',
        ).hasMatch(lower),
      );
    }
    final options = {pts.toStringAsFixed(0), pts.toStringAsFixed(1)};
    return options.any(
      (o) => RegExp(
        '(?<![\\d.])${o.replaceAll('.', r'\.')}\\s*(%|percent)',
      ).hasMatch(lower),
    );
  }

  static bool _looksComplete(String text) {
    if (text.isEmpty) return false;
    if (RegExp(r'''[\s"'‘’“”({\[]$''').hasMatch(text)) return false;
    if (text.length < 40 && !text.endsWith('.') && !text.endsWith('!')) {
      return false;
    }
    return true;
  }

  /// Removes common markdown so admins never see raw **, #, or similar markup.
  static String stripMarkdown(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return text;

    // Heading markers: "# Title" / "## Title"
    text = text.replaceAllMapped(
      RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true),
      (_) => '',
    );
    // Bold/italic markers
    text = text.replaceAll('**', '');
    text = text.replaceAll('__', '');
    text = text.replaceAllMapped(
      RegExp(r'(?<!\w)\*(?!\s)(.+?)(?<!\s)\*(?!\w)'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)'),
      (m) => m.group(1) ?? '',
    );
    // Inline code / backticks
    text = text.replaceAll('`', '');
    // Markdown links [label](url) → label
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1) ?? '',
    );
    // List markers at line starts
    text = text.replaceAllMapped(
      RegExp(r'^\s*[-*+]\s+', multiLine: true),
      (_) => '',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*\d+\.\s+', multiLine: true),
      (m) => '',
    );
    // Collapse leftover stray emphasis characters
    text = text.replaceAll(RegExp(r'[*#_]+'), '');
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
