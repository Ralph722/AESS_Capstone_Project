import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

class DssRepository {
  DssRepository({SupabaseClient? supabase, AuditService? auditService})
    : _supabase = supabase ?? Supabase.instance.client,
      _audit = auditService ?? AuditService();

  final SupabaseClient _supabase;
  final AuditService _audit;

  static const _flagSelect =
      '*, dss_rules(name, severity, playbook, recommended_action, operator, min_n, category)';

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
    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit);
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

  Future<List<DssFlagNote>> listNotesForFlags(
    List<String> flagIds, {
    int limit = 500,
  }) async {
    if (flagIds.isEmpty) return const [];
    final rows = await _supabase
        .from('dss_flag_notes')
        .select()
        .inFilter('flag_id', flagIds)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(DssFlagNote.fromSupabaseRow).toList();
  }

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
    final user = AppSession.currentUser;
    final now = DateTime.now().toUtc().toIso8601String();
    final updates = <String, dynamic>{
      'status': status.dbValue,
      'updated_by': user?.id,
      'updated_at': now,
    };
    if (status == DssFlagStatus.resolved || status == DssFlagStatus.dismissed) {
      updates['resolved_at'] = now;
    }
    if (clearResolvedAt ||
        status == DssFlagStatus.open ||
        status == DssFlagStatus.inProgress) {
      if (flag.status == DssFlagStatus.resolved ||
          flag.status == DssFlagStatus.dismissed) {
        updates['resolved_at'] = null;
        updates['verify_due_at'] = null;
      }
    }
    if (interventionType != null) {
      updates['intervention_type'] = interventionType;
    }
    if (interventionDetail != null) {
      updates['intervention_detail'] = interventionDetail;
    }
    if (followupValue != null) {
      updates['followup_value'] = followupValue;
      updates['followup_at'] = now;
    }
    if (followupSampleN != null) {
      updates['followup_sample_n'] = followupSampleN;
    }
    if (impactVerdict != null) {
      updates['impact_verdict'] = impactVerdict;
    }
    if (verifyDueAt != null) {
      updates['verify_due_at'] = verifyDueAt.toUtc().toIso8601String();
    }

    await _supabase.from('dss_flags').update(updates).eq('id', flag.id);

    final trimmed = note.trim();
    if (trimmed.isNotEmpty || status != flag.status) {
      final isReopen = (flag.status == DssFlagStatus.resolved ||
              flag.status == DssFlagStatus.dismissed) &&
          (status == DssFlagStatus.open || status == DssFlagStatus.inProgress);
      await _insertNote(
        flagId: flag.id,
        note: trimmed.isEmpty
            ? 'Status changed to ${status.label}'
            : trimmed,
        statusFrom: flag.status.dbValue,
        statusTo: status.dbValue,
        eventType: isReopen
            ? DssNoteEventType.reopen
            : DssNoteEventType.status,
        metadata: {
          if (interventionType != null) 'intervention': interventionType,
          if (interventionDetail != null && interventionDetail.isNotEmpty)
            'intervention_detail': interventionDetail,
          if (impactVerdict != null) 'impact_verdict': impactVerdict,
          if (followupValue != null) 'followup_value': followupValue,
          if (followupSampleN != null) 'followup_sample_n': followupSampleN,
        },
      );
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
    await _supabase.from('dss_flags').update({
      'followup_value': followupValue,
      'followup_sample_n': followupSampleN,
      'followup_at': now,
      'impact_verdict': impactVerdict,
      'verify_due_at': nextVerifyDueAt?.toUtc().toIso8601String(),
      'updated_by': user?.id,
      'updated_at': now,
    }).eq('id', flag.id);

    await _insertNote(
      flagId: flag.id,
      note: 'Impact recheck: $impactVerdict'
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
    await _supabase.from('dss_flags').update({
      'linked_announcement_id': announcementId,
      'updated_by': AppSession.currentUser?.id,
    }).eq('id', flagId);
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
    final map = res is Map ? Map<String, dynamic>.from(res) : const {};
    int read(String k) => (map[k] as num?)?.toInt() ?? 0;
    return DssActionResult(
      selected: read('selected'),
      eligible: read('eligible'),
      sent: read('sent'),
      jobs: read('jobs'),
    );
  }

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
          .update({
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
            'updated_by': user?.id,
          })
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

  Future<DssHistoryStats> historyStats({int lookbackDays = 365}) async {
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: lookbackDays))
        .toIso8601String();
    final rows = await _supabase
        .from('dss_flags')
        .select(
          'rule_id, status, created_at, resolved_at, impact_verdict, '
          'baseline_value, followup_value',
        )
        .gte('created_at', since)
        .limit(2000);

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
    final impactByRule = <String, ({int checked, int improved, int stillFlagged})>{};

    for (final row in rows) {
      raised++;
      final status = DssFlagStatusX.fromDb(row['status']?.toString());
      switch (status) {
        case DssFlagStatus.open:
          open++;
        case DssFlagStatus.inProgress:
          inProgress++;
        case DssFlagStatus.resolved:
          resolved++;
        case DssFlagStatus.dismissed:
          dismissed++;
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
        resolutionDays.add(
          resolvedAt.difference(created).inHours / 24.0,
        );
      }

      if (status == DssFlagStatus.resolved) {
        final verdict = (row['impact_verdict'] ?? '').toString();
        if (verdict.isNotEmpty) {
          impactChecked++;
          final prev = impactByRule[ruleId] ??
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
      avg =
          resolutionDays.reduce((a, b) => a + b) / resolutionDays.length;
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
