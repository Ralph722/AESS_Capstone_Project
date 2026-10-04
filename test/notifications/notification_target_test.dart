import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/notifications/application/notification_target.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/features/notifications/models/notification_preferences.dart';
import 'package:alumni_system/features/notifications/presentation/widgets/notification_tile.dart';

NotificationModel _n({
  NotificationType type = NotificationType.system,
  String? route,
  String? relatedId,
  Map<String, dynamic>? data,
  DateTime? createdAt,
}) {
  return NotificationModel(
    id: 'n1',
    userId: 'u1',
    type: type,
    title: 't',
    message: 'm',
    relatedId: relatedId,
    isRead: false,
    createdAt: createdAt ?? DateTime(2026, 10, 1, 9),
    data: data,
    route: route,
  );
}

void main() {
  group('route parsing (alumni)', () {
    NotificationTarget? parse(String r) => NotificationTarget.parseRoute(r);

    test('event and comments', () {
      expect(parse('event/e1')!.destination, NotificationDestination.event);
      expect(parse('event/e1')!.id, 'e1');
      expect(
        parse('event/e1/comments')!.destination,
        NotificationDestination.eventComments,
      );
    });

    test('job, survey, tracer, announcement, feedback, forum, profile', () {
      expect(parse('job/j1')!.destination, NotificationDestination.job);
      expect(parse('survey/s1')!.destination, NotificationDestination.survey);
      expect(parse('tracer')!.destination, NotificationDestination.tracer);
      expect(
        parse('announcement/a1')!.destination,
        NotificationDestination.announcement,
      );
      expect(parse('feedback/f1')!.id, 'f1');
      expect(
        parse('forum/t1')!.destination,
        NotificationDestination.forumTopic,
      );
      expect(parse('profile')!.destination, NotificationDestination.profile);
      expect(parse('messages')!.destination, NotificationDestination.messages);
    });

    test('unknown or empty routes return null', () {
      expect(parse(''), isNull);
      expect(parse('nope/1'), isNull);
      expect(NotificationTarget.parseRoute(null), isNull);
    });
  });

  group('route parsing (admin)', () {
    NotificationTarget? parse(String r) =>
        NotificationTarget.parseRoute(r, isAdmin: true);

    test('entity deep links', () {
      final ev = parse('admin/events/e1')!;
      expect(ev.destination, NotificationDestination.adminEvent);
      expect(ev.id, 'e1');
      expect(ev.adminMenuIndex, AdminNotificationMenu.events);

      final fb = parse('admin/feedback/f1')!;
      expect(fb.destination, NotificationDestination.adminFeedback);
      expect(fb.adminMenuIndex, AdminNotificationMenu.feedback);
    });

    test('module routes', () {
      expect(parse('admin/forum')!.adminMenuIndex, AdminNotificationMenu.forum);
      expect(parse('admin/alumni')!.adminMenuIndex, AdminNotificationMenu.alumni);
      expect(
        parse('admin/surveys')!.adminMenuIndex,
        AdminNotificationMenu.surveys,
      );
    });

    test('conversation route for admins', () {
      final t = parse('messages/u9')!;
      expect(t.destination, NotificationDestination.adminConversation);
      expect(t.id, 'u9');
    });
  });

  group('resolve', () {
    test('alumni route wins over type', () {
      final t = NotificationTarget.resolve(
        _n(type: NotificationType.survey, route: 'tracer', relatedId: 's1'),
        isAdmin: false,
      );
      expect(t.destination, NotificationDestination.tracer);
    });

    test('legacy survey rows keep opening the survey list', () {
      final t = NotificationTarget.resolve(
        _n(type: NotificationType.survey, relatedId: 's1'),
        isAdmin: false,
      );
      expect(t.destination, NotificationDestination.surveysList);
    });

    test('legacy event reply rows open comments', () {
      final t = NotificationTarget.resolve(
        _n(
          type: NotificationType.event,
          relatedId: 'e1',
          data: {'commentId': 'c1'},
        ),
        isAdmin: false,
      );
      expect(t.destination, NotificationDestination.eventComments);
      expect(t.id, 'e1');
    });

    test('admin with an alumni-style route falls back to the module', () {
      final t = NotificationTarget.resolve(
        _n(type: NotificationType.job, route: 'job/j1'),
        isAdmin: true,
      );
      expect(t.destination, NotificationDestination.adminMenu);
      expect(t.adminMenuIndex, AdminNotificationMenu.jobs);
    });

    test('legacy admin message opens the sender conversation', () {
      final t = NotificationTarget.resolve(
        _n(
          type: NotificationType.message,
          data: {'conversationUserId': 'u5'},
        ),
        isAdmin: true,
      );
      expect(t.destination, NotificationDestination.adminConversation);
      expect(t.id, 'u5');
    });

    test('system notice without route does nothing for alumni', () {
      expect(
        NotificationTarget.resolve(_n(), isAdmin: false).destination,
        NotificationDestination.none,
      );
    });
  });

  group('model', () {
    test('fromSupabaseRow reads new columns and hides internal keys', () {
      final n = NotificationModel.fromSupabaseRow({
        'id': 'x',
        'user_id': 'u',
        'type': 'announcement',
        'title': 'T',
        'body': 'B',
        'is_read': false,
        'created_at': '2026-10-01T01:00:00Z',
        'priority': 'urgent',
        'route': 'announcement/a1',
        'dedupe_key': 'announcement:a1:published',
        'data': {'relatedId': 'a1', 'push': true, 'announcementId': 'a1'},
      });
      expect(n.priority, NotificationPriority.urgent);
      expect(n.isUrgent, isTrue);
      expect(n.route, 'announcement/a1');
      expect(n.relatedId, 'a1');
      expect(n.data!.containsKey('push'), isFalse);
      expect(n.data!['announcementId'], 'a1');
    });

    test('unknown priority falls back to normal', () {
      final n = NotificationModel.fromSupabaseRow({
        'id': 'x',
        'type': 'job',
        'priority': 'weird',
      });
      expect(n.priority, NotificationPriority.normal);
      expect(n.route, isNull);
    });
  });

  group('grouping', () {
    final now = DateTime(2026, 10, 8, 15);

    test('buckets by calendar day', () {
      expect(
        notificationGroupFor(DateTime(2026, 10, 8, 1), now),
        NotificationGroup.today,
      );
      expect(
        notificationGroupFor(DateTime(2026, 10, 7, 23), now),
        NotificationGroup.yesterday,
      );
      expect(
        notificationGroupFor(DateTime(2026, 10, 3), now),
        NotificationGroup.thisWeek,
      );
      expect(
        notificationGroupFor(DateTime(2026, 9, 30), now),
        NotificationGroup.earlier,
      );
    });

    test('groups keep order and skip empty buckets', () {
      final groups = groupNotifications([
        _n(createdAt: DateTime(2026, 10, 8, 9)),
        _n(createdAt: DateTime(2026, 9, 1)),
      ], now: now);
      expect(groups.map((g) => g.key), [
        NotificationGroup.today,
        NotificationGroup.earlier,
      ]);
    });
  });

  group('preferences', () {
    test('missing keys mean on; locks are enforced', () {
      const p = NotificationPreferences();
      expect(p.inAppEnabled(NotificationType.job), isTrue);
      final off = p
          .withInApp(NotificationType.job, false)
          .withInApp(NotificationType.survey, false)
          .withPush(NotificationType.system, false);
      expect(off.inAppEnabled(NotificationType.job), isFalse);
      expect(off.inAppEnabled(NotificationType.survey), isTrue);
      expect(off.pushEnabled(NotificationType.system), isTrue);
    });

    test('row round trip; locked keys are not written', () {
      final p = const NotificationPreferences()
          .withInApp(NotificationType.forum, false)
          .withInApp(NotificationType.survey, false)
          .withPush(NotificationType.job, false)
          .copyWith(
            quietHoursEnabled: true,
            quietStartMinutes: 21 * 60 + 30,
            quietEndMinutes: 6 * 60,
          );
      final row = p.toSupabaseRow(userId: 'u');
      expect(row['in_app'], {'forum': false});
      expect(row['push'], {'job': false});
      expect(row['quiet_start'], '21:30');
      expect(row['quiet_end'], '06:00');

      final back = NotificationPreferences.fromSupabaseRow({
        ...row,
        'quiet_start': '21:30:00',
      });
      expect(back.inAppEnabled(NotificationType.forum), isFalse);
      expect(back.pushEnabled(NotificationType.job), isFalse);
      expect(back.quietHoursEnabled, isTrue);
      expect(back.quietStartMinutes, 21 * 60 + 30);
      expect(back.quietEndMinutes, 6 * 60);
    });

    test('bad time strings are rejected', () {
      expect(NotificationPreferences.parseTimeMinutes('25:00'), isNull);
      expect(NotificationPreferences.parseTimeMinutes('x'), isNull);
      expect(NotificationPreferences.parseTimeMinutes(null), isNull);
    });
  });
}
