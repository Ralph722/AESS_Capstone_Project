import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/app_session.dart';

class UserProfileService {
  UserProfileService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<TracerProfile?> getTracerProfile([String? uid]) async {
    final id = uid ?? AppSession.userId;
    if (id == null) return null;

    final row =
        await _supabase.from('users').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return TracerProfile.fromSupabaseRow(row);
  }

  /// Single fetch used by onboarding — profile fields + avatar URL together.
  Future<({TracerProfile? profile, String? imageUrl})> getOnboardingBootstrap({
    String? uid,
  }) async {
    final id = uid ?? AppSession.userId;
    if (id == null) return (profile: null, imageUrl: null);

    final row = await _supabase
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return (profile: null, imageUrl: null);

    final image = row['profile_image_base64'] as String?;
    return (
      profile: TracerProfile.fromSupabaseRow(row),
      imageUrl: (image != null && image.trim().isNotEmpty) ? image.trim() : null,
    );
  }

  Stream<TracerProfile?> watchTracerProfile([String? uid]) {
    final id = uid ?? AppSession.userId;
    if (id == null) return Stream.value(null);

    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) => rows.isEmpty ? null : TracerProfile.fromSupabaseRow(rows.first));
  }

  Future<String?> getProfileImageUrl([String? uid]) async {
    final id = uid ?? AppSession.userId;
    if (id == null) return null;
    try {
      final row = await _supabase
          .from('users')
          .select('profile_image_base64')
          .eq('id', id)
          .maybeSingle();
      final url = row?['profile_image_base64'] as String?;
      return (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTracerProfile(
    TracerProfile profile, {
    bool syncRoster = true,
  }) async {
    final data = profile.toSupabaseRow();

    // Keep role for RLS check on update writes.
    data['role'] = 'user';

    await _supabase.from('users').upsert(data, onConflict: 'id');
    if (!syncRoster) return;

    try {
      // Use the same computed completion as the users row — [TracerProfile]
      // built from form fields often has completionPercent still at 0.
      final synced = TracerProfile.fromSupabaseRow({
        ...data,
        'id': profile.uid,
      });
      await _syncAlumniDirectory(synced);
      await AlumniMemberService().flagProfileUpdatedForAuthUid(profile.uid);
    } catch (_) {
      // User profile is saved; roster mirror is best-effort (no list/query).
    }
  }

  Future<void> syncRosterFromSavedProfile(String uid) async {
    final profile = await getTracerProfile(uid);
    if (profile == null) return;
    try {
      await _syncAlumniDirectory(profile);
      await AlumniMemberService().flagProfileUpdatedForAuthUid(uid);
    } catch (_) {}
  }

  Future<void> saveProfileImageUrl({
    required String uid,
    required String imageUrl,
  }) async {
    await _supabase.from('users').update({
      'profile_image_base64': imageUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
    await AlumniMemberService().mirrorProfileImageForAuthUid(uid, imageUrl);
  }

  Future<void> _syncAlumniDirectory(TracerProfile profile) async {
    if (profile.displayName.trim().isEmpty) return;

    String? imageUrl;
    try {
      final row = await _supabase
          .from('users')
          .select('profile_image_base64')
          .eq('id', profile.uid)
          .maybeSingle();
      imageUrl = row?['profile_image_base64'] as String?;
    } catch (_) {}

    await AlumniMemberService().syncRosterFromTracerProfile(
      authUid: profile.uid,
      displayName: profile.displayName,
      course: profile.program,
      studentId: profile.studentId,
      contactNumber: profile.mobileNumber,
      email: profile.email,
      address: profile.address,
      gender: profile.gender,
      civilStatus: profile.civilStatus,
      birthDate: profile.birthDate,
      yearGraduated: profile.yearGraduated,
      tracerProfileComplete: profile.isComplete,
      profileImageUrl:
          (imageUrl != null && imageUrl.trim().isNotEmpty) ? imageUrl : null,
    );
  }

  Future<List<RegisteredAlumniRow>> getRegisteredAlumni({
    String? programFilter,
    String? batchFilter,
    bool? profileCompleteOnly,
    String searchQuery = '',
  }) async {
    final activeRegisteredIds =
        await AlumniMemberService().getActiveRegisteredAuthUids();
    if (activeRegisteredIds.isEmpty) return [];

    final rows = await _supabase
        .from('users')
        .select()
        .eq('role', 'user')
        .inFilter('id', activeRegisteredIds.toList());

    final employmentUids = await _employmentUserIds();
    final query = searchQuery.trim().toLowerCase();

    final result = <RegisteredAlumniRow>[];

    for (final row in rows) {
      final profile = TracerProfile.fromSupabaseRow(row);

      if (programFilter != null &&
          programFilter.isNotEmpty &&
          profile.program != programFilter) {
        continue;
      }
      if (batchFilter != null &&
          batchFilter.isNotEmpty &&
          profile.batchYear != batchFilter) {
        continue;
      }
      if (profileCompleteOnly == true && !profile.isComplete) continue;
      if (profileCompleteOnly == false && profile.isComplete) continue;

      if (query.isNotEmpty) {
        final haystack =
            '${profile.displayName} ${profile.email} ${profile.program} '
                    '${profile.batchYear} ${profile.studentId}'
                .toLowerCase();
        if (!haystack.contains(query)) continue;
      }

      result.add(
        RegisteredAlumniRow(
          profile: profile,
          hasEmploymentRecord: employmentUids.contains(row['id']),
        ),
      );
    }

    result.sort(
      (a, b) => a.profile.displayName.toLowerCase().compareTo(
            b.profile.displayName.toLowerCase(),
          ),
    );
    return result;
  }

  /// Live profiles of active registered alumni, keyed by auth uid.
  /// Used to enrich roster exports with batch year / email that may be
  /// missing from the `alumni_members` mirror.
  Future<Map<String, TracerProfile>> getRegisteredProfileIndex() async {
    final activeRegisteredIds =
        await AlumniMemberService().getActiveRegisteredAuthUids();
    if (activeRegisteredIds.isEmpty) return {};

    final rows = await _supabase
        .from('users')
        .select()
        .eq('role', 'user')
        .inFilter('id', activeRegisteredIds.toList());

    return {
      for (final row in rows)
        if ((row['id'] as String? ?? '').isNotEmpty)
          row['id'] as String: TracerProfile.fromSupabaseRow(row),
    };
  }

  Future<Set<String>> _employmentUserIds() async {
    final rows = await _supabase.from('employment_records').select('user_id');
    return rows
        .map((r) => r['user_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<bool> currentUserHasEmploymentRecord() async {
    final uid = AppSession.userId;
    if (uid == null) return false;
    final row = await _supabase
        .from('employment_records')
        .select('id')
        .eq('user_id', uid)
        .maybeSingle();
    return row != null;
  }
}
