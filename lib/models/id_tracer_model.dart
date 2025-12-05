import 'package:cloud_firestore/cloud_firestore.dart';

class EmploymentRecord {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String schoolId;
  final String employmentStatus; // 'Employed' or 'Unemployed'
  final int? monthsUnemployed;
  
  // Employment details (if employed)
  final String? companyName;
  final String? position;
  final String? industry;
  final String? employmentType; // 'Full-time', 'Part-time', 'Contract', 'Freelance', 'Self-employed'
  final DateTime? startDate;
  final String? salaryRange;
  
  // Location
  final String? city;
  final String? province;
  final String? country;
  
  // Contact information
  final String contactNumber;
  
  // Metadata
  final DateTime submittedAt;
  final DateTime lastUpdated;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String verificationStatus; // 'Pending', 'Verified', 'Rejected'
  final String? notes;

  EmploymentRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.schoolId,
    required this.employmentStatus,
    this.monthsUnemployed,
    this.companyName,
    this.position,
    this.industry,
    this.employmentType,
    this.startDate,
    this.salaryRange,
    this.city,
    this.province,
    this.country,
    required this.contactNumber,
    DateTime? submittedAt,
    DateTime? lastUpdated,
    this.verifiedBy,
    this.verifiedAt,
    this.verificationStatus = 'Pending',
    this.notes,
  })  : submittedAt = submittedAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  /// Convert EmploymentRecord to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'schoolId': schoolId,
      'employmentStatus': employmentStatus,
      'monthsUnemployed': monthsUnemployed,
      'companyName': companyName,
      'position': position,
      'industry': industry,
      'employmentType': employmentType,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'salaryRange': salaryRange,
      'city': city,
      'province': province,
      'country': country,
      'contactNumber': contactNumber,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'verificationStatus': verificationStatus,
      'notes': notes,
    };
  }

  /// Create EmploymentRecord from Firestore document
  factory EmploymentRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmploymentRecord(
      id: data['id'] ?? doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      schoolId: data['schoolId'] ?? '',
      employmentStatus: data['employmentStatus'] ?? 'Unemployed',
      monthsUnemployed: data['monthsUnemployed'] as int?,
      companyName: data['companyName'] as String?,
      position: data['position'] as String?,
      industry: data['industry'] as String?,
      employmentType: data['employmentType'] as String?,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      salaryRange: data['salaryRange'] as String?,
      city: data['city'] as String?,
      province: data['province'] as String?,
      country: data['country'] as String?,
      contactNumber: data['contactNumber'] ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedBy: data['verifiedBy'] as String?,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      verificationStatus: data['verificationStatus'] ?? 'Pending',
      notes: data['notes'] as String?,
    );
  }

  /// Create a copy of EmploymentRecord with modified fields
  EmploymentRecord copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? schoolId,
    String? employmentStatus,
    int? monthsUnemployed,
    String? companyName,
    String? position,
    String? industry,
    String? employmentType,
    DateTime? startDate,
    String? salaryRange,
    String? city,
    String? province,
    String? country,
    String? contactNumber,
    DateTime? submittedAt,
    DateTime? lastUpdated,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? verificationStatus,
    String? notes,
  }) {
    return EmploymentRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      schoolId: schoolId ?? this.schoolId,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      monthsUnemployed: monthsUnemployed ?? this.monthsUnemployed,
      companyName: companyName ?? this.companyName,
      position: position ?? this.position,
      industry: industry ?? this.industry,
      employmentType: employmentType ?? this.employmentType,
      startDate: startDate ?? this.startDate,
      salaryRange: salaryRange ?? this.salaryRange,
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      contactNumber: contactNumber ?? this.contactNumber,
      submittedAt: submittedAt ?? this.submittedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      notes: notes ?? this.notes,
    );
  }
}


