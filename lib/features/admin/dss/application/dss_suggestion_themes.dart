import 'dart:convert';

import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluation_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';
import 'package:alumni_system/features/ai/models/ai_chat_message.dart';

/// Curriculum feedback for one flag's group: Q34 suggestions grouped into
/// themes (quotes are always the alumni's own text) plus Q33 competency picks.
class DssSuggestionSummary {
  const DssSuggestionSummary({
    required this.respondents,
    required this.texts,
    required this.themes,
    required this.competencies,
    this.byAi = false,
  });

  final int respondents;
  final List<String> texts;
  final List<DssTheme> themes;
  final Map<String, int> competencies;
  final bool byAi;

  int get themed => {for (final t in themes) ...t.indexes}.length;

  List<String> quotes(DssTheme theme) => [
    for (final i in theme.indexes)
      if (i >= 0 && i < texts.length) texts[i],
  ];

  List<MapEntry<String, int>> get topCompetencies =>
      competencies.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

class DssSuggestionThemeService {
  DssSuggestionThemeService({
    DssEvaluationService? eval,
    AiAssistantService? ai,
  }) : _eval = eval ?? DssEvaluationService(),
       _ai = ai ?? AiAssistantService();

  final DssEvaluationService _eval;
  final AiAssistantService _ai;

  static const maxThemes = 6;
  static const maxTexts = 150;
  static const _maxChars = 300;

  static final Map<String, List<DssTheme>> _aiCache = {};

  static bool appliesTo(DssFlag flag) =>
      flag.ruleId == 'RELATEDNESS_LOW' || flag.ruleId == 'RELATEDNESS_HIGH';

  Future<DssSuggestionSummary> summarize(DssFlag flag) async {
    final answers = await _eval.answersForFlag(flag);
    final texts = DssMetrics.curriculumSuggestions(answers);
    final competencies = DssMetrics.usefulCompetencies(answers);
    final keyword = DssMetrics.keywordThemes(texts).take(maxThemes).toList();

    DssSuggestionSummary result({List<DssTheme>? ai}) => DssSuggestionSummary(
      respondents: answers.length,
      texts: texts,
      themes: ai ?? keyword,
      competencies: competencies,
      byAi: ai != null,
    );

    if (texts.length < 2 || !AiConfig.isConfigured) return result();

    final cacheKey = '${flag.id}:${texts.length}:${Object.hashAll(texts)}';
    final cached = _aiCache[cacheKey];
    if (cached != null) return result(ai: cached);

    try {
      final themes = await _groupWithAi(texts);
      if (themes.isEmpty) return result();
      _aiCache[cacheKey] = themes;
      return result(ai: themes);
    } catch (_) {
      return result();
    }
  }

  Future<List<DssTheme>> _groupWithAi(List<String> texts) async {
    final shown = texts.take(maxTexts).toList();
    final numbered = StringBuffer();
    for (var i = 0; i < shown.length; i++) {
      final t = shown[i];
      final clipped = t.length > _maxChars ? '${t.substring(0, _maxChars)}…' : t;
      numbered.writeln('${i + 1}. ${clipped.replaceAll('\n', ' ')}');
    }
    final raw = await _ai.sendMessage(
      isAdmin: true,
      history: const <AiChatMessage>[],
      userMessage:
          'Group these alumni curriculum suggestions into at most $maxThemes '
          'themes. Return JSON only, shaped like '
          '{"themes":[{"label":"Short theme","items":[1,4]}]}.\n'
          'Suggestions:\n$numbered',
      systemInstructionOverride:
          'You group free-text curriculum suggestions written by university '
          'alumni. Use only the numbered suggestions supplied. A theme label '
          'is a neutral noun phrase of at most 6 words describing what alumni '
          'asked for. List a suggestion number under a theme only when that '
          'suggestion clearly asks for it. Skip suggestions that fit no theme. '
          'Never invent suggestions, quotes, or numbers. Output JSON only.',
      temperature: 0.1,
      maxOutputTokens: 2048,
      responseMimeType: 'application/json',
      disableThinking: true,
    );
    return parseAiThemes(raw, shown.length);
  }

  /// Validates the AI reply: keeps only in-range suggestion numbers (as
  /// 0-based indexes), drops empty themes, and sorts by size.
  static List<DssTheme> parseAiThemes(String raw, int textCount) {
    var body = raw.trim();
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(body);
    if (fenced != null) body = fenced.group(1)!.trim();

    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    final list = switch (decoded) {
      {'themes': final List<dynamic> t} => t,
      final List<dynamic> t => t,
      _ => const <dynamic>[],
    };

    final themes = <DssTheme>[];
    final seenLabels = <String>{};
    for (final item in list) {
      if (item is! Map) continue;
      var label = (item['label'] ?? '')
          .toString()
          .replaceAll(RegExp(r'[*#_`]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (label.isEmpty) continue;
      if (label.length > 60) label = '${label.substring(0, 57).trim()}...';
      if (!seenLabels.add(label.toLowerCase())) continue;

      final rawItems = item['items'];
      if (rawItems is! List) continue;
      final indexes = <int>{};
      for (final n in rawItems) {
        final v = n is num ? n.toInt() : int.tryParse(n.toString().trim());
        if (v != null && v >= 1 && v <= textCount) indexes.add(v - 1);
      }
      if (indexes.isEmpty) continue;
      themes.add(DssTheme(label: label, indexes: indexes.toList()..sort()));
    }
    themes.sort((a, b) => b.count.compareTo(a.count));
    return themes.take(maxThemes).toList();
  }
}
