enum FeedbackCategory {
  bug,
  feature,
  general,
  portal,
  event,
  jobs,
  other,
}

enum FeedbackStatus {
  submitted,
  inReview,
  resolved,
  closed,
}

extension FeedbackCategoryX on FeedbackCategory {
  String get label {
    switch (this) {
      case FeedbackCategory.bug:
        return 'Bug';
      case FeedbackCategory.feature:
        return 'Feature request';
      case FeedbackCategory.general:
        return 'General';
      case FeedbackCategory.portal:
        return 'Portal issue';
      case FeedbackCategory.event:
        return 'Events';
      case FeedbackCategory.jobs:
        return 'Jobs';
      case FeedbackCategory.other:
        return 'Other';
    }
  }
}

extension FeedbackStatusX on FeedbackStatus {
  String get label {
    switch (this) {
      case FeedbackStatus.submitted:
        return 'Submitted';
      case FeedbackStatus.inReview:
        return 'In review';
      case FeedbackStatus.resolved:
        return 'Resolved';
      case FeedbackStatus.closed:
        return 'Closed';
    }
  }

  static FeedbackStatus fromName(String? value) {
    return FeedbackStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FeedbackStatus.submitted,
    );
  }
}

class FeedbackSubmission {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? program;
  final String? batchYear;
  final FeedbackCategory category;
  final String? subject;
  final String message;
  final int? rating;
  final FeedbackStatus status;
  final String? adminResponse;
  final String? respondedBy;
  final String? respondedByName;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FeedbackSubmission({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.program,
    this.batchYear,
    required this.category,
    this.subject,
    required this.message,
    this.rating,
    required this.status,
    this.adminResponse,
    this.respondedBy,
    this.respondedByName,
    this.respondedAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get hasAdminResponse =>
      adminResponse != null && adminResponse!.trim().isNotEmpty;

  /// Open for admin action: new submissions or in review without a reply yet.
  bool get isOpen {
    if (status == FeedbackStatus.resolved || status == FeedbackStatus.closed) {
      return false;
    }
    // Legacy rows: response saved but status never moved off submitted/inReview.
    if (hasAdminResponse) return false;
    return status == FeedbackStatus.submitted ||
        status == FeedbackStatus.inReview;
  }

  factory FeedbackSubmission.fromSupabaseRow(Map<String, dynamic> row) {
    final data = row['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(row['data'] as Map<String, dynamic>)
        : <String, dynamic>{};

    return FeedbackSubmission(
      id: row['id']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      program: data['program']?.toString(),
      batchYear: data['batchYear']?.toString(),
      category: FeedbackCategory.values.firstWhere(
        (e) => e.name == (data['category']?.toString() ?? 'general'),
        orElse: () => FeedbackCategory.general,
      ),
      subject: data['subject']?.toString(),
      message: row['message']?.toString() ?? '',
      rating: data['rating'] is int
          ? data['rating'] as int
          : int.tryParse(data['rating']?.toString() ?? ''),
      status: FeedbackStatusX.fromName(row['status']?.toString()),
      adminResponse: row['admin_reply']?.toString(),
      respondedBy: data['respondedBy']?.toString(),
      respondedByName: data['respondedByName']?.toString(),
      respondedAt: data['respondedAt'] != null
          ? _parseDateTime(data['respondedAt'])
          : null,
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: row['updated_at'] != null
          ? _parseDateTime(row['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toSupabaseRow({required String supabaseUserId}) {
    return {
      'id': id,
      'user_id': supabaseUserId,
      'status': status.name,
      'message': message,
      'admin_reply': adminResponse,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'data': {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'program': program,
        'batchYear': batchYear,
        'category': category.name,
        'subject': subject,
        'rating': rating,
        'respondedBy': respondedBy,
        'respondedByName': respondedByName,
        'respondedAt': respondedAt?.toUtc().toIso8601String(),
      },
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }
}
