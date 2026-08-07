import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/supabase_user_bridge.dart';

/// Favorite jobs — Supabase only.
class FavoriteJobService {
  FavoriteJobService({
    SupabaseClient? supabase,
    SupabaseUserBridge? bridge,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _bridge = bridge ?? SupabaseUserBridge(client: supabase);

  final SupabaseClient _supabase;
  final SupabaseUserBridge _bridge;

  String _requireUserId() => AppSession.requireUserId();

  Future<String?> _resolveSupabaseUserId() async {
    return _bridge.resolveSupabaseUserId(_requireUserId());
  }

  Future<void> addToFavorites(String jobId) async {
    try {
      final supabaseUserId = await _resolveSupabaseUserId();
      if (supabaseUserId == null) {
        throw Exception('Job not found');
      }
      await _supabase.from('favorite_jobs').upsert({
        'user_id': supabaseUserId,
        'job_id': jobId,
      });
    } catch (e) {
      throw Exception('Error adding job to favorites: $e');
    }
  }

  Future<void> removeFromFavorites(String jobId) async {
    try {
      final supabaseUserId = await _resolveSupabaseUserId();
      if (supabaseUserId == null) return;
      await _supabase
          .from('favorite_jobs')
          .delete()
          .eq('user_id', supabaseUserId)
          .eq('job_id', jobId);
    } catch (e) {
      throw Exception('Error removing job from favorites: $e');
    }
  }

  Future<bool> isFavorite(String jobId) async {
    try {
      final supabaseUserId = await _resolveSupabaseUserId();
      if (supabaseUserId == null) return false;
      final row = await _supabase
          .from('favorite_jobs')
          .select('job_id')
          .eq('user_id', supabaseUserId)
          .eq('job_id', jobId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getFavoriteJobIds() async {
    return _fetchFavoriteIdsFromSupabase();
  }

  /// jobId → when favorited (for Saved Jobs polish).
  Future<Map<String, DateTime>> getFavoriteJobDates() async {
    try {
      final supabaseUserId = await _resolveSupabaseUserId();
      if (supabaseUserId == null) return {};
      final rows = await _supabase
          .from('favorite_jobs')
          .select('job_id, created_at')
          .eq('user_id', supabaseUserId);
      final out = <String, DateTime>{};
      for (final row in rows) {
        final id = row['job_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final at = row['created_at'] != null
            ? DateTime.tryParse(row['created_at'].toString())?.toLocal()
            : null;
        out[id] = at ?? DateTime.now();
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Stream<List<String>> getFavoriteJobIdsStream() {
    return AppSession.onAuthStateChange.asyncExpand((state) {
      if (!AppSession.isSignedIn) {
        return Stream.value(<String>[]);
      }

      final controller = StreamController<List<String>>();

      Future<void> emit() async {
        final ids = await _fetchFavoriteIdsFromSupabase();
        if (!controller.isClosed) controller.add(ids);
      }

      StreamSubscription<dynamic>? sub;
      Timer? poller;

      Future<void> startPolling() async {
        await emit();
        poller?.cancel();
        poller = Timer.periodic(
          const Duration(seconds: 15),
          (_) => emit(),
        );
      }

      controller.onListen = () async {
        await emit();
        final supabaseUserId = await _resolveSupabaseUserId();
        if (supabaseUserId == null) return;
        try {
          sub = _supabase
              .from('favorite_jobs')
              .stream(primaryKey: ['user_id', 'job_id'])
              .eq('user_id', supabaseUserId)
              .listen(
                (_) => emit(),
                onError: (_) => startPolling(),
              );
        } catch (_) {
          await startPolling();
        }
      };

      controller.onCancel = () async {
        await sub?.cancel();
        poller?.cancel();
      };

      return controller.stream;
    });
  }

  Future<List<String>> _fetchFavoriteIdsFromSupabase() async {
    try {
      final supabaseUserId = await _resolveSupabaseUserId();
      if (supabaseUserId == null) return [];

      final rows = await _supabase
          .from('favorite_jobs')
          .select('job_id')
          .eq('user_id', supabaseUserId);

      return rows
          .map((row) => row['job_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
