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
  });

  factory NotificationModel.fromSupabaseRow(Map<String, dynamic> row) {
    final data = row['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(row['data'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final relatedId = data.remove('relatedId')?.toString();

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
    );
  }

  Map<String, dynamic> toSupabaseRow({required String supabaseUserId}) {
    final payload = <String, dynamic>{
      if (relatedId != null) 'relatedId': relatedId,
      if (data != null) ...data!,
    };

    return {
      'user_id': supabaseUserId,
      'title': title,
      'body': message,
      'type': type.name,
      'is_read': isRead,
      'data': payload,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
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
  int get colorValue {
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
