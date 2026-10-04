import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/core/services/app_session.dart';

/// On-device event reminders (Android / iOS). No-op on web.
///
/// Reminder failures never throw: an RSVP must not look failed because the
/// phone refused to schedule a local notification.
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  static void Function(String eventId)? _onReminderTap;
  static String? _pendingTapEventId;

  /// Receives the tapped reminder's payload (an event id). A tap that
  /// launched the app before a handler was set is delivered on assignment.
  static set onReminderTap(void Function(String eventId)? handler) {
    _onReminderTap = handler;
    final pending = _pendingTapEventId;
    if (handler != null && pending != null) {
      _pendingTapEventId = null;
      handler(pending);
    }
  }

  static const _routePayloadPrefix = 'route:';
  static void Function(String route)? _onRouteTap;
  static String? _pendingTapRoute;

  /// Receives taps on pushed alerts shown while the app was open.
  static set onRouteTap(void Function(String route)? handler) {
    _onRouteTap = handler;
    final pending = _pendingTapRoute;
    if (handler != null && pending != null) {
      _pendingTapRoute = null;
      handler(pending);
    }
  }

  /// Channel used for pushed alerts; the server sends `channel_id` to match.
  static const alertChannel = AndroidNotificationChannel(
    'aess_notifications',
    'Alumni notifications',
    description: 'Messages, events, jobs, surveys and announcements',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supported => !kIsWeb;

  Future<void> initialize() async {
    if (_initialized || !_supported) return;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(alertChannel);
      await android?.requestNotificationsPermission();

      _initialized = true;

      final launch = await _notifications.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        _onNotificationTapped(response);
      }
    } catch (e) {
      debugPrint('ReminderService.initialize failed: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload?.trim() ?? '';
    if (payload.startsWith(_routePayloadPrefix)) {
      final route = payload.substring(_routePayloadPrefix.length);
      if (route.isEmpty) return;
      final handler = _onRouteTap;
      if (handler == null) {
        _pendingTapRoute = route;
      } else {
        handler(route);
      }
      return;
    }

    final eventId = payload;
    if (eventId.isEmpty) return;
    final handler = _onReminderTap;
    if (handler == null) {
      _pendingTapEventId = eventId;
    } else {
      handler(eventId);
    }
  }

  /// Schedules: 3 days before, 1 day before, and day-of (6 AM local).
  Future<void> scheduleEventReminder(AlumniEvent event) async {
    if (!_supported) return;
    if (!_initialized) await initialize();
    if (!_initialized || AppSession.userId == null) return;

    final eventDate = event.date.toLocal();
    final now = DateTime.now();

    final threeDaysBefore = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day - 3,
      6,
    );
    final dayBefore = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day - 1,
      6,
    );
    final dayOfEvent = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      6,
    );

    final ids = reminderIdsFor(event.id);

    if (threeDaysBefore.isAfter(now)) {
      await _scheduleNotification(
        id: ids[0],
        title: 'Upcoming: ${event.theme}',
        body: '${event.theme} is in 3 days at ${event.venue}.',
        scheduledDate: threeDaysBefore,
        payload: event.id,
      );
    }

    if (dayBefore.isAfter(now)) {
      await _scheduleNotification(
        id: ids[1],
        title: 'Event Reminder: ${event.theme}',
        body: '${event.theme} is happening tomorrow! Don\'t forget to attend.',
        scheduledDate: dayBefore,
        payload: event.id,
      );
    }

    if (dayOfEvent.isAfter(now)) {
      await _scheduleNotification(
        id: ids[2],
        title: 'Event Today: ${event.theme}',
        body: '${event.theme} is happening today at ${event.venue}!',
        scheduledDate: dayOfEvent,
        payload: event.id,
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'event_reminders',
            'Event Reminders',
            channelDescription: 'Notifications for event reminders',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('ReminderService: could not schedule $id: $e');
    }
  }

  /// Shows a pushed alert that arrived while the app was in the foreground
  /// (Android does not display those on its own).
  Future<void> showPushedAlert({
    required String tag,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!_supported) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;
    try {
      await _notifications.show(
        _stableId(tag),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            alertChannel.id,
            alertChannel.name,
            channelDescription: alertChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            tag: tag,
          ),
        ),
        payload: (route == null || route.isEmpty)
            ? null
            : '$_routePayloadPrefix$route',
      );
    } catch (e) {
      debugPrint('ReminderService: could not show pushed alert: $e');
    }
  }

  Future<void> cancelEventReminders(String eventId) async {
    if (!_supported) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;
    for (final id in reminderIdsFor(eventId)) {
      try {
        await _notifications.cancel(id);
      } catch (_) {}
    }
  }

  /// Re-aligns reminders with the latest event data for events the user is
  /// going to (picks up admin date changes and cancellations).
  Future<void> syncGoingEvents(Iterable<AlumniEvent> goingEvents) async {
    if (!_supported) return;
    for (final event in goingEvents) {
      await cancelEventReminders(event.id);
      if (!event.cancelled) {
        await scheduleEventReminder(event);
      }
    }
  }

  Future<void> cancelAllReminders() async {
    if (!_supported) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;
    try {
      await _notifications.cancelAll();
    } catch (_) {}
  }

  /// Three stable 32-bit-safe ids per event (3 days, 1 day, day-of).
  ///
  /// `String.hashCode` is not stable across app launches, which made
  /// cancelling after a restart miss the scheduled reminders.
  @visibleForTesting
  static List<int> reminderIdsFor(String eventId) {
    final base = (_fnv1a(eventId) % 100000000) * 10;
    return [base + 3, base + 1, base + 2];
  }

  /// Pushed alerts use ids at or above 1,000,000,000, above every reminder id.
  static int _stableId(String tag) => 1000000000 + _fnv1a(tag) % 1000000000;

  static int _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
