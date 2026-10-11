import 'dart:convert';

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
/// The demo project (docs/demo-data-plan.md) also sets `AESS_ENV=demo`.
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

  static const environment = String.fromEnvironment('AESS_ENV');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Why the app must not start with the current build settings, or null.
  static String? get configurationError => validate(
    environment: environment,
    url: url,
    anonKey: anonKey,
    urlOverridden: const bool.hasEnvironment('SUPABASE_URL'),
    anonKeyOverridden: const bool.hasEnvironment('SUPABASE_ANON_KEY'),
  );

  /// Ribbon text for non-live builds, or null on the live project.
  static String? get environmentLabel => labelFor(url, environment);

  static String? validate({
    required String environment,
    required String url,
    required String anonKey,
    required bool urlOverridden,
    required bool anonKeyOverridden,
  }) {
    if (url.isEmpty || anonKey.isEmpty) {
      return 'Supabase is not configured. Set SUPABASE_URL and '
          'SUPABASE_ANON_KEY.';
    }
    if (urlOverridden != anonKeyOverridden) {
      return 'Set both SUPABASE_URL and SUPABASE_ANON_KEY, or neither.';
    }
    final claims = _jwtClaims(anonKey);
    if (claims['role'] == 'service_role' || anonKey.startsWith('sb_secret_')) {
      return 'A service-role or secret key must never be used in the app.';
    }
    final ref = projectRefOf(url);
    final keyRef = claims['ref'];
    if (keyRef is String && keyRef != ref) {
      return 'SUPABASE_ANON_KEY belongs to a different project than '
          'SUPABASE_URL.';
    }
    switch (environment) {
      case '':
        return null;
      case 'demo':
        if (!urlOverridden) {
          return 'AESS_ENV=demo needs the demo SUPABASE_URL and '
              'SUPABASE_ANON_KEY.';
        }
        if (ref == liveProjectRef) {
          return 'AESS_ENV=demo cannot use the live project.';
        }
        if (!RegExp(r'^[a-z]{20}$').hasMatch(ref)) {
          return 'AESS_ENV=demo needs a https://<project-ref>.supabase.co '
              'URL.';
        }
        return null;
      default:
        return 'Unknown AESS_ENV "$environment".';
    }
  }

  static String? labelFor(String url, String environment) {
    if (projectRefOf(url) == liveProjectRef) return null;
    return environment == 'demo' ? 'DEMO DATA' : 'NOT LIVE';
  }

  static String get liveProjectRef => projectRefOf(SupabaseDefaults.url);

  /// `abc` for `https://abc.supabase.co`, otherwise an empty string.
  static String projectRefOf(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https') return '';
    final host = uri.host.toLowerCase();
    if (!host.endsWith('.supabase.co')) return '';
    final ref = host.substring(0, host.length - '.supabase.co'.length);
    return ref.contains('.') ? '' : ref;
  }

  static Map<String, dynamic> _jwtClaims(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return const {};
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}
