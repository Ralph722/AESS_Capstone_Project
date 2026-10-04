import 'dart:math' as math;

import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

/// A share of answers that hit a condition (e.g. 7 of 25 not employed).
class DssProportion {
  const DssProportion({required this.hits, required this.total});

  final int hits;
  final int total;

  double get rate => total <= 0 ? 0 : hits / total;
}

/// Course / curriculum relatedness over respondents who answered Q24 or Q32.
class DssRelatedness {
  const DssRelatedness({
    required this.mismatch,
    required this.answered,
    required this.mismatchSuggestions,
  });

  /// Respondents with "No" on Q24 (first job related) or Q32 (curriculum
  /// relevant).
  final int mismatch;
  final int answered;

  /// Q34 suggestions written by respondents counted in [mismatch].
  final List<String> mismatchSuggestions;

  int get aligned => answered - mismatch;

  DssProportion get mismatchShare =>
      DssProportion(hits: mismatch, total: answered);

  /// Complement of [mismatchShare] so RELATEDNESS_LOW and RELATEDNESS_HIGH
  /// always describe the same respondents.
  DssProportion get alignedShare => DssProportion(hits: aligned, total: answered);
}

/// Pure CHED GTS metric calculations shared by evaluation and impact
/// re-checks, so both always use the same definitions.
abstract final class DssMetrics {
  static const longTimeToJob = {
    '1 year to less than 2 years',
    '2 years to less than 3 years',
    '3 years to less than 4 years',
  };

  static const clericalLevel = 'Rank or Clerical';
  static const currentJobCol = '30.2. Current or Present Job';
  static const firstJobCol = '30.1. First Job';

  static const salaryBrackets = [
    'Below P5,000.00',
    'P5,000.00 to less than P10,000.00',
    'P10,000.00 to less than P15,000.00',
    'P15,000.00 to less than P20,000.00',
    'P20,000.00 to less than P25,000.00',
    'P25,000.00 and above',
  ];

  /// Salary bracket rank (higher = better). Unknown → -1.
  static int salaryRank(String? bracket) =>
      salaryBrackets.indexOf((bracket ?? '').trim());

  /// Q16: "No" or "Never Employed" among respondents who answered.
  static DssProportion? unemployment(Iterable<Map<String, dynamic>> answers) {
    final values = answers
        .map((a) => single(a['ched_16']))
        .whereType<String>()
        .toList();
    if (values.isEmpty) return null;
    final notEmployed = values
        .where(
          (v) => v == ChedGtsBuiltin.no || v == ChedGtsBuiltin.neverEmployed,
        )
        .length;
    return DssProportion(hits: notEmployed, total: values.length);
  }

  static Map<String, int> employmentBreakdown(
    Iterable<Map<String, dynamic>> answers,
  ) =>
      counts(answers.map((a) => single(a['ched_16'])).whereType<String>());

  static DssRelatedness? relatedness(Iterable<Map<String, dynamic>> answers) {
    var mismatch = 0;
    var answered = 0;
    final suggestions = <String>[];
    for (final a in answers) {
      final a24 = single(a['ched_24a']);
      final a32 = single(a['ched_32']);
      if (a24 == null && a32 == null) continue;
      answered++;
      if (a24 == ChedGtsBuiltin.no || a32 == ChedGtsBuiltin.no) {
        mismatch++;
        final sug = a['ched_34']?.toString().trim() ?? '';
        if (sug.isNotEmpty) suggestions.add(sug);
      }
    }
    if (answered == 0) return null;
    return DssRelatedness(
      mismatch: mismatch,
      answered: answered,
      mismatchSuggestions: suggestions,
    );
  }

  /// Q30: Rank/Clerical among presently employed respondents (current job,
  /// falling back to first job).
  static DssProportion? clerical(Iterable<Map<String, dynamic>> answers) {
    var hits = 0;
    var total = 0;
    for (final a in answers) {
      if (single(a['ched_16']) != ChedGtsBuiltin.yes) continue;
      final level = jobLevel(a['ched_30']);
      if (level == null) continue;
      total++;
      if (level == clericalLevel) hits++;
    }
    if (total == 0) return null;
    return DssProportion(hits: hits, total: total);
  }

  /// Q29: one year or longer to land a first job.
  static DssProportion? longTimeToFirstJob(
    Iterable<Map<String, dynamic>> answers,
  ) {
    final values = timeToJobAnswers(answers);
    if (values.isEmpty) return null;
    return DssProportion(
      hits: values.where(longTimeToJob.contains).length,
      total: values.length,
    );
  }

  static List<String> timeToJobAnswers(
    Iterable<Map<String, dynamic>> answers,
  ) =>
      answers.map((a) => single(a['ched_29'])).whereType<String>().toList();

  /// Q31 salary ranks for respondents with a known bracket.
  static List<int> salaryRanks(Iterable<Map<String, dynamic>> answers) =>
      answers
          .map((a) => salaryRank(single(a['ched_31'])))
          .where((r) => r >= 0)
          .toList();

  /// Median salary rank of every course except [course]. Null when no other
  /// course has salary answers.
  static double? peerMedianExcluding(
    Map<String, List<int>> ranksByCourse,
    String course,
  ) {
    final peers = [
      for (final e in ranksByCourse.entries)
        if (e.key != course) ...e.value,
    ];
    if (peers.isEmpty) return null;
    return median(peers.map((e) => e.toDouble()));
  }

  /// Bracket steps the cohort's median sits below [peerMedian]
  /// (positive = worse). Null when the cohort has no salary answers.
  static double? salaryGap(List<int> cohortRanks, double? peerMedian) {
    if (cohortRanks.isEmpty || peerMedian == null) return null;
    return peerMedian - median(cohortRanks.map((e) => e.toDouble()));
  }

  /// 95% Wilson score interval for [hits] out of [total]. Stays inside 0–1
  /// and behaves sensibly for small groups and 0% / 100% shares.
  static ({double low, double high}) wilson(
    int hits,
    int total, {
    double z = 1.959964,
  }) {
    if (total <= 0) return (low: 0, high: 1);
    final p = hits / total;
    final z2 = z * z;
    final denom = 1 + z2 / total;
    final centre = (p + z2 / (2 * total)) / denom;
    final half =
        z * math.sqrt(p * (1 - p) / total + z2 / (4 * total * total)) / denom;
    return (
      low: hits <= 0 ? 0.0 : math.max(0.0, centre - half),
      high: hits >= total ? 1.0 : math.min(1.0, centre + half),
    );
  }

  /// 95% interval for the change `current − previous` between two shares
  /// (Newcombe's method, built from each share's Wilson interval).
  static ({double low, double high}) changeInterval(
    DssProportion current,
    DssProportion previous,
  ) {
    final c = current.rate;
    final p = previous.rate;
    final ci = wilson(current.hits, current.total);
    final pi = wilson(previous.hits, previous.total);
    final d = c - p;
    return (
      low: d - math.sqrt(math.pow(c - ci.low, 2) + math.pow(pi.high - p, 2)),
      high: d + math.sqrt(math.pow(ci.high - c, 2) + math.pow(p - pi.low, 2)),
    );
  }

  /// "confirmed" when even the favourable end of the interval still crosses
  /// the threshold (lower bound for gte/gt rules, upper bound for lt/lte);
  /// otherwise "possible".
  static String certainty(
    String operator,
    double threshold,
    ({double low, double high}) interval,
  ) {
    final bound = operator == 'lt' || operator == 'lte'
        ? interval.high
        : interval.low;
    return crosses(operator, bound, threshold) ? 'confirmed' : 'possible';
  }

  static bool crosses(String operator, double value, double threshold) {
    switch (operator) {
      case 'gt':
        return value > threshold;
      case 'lt':
        return value < threshold;
      case 'lte':
        return value <= threshold;
      case 'gte':
      default:
        return value >= threshold;
    }
  }

  static String? single(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      if (raw.isEmpty) return null;
      final s = raw.first.toString().trim();
      return s.isEmpty ? null : s;
    }
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Prefer current job level; fall back to first job.
  static String? jobLevel(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    String? fromCol(String col) {
      for (final entry in map.entries) {
        final cols = entry.value;
        if (cols is Map && cols[col] == true) return entry.key.toString();
      }
      return null;
    }

    return fromCol(currentJobCol) ?? fromCol(firstJobCol);
  }

  static Map<String, int> counts(Iterable<String> values) {
    final out = <String, int>{};
    for (final v in values) {
      out[v] = (out[v] ?? 0) + 1;
    }
    return out;
  }

  static double median(Iterable<double> values) {
    final list = values.toList()..sort();
    if (list.isEmpty) return 0;
    final mid = list.length ~/ 2;
    if (list.length.isOdd) return list[mid];
    return (list[mid - 1] + list[mid]) / 2;
  }

  static List<String> themeHints(List<String> texts) => keywordThemes(texts)
      .take(5)
      .map((t) => '${t.label} (${t.count})')
      .toList();

  static const _emptySuggestions = {
    'none', 'n/a', 'na', 'nothing', 'no', 'no suggestion', 'no suggestions',
    'nothing to suggest', 'none so far', '-', '.', 'ok', 'okay',
  };

  /// Q34 free-text curriculum suggestions, skipping placeholders like "N/A".
  static List<String> curriculumSuggestions(
    Iterable<Map<String, dynamic>> answers,
  ) {
    final out = <String>[];
    for (final a in answers) {
      final text = (a['ched_34']?.toString() ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.length < 3) continue;
      final key = text.toLowerCase().replaceAll(RegExp(r'[.!]+$'), '').trim();
      if (_emptySuggestions.contains(key)) continue;
      out.add(text);
    }
    return out;
  }

  /// Q33: how often each listed competency was picked as useful.
  static Map<String, int> usefulCompetencies(
    Iterable<Map<String, dynamic>> answers,
  ) {
    final picks = <String>[];
    for (final a in answers) {
      final raw = a['ched_33'];
      final values = raw is List ? raw : (raw == null ? const [] : [raw]);
      for (final v in values) {
        final s = v.toString().trim();
        if (s.isEmpty || s.startsWith('Other skills')) continue;
        picks.add(s);
      }
    }
    return counts(picks);
  }

  static const _themeKeywords = {
    'Internships / OJT': ['internship', 'ojt', 'on-the-job', 'on the job', 'practicum', 'immersion'],
    'Industry exposure and partnerships': ['industry', 'company', 'companies', 'partner', 'field trip', 'seminar'],
    'Hands-on and project-based learning': ['hands-on', 'hands on', 'practical', 'project', 'laboratory', 'lab '],
    'Updated tools and technology': ['software', 'tools', 'technology', 'equipment', 'updated', 'modern', 'latest'],
    'Programming and technical depth': ['coding', 'programming', 'technical', 'develop'],
    'Communication and English': ['communication', 'english', 'speaking', 'writing', 'presentation'],
    'Soft skills and work readiness': ['soft skill', 'leadership', 'teamwork', 'work ethic', 'interview', 'resume', 'career'],
    'Certifications and licensure': ['certification', 'certificate', 'licensure', 'board exam', 'nc ii', 'tesda'],
    'Teaching quality and faculty': ['teacher', 'instructor', 'faculty', 'professor', 'teaching'],
  };

  /// Keyword grouping of [texts]; each theme lists the indexes it covers.
  static List<DssTheme> keywordThemes(List<String> texts) {
    final hits = <String, List<int>>{};
    for (var i = 0; i < texts.length; i++) {
      final lower = texts[i].toLowerCase();
      for (final e in _themeKeywords.entries) {
        if (e.value.any(lower.contains)) {
          hits.putIfAbsent(e.key, () => []).add(i);
        }
      }
    }
    final themes = [
      for (final e in hits.entries) DssTheme(label: e.key, indexes: e.value),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return themes;
  }
}

/// A group of alumni suggestions; [indexes] point into the source text list.
class DssTheme {
  const DssTheme({required this.label, required this.indexes});

  final String label;
  final List<int> indexes;

  int get count => indexes.length;
}
