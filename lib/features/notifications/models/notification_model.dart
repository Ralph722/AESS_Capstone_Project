enum NotificationType {
  event,
  job,
  message,
  announcement,
  survey,
  feedback,
  forum,
  system,
}

enum NotificationPriority { low, normal, high, urgent }

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? relatedId; // ID of related resource (event, job, etc.)
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data; // Additional data
  final NotificationPriority priority;

  /// In-app destination, e.g. `event/{id}`, `survey/{id}`, `tracer`,
  /// `admin/feedback/{id}`. Null on older rows.
  final String? route;
  final String? dedupeKey;
  final DateTime? readAt;
  final DateTime? expiresAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
    this.data,
    this.priority = NotificationPriority.normal,
    this.route,
    this.dedupeKey,
    this.readAt,
    this.expiresAt,
  });

  bool get isUrgent => priority == NotificationPriority.urgent;
  bool get isHighPriority =>
      priority == NotificationPriority.high ||
      priority == NotificationPriority.urgent;

  factory NotificationModel.fromSupabaseRow(Map<String, dynamic> row) {
    final data = row['data'] is Map
        ? Map<String, dynamic>.from(row['data'] as Map)
        : <String, dynamic>{};
    final relatedId = data.remove('relatedId')?.toString();
    data.remove('push');
    final route = row['route']?.toString().trim();

    return NotificationModel(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == (row['type']?.toString() ?? ''),
        orElse: () => NotificationType.system,
      ),
      title: row['title']?.toString() ?? '',
      message: row['body']?.toString() ?? '',
      relatedId: relatedId,
      isRead: row['is_read'] == true,
      createdAt: _parseDateTime(row['created_at']),
      data: data.isEmpty ? null : data,
      priority: NotificationPriority.values.firstWhere(
        (p) => p.name == row['priority']?.toString(),
        orElse: () => NotificationPriority.normal,
      ),
      route: (route == null || route.isEmpty) ? null : route,
      dedupeKey: row['dedupe_key']?.toString(),
      readAt: _parseOptionalDateTime(row['read_at']),
      expiresAt: _parseOptionalDateTime(row['expires_at']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    return _parseOptionalDateTime(value) ?? DateTime.now();
  }

  static DateTime? _parseOptionalDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  // Copy with method
  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    String? relatedId,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
    NotificationPriority? priority,
    String? route,
    String? dedupeKey,
    DateTime? readAt,
    DateTime? expiresAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      route: route ?? this.route,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      readAt: readAt ?? this.readAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  // Get icon based on type
  String get iconName {
    switch (type) {
      case NotificationType.event:
        return 'event';
      case NotificationType.job:
        return 'work';
      case NotificationType.message:
        return 'message';
      case NotificationType.announcement:
        return 'campaign';
      case NotificationType.survey:
        return 'poll';
      case NotificationType.feedback:
        return 'feedback';
      case NotificationType.forum:
        return 'forum';
      case NotificationType.system:
        return 'info';
    }
  }

  // Get color based on type
  int get colorValue => colorValueFor(type);

  static int colorValueFor(NotificationType type) {
    switch (type) {
      case NotificationType.event:
        return 0xFF4CAF50; // Green
      case NotificationType.job:
        return 0xFF2196F3; // Blue
      case NotificationType.message:
        return 0xFFFF9800; // Orange
      case NotificationType.announcement:
        return 0xFF9C27B0; // Purple
      case NotificationType.survey:
        return 0xFF090A4F; // Navy
      case NotificationType.feedback:
        return 0xFF090A4F; // Navy
      case NotificationType.forum:
        return 0xFF090A4F; // Navy
      case NotificationType.system:
        return 0xFF607D8B; // Blue Grey
    }
  }
}
