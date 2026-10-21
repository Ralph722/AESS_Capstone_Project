import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/core/utils/calendar_date.dart';

/// Live alumni profile stored on `public.users` — GTS Section A, B item 12, employment status.
class TracerProfile {
  final String uid;
  final String email;
  final String displayName;
  final String studentId;
  final String program;
  final String batchYear;
  final String yearGraduated;
  final String telephoneNumber;
  final String mobileNumber;
  final String address;
  final String gender;
  final String civilStatus;
  final DateTime? birthDate;
  final String regionOfOrigin;
  final String province;
  final String locationOfResidence;
  final String collegeUniversity;
  final String honorsAwards;
  final String employmentStatus;
  final double completionPercent;
  final bool isComplete;
  final DateTime? completedAt;

  /// Verified contact email (`users.contact_email`), separate from the login
  /// [email]. Read-only here: saved by contact-verify `apply_email`.
  /// Empty on profiles built from form fields.
  final String contactEmail;
  final DateTime? contactEmailVerifiedAt;

  /// Set only after a real SMS check.
  final DateTime? mobileVerifiedAt;

  /// `sms`, `mock` (demo code while SMS is not integrated) or empty.
  final String mobileVerificationMethod;

  const TracerProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.studentId,
    required this.program,
    required this.batchYear,
    required this.yearGraduated,
    this.telephoneNumber = '',
    this.mobileNumber = '',
    this.address = '',
    this.gender = '',
    this.civilStatus = '',
    this.birthDate,
    this.regionOfOrigin = '',
    this.province = '',
    this.locationOfResidence = '',
    this.collegeUniversity = '',
    this.honorsAwards = '',
    this.employmentStatus = '',
    this.completionPercent = 0,
    this.isComplete = false,
    this.completedAt,
    this.contactEmail = '',
    this.contactEmailVerifiedAt,
    this.mobileVerifiedAt,
    this.mobileVerificationMethod = '',
  });

  /// Legacy alias — mobile number is the primary contact field.
  String get contactNumber => mobileNumber;

  /// The email to contact the alumnus at: [contactEmail], else the login.
  String get preferredEmail =>
      contactEmail.trim().isNotEmpty ? contactEmail.trim() : email.trim();

  /// The login email was confirmed at registration, so it counts as verified.
  bool get contactEmailVerified =>
      contactEmailVerifiedAt != null ||
      preferredEmail.toLowerCase() == email.trim().toLowerCase();

  bool get mobileVerified => mobileVerifiedAt != null;

  /// Confirmed with a demo code; still needs an SMS check once available.
  bool get mobileDemoConfirmed =>
      !mobileVerified && mobileVerificationMethod == 'mock';

  /// GTS Section A + B item 12 (employment collected separately in onboarding).
  static const profileRequiredFieldKeys = [
    'displayName',
    'address',
    'email',
    'telephoneNumber',
    'mobileNumber',
    'civilStatus',
    'gender',
    'birthDate',
    'regionOfOrigin',
    'province',
    'locationOfResidence',
    'program',
    'collegeUniversity',
    'yearGraduated',
  ];

  /// Full live profile including employment status.
  static const requiredFieldKeys = [
    ...profileRequiredFieldKeys,
    'employmentStatus',
  ];

  static List<bool> _profileCompletionChecks(Map<String, dynamic> data) => [
        _readString(data, 'displayName').trim().isNotEmpty,
        _readString(data, 'address').trim().isNotEmpty,
        _readString(data, 'email').trim().isNotEmpty,
        _readString(data, 'telephoneNumber').trim().isNotEmpty,
        _readContact(data).trim().isNotEmpty,
        _readString(data, 'civilStatus').trim().isNotEmpty,
        _readString(data, 'gender').trim().isNotEmpty,
        data['birthDate'] != null,
        _readString(data, 'regionOfOrigin').trim().isNotEmpty,
        _readString(data, 'province').trim().isNotEmpty,
        _readString(data, 'locationOfResidence').trim().isNotEmpty,
        _readProgram(data).trim().isNotEmpty,
        _readString(data, 'collegeUniversity').trim().isNotEmpty,
        _readString(data, 'yearGraduated').trim().isNotEmpty,
      ];

  static double computeProfileCompletion(Map<String, dynamic> data) {
    final checks = _profileCompletionChecks(data);
    final filled = checks.where((v) => v).length;
    return (filled / profileRequiredFieldKeys.length) * 100;
  }

  static int countFilledProfileFields(Map<String, dynamic> data) =>
      _profileCompletionChecks(data).where((v) => v).length;

  static int countFilledRequiredFields(Map<String, dynamic> data) {
    final checks = [
      ..._profileCompletionChecks(data),
      _readString(data, 'employmentStatus').trim().isNotEmpty,
    ];
    return checks.where((v) => v).length;
  }

  /// Keys from [requiredFieldKeys] that are still empty in [data].
  static List<String> missingRequiredKeys(Map<String, dynamic> data) {
    final checks = [
      ..._profileCompletionChecks(data),
      _readString(data, 'employmentStatus').trim().isNotEmpty,
    ];
    return [
      for (var i = 0; i < requiredFieldKeys.length; i++)
        if (!checks[i]) requiredFieldKeys[i],
    ];
  }

  static int get profileFieldCount => profileRequiredFieldKeys.length;

  static int get fullProfileFieldCount => requiredFieldKeys.length;

  static double computeCompletion(Map<String, dynamic> data) {
    final checks = [
      ..._profileCompletionChecks(data),
      _readString(data, 'employmentStatus').trim().isNotEmpty,
    ];
    final filled = checks.where((v) => v).length;
    return (filled / requiredFieldKeys.length) * 100;
  }

  static String _readString(Map<String, dynamic> data, String key) {
    final v = data[key];
    return v == null ? '' : v.toString();
  }

  static String _readProgram(Map<String, dynamic> data) {
    return _readString(data, 'program').isNotEmpty
        ? _readString(data, 'program')
        : _readString(data, 'course');
  }

  static String _readContact(Map<String, dynamic> data) {
    return _readString(data, 'mobileNumber').isNotEmpty
        ? _readString(data, 'mobileNumber')
        : _readString(data, 'contactNumber').isNotEmpty
            ? _readString(data, 'contactNumber')
            : _readString(data, 'phoneNumber');
  }

  factory TracerProfile.fromSupabaseRow(Map<String, dynamic> row) {
    final program = (row['program'] as String? ?? '').trim();
    final mobile = (row['mobile_number'] as String? ?? '').trim();
    final yearGraduated = (row['year_graduated'] as String? ?? '').trim();

    final completionData = {
      'displayName': row['display_name'],
      'address': row['address'],
      'email': row['email'],
      'telephoneNumber': row['telephone_number'],
      'mobileNumber': mobile,
      'civilStatus': row['civil_status'],
      'gender': row['gender'],
      'birthDate': row['birth_date'] != null
          ? DateTime.tryParse(row['birth_date'].toString())
          : null,
      'regionOfOrigin': row['region_of_origin'],
      'province': row['province'],
      'locationOfResidence': row['location_of_residence'],
      'program': program,
      'collegeUniversity': row['college_university'],
      'yearGraduated': yearGraduated,
      'employmentStatus': row['employment_status'],
    };

    final storedCompletion =
        (row['tracer_profile_completion'] as num?)?.toDouble();
    final resolvedCompletion =
        storedCompletion ?? computeCompletion(completionData);
    final isComplete =
        row['tracer_profile_complete'] == true || resolvedCompletion >= 100;

    return TracerProfile(
      uid: row['id'] as String? ?? '',
      email: row['email'] as String? ?? '',
      displayName: row['display_name'] as String? ?? '',
      studentId: row['student_id'] as String? ?? '',
      program: program,
      batchYear: yearGraduated,
      yearGraduated: yearGraduated,
      telephoneNumber: row['telephone_number'] as String? ?? '',
      mobileNumber: mobile,
      address: row['address'] as String? ?? '',
      gender: row['gender'] as String? ?? '',
      civilStatus: row['civil_status'] as String? ?? '',
      birthDate: row['birth_date'] != null
          ? DateTime.tryParse(row['birth_date'].toString())
          : null,
      regionOfOrigin: row['region_of_origin'] as String? ?? '',
      province: row['province'] as String? ?? '',
      locationOfResidence: row['location_of_residence'] as String? ?? '',
      collegeUniversity: row['college_university'] as String? ?? '',
      honorsAwards: row['honors_awards'] as String? ?? '',
      employmentStatus: row['employment_status'] as String? ?? '',
      completionPercent: resolvedCompletion,
      isComplete: isComplete,
      completedAt: null,
      contactEmail: (row['contact_email'] as String? ?? '').trim(),
      contactEmailVerifiedAt: DateTime.tryParse(
        row['contact_email_verified_at']?.toString() ?? '',
      ),
      mobileVerifiedAt: DateTime.tryParse(
        row['mobile_verified_at']?.toString() ?? '',
      ),
      mobileVerificationMethod:
          (row['mobile_verification_method'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toSupabaseRow() {
    final completion = computeCompletion({
      'displayName': displayName,
      'address': address,
      'email': email,
      'telephoneNumber': telephoneNumber,
      'mobileNumber': mobileNumber,
      'civilStatus': civilStatus,
      'gender': gender,
      'birthDate': birthDate,
      'regionOfOrigin': regionOfOrigin,
      'province': province,
      'locationOfResidence': locationOfResidence,
      'program': program,
      'collegeUniversity': collegeUniversity,
      'yearGraduated': yearGraduated,
      'employmentStatus': employmentStatus,
    });
    final complete = completion >= 100;
    final mobile = mobileNumber.trim();
    final year = yearGraduated.trim().isNotEmpty
        ? yearGraduated.trim()
        : batchYear.trim();

    return {
      'id': uid,
      'email': email.trim(),
      'display_name': displayName.trim(),
      'student_id': studentId.trim(),
      'program': program.trim(),
      'year_graduated': year,
      'telephone_number': telephoneNumber.trim(),
      'mobile_number': mobile,
      'address': address.trim(),
      'gender': gender.trim(),
      'civil_status': civilStatus.trim(),
      'birth_date': CalendarDate.toDb(birthDate),
      'region_of_origin': regionOfOrigin.trim(),
      'province': province.trim(),
      'location_of_residence': locationOfResidence.trim(),
      'college_university': collegeUniversity.trim().isNotEmpty
          ? collegeUniversity.trim()
          : GtsConstants.defaultCollegeUniversity,
      'honors_awards': honorsAwards.trim(),
      'employment_status': employmentStatus.trim(),
      'tracer_profile_completion': completion.round(),
      'tracer_profile_complete': complete,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  TracerProfile copyWith({
    String? displayName,
    String? email,
    String? studentId,
    String? program,
    String? batchYear,
    String? yearGraduated,
    String? telephoneNumber,
    String? mobileNumber,
    String? address,
    String? gender,
    String? civilStatus,
    DateTime? birthDate,
    String? regionOfOrigin,
    String? province,
    String? locationOfResidence,
    String? collegeUniversity,
    String? honorsAwards,
    String? employmentStatus,
  }) {
    return TracerProfile(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      studentId: studentId ?? this.studentId,
      program: program ?? this.program,
      batchYear: batchYear ?? this.batchYear,
      yearGraduated: yearGraduated ?? this.yearGraduated,
      telephoneNumber: telephoneNumber ?? this.telephoneNumber,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      civilStatus: civilStatus ?? this.civilStatus,
      birthDate: birthDate ?? this.birthDate,
      regionOfOrigin: regionOfOrigin ?? this.regionOfOrigin,
      province: province ?? this.province,
      locationOfResidence: locationOfResidence ?? this.locationOfResidence,
      collegeUniversity: collegeUniversity ?? this.collegeUniversity,
      honorsAwards: honorsAwards ?? this.honorsAwards,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      contactEmail: contactEmail,
      contactEmailVerifiedAt: contactEmailVerifiedAt,
      mobileVerifiedAt: mobileVerifiedAt,
      mobileVerificationMethod: mobileVerificationMethod,
    );
  }
}

/// Row shown in admin "Registered alumni" tab.
class RegisteredAlumniRow {
  final TracerProfile profile;
  final bool hasEmploymentRecord;

  const RegisteredAlumniRow({
    required this.profile,
    this.hasEmploymentRecord = false,
  });
}
