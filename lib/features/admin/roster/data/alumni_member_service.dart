import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/core/services/supabase_user_bridge.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';

class AlumniMemberDuplicateException implements Exception {
  AlumniMemberDuplicateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Official alumni roster — Supabase only.
class AlumniMemberService {
  AlumniMemberService({SupabaseClient? supabase, SupabaseUserBridge? bridge})
    : _supabase = supabase ?? Supabase.instance.client,
      _bridge = bridge ?? SupabaseUserBridge(client: supabase);

  final SupabaseClient _supabase;
  final SupabaseUserBridge _bridge;

  static String normalizeStudentId(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static String normalizeFullName(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<AlumniMember?> findByStudentIdAndCourse({
    required String studentId,
    required String course,
    bool registrationLookup = false,
  }) async {
    final sid = normalizeStudentId(studentId);
    final prog = CourseConstants.normalize(course);
    if (sid.isEmpty || prog == null) return null;

    try {
      final rows = await _supabase
          .from('alumni_members')
          .select()
          .eq('student_id', sid)
          .eq('course', prog)
          .limit(1);
      if (rows.isNotEmpty) {
        return AlumniMember.fromSupabaseRow(rows.first);
      }
      return null;
    } catch (e) {
      throw Exception('Error looking up alumni member: $e');
    }
  }

  Future<void> assertNotDuplicate({
    required String studentId,
    required String course,
    String? excludeMemberId,
  }) async {
    final existing = await findByStudentIdAndCourse(
      studentId: studentId,
      course: course,
    );
    if (existing != null && existing.id != excludeMemberId) {
      throw AlumniMemberDuplicateException(
        'An alumni with this ID number and course already exists.',
      );
    }
  }

  /// Four-digit graduation year, or '' when [raw] is blank.
  static String normalizeGraduationYear(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final match = RegExp(r'(19|20)\d{2}').firstMatch(value);
    if (match == null) {
      throw Exception('Enter the year graduated as a 4-digit year.');
    }
    return match.group(0)!;
  }

  Future<AlumniMember> createMember({
    required String fullName,
    required String course,
    required String studentId,
    String yearGraduated = '',
    bool skipDuplicateCheck = false,
  }) async {
    final name = normalizeFullName(fullName);
    final sid = normalizeStudentId(studentId);
    final prog = CourseConstants.normalize(course);

    if (name.isEmpty || sid.isEmpty) {
      throw Exception('Full name and ID number are required.');
    }
    if (prog == null || !CourseConstants.isValid(prog)) {
      throw Exception('Select a valid course.');
    }
    final year = normalizeGraduationYear(yearGraduated);

    if (!skipDuplicateCheck) {
      await assertNotDuplicate(studentId: sid, course: prog);
    }

    final member = AlumniMember(
      id: LocalId.generate(),
      fullName: name,
      course: prog,
      studentId: sid,
      batchYear: year,
      yearGraduated: year.isEmpty ? null : year,
    );

    await _upsertMemberToSupabase(member);
    return member;
  }

  Future<AlumniMember> createMemberLegacy(AlumniMember member) async {
    return createMember(
      fullName: member.fullName,
      course: member.course.isNotEmpty
          ? member.course
          : CourseConstants.courses.first,
      studentId: member.studentId.isNotEmpty
          ? member.studentId
          : 'LEGACY-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Student-id + course keys already on the roster (for bulk import).
  Future<Set<String>> existingStudentCourseKeys() async {
    try {
      final rows = await _supabase
          .from('alumni_members')
          .select('student_id, course');
      final keys = <String>{};
      for (final row in rows) {
        final sid = normalizeStudentId(row['student_id'] as String? ?? '');
        final prog = CourseConstants.normalize(row['course'] as String? ?? '');
        if (sid.isNotEmpty && prog != null) {
          keys.add(_studentCourseKey(sid, prog));
        }
      }
      return keys;
    } catch (e) {
      throw Exception('Error loading roster keys: $e');
    }
  }

  static String studentCourseKey(String studentId, String course) =>
      _studentCourseKey(studentId, course);

  static String _studentCourseKey(String studentId, String course) =>
      '$studentId|$course';

  Future<List<AlumniMember>> getAllMembers({
    bool includeDeactivated = true,
  }) async {
    try {
      var list = await _fetchMembersFromSupabase();
      list = await _hydrateProfileImages(list);
      list = await _hydrateBatchYearsFromUsers(list);
      if (!includeDeactivated) {
        list = list.where((m) => !m.isDeactivated).toList();
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      throw Exception('Error fetching members: $e');
    }
  }

  /// Roster rows without a graduation year fall back to the year on the
  /// linked `users` profile. Fill in-memory for filters.
  Future<List<AlumniMember>> _hydrateBatchYearsFromUsers(
    List<AlumniMember> members,
  ) async {
    final needUids = members
        .where((m) => m.effectiveBatchYear.isEmpty)
        .map((m) => m.authUid?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (needUids.isEmpty) return members;

    try {
      final rows = await _supabase
          .from('users')
          .select('id, year_graduated')
          .inFilter('id', needUids);

      final batchByUid = <String, String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final grad = (row['year_graduated'] as String? ?? '').trim();
        if (grad.isNotEmpty) batchByUid[id] = grad;
      }
      if (batchByUid.isEmpty) return members;

      return members.map((m) {
        if (m.effectiveBatchYear.isNotEmpty) return m;
        final uid = m.authUid?.trim();
        if (uid == null || uid.isEmpty) return m;
        final filled = batchByUid[uid];
        if (filled == null || filled.isEmpty) return m;
        return m.copyWith(batchYear: filled);
      }).toList();
    } catch (_) {
      // Filters still work from roster fields if users lookup fails.
      return members;
    }
  }

  Future<AlumniMember?> getMemberById(String id) async {
    try {
      final row = await _supabase
          .from('alumni_members')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row != null) return AlumniMember.fromSupabaseRow(row);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateRosterMember({
    required String id,
    required String fullName,
    required String course,
    required String studentId,
    required String yearGraduated,
  }) async {
    final name = normalizeFullName(fullName);
    final sid = normalizeStudentId(studentId);
    final prog = CourseConstants.normalize(course);

    if (name.isEmpty || sid.isEmpty) {
      throw Exception('Full name and ID number are required.');
    }
    if (prog == null || !CourseConstants.isValid(prog)) {
      throw Exception('Select a valid course.');
    }
    final year = normalizeGraduationYear(yearGraduated);

    await assertNotDuplicate(studentId: sid, course: prog, excludeMemberId: id);

    final existing = await getMemberById(id);
    final updated =
        (existing ??
                AlumniMember(
                  id: id,
                  fullName: name,
                  course: prog,
                  studentId: sid,
                ))
            .copyWith(
              fullName: name,
              course: prog,
              studentId: sid,
              batchYear: year,
              yearGraduated: year,
              updatedAt: DateTime.now(),
            );

    await _upsertMemberToSupabase(updated);
  }

  Future<void> updateMember(AlumniMember member) async {
    final updated = member.copyWith(updatedAt: DateTime.now());
    await _upsertMemberToSupabase(updated);
  }

  Future<void> deactivateMember(String id) async {
    try {
      await _supabase
          .from('alumni_members')
          .update({
            'is_deactivated': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Error deactivating member: $e');
    }
  }

  Future<void> reactivateMember(String id) async {
    try {
      await _supabase
          .from('alumni_members')
          .update({
            'is_deactivated': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Error reactivating member: $e');
    }
  }

  Future<void> deleteMember(String id) async {
    try {
      await _supabase.from('alumni_members').delete().eq('id', id);
    } catch (e) {
      throw Exception('Error deleting member: $e');
    }
  }

  /// Deactivates and anonymizes the linked portal account. The roster row
  /// stays (deactivated, unlinked) and tracer answers are kept with
  /// identifying items blanked.
  Future<void> removeRegisteredMemberAccount(AlumniMember member) async {
    final authUid = member.authUid?.trim() ?? '';
    if (authUid.isEmpty) {
      await deleteMember(member.id);
      return;
    }

    final Object? data;
    try {
      data = await _supabase.rpc(
        'admin_remove_alumni_account',
        params: {'p_member_id': member.id},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
    if (data is! Map || data['ok'] != true) {
      throw Exception('Could not remove the registered account.');
    }

    await ImageStorageService(supabase: _supabase).deleteProfileImage(
      authUid,
      avatarUrl: data['avatarUrl']?.toString(),
    );
  }

  Future<void> markAdminViewed(String memberId) async {
    try {
      await _supabase
          .from('alumni_members')
          .update({
            'has_profile_updates': false,
            'admin_viewed_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', memberId);
    } catch (e) {
      throw Exception('Error marking member admin viewed: $e');
    }
  }

  /// Looks up the roster member linked to a Supabase auth user via their
  /// `users` row course + student ID (replaces the old Firestore doc-ref path).
  Future<AlumniMember?> findRosterMemberForAuthUid(String authUid) async {
    if (authUid.isEmpty) return null;
    try {
      final userRow = await _supabase
          .from('users')
          .select('program, student_id')
          .eq('id', authUid)
          .maybeSingle();
      if (userRow == null) return null;

      final course = (userRow['program'] as String? ?? '').trim();
      final studentId = (userRow['student_id'] as String? ?? '').trim();
      if (course.isEmpty || studentId.isEmpty) return null;

      return findByStudentIdAndCourse(studentId: studentId, course: course);
    } catch (_) {
      return null;
    }
  }

  Future<void> flagProfileUpdatedForAuthUid(String authUid) async {
    final member = await findRosterMemberForAuthUid(authUid);
    if (member == null) return;
    try {
      await _supabase
          .from('alumni_members')
          .update({
            'has_profile_updates': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', member.id);
    } catch (_) {
      // Best-effort roster mirror.
    }
  }

  /// Keeps the roster avatar in sync immediately after a user uploads one.
  Future<void> mirrorProfileImageForAuthUid(
    String authUid,
    String profileImageUrl,
  ) async {
    if (authUid.isEmpty || profileImageUrl.trim().isEmpty) return;
    final member = await findRosterMemberForAuthUid(authUid);
    if (member == null) return;
    try {
      await _supabase
          .from('alumni_members')
          .update({
            'profile_image_url': profileImageUrl.trim(),
            'has_profile_updates': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', member.id);
    } catch (_) {
      // The profile upload succeeded; this denormalized roster mirror is best-effort.
    }
  }

  Future<void> recordLastActiveForAuthUid(String authUid) async {
    if (authUid.isEmpty) return;
    final member = await findRosterMemberForAuthUid(authUid);
    if (member == null) return;
    try {
      await _supabase
          .from('alumni_members')
          .update({'last_active_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', member.id);
    } catch (_) {
      // Best-effort activity tracking.
    }
  }

  /// Mirrors contact details from a saved tracer profile onto the linked
  /// roster row. Name, course, ID number and year belong to the alumni office
  /// and are never written from here.
  Future<void> syncRosterFromTracerProfile({
    required String authUid,
    String contactNumber = '',
    String email = '',
    String address = '',
    String gender = '',
    String civilStatus = '',
    DateTime? birthDate,
    bool tracerProfileComplete = false,
    String? profileImageUrl,
  }) async {
    if (authUid.trim().isEmpty) return;

    final patch = <String, dynamic>{
      'contact_number': contactNumber,
      'email_address': email,
      'address': address,
      'gender': gender,
      'civil_status': civilStatus,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'tracer_profile_complete': tracerProfileComplete,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (profileImageUrl != null) patch['profile_image_url'] = profileImageUrl;

    try {
      await _supabase
          .from('alumni_members')
          .update(patch)
          .eq('auth_uid', authUid);
    } catch (_) {
      // Roster mirror is best-effort.
    }
  }

  Future<AlumniMember?> findByAuthUid(String authUid) async {
    if (authUid.trim().isEmpty) return null;
    try {
      final row = await _supabase
          .from('alumni_members')
          .select()
          .eq('auth_uid', authUid)
          .maybeSingle();
      if (row == null) return null;
      return AlumniMember.fromSupabaseRow(row);
    } catch (_) {
      return null;
    }
  }

  Future<int> getTotalMemberCount() async {
    try {
      return await _supabase
          .from('alumni_members')
          .count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  Future<({int active, int registeredActive, int tracerCompleteActive})>
  getDashboardRosterCounts() async {
    try {
      final members = await getAllMembers(includeDeactivated: true);
      final active = members.where((m) => !m.isDeactivated).length;
      final registered = members
          .where((m) => !m.isDeactivated && m.isRegisteredUser)
          .toList();
      final registeredActive = registered.length;

      // Prefer the users table (source of truth) over the denormalized roster flag.
      final authIds = registered
          .map((m) => m.authUid)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      var tracerCompleteActive = 0;
      if (authIds.isNotEmpty) {
        final rows = await _supabase
            .from('users')
            .select(
              'id, tracer_profile_complete, tracer_profile_completion, '
              'display_name, student_id, program, year_graduated, '
              'mobile_number, address, gender',
            )
            .inFilter('id', authIds);

        final completeIds = <String>{};
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id == null) continue;
          if (TracerProfile.fromSupabaseRow(row).isComplete) {
            completeIds.add(id);
          }
        }

        tracerCompleteActive = registered
            .where((m) => m.authUid != null && completeIds.contains(m.authUid))
            .length;

        // Heal stale roster flags so directory cards stay in sync.
        for (final m in registered) {
          final uid = m.authUid;
          if (uid != null &&
              completeIds.contains(uid) &&
              !m.tracerProfileComplete) {
            try {
              await _supabase
                  .from('alumni_members')
                  .update({
                    'tracer_profile_complete': true,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('id', m.id);
            } catch (_) {}
          }
        }
      } else {
        tracerCompleteActive = registered
            .where((m) => m.tracerProfileComplete)
            .length;
      }

      return (
        active: active,
        registeredActive: registeredActive,
        tracerCompleteActive: tracerCompleteActive,
      );
    } catch (_) {
      return (active: 0, registeredActive: 0, tracerCompleteActive: 0);
    }
  }

  Future<Set<String>> getActiveRegisteredAuthUids() async {
    try {
      final rows = await _supabase
          .from('alumni_members')
          .select('auth_uid')
          .eq('is_registered_user', true)
          .eq('is_deactivated', false);
      return rows
          .map((row) => row['auth_uid']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Stream<List<AlumniMember>> watchMembers() {
    final controller = StreamController<List<AlumniMember>>();

    Future<void> emit() async {
      final list = await getAllMembers();
      if (!controller.isClosed) controller.add(list);
    }

    StreamSubscription<dynamic>? supabaseSub;

    controller.onListen = () async {
      await emit();
      supabaseSub = _supabase
          .from('alumni_members')
          .stream(primaryKey: ['id'])
          .listen((_) => emit());
    };

    controller.onCancel = () async {
      await supabaseSub?.cancel();
    };

    return controller.stream;
  }

  List<AlumniMember> filterAndSort({
    required List<AlumniMember> members,
    String searchQuery = '',
    String? courseFilter,
    String? batchFilter,
    AlumniRegistrationFilter registrationFilter = AlumniRegistrationFilter.all,
    AlumniActiveFilter activeFilter = AlumniActiveFilter.all,
    AlumniEmploymentFilter employmentFilter = AlumniEmploymentFilter.all,
    EmploymentStatusIndex employmentIndex = const EmploymentStatusIndex(),
    AlumniDirectorySort sort = AlumniDirectorySort.nameAsc,
    bool hideDeactivated = true,
  }) {
    final q = searchQuery.trim().toLowerCase();
    var list = members.where((m) {
      if (hideDeactivated && m.isDeactivated) return false;

      if (courseFilter != null &&
          courseFilter.isNotEmpty &&
          m.course != courseFilter) {
        return false;
      }

      if (batchFilter != null && batchFilter.isNotEmpty) {
        if (m.effectiveBatchYear != batchFilter) return false;
      }

      switch (registrationFilter) {
        case AlumniRegistrationFilter.registered:
          if (!m.isRegisteredUser) return false;
          break;
        case AlumniRegistrationFilter.notRegistered:
          if (m.isRegisteredUser) return false;
          break;
        case AlumniRegistrationFilter.all:
          break;
      }

      switch (activeFilter) {
        case AlumniActiveFilter.all:
          break;
        case AlumniActiveFilter.active7:
          if (!m.isActiveWithin(const Duration(days: 7))) return false;
          break;
        case AlumniActiveFilter.active30:
          if (!m.isActiveWithin(const Duration(days: 30))) return false;
          break;
        case AlumniActiveFilter.active90:
          if (!m.isActiveWithin(const Duration(days: 90))) return false;
          break;
        case AlumniActiveFilter.inactive:
          if (m.isRegisteredUser &&
              m.isActiveWithin(const Duration(days: 90))) {
            return false;
          }
          if (!m.isRegisteredUser) return false;
          break;
      }

      if (employmentFilter != AlumniEmploymentFilter.all) {
        final status = resolveEmploymentStatus(m, employmentIndex);
        if (status == null) return false;
        switch (employmentFilter) {
          case AlumniEmploymentFilter.employed:
            if (status != 'employed') return false;
            break;
          case AlumniEmploymentFilter.unemployed:
            if (status != 'unemployed') return false;
            break;
          case AlumniEmploymentFilter.all:
            break;
        }
      }

      if (q.isEmpty) return true;
      return m.fullName.toLowerCase().contains(q) ||
          m.studentId.toLowerCase().contains(q) ||
          m.course.toLowerCase().contains(q) ||
          m.effectiveBatchYear.toLowerCase().contains(q) ||
          (m.registeredEmail ?? '').toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      switch (sort) {
        case AlumniDirectorySort.nameAsc:
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        case AlumniDirectorySort.nameDesc:
          return b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase());
        case AlumniDirectorySort.studentIdAsc:
          return a.studentId.compareTo(b.studentId);
        case AlumniDirectorySort.courseAsc:
          final c = a.course.compareTo(b.course);
          return c != 0 ? c : a.fullName.compareTo(b.fullName);
        case AlumniDirectorySort.createdNewest:
          return b.createdAt.compareTo(a.createdAt);
        case AlumniDirectorySort.lastActiveNewest:
          final aT = a.lastActiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bT = b.lastActiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bT.compareTo(aT);
      }
    });

    return list;
  }

  static String? resolveEmploymentStatus(
    AlumniMember member,
    EmploymentStatusIndex index,
  ) {
    final onRoster = member.employmentStatus?.trim();
    if (onRoster != null && onRoster.isNotEmpty) {
      return onRoster.toLowerCase();
    }

    final uid = member.authUid;
    if (uid != null && uid.isNotEmpty) {
      final byUid = index.byAuthUid[uid]?.trim();
      if (byUid != null && byUid.isNotEmpty) {
        return byUid.toLowerCase();
      }
    }

    final sid = normalizeStudentId(member.studentId);
    if (sid.isNotEmpty) {
      final bySchool = index.bySchoolId[sid]?.trim();
      if (bySchool != null && bySchool.isNotEmpty) {
        return bySchool.toLowerCase();
      }
    }

    return null;
  }

  Future<List<AlumniMember>> getMembersByBatch(String batchYear) async {
    final all = await getAllMembers();
    return all.where((m) => m.effectiveBatchYear == batchYear).toList();
  }

  Future<List<String>> getBatchYears() async {
    final all = await getAllMembers();
    final years = all
        .map((m) => m.effectiveBatchYear)
        .where((y) => y.isNotEmpty)
        .toSet();
    final list = years.toList()..sort();
    return list;
  }

  Future<int> getMemberCountByBatch(String batchYear) async {
    final members = await getMembersByBatch(batchYear);
    return members.length;
  }

  Stream<List<AlumniMember>> getMembersStream() => watchMembers();

  Future<void> _upsertMemberToSupabase(AlumniMember member) async {
    String? authSupabaseId;
    if (member.authUid != null && member.authUid!.isNotEmpty) {
      authSupabaseId = await _bridge.resolveSupabaseUserId(member.authUid!);
    }

    try {
      await _supabase
          .from('alumni_members')
          .upsert(
            member.toSupabaseRow(authSupabaseId: authSupabaseId),
            onConflict: 'id',
          );
    } catch (e) {
      throw Exception('Error saving member: $e');
    }
  }

  Future<List<AlumniMember>> _fetchMembersFromSupabase() async {
    final rows = await _supabase
        .from('alumni_members')
        .select(
          'id, full_name, course, student_id, auth_uid, registered_email, '
          'is_registered_user, is_deactivated, profile_image_url, last_active_at, '
          'has_profile_updates, admin_viewed_at, created_at, updated_at, '
          'contact_number, email_address, address, gender, civil_status, birth_date, '
          'year_graduated, tracer_profile_complete, employment_status',
        )
        .order('created_at', ascending: false);
    return rows.map(AlumniMember.fromSupabaseRow).toList();
  }

  /// Uses the users table as the avatar source of truth. This also covers
  /// profiles uploaded before profile_image_url was mirrored to the roster.
  ///
  /// Skips members that already have a non-data URL (storage URL preferred).
  Future<List<AlumniMember>> _hydrateProfileImages(
    List<AlumniMember> members,
  ) async {
    final authIds = members
        .where((member) {
          final existing = member.profileImageUrl?.trim();
          if (existing != null &&
              existing.isNotEmpty &&
              !existing.startsWith('data:')) {
            return false;
          }
          final id = member.authUid;
          return id != null && id.isNotEmpty;
        })
        .map((member) => member.authUid!)
        .toSet()
        .toList();
    if (authIds.isEmpty) return members;

    try {
      final rows = await _supabase
          .from('users')
          .select('id, profile_image_base64')
          .inFilter('id', authIds);
      final imagesByUserId = <String, String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        final image = row['profile_image_base64'] as String?;
        if (id != null && image != null && image.trim().isNotEmpty) {
          imagesByUserId[id] = image.trim();
        }
      }

      return members.map((member) {
        final image = imagesByUserId[member.authUid];
        return image == null ? member : member.copyWith(profileImageUrl: image);
      }).toList();
    } catch (_) {
      return members;
    }
  }
}
