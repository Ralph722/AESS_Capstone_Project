import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/config/push_config.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/events/data/reminder_service.dart';
import 'package:alumni_system/features/notifications/application/notification_router.dart';
import 'package:alumni_system/features/notifications/push/fcm_push_bridge.dart';
import 'package:alumni_system/features/notifications/push/web_push_bridge.dart';

/// Phone and browser alert status for this device.
enum PushDeviceState {
  /// This platform or browser cannot receive alerts (e.g. iOS, desktop).
  unsupported,

  /// Android build without the Firebase values.
  notConfigured,

  /// The user blocked notifications in system or browser settings.
  blocked,

  /// Available but not turned on for this device.
  off,

  /// This device is registered for alerts.
  on,
}

/// Registers this device for phone and browser alerts and routes alert taps.
///
/// Devices are stored server-side through `register_push_token` /
/// `unregister_push_token`; the `send-push` edge function does the sending.
/// Which alerts are sent is controlled by the user's notification preferences.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _choiceKeyPrefix = 'aess_push_device_choice_';

  SupabaseClient get _supabase => Supabase.instance.client;

  bool _tapsWired = false;
  String? _syncedForUser;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Hooks alert taps. Call once at startup, before sign-in.
  void initialize() {
    if (_tapsWired) return;
    _tapsWired = true;
    AuthService.beforeSignOut = unregisterForSignOut;
    if (kIsWeb) {
      final launchRoute = webPushTakeLaunchRoute();
      if (launchRoute != null) NotificationRouter.openRoute(launchRoute);
      webPushListenForOpens(NotificationRouter.openRoute);
    } else if (_isAndroid) {
      ReminderService.onRouteTap = NotificationRouter.openRoute;
    }
  }

  Future<PushDeviceState> state() async {
    try {
      if (kIsWeb) {
        if (!webPushSupported() || !PushConfig.webPushConfigured) {
          return PushDeviceState.unsupported;
        }
        final permission = webPushPermission();
        if (permission == 'denied') return PushDeviceState.blocked;
        if (permission != 'granted' || await _choice() != 'on') {
          return PushDeviceState.off;
        }
        final sub = await webPushSubscription(
          PushConfig.webVapidPublicKey,
          create: false,
        );
        return sub == null ? PushDeviceState.off : PushDeviceState.on;
      }
      if (!_isAndroid) return PushDeviceState.unsupported;
      if (!FcmPushBridge.supported) return PushDeviceState.notConfigured;
      final permission = await FcmPushBridge.permission();
      if (permission == 'denied') return PushDeviceState.blocked;
      if (permission != 'granted' || await _choice() == 'off') {
        return PushDeviceState.off;
      }
      return PushDeviceState.on;
    } catch (e) {
      debugPrint('PushService.state failed: $e');
      return PushDeviceState.unsupported;
    }
  }

  /// Turns alerts on for this device. Call from a button tap: browsers only
  /// show the permission prompt in response to a user gesture.
  Future<PushDeviceState> enable() async {
    if (!AppSession.isSignedIn) return state();
    if (kIsWeb) {
      if (!webPushSupported() || !PushConfig.webPushConfigured) {
        return PushDeviceState.unsupported;
      }
      var permission = webPushPermission();
      if (permission == 'default') {
        permission = await webPushRequestPermission();
      }
      if (permission == 'denied') return PushDeviceState.blocked;
      if (permission != 'granted') return PushDeviceState.off;
      await _setChoice('on');
      await _registerWeb(create: true);
      return state();
    }

    if (!_isAndroid) return PushDeviceState.unsupported;
    if (!FcmPushBridge.supported) return PushDeviceState.notConfigured;
    await ReminderService().initialize();
    var permission = await FcmPushBridge.permission();
    if (permission != 'granted') {
      permission = await FcmPushBridge.requestPermission();
    }
    if (permission == 'denied') return PushDeviceState.blocked;
    if (permission != 'granted') return PushDeviceState.off;
    await _setChoice('on');
    await _registerAndroid();
    return state();
  }

  /// Stops alerts on this device for the signed-in user.
  Future<PushDeviceState> disable() async {
    await _setChoice('off');
    try {
      if (kIsWeb) {
        final sub = await webPushSubscription(
          PushConfig.webVapidPublicKey,
          create: false,
        );
        if (sub != null) await _unregister(sub.endpoint);
        await webPushUnsubscribe();
      } else if (FcmPushBridge.supported) {
        final token = await FcmPushBridge.token();
        if (token != null) await _unregister(token);
      }
    } catch (e) {
      debugPrint('PushService.disable failed: $e');
    }
    return state();
  }

  /// Quietly refreshes this device's registration after sign-in. Never
  /// prompts; only re-registers where the user already allowed alerts.
  Future<void> syncForSignedInUser() async {
    final userId = AppSession.userId;
    if (userId == null || _syncedForUser == userId) return;
    _syncedForUser = userId;
    try {
      if (kIsWeb) {
        if (!webPushSupported() || !PushConfig.webPushConfigured) return;
        if (webPushPermission() != 'granted' || await _choice() != 'on') {
          return;
        }
        await _registerWeb(create: true);
        return;
      }
      if (!FcmPushBridge.supported) return;
      await ReminderService().initialize();
      await FcmPushBridge.listen(
        onToken: (token) {
          if (AppSession.isSignedIn) unawaited(_syncAndroidToken(token));
        },
        onForeground: _showForegroundAlert,
        onOpen: NotificationRouter.openRoute,
      );
      if (await FcmPushBridge.permission() != 'granted') return;
      if (await _choice() == 'off') return;
      await _registerAndroid();
    } catch (e) {
      debugPrint('PushService.syncForSignedInUser failed: $e');
    }
  }

  /// Detaches this device from the account. Call before signing out, while
  /// the session is still valid. The browser/OS permission is left as is.
  Future<void> unregisterForSignOut() async {
    _syncedForUser = null;
    if (!AppSession.isSignedIn) return;
    try {
      String? token;
      if (kIsWeb) {
        if (!webPushSupported()) return;
        token = (await webPushSubscription(
          PushConfig.webVapidPublicKey,
          create: false,
        ))
            ?.endpoint;
      } else if (FcmPushBridge.supported) {
        token = await FcmPushBridge.token();
      }
      if (token != null) await _unregister(token);
    } catch (e) {
      debugPrint('PushService.unregisterForSignOut failed: $e');
    }
  }

  Future<void> _registerWeb({required bool create}) async {
    final sub = await webPushSubscription(
      PushConfig.webVapidPublicKey,
      create: create,
    );
    if (sub == null) return;
    await _supabase.rpc('register_push_token', params: {
      'p_provider': 'webpush',
      'p_platform': 'web',
      'p_token': sub.endpoint,
      'p_subscription': sub.json,
      'p_device_label': webPushDeviceLabel(),
    });
  }

  Future<void> _registerAndroid() async {
    final token = await FcmPushBridge.token();
    if (token != null) await _registerAndroidToken(token);
  }

  Future<void> _syncAndroidToken(String token) async {
    try {
      if (await _choice() == 'off') return;
      await _registerAndroidToken(token);
    } catch (e) {
      debugPrint('PushService: token refresh failed: $e');
    }
  }

  Future<void> _registerAndroidToken(String token) async {
    await _supabase.rpc('register_push_token', params: {
      'p_provider': 'fcm',
      'p_platform': 'android',
      'p_token': token,
      'p_device_label': 'Android device',
    });
  }

  Future<void> _unregister(String token) async {
    await _supabase.rpc('unregister_push_token', params: {'p_token': token});
  }

  void _showForegroundAlert(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    if (title == null || title.isEmpty) return;
    final tag = message.data['notificationId'] as String? ??
        message.messageId ??
        DateTime.now().microsecondsSinceEpoch.toString();
    unawaited(ReminderService().showPushedAlert(
      tag: tag,
      title: title,
      body: notification?.body ?? '',
      route: FcmPushBridge.routeOf(message),
    ));
  }

  Future<String?> _choice() async {
    final userId = AppSession.userId;
    if (userId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_choiceKeyPrefix$userId');
  }

  Future<void> _setChoice(String value) async {
    final userId = AppSession.userId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_choiceKeyPrefix$userId', value);
  }
}
