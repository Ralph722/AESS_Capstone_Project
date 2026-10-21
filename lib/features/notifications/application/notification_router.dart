import 'package:flutter/material.dart';
import 'package:alumni_system/core/navigation/app_navigator.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/announcements/presentation/user_announcements_page.dart';
import 'package:alumni_system/features/events/presentation/events_page.dart';
import 'package:alumni_system/features/feedback/data/feedback_service.dart';
import 'package:alumni_system/features/feedback/presentation/user_feedback_detail_page.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/presentation/forum_topic_page.dart';
import 'package:alumni_system/features/jobs/presentation/job_posting_page.dart';
import 'package:alumni_system/features/messages/presentation/user_messages_page.dart';
import 'package:alumni_system/features/notifications/application/notification_target.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/tracer_page.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/presentation/user_survey_take_page.dart';
import 'package:alumni_system/features/surveys/presentation/user_surveys_page.dart';

/// Opens the screen a notification points to, for in-app taps, push taps and
/// local reminder taps alike.
///
/// The alumni shell ([MainNavigationState]) and the admin dashboard register
/// themselves; a tap that arrives before either is ready (app launched from a
/// notification) is held and replayed once one registers.
abstract final class NotificationRouter {
  static Future<void> Function(NotificationTarget target)? _adminHandler;
  static NotificationTarget? _pending;
  static bool _pendingIsRoute = false;
  static String? _pendingRoute;

  /// Bumped on [clearPending] so in-flight deep links abort after logout.
  static int _openGeneration = 0;

  static bool get adminActive => _adminHandler != null;

  static void registerAdminHandler(
    Future<void> Function(NotificationTarget target) handler,
  ) {
    _adminHandler = handler;
    _flushPending();
  }

  static void unregisterAdminHandler(
    Future<void> Function(NotificationTarget target) handler,
  ) {
    if (identical(_adminHandler, handler)) _adminHandler = null;
  }

  /// Called by [MainNavigationState] once the alumni shell is built.
  static void alumniShellReady() => _flushPending();

  /// Drops a held tap so it cannot open after sign-out / account switch.
  static void clearPending() {
    _pending = null;
    _pendingRoute = null;
    _pendingIsRoute = false;
    _openGeneration++;
  }

  @visibleForTesting
  static bool get hasPending => _pending != null || _pendingRoute != null;

  @visibleForTesting
  static void debugHoldRoute(String route) {
    _pendingIsRoute = true;
    _pendingRoute = route;
    _pending = null;
  }

  /// Marks [n] read (best effort) and opens its destination.
  static Future<void> open(NotificationModel n) async {
    if (!n.isRead) {
      try {
        await NotificationService().markAsRead(n.id);
      } catch (_) {}
    }
    await openTarget(NotificationTarget.resolve(n, isAdmin: adminActive));
  }

  /// Opens a raw route string (push / reminder payloads).
  static Future<void> openRoute(String route) async {
    // Cold-start tap while signed out: hold until login completes.
    if (!_canOpenAlumni && !adminActive) {
      _pendingIsRoute = true;
      _pendingRoute = route;
      _pending = null;
      return;
    }
    if (!_ready) {
      _pendingIsRoute = true;
      _pendingRoute = route;
      _pending = null;
      return;
    }
    final target = NotificationTarget.parseRoute(route, isAdmin: adminActive);
    if (target != null) await openTarget(target);
  }

  static bool get _ready =>
      _adminHandler != null || MainNavigationState.active != null;

  static bool get _canOpenAlumni =>
      AppSession.isSignedIn && MainNavigationState.active != null;

  static Future<void> openTarget(NotificationTarget target) async {
    if (target.destination == NotificationDestination.none) return;
    final admin = _adminHandler;
    if (admin != null) {
      await admin(target);
      return;
    }
    if (!_canOpenAlumni) {
      _pending = target;
      _pendingIsRoute = false;
      _pendingRoute = null;
      return;
    }
    await _openForAlumni(target);
  }

  static void _flushPending() {
    if (!_ready) return;
    // Alumni pending stays until a signed-in shell is ready.
    if (_adminHandler == null && !AppSession.isSignedIn) return;
    final route = _pendingRoute;
    final target = _pending;
    final isRoute = _pendingIsRoute;
    _pending = null;
    _pendingRoute = null;
    _pendingIsRoute = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isRoute && route != null) {
        openRoute(route);
      } else if (target != null) {
        openTarget(target);
      }
    });
  }

  static Future<void> _push(Widget screen) async {
    final nav = AppNavigator.navigator;
    if (nav == null) return;
    await nav.push(MaterialPageRoute(builder: (_) => screen));
  }

  static Future<void> _openForAlumni(NotificationTarget t) async {
    final generation = _openGeneration;
    final shell = MainNavigationState.active;
    final id = t.id;

    bool stillValid() =>
        generation == _openGeneration &&
        AppSession.isSignedIn &&
        (shell == null || identical(MainNavigationState.active, shell));

    switch (t.destination) {
      case NotificationDestination.event:
      case NotificationDestination.eventComments:
        if (id == null) return;
        final comments = t.destination == NotificationDestination.eventComments;
        if (shell != null) {
          if (!stillValid()) return;
          await shell.openEvent(id, openComments: comments);
        } else {
          await _push(
            EventsScreen(initialEventId: id, openCommentsOnLaunch: comments),
          );
        }
      case NotificationDestination.eventsTab:
        if (!stillValid()) return;
        await shell?.switchToTab(PortalTabs.events);
      case NotificationDestination.job:
        if (id == null) return;
        if (shell != null) {
          if (!stillValid()) return;
          await shell.openJob(id);
        } else {
          await _push(JobPostingScreen(initialJobId: id));
        }
      case NotificationDestination.jobsTab:
        if (!stillValid()) return;
        await shell?.switchToTab(PortalTabs.jobs);
      case NotificationDestination.tracer:
        if (!stillValid()) return;
        await shell?.switchToTab(PortalTabs.tracer);
      case NotificationDestination.tracerSurvey:
        if (id == null) return;
        final survey = await _safe(() => SurveyService().getSurvey(id));
        if (!stillValid()) return;
        if (survey == null || !survey.isChedGtsBuiltin) {
          AppNavigator.showMessage('This tracer study is no longer available.');
          return;
        }
        if (shell != null) {
          if (!stillValid()) return;
          await shell.openTracerSurvey(id);
        } else {
          await _push(TracerScreen(requestedSurveyId: id));
        }
      case NotificationDestination.profile:
        if (!stillValid()) return;
        await shell?.switchToTab(PortalTabs.profile);
      case NotificationDestination.survey:
        if (id == null) return;
        final userId = AppSession.userId;
        if (userId == null) return;
        final access = await _safe(
          () => SurveyService().getSurveyAccess(id, userId),
        );
        if (!stillValid()) return;
        if (access == null || !access.canOpen) {
          AppNavigator.showMessage(
            access?.userMessage ?? 'This survey is no longer available.',
          );
          return;
        }
        await _push(UserSurveyTakeScreen(surveyId: id));
      case NotificationDestination.surveysList:
        if (!stillValid()) return;
        await _push(const UserSurveysScreen());
      case NotificationDestination.announcement:
        if (id != null) {
          final item = await _safe(
            () => AnnouncementService().getAnnouncement(id),
          );
          if (!stillValid()) return;
          if (item == null) {
            AppNavigator.showMessage(
              'This announcement is no longer available.',
            );
            return;
          }
        }
        if (!stillValid()) return;
        await _push(UserAnnouncementsScreen(initialAnnouncementId: id));
      case NotificationDestination.feedback:
        if (id == null) return;
        final item = await _safe(() => FeedbackService().getFeedbackById(id));
        if (!stillValid()) return;
        if (item == null) {
          AppNavigator.showMessage(
            'This feedback item is no longer available.',
          );
          return;
        }
        await _push(UserFeedbackDetailScreen(feedbackId: id));
      case NotificationDestination.forumTopic:
        if (id == null) return;
        final topic = await _safe(() => ForumService().getTopic(id));
        if (!stillValid()) return;
        if (topic == null) {
          AppNavigator.showMessage('This discussion is no longer available.');
          return;
        }
        if (shell != null) {
          await shell.openForumTopic(id);
        } else {
          await _push(ForumTopicScreen(topicId: id));
        }
      case NotificationDestination.messages:
        if (!stillValid()) return;
        await _push(const UserMessagesScreen(isTabActive: true));
      case NotificationDestination.adminEvent:
      case NotificationDestination.adminFeedback:
      case NotificationDestination.adminConversation:
      case NotificationDestination.adminMenu:
      case NotificationDestination.none:
        return;
    }
  }

  static Future<T?> _safe<T>(Future<T?> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }
}
