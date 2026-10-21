import 'package:alumni_system/features/notifications/models/notification_model.dart';

enum NotificationDestination {
  event,
  eventComments,
  job,
  survey,
  surveysList,
  tracer,
  tracerSurvey,
  announcement,
  feedback,
  forumTopic,
  messages,
  profile,
  eventsTab,
  jobsTab,
  adminEvent,
  adminFeedback,
  adminConversation,
  adminMenu,
  none,
}

/// Admin dashboard menu indices used by notification deep links.
abstract final class AdminNotificationMenu {
  static const dashboard = 0;
  static const events = 1;
  static const alumni = 2;
  static const jobs = 5;
  static const messages = 6;
  static const surveys = 10;
  static const announcements = 11;
  static const forum = 12;
  static const feedback = 14;

  static int forType(NotificationType type) => switch (type) {
    NotificationType.event => events,
    NotificationType.job => jobs,
    NotificationType.message => messages,
    NotificationType.announcement => announcements,
    NotificationType.survey => surveys,
    NotificationType.feedback => feedback,
    NotificationType.forum => forum,
    NotificationType.system => dashboard,
  };
}

/// Where tapping a notification should go. Built from the server `route`
/// (e.g. `event/{id}/comments`, `admin/feedback/{id}`), falling back to the
/// type + ids on rows created before routes existed.
class NotificationTarget {
  const NotificationTarget(this.destination, {this.id, this.adminMenuIndex});

  static const none = NotificationTarget(NotificationDestination.none);

  final NotificationDestination destination;
  final String? id;
  final int? adminMenuIndex;

  static NotificationTarget resolve(
    NotificationModel n, {
    required bool isAdmin,
  }) {
    final fromRoute = parseRoute(n.route, isAdmin: isAdmin);
    if (fromRoute != null) {
      if (isAdmin && !_isAdminDestination(fromRoute.destination)) {
        return _adminFallback(n);
      }
      return fromRoute;
    }
    return isAdmin ? _adminFallback(n) : _alumniFallback(n);
  }

  /// Null when [route] is empty or not recognised.
  static NotificationTarget? parseRoute(String? route, {bool isAdmin = false}) {
    final raw = route?.trim() ?? '';
    if (raw.isEmpty) return null;
    final parts = raw
        .split('/')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    final id = parts.length > 1 ? parts[1] : null;

    switch (parts.first) {
      case 'event':
        if (id == null) {
          return const NotificationTarget(NotificationDestination.eventsTab);
        }
        return NotificationTarget(
          parts.length > 2 && parts[2] == 'comments'
              ? NotificationDestination.eventComments
              : NotificationDestination.event,
          id: id,
          adminMenuIndex: isAdmin ? AdminNotificationMenu.events : null,
        );
      case 'job':
        return id == null
            ? const NotificationTarget(NotificationDestination.jobsTab)
            : NotificationTarget(
                NotificationDestination.job,
                id: id,
                adminMenuIndex: isAdmin ? AdminNotificationMenu.jobs : null,
              );
      case 'survey':
        return id == null
            ? const NotificationTarget(NotificationDestination.surveysList)
            : NotificationTarget(
                NotificationDestination.survey,
                id: id,
                adminMenuIndex: isAdmin ? AdminNotificationMenu.surveys : null,
              );
      case 'tracer':
        return id == null
            ? const NotificationTarget(NotificationDestination.tracer)
            : NotificationTarget(
                NotificationDestination.tracerSurvey,
                id: id,
                adminMenuIndex: isAdmin ? AdminNotificationMenu.surveys : null,
              );
      case 'announcement':
        return NotificationTarget(NotificationDestination.announcement, id: id);
      case 'feedback':
        return id == null
            ? null
            : NotificationTarget(NotificationDestination.feedback, id: id);
      case 'forum':
        return id == null
            ? null
            : NotificationTarget(
                NotificationDestination.forumTopic,
                id: id,
                adminMenuIndex: isAdmin ? AdminNotificationMenu.forum : null,
              );
      case 'messages':
        if (isAdmin) {
          return NotificationTarget(
            NotificationDestination.adminConversation,
            id: id,
            adminMenuIndex: AdminNotificationMenu.messages,
          );
        }
        return const NotificationTarget(NotificationDestination.messages);
      case 'profile':
        return const NotificationTarget(NotificationDestination.profile);
      case 'admin':
        return _parseAdmin(parts.skip(1).toList());
    }
    return null;
  }

  static NotificationTarget? _parseAdmin(List<String> parts) {
    if (parts.isEmpty) {
      return const NotificationTarget(
        NotificationDestination.adminMenu,
        adminMenuIndex: AdminNotificationMenu.dashboard,
      );
    }
    final id = parts.length > 1 ? parts[1] : null;
    switch (parts.first) {
      case 'events':
        return id == null
            ? const NotificationTarget(
                NotificationDestination.adminMenu,
                adminMenuIndex: AdminNotificationMenu.events,
              )
            : NotificationTarget(
                NotificationDestination.adminEvent,
                id: id,
                adminMenuIndex: AdminNotificationMenu.events,
              );
      case 'feedback':
        return id == null
            ? const NotificationTarget(
                NotificationDestination.adminMenu,
                adminMenuIndex: AdminNotificationMenu.feedback,
              )
            : NotificationTarget(
                NotificationDestination.adminFeedback,
                id: id,
                adminMenuIndex: AdminNotificationMenu.feedback,
              );
      case 'messages':
        return NotificationTarget(
          NotificationDestination.adminConversation,
          id: id,
          adminMenuIndex: AdminNotificationMenu.messages,
        );
    }
    final menu = switch (parts.first) {
      'alumni' => AdminNotificationMenu.alumni,
      'jobs' => AdminNotificationMenu.jobs,
      'surveys' => AdminNotificationMenu.surveys,
      'announcements' => AdminNotificationMenu.announcements,
      'forum' => AdminNotificationMenu.forum,
      _ => null,
    };
    if (menu == null) return null;
    return NotificationTarget(
      NotificationDestination.adminMenu,
      adminMenuIndex: menu,
    );
  }

  static bool _isAdminDestination(NotificationDestination d) =>
      d == NotificationDestination.adminEvent ||
      d == NotificationDestination.adminFeedback ||
      d == NotificationDestination.adminConversation ||
      d == NotificationDestination.adminMenu;

  static String? _dataId(NotificationModel n, String key) {
    final value = (n.data?[key] ?? n.relatedId)?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static NotificationTarget _alumniFallback(NotificationModel n) {
    final data = n.data ?? const <String, dynamic>{};
    switch (n.type) {
      case NotificationType.event:
        final id = _dataId(n, 'eventId');
        if (id == null) {
          return const NotificationTarget(NotificationDestination.eventsTab);
        }
        final comments =
            data['target'] == 'event_comments' ||
            data.containsKey('commentId') ||
            data.containsKey('replyId');
        return NotificationTarget(
          comments
              ? NotificationDestination.eventComments
              : NotificationDestination.event,
          id: id,
        );
      case NotificationType.job:
        final id = _dataId(n, 'jobId');
        return id == null
            ? const NotificationTarget(NotificationDestination.jobsTab)
            : NotificationTarget(NotificationDestination.job, id: id);
      case NotificationType.message:
        return const NotificationTarget(NotificationDestination.messages);
      case NotificationType.survey:
        return const NotificationTarget(NotificationDestination.surveysList);
      case NotificationType.announcement:
        return NotificationTarget(
          NotificationDestination.announcement,
          id: _dataId(n, 'announcementId'),
        );
      case NotificationType.feedback:
        final id = _dataId(n, 'feedbackId');
        return id == null
            ? none
            : NotificationTarget(NotificationDestination.feedback, id: id);
      case NotificationType.forum:
        final id = _dataId(n, 'topicId');
        return id == null
            ? none
            : NotificationTarget(NotificationDestination.forumTopic, id: id);
      case NotificationType.system:
        return none;
    }
  }

  static NotificationTarget _adminFallback(NotificationModel n) {
    final menu = AdminNotificationMenu.forType(n.type);
    switch (n.type) {
      case NotificationType.message:
        final id = (n.data?['conversationUserId'] ?? n.data?['senderId'])
            ?.toString()
            .trim();
        return NotificationTarget(
          NotificationDestination.adminConversation,
          id: (id == null || id.isEmpty) ? null : id,
          adminMenuIndex: menu,
        );
      case NotificationType.feedback:
        final id = _dataId(n, 'feedbackId');
        if (id != null) {
          return NotificationTarget(
            NotificationDestination.adminFeedback,
            id: id,
            adminMenuIndex: menu,
          );
        }
        break;
      case NotificationType.event:
        if (n.data?['target'] == 'event_comments') {
          final id = _dataId(n, 'eventId');
          if (id != null) {
            return NotificationTarget(
              NotificationDestination.adminEvent,
              id: id,
              adminMenuIndex: menu,
            );
          }
        }
        break;
      default:
        break;
    }
    return NotificationTarget(
      NotificationDestination.adminMenu,
      adminMenuIndex: menu,
    );
  }

  @override
  String toString() =>
      'NotificationTarget($destination, id: $id, menu: $adminMenuIndex)';
}
