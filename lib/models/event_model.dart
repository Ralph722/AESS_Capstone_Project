import 'package:cloud_firestore/cloud_firestore.dart';

class AlumniEvent {
  final String id;
  final String theme;
  final String batchYear;
  final DateTime date;
  final String venue;
  final String status;
  final int comments;

  AlumniEvent({
    required this.id,
    required this.theme,
    required this.batchYear,
    required this.date,
    required this.venue,
    required this.status,
    required this.comments,
  });

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
  }) {
    return AlumniEvent(
      id: id ?? this.id,
      theme: theme ?? this.theme,
      batchYear: batchYear ?? this.batchYear,
      date: date ?? this.date,
      venue: venue ?? this.venue,
      status: status ?? this.status,
      comments: comments ?? this.comments,
    );
  }
}
