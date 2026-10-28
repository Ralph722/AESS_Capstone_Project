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
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return AppSession.userId;

    final current = AppSession.userId;
    if (current != null && current == trimmed) return current;

    try {
      final byId = await _client
          .from('users')
          .select('id')
          .eq('id', trimmed)
          .maybeSingle();
      final id = byId?['id'] as String?;
      if (id != null && id.isNotEmpty) {
        return id;
      }
      return trimmed;
    } catch (_) {
      return trimmed;
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
