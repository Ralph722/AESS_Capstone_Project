/// Non-web builds have no browser push; every call is a no-op.
library;

class WebPushSubscription {
  const WebPushSubscription({required this.endpoint, required this.json});

  final String endpoint;
  final Map<String, dynamic> json;
}

bool webPushSupported() => false;

String webPushPermission() => 'unsupported';

Future<String> webPushRequestPermission() async => 'unsupported';

Future<WebPushSubscription?> webPushSubscription(
  String vapidPublicKey, {
  required bool create,
}) async =>
    null;

Future<String?> webPushUnsubscribe() async => null;

void webPushListenForOpens(void Function(String route) onOpen) {}

String? webPushTakeLaunchRoute() => null;

String webPushDeviceLabel() => 'Browser';
