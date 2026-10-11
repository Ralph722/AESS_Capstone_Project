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

  /// Short forms, acronyms and misspellings of the terms above. Matched as
  /// whole words only. Ambiguous ones (bs = Bachelor of Science, fk = foreign
  /// key, af, sob, pi, mf, tf, fu as in kung fu) are left to the AI pass.
  static const _blockedAbbreviations = <String>[
    // English
    'wtf', 'stfu', 'gtfo', 'omfg', 'lmfao', 'fml', 'kys', 'dafuq',
    'fck', 'fcking', 'fckin', 'fcked', 'fcker', 'fking', 'fkin', 'fkn',
    'fked', 'fuk', 'fuking', 'fukin', 'fuq', 'fvck', 'fcuk', 'phuck', 'phuk',
    'sht', 'shyt', 'btch', 'biatch', 'mofo', 'mfer', 'mfker',
    'dumbass', 'jackass', 'dipshit', 'shithead', 'asshat', 'bitchass',
    // Tagalog / Filipino
    'tngina', 'tngna', 'tnginamo', 'tngnamo', 'ptngina', 'ptngna',
    'ptnginamo', 'putngina', 'potangina', 'pota', 'tangna', 'tanginamo',
    'putanginamo', 'kingina', 'kinginamo', 'inamo', 'inamu', 'olol', 'ulul',
    'tnga', 'kupal', 'tite', 'hinayupak', 'hayup ka', 'leche ka', 'pakshet',
    'pakingshet', 'fakyu', 'pak yu', 'tang na', 'puta ka', 'gago ka',
    'tarantado ka',
    // Bisaya / Cebuano
    'giatay', 'atay ka', 'yawa ka', 'buang ka', 'bilatan', 'bilatin',
    'iyot', 'iyotan', 'iyutan',
  ];

  /// Roots that are never part of a normal word, so they are matched anywhere
  /// inside a word (fuckyou, tanginamoka, putanginaaa).
  static const _blockedRoots = <String>[
    'fuck',
    'putangina',
    'tangina',
    'tngina',
    'kingina',
  ];

  static const _leetMap = <String, String>{
    '@': 'a',
    '4': 'a',
    r'$': 's',
    '5': 's',
    '0': 'o',
    '1': 'i',
    '!': 'i',
    '|': 'i',
    '3': 'e',
    '7': 't',
  };

  Future<ForumModerationResult> reviewTopic({
    required String title,
    required String body,
  }) async {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty || cleanBody.isEmpty) {
      return ForumModerationResult.allowUnchecked;
    }
    return _review(
      localText: '$cleanTitle\n$cleanBody',
      noun: 'post',
      aiMessage:
          'Review this alumni forum post.\n\n'
          'TITLE:\n$cleanTitle\n\n'
          'BODY:\n$cleanBody\n\n'
          'Return JSON only with verdict and reasons.',
    );
  }

  /// Same check as [reviewTopic] for a reply (new or edited).
  Future<ForumModerationResult> reviewReply({
    required String body,
    String? topicTitle,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) return ForumModerationResult.allowUnchecked;
    final context = (topicTitle ?? '').trim();
    return _review(
      localText: cleanBody,
      noun: 'reply',
      aiMessage:
          'Review this reply in an alumni forum discussion.\n\n'
          '${context.isEmpty ? '' : 'DISCUSSION TITLE (context only, do not judge):\n$context\n\n'}'
          'REPLY:\n$cleanBody\n\n'
          'Return JSON only with verdict and reasons.',
    );
  }

  Future<ForumModerationResult> _review({
    required String localText,
    required String noun,
    required String aiMessage,
  }) async {
    final local = _localReview(localText, noun: noun);
    if (local.isBlocked) return local;

    if (!AiConfig.isEnabled) {
      // Local pass only — still allow if no keyword hit.
      return ForumModerationResult.allowUnchecked;
    }

    try {
      final raw = await _ai.sendMessage(
        task: AiTask.forumModeration,
        userMessage: aiMessage,
      );
      final ai = _parse(raw);
      // Prefer the stricter of local vs AI (local already allow here).
      return ai;
    } on AiNotConfiguredException {
      return local.checkedByAi ? local : ForumModerationResult.allowUnchecked;
    } on AiQuotaException {
      // Keep local result; if clean, allow but mark unchecked.
      return local.isClean ? ForumModerationResult.allowUnchecked : local;
    } catch (_) {
      return local.isClean ? ForumModerationResult.allowUnchecked : local;
    }
  }

  ForumModerationResult _localReview(String text, {required String noun}) {
    if (!containsBlockedLanguage(text)) {
      return const ForumModerationResult(
        verdict: ForumModerationVerdict.allow,
        checkedByAi: false,
      );
    }
    return ForumModerationResult(
      verdict: ForumModerationVerdict.block,
      checkedByAi: false,
      reasons: [
        'Inappropriate or vulgar language was detected. '
            'Please revise your $noun.',
      ],
    );
  }

  /// Local keyword check. Catches masked (f*ck, sh1t), stretched (fuuuck),
  /// dotted (w.t.f) and spaced-out (w t f) spellings.
  static bool containsBlockedLanguage(String text) {
    final lower = text.toLowerCase();
    final mapped = lower.split('').map((c) => _leetMap[c] ?? c).join();
    // Checked twice so "wtf!!" is not read as "wtfii".
    return _matches(lower) || (mapped != lower && _matches(mapped));
  }

  static bool _matches(String text) {
    final spacedWords = text
        .replaceAll(RegExp(r'[^a-zñ\s]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    // Strips masking inside a word: f*ck -> fck, w.t.f -> wtf.
    final maskedWords = text
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^a-zñ]'), ''))
        .where((t) => t.isNotEmpty)
        .toList();

    final words = <String>{...spacedWords, ...maskedWords};
    // Joins runs of 3+ single letters: "w t f" -> wtf, "f u c k" -> fuck.
    final run = StringBuffer();
    for (final w in [...spacedWords, '']) {
      if (w.length == 1) {
        run.write(w);
        continue;
      }
      if (run.length >= 3) words.add(run.toString());
      run.clear();
    }
    final squeezedWords = words.map(_squeeze).toSet();

    final spacedLine = ' ${spacedWords.join(' ')} ';
    final squeezedLine = ' ${spacedWords.map(_squeeze).join(' ')} ';

    for (final term in [..._blockedTerms, ..._blockedAbbreviations]) {
      final needle = term.toLowerCase().trim();
      if (needle.isEmpty) continue;
      if (needle.contains(' ')) {
        final squeezedNeedle = needle.split(' ').map(_squeeze).join(' ');
        if (spacedLine.contains(' $needle ') ||
            squeezedLine.contains(' $squeezedNeedle ')) {
          return true;
        }
      } else if (words.contains(needle) ||
          squeezedWords.contains(_squeeze(needle))) {
        return true;
      }
    }

    for (final root in _blockedRoots) {
      final squeezedRoot = _squeeze(root);
      if (squeezedWords.any((w) => w.contains(squeezedRoot))) return true;
    }
    return false;
  }

  /// Collapses repeated letters so fuuuck, fuckk and bullshit compare as
  /// fuck, fuck and bulshit.
  static String _squeeze(String word) =>
      word.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);

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
          json =
              jsonDecode(text.substring(start, end + 1))
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
      'block' ||
      'blocked' ||
      'reject' ||
      'denied' => ForumModerationVerdict.block,
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
