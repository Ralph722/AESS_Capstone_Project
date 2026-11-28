import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

/// A stored flag as the sync sees it.
typedef DssStoredFlag = ({
  String id,
  String findingKey,
  String surveyId,
  DssFlagStatus status,
});

/// One row of `dss_evaluation_events`, before the run id is attached.
class DssEvaluationEvent {
  const DssEvaluationEvent({
    required this.findingKey,
    required this.surveyId,
    required this.outcome,
    required this.reason,
    this.flagId,
    this.validAnswers,
  });

  final String findingKey;
  final String surveyId;

  /// raised, updated, suppressed or superseded.
  final String outcome;
  final String reason;
  final String? flagId;
  final int? validAnswers;

  DssEvaluationEvent withFlag(String? id) => DssEvaluationEvent(
    findingKey: findingKey,
    surveyId: surveyId,
    outcome: outcome,
    reason: reason,
    flagId: id,
    validAnswers: validAnswers,
  );

  Map<String, dynamic> toRow({
    required String runId,
    required String trigger,
  }) => {
    'run_id': runId,
    'run_trigger': trigger,
    'finding_key': findingKey,
    'survey_id': surveyId,
    'flag_id': flagId,
    'outcome': outcome,
    'reason': reason,
    'valid_answers': validAnswers,
  };
}

/// What one Refresh wrote.
class DssSyncSummary {
  const DssSyncSummary({
    required this.raised,
    required this.updated,
    required this.superseded,
    required this.skippedNewerWave,
    required this.skippedClosed,
    this.legacy = false,
  });

  final int raised;
  final int updated;
  final int superseded;

  /// Older-wave results not raised because a newer wave checked them.
  final int skippedNewerWave;

  /// Results not raised again because their flag was closed in that wave.
  final int skippedClosed;

  /// Saved without the finding-identity schema (one open flag per row).
  final bool legacy;

  String get message {
    if (legacy) return '';
    final b = StringBuffer(' Saved: $raised new, $updated refreshed');
    if (superseded > 0) {
      b.write(', $superseded older-wave flag(s) superseded by a newer wave');
    }
    b.write('.');
    if (skippedNewerWave > 0) {
      b.write(
        ' $skippedNewerWave older-wave result(s) were not raised because a '
        'newer wave checked the same finding.',
      );
    }
    if (skippedClosed > 0) {
      b.write(
        ' $skippedClosed result(s) were not raised again because their flag '
        'was already closed for that wave.',
      );
    }
    return b.toString();
  }
}

/// Refresh of a stored active flag. [statusTo] is set only when it moves
/// between Watch and open.
typedef DssFlagUpdate = ({
  String id,
  Map<String, dynamic> row,
  DssFlagStatus from,
  DssFlagStatus? statusTo,
  DssEvaluationEvent event,
});

/// An open or Watch flag replaced by a newer wave of the same finding.
typedef DssFlagSupersede = ({
  String id,
  String findingKey,
  DssFlagStatus from,
  String newerSurveyId,
});

/// A new flag to insert; its event gets the id after insert.
typedef DssFlagInsert = ({Map<String, dynamic> row, DssEvaluationEvent event});

class DssFindingPlan {
  const DssFindingPlan({
    required this.inserts,
    required this.updates,
    required this.supersedes,
    required this.events,
  });

  final List<DssFlagInsert> inserts;
  final List<DssFlagUpdate> updates;
  final List<DssFlagSupersede> supersedes;

  /// Suppressed measures (no flag written).
  final List<DssEvaluationEvent> events;
}

/// Decides what one Refresh writes. One active flag per finding: when a
/// newer wave checked the same finding, older open and Watch flags are
/// superseded and older waves are not raised again. In-progress flags are
/// never moved or superseded.
///
/// Sticky once-per-cohort rules ([isStickyOncePerCohortRule], currently
/// `TIME_TO_JOB_LONG`) are different: Q29 is a historical first-job fact, so
/// a later tracer must not reopen the same course×batch. Prior Open /
/// In progress / Closed / Superseded on another wave suppresses a new raise;
/// a prior Watch alone may still upgrade to a Finding.
class DssFindingSync {
  DssFindingSync._();

  /// Rules that should raise at most once per finding key across tracer waves
  /// (except Watch → Finding upgrades).
  static bool isStickyOncePerCohortRule(String ruleId) =>
      ruleId == 'TIME_TO_JOB_LONG';

  static String? ruleIdFromFindingKey(String findingKey) {
    final pipe = findingKey.indexOf('|');
    if (pipe <= 0) return null;
    return findingKey.substring(0, pipe);
  }

  static DssFindingPlan plan({
    required List<Map<String, dynamic>> rows,
    required Map<String, Set<String>> checked,
    required List<DssSuppressedMeasure> suppressed,
    required Map<String, DateTime> waveDates,
    required List<DssStoredFlag> stored,
  }) {
    final latest = <String, String>{};
    void consider(String key, String surveyId) {
      final date = waveDates[surveyId];
      if (date == null) return;
      final current = latest[key];
      if (current == null || date.isAfter(waveDates[current]!)) {
        latest[key] = surveyId;
      }
    }

    for (final e in checked.entries) {
      for (final s in e.value) {
        consider(e.key, s);
      }
    }
    for (final r in rows) {
      consider(keyOfRow(r), r['survey_id'].toString());
    }

    bool isOlder(String key, String surveyId) {
      final newest = latest[key];
      final date = waveDates[surveyId];
      return newest != null && date != null && waveDates[newest]!.isAfter(date);
    }

    final byWave = <String, List<DssStoredFlag>>{};
    final byKey = <String, List<DssStoredFlag>>{};
    for (final f in stored) {
      byWave.putIfAbsent('${f.findingKey}@${f.surveyId}', () => []).add(f);
      byKey.putIfAbsent(f.findingKey, () => []).add(f);
    }

    final inserts = <DssFlagInsert>[];
    final updates = <DssFlagUpdate>[];
    final events = <DssEvaluationEvent>[];
    // Sticky keys that kept an older Open/In progress instead of re-raising.
    final stickyHeldKeys = <String>{};

    for (final row in rows) {
      final key = keyOfRow(row);
      final surveyId = row['survey_id'].toString();
      final ruleId = row['rule_id']?.toString() ?? '';
      final sticky = isStickyOncePerCohortRule(ruleId);
      final older = isOlder(key, surveyId);
      final here = byWave['$key@$surveyId'] ?? const <DssStoredFlag>[];
      final active = here.where((f) => _isActive(f.status)).firstOrNull;
      final desired = DssFlagStatusX.fromDb(row['status']?.toString());
      DssEvaluationEvent event(String outcome, String reason, {String? id}) =>
          DssEvaluationEvent(
            findingKey: key,
            surveyId: surveyId,
            outcome: outcome,
            reason: reason,
            flagId: id,
            validAnswers: (row['sample_n'] as num?)?.toInt(),
          );

      if (active != null) {
        if (active.status == DssFlagStatus.inProgress) {
          updates.add((
            id: active.id,
            row: row,
            from: active.status,
            statusTo: null,
            event: event('updated', 'refreshed', id: active.id),
          ));
        } else if (!older) {
          final moves = active.status != desired;
          updates.add((
            id: active.id,
            row: row,
            from: active.status,
            statusTo: moves ? desired : null,
            event: event(
              'updated',
              !moves
                  ? 'refreshed'
                  : desired == DssFlagStatus.watch
                  ? 'became_watch'
                  : 'became_finding',
              id: active.id,
            ),
          ));
        }
        continue;
      }
      if (older) {
        events.add(event('suppressed', 'newer_wave'));
      } else if (here.any((f) => f.status == DssFlagStatus.superseded)) {
        events.add(event('suppressed', 'superseded_in_wave'));
      } else if (here.isNotEmpty) {
        events.add(event('suppressed', 'closed_in_wave'));
      } else if (sticky &&
          _stickyPriorBlocksRaise(
            prior: byKey[key] ?? const [],
            currentSurveyId: surveyId,
            desired: desired,
          )) {
        stickyHeldKeys.add(key);
        events.add(event('suppressed', 'sticky_prior_finding'));
      } else {
        inserts.add((
          row: row,
          event: event(
            'raised',
            row['rule_id'] == 'DATA_QUALITY_LOW'
                ? 'data_quality'
                : desired == DssFlagStatus.watch
                ? 'watch'
                : 'finding',
          ),
        ));
      }
    }

    for (final s in suppressed) {
      events.add(
        DssEvaluationEvent(
          findingKey: s.findingKey,
          surveyId: s.surveyId,
          outcome: 'suppressed',
          reason: 'not_enough_data',
          validAnswers: s.validAnswers,
        ),
      );
    }

    final supersedes = <DssFlagSupersede>[
      for (final f in stored)
        if ((f.status == DssFlagStatus.open ||
                f.status == DssFlagStatus.watch) &&
            isOlder(f.findingKey, f.surveyId) &&
            !_stickyBlocksSupersede(
              findingKey: f.findingKey,
              from: f.status,
              stickyHeldKeys: stickyHeldKeys,
              inserts: inserts,
            ))
          (
            id: f.id,
            findingKey: f.findingKey,
            from: f.status,
            newerSurveyId: latest[f.findingKey]!,
          ),
    ];

    return DssFindingPlan(
      inserts: inserts,
      updates: updates,
      supersedes: supersedes,
      events: events,
    );
  }

  /// Prior flags on other waves that should block a new sticky raise.
  /// Watch-only priors still allow a Finding upgrade on a later wave.
  static bool _stickyPriorBlocksRaise({
    required List<DssStoredFlag> prior,
    required String currentSurveyId,
    required DssFlagStatus desired,
  }) {
    final other = prior.where((f) => f.surveyId != currentSurveyId).toList();
    if (other.isEmpty) return false;

    final hasBlocking = other.any(
      (f) =>
          f.status == DssFlagStatus.open ||
          f.status == DssFlagStatus.inProgress ||
          f.status == DssFlagStatus.resolved ||
          f.status == DssFlagStatus.dismissed ||
          f.status == DssFlagStatus.superseded,
    );
    if (hasBlocking) return true;

    // Only Watch (or other non-blocking) on prior waves: allow Finding raise.
    final onlyWatch = other.every((f) => f.status == DssFlagStatus.watch);
    if (onlyWatch && desired == DssFlagStatus.open) return false;
    // Prior Watch + desired Watch: no need to re-raise.
    return onlyWatch;
  }

  /// Sticky Open/In progress should stay the active work item; do not
  /// supersede them when the newer wave was only suppressed. Watch may still
  /// be superseded when a Finding is raised on a later wave.
  static bool _stickyBlocksSupersede({
    required String findingKey,
    required DssFlagStatus from,
    required Set<String> stickyHeldKeys,
    required List<DssFlagInsert> inserts,
  }) {
    final ruleId = ruleIdFromFindingKey(findingKey);
    if (ruleId == null || !isStickyOncePerCohortRule(ruleId)) return false;
    if (stickyHeldKeys.contains(findingKey)) {
      // Newer wave suppressed: keep older Open; Watch can stay too.
      return true;
    }
    final raisedOnNewer = inserts.any(
      (i) => keyOfRow(i.row) == findingKey,
    );
    // Watch → Finding upgrade on newer wave: allow supersede of Watch.
    if (from == DssFlagStatus.watch && raisedOnNewer) return false;
    // Sticky Open without a newer insert: do not clear it away.
    return from == DssFlagStatus.open;
  }

  static String keyOfRow(Map<String, dynamic> row) => dssFindingKey(
    row['rule_id'].toString(),
    (row['cohort_level'] ?? 'batch').toString(),
    (row['course'] ?? '').toString(),
    (row['batch_year'] ?? '').toString(),
  );

  static bool _isActive(DssFlagStatus s) =>
      s == DssFlagStatus.open ||
      s == DssFlagStatus.inProgress ||
      s == DssFlagStatus.watch;
}
