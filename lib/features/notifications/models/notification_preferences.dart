import 'package:alumni_system/features/notifications/models/notification_model.dart';

/// Per-user notification settings (`public.notification_preferences`).
///
/// Channel maps are keyed by [NotificationType.name]; a missing key means
/// "on". The server enforces the same locks: account (`system`) notices and
/// urgent notices always arrive, and survey assignments always appear in-app.
class NotificationPreferences {
  const NotificationPreferences({
    this.inApp = const {},
    this.push = const {},
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
    this.timezone = 'Asia/Manila',
  });

  final Map<NotificationType, bool> inApp;
  final Map<NotificationType, bool> push;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;
  final String timezone;

  static bool isInAppLocked(NotificationType type) =>
      type == NotificationType.system || type == NotificationType.survey;

  static bool isPushLocked(NotificationType type) =>
      type == NotificationType.system;

  bool inAppEnabled(NotificationType type) =>
      isInAppLocked(type) || (inApp[type] ?? true);

  bool pushEnabled(NotificationType type) =>
      isPushLocked(type) || (push[type] ?? true);

  NotificationPreferences copyWith({
    Map<NotificationType, bool>? inApp,
    Map<NotificationType, bool>? push,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    String? timezone,
  }) {
    return NotificationPreferences(
      inApp: inApp ?? this.inApp,
      push: push ?? this.push,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      timezone: timezone ?? this.timezone,
    );
  }

  NotificationPreferences withInApp(NotificationType type, bool enabled) =>
      copyWith(inApp: {...inApp, type: enabled});

  NotificationPreferences withPush(NotificationType type, bool enabled) =>
      copyWith(push: {...push, type: enabled});

  factory NotificationPreferences.fromSupabaseRow(Map<String, dynamic> row) {
    return NotificationPreferences(
      inApp: _parseChannel(row['in_app']),
      push: _parseChannel(row['push']),
      quietHoursEnabled: row['quiet_hours_enabled'] == true,
      quietStartMinutes: parseTimeMinutes(row['quiet_start']) ?? 22 * 60,
      quietEndMinutes: parseTimeMinutes(row['quiet_end']) ?? 7 * 60,
      timezone: (row['timezone']?.toString().trim().isNotEmpty ?? false)
          ? row['timezone'].toString().trim()
          : 'Asia/Manila',
    );
  }

  Map<String, dynamic> toSupabaseRow({required String userId}) {
    return {
      'user_id': userId,
      'in_app': {
        for (final e in inApp.entries)
          if (!isInAppLocked(e.key)) e.key.name: e.value,
      },
      'push': {
        for (final e in push.entries)
          if (!isPushLocked(e.key)) e.key.name: e.value,
      },
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_start': formatTimeMinutes(quietStartMinutes),
      'quiet_end': formatTimeMinutes(quietEndMinutes),
      'timezone': timezone,
    };
  }

  static Map<NotificationType, bool> _parseChannel(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <NotificationType, bool>{};
    for (final type in NotificationType.values) {
      final value = raw[type.name];
      if (value is bool) {
        out[type] = value;
      } else if (value is String) {
        out[type] = value.toLowerCase() != 'false';
      }
    }
    return out;
  }

  /// `"22:00"` / `"22:00:00"` -> minutes after midnight.
  static int? parseTimeMinutes(dynamic raw) {
    final parts = raw?.toString().split(':') ?? const <String>[];
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  static String formatTimeMinutes(int minutes) {
    final m = minutes % (24 * 60);
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final mm = (m % 60).toString().padLeft(2, '0');
    return '$h:$mm';
  }
}
