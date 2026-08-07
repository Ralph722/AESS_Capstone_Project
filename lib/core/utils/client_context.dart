import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:universal_html/html.dart' as html;

/// Privacy-safe coarse client context for survey activity tracking.
///
/// Does not collect IP, raw user agent, device IDs, or fingerprint signals.
class SurveyClientContext {
  const SurveyClientContext({
    this.deviceCategory,
    this.platformFamily,
    this.browserFamily,
  });

  final String? deviceCategory;
  final String? platformFamily;
  final String? browserFamily;

  Map<String, String?> toRpcParams() => {
        'device_category': deviceCategory,
        'platform_family': platformFamily,
        'browser_family': browserFamily,
      };

  static SurveyClientContext capture() {
    if (kIsWeb) {
      return SurveyClientContext(
        deviceCategory: _webDeviceCategory(),
        platformFamily: 'web',
        browserFamily: _webBrowserFamily(),
      );
    }

    final platform = defaultTargetPlatform;
    return SurveyClientContext(
      deviceCategory: 'mobile',
      platformFamily: switch (platform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.windows => 'windows',
        TargetPlatform.macOS => 'macos',
        TargetPlatform.linux => 'linux',
        _ => 'other',
      },
      browserFamily: 'native',
    );
  }

  static String _webDeviceCategory() {
    final ua = _webUserAgent().toLowerCase();
    if (ua.contains('ipad') ||
        ua.contains('tablet') ||
        (ua.contains('android') && !ua.contains('mobile'))) {
      return 'tablet';
    }
    if (ua.contains('mobile') ||
        ua.contains('iphone') ||
        ua.contains('android')) {
      return 'mobile';
    }
    return 'desktop';
  }

  static String _webUserAgent() {
    if (!kIsWeb) return '';
    try {
      return html.window.navigator.userAgent;
    } catch (_) {
      return '';
    }
  }

  static String _webBrowserFamily() {
    if (!kIsWeb) return 'other';
    final ua = _webUserAgent().toLowerCase();
    if (ua.contains('edg/')) return 'edge';
    if (ua.contains('opr/') || ua.contains('opera')) return 'opera';
    if (ua.contains('firefox')) return 'firefox';
    if (ua.contains('chrome') && !ua.contains('edg/')) return 'chrome';
    if (ua.contains('safari') && !ua.contains('chrome')) return 'safari';
    return 'other';
  }
}

/// Normalizes a device category string for storage.
String normalizeSurveyDeviceCategory(String? value) {
  switch (value?.toLowerCase()) {
    case 'mobile':
    case 'tablet':
    case 'desktop':
      return value!.toLowerCase();
    default:
      return 'other';
  }
}

/// Normalizes a platform family string for storage.
String normalizeSurveyPlatformFamily(String? value) {
  switch (value?.toLowerCase()) {
    case 'android':
    case 'ios':
    case 'web':
    case 'windows':
    case 'macos':
    case 'linux':
      return value!.toLowerCase();
    default:
      return 'other';
  }
}

/// Normalizes a browser family string for storage.
String normalizeSurveyBrowserFamily(String? value) {
  switch (value?.toLowerCase()) {
    case 'chrome':
    case 'safari':
    case 'firefox':
    case 'edge':
    case 'opera':
    case 'native':
      return value!.toLowerCase();
    default:
      return 'other';
  }
}
