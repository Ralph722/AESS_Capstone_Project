import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alumni_system/models/event_model.dart';

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
    // Handle notification tap if needed
    print('Notification tapped: ${response.payload}');
  }

  /// Schedule reminder notifications for an event
  /// Schedules two notifications: one day before and on the day of the event
  Future<void> scheduleEventReminder(AlumniEvent event) async {
    if (!_initialized) {
      await initialize();
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final eventDate = event.date;
    final now = DateTime.now();

    // Calculate day before (24 hours before event at 6 AM)
    final dayBefore = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day - 1,
      6, // 6 AM
    );

    // Calculate day of event (6 AM on event day)
    final dayOfEvent = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      6, // 6 AM
    );

    // Generate unique IDs based on event ID hash
    // Use positive hash codes to ensure valid notification IDs
    final baseId = event.id.hashCode.abs();
    final dayBeforeId = baseId * 10 + 1; // Unique ID for day before
    final dayOfEventId = baseId * 10 + 2; // Unique ID for day of event

    // Only schedule if the dates are in the future
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
      print('Error scheduling notification: $e');
      rethrow;
    }
  }

  /// Cancel all reminders for an event
  Future<void> cancelEventReminders(String eventId) async {
    if (!_initialized) {
      await initialize();
    }

    // Generate the same IDs used when scheduling
    final baseId = eventId.hashCode.abs();
    final dayBeforeId = baseId * 10 + 1;
    final dayOfEventId = baseId * 10 + 2;

    // Cancel both notifications (day before and day of event)
    await _notifications.cancel(dayBeforeId);
    await _notifications.cancel(dayOfEventId);
  }

  /// Cancel all reminders
  Future<void> cancelAllReminders() async {
    if (!_initialized) {
      await initialize();
    }

    await _notifications.cancelAll();
  }
}

