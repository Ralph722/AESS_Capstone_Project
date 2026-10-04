class EventComment {
  final String id;
  final String eventId;
  final String userId;
  final String userDocId;
  final String userName;
  final String userEmail;
  final String profileImageUrl;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Only set for replies — the parent comment's id (`event_replies.comment_id`).
  final String parentCommentId;

  EventComment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userDocId,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl = '',
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.parentCommentId = '',
  });

  /// Convert to a `public.event_comments` (or `event_replies`) row payload.
  /// User display fields aren't stored on these tables; they are looked up
  /// separately from `public.users` when reading.
  Map<String, dynamic> toSupabaseRow() {
    return {
      'event_id': eventId,
      'user_id': userId,
      'body': comment,
      if (parentCommentId.isNotEmpty) 'comment_id': parentCommentId,
    };
  }

  factory EventComment.fromSupabaseRow(
    Map<String, dynamic> row, {
    String userName = '',
    String userEmail = '',
    String profileImageUrl = '',
  }) {
    return EventComment(
      id: row['id']?.toString() ?? '',
      eventId: row['event_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      userDocId: row['user_id']?.toString() ?? '',
      userName: userName,
      userEmail: userEmail,
      profileImageUrl: profileImageUrl,
      comment: row['body'] as String? ?? '',
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: row['updated_at'] != null
          ? _parseDateTime(row['updated_at'])
          : null,
      parentCommentId: row['comment_id']?.toString() ?? '',
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }

  /// Create a copy of EventComment with modified fields
  EventComment copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? userDocId,
    String? userName,
    String? userEmail,
    String? profileImageUrl,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentCommentId,
  }) {
    return EventComment(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      userDocId: userDocId ?? this.userDocId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
    );
  }
}
