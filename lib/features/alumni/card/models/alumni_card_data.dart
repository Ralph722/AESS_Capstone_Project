import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';

/// Details shown on the digital alumni card (front and back).
class AlumniCardData {
  const AlumniCardData({
    required this.fullName,
    required this.program,
    required this.studentId,
    required this.batchYear,
    required this.sex,
    required this.email,
    required this.memberSince,
    required this.campus,
    this.profileImageUrl,
    this.birthDate,
    this.contactNumber = '',
    this.address = '',
  });

  final String fullName;
  final String program;
  final String studentId;
  final String batchYear;
  final String sex;
  final String email;
  final DateTime memberSince;
  final String campus;
  final String? profileImageUrl;

  /// Profile birthday (back face).
  final DateTime? birthDate;

  /// Mobile / contact number (back face).
  final String contactNumber;

  /// Home / permanent address (back face).
  final String address;

  /// Initials for the photo placeholder (up to two letters).
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return w.length >= 2 ? w.substring(0, 2).toUpperCase() : w.toUpperCase();
    }
    return ('${parts.first[0]}${parts.last[0]}').toUpperCase();
  }

  static const Object _unset = Object();

  AlumniCardData copyWith({
    String? fullName,
    String? program,
    String? studentId,
    String? batchYear,
    String? sex,
    String? email,
    DateTime? memberSince,
    String? campus,
    Object? profileImageUrl = _unset,
    Object? birthDate = _unset,
    String? contactNumber,
    String? address,
  }) {
    return AlumniCardData(
      fullName: fullName ?? this.fullName,
      program: program ?? this.program,
      studentId: studentId ?? this.studentId,
      batchYear: batchYear ?? this.batchYear,
      sex: sex ?? this.sex,
      email: email ?? this.email,
      memberSince: memberSince ?? this.memberSince,
      campus: campus ?? this.campus,
      profileImageUrl: identical(profileImageUrl, _unset)
          ? this.profileImageUrl
          : profileImageUrl as String?,
      birthDate: identical(birthDate, _unset)
          ? this.birthDate
          : birthDate as DateTime?,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'program': program,
    'studentId': studentId,
    'batchYear': batchYear,
    'sex': sex,
    'email': email,
    'memberSince': memberSince.toUtc().toIso8601String(),
    'campus': campus,
    'profileImageUrl': profileImageUrl,
    'birthDate': birthDate?.toUtc().toIso8601String(),
    'contactNumber': contactNumber,
    'address': address,
  };

  factory AlumniCardData.fromJson(Map<String, dynamic> json) {
    final sinceRaw = json['memberSince'];
    final since = sinceRaw is DateTime
        ? sinceRaw.toUtc()
        : DateTime.tryParse(sinceRaw?.toString() ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final photo = json['profileImageUrl']?.toString().trim();
    final sexRaw = (json['sex'] ?? json['gender'] ?? '').toString();
    final birthRaw = json['birthDate'];
    final birth = birthRaw is DateTime
        ? birthRaw.toUtc()
        : DateTime.tryParse(birthRaw?.toString() ?? '')?.toUtc();
    return AlumniCardData(
      fullName: (json['fullName'] ?? 'Alumni').toString(),
      program: (json['program'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      batchYear: (json['batchYear'] ?? '').toString(),
      sex: _formatSex(sexRaw),
      email: (json['email'] ?? '').toString(),
      memberSince: since,
      campus: (json['campus'] ?? 'USTP Oroquieta').toString(),
      profileImageUrl: (photo == null || photo.isEmpty) ? null : photo,
      birthDate: birth,
      contactNumber: (json['contactNumber'] ?? json['mobileNumber'] ?? '')
          .toString(),
      address: (json['address'] ?? '').toString(),
    );
  }

  factory AlumniCardData.fromMember(
    AlumniMember member, {
    String? profileImageUrl,
    String? sex,
    String campus = 'USTP Oroquieta',
    TracerProfile? profile,
  }) {
    final email = (member.registeredEmail?.trim().isNotEmpty == true)
        ? member.registeredEmail!.trim()
        : member.emailAddress.trim();
    final sexRaw = (sex != null && sex.trim().isNotEmpty)
        ? sex
        : (profile?.gender.isNotEmpty == true
              ? profile!.gender
              : member.gender);
    final program = (profile?.program.trim().isNotEmpty == true)
        ? profile!.program.trim()
        : member.course.trim();
    return AlumniCardData(
      fullName: member.fullName.trim().isEmpty
          ? 'Alumni'
          : member.fullName.trim(),
      program: program,
      studentId: member.studentId.trim(),
      batchYear: member.effectiveBatchYear,
      sex: _formatSex(sexRaw),
      email: email,
      memberSince: member.createdAt,
      campus: campus,
      profileImageUrl: profileImageUrl?.trim().isNotEmpty == true
          ? profileImageUrl!.trim()
          : member.profileImageUrl,
      birthDate: profile?.birthDate,
      contactNumber: profile?.mobileNumber.trim() ?? '',
      address: profile?.address.trim() ?? '',
    );
  }

  /// Normalizes roster/profile gender values for the card (e.g. Male / Female).
  static String _formatSex(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    final lower = v.toLowerCase();
    if (lower == 'm' || lower == 'male') return 'Male';
    if (lower == 'f' || lower == 'female') return 'Female';
    if (v.length == 1) return v.toUpperCase();
    return '${v[0].toUpperCase()}${v.substring(1)}';
  }
}

/// Outcome of loading the signed-in alumnus's card.
enum AlumniCardStatus { unmatched, deactivated, ready }

class AlumniCardLoadResult {
  const AlumniCardLoadResult._(this.status, {this.data, this.offline = false});

  const AlumniCardLoadResult.unmatched() : this._(AlumniCardStatus.unmatched);
  const AlumniCardLoadResult.deactivated()
    : this._(AlumniCardStatus.deactivated);
  const AlumniCardLoadResult.ready(AlumniCardData data, {bool offline = false})
    : this._(AlumniCardStatus.ready, data: data, offline: offline);

  final AlumniCardStatus status;
  final AlumniCardData? data;

  /// True when [data] came from the local cache because the network failed.
  final bool offline;
}
