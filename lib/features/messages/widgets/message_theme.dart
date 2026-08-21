import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Shared visual tokens for the Messages module (alumni + admin).
///
/// Aliases [PortalTheme] so message chrome stays consistent with the portal.
class MessageTheme {
  MessageTheme._();

  static const Color navy = PortalTheme.navy;
  static const Color navyMid = PortalTheme.navyMid;
  static const Color pageBg = PortalTheme.pageBg;
  static const Color border = PortalTheme.border;
  static const Color textPrimary = PortalTheme.textPrimary;
  static const Color textSecondary = PortalTheme.textSecondary;
  static const Color textMuted = PortalTheme.textMuted;

  static const Color sentBubble = navy;
  static const Color receivedBubble = Color(0xFFEFF1F7);
  static const Color sentText = Colors.white;
  static const Color receivedText = textPrimary;
  static const Color failed = PortalTheme.danger;
  static const Color sending = textMuted;

  static const double bubbleRadius = PortalTheme.radiusXl;
  static const double bubbleRadiusTight = 6;
  /// Fraction of the *thread pane* width (not the full window).
  static const double maxBubbleWidthFactor = 0.72;
  /// Hard cap so wide admin panes don't stretch long messages edge-to-edge.
  static const double maxBubbleWidthPx = 420;
  static const int messageMaxLength = 4000;

  /// Thread list padding (matches AdminDensity.cardPadding).
  static const double threadPadding = 12;

  static const List<String> reactionEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  static const String officeDisplayName = 'Alumni Office';
  static const String supportStatusLabel = 'Support';
  static const String supportHoursHint =
      'Typically replies during office hours';

  static LinearGradient get headerGradient => PortalTheme.navyGradient;
}

/// Relative time labels shared by alumni + admin message UIs.
String formatMessageRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d';
  } else {
    return formatMessageDateLabel(dateTime);
  }
}

String formatMessageClockTime(DateTime dateTime) {
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final period = hour >= 12 ? 'PM' : 'AM';
  return '$h12:$minute $period';
}

String formatMessageDateLabel(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (dateTime.year == now.year) {
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }
  return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
}

bool isSameMessageCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
