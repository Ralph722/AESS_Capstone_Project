import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/app_session.dart';

class AlumniEligibilityResult {
  const AlumniEligibilityResult({
    required this.eligible,
    this.memberId,
    this.rosterFullName,
    this.course,
    this.studentId,
    this.message,
  });

  final bool eligible;
  final String? memberId;
  final String? rosterFullName;
  final String? course;
  final String? studentId;
  final String? message;
}

/// Validates roster eligibility and links accounts after registration.
///
/// Both steps run in database functions; the roster table itself is not
/// readable before sign-in or writable by alumni.
class AlumniEligibilityService {
  AlumniEligibilityService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<AlumniEligibilityResult> validate({
    required String fullName,
    required String course,
    required String studentId,
  }) async {
    final prog = CourseConstants.normalize(course);
    final sid = AlumniMemberService.normalizeStudentId(studentId);

    if (fullName.trim().isEmpty || sid.isEmpty || prog == null) {
      return const AlumniEligibilityResult(
        eligible: false,
        message: 'Please complete all fields.',
      );
    }

    try {
      final raw = await _supabase.rpc(
        'validate_alumni_eligibility',
        params: {
          'p_full_name': fullName.trim(),
          'p_student_id': sid,
          'p_course': prog,
        },
      );
      if (raw is! Map) throw const FormatException();
      final data = Map<String, dynamic>.from(raw);
      final eligible = data['eligible'] == true;
      return AlumniEligibilityResult(
        eligible: eligible,
        memberId: data['memberId']?.toString(),
        rosterFullName: data['rosterFullName']?.toString(),
        course: data['course']?.toString(),
        studentId: data['studentId']?.toString(),
        message: eligible ? null : data['message']?.toString(),
      );
    } catch (_) {
      return const AlumniEligibilityResult(
        eligible: false,
        message:
            'Could not check the alumni roster right now. '
            'Check your connection and try again.',
      );
    }
  }

  /// Links the signed-in, email-verified account to its roster record.
  Future<void> linkRegistration({
    required String memberId,
    required String fullName,
    required String course,
    required String studentId,
    required String email,
  }) async {
    if (AppSession.userId == null) {
      throw Exception('You must be signed in to complete registration.');
    }

    final prog = CourseConstants.normalize(course);
    if (prog == null) {
      throw Exception('Select a valid course.');
    }

    final Object? raw;
    try {
      raw = await _supabase.rpc(
        'link_alumni_registration',
        params: {
          'p_member_id': memberId,
          'p_full_name': fullName.trim(),
          'p_student_id': AlumniMemberService.normalizeStudentId(studentId),
          'p_course': prog,
          'p_email': email.trim().toLowerCase(),
        },
      );
    } catch (_) {
      throw Exception(
        'Could not complete registration. Check your connection and try again.',
      );
    }

    final data = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    if (data['ok'] == true) return;
    throw Exception(
      data['message']?.toString() ?? 'Could not complete registration.',
    );
  }
}
