import 'package:alumni_system/core/constants/event_category_constants.dart';
import 'package:alumni_system/features/events/models/event_agenda_item.dart';

class AlumniEvent {
  final String id;
  final String theme;
  final String batchYear;
  final DateTime date;
  final String venue;
  final String status;
  final int comments;
  final String startTime; // Format: HH:mm (e.g., "14:00")
  final String endTime; // Format: HH:mm (e.g., "18:00")
  final String description;
  final DateTime createdAt;
  final String coverImageUrl;
  final String category;
  final int? capacity;
  final DateTime? registrationDeadline;
  final List<EventAgendaItem> agenda;
  final int viewsCount;
  final bool cancelled;
  final double? venueLatitude;
  final double? venueLongitude;

  AlumniEvent({
    required this.id,
    required this.theme,
    required this.batchYear,
    required this.date,
    required this.venue,
    required this.status,
    required this.comments,
    this.startTime = '09:00',
    this.endTime = '17:00',
    this.description = '',
    DateTime? createdAt,
    this.coverImageUrl = '',
    this.category = EventCategoryConstants.other,
    this.capacity,
    this.registrationDeadline,
    this.agenda = const [],
    this.viewsCount = 0,
    this.cancelled = false,
    this.venueLatitude,
    this.venueLongitude,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasCoverImage => coverImageUrl.trim().isNotEmpty;

  bool get hasVenuePin =>
      venueLatitude != null &&
      venueLongitude != null &&
      venueLatitude!.isFinite &&
      venueLongitude!.isFinite;

  bool get isRegistrationOpen {
    if (cancelled || status == 'Archived') return false;
    if (registrationDeadline == null) return true;
    return DateTime.now().isBefore(registrationDeadline!);
  }

  int? seatsRemaining(int goingCount) {
    if (capacity == null || capacity! <= 0) return null;
    final left = capacity! - goingCount;
    return left < 0 ? 0 : left;
  }

  bool isFull(int goingCount) {
    final left = seatsRemaining(goingCount);
    return left != null && left <= 0;
  }

  /// Create AlumniEvent from Supabase `events` row.
  factory AlumniEvent.fromSupabaseRow(Map<String, dynamic> row) {
    return AlumniEvent(
      id: row['id']?.toString() ?? '',
      theme: row['theme'] as String? ?? '',
      batchYear: row['batch_year'] as String? ?? '',
      date: _parseDateTime(row['date']),
      venue: row['venue'] as String? ?? '',
      status: row['status'] as String? ?? 'Active',
      comments: row['comments_count'] as int? ?? 0,
      startTime: row['start_time'] as String? ?? '09:00',
      endTime: row['end_time'] as String? ?? '17:00',
      description: row['description'] as String? ?? '',
      createdAt: _parseDateTime(row['created_at']),
      coverImageUrl: row['cover_image_url'] as String? ?? '',
      category: EventCategoryConstants.normalize(row['category'] as String?),
      capacity: row['capacity'] as int?,
      registrationDeadline: row['registration_deadline'] != null
          ? _parseDateTime(row['registration_deadline'])
          : null,
      agenda: EventAgendaItem.listFromJson(row['agenda']),
      viewsCount: row['views_count'] as int? ?? 0,
      cancelled: row['cancelled'] as bool? ?? false,
      venueLatitude: _parseDouble(row['venue_latitude']),
      venueLongitude: _parseDouble(row['venue_longitude']),
    );
  }

  /// Convert AlumniEvent to Supabase row payload.
  Map<String, dynamic> toSupabaseRow() {
    return {
      'id': id,
      'theme': theme,
      'batch_year': batchYear,
      'date': date.toUtc().toIso8601String(),
      'venue': venue,
      'status': status,
      'comments_count': comments,
      'start_time': startTime,
      'end_time': endTime,
      'description': description,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'cover_image_url': coverImageUrl,
      'category': category,
      'capacity': capacity,
      'registration_deadline': registrationDeadline?.toUtc().toIso8601String(),
      'agenda': agenda.map((e) => e.toJson()).toList(),
      'views_count': viewsCount,
      'cancelled': cancelled,
      'venue_latitude': venueLatitude,
      'venue_longitude': venueLongitude,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  AlumniEvent copyWith({
    String? id,
    String? theme,
    String? batchYear,
    DateTime? date,
    String? venue,
    String? status,
    int? comments,
    String? startTime,
    String? endTime,
    String? description,
    DateTime? createdAt,
    String? coverImageUrl,
    String? category,
    int? capacity,
    bool clearCapacity = false,
    DateTime? registrationDeadline,
    bool clearRegistrationDeadline = false,
    List<EventAgendaItem>? agenda,
    int? viewsCount,
    bool? cancelled,
    double? venueLatitude,
    double? venueLongitude,
    bool clearVenuePin = false,
  }) {
    return AlumniEvent(
      id: id ?? this.id,
      theme: theme ?? this.theme,
      batchYear: batchYear ?? this.batchYear,
      date: date ?? this.date,
      venue: venue ?? this.venue,
      status: status ?? this.status,
      comments: comments ?? this.comments,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      category: category ?? this.category,
      capacity: clearCapacity ? null : (capacity ?? this.capacity),
      registrationDeadline: clearRegistrationDeadline
          ? null
          : (registrationDeadline ?? this.registrationDeadline),
      agenda: agenda ?? this.agenda,
      viewsCount: viewsCount ?? this.viewsCount,
      cancelled: cancelled ?? this.cancelled,
      venueLatitude:
          clearVenuePin ? null : (venueLatitude ?? this.venueLatitude),
      venueLongitude:
          clearVenuePin ? null : (venueLongitude ?? this.venueLongitude),
    );
  }
}
