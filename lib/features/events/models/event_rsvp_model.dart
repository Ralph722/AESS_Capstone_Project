enum EventRsvpStatus { going, interested, cantAttend }

extension EventRsvpStatusX on EventRsvpStatus {
  String get dbValue => switch (this) {
    EventRsvpStatus.going => 'going',
    EventRsvpStatus.interested => 'interested',
    EventRsvpStatus.cantAttend => 'cant_attend',
  };

  String get label => switch (this) {
    EventRsvpStatus.going => 'Going',
    EventRsvpStatus.interested => 'Interested',
    EventRsvpStatus.cantAttend => "Can't Attend",
  };

  static EventRsvpStatus? tryParse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'going':
        return EventRsvpStatus.going;
      case 'interested':
        return EventRsvpStatus.interested;
      case 'cant_attend':
      case 'cantattend':
      case 'declined':
        return EventRsvpStatus.cantAttend;
      default:
        return null;
    }
  }
}

class EventRsvp {
  const EventRsvp({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.userName = '',
    this.userEmail = '',
    this.profileImageUrl = '',
  });

  final String id;
  final String eventId;
  final String userId;
  final EventRsvpStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String userName;
  final String userEmail;
  final String profileImageUrl;

  factory EventRsvp.fromSupabaseRow(
    Map<String, dynamic> row, {
    String userName = '',
    String userEmail = '',
    String profileImageUrl = '',
  }) {
    return EventRsvp(
      id: row['id']?.toString() ?? '',
      eventId: row['event_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      status:
          EventRsvpStatusX.tryParse(row['status'] as String?) ??
          EventRsvpStatus.interested,
      createdAt: _parseDate(row['created_at']),
      updatedAt: row['updated_at'] != null ? _parseDate(row['updated_at']) : null,
      userName: userName,
      userEmail: userEmail,
      profileImageUrl: profileImageUrl,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }
}

class EventRsvpCounts {
  const EventRsvpCounts({
    this.going = 0,
    this.interested = 0,
    this.cantAttend = 0,
  });

  final int going;
  final int interested;
  final int cantAttend;

  int get totalResponses => going + interested + cantAttend;

  EventRsvpCounts copyWith({int? going, int? interested, int? cantAttend}) {
    return EventRsvpCounts(
      going: going ?? this.going,
      interested: interested ?? this.interested,
      cantAttend: cantAttend ?? this.cantAttend,
    );
  }
}
