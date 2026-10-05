import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/core/services/app_session.dart';

class AuditService {
  AuditService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Audit rows are append-only. The server stamps user id, name, email and
  /// role, and a nightly job prunes old rows.
  Future<void> logAction({
    required String action,
    required String resource,
    required String resourceId,
    required String description,
    Map<String, dynamic>? changes,
    String status = 'SUCCESS',
    String userRole = 'user',
  }) async {
    try {
      final user = AppSession.currentUser;
      if (user == null) return;

      final auditLog = AuditLog(
        id: '',
        userId: user.id,
        userName: (user.userMetadata?['display_name'] as String?) ?? 'Unknown',
        userEmail: user.email ?? 'unknown@example.com',
        action: action,
        resource: resource,
        resourceId: resourceId,
        description: description,
        changes: changes,
        timestamp: DateTime.now(),
        ipAddress: null,
        status: status,
        userRole: userRole,
      );

      await _supabase.from('audit_logs').insert(auditLog.toSupabaseRow());
    } catch (_) {
      // Audit logging must not break user flows
    }
  }

  // Get all audit logs
  Future<List<AuditLog>> getAllAuditLogs({int limit = 100}) async {
    try {
      final rows = await _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(AuditLog.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
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
    try {
      final rows = await _supabase
          .from('audit_logs')
          .select()
          .gte('created_at', startDate.toUtc().toIso8601String())
          .lte('created_at', endDate.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(AuditLog.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  // Get total audit log count
  Future<int> getAuditLogCount() async {
    try {
      final rows = await _supabase.from('audit_logs').select('id');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  // Get failed actions count
  Future<int> getFailedActionsCount() async {
    try {
      final rows = await _supabase
          .from('audit_logs')
          .select('id, details')
          .filter('details->>status', 'eq', 'FAILED');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  // Search audit logs
  Future<List<AuditLog>> searchAuditLogs(
    String query, {
    int limit = 50,
  }) async {
    try {
      final rows = await _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit * 2);

      final logs = rows.map(AuditLog.fromSupabaseRow).toList();

      // Client-side filtering
      return logs
          .where((log) =>
              log.description.toLowerCase().contains(query.toLowerCase()) ||
              log.userName.toLowerCase().contains(query.toLowerCase()) ||
              log.action.toLowerCase().contains(query.toLowerCase()))
          .take(limit)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
