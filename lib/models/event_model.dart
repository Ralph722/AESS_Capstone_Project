import 'package:cloud_firestore/cloud_firestore.dart';

class AlumniEvent {
  final String id;
  final String theme;
  final String batchYear;
  final DateTime date;
  final String venue;
  final String status;
  final int comments;
  final String startTime; // Format: HH:mm (e.g., "14:00")
  final String endTime;   // Format: HH:mm (e.g., "18:00")
  final String description;
  final DateTime createdAt; // When the event was created/posted

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
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert AlumniEvent to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'theme': theme,
      'batchYear': batchYear,
      'date': Timestamp.fromDate(date),
      'venue': venue,
      'status': status,
      'comments': comments,
      'startTime': startTime,
      'endTime': endTime,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create AlumniEvent from Firestore document
  factory AlumniEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlumniEvent(
      id: data['id'] ?? '',
      theme: data['theme'] ?? '',
      batchYear: data['batchYear'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      venue: data['venue'] ?? '',
      status: data['status'] ?? 'Active',
      comments: data['comments'] ?? 0,
      startTime: data['startTime'] ?? '09:00',
      endTime: data['endTime'] ?? '17:00',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy of AlumniEvent with modified fields
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
    );
  }
}
