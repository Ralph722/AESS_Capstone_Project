import 'package:cloud_firestore/cloud_firestore.dart';

class EventComment {
  final String id;
  final String eventId;
  final String userId;
  final String userDocId;
  final String userName;
  final String userEmail;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EventComment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userDocId,
    required this.userName,
    required this.userEmail,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert EventComment to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'eventId': eventId,
      'userId': userId,
      'userDocId': userDocId,
      'userName': userName,
      'userEmail': userEmail,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create EventComment from Firestore document
  factory EventComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventComment(
      id: data['id'] ?? doc.id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      userDocId: data['userDocId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create a copy of EventComment with modified fields
  EventComment copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? userDocId,
    String? userName,
    String? userEmail,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventComment(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      userDocId: userDocId ?? this.userDocId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

