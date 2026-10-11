import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

IconData notificationIconFor(NotificationType type) {
  switch (type) {
    case NotificationType.event:
      return Icons.event;
    case NotificationType.job:
      return Icons.work;
    case NotificationType.message:
      return Icons.message;
    case NotificationType.announcement:
      return Icons.campaign;
    case NotificationType.survey:
      return Icons.poll_outlined;
    case NotificationType.feedback:
      return Icons.feedback_outlined;
    case NotificationType.forum:
      return Icons.forum_outlined;
    case NotificationType.system:
      return Icons.info;
  }
}

/// Theme colour for each notification type's icon.
Color notificationColorFor(NotificationType type) {
  switch (type) {
    case NotificationType.event:
      return PortalTheme.success;
    case NotificationType.job:
      return PortalTheme.navyMid;
    case NotificationType.message:
      return PortalTheme.sky;
    case NotificationType.announcement:
      // Plain gold is too faint for an icon on white.
      return const Color(0xFFD99A00);
    case NotificationType.survey:
    case NotificationType.feedback:
    case NotificationType.forum:
      return PortalTheme.navy;
    case NotificationType.system:
      return PortalTheme.textSecondary;
  }
}

String notificationTypeLabel(NotificationType type) {
  switch (type) {
    case NotificationType.event:
      return 'Events';
    case NotificationType.job:
      return 'Jobs';
    case NotificationType.message:
      return 'Messages';
    case NotificationType.announcement:
      return 'Announcements';
    case NotificationType.survey:
      return 'Surveys';
    case NotificationType.feedback:
      return 'Feedback';
    case NotificationType.forum:
      return 'Forum';
    case NotificationType.system:
      return 'Account';
  }
}

enum NotificationGroup { today, yesterday, thisWeek, earlier }

extension NotificationGroupLabel on NotificationGroup {
  String get label => switch (this) {
        NotificationGroup.today => 'Today',
        NotificationGroup.yesterday => 'Yesterday',
        NotificationGroup.thisWeek => 'This week',
        NotificationGroup.earlier => 'Earlier',
      };
}

NotificationGroup notificationGroupFor(DateTime createdAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return NotificationGroup.today;
  if (diff == 1) return NotificationGroup.yesterday;
  if (diff < 7) return NotificationGroup.thisWeek;
  return NotificationGroup.earlier;
}

/// Newest-first [items] split into ordered, non-empty groups.
List<MapEntry<NotificationGroup, List<NotificationModel>>> groupNotifications(
  List<NotificationModel> items, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final buckets = <NotificationGroup, List<NotificationModel>>{};
  for (final n in items) {
    buckets.putIfAbsent(notificationGroupFor(n.createdAt, at), () => []).add(n);
  }
  return [
    for (final g in NotificationGroup.values)
      if (buckets[g] != null) MapEntry(g, buckets[g]!),
  ];
}

class NotificationGroupHeader extends StatelessWidget {
  const NotificationGroupHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(
        label,
        style: PortalTheme.meta.copyWith(
          fontWeight: FontWeight.w800,
          color: PortalTheme.navy,
          letterSpacing: 0.2,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

/// Alumni-portal notification card.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final created = notification.createdAt;
    final isToday = created.year == now.year &&
        created.month == now.month &&
        created.day == now.day;
    final timeText = isToday
        ? intl.DateFormat('hh:mm a').format(created)
        : intl.DateFormat('MMM d • hh:mm a').format(created);
    final accent = notificationColorFor(notification.type);
    final unread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: '${unread ? 'Unread. ' : ''}${notification.title}. '
            '${notification.message}',
        child: PortalCardShell(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
          elevation: 1,
          shadowColor: PortalTheme.navy.withValues(alpha: 0.08),
          color: unread
              ? PortalTheme.navy.withValues(alpha: 0.03)
              : Colors.white,
          borderColor: unread
              ? PortalTheme.navy.withValues(alpha: 0.16)
              : PortalTheme.border.withValues(alpha: 0.75),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  notificationIconFor(notification.type),
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: PortalTheme.cardTitle.copyWith(
                              fontSize: 14.5,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w700,
                              color: PortalTheme.navy,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: PortalTheme.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: PortalTheme.bodySecondary.copyWith(
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (notification.isHighPriority) ...[
                          _PriorityChip(urgent: notification.isUrgent),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            timeText,
                            style: PortalTheme.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: PortalTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.urgent});

  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: urgent
            ? PortalTheme.danger.withValues(alpha: 0.12)
            : PortalTheme.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        urgent ? 'Urgent' : 'Important',
        style: PortalTheme.caption.copyWith(
          color: urgent ? PortalTheme.danger : PortalTheme.navy,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
