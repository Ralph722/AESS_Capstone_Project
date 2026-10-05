import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/supabase_user_bridge.dart';
import 'package:alumni_system/features/jobs/models/job_interest_model.dart';

/// Toggle + roster for job interest (not applications).
class JobInterestService {
  JobInterestService({
    SupabaseClient? supabase,
    SupabaseUserBridge? bridge,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _bridge = bridge ?? SupabaseUserBridge(client: supabase);

  final SupabaseClient _supabase;
  final SupabaseUserBridge _bridge;

  Future<String?> _resolveUid() async {
    final id = AppSession.userId;
    if (id == null) return null;
    return _bridge.resolveSupabaseUserId(id);
  }

  Future<bool> isInterested(String jobId) async {
    try {
      final uid = await _resolveUid();
      if (uid == null || jobId.isEmpty) return false;
      final row = await _supabase
          .from('job_interests')
          .select('job_id')
          .eq('user_id', uid)
          .eq('job_id', jobId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getInterestedJobIds() async {
    try {
      final uid = await _resolveUid();
      if (uid == null) return [];
      final rows = await _supabase
          .from('job_interests')
          .select('job_id')
          .eq('user_id', uid);
      return rows
          .map((r) => r['job_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns true if now interested.
  Future<bool> toggleInterest(String jobId) async {
    final uid = await _resolveUid();
    if (uid == null || jobId.isEmpty) {
      throw Exception('Not signed in.');
    }
    final existing = await _supabase
        .from('job_interests')
        .select('job_id')
        .eq('user_id', uid)
        .eq('job_id', jobId)
        .maybeSingle();
    if (existing != null) {
      await _supabase
          .from('job_interests')
          .delete()
          .eq('user_id', uid)
          .eq('job_id', jobId);
      return false;
    }
    await _supabase.from('job_interests').upsert({
      'user_id': uid,
      'job_id': jobId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return true;
  }

  Future<Map<String, int>> countByJobIds(Iterable<String> jobIds) async {
    final ids = jobIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    try {
      final rows = await _supabase
          .from('job_interests')
          .select('job_id')
          .inFilter('job_id', ids);
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['job_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<int> totalInterestCount() async {
    try {
      return await _supabase.from('job_interests').count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  Future<List<JobInterest>> listForJob(String jobId) async {
    if (jobId.isEmpty) return [];
    try {
      final rows = await _supabase
          .from('job_interests')
          .select()
          .eq('job_id', jobId)
          .order('created_at', ascending: false);
      return rows.map(JobInterest.fromSupabaseRow).toList();
    } catch (e) {
      throw Exception('Error loading interested alumni: $e');
    }
  }

  /// Hydrate interest rows with user + roster profile fields.
  Future<List<JobInterestedAlumni>> listAlumniForJob(String jobId) async {
    final interests = await listForJob(jobId);
    if (interests.isEmpty) return [];

    final userIds = interests.map((i) => i.userId).toSet().toList();
    final profiles = <String, Map<String, dynamic>>{};

    try {
      final users = await _supabase
          .from('users')
          .select(
            'id, display_name, email, program, batch_year, year_graduated, '
            'profile_image_base64',
          )
          .inFilter('id', userIds);
      for (final row in users) {
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty) profiles[id] = row;
      }
    } catch (_) {}

    try {
      final members = await _supabase
          .from('alumni_members')
          .select(
            'auth_uid, full_name, registered_email, course, batch_year, '
            'year_graduated, employment_status, profile_image_url',
          )
          .inFilter('auth_uid', userIds);
      for (final row in members) {
        final id = row['auth_uid']?.toString() ?? '';
        if (id.isEmpty) continue;
        final existing = profiles[id] ?? <String, dynamic>{};
        profiles[id] = {
          ...existing,
          if ((row['full_name'] as String?)?.trim().isNotEmpty == true)
            'display_name': row['full_name'],
          if ((row['registered_email'] as String?)?.trim().isNotEmpty == true)
            'email': row['registered_email'],
          if ((row['course'] as String?)?.trim().isNotEmpty == true)
            'program': row['course'],
          'batch_year': row['batch_year'] ?? existing['batch_year'],
          'year_graduated': row['year_graduated'] ?? existing['year_graduated'],
          'employment_status': row['employment_status'],
          if ((row['profile_image_url'] as String?)?.trim().isNotEmpty == true)
            'profile_image_base64': row['profile_image_url'],
        };
      }
    } catch (_) {}

    return interests.map((i) {
      final p = profiles[i.userId] ?? {};
      final batch = ((p['batch_year'] as String?) ?? '').trim().isNotEmpty
          ? (p['batch_year'] as String).trim()
          : ((p['year_graduated'] as String?) ?? '').trim();
      return JobInterestedAlumni(
        userId: i.userId,
        name: (p['display_name'] as String?)?.trim().isNotEmpty == true
            ? (p['display_name'] as String).trim()
            : 'Alumni',
        email: (p['email'] as String?)?.trim() ?? '',
        course: (p['program'] as String?)?.trim() ?? '',
        batch: batch,
        employmentStatus: (p['employment_status'] as String?)?.trim() ?? '',
        avatarUrl: (p['profile_image_base64'] as String?)?.trim(),
        interestedAt: i.createdAt,
      );
    }).toList();
  }

  Stream<List<String>> watchMyInterestedJobIds() {
    return AppSession.onAuthStateChange.asyncExpand((state) {
      if (!AppSession.isSignedIn) {
        return Stream.value(<String>[]);
      }
      final controller = StreamController<List<String>>();
      Timer? poller;

      Future<void> emit() async {
        final ids = await getInterestedJobIds();
        if (!controller.isClosed) controller.add(ids);
      }

      controller.onListen = () async {
        await emit();
        poller = Timer.periodic(const Duration(seconds: 12), (_) => emit());
      };
      controller.onCancel = () => poller?.cancel();
      return controller.stream;
    });
  }
}
