import 'package:cloud_firestore/cloud_firestore.dart';

class AlumniMember {
  final String id;
  final String fullName;
  final String batchYear;
  final String course;
  final String contactNumber;
  final String emailAddress;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? profileImageUrl;
  final String? linkedInUrl;
  final String? currentPosition;
  final String? currentCompany;
  final String? address;

  AlumniMember({
    required this.id,
    required this.fullName,
    required this.batchYear,
    required this.course,
    required this.contactNumber,
    required this.emailAddress,
    DateTime? createdAt,
    this.updatedAt,
    this.profileImageUrl,
    this.linkedInUrl,
    this.currentPosition,
    this.currentCompany,
    this.address,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert AlumniMember to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'fullName': fullName,
      'batchYear': batchYear,
      'course': course,
      'contactNumber': contactNumber,
      'emailAddress': emailAddress,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'profileImageUrl': profileImageUrl,
      'linkedInUrl': linkedInUrl,
      'currentPosition': currentPosition,
      'currentCompany': currentCompany,
      'address': address,
    };
  }

  /// Create AlumniMember from Firestore document
  factory AlumniMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlumniMember(
      id: data['id'] ?? doc.id,
      fullName: data['fullName'] ?? '',
      batchYear: data['batchYear'] ?? '',
      course: data['course'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      emailAddress: data['emailAddress'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      profileImageUrl: data['profileImageUrl'],
      linkedInUrl: data['linkedInUrl'],
      currentPosition: data['currentPosition'],
      currentCompany: data['currentCompany'],
      address: data['address'],
    );
  }

  /// Create a copy of AlumniMember with modified fields
  AlumniMember copyWith({
    String? id,
    String? fullName,
    String? batchYear,
    String? course,
    String? contactNumber,
    String? emailAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profileImageUrl,
    String? linkedInUrl,
    String? currentPosition,
    String? currentCompany,
    String? address,
  }) {
    return AlumniMember(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      batchYear: batchYear ?? this.batchYear,
      course: course ?? this.course,
      contactNumber: contactNumber ?? this.contactNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      linkedInUrl: linkedInUrl ?? this.linkedInUrl,
      currentPosition: currentPosition ?? this.currentPosition,
      currentCompany: currentCompany ?? this.currentCompany,
      address: address ?? this.address,
    );
  }
}

