import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/application/dss_finding_sync.dart';
import 'package:alumni_system/features/admin/dss/application/dss_history.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

class DssRepository {
  DssRepository({SupabaseClient? supabase, AuditService? auditService})
    : _supabase = supabase ?? Supabase.instance.client,
      _audit = auditService ?? AuditService();

  final SupabaseClient _supabase;
  final AuditService _audit;

  static const _flagSelect =
      '*, dss_rules(name, severity, playbook, recommended_action, operator, min_n, category), '
      'dss_flag_checks(state, metric_value, sample_n, checked_at, recovered_since)';

  Future<List<DssRule>> listRules() async {
    final rows = await _supabase
        .from('dss_rules')
        .select()
        .order('sort_order', ascending: true);
    return rows.map(DssRule.fromSupabaseRow).toList();
  }

  Future<void> updateRule(DssRule rule) async {
    await _supabase
        .from('dss_rules')
        .update({
          'threshold': rule.threshold,
          'min_n': rule.minN,
          'enabled': rule.enabled,
          'recommended_action': rule.recommendedAction,
        })
        .eq('rule_id', rule.ruleId);
    await _audit.logAction(
      action: 'DSS_RULE_UPDATE',
      resource: 'dss_rules',
      resourceId: rule.ruleId,
      description: 'Updated DSS rule ${rule.ruleId}',
      changes: {
        'threshold': rule.threshold,
        'min_n': rule.minN,
        'enabled': rule.enabled,
      },
      userRole: 'admin',
    );
  }

  Future<List<DssFlag>> listFlags({
    DssFlagStatus? status,
    String? ruleId,
    String? course,
    int limit = 200,
  }) async {
    var query = _supabase.from('dss_flags').select(_flagSelect);
    if (status != null) {
      query = query.eq('status', status.dbValue);
    }
    if (ruleId != null && ruleId.isNotEmpty) {
      query = query.eq('rule_id', ruleId);
    }
    if (course != null && course.isNotEmpty) {
      query = query.eq('course', course);
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(DssFlag.fromSupabaseRow).toList();
  }

  Future<DssFlag?> getFlag(String id) async {
    final rows = await _supabase
        .from('dss_flags')
        .select(_flagSelect)
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return DssFlag.fromSupabaseRow(rows.first);
  }

  /// Notes on [flagIds], newest first, at most [limit].
  Future<List<DssFlagNote>> listNotesForFlags(
    List<String> flagIds, {
    int limit = 500,
  }) async {
    if (flagIds.isEmpty) return const [];
    final notes = <DssFlagNote>[];
    for (final ids in _chunks(flagIds)) {
      final rows = await _supabase
          .from('dss_flag_notes')
          .select()
          .inFilter('flag_id', ids)
          .order('created_at', ascending: false)
          .limit(limit);
      notes.addAll(rows.map(DssFlagNote.fromSupabaseRow));
    }
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes.take(limit).toList();
  }

  /// Keeps `in (...)` filters short enough for a request URL.
  static Iterable<List<String>> _chunks(List<String> ids, [int size = 100]) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, min(i + size, ids.length));
    }
  }

  /// Reads up to [max] rows, [page] at a time (the API caps each request).
  static Future<List<Map<String, dynamic>>> _pages(
    Future<List<Map<String, dynamic>>> Function(int from, int to) fetch, {
    int page = 1000,
    int max = 10000,
  }) async {
    final out = <Map<String, dynamic>>[];
    for (var from = 0; from < max; from += page) {
      final rows = await fetch(from, min(from + page, max) - 1);
      out.addAll(rows);
      if (rows.length < page) break;
    }
    return out;
  }

  static String? _since(int? lookbackDays) => lookbackDays == null
      ? null
      : DateTime.now()
            .toUtc()
            .subtract(Duration(days: lookbackDays))
            .toIso8601String();

  Future<List<DssFlagNote>> listNotes(String flagId) async {
    final rows = await _supabase
        .from('dss_flag_notes')
        .select()
        .eq('flag_id', flagId)
        .order('created_at', ascending: false);
    return rows.map(DssFlagNote.fromSupabaseRow).toList();
  }

  Future<DssFlag> updateFlagStatus({
    required DssFlag flag,
    required DssFlagStatus status,
    String note = '',
    String? interventionType,
    String? interventionDetail,
    double? followupValue,
    int? followupSampleN,
    String? impactVerdict,
    DateTime? verifyDueAt,
    bool clearResolvedAt = false,
  }) async {
    final trimmed = note.trim();
    try {
      await _supabase.rpc(
        'dss_update_flag_status',
        params: {
          'p_flag_id': flag.id,
          'p_status': status.dbValue,
          'p_note': trimmed,
          'p_intervention_type': interventionType,
          'p_intervention_detail': interventionDetail,
          'p_followup_value': followupValue,
          'p_followup_sample_n': followupSampleN,
          'p_impact_verdict': impactVerdict,
          'p_verify_due_at': verifyDueAt?.toUtc().toIso8601String(),
          'p_clear_resolved_at': clearResolvedAt,
        },
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
    if (status == DssFlagStatus.inProgress &&
        flag.status == DssFlagStatus.open) {
      await _fillStartDate(flag);
    }

    await _audit.logAction(
      action: 'DSS_FLAG_STATUS',
      resource: 'dss_flags',
      resourceId: flag.id,
      description:
          'DSS flag ${flag.ruleId} → ${status.label} (${flag.cohortLabel})',
      changes: {
        'from': flag.status.dbValue,
        'to': status.dbValue,
        if (trimmed.isNotEmpty) 'note': trimmed,
        if (interventionType != null) 'intervention': interventionType,
        if (impactVerdict != null) 'impact': impactVerdict,
      },
      userRole: 'admin',
    );

    return (await getFlag(flag.id)) ?? flag;
  }

  Future<DssFlag> recordImpactRecheck({
    required DssFlag flag,
    required double? followupValue,
    required int followupSampleN,
    required String impactVerdict,
    DateTime? nextVerifyDueAt,
  }) async {
    final user = AppSession.currentUser;
    final now = DateTime.now().toUtc().toIso8601String();
    await _supabase
        .from('dss_flags')
        .update({
          'followup_value': followupValue,
          'followup_sample_n': followupSampleN,
          'followup_at': now,
          'impact_verdict': impactVerdict,
          'verify_due_at': nextVerifyDueAt?.toUtc().toIso8601String(),
          'updated_by': user?.id,
          'updated_at': now,
        })
        .eq('id', flag.id);

    await _insertNote(
      flagId: flag.id,
      note:
          'Coverage re-check: $impactVerdict'
          '${followupValue == null ? '' : ' (metric ${followupValue.toStringAsFixed(3)})'}',
      statusFrom: flag.status.dbValue,
      statusTo: flag.status.dbValue,
      eventType: DssNoteEventType.impact,
      metadata: {
        'impact_verdict': impactVerdict,
        if (followupValue != null) 'followup_value': followupValue,
        'followup_sample_n': followupSampleN,
        if (flag.baselineValue != null) 'baseline_value': flag.baselineValue,
      },
    );

    await _audit.logAction(
      action: 'DSS_FLAG_IMPACT',
      resource: 'dss_flags',
      resourceId: flag.id,
      description: 'DSS impact recheck ${flag.ruleId} → $impactVerdict',
      changes: {
        'impact_verdict': impactVerdict,
        'followup_value': followupValue,
        'followup_sample_n': followupSampleN,
      },
      userRole: 'admin',
    );

    return (await getFlag(flag.id)) ?? flag;
  }

  Future<void> linkAnnouncement({
    required String flagId,
    required String announcementId,
  }) async {
    await _supabase
        .from('dss_flags')
        .update({
          'linked_announcement_id': announcementId,
          'updated_by': AppSession.currentUser?.id,
        })
        .eq('id', flagId);
  }

  Future<void> addNote({
    required String flagId,
    required String note,
    DssNoteEventType eventType = DssNoteEventType.note,
    Map<String, dynamic> metadata = const {},
  }) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    await _insertNote(
      flagId: flagId,
      note: trimmed,
      eventType: eventType,
      metadata: metadata,
    );
  }

  Future<void> _insertNote({
    required String flagId,
    required String note,
    String? statusFrom,
    String? statusTo,
    DssNoteEventType eventType = DssNoteEventType.note,
    Map<String, dynamic> metadata = const {},
  }) async {
    final user = AppSession.currentUser;
    await _supabase.from('dss_flag_notes').insert({
      'flag_id': flagId,
      'author_id': user?.id,
      'author_name':
          (user?.userMetadata?['display_name'] as String?) ??
          user?.email ??
          'Admin',
      'note': note,
      'status_from': statusFrom,
      'status_to': statusTo,
      'event_type': eventType.dbValue,
      'metadata': metadata,
    });
  }

  /// Server-side one-click action (`survey_reminder` or `job_matches`).
  /// Sends notifications, logs the action on the flag and moves it to
  /// in_progress. Returns how many notifications were actually sent.
  Future<DssActionResult> runFlagAction({
    required String flagId,
    required String action,
    required List<String> userIds,
    List<String> jobIds = const [],
  }) async {
    final res = await _supabase.rpc(
      'dss_run_flag_action',
      params: {
        'p_flag_id': flagId,
        'p_action': action,
        'p_user_ids': userIds,
        'p_job_ids': jobIds,
      },
    );
    final flag = await getFlag(flagId);
    if (flag != null) await _fillStartDate(flag);
    final map = res is Map ? Map<String, dynamic>.from(res) : const {};
    int read(String k) => (map[k] as num?)?.toInt() ?? 0;
    return DssActionResult(
      selected: read('selected'),
      eligible: read('eligible'),
      sent: read('sent'),
      jobs: read('jobs'),
    );
  }

  /// Roster counts saved while each wave was open. Empty when the snapshot
  /// table is not installed yet (rates then use the current roster).
  Future<List<DssCohortSnapshot>> listCohortSnapshots(
    List<String> surveyIds,
  ) async {
    if (surveyIds.isEmpty) return const [];
    try {
      final rows = await _supabase
          .from('dss_wave_cohort_snapshots')
          .select()
          .inFilter('survey_id', surveyIds);
      return rows.map(DssCohortSnapshot.fromSupabaseRow).toList();
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return const [];
      rethrow;
    }
  }

  /// Saves the roster counts of waves that are still open.
  Future<void> saveCohortSnapshots(List<DssCohortSnapshot> rows) async {
    if (rows.isEmpty) return;
    try {
      await _supabase
          .from('dss_wave_cohort_snapshots')
          .upsert(
            rows.map((r) => r.toSupabaseRow()).toList(),
            onConflict: 'survey_id,course,batch_year',
          );
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return;
      rethrow;
    }
  }

  static bool _isMissingTable(PostgrestException e) =>
      e.code == 'PGRST205' || e.code == '42P01';

  /// One full Refresh on the server (`dss_evaluate_all`, DSS Phase 8):
  /// evaluates, saves flags, logs the run and saves snapshots in one
  /// transaction. Returns the run counts, or null when the function is not
  /// installed.
  Future<Map<String, dynamic>?> evaluateOnServer() async {
    try {
      final res = await _supabase.rpc(
        'dss_evaluate_all',
        params: {'p_trigger': 'manual'},
      );
      return res is Map ? Map<String, dynamic>.from(res) : null;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.code == '42883') return null;
      rethrow;
    }
  }

  bool? _findingIdentity;

  /// Whether `dss_flags.finding_key` (DSS Phase 4) is installed.
  Future<bool> _hasFindingIdentity() async {
    final known = _findingIdentity;
    if (known != null) return known;
    try {
      await _supabase.from('dss_flags').select('finding_key').limit(1);
      return _findingIdentity = true;
    } on PostgrestException catch (e) {
      if (e.code == '42703' || e.code == 'PGRST204') {
        return _findingIdentity = false;
      }
      rethrow;
    }
  }

  /// Saves one Refresh: raises, refreshes and supersedes flags as
  /// [DssFindingSync] plans, and logs every outcome. Without the Phase 4
  /// schema, falls back to one open flag per row.
  Future<DssSyncSummary> syncFindings({
    required DssEvaluation evaluation,
    required Map<String, DateTime> waveDates,
  }) async {
    if (!await _hasFindingIdentity()) {
      for (final row in evaluation.flagRows) {
        await upsertActiveFlag(row);
      }
      return DssSyncSummary(
        raised: 0,
        updated: evaluation.flagRows.length,
        superseded: 0,
        skippedNewerWave: 0,
        skippedClosed: 0,
        legacy: true,
      );
    }

    final stored = await _storedFlags(waveDates.keys.toList());
    final plan = DssFindingSync.plan(
      rows: evaluation.flagRows,
      checked: evaluation.checked,
      suppressed: evaluation.suppressed,
      waveDates: waveDates,
      stored: stored,
    );
    final user = AppSession.currentUser;
    final events = <DssEvaluationEvent>[...plan.events];
    final activeIds = <String, String>{
      for (final f in stored)
        if (!f.status.isClosed) '${f.findingKey}@${f.surveyId}': f.id,
    };

    if (plan.inserts.isNotEmpty) {
      final payload = [
        for (final i in plan.inserts)
          {
            ...i.row,
            if (i.row['evidence'] is! Map) 'evidence': <String, dynamic>{},
            'created_by': user?.id,
            'updated_by': user?.id,
          },
      ];
      final inserted = await _supabase
          .from('dss_flags')
          .insert(payload)
          .select('id, finding_key, survey_id');
      final ids = {
        for (final r in inserted)
          '${r['finding_key']}@${r['survey_id']}': r['id'].toString(),
      };
      activeIds.addAll(ids);
      for (final i in plan.inserts) {
        events.add(
          i.event.withFlag(ids['${i.event.findingKey}@${i.event.surveyId}']),
        );
      }
    }

    for (final u in plan.updates) {
      await _supabase
          .from('dss_flags')
          .update({
            ..._metricFields(u.row),
            if (u.statusTo != null) 'status': u.statusTo!.dbValue,
            'updated_by': user?.id,
          })
          .eq('id', u.id);
      if (u.statusTo != null) {
        await _insertNote(
          flagId: u.id,
          note: u.statusTo == DssFlagStatus.watch
              ? 'Moved to Watch: the latest Refresh found too few valid '
                    'answers for a finding.'
              : 'Now a finding: the latest Refresh found enough valid '
                    'answers.',
          statusFrom: u.from.dbValue,
          statusTo: u.statusTo!.dbValue,
          eventType: DssNoteEventType.status,
        );
      }
      events.add(u.event);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    for (final s in plan.supersedes) {
      final newer = activeIds['${s.findingKey}@${s.newerSurveyId}'];
      await _supabase
          .from('dss_flags')
          .update({
            'status': DssFlagStatus.superseded.dbValue,
            'superseded_at': now,
            'superseded_by': newer,
            'updated_by': user?.id,
          })
          .eq('id', s.id);
      await _insertNote(
        flagId: s.id,
        note: newer == null
            ? 'Superseded: a newer wave checked the same finding and has no '
                  'active flag for it.'
            : "Superseded by the newer wave's flag for the same finding.",
        statusFrom: s.from.dbValue,
        statusTo: DssFlagStatus.superseded.dbValue,
        eventType: DssNoteEventType.status,
        metadata: {if (newer != null) 'superseded_by': newer},
      );
      events.add(
        DssEvaluationEvent(
          findingKey: s.findingKey,
          surveyId: s.newerSurveyId,
          outcome: 'superseded',
          reason: newer == null ? 'newer_wave_clear' : 'newer_wave_raised',
          flagId: s.id,
        ),
      );
    }

    await _logEvaluationEvents(events);

    int count(String outcome, [String? reason]) => events
        .where(
          (e) => e.outcome == outcome && (reason == null || e.reason == reason),
        )
        .length;
    return DssSyncSummary(
      raised: count('raised'),
      updated: count('updated'),
      superseded: count('superseded'),
      skippedNewerWave: count('suppressed', 'newer_wave'),
      skippedClosed:
          count('suppressed', 'closed_in_wave') +
          count('suppressed', 'superseded_in_wave'),
    );
  }

  Future<List<DssStoredFlag>> _storedFlags(List<String> surveyIds) async {
    if (surveyIds.isEmpty) return const [];
    const page = 1000;
    final out = <DssStoredFlag>[];
    for (var from = 0; ; from += page) {
      final rows = await _supabase
          .from('dss_flags')
          .select('id, finding_key, survey_id, status')
          .inFilter('survey_id', surveyIds)
          .order('id')
          .range(from, from + page - 1);
      for (final r in rows) {
        out.add((
          id: r['id'].toString(),
          findingKey: r['finding_key'].toString(),
          surveyId: r['survey_id'].toString(),
          status: DssFlagStatusX.fromDb(r['status']?.toString()),
        ));
      }
      if (rows.length < page) return out;
    }
  }

  Future<void> _logEvaluationEvents(List<DssEvaluationEvent> events) async {
    if (events.isEmpty) return;
    final runId = _uuidV4();
    const chunk = 500;
    try {
      for (var i = 0; i < events.length; i += chunk) {
        await _supabase.from('dss_evaluation_events').insert([
          for (final e in events.skip(i).take(chunk))
            e.toRow(runId: runId, trigger: 'manual'),
        ]);
      }
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return;
      rethrow;
    }
  }

  static String _uuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Map<String, dynamic> _metricFields(Map<String, dynamic> row) => {
    'metric_value': row['metric_value'],
    'threshold_snapshot': row['threshold_snapshot'],
    'sample_n': row['sample_n'],
    'eligible_n': row['eligible_n'],
    'confidence': row['confidence'],
    'title': row['title'],
    'body': row['body'],
    'recommended_action': row['recommended_action'],
    'evidence': row['evidence'],
    'survey_title': row['survey_title'],
    'baseline_value': row['baseline_value'],
  };

  /// Insert a new open flag, or refresh metric fields on existing open/in_progress.
  Future<void> upsertActiveFlag(Map<String, dynamic> row) async {
    final ruleId = row['rule_id']?.toString() ?? '';
    final course = row['course']?.toString() ?? '';
    final batch = row['batch_year']?.toString() ?? '';
    final surveyId = row['survey_id']?.toString() ?? '';
    final level = row['cohort_level']?.toString() ?? 'batch';

    final existing = await _supabase
        .from('dss_flags')
        .select('id, status')
        .eq('rule_id', ruleId)
        .eq('cohort_level', level)
        .eq('course', course)
        .eq('batch_year', batch)
        .eq('survey_id', surveyId)
        .inFilter('status', ['open', 'in_progress'])
        .limit(1);

    final user = AppSession.currentUser;
    if (existing.isNotEmpty) {
      final id = existing.first['id']?.toString();
      if (id == null) return;
      await _supabase
          .from('dss_flags')
          .update({..._metricFields(row), 'updated_by': user?.id})
          .eq('id', id);
      return;
    }

    final payload = <String, dynamic>{
      ...row,
      'status': 'open',
      'created_by': user?.id,
      'updated_by': user?.id,
    };
    // evidence must be a Map for jsonb; guard against accidental strings
    final evidence = payload['evidence'];
    if (evidence is! Map) {
      payload['evidence'] = <String, dynamic>{};
    }

    await _supabase.from('dss_flags').insert(payload);
  }

  /// Flag counts for the History tab; [lookbackDays] null means all time.
  Future<DssHistoryStats> historyStats({int? lookbackDays = 365}) async {
    final since = _since(lookbackDays);
    final rows = await _pages((from, to) {
      var q = _supabase
          .from('dss_flags')
          .select(
            'rule_id, status, created_at, resolved_at, impact_verdict, '
            'baseline_value, followup_value',
          );
      if (since != null) q = q.gte('created_at', since);
      return q.order('created_at', ascending: false).range(from, to);
    });

    var raised = 0;
    var resolved = 0;
    var dismissed = 0;
    var open = 0;
    var inProgress = 0;
    var impactChecked = 0;
    var impactImproved = 0;
    var impactStillFlagged = 0;
    final resolutionDays = <double>[];
    final byMonth = <String, int>{};
    final byRule = <String, int>{};
    final impactByRule =
        <String, ({int checked, int improved, int stillFlagged})>{};

    var superseded = 0;
    for (final row in rows) {
      final status = DssFlagStatusX.fromDb(row['status']?.toString());
      if (status == DssFlagStatus.watch) continue;
      raised++;
      switch (status) {
        case DssFlagStatus.open:
          open++;
        case DssFlagStatus.inProgress:
          inProgress++;
        case DssFlagStatus.resolved:
          resolved++;
        case DssFlagStatus.dismissed:
          dismissed++;
        case DssFlagStatus.superseded:
          superseded++;
        case DssFlagStatus.watch:
          break;
      }
      final ruleId = (row['rule_id'] ?? '').toString();
      byRule[ruleId] = (byRule[ruleId] ?? 0) + 1;
      final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (created != null) {
        final key =
            '${created.year}-${created.month.toString().padLeft(2, '0')}';
        byMonth[key] = (byMonth[key] ?? 0) + 1;
      }
      final resolvedAt = DateTime.tryParse(
        row['resolved_at']?.toString() ?? '',
      );
      if (created != null &&
          resolvedAt != null &&
          (status == DssFlagStatus.resolved ||
              status == DssFlagStatus.dismissed)) {
        resolutionDays.add(resolvedAt.difference(created).inHours / 24.0);
      }

      if (status == DssFlagStatus.resolved) {
        final verdict = (row['impact_verdict'] ?? '').toString();
        if (verdict.isNotEmpty) {
          impactChecked++;
          final prev =
              impactByRule[ruleId] ??
              (checked: 0, improved: 0, stillFlagged: 0);
          var improved = prev.improved;
          var still = prev.stillFlagged;
          if (verdict == 'improved') {
            impactImproved++;
            improved++;
          } else if (verdict == 'still_flagged') {
            impactStillFlagged++;
            still++;
          }
          impactByRule[ruleId] = (
            checked: prev.checked + 1,
            improved: improved,
            stillFlagged: still,
          );
        }
      }
    }

    double? avg;
    if (resolutionDays.isNotEmpty) {
      avg = resolutionDays.reduce((a, b) => a + b) / resolutionDays.length;
    }

    double? improvedPct;
    if (impactChecked > 0) {
      improvedPct = impactImproved / impactChecked;
    }

    return DssHistoryStats(
      raised: raised,
      resolved: resolved,
      dismissed: dismissed,
      open: open,
      inProgress: inProgress,
      avgResolutionDays: avg,
      byMonth: byMonth,
      byRule: byRule,
      impactChecked: impactChecked,
      impactImproved: impactImproved,
      impactStillFlagged: impactStillFlagged,
      improvedPct: improvedPct,
      impactByRule: impactByRule,
      superseded: superseded,
    );
  }

  Future<void> assignOwner({
    required String flagId,
    required String? userId,
    String? ownerLabel,
  }) async {
    await _supabase
        .from('dss_flags')
        .update({
          'assigned_to': userId,
          'updated_by': AppSession.currentUser?.id,
        })
        .eq('id', flagId);

    await _insertNote(
      flagId: flagId,
      note: userId == null || userId.isEmpty
          ? 'Owner cleared'
          : 'Assigned to ${ownerLabel ?? 'admin'}',
      eventType: DssNoteEventType.assign,
      metadata: {
        'assigned_to': userId,
        if (ownerLabel != null) 'owner_label': ownerLabel,
      },
    );
  }

  bool? _accountability;

  /// Whether the DSS Phase 6 owner, dates and evidence schema is installed.
  Future<bool> hasAccountability() async {
    final known = _accountability;
    if (known != null) return known;
    try {
      await _supabase.from('dss_flag_evidence').select('id').limit(1);
      return _accountability = true;
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return _accountability = false;
      rethrow;
    }
  }

  /// Saves the owner office, responsible person and dates, and logs what
  /// changed on the flag.
  Future<DssFlag> updateAccountability({
    required DssFlag flag,
    String? ownerOffice,
    String? responsibleName,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? reviewDate,
  }) async {
    String? clean(String? s) {
      final t = s?.trim();
      return t == null || t.isEmpty ? null : t;
    }

    String? day(DateTime? d) => d == null ? null : dssDateValue(d);

    final row = {
      'owner_office': clean(ownerOffice),
      'responsible_name': clean(responsibleName),
      'start_date': day(startDate),
      'due_date': day(dueDate),
      'review_date': day(reviewDate),
    };
    final before = {
      'owner_office': flag.ownerOffice,
      'responsible_name': flag.responsibleName,
      'start_date': day(flag.startDate),
      'due_date': day(flag.dueDate),
      'review_date': day(flag.reviewDate),
    };
    const labels = {
      'owner_office': 'Office',
      'responsible_name': 'Responsible',
      'start_date': 'Start',
      'due_date': 'Due',
      'review_date': 'Next review',
    };
    final changes = [
      for (final key in labels.keys)
        if (row[key] != before[key])
          row[key] == null
              ? '${labels[key]} cleared'
              : '${labels[key]}: ${row[key]}',
    ];
    if (changes.isEmpty) return flag;

    try {
      await _supabase
          .from('dss_flags')
          .update({...row, 'updated_by': AppSession.currentUser?.id})
          .eq('id', flag.id);
    } on PostgrestException catch (e) {
      throw Exception(_accountabilityError(e));
    }

    await _insertNote(
      flagId: flag.id,
      note: 'Plan updated. ${changes.join('; ')}.',
      eventType: DssNoteEventType.assign,
      metadata: row,
    );
    await _audit.logAction(
      action: 'DSS_FLAG_PLAN',
      resource: 'dss_flags',
      resourceId: flag.id,
      description: 'DSS flag ${flag.ruleId} plan updated (${flag.cohortLabel})',
      changes: {'from': before, 'to': row},
      userRole: 'admin',
    );
    return (await getFlag(flag.id)) ?? flag;
  }

  /// Fills in today as the start date when work starts, unless one is set
  /// or today is already past the due or review date.
  Future<void> _fillStartDate(DssFlag flag) async {
    if (flag.startDate != null || !await hasAccountability()) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = flag.dueDate;
    final review = flag.reviewDate;
    if ((due != null && due.isBefore(today)) ||
        (review != null && review.isBefore(today))) {
      return;
    }
    try {
      await _supabase
          .from('dss_flags')
          .update({'start_date': dssDateValue(today)})
          .eq('id', flag.id)
          .isFilter('start_date', null);
    } on PostgrestException catch (_) {
      // The start date is a convenience; the status change already saved.
    }
  }

  /// Evidence entries that have not been removed, newest first.
  Future<List<DssFlagEvidence>> listEvidence(String flagId) async {
    try {
      final rows = await _supabase
          .from('dss_flag_evidence')
          .select()
          .eq('flag_id', flagId)
          .isFilter('removed_at', null)
          .order('evidence_date', ascending: false)
          .order('created_at', ascending: false);
      return rows.map(DssFlagEvidence.fromSupabaseRow).toList();
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return const [];
      rethrow;
    }
  }

  /// Adds an evidence entry; the server stamps the author and logs it on
  /// the flag.
  Future<void> addEvidence({
    required DssFlag flag,
    required DssEvidenceType type,
    required String title,
    required DateTime date,
    String description = '',
    String? link,
  }) async {
    final cleanLink = link?.trim();
    try {
      await _supabase.from('dss_flag_evidence').insert({
        'flag_id': flag.id,
        'evidence_type': type.dbValue,
        'title': title.trim(),
        'evidence_date': dssDateValue(date),
        'description': description.trim(),
        'link': cleanLink == null || cleanLink.isEmpty ? null : cleanLink,
      });
    } on PostgrestException catch (e) {
      throw Exception(_accountabilityError(e));
    }
    await _audit.logAction(
      action: 'DSS_FLAG_EVIDENCE',
      resource: 'dss_flags',
      resourceId: flag.id,
      description:
          'DSS flag ${flag.ruleId} evidence added: ${type.label} '
          '(${flag.cohortLabel})',
      changes: {
        'evidence_type': type.dbValue,
        'evidence_date': dssDateValue(date),
      },
      userRole: 'admin',
    );
  }

  /// Hides an evidence entry. The row stays, with who removed it and when.
  Future<void> removeEvidence({
    required DssFlag flag,
    required DssFlagEvidence entry,
  }) async {
    try {
      await _supabase
          .from('dss_flag_evidence')
          .update({'removed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', entry.id);
    } on PostgrestException catch (e) {
      throw Exception(_accountabilityError(e));
    }
    await _audit.logAction(
      action: 'DSS_FLAG_EVIDENCE_REMOVED',
      resource: 'dss_flags',
      resourceId: flag.id,
      description:
          'DSS flag ${flag.ruleId} evidence removed: ${entry.type.label} '
          '(${flag.cohortLabel})',
      changes: {'evidence_id': entry.id},
      userRole: 'admin',
    );
  }

  static String _accountabilityError(PostgrestException e) {
    final m = e.message;
    if (m.contains('dss_flags_plan_dates_check')) {
      return 'The due and review dates cannot be before the start date.';
    }
    if (m.contains('dss_flags_owner_office_check') ||
        m.contains('dss_flags_responsible_name_check')) {
      return 'Office and person names can be at most 120 characters.';
    }
    if (m.contains('dss_flag_evidence_link_check')) {
      return 'The link must start with http:// or https://.';
    }
    if (m.contains('dss_flag_evidence_title_check')) {
      return 'Give the evidence a title (at most 200 characters).';
    }
    if (m.contains('dss_flag_evidence_description_check')) {
      return 'The description can be at most 2000 characters.';
    }
    return m;
  }

  bool? _outcomes;

  /// Whether the DSS Phase 7 interventions schema is installed.
  Future<bool> hasOutcomes() async {
    final known = _outcomes;
    if (known != null) return known;
    try {
      await _supabase.from('dss_interventions').select('id').limit(1);
      return _outcomes = true;
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return _outcomes = false;
      rethrow;
    }
  }

  /// Every intervention on a finding (all waves), newest first.
  Future<List<DssIntervention>> listInterventions(String findingKey) async {
    try {
      final rows = await _supabase
          .from('dss_interventions')
          .select()
          .eq('finding_key', findingKey)
          .order('created_at', ascending: false);
      return rows.map(DssIntervention.fromSupabaseRow).toList();
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return const [];
      rethrow;
    }
  }

  /// Interventions recorded in the last [lookbackDays] (null: all time),
  /// newest first. Empty without the Phase 7 schema.
  Future<List<DssIntervention>> listRecentInterventions({
    int? lookbackDays = 365,
  }) async {
    final since = _since(lookbackDays);
    try {
      final rows = await _pages((from, to) {
        var q = _supabase.from('dss_interventions').select();
        if (since != null) q = q.gte('created_at', since);
        return q.order('created_at', ascending: false).range(from, to);
      });
      return rows.map(DssIntervention.fromSupabaseRow).toList();
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return const [];
      rethrow;
    }
  }

  /// Interventions on [flagIds], newest first. Empty without the Phase 7
  /// schema.
  Future<List<DssIntervention>> listInterventionsForFlags(
    List<String> flagIds,
  ) async {
    if (flagIds.isEmpty) return const [];
    final out = <DssIntervention>[];
    try {
      for (final ids in _chunks(flagIds)) {
        final rows = await _supabase
            .from('dss_interventions')
            .select()
            .inFilter('flag_id', ids);
        out.addAll(rows.map(DssIntervention.fromSupabaseRow));
      }
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return const [];
      rethrow;
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// The latest [limit] evaluation runs (Refresh and nightly), newest
  /// first. Empty without the Phase 4 run log.
  Future<List<DssEvaluationRun>> listEvaluationRuns({int limit = 20}) async {
    try {
      final rows = <Map<String, dynamic>>[];
      final runs = <String>{};
      const page = 1000;
      for (var from = 0; from < 20000; from += page) {
        final batch = await _supabase
            .from('dss_evaluation_events')
            .select('run_id, run_trigger, outcome, reason, created_at')
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .range(from, from + page - 1);
        rows.addAll(batch);
        runs.addAll(batch.map((r) => (r['run_id'] ?? '').toString()));
        // One more run than needed means every kept run is complete.
        if (batch.length < page || runs.length > limit) break;
      }
      return DssEvaluationRun.fromEvents(rows, limit: limit);
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) return const [];
      rethrow;
    }
  }

  /// Records an intervention. The server sets the success metric, operator,
  /// baseline and author; [successTarget] null means the rule's default.
  Future<void> recordIntervention({
    required DssFlag flag,
    required String interventionType,
    String description = '',
    String expectedOutcome = '',
    double? successTarget,
    DateTime? startedOn,
  }) async {
    try {
      await _supabase.from('dss_interventions').insert({
        'flag_id': flag.id,
        'intervention_type': interventionType.trim(),
        'description': description.trim(),
        'expected_outcome': expectedOutcome.trim(),
        'success_target': ?successTarget,
        if (startedOn != null) 'started_on': dssDateValue(startedOn),
      });
    } on PostgrestException catch (e) {
      throw Exception(_outcomeError(e));
    }
    await _audit.logAction(
      action: 'DSS_INTERVENTION',
      resource: 'dss_flags',
      resourceId: flag.id,
      description:
          'DSS flag ${flag.ruleId} intervention recorded: $interventionType '
          '(${flag.cohortLabel})',
      changes: {
        'intervention_type': interventionType.trim(),
        'success_target': ?successTarget,
      },
      userRole: 'admin',
    );
  }

  /// Changes the plan of an intervention whose outcome is not known yet.
  Future<void> updateInterventionPlan({
    required DssIntervention intervention,
    required String interventionType,
    required String description,
    required String expectedOutcome,
    required double successTarget,
    required DateTime startedOn,
  }) async {
    try {
      await _supabase
          .from('dss_interventions')
          .update({
            'intervention_type': interventionType.trim(),
            'description': description.trim(),
            'expected_outcome': expectedOutcome.trim(),
            'success_target': successTarget,
            'started_on': dssDateValue(startedOn),
          })
          .eq('id', intervention.id);
    } on PostgrestException catch (e) {
      throw Exception(_outcomeError(e));
    }
  }

  /// Judges the outcome from the next tracer wave (server rules only).
  Future<DssOutcomeCheck> evaluateIntervention(String interventionId) async {
    try {
      final res = await _supabase.rpc(
        'dss_evaluate_intervention',
        params: {'p_id': interventionId},
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : const {};
      return DssOutcomeCheck.fromJson(Map<String, dynamic>.from(map));
    } on PostgrestException catch (e) {
      throw Exception(_outcomeError(e));
    }
  }

  /// Records the decision after an outcome. Returns the new intervention's
  /// id for Continue and Modify.
  Future<String?> decideIntervention({
    required DssFlag flag,
    required DssIntervention intervention,
    required DssOutcomeDecision decision,
    required String note,
    String? office,
    String? interventionType,
    String? description,
    String? expectedOutcome,
    double? successTarget,
  }) async {
    final Object? res;
    try {
      res = await _supabase.rpc(
        'dss_decide_intervention',
        params: {
          'p_id': intervention.id,
          'p_decision': decision.dbValue,
          'p_note': note.trim(),
          'p_office': office,
          'p_intervention_type': interventionType,
          'p_description': description,
          'p_expected_outcome': expectedOutcome,
          'p_success_target': successTarget,
        },
      );
    } on PostgrestException catch (e) {
      throw Exception(_outcomeError(e));
    }
    await _audit.logAction(
      action: 'DSS_INTERVENTION_DECISION',
      resource: 'dss_flags',
      resourceId: flag.id,
      description:
          'DSS flag ${flag.ruleId} outcome decision: ${decision.label} '
          '(${flag.cohortLabel})',
      changes: {
        'intervention_id': intervention.id,
        'outcome': intervention.outcomeStatus.dbValue,
        'decision': decision.dbValue,
        'escalated_to': ?office,
      },
      userRole: 'admin',
    );
    final id = res?.toString() ?? '';
    return id.isEmpty ? null : id;
  }

  static String _outcomeError(PostgrestException e) {
    final m = e.message;
    if (m.contains('uq_dss_interventions_undecided_finding')) {
      return 'This finding already has an intervention waiting for its '
          'outcome. Record a decision on it first.';
    }
    if (m.contains('dss_interventions_target_check')) {
      return 'The target must be between 0% and 100% (or -10 to 10 salary '
          'brackets).';
    }
    if (m.contains('dss_interventions_intervention_type_check')) {
      return 'Choose an intervention (at most 120 characters).';
    }
    if (m.contains('dss_interventions_description_check') ||
        m.contains('dss_interventions_expected_outcome_check')) {
      return 'The text is too long.';
    }
    return m;
  }

  Future<List<({String id, String displayName, String email})>>
  listAdminUsers() async {
    try {
      final rows = await _supabase
          .from('users')
          .select('id, display_name, email')
          .eq('role', 'admin')
          .order('display_name');
      return rows
          .map(
            (r) => (
              id: (r['id'] ?? '').toString(),
              displayName: (r['display_name'] ?? '').toString(),
              email: (r['email'] ?? '').toString(),
            ),
          )
          .where((a) => a.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
