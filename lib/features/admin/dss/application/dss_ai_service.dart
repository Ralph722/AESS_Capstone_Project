import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';
import 'package:alumni_system/features/ai/models/ai_chat_message.dart';

/// Narrow AI helpers: phrase flags and prioritize open items. Never invents rules.
class DssAiService {
  DssAiService({AiAssistantService? ai}) : _ai = ai ?? AiAssistantService();

  final AiAssistantService _ai;

  Future<String> phraseFlag(DssFlag flag) async {
    final fallback =
        '${DssCopy.whyFlagged(flag)} ${DssCopy.displayRecommendedAction(flag)}';
    if (!AiConfig.isConfigured) return fallback;
    try {
      final text = await _ai.sendMessage(
        isAdmin: true,
        history: const <AiChatMessage>[],
        userMessage:
            'Write a complete admin briefing in 2-4 short sentences. '
            'Finish every sentence. Be plain and clear for non-technical admins. '
            'Do not invent recommendations.\n'
            'Display title: ${DssCopy.displayTitle(flag)}\n'
            'Why flagged: ${DssCopy.whyFlagged(flag)}\n'
            'Finding: ${DssCopy.displayHeadline(flag)}\n'
            '${DssCopy.metricLabel(flag)}: ${DssCopy.metricValueLabel(flag)}\n'
            'Rule threshold wording: ${DssCopy.thresholdLabel(flag)}\n'
            'Responses: ${flag.sampleN}; roster in group: ${flag.eligibleN ?? 'n/a'}\n'
            'Fixed recommended action: ${DssCopy.displayRecommendedAction(flag)}',
        systemInstructionOverride:
            'You help university alumni-office admins understand DSS alerts. '
            'Explain clearly why the flag exists. If response rate is high but '
            'the flag is about too few responses, say that explicitly. '
            'Restate only supplied facts and the fixed recommended action. '
            'Never leave a sentence unfinished. '
            'Use plain text only — no markdown, asterisks, hashtags, or bullet symbols.',
        temperature: 0.2,
        maxOutputTokens: 2048,
        disableThinking: true,
      );
      return _completeOrFallback(text, fallback);
    } catch (_) {
      return fallback;
    }
  }

  Future<String> prioritizeFlags(List<DssFlag> openFlags) async {
    if (openFlags.isEmpty) return 'No open flags.';
    final sorted = [...openFlags]..sort((a, b) {
      final sev = _sevRank(b.severity).compareTo(_sevRank(a.severity));
      if (sev != 0) return sev;
      final n = b.sampleN.compareTo(a.sampleN);
      if (n != 0) return n;
      return a.createdAt.compareTo(b.createdAt);
    });
    final heuristic = StringBuffer('Suggested priority:\n');
    for (var i = 0; i < sorted.length && i < 8; i++) {
      final f = sorted[i];
      heuristic.writeln(
        '${i + 1}. ${DssCopy.displayTitle(f)} (${f.cohortLabel}) — '
        '${DssCopy.responsesLabel(f)}, ${f.status.label}',
      );
    }
    if (!AiConfig.isConfigured) return heuristic.toString();
    try {
      final facts = sorted
          .take(12)
          .map(
            (f) =>
                '- ${DssCopy.displayTitle(f)} | ${f.cohortLabel} | '
                '${DssCopy.metricLabel(f)}=${DssCopy.metricValueLabel(f)} | '
                '${DssCopy.responsesLabel(f)} | '
                'why=${DssCopy.whyFlagged(f)} | status=${f.status.label}',
          )
          .join('\n');
      final ai = await _ai.sendMessage(
        isAdmin: true,
        history: const <AiChatMessage>[],
        userMessage:
            'Suggest a short priority order for these open DSS flags and why. '
            'Prefer higher severity, larger affected groups, and older items. '
            'Write complete plain sentences.\n$facts',
        systemInstructionOverride:
            'You prioritize existing DSS flags for alumni admins. '
            'Use only the supplied facts. Keep under 180 words. '
            'Never leave a sentence unfinished. '
            'Use plain text only — no markdown, asterisks, hashtags, or bullet symbols.',
        temperature: 0.2,
        maxOutputTokens: 2048,
        disableThinking: true,
      );
      return _completeOrFallback(ai, heuristic.toString());
    } catch (_) {
      return heuristic.toString();
    }
  }

  String _completeOrFallback(String raw, String fallback) {
    final text = _stripMarkdown(raw);
    if (text.isEmpty) return fallback;
    final truncatedTail = RegExp(r'''[\s"'‘’“”({\[]$''');
    if (truncatedTail.hasMatch(text)) return fallback;
    if (text.length < 40 && !text.endsWith('.') && !text.endsWith('!')) {
      return fallback;
    }
    return text;
  }

  /// Removes common markdown so admins never see raw **, #, or similar markup.
  String _stripMarkdown(String raw) {
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

  int _sevRank(DssSeverity? s) => switch (s) {
    DssSeverity.critical => 3,
    DssSeverity.warning => 2,
    DssSeverity.info => 1,
    null => 2,
  };
}
