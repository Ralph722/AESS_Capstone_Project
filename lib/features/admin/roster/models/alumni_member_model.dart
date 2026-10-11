import 'package:alumni_system/core/utils/calendar_date.dart';

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

  /// Batch is the graduation year (`year_graduated`); kept as its own field
  /// for filters and exports.
  final String batchYear;

  // Legacy fields (older manual directory rows)
  final String contactNumber;
  final String emailAddress;
  final String? address;
  final String? gender;
  final String? civilStatus;
  final DateTime? birthDate;
  final String? yearGraduated;
  final bool tracerProfileComplete;

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
    this.address,
    this.gender,
    this.civilStatus,
    this.birthDate,
    this.yearGraduated,
    this.tracerProfileComplete = false,
  }) : createdAt = createdAt ?? DateTime.now();

  String get program => course;

  /// Batch year used for filters/exports.
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
      batchYear: (row['year_graduated'] as String? ?? '').trim(),
      contactNumber: row['contact_number'] as String? ?? '',
      emailAddress: row['email_address'] as String? ?? '',
      address: row['address'] as String?,
      gender: row['gender'] as String?,
      civilStatus: row['civil_status'] as String?,
      birthDate: row['birth_date'] != null
          ? _parseDateTime(row['birth_date'])
          : null,
      yearGraduated: row['year_graduated'] as String?,
      tracerProfileComplete: row['tracer_profile_complete'] == true,
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
      'contact_number': contactNumber,
      'email_address': emailAddress,
      'address': address,
      'gender': gender,
      'civil_status': civilStatus,
      'birth_date': CalendarDate.toDb(birthDate),
      'year_graduated': yearGraduated,
      'tracer_profile_complete': tracerProfileComplete,
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
      address: address ?? this.address,
      gender: gender ?? this.gender,
      civilStatus: civilStatus ?? this.civilStatus,
      birthDate: birthDate ?? this.birthDate,
      yearGraduated: yearGraduated ?? this.yearGraduated,
      tracerProfileComplete:
          tracerProfileComplete ?? this.tracerProfileComplete,
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

/// Filter roster by the latest CHED GTS employment answer.
enum AlumniEmploymentFilter { all, employed, unemployed }
