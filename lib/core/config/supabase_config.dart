import 'package:alumni_system/core/config/supabase_defaults.dart';

/// Supabase client credentials for the Flutter app.
///
/// Defaults come from [SupabaseDefaults] so `flutter run -d chrome` works
/// without extra flags. Override only when needed:
///
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// ```
///
/// The **service role** key must never be used in the client app.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: SupabaseDefaults.url,
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: SupabaseDefaults.anonKey,
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
