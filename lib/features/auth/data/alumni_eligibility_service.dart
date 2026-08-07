import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/core/services/supabase_user_bridge.dart';

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
/// Supabase RPCs only — order: RPC → local Supabase table fallback.
class AlumniEligibilityService {
  AlumniEligibilityService({
    SupabaseClient? supabase,
    AlumniMemberService? memberService,
    AuthService? authService,
    SupabaseUserBridge? bridge,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _memberService = memberService ?? AlumniMemberService(),
        _authService = authService ?? AuthService(),
        _bridge = bridge ?? SupabaseUserBridge(client: supabase);

  final SupabaseClient _supabase;
  final AlumniMemberService _memberService;
  final AuthService _authService;
  final SupabaseUserBridge _bridge;

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
      final supabaseResult = await _validateViaSupabaseRpc(
        fullName: fullName.trim(),
        course: prog,
        studentId: sid,
      );
      if (supabaseResult != null) return supabaseResult;

      return await _validateLocally(
        fullName: fullName.trim(),
        course: prog,
        studentId: sid,
      );
    } catch (e) {
      return AlumniEligibilityResult(
        eligible: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<AlumniEligibilityResult?> _validateViaSupabaseRpc({
    required String fullName,
    required String course,
    required String studentId,
  }) async {
    try {
      final raw = await _supabase.rpc(
        'validate_alumni_eligibility',
        params: {
          'p_full_name': fullName,
          'p_student_id': studentId,
          'p_course': course,
        },
      );
      if (raw is! Map) return null;
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
      return null;
    }
  }

  Future<AlumniEligibilityResult> _validateLocally({
    required String fullName,
    required String course,
    required String studentId,
  }) async {
    final member = await _memberService.findByStudentIdAndCourse(
      studentId: studentId,
      course: course,
      registrationLookup: true,
    );

    if (member == null) {
      return const AlumniEligibilityResult(
        eligible: false,
        message:
            'You are not listed as an official alumni member. '
            'Please contact the alumni office.',
      );
    }

    if (member.isDeactivated) {
      return const AlumniEligibilityResult(
        eligible: false,
        message:
            'This alumni record has been deactivated. Please contact the alumni office.',
      );
    }

    if (member.isRegisteredUser) {
      return const AlumniEligibilityResult(
        eligible: false,
        message:
            'This ID number is already registered. Try logging in instead.',
      );
    }

    final rosterName = AlumniMemberService.normalizeFullName(member.fullName)
        .toLowerCase();
    final inputName =
        AlumniMemberService.normalizeFullName(fullName).toLowerCase();

    if (rosterName != inputName) {
      return const AlumniEligibilityResult(
        eligible: false,
        message:
            'The full name does not match our official records. '
            'Use the exact name on your school records.',
      );
    }

    return AlumniEligibilityResult(
      eligible: true,
      memberId: member.id,
      rosterFullName: member.fullName,
      course: course,
      studentId: studentId,
    );
  }

  Future<void> linkRegistration({
    required String memberId,
    required String fullName,
    required String course,
    required String studentId,
    required String email,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) {
      throw Exception('You must be signed in to complete registration.');
    }

    final prog = CourseConstants.normalize(course);
    final sid = AlumniMemberService.normalizeStudentId(studentId);
    final normalizedEmail = email.trim().toLowerCase();
    if (prog == null) {
      throw Exception('Select a valid course.');
    }

    final linkedViaSupabase = await _linkViaSupabaseRpc(
      memberId: memberId,
      fullName: fullName.trim(),
      course: prog,
      studentId: sid,
      email: normalizedEmail,
    );
    if (linkedViaSupabase) return;

    await _linkLocally(
      uid: userId,
      memberId: memberId,
      fullName: fullName.trim(),
      course: prog,
      studentId: sid,
      email: normalizedEmail,
    );
  }

  Future<bool> _linkViaSupabaseRpc({
    required String memberId,
    required String fullName,
    required String course,
    required String studentId,
    required String email,
  }) async {
    Map<String, dynamic>? data;
    try {
      final raw = await _supabase.rpc(
        'link_alumni_registration',
        params: {
          'p_member_id': memberId,
          'p_full_name': fullName,
          'p_student_id': studentId,
          'p_course': course,
          'p_email': email,
        },
      );
      if (raw is! Map) return false;
      data = Map<String, dynamic>.from(raw);
    } catch (_) {
      // RPC missing / network — fall back to direct table path.
      return false;
    }

    if (data['success'] == true) return true;

    final code = data['code']?.toString() ?? '';
    final message =
        data['message']?.toString() ?? 'Could not complete registration.';
    if (code == 'already_exists' ||
        code == 'failed_precondition' ||
        code == 'not_found' ||
        code == 'invalid_argument' ||
        code == 'unauthenticated') {
      throw Exception(message);
    }
    return false;
  }

  Future<void> _linkLocally({
    required String uid,
    required String memberId,
    required String fullName,
    required String course,
    required String studentId,
    required String email,
  }) async {
    final member = await _memberService.getMemberById(memberId);
    if (member == null) {
      throw Exception('Roster record not found. Please register again.');
    }

    if (AlumniMemberService.normalizeStudentId(member.studentId) != studentId ||
        CourseConstants.normalize(member.course) != course) {
      throw Exception('Roster details do not match.');
    }

    if (AlumniMemberService.normalizeFullName(member.fullName).toLowerCase() !=
        AlumniMemberService.normalizeFullName(fullName).toLowerCase()) {
      throw Exception('Full name does not match roster.');
    }

    if (member.isRegisteredUser &&
        member.authUid != null &&
        member.authUid!.isNotEmpty &&
        member.authUid != uid) {
      throw Exception('This alumni ID is already linked to another account.');
    }

    final displayName =
        member.fullName.isNotEmpty ? member.fullName : fullName;

    await _authService.createAlumniUserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      studentId: studentId,
      course: course,
    );

    await _linkSupabaseRoster(
      supabaseUserId: uid,
      memberId: memberId,
      displayName: displayName,
      email: email,
      studentId: studentId,
      course: course,
    );
  }

  Future<void> _linkSupabaseRoster({
    required String supabaseUserId,
    required String memberId,
    required String displayName,
    required String email,
    required String studentId,
    required String course,
  }) async {
    final resolvedId =
        await _bridge.resolveSupabaseUserId(supabaseUserId) ?? supabaseUserId;

    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _supabase.from('alumni_members').update({
        'auth_uid': resolvedId,
        'is_registered_user': true,
        'registered_email': email,
        'full_name': displayName,
        'student_id': studentId,
        'course': course,
        'updated_at': now,
      }).eq('id', memberId);
    } catch (e) {
      throw Exception('Could not link alumni roster: $e');
    }
  }
}
