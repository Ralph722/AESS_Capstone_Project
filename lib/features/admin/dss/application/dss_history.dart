import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

/// Interventions counted by next-wave outcome.
class DssOutcomeTally {
  DssOutcomeTally([Map<DssOutcomeStatus, int>? counts])
    : counts = counts ?? {};

  final Map<DssOutcomeStatus, int> counts;

  int count(DssOutcomeStatus s) => counts[s] ?? 0;

  int get total => counts.values.fold(0, (a, b) => a + b);

  /// Not judged yet: not checked, or waiting for the next wave.
  int get waiting =>
      count(DssOutcomeStatus.notEvaluated) +
      count(DssOutcomeStatus.pendingFollowup);

  /// Judged against a comparable next wave (Successful, Partially
  /// successful, Unsuccessful or Inconclusive).
  int get judged =>
      count(DssOutcomeStatus.successful) +
      count(DssOutcomeStatus.partiallySuccessful) +
      count(DssOutcomeStatus.unsuccessful) +
      count(DssOutcomeStatus.inconclusive);

  void add(DssOutcomeStatus s) => counts[s] = count(s) + 1;
}

/// Intervention outcomes grouped by intervention type and by rule.
class DssOutcomeSummary {
  DssOutcomeSummary._(this.overall, this.byType, this.byRule);

  /// Types are grouped ignoring case and extra spaces; the label is the
  /// first spelling seen (newest first when [interventions] is newest
  /// first).
  factory DssOutcomeSummary.from(Iterable<DssIntervention> interventions) {
    final overall = DssOutcomeTally();
    final byType = <String, DssOutcomeTally>{};
    final labels = <String, String>{};
    final byRule = <String, DssOutcomeTally>{};
    for (final i in interventions) {
      overall.add(i.outcomeStatus);
      final label = typeLabel(i.interventionType);
      final key = label.toLowerCase();
      labels.putIfAbsent(key, () => label);
      byType.putIfAbsent(labels[key]!, DssOutcomeTally.new).add(i.outcomeStatus);
      byRule.putIfAbsent(i.ruleId, DssOutcomeTally.new).add(i.outcomeStatus);
    }
    return DssOutcomeSummary._(overall, _sorted(byType), _sorted(byRule));
  }

  final DssOutcomeTally overall;

  /// Most recorded first, then by name.
  final Map<String, DssOutcomeTally> byType;

  /// Rule id → tally, most recorded first.
  final Map<String, DssOutcomeTally> byRule;

  bool get isEmpty => overall.total == 0;

  static String typeLabel(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.isEmpty ? 'Not specified' : t;
  }

  static Map<String, DssOutcomeTally> _sorted(Map<String, DssOutcomeTally> m) {
    final entries = m.entries.toList()
      ..sort((a, b) {
        final c = b.value.total.compareTo(a.value.total);
        return c != 0 ? c : a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    return {for (final e in entries) e.key: e.value};
  }
}

/// One Refresh or nightly run, from `dss_evaluation_events`.
class DssEvaluationRun {
  const DssEvaluationRun({
    required this.runId,
    required this.scheduled,
    required this.at,
    required this.raised,
    required this.updated,
    required this.superseded,
    required this.skipped,
    required this.notEnoughData,
  });

  final String runId;

  /// Nightly job (`scheduled`) rather than a Refresh click (`manual`).
  final bool scheduled;
  final DateTime at;
  final int raised;
  final int updated;
  final int superseded;

  /// Not raised again: a newer wave checked the finding, or its flag was
  /// already closed for that wave.
  final int skipped;

  /// Group measures with fewer than 5 answers.
  final int notEnoughData;

  String get triggerLabel => scheduled ? 'Nightly' : 'Manual Refresh';

  /// Groups event rows by run, newest run first, keeping [limit] runs.
  static List<DssEvaluationRun> fromEvents(
    Iterable<Map<String, dynamic>> rows, {
    int limit = 20,
  }) {
    final byRun = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final id = (r['run_id'] ?? '').toString();
      if (id.isEmpty) continue;
      byRun.putIfAbsent(id, () => []).add(r);
    }
    final runs = [
      for (final e in byRun.entries) _fromRows(e.key, e.value),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return runs.take(limit).toList();
  }

  static DssEvaluationRun _fromRows(
    String runId,
    List<Map<String, dynamic>> rows,
  ) {
    int count(bool Function(String outcome, String reason) test) => rows
        .where(
          (r) => test(
            (r['outcome'] ?? '').toString(),
            (r['reason'] ?? '').toString(),
          ),
        )
        .length;
    final times = [
      for (final r in rows)
        if (DateTime.tryParse(r['created_at']?.toString() ?? '') case final t?)
          t,
    ];
    return DssEvaluationRun(
      runId: runId,
      scheduled: rows.any((r) => r['run_trigger'] == 'scheduled'),
      at: times.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : times.reduce((a, b) => a.isBefore(b) ? a : b),
      raised: count((o, _) => o == 'raised'),
      updated: count((o, _) => o == 'updated'),
      superseded: count((o, _) => o == 'superseded'),
      skipped: count((o, r) => o == 'suppressed' && r != 'not_enough_data'),
      notEnoughData: count((o, r) => o == 'suppressed' && r == 'not_enough_data'),
    );
  }
}
