import 'package:alumni_system/core/services/audit_events.dart';

class AuditLog {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String action;
  final String resource;
  final String resourceId;
  final String description;
  final Map<String, dynamic>? changes;
  final DateTime timestamp;
  final String? ipAddress;
  final String status;
  final String userRole; // 'admin' or 'user'
  final String module;
  final String category;
  final String actorType;
  final String? correlationId;
  final String? targetLabel;
  final Map<String, dynamic>? meta;

  AuditLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.action,
    required this.resource,
    required this.resourceId,
    required this.description,
    this.changes,
    required this.timestamp,
    this.ipAddress,
    required this.status,
    this.userRole = 'user',
    this.module = '',
    this.category = AuditCategories.activity,
    this.actorType = AuditActorTypes.alumni,
    this.correlationId,
    this.targetLabel,
    this.meta,
  });

  /// Convert to a `public.audit_logs` row. Fields without a dedicated
  /// column are packed into `details` jsonb.
  Map<String, dynamic> toSupabaseRow() {
    return {
      'user_id': userId.isNotEmpty ? userId : null,
      'action': action,
      'entity_type': resource,
      'entity_id': resourceId,
      'details': {
        'userName': userName,
        'userEmail': userEmail,
        'description': description,
        if (changes != null) 'changes': changes,
        if (ipAddress != null) 'ipAddress': ipAddress,
        'status': status,
        'userRole': userRole,
        if (module.isNotEmpty) 'module': module,
        'category': category,
        'actorType': actorType,
        if (correlationId != null && correlationId!.isNotEmpty)
          'correlationId': correlationId,
        if (targetLabel != null && targetLabel!.isNotEmpty)
          'targetLabel': targetLabel,
        if (meta != null && meta!.isNotEmpty) 'meta': meta,
      },
      'created_at': timestamp.toUtc().toIso8601String(),
    };
  }

  factory AuditLog.fromSupabaseRow(Map<String, dynamic> row) {
    final details = row['details'] as Map<String, dynamic>? ?? {};
    final role = details['userRole'] as String? ?? 'user';
    final actorType = details['actorType'] as String?;
    return AuditLog(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      userName: details['userName'] as String? ?? '',
      userEmail: details['userEmail'] as String? ?? '',
      action: row['action'] as String? ?? '',
      resource: row['entity_type'] as String? ?? '',
      resourceId: row['entity_id'] as String? ?? '',
      description: details['description'] as String? ?? '',
      changes: _asStringKeyedMap(details['changes']),
      timestamp: _parseDateTime(row['created_at']),
      ipAddress: details['ipAddress'] as String?,
      status: details['status'] as String? ?? AuditStatus.success,
      userRole: role,
      module: details['module'] as String? ?? '',
      category: details['category'] as String? ?? AuditCategories.activity,
      actorType:
          actorType ??
          (role == 'admin'
              ? AuditActorTypes.admin
              : AuditActorTypes.alumni),
      correlationId: details['correlationId'] as String?,
      targetLabel: details['targetLabel'] as String?,
      meta: _asStringKeyedMap(details['meta']),
    );
  }

  static Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }

  AuditLog copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? action,
    String? resource,
    String? resourceId,
    String? description,
    Map<String, dynamic>? changes,
    DateTime? timestamp,
    String? ipAddress,
    String? status,
    String? userRole,
    String? module,
    String? category,
    String? actorType,
    String? correlationId,
    String? targetLabel,
    Map<String, dynamic>? meta,
  }) {
    return AuditLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      action: action ?? this.action,
      resource: resource ?? this.resource,
      resourceId: resourceId ?? this.resourceId,
      description: description ?? this.description,
      changes: changes ?? this.changes,
      timestamp: timestamp ?? this.timestamp,
      ipAddress: ipAddress ?? this.ipAddress,
      status: status ?? this.status,
      userRole: userRole ?? this.userRole,
      module: module ?? this.module,
      category: category ?? this.category,
      actorType: actorType ?? this.actorType,
      correlationId: correlationId ?? this.correlationId,
      targetLabel: targetLabel ?? this.targetLabel,
      meta: meta ?? this.meta,
    );
  }
}
