import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/core/services/app_session.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification plugin
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap if needed (e.g. deep link via response.payload)
  }

  /// Schedule reminder notifications for an event.
  /// Schedules: 3 days before, 1 day before, and day-of (6 AM local).
  Future<void> scheduleEventReminder(AlumniEvent event) async {
    if (!_initialized) {
      await initialize();
    }

    final userId = AppSession.userId;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final eventDate = event.date;
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

    final baseId = event.id.hashCode.abs();
    final threeDaysId = baseId * 10 + 3;
    final dayBeforeId = baseId * 10 + 1;
    final dayOfEventId = baseId * 10 + 2;

    if (threeDaysBefore.isAfter(now)) {
      await _scheduleNotification(
        id: threeDaysId,
        title: 'Upcoming: ${event.theme}',
        body: '${event.theme} is in 3 days at ${event.venue}.',
        scheduledDate: threeDaysBefore,
        payload: event.id,
      );
    }

    if (dayBefore.isAfter(now)) {
      await _scheduleNotification(
        id: dayBeforeId,
        title: 'Event Reminder: ${event.theme}',
        body: '${event.theme} is happening tomorrow! Don\'t forget to attend.',
        scheduledDate: dayBefore,
        payload: event.id,
      );
    }

    if (dayOfEvent.isAfter(now)) {
      await _scheduleNotification(
        id: dayOfEventId,
        title: 'Event Today: ${event.theme}',
        body: '${event.theme} is happening today at ${event.venue}!',
        scheduledDate: dayOfEvent,
        payload: event.id,
      );
    }
  }

  /// Schedule a single notification
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel all reminders for an event
  Future<void> cancelEventReminders(String eventId) async {
    if (!_initialized) {
      await initialize();
    }

    final baseId = eventId.hashCode.abs();
    await _notifications.cancel(baseId * 10 + 1);
    await _notifications.cancel(baseId * 10 + 2);
    await _notifications.cancel(baseId * 10 + 3);
  }

  /// Cancel all reminders
  Future<void> cancelAllReminders() async {
    if (!_initialized) {
      await initialize();
    }

    await _notifications.cancelAll();
  }
}

