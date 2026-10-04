/// Browser push through the standard Push API and `web/push-sw.js`.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const _workerScript = 'push-sw.js';
const _workerScope = 'aess-push/';
const _launchRouteParam = 'notification_route';

class WebPushSubscription {
  const WebPushSubscription({required this.endpoint, required this.json});

  final String endpoint;
  final Map<String, dynamic> json;
}

bool webPushSupported() {
  try {
    return web.window.navigator.has('serviceWorker') &&
        web.window.has('PushManager') &&
        web.window.has('Notification');
  } catch (_) {
    return false;
  }
}

/// `default`, `granted`, `denied`, or `unsupported`.
String webPushPermission() {
  if (!webPushSupported()) return 'unsupported';
  return web.Notification.permission;
}

/// Must run from a user gesture (a button tap) or browsers ignore it.
Future<String> webPushRequestPermission() async {
  if (!webPushSupported()) return 'unsupported';
  final result = await web.Notification.requestPermission().toDart;
  return result.toDart;
}

/// The current subscription, or a new one when [create] is true and
/// permission is granted.
Future<WebPushSubscription?> webPushSubscription(
  String vapidPublicKey, {
  required bool create,
}) async {
  if (!webPushSupported()) return null;
  final container = web.window.navigator.serviceWorker;

  web.ServiceWorkerRegistration? registration =
      await container.getRegistration(_workerScope).toDart;
  if (registration == null) {
    if (!create) return null;
    registration = await container
        .register(
          _workerScript.toJS,
          web.RegistrationOptions(scope: _workerScope),
        )
        .toDart;
  }

  var subscription = await registration.pushManager.getSubscription().toDart;
  if (subscription == null) {
    if (!create || web.Notification.permission != 'granted') return null;
    subscription = await registration.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _decodeKey(vapidPublicKey).toJS,
          ),
        )
        .toDart;
  }

  final raw = jsonDecode(jsonEncode(subscription.toJSON().dartify()));
  if (raw is! Map) return null;
  final json = Map<String, dynamic>.from(raw);
  final endpoint = json['endpoint'] as String? ?? subscription.endpoint;
  return WebPushSubscription(endpoint: endpoint, json: json);
}

/// Removes this browser's subscription. Returns the old endpoint, if any.
Future<String?> webPushUnsubscribe() async {
  if (!webPushSupported()) return null;
  final registration = await web.window.navigator.serviceWorker
      .getRegistration(_workerScope)
      .toDart;
  if (registration == null) return null;
  final subscription = await registration.pushManager.getSubscription().toDart;
  if (subscription == null) return null;
  final endpoint = subscription.endpoint;
  await subscription.unsubscribe().toDart;
  return endpoint;
}

/// Taps on an alert while the app is already open arrive as worker messages.
void webPushListenForOpens(void Function(String route) onOpen) {
  if (!webPushSupported()) return;
  final container = web.window.navigator.serviceWorker;
  container.addEventListener(
    'message',
    ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is! Map || data['type'] != 'aess-notification-open') return;
      final route = data['route'];
      if (route is String && route.trim().isNotEmpty) onOpen(route.trim());
    }).toJS,
  );
  container.startMessages();
}

/// A tap that opened a new tab carries the route in the query string.
/// Reads it once and removes it from the address bar.
String? webPushTakeLaunchRoute() {
  final uri = Uri.base;
  final route = uri.queryParameters[_launchRouteParam]?.trim();
  if (route == null) return null;

  final rest = Map<String, String>.from(uri.queryParameters)
    ..remove(_launchRouteParam);
  final query = rest.isEmpty ? '' : '?${Uri(queryParameters: rest).query}';
  final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
  try {
    web.window.history.replaceState(
      null,
      '',
      '${uri.origin}${uri.path}$query$fragment',
    );
  } catch (_) {}
  return route.isEmpty ? null : route;
}

String webPushDeviceLabel() {
  final agent = web.window.navigator.userAgent;
  final browser = agent.contains('Edg/')
      ? 'Edge'
      : agent.contains('OPR/')
          ? 'Opera'
          : agent.contains('Firefox/')
              ? 'Firefox'
              : agent.contains('Chrome/')
                  ? 'Chrome'
                  : agent.contains('Safari/')
                      ? 'Safari'
                      : 'Browser';
  final os = agent.contains('Windows')
      ? 'Windows'
      : agent.contains('Android')
          ? 'Android'
          : agent.contains('iPhone') || agent.contains('iPad')
              ? 'iOS'
              : agent.contains('Mac OS')
                  ? 'macOS'
                  : agent.contains('Linux')
                      ? 'Linux'
                      : '';
  return os.isEmpty ? browser : '$browser on $os';
}

Uint8List _decodeKey(String base64UrlKey) {
  final padded =
      base64UrlKey.padRight((base64UrlKey.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(padded);
}
