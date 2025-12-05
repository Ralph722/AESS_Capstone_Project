import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { event, job, message, announcement, system }

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

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'relatedId': relatedId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'data': data,
    };
  }

  // Create from Firestore document
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.system,
      ),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      relatedId: map['relatedId'],
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data: map['data'] as Map<String, dynamic>?,
    );
  }

  // Create from Firestore document snapshot
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel.fromMap(data);
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
      case NotificationType.system:
        return 0xFF607D8B; // Blue Grey
    }
  }
}
