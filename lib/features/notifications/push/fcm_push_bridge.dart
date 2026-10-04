import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:alumni_system/core/config/push_config.dart';

/// Android alerts through Firebase Cloud Messaging.
///
/// Firebase is used only as the delivery channel to Android devices; all
/// notification data stays in Supabase. Nothing here runs unless the build
/// was given the `FIREBASE_*` values (see [PushConfig]).
abstract final class FcmPushBridge {
  static bool _initialized = false;
  static bool _listening = false;

  static bool get supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      PushConfig.fcmConfigured;

  static Future<bool> ensureInitialized() async {
    if (!supported) return false;
    if (_initialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: PushConfig.firebaseApiKey,
            appId: PushConfig.firebaseAppId,
            messagingSenderId: PushConfig.firebaseMessagingSenderId,
            projectId: PushConfig.firebaseProjectId,
          ),
        );
      }
      _initialized = true;
    } catch (e) {
      debugPrint('FcmPushBridge: Firebase init failed: $e');
    }
    return _initialized;
  }

  /// `granted`, `denied`, or `default` (not asked yet).
  static Future<String> permission() async {
    if (!await ensureInitialized()) return 'unsupported';
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return _describe(settings.authorizationStatus);
  }

  static Future<String> requestPermission() async {
    if (!await ensureInitialized()) return 'unsupported';
    final settings = await FirebaseMessaging.instance.requestPermission();
    return _describe(settings.authorizationStatus);
  }

  static Future<String?> token() async {
    if (!await ensureInitialized()) return null;
    return FirebaseMessaging.instance.getToken();
  }

  /// Wires token refreshes, foreground alerts and alert taps. Safe to call
  /// more than once.
  static Future<void> listen({
    required void Function(String token) onToken,
    required void Function(RemoteMessage message) onForeground,
    required void Function(String route) onOpen,
  }) async {
    if (_listening || !await ensureInitialized()) return;
    _listening = true;

    final messaging = FirebaseMessaging.instance;
    messaging.onTokenRefresh.listen(onToken);
    FirebaseMessaging.onMessage.listen(onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = routeOf(message);
      if (route != null) onOpen(route);
    });

    final initial = await messaging.getInitialMessage();
    final route = initial == null ? null : routeOf(initial);
    if (route != null) onOpen(route);
  }

  static String? routeOf(RemoteMessage message) {
    final route = message.data['route'];
    if (route is! String) return null;
    final trimmed = route.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _describe(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return 'granted';
      case AuthorizationStatus.denied:
      case AuthorizationStatus.deniedPermanently:
        return 'denied';
      case AuthorizationStatus.notDetermined:
        return 'default';
    }
  }
}
