import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';

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
  };

  factory AlumniCardData.fromJson(Map<String, dynamic> json) {
    final sinceRaw = json['memberSince'];
    final since = sinceRaw is DateTime
        ? sinceRaw.toUtc()
        : DateTime.tryParse(sinceRaw?.toString() ?? '')?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final photo = json['profileImageUrl']?.toString().trim();
    final sexRaw = (json['sex'] ?? json['gender'] ?? '').toString();
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
    );
  }

  factory AlumniCardData.fromMember(
    AlumniMember member, {
    String? profileImageUrl,
    String? sex,
    String campus = 'USTP Oroquieta',
  }) {
    final email = (member.registeredEmail?.trim().isNotEmpty == true)
        ? member.registeredEmail!.trim()
        : member.emailAddress.trim();
    final sexRaw = (sex != null && sex.trim().isNotEmpty)
        ? sex
        : member.gender;
    return AlumniCardData(
      fullName: member.fullName.trim().isEmpty
          ? 'Alumni'
          : member.fullName.trim(),
      program: member.course.trim(),
      studentId: member.studentId.trim(),
      batchYear: member.effectiveBatchYear,
      sex: _formatSex(sexRaw),
      email: email,
      memberSince: member.createdAt,
      campus: campus,
      profileImageUrl: profileImageUrl?.trim().isNotEmpty == true
          ? profileImageUrl!.trim()
          : member.profileImageUrl,
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
