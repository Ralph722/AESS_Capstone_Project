import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_columns.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

/// One submitted CHED GTS response with every answer, personal items
/// included (admins only).
class GtsListResponse {
  const GtsListResponse({
    required this.userId,
    required this.surveyId,
    required this.answers,
    this.responseId = '',
    this.submittedAt,
  });

  final String userId;
  final String surveyId;
  final String responseId;
  final DateTime? submittedAt;
  final Map<String, dynamic> answers;

  bool isLaterThan(GtsListResponse other) {
    final a = submittedAt;
    final b = other.submittedAt;
    if (a != null && b != null && a != b) return a.isAfter(b);
    if (a != null && b == null) return true;
    if (a == null && b != null) return false;
    return responseId.compareTo(other.responseId) > 0;
  }
}

/// One alumnus in the list: a roster record, an off-roster responder, or
/// both a roster record and their answer.
class GtsListRow {
  const GtsListRow({required this.status, this.member, this.response});

  /// Null for [GtsTracerStatus.offRoster].
  final AlumniMember? member;

  /// Null for untracked alumni.
  final GtsListResponse? response;
  final GtsTracerStatus status;

  String get name {
    final m = member;
    if (m != null) return m.fullName.trim();
    return DssMetrics.single(response?.answers['ched_1']) ?? '';
  }

  /// Roster course; empty when not recorded or off the roster.
  String get course => member?.course.trim() ?? '';

  /// Roster batch, else year graduated (as the Tracer tab batch filter);
  /// "Batch not recorded" when both are missing.
  String get batch {
    final m = member;
    if (m == null) return '';
    final b = _rosterBatch(m);
    return b.isEmpty ? DssPolicy.batchNotRecorded : b;
  }

  static String _rosterBatch(AlumniMember m) {
    final b = m.batchYear.trim();
    return b.isNotEmpty ? b : (m.yearGraduated ?? '').trim();
  }

  /// The answer as the report engine reads it; null when untracked.
  GtsRespondent? get respondent {
    final r = response;
    if (r == null) return null;
    return GtsRespondent(
      userId: r.userId,
      surveyId: r.surveyId,
      answers: r.answers,
      course: course,
      yearGraduated: switch (member) {
        final m? => _rosterBatch(m),
        null => '',
      },
      onActiveRoster: member != null,
    );
  }
}

/// Tracer status counts for a set of rows.
class GtsListTally {
  GtsListTally(Iterable<GtsListRow> rows)
    : counts = {for (final s in GtsTracerStatus.values) s: 0} {
    for (final r in rows) {
      counts[r.status] = counts[r.status]! + 1;
      if (r.status.onRoster &&
          DssMetrics.single(r.response?.answers['ched_16']) != null) {
        _answeredItem16++;
      }
    }
  }

  final Map<GtsTracerStatus, int> counts;
  var _answeredItem16 = 0;

  int count(GtsTracerStatus status) => counts[status]!;

  /// Alumni on the active roster in scope.
  int get total => [
    for (final s in GtsTracerStatus.values)
      if (s.onRoster) count(s),
  ].fold(0, (a, b) => a + b);

  /// Roster alumni who submitted the tracer in scope.
  int get answered => [
    for (final s in GtsTracerStatus.values)
      if (s.onRoster && s.answered) count(s),
  ].fold(0, (a, b) => a + b);

  /// Roster alumni with any item 16 answer (the DSS and Tracer tab base).
  int get answeredItem16 => _answeredItem16;

  /// Share of [total]; null when there is nobody, or for off-roster
  /// responders (outside the total).
  double? share(GtsTracerStatus status) =>
      total == 0 || !status.onRoster ? null : count(status) / total;

  /// Answered ÷ total (the Tracer tab "took tracer" share of the roster).
  double? get responseRate => total == 0 ? null : answered / total;

  /// Employed ÷ answered item 16 (the Tracer tab employment rate).
  double? get employmentRate => answeredItem16 == 0
      ? null
      : count(GtsTracerStatus.employed) / answeredItem16;

  /// Lines to print: the five main statuses always, the others when used.
  List<GtsTracerStatus> get lines => [
    for (final s in GtsTracerStatus.values)
      if (count(s) > 0 ||
          (s != GtsTracerStatus.statusNotGiven &&
              s != GtsTracerStatus.offRoster))
        s,
  ];
}

/// Rows of one batch or course with their subtotal.
class GtsListGroup {
  GtsListGroup(this.label, this.rows) : tally = GtsListTally(rows);

  final String label;
  final List<GtsListRow> rows;
  final GtsListTally tally;
}

class GtsAlumniListResult {
  const GtsAlumniListResult({
    required this.config,
    required this.rows,
    required this.tally,
    required this.groups,
    required this.generatedAt,
    this.waveLabels = const {},
  });

  final GtsListConfig config;

  /// Sorted rows after filters; off-roster responders last.
  final List<GtsListRow> rows;
  final GtsListTally tally;

  /// Subtotal groups; empty when [GtsListConfig.subtotalBy] is none.
  /// Off-roster responders belong to no group.
  final List<GtsListGroup> groups;
  final DateTime generatedAt;
  final Map<String, String> waveLabels;

  String waveLabel(String surveyId) => waveLabels[surveyId] ?? surveyId;
}

/// Builds an alumni list: every alumnus on the active roster, with their
/// answer to the wave in scope (or their latest from any wave), and anyone
/// who answered without an active roster record.
abstract final class GtsAlumniList {
  /// [waveIds] are the CHED waves that may be used (published or closed);
  /// responses to other surveys are ignored.
  static GtsAlumniListResult build(
    GtsListConfig config, {
    required Iterable<AlumniMember> roster,
    required Iterable<GtsListResponse> responses,
    required Iterable<String> waveIds,
    Map<String, String> waveLabels = const {},
    DateTime? now,
  }) {
    final allowed = waveIds.toSet();
    final latest = <String, GtsListResponse>{};
    for (final r in responses) {
      final uid = r.userId.trim();
      if (uid.isEmpty || !allowed.contains(r.surveyId)) continue;
      if (config.surveyId != null && r.surveyId != config.surveyId) continue;
      final previous = latest[uid];
      if (previous == null || r.isLaterThan(previous)) latest[uid] = r;
    }

    final rows = <GtsListRow>[];
    final linked = <String>{};
    for (final m in roster) {
      if (m.isDeactivated) continue;
      final uid = (m.authUid ?? '').trim();
      final response = uid.isEmpty ? null : latest[uid];
      if (response != null) linked.add(uid);
      rows.add(
        GtsListRow(
          member: m,
          response: response,
          status: response != null
              ? statusOf(response.answers)
              : m.isRegisteredUser
              ? GtsTracerStatus.untrackedRegistered
              : GtsTracerStatus.untrackedNotRegistered,
        ),
      );
    }
    for (final entry in latest.entries) {
      if (linked.contains(entry.key)) continue;
      rows.add(
        GtsListRow(response: entry.value, status: GtsTracerStatus.offRoster),
      );
    }

    final sortColumn = switch (config.sortBy) {
      final key? => GtsListColumns.byKey(key),
      null => null,
    };
    final kept = rows.where((r) => _matches(config, r)).toList()
      ..sort((a, b) => _compare(config, sortColumn, waveLabels, a, b));

    final groups = <GtsListGroup>[];
    if (config.subtotalBy != GtsListSubtotal.none) {
      final byLabel = <String, List<GtsListRow>>{};
      for (final r in kept) {
        if (r.member == null) continue;
        final label = config.subtotalBy == GtsListSubtotal.batch
            ? r.batch
            : (r.course.isEmpty ? gtsUnknownLabel : r.course);
        (byLabel[label] ??= []).add(r);
      }
      final labels = byLabel.keys.toList()
        ..sort(
          config.subtotalBy == GtsListSubtotal.batch
              ? _compareBatch
              : (a, b) {
                  if (a == gtsUnknownLabel) return 1;
                  if (b == gtsUnknownLabel) return -1;
                  return a.toLowerCase().compareTo(b.toLowerCase());
                },
        );
      for (final label in labels) {
        groups.add(GtsListGroup(label, byLabel[label]!));
      }
    }

    return GtsAlumniListResult(
      config: config,
      rows: kept,
      tally: GtsListTally(kept),
      groups: groups,
      generatedAt: now ?? DateTime.now(),
      waveLabels: waveLabels,
    );
  }

  /// Tracer status from a submitted answer (item 16, read as the DSS does).
  static GtsTracerStatus statusOf(Map<String, dynamic> answers) =>
      switch (DssMetrics.single(answers['ched_16'])) {
        ChedGtsBuiltin.yes => GtsTracerStatus.employed,
        ChedGtsBuiltin.no => GtsTracerStatus.notEmployed,
        ChedGtsBuiltin.neverEmployed => GtsTracerStatus.neverEmployed,
        _ => GtsTracerStatus.statusNotGiven,
      };

  static String _key(String s) => s.trim().toLowerCase();

  static bool _matches(GtsListConfig config, GtsListRow row) {
    if (config.statuses.isNotEmpty && !config.statuses.contains(row.status)) {
      return false;
    }
    if (config.courses.isNotEmpty) {
      final wanted = {for (final c in config.courses) _key(c)};
      if (!wanted.contains(_key(row.course))) return false;
    }
    if (config.batches.isNotEmpty) {
      final wanted = {for (final b in config.batches) _key(b)};
      if (row.member == null || !wanted.contains(_key(row.batch))) {
        return false;
      }
    }
    if (config.answerFilters.isNotEmpty) {
      final respondent = row.respondent;
      if (respondent == null) return false;
      for (final f in config.answerFilters) {
        final field = GtsFieldDictionary.byKey(f.field);
        if (field == null) return false;
        final answer = GtsStats.read(field, respondent);
        if (!answer.isAnswered || !answer.values.any(f.values.contains)) {
          return false;
        }
      }
    }
    return true;
  }

  static int _compare(
    GtsListConfig config,
    GtsListColumn? sortColumn,
    Map<String, String> waveLabels,
    GtsListRow a,
    GtsListRow b,
  ) {
    final offRoster = (a.member == null ? 1 : 0) - (b.member == null ? 1 : 0);
    if (offRoster != 0) return offRoster;
    int byName() => _key(a.name).compareTo(_key(b.name));
    int byBatch() => _compareBatch(a.batch, b.batch);
    int by(int Function() primary) {
      final c = primary();
      return config.sortDescending ? -c : c;
    }

    final c = switch (config.sortBy) {
      GtsListConfig.nameColumn => by(byName),
      GtsListConfig.courseColumn => by(
        () => _key(a.course).compareTo(_key(b.course)),
      ),
      GtsListConfig.statusColumn => by(
        () => a.status.index.compareTo(b.status.index),
      ),
      GtsListConfig.batchColumn || null => by(byBatch),
      _ when sortColumn != null => _compareCells(
        GtsListColumns.cell(sortColumn, a, waveLabels: waveLabels),
        GtsListColumns.cell(sortColumn, b, waveLabels: waveLabels),
        config.sortDescending,
      ),
      _ => by(byBatch),
    };
    if (c != 0) return c;
    final batch = byBatch();
    if (batch != 0) return batch;
    return byName();
  }

  /// Blank and "Not asked" cells last in either direction; numbers by value.
  static int _compareCells(String a, String b, bool descending) {
    bool empty(String s) => s.isEmpty || s == gtsNotAskedLabel;
    if (empty(a) || empty(b)) return (empty(a) ? 1 : 0) - (empty(b) ? 1 : 0);
    final na = num.tryParse(a);
    final nb = num.tryParse(b);
    final c = na != null && nb != null
        ? na.compareTo(nb)
        : a.toLowerCase().compareTo(b.toLowerCase());
    return descending ? -c : c;
  }

  /// Numeric years first, then other text; "Batch not recorded" last.
  static int _compareBatch(String a, String b) {
    if (a == b) return 0;
    if (a == DssPolicy.batchNotRecorded) return 1;
    if (b == DssPolicy.batchNotRecorded) return -1;
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}
