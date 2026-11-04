import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/core/utils/csv_safe.dart';

class AuditService {
  AuditService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Audit rows are append-only. The server stamps user id, name, email and
  /// role. A nightly job keeps the hot table lean with tiered retention:
  /// LOGIN/LOGOUT 90d (deleted), activity 1y → archive (kept 3y), security
  /// 3y → archive (kept 5y).
  Future<void> logAction({
    required String action,
    required String resource,
    required String resourceId,
    required String description,
    Map<String, dynamic>? changes,
    String status = AuditStatus.success,
    String userRole = 'user',
    String module = '',
    String category = AuditCategories.activity,
    String? actorType,
    String? correlationId,
    String? targetLabel,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final user = AppSession.currentUser;
      if (user == null) return;

      final resolvedRole = userRole;
      final resolvedActorType = actorType ??
          (resolvedRole == 'admin'
              ? AuditActorTypes.admin
              : AuditActorTypes.alumni);

      final auditLog = AuditLog(
        id: '',
        userId: user.id,
        userName: (user.userMetadata?['display_name'] as String?) ?? 'Unknown',
        userEmail: user.email ?? 'unknown@example.com',
        action: action,
        resource: resource,
        resourceId: resourceId,
        description: _truncate(description, 500),
        changes: _sanitizeChanges(changes),
        timestamp: DateTime.now(),
        ipAddress: null,
        status: status,
        userRole: resolvedRole,
        module: module,
        category: category,
        actorType: resolvedActorType,
        correlationId: correlationId,
        targetLabel: targetLabel == null ? null : _truncate(targetLabel, 120),
        meta: meta,
      );

      await _supabase.from('audit_logs').insert(auditLog.toSupabaseRow());
    } catch (_) {
      // Audit logging must not break user flows
    }
  }

  /// Records a failed authentication attempt via SECURITY DEFINER RPC.
  /// Works without an authenticated session (unlike [logAction]).
  Future<void> logFailedAuthAttempt({
    required String action,
    required String email,
    String? description,
  }) async {
    try {
      final normalized = email.trim().toLowerCase();
      await _supabase.rpc(
        'record_failed_auth_attempt',
        params: {
          'p_action': action,
          'p_email': _truncate(normalized, 254),
          'p_description': _truncate(
            description ?? 'Failed $action attempt',
            500,
          ),
        },
      );
    } catch (_) {
      // Non-fatal — never block login UI on audit failure.
    }
  }

  // Get all audit logs
  Future<List<AuditLog>> getAllAuditLogs({int limit = 100}) async {
    final page = await queryAuditLogs(AuditLogQuery(limit: limit));
    return page.logs;
  }

  /// Server-filtered audit log page for the Activity Logs UI.
  Future<({List<AuditLog> logs, int? totalHint})> queryAuditLogs(
    AuditLogQuery query,
  ) async {
    try {
      var builder = _supabase.from('audit_logs').select();

      if (query.action != null &&
          query.action!.isNotEmpty &&
          query.action != 'All') {
        builder = builder.eq('action', query.action!);
      }
      if (query.resource != null &&
          query.resource!.isNotEmpty &&
          query.resource != 'All') {
        builder = builder.eq('entity_type', query.resource!);
      }
      if (query.module != null &&
          query.module!.isNotEmpty &&
          query.module != 'All') {
        builder = builder.filter('details->>module', 'eq', query.module!);
      }
      if (query.category != null &&
          query.category!.isNotEmpty &&
          query.category != 'All') {
        builder = builder.filter('details->>category', 'eq', query.category!);
      }
      if (query.status != null &&
          query.status!.isNotEmpty &&
          query.status != 'All') {
        builder = builder.filter('details->>status', 'eq', query.status!);
      }
      if (query.actorType != null &&
          query.actorType!.isNotEmpty &&
          query.actorType != 'All') {
        builder =
            builder.filter('details->>actorType', 'eq', query.actorType!);
      }
      if (query.userRole != null &&
          query.userRole!.isNotEmpty &&
          query.userRole != 'All') {
        builder = builder.filter('details->>userRole', 'eq', query.userRole!);
      }
      if (query.startDate != null) {
        final start = DateTime(
          query.startDate!.year,
          query.startDate!.month,
          query.startDate!.day,
        ).toUtc();
        builder = builder.gte('created_at', start.toIso8601String());
      }
      if (query.endDate != null) {
        final end = DateTime(
          query.endDate!.year,
          query.endDate!.month,
          query.endDate!.day,
        ).add(const Duration(days: 1)).toUtc();
        builder = builder.lt('created_at', end.toIso8601String());
      }

      final rows = await builder
          .order('created_at', ascending: false)
          .range(query.offset, query.offset + query.limit - 1);

      var logs = rows.map(AuditLog.fromSupabaseRow).toList();

      final search = query.search?.trim().toLowerCase();
      if (search != null && search.isNotEmpty) {
        logs = logs
            .where(
              (log) =>
                  log.description.toLowerCase().contains(search) ||
                  log.userName.toLowerCase().contains(search) ||
                  log.userEmail.toLowerCase().contains(search) ||
                  log.action.toLowerCase().contains(search) ||
                  log.resource.toLowerCase().contains(search) ||
                  log.module.toLowerCase().contains(search) ||
                  (log.targetLabel?.toLowerCase().contains(search) ?? false),
            )
            .toList();
      }

      return (logs: logs, totalHint: null);
    } catch (_) {
      return (logs: <AuditLog>[], totalHint: 0);
    }
  }

  /// Overview stats for the selected date range (best-effort aggregations).
  Future<AuditLogStats> getAuditLogStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final page = await queryAuditLogs(
        AuditLogQuery(
          limit: 2000,
          startDate: startDate,
          endDate: endDate,
        ),
      );
      final logs = page.logs;
      final now = DateTime.now();
      var today = 0;
      var adminActions = 0;
      var securityEvents = 0;
      var failed = 0;
      var systemEvents = 0;

      for (final log in logs) {
        final t = log.timestamp;
        if (t.year == now.year && t.month == now.month && t.day == now.day) {
          today++;
        }
        if (log.userRole == 'admin' ||
            log.actorType == AuditActorTypes.admin) {
          adminActions++;
        }
        if (log.category == AuditCategories.security) {
          securityEvents++;
        }
        if (log.status == AuditStatus.failed ||
            log.status == AuditStatus.rejected) {
          failed++;
        }
        if (log.actorType == AuditActorTypes.system) {
          systemEvents++;
        }
      }

      return AuditLogStats(
        total: logs.length,
        today: today,
        adminActions: adminActions,
        securityEvents: securityEvents,
        failed: failed,
        systemEvents: systemEvents,
      );
    } catch (_) {
      return AuditLogStats.empty;
    }
  }

  /// CSV for the current filter set (excludes raw nested PII-heavy maps).
  String buildExportCsv(List<AuditLog> logs) {
    final buffer = StringBuffer();
    buffer.writeln(
      [
        'timestamp',
        'actor',
        'email',
        'role',
        'actor_type',
        'action',
        'module',
        'category',
        'resource',
        'resource_id',
        'target',
        'status',
        'description',
        'correlation_id',
      ].map(CsvSafe.cell).join(','),
    );
    for (final log in logs) {
      buffer.writeln(
        [
          log.timestamp.toUtc().toIso8601String(),
          log.userName,
          log.userEmail,
          log.userRole,
          log.actorType,
          log.action,
          log.module,
          log.category,
          log.resource,
          log.resourceId,
          log.targetLabel ?? '',
          log.status,
          log.description,
          log.correlationId ?? '',
        ].map(CsvSafe.cell).join(','),
      );
    }
    return buffer.toString();
  }

  // Get audit logs for a specific user
  Future<List<AuditLog>> getUserAuditLogs(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final rows = await _supabase
          .from('audit_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(AuditLog.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  // Get audit logs for a specific resource
  Future<List<AuditLog>> getResourceAuditLogs(
    String resource,
    String resourceId, {
    int limit = 50,
  }) async {
    try {
      final rows = await _supabase
          .from('audit_logs')
          .select()
          .eq('entity_type', resource)
          .eq('entity_id', resourceId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(AuditLog.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  /// Lightweight id-only count for directory detail chips (no full row payloads).
  Future<int> countRelatedAuditLogs({
    required String? userId,
    required String resource,
    required String resourceId,
    int limit = 100,
  }) async {
    final logs = await getRelatedAuditLogs(
      userId: userId,
      resource: resource,
      resourceId: resourceId,
      limit: limit,
    );
    return logs.length;
  }

  /// Deduped audit rows tied to a roster member and/or their auth user.
  Future<List<AuditLog>> getRelatedAuditLogs({
    required String? userId,
    required String resource,
    required String resourceId,
    int limit = 100,
  }) async {
    try {
      final futures = <Future<List<Map<String, dynamic>>>>[
        _supabase
            .from('audit_logs')
            .select()
            .eq('entity_type', resource)
            .eq('entity_id', resourceId)
            .order('created_at', ascending: false)
            .limit(limit),
      ];
      if (userId != null && userId.isNotEmpty) {
        futures.add(
          _supabase
              .from('audit_logs')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(limit),
        );
      }
      final results = await Future.wait(futures);
      final byId = <String, AuditLog>{};
      for (final rows in results) {
        for (final row in rows) {
          final log = AuditLog.fromSupabaseRow(row);
          if (log.id.isEmpty) continue;
          byId.putIfAbsent(log.id, () => log);
        }
      }
      final logs = byId.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (logs.length <= limit) return logs;
      return logs.sublist(0, limit);
    } catch (_) {
      return [];
    }
  }

  // Get audit logs by action type
  Future<List<AuditLog>> getAuditLogsByAction(
    String action, {
    int limit = 50,
  }) async {
    try {
      final rows = await _supabase
          .from('audit_logs')
          .select()
          .eq('action', action)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(AuditLog.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  // Get audit logs by date range
  Future<List<AuditLog>> getAuditLogsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int limit = 100,
  }) async {
    final page = await queryAuditLogs(
      AuditLogQuery(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      ),
    );
    return page.logs;
  }

  // Get total audit log count
  Future<int> getAuditLogCount() async {
    try {
      return await _supabase.from('audit_logs').count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  // Get failed actions count
  Future<int> getFailedActionsCount() async {
    try {
      return await _supabase
          .from('audit_logs')
          .count(CountOption.exact)
          .filter('details->>status', 'eq', AuditStatus.failed);
    } catch (_) {
      return 0;
    }
  }

  // Search audit logs
  Future<List<AuditLog>> searchAuditLogs(
    String query, {
    int limit = 50,
  }) async {
    final page = await queryAuditLogs(
      AuditLogQuery(limit: limit, search: query),
    );
    return page.logs;
  }

  static String _truncate(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return trimmed.substring(0, max);
  }

  /// Drops known secret keys and caps nested size for audit `changes`.
  static Map<String, dynamic>? _sanitizeChanges(Map<String, dynamic>? input) {
    if (input == null || input.isEmpty) return input;
    const blocked = {
      'password',
      'otp',
      'token',
      'access_token',
      'refresh_token',
      'api_key',
      'secret',
      'authorization',
    };
    final out = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key.toLowerCase();
      if (blocked.any(key.contains)) continue;
      final value = entry.value;
      if (value is String) {
        out[entry.key] = _truncate(value, 200);
      } else if (value is Map) {
        out[entry.key] = _sanitizeChanges(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        out[entry.key] = value;
      }
    }
    return out;
  }
}
