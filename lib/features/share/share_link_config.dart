/// Canonical origin for shareable AESS links.
///
/// Override at build time when a custom domain is attached:
/// `flutter build web --dart-define=SHARE_BASE_ORIGIN=https://example.edu`
abstract final class ShareLinkConfig {
  static const origin = String.fromEnvironment(
    'SHARE_BASE_ORIGIN',
    defaultValue: 'https://ustp-aess.web.app',
  );

  /// Hosts whose links this app will open. Links on any other host are
  /// ignored, so a pasted foreign URL can never drive navigation.
  static Set<String> get allowedHosts => {
    'ustp-aess.web.app',
    'ustp-aess.firebaseapp.com',
    if (Uri.tryParse(origin)?.host.isNotEmpty == true)
      Uri.parse(origin).host.toLowerCase(),
  };
}
