import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/notifications/models/notification_preferences.dart';

class NotificationPreferencesService {
  NotificationPreferencesService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Defaults when the user has never saved settings.
  Future<NotificationPreferences> load() async {
    final userId = AppSession.userId;
    if (userId == null) return const NotificationPreferences();
    final row = await _supabase
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const NotificationPreferences();
    return NotificationPreferences.fromSupabaseRow(row);
  }

  Future<void> save(NotificationPreferences prefs) async {
    final userId = AppSession.userId;
    if (userId == null) throw StateError('Not signed in');
    await _supabase
        .from('notification_preferences')
        .upsert(prefs.toSupabaseRow(userId: userId), onConflict: 'user_id');
  }
}
