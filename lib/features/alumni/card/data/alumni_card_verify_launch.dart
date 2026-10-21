import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

/// Reads `?verify=` from the start-up URL (staff QR scan).
abstract final class AlumniCardVerifyLaunch {
  static const queryParam = 'verify';

  /// Returns the code without changing the address bar.
  static String? peekCode([Uri? uri]) {
    final raw = (uri ?? Uri.base).queryParameters[queryParam]?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  /// Returns the code and removes `verify` from the address bar on web.
  static String? takeCode([Uri? uri]) {
    final code = peekCode(uri);
    if (code == null) return null;
    _stripFromAddressBar(uri ?? Uri.base);
    return code;
  }

  static void _stripFromAddressBar(Uri uri) {
    if (!kIsWeb) return;
    try {
      final rest = Map<String, String>.from(uri.queryParameters)
        ..remove(queryParam);
      final query = rest.isEmpty ? '' : '?${Uri(queryParameters: rest).query}';
      final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
      html.window.history.replaceState(
        null,
        '',
        '${uri.origin}${uri.path}$query$fragment',
      );
    } catch (_) {}
  }
}
