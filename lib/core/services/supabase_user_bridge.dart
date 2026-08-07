import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';

/// Resolves app user IDs against `public.users` (Supabase Auth UUIDs).
class SupabaseUserBridge {
  SupabaseUserBridge({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentSupabaseUserId => AppSession.userId;

  /// [userId] is the Supabase auth UUID (primary key of `public.users`).
  Future<String?> resolveSupabaseUserId(String userId) async {
    if (userId.isEmpty) return AppSession.userId;

    final current = AppSession.userId;
    if (current != null && current == userId) return current;

    try {
      final byId = await _client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return byId?['id'] as String? ?? current;
    } catch (_) {
      return current;
    }
  }

  Future<Map<String, dynamic>?> fetchUserById(String userId) async {
    try {
      return await _client.from('users').select().eq('id', userId).maybeSingle();
    } catch (_) {
      return null;
    }
  }
}
