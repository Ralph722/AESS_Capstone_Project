class EmploymentRecord {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String schoolId;
  final String employmentStatus; // 'Employed', 'Unemployed' or 'Never Employed'
  final int? monthsUnemployed;

  // Employment details (if employed)
  final String? companyName;
  final String? position;
  final String? industry;
  final String? employmentType; // CHED Q18, e.g. 'Regular or Permanent'
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
  final String verificationStatus; // 'Submitted' (self-reported GTS answer)
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
  }) : submittedAt = submittedAt ?? DateTime.now(),
       lastUpdated = lastUpdated ?? DateTime.now();

  /// Reads a `public.gts_employment_records` row.
  factory EmploymentRecord.fromSupabaseRow(Map<String, dynamic> row) {
    final data = row['data'] as Map<String, dynamic>? ?? {};
    return EmploymentRecord(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      userName: data['userName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      schoolId: data['schoolId'] as String? ?? '',
      employmentStatus: row['status'] as String? ?? 'Unemployed',
      monthsUnemployed: data['monthsUnemployed'] as int?,
      companyName: row['company'] as String?,
      position: row['position'] as String?,
      industry: data['industry'] as String?,
      employmentType: data['employmentType'] as String?,
      startDate: row['start_date'] != null
          ? _parseDateTime(row['start_date'])
          : null,
      salaryRange: data['salaryRange'] as String?,
      city: data['city'] as String?,
      province: data['province'] as String?,
      country: data['country'] as String?,
      contactNumber: data['contactNumber'] as String? ?? '',
      submittedAt: _parseDateTime(row['created_at']),
      lastUpdated: _parseDateTime(row['updated_at']),
      verifiedBy: row['verified_by'] as String?,
      verifiedAt: row['verified_at'] != null
          ? _parseDateTime(row['verified_at'])
          : null,
      verificationStatus: row['verification_status'] as String? ?? 'Pending',
      notes: data['notes'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
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
