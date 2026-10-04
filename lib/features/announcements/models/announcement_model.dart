enum AnnouncementStatus { draft, published, archived }

enum AnnouncementPriority { normal, important }

class Announcement {
  final String id;
  final String title;
  final String body;
  final AnnouncementStatus status;
  final AnnouncementPriority priority;
  final List<String> targetPrograms;
  final List<String> targetBatchYears;
  final bool notifyInApp;
  final bool notifyEmail;

  /// Also send a phone / browser alert when published.
  final bool notifyPush;

  /// Urgent notices bypass recipients' category settings and quiet hours.
  final bool urgent;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final int recipientCount;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    this.priority = AnnouncementPriority.normal,
    this.targetPrograms = const [],
    this.targetBatchYears = const [],
    this.notifyInApp = true,
    this.notifyEmail = false,
    this.notifyPush = true,
    this.urgent = false,
    required this.createdBy,
    required this.createdAt,
    this.publishedAt,
    this.recipientCount = 0,
  });

  factory Announcement.fromSupabaseRow(Map<String, dynamic> row) {
    final data = row['data'] as Map<String, dynamic>? ?? {};
    return Announcement(
      id: row['id']?.toString() ?? '',
      title: row['title'] as String? ?? '',
      body: row['body'] as String? ?? '',
      status: AnnouncementStatus.values.firstWhere(
        (e) => e.name == (row['status'] as String? ?? 'draft'),
        orElse: () => AnnouncementStatus.draft,
      ),
      priority: AnnouncementPriority.values.firstWhere(
        (e) => e.name == (data['priority'] as String? ?? 'normal'),
        orElse: () => AnnouncementPriority.normal,
      ),
      targetPrograms: List<String>.from(data['targetPrograms'] ?? []),
      targetBatchYears: List<String>.from(data['targetBatchYears'] ?? []),
      notifyInApp: data['notifyInApp'] as bool? ?? true,
      notifyEmail: data['notifyEmail'] as bool? ?? false,
      notifyPush: data['notifyPush'] as bool? ?? true,
      urgent: data['urgent'] as bool? ?? false,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(row['created_at']),
      publishedAt: row['published_at'] != null
          ? _parseDateTime(row['published_at'])
          : null,
      recipientCount: data['recipientCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabaseRow() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'status': status.name,
      'published_at': publishedAt?.toUtc().toIso8601String(),
      'data': {
        'priority': priority.name,
        'targetPrograms': targetPrograms,
        'targetBatchYears': targetBatchYears,
        'notifyInApp': notifyInApp,
        'notifyEmail': notifyEmail,
        'notifyPush': notifyPush,
        'urgent': urgent,
        'createdBy': createdBy,
        'recipientCount': recipientCount,
      },
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }

  Announcement copyWith({
    String? title,
    String? body,
    AnnouncementStatus? status,
    AnnouncementPriority? priority,
    List<String>? targetPrograms,
    List<String>? targetBatchYears,
    bool? notifyInApp,
    bool? notifyEmail,
    bool? notifyPush,
    bool? urgent,
    DateTime? publishedAt,
    int? recipientCount,
  }) {
    return Announcement(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      targetPrograms: targetPrograms ?? this.targetPrograms,
      targetBatchYears: targetBatchYears ?? this.targetBatchYears,
      notifyInApp: notifyInApp ?? this.notifyInApp,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      notifyPush: notifyPush ?? this.notifyPush,
      urgent: urgent ?? this.urgent,
      createdBy: createdBy,
      createdAt: createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      recipientCount: recipientCount ?? this.recipientCount,
    );
  }
}
