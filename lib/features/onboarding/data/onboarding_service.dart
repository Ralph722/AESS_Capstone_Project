import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';

/// Gates main app until mandatory alumni onboarding is finished.
/// Reads/writes `public.users.onboarding_complete` only.
class OnboardingService {
  OnboardingService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// `true` when the user may enter [MainNavigation].
  Future<bool> isOnboardingComplete(String userId) async {
    try {
      final row = await _supabase
          .from('users')
          .select('onboarding_complete')
          .eq('id', userId)
          .maybeSingle();
      return row?['onboarding_complete'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resolveForCurrentUser() async {
    final userId = AppSession.userId;
    if (userId == null) return false;
    return isOnboardingComplete(userId);
  }

  Future<void> completeOnboarding(String userId) async {
    await _supabase.from('users').update({
      'onboarding_complete': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }
}
