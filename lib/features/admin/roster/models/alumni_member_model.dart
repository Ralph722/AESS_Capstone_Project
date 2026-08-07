/// Official alumni roster entry (`alumni_members/{id}`).
class AlumniMember {
  final String id;
  final String fullName;
  final String course;
  final String studentId;

  final String? authUid;
  final String? registeredEmail;
  final bool isRegisteredUser;
  final bool isDeactivated;

  final String? profileImageUrl;
  final DateTime? lastActiveAt;
  final bool hasProfileUpdates;
  final DateTime? adminViewedAt;

  final DateTime createdAt;
  final DateTime? updatedAt;

  // Legacy fields (older manual directory rows)
  final String batchYear;
  final String contactNumber;
  final String emailAddress;
  final String? currentPosition;
  final String? currentCompany;
  final String? address;
  final String? gender;
  final String? civilStatus;
  final DateTime? birthDate;
  final String? yearGraduated;
  final bool tracerProfileComplete;

  /// Latest employment tracer status (Employed / Unemployed), mirrored from submissions.
  final String? employmentStatus;

  AlumniMember({
    required this.id,
    required this.fullName,
    required this.course,
    required this.studentId,
    this.authUid,
    this.registeredEmail,
    this.isRegisteredUser = false,
    this.isDeactivated = false,
    this.profileImageUrl,
    this.lastActiveAt,
    this.hasProfileUpdates = false,
    this.adminViewedAt,
    DateTime? createdAt,
    this.updatedAt,
    this.batchYear = '',
    this.contactNumber = '',
    this.emailAddress = '',
    this.currentPosition,
    this.currentCompany,
    this.address,
    this.gender,
    this.civilStatus,
    this.birthDate,
    this.yearGraduated,
    this.tracerProfileComplete = false,
    this.employmentStatus,
  }) : createdAt = createdAt ?? DateTime.now();

  String get program => course;

  /// Batch year used for filters/exports. Prefer roster `batch_year`, then
  /// `year_graduated` (legacy / profile-synced rows often leave one blank).
  String get effectiveBatchYear {
    final batch = batchYear.trim();
    if (batch.isNotEmpty) return batch;
    return (yearGraduated ?? '').trim();
  }

  bool get isOnRoster => !isDeactivated;

  bool isActiveWithin(Duration window) {
    if (!isRegisteredUser || lastActiveAt == null) return false;
    return DateTime.now().difference(lastActiveAt!) <= window;
  }

  factory AlumniMember.fromSupabaseRow(Map<String, dynamic> row) {
    return AlumniMember(
      id: row['id']?.toString() ?? '',
      fullName: row['full_name'] as String? ?? '',
      course: (row['course'] as String? ?? '').trim(),
      studentId: (row['student_id'] as String? ?? '').trim(),
      authUid: row['auth_uid']?.toString(),
      registeredEmail: row['registered_email'] as String?,
      isRegisteredUser: row['is_registered_user'] == true,
      isDeactivated: row['is_deactivated'] == true,
      profileImageUrl: row['profile_image_url'] as String?,
      lastActiveAt: row['last_active_at'] != null
          ? _parseDateTime(row['last_active_at'])
          : null,
      hasProfileUpdates: row['has_profile_updates'] == true,
      adminViewedAt: row['admin_viewed_at'] != null
          ? _parseDateTime(row['admin_viewed_at'])
          : null,
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: row['updated_at'] != null
          ? _parseDateTime(row['updated_at'])
          : null,
      batchYear: row['batch_year'] as String? ?? '',
      contactNumber: row['contact_number'] as String? ?? '',
      emailAddress: row['email_address'] as String? ?? '',
      currentPosition: row['current_position'] as String?,
      currentCompany: row['current_company'] as String?,
      address: row['address'] as String?,
      gender: row['gender'] as String?,
      civilStatus: row['civil_status'] as String?,
      birthDate: row['birth_date'] != null
          ? _parseDateTime(row['birth_date'])
          : null,
      yearGraduated: row['year_graduated'] as String?,
      tracerProfileComplete: row['tracer_profile_complete'] == true,
      employmentStatus: row['employment_status'] as String?,
    );
  }

  Map<String, dynamic> toSupabaseRow({String? authSupabaseId}) {
    return {
      'id': id,
      'full_name': fullName,
      'course': course,
      'student_id': studentId,
      if (authSupabaseId != null) 'auth_uid': authSupabaseId,
      'registered_email': registeredEmail,
      'is_registered_user': isRegisteredUser,
      'is_deactivated': isDeactivated,
      'profile_image_url': profileImageUrl,
      'last_active_at': lastActiveAt?.toUtc().toIso8601String(),
      'has_profile_updates': hasProfileUpdates,
      'admin_viewed_at': adminViewedAt?.toUtc().toIso8601String(),
      'batch_year': batchYear,
      'contact_number': contactNumber,
      'email_address': emailAddress,
      'current_position': currentPosition,
      'current_company': currentCompany,
      'address': address,
      'gender': gender,
      'civil_status': civilStatus,
      'birth_date': birthDate?.toUtc().toIso8601String().split('T').first,
      'year_graduated': yearGraduated,
      'tracer_profile_complete': tracerProfileComplete,
      'employment_status': employmentStatus,
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

  AlumniMember copyWith({
    String? id,
    String? fullName,
    String? course,
    String? studentId,
    String? authUid,
    String? registeredEmail,
    bool? isRegisteredUser,
    bool? isDeactivated,
    String? profileImageUrl,
    DateTime? lastActiveAt,
    bool? hasProfileUpdates,
    DateTime? adminViewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? batchYear,
    String? contactNumber,
    String? emailAddress,
    String? currentPosition,
    String? currentCompany,
    String? address,
    String? gender,
    String? civilStatus,
    DateTime? birthDate,
    String? yearGraduated,
    bool? tracerProfileComplete,
  }) {
    return AlumniMember(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      course: course ?? this.course,
      studentId: studentId ?? this.studentId,
      authUid: authUid ?? this.authUid,
      registeredEmail: registeredEmail ?? this.registeredEmail,
      isRegisteredUser: isRegisteredUser ?? this.isRegisteredUser,
      isDeactivated: isDeactivated ?? this.isDeactivated,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      hasProfileUpdates: hasProfileUpdates ?? this.hasProfileUpdates,
      adminViewedAt: adminViewedAt ?? this.adminViewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      batchYear: batchYear ?? this.batchYear,
      contactNumber: contactNumber ?? this.contactNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      currentPosition: currentPosition ?? this.currentPosition,
      currentCompany: currentCompany ?? this.currentCompany,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      civilStatus: civilStatus ?? this.civilStatus,
      birthDate: birthDate ?? this.birthDate,
      yearGraduated: yearGraduated ?? this.yearGraduated,
      tracerProfileComplete:
          tracerProfileComplete ?? this.tracerProfileComplete,
      employmentStatus: employmentStatus ?? this.employmentStatus,
    );
  }
}

/// Lookup tables for admin directory employment filters.
class EmploymentStatusIndex {
  const EmploymentStatusIndex({
    this.byAuthUid = const {},
    this.bySchoolId = const {},
  });

  final Map<String, String> byAuthUid;
  final Map<String, String> bySchoolId;

  bool get isEmpty => byAuthUid.isEmpty && bySchoolId.isEmpty;
}

enum AlumniDirectorySort {
  nameAsc,
  nameDesc,
  studentIdAsc,
  courseAsc,
  createdNewest,
  lastActiveNewest,
}

enum AlumniRegistrationFilter { all, registered, notRegistered }

enum AlumniActiveFilter { all, active7, active30, active90, inactive }

/// Filter roster by latest employment tracer submission.
enum AlumniEmploymentFilter { all, employed, unemployed }
