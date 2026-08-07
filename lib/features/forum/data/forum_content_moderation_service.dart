import 'dart:convert';

import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/ai/data/ai_assistant_service.dart';

enum ForumModerationVerdict { allow, warn, block }

class ForumModerationResult {
  const ForumModerationResult({
    required this.verdict,
    this.reasons = const [],
    this.checkedByAi = true,
  });

  final ForumModerationVerdict verdict;
  final List<String> reasons;
  final bool checkedByAi;

  bool get isClean => verdict == ForumModerationVerdict.allow;
  bool get isBlocked => verdict == ForumModerationVerdict.block;
  bool get isWarned => verdict == ForumModerationVerdict.warn;

  static const allowUnchecked = ForumModerationResult(
    verdict: ForumModerationVerdict.allow,
    checkedByAi: false,
  );
}

/// Pre-publish content check for forum topic title + body.
///
/// Uses a local keyword/heuristic pass first, then Gemini AI when available.
class ForumContentModerationService {
  ForumContentModerationService({AiAssistantService? ai})
      : _ai = ai ?? AiAssistantService();

  final AiAssistantService _ai;

  /// Common vulgar / abusive terms (English, Tagalog, Bisaya).
  /// Word-boundary matched after normalizing punctuation.
  static const _blockedTerms = <String>[
    // English
    'fuck', 'fucking', 'fucker', 'motherfucker', 'shit', 'bullshit',
    'bitch', 'asshole', 'bastard', 'dick', 'cock', 'pussy', 'cunt',
    'whore', 'slut', 'nigger', 'nigga', 'retard', 'rape', 'rapist',
    // Tagalog / Filipino
    'putangina', 'puta', 'tangina', 'tang ina', 'gago', 'gaga',
    'ulol', 'tarantado', 'punyeta', 'puneta', 'leche', 'lintik',
    'hayop ka', 'bobo', 'tanga', 'inutil', 'pokpok', 'bayot',
    'kantot', 'kantutan', 'jakol', 'libog', 'burat',
    'pekpek', 'puke', 'titi', 'bayag',
    // Bisaya / Cebuano
    'yawa', 'atay', 'piste', 'pisti', 'buang', 'animal ka',
    'bilat', 'oten', 'utot', 'bogo', 'boang', 'pakyu', 'pakyaw',
  ];

  static const _systemInstruction = '''
You are a strict content-safety reviewer for a university alumni portal forum
in the Philippines (USTP alumni + alumni office).

You MUST understand and evaluate content in:
- English
- Tagalog / Filipino
- Bisaya / Cebuano
- Mixed Taglish / Bislish

BLOCK (verdict "block") when the text contains any of:
- Profanity, swearing, vulgar or sexual slang (any of the languages above)
- Insults, harassment, bullying, hate, threats
- Explicit sexual content
- Graphic violence or self-harm encouragement
- Scams, phishing, malware / suspicious fraud links, doxxing, illegal activity

Normal http/https links to jobs, events, forms, articles, or official sites are ALLOWED
unless they clearly look like phishing or scams.

WARN (verdict "warn") only for borderline sensitive topics that are not clearly vulgar
but may still need user review (e.g. graphic health details, heated political attacks
without swear words).

ALLOW only if the post is appropriate for a professional alumni community.

IMPORTANT:
- Do NOT treat swear words as "mild slang". Swear words and insults must be "block".
- Masked swear words (f*ck, p@ta, put@ngina, g@go) still count as block.
- If unsure between warn and block for vulgar language, choose "block".

Respond with ONLY valid JSON (no markdown):
{"verdict":"allow"|"warn"|"block","reasons":["short reason in English"]}
''';

  Future<ForumModerationResult> reviewTopic({
    required String title,
    required String body,
  }) async {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty || cleanBody.isEmpty) {
      return ForumModerationResult.allowUnchecked;
    }

    final local = _localReview('$cleanTitle\n$cleanBody');
    if (local.isBlocked) return local;

    if (!AiConfig.isConfigured) {
      // Local pass only — still allow if no keyword hit.
      return ForumModerationResult.allowUnchecked;
    }

    try {
      final raw = await _ai.sendMessage(
        isAdmin: false,
        history: const [],
        temperature: 0.0,
        maxOutputTokens: 256,
        responseMimeType: 'application/json',
        systemInstructionOverride: _systemInstruction,
        userMessage:
            'Review this alumni forum post.\n\n'
            'TITLE:\n$cleanTitle\n\n'
            'BODY:\n$cleanBody\n\n'
            'Return JSON only with verdict and reasons.',
      );
      final ai = _parse(raw);
      // Prefer the stricter of local vs AI (local already allow here).
      return ai;
    } on AiNotConfiguredException {
      return local.checkedByAi ? local : ForumModerationResult.allowUnchecked;
    } on AiQuotaException {
      // Keep local result; if clean, allow but mark unchecked.
      return local.isClean
          ? ForumModerationResult.allowUnchecked
          : local;
    } catch (_) {
      return local.isClean
          ? ForumModerationResult.allowUnchecked
          : local;
    }
  }

  ForumModerationResult _localReview(String text) {
    final lower = text.toLowerCase();
    final spaced = lower
        .replaceAll(RegExp(r'[^a-z0-9ñ\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Collapses f*ck / p@ta style masking into letter-only tokens.
    final tokens = lower
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^a-zñ]'), ''))
        .where((t) => t.isNotEmpty)
        .toList();

    final hits = <String>[];
    for (final term in _blockedTerms) {
      final needle = term.toLowerCase().trim();
      if (needle.isEmpty) continue;

      final matched = needle.contains(' ')
          ? spaced.contains(needle)
          : (RegExp('\\b${RegExp.escape(needle)}\\b').hasMatch(spaced) ||
              tokens.contains(needle));

      if (matched) {
        hits.add(needle);
        if (hits.length >= 2) break;
      }
    }

    if (hits.isEmpty) {
      return const ForumModerationResult(
        verdict: ForumModerationVerdict.allow,
        checkedByAi: false,
      );
    }

    return const ForumModerationResult(
      verdict: ForumModerationVerdict.block,
      checkedByAi: false,
      reasons: [
        'Inappropriate or vulgar language was detected. Please revise your post.',
      ],
    );
  }

  ForumModerationResult _parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return ForumModerationResult.allowUnchecked;

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(_stripFences(text)) as Map<String, dynamic>?;
    } catch (_) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          json = jsonDecode(text.substring(start, end + 1))
              as Map<String, dynamic>?;
        } catch (_) {
          return ForumModerationResult.allowUnchecked;
        }
      }
    }

    if (json == null) return ForumModerationResult.allowUnchecked;

    final verdictRaw = (json['verdict']?.toString() ?? 'allow')
        .toLowerCase()
        .trim();
    final verdict = switch (verdictRaw) {
      'block' || 'blocked' || 'reject' || 'denied' =>
        ForumModerationVerdict.block,
      'warn' || 'warning' || 'review' => ForumModerationVerdict.warn,
      _ => ForumModerationVerdict.allow,
    };

    final reasons = <String>[];
    final rawReasons = json['reasons'];
    if (rawReasons is List) {
      for (final r in rawReasons) {
        final s = r?.toString().trim() ?? '';
        if (s.isNotEmpty) reasons.add(s);
      }
    } else if (rawReasons is String && rawReasons.trim().isNotEmpty) {
      reasons.add(rawReasons.trim());
    }

    return ForumModerationResult(
      verdict: verdict,
      reasons: reasons.take(3).toList(),
    );
  }

  String _stripFences(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
      t = t.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return t.trim();
  }
}
