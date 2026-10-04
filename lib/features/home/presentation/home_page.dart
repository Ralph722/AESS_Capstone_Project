import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:async';
import 'package:alumni_system/core/navigation/app_navigator.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/jobs/presentation/job_posting_page.dart';
import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_events.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/presentation/events_page.dart';
import 'package:alumni_system/features/notifications/presentation/notification_panel_sheet.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/features/surveys/presentation/user_surveys_page.dart';
import 'package:alumni_system/features/surveys/presentation/user_survey_take_page.dart';
import 'package:alumni_system/features/announcements/presentation/user_announcements_page.dart';
import 'package:alumni_system/features/forum/presentation/forum_topic_page.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/data/forum_refresh_bus.dart';
import 'package:alumni_system/features/forum/models/forum_filters.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/shared/widgets/aess_logo.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/features/home/data/survey_attention_reminder.dart';
import 'package:alumni_system/features/home/models/home_calendar_item.dart';
import 'package:alumni_system/features/home/widgets/home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSelectTab});

  /// Switches [MainNavigation] tab in-place (no full route rebuild).
  final ValueChanged<int>? onSelectTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with RouteAware {
  final EventService _eventService = EventService();
  final JobService _jobService = JobService();
  final MessageService _messageService = MessageService();
  final NotificationService _notificationService = NotificationService();
  final UserProfileService _userProfileService = UserProfileService();
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<int>? _messagesCountSubscription;
  StreamSubscription<int>? _notificationsCountSubscription;
  StreamSubscription<String?>? _avatarSubscription;
  StreamSubscription<void>? _forumRefreshSubscription;

  // Counts for stat cards
  int eventsCount = 0;
  int announcementsCount = 0;
  int communityTodayCount = 0;
  int messagesCount = 0;
  int unreadNotificationsCount = 0;
  double _tracerCompletion = 0;
  int _pendingCustomSurveys = 0;
  bool _openTracerAttention = false;
  bool _attentionDueSoon = false;
  String? _attentionDueSoonLabel;
  String? _tracerAttentionSubtitle;
  String? _surveyAttentionSubtitle;

  // Data for home screen sections
  List<AlumniEvent> upcomingEvents = [];
  List<AlumniEvent> _allUpcomingEvents = [];
  List<JobPosting> _activeJobs = [];
  List<HomeCalendarItem> _calendarItems = [];
  List<ForumTopic> _communityTopics = [];
  bool isLoadingEvents = false;
  bool isLoadingCommunity = false;
  bool isLoadingCalendar = false;
  String? _eventsError;
  String? _communityError;

  // Profile data
  String? _profileImageUrl;
  String? _displayName;
  String? _program;
  String? _batchYear;
  final SurveyService _surveyService = SurveyService();
  final AnnouncementService _announcementService = AnnouncementService();
  final ForumService _forumService = ForumService();

  @override
  void initState() {
    super.initState();
    _startMessagesCountListener();
    _startNotificationsListener();
    _avatarSubscription = UserProfileEvents.onAvatarChanged.listen((url) {
      if (!mounted) return;
      setState(() => _profileImageUrl = url);
    });
    _forumRefreshSubscription = ForumRefreshBus.stream.listen((_) {
      if (!mounted) return;
      unawaited(_loadCommunitySection());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDashboardContent();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) AppNavigator.routeObserver.subscribe(this, route);
  }

  /// A screen opened over the dashboard (e.g. from a push tap) was closed.
  @override
  void didPopNext() => unawaited(_maybeShowAttentionReminder());

  /// True only while the dashboard is on screen: Home tab selected and no
  /// route (screen, dialog, sheet) open above it.
  bool get _dashboardVisible {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    return MainNavigationState.active?.isHomeTabActive ?? true;
  }

  /// Called when Home tab becomes visible again (see [MainNavigation]).
  Future<void> refreshDashboard() => _loadDashboardContent();

  Future<void> _loadDashboardContent() async {
    if (mounted) {
      setState(() => isLoadingCalendar = true);
    }
    await Future.wait([
      _loadUpcomingEvents(),
      _loadCalendarJobs(),
      _loadUserProfile(),
      _loadSurveyAttention(),
      _loadAnnouncements(),
      _loadCommunitySection(),
      _ensureUserRow(),
    ]);
    await _buildCalendarItems();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = AppSession.userId;
      if (userId == null) return;

      final row = await _supabase
          .from('users')
          .select('display_name, profile_image_base64')
          .eq('id', userId)
          .maybeSingle();
      final tracer = await _userProfileService.getTracerProfile(userId);
      if (mounted) {
        setState(() {
          _profileImageUrl = row?['profile_image_base64'] as String?;
          _displayName =
              (row?['display_name'] as String?)?.trim().isNotEmpty == true
              ? row!['display_name'] as String
              : tracer?.displayName;
          _program = tracer?.program.trim().isNotEmpty == true
              ? tracer!.program.trim()
              : null;
          _batchYear = tracer?.batchYear.trim().isNotEmpty == true
              ? tracer!.batchYear.trim()
              : (tracer?.yearGraduated.trim().isNotEmpty == true
                    ? tracer!.yearGraduated.trim()
                    : null);
          _tracerCompletion = tracer?.completionPercent ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCommunitySection() async {
    if (!mounted) return;
    setState(() {
      isLoadingCommunity = true;
      _communityError = null;
    });
    try {
      final page = await _forumService.fetchTopics(
        const ForumTopicQuery(pageSize: 12),
      );
      final topics = page.topics
          .where((t) => !t.isAnnouncement)
          .take(3)
          .toList();
      final todayCount = await _countForumPostsToday();
      if (mounted) {
        setState(() {
          _communityTopics = topics;
          communityTodayCount = todayCount;
          isLoadingCommunity = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _communityTopics = [];
          isLoadingCommunity = false;
          _communityError = 'Community failed to load';
        });
      }
    }
  }

  Future<int> _countForumPostsToday() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final rows = await _supabase
          .from('forum_topics')
          .select('id')
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String())
          .eq('is_announcement', false);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadSurveyAttention() async {
    try {
      final userId = AppSession.userId;
      if (userId == null) return;
      final assignments = await _surveyService.getUserAssignments(userId);
      var customPending = 0;
      var openTracerPending = false;
      DateTime? nearestClose;
      String? tracerSubtitle;
      String? surveySubtitle;
      var dueSoon = false;

      for (final a in assignments) {
        if (a.status == SurveyAssignmentStatus.completed) continue;
        final survey = await _surveyService.getSurvey(a.surveyId);
        // Respect schedule: only surface surveys that are currently open.
        if (survey == null || !survey.acceptsResponses) continue;

        final closeAt = survey.closeAt;
        if (closeAt != null) {
          nearestClose = nearestClose == null || closeAt.isBefore(nearestClose)
              ? closeAt
              : nearestClose;
          final daysLeft = closeAt.difference(DateTime.now()).inDays;
          final hoursLeft = closeAt.difference(DateTime.now()).inHours;
          final isDueSoon =
              !closeAt.isBefore(DateTime.now()) &&
              (daysLeft <= 3 || hoursLeft <= 72);
          if (isDueSoon) dueSoon = true;

          final dueText = _formatDueLabel(closeAt);
          if (survey.isChedGtsBuiltin) {
            tracerSubtitle = dueText;
          } else {
            surveySubtitle = dueText;
          }
        }

        if (survey.isChedGtsBuiltin) {
          openTracerPending = true;
          tracerSubtitle ??=
              '${_tracerCompletion.toStringAsFixed(0)}% complete — finish your CHED Tracer';
        } else {
          customPending++;
          surveySubtitle ??= 'Respond when you can — separate from Tracer';
        }
      }

      String? dueSoonLabel;
      if (dueSoon && nearestClose != null) {
        dueSoonLabel = _formatDueLabel(nearestClose);
      }

      if (mounted) {
        setState(() {
          _pendingCustomSurveys = customPending;
          _openTracerAttention = openTracerPending;
          _attentionDueSoon = dueSoon;
          _attentionDueSoonLabel = dueSoonLabel;
          _tracerAttentionSubtitle = tracerSubtitle;
          _surveyAttentionSubtitle = surveySubtitle;
        });
      }
      // Outside setState so the dialog has a settled tree / navigator.
      if (mounted) unawaited(_maybeShowAttentionReminder());
    } catch (_) {}
  }

  String _formatDueLabel(DateTime closeAt) {
    final now = DateTime.now();
    final days = DateTime(
      closeAt.year,
      closeAt.month,
      closeAt.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days <= 0) {
      return 'Due today · ${intl.DateFormat.jm().format(closeAt)}';
    }
    if (days == 1) {
      return 'Due tomorrow · ${intl.DateFormat.jm().format(closeAt)}';
    }
    if (days <= 3) {
      return 'Due in $days days · ${intl.DateFormat.MMMd().format(closeAt)}';
    }
    return 'Due ${intl.DateFormat.MMMd().add_jm().format(closeAt)}';
  }

  /// Stays pending (not marked shown) while another screen covers the
  /// dashboard; [didPopNext] or returning to the Home tab retries.
  Future<void> _maybeShowAttentionReminder() async {
    final hasActions = _openTracerAttention || _pendingCustomSurveys > 0;
    final should = await SurveyAttentionReminder.shouldShow(
      hasActions: hasActions,
    );
    if (!should || !_dashboardVisible) return;

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!_dashboardVisible) return;

    final stillHasActions = _openTracerAttention || _pendingCustomSurveys > 0;
    final stillShould = await SurveyAttentionReminder.shouldShow(
      hasActions: stillHasActions,
    );
    if (!stillShould || !mounted || !_dashboardVisible) return;

    final hasTracer = _openTracerAttention;
    final hasSurveys = _pendingCustomSurveys > 0;
    final dueSoon = _attentionDueSoon;

    // Mark only once we are about to present a real dialog.
    SurveyAttentionReminder.markShownThisSession();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              elevation: 12,
              shadowColor: PortalTheme.navy.withValues(alpha: 0.25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: dueSoon
                            ? const [Color(0xFFFFF0E8), Color(0xFFFFD8B0)]
                            : const [Color(0xFFFFF7E0), Color(0xFFFCE08A)],
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: PortalTheme.navy.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            dueSoon
                                ? Icons.schedule_rounded
                                : Icons.notifications_active_rounded,
                            color: PortalTheme.navy,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          dueSoon
                              ? 'Something is due soon'
                              : 'A quick reminder',
                          textAlign: TextAlign.center,
                          style: PortalTheme.sectionTitle.copyWith(
                            fontSize: 18,
                            color: PortalTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dueSoon
                              ? 'Please respond when you can — it only takes a moment.'
                              : 'You have an open item waiting on your alumni portal.',
                          textAlign: TextAlign.center,
                          style: PortalTheme.meta.copyWith(
                            color: PortalTheme.navy.withValues(alpha: 0.72),
                            height: 1.35,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_attentionDueSoonLabel != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: dueSoon
                                  ? const Color(0xFFFFF0E8)
                                  : PortalTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: dueSoon
                                    ? const Color(0xFFFFD0A8)
                                    : PortalTheme.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.event_outlined,
                                  size: 16,
                                  color: dueSoon
                                      ? const Color(0xFFC2410C)
                                      : PortalTheme.navyMid,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _attentionDueSoonLabel!,
                                    style: PortalTheme.caption.copyWith(
                                      color: dueSoon
                                          ? const Color(0xFFC2410C)
                                          : PortalTheme.navy,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (hasTracer)
                          _ReminderActionTile(
                            icon: Icons.assignment_outlined,
                            title: 'Graduate Tracer',
                            subtitle:
                                _tracerAttentionSubtitle ??
                                'Complete your CHED Tracer Survey',
                            onTap: () {
                              Navigator.pop(ctx);
                              unawaited(SurveyAttentionReminder.markActed());
                              _navigateToScreen(PortalTabs.tracer);
                            },
                          ),
                        if (hasTracer && hasSurveys) const SizedBox(height: 8),
                        if (hasSurveys)
                          _ReminderActionTile(
                            icon: Icons.poll_outlined,
                            title: _pendingCustomSurveys == 1
                                ? 'Assigned survey'
                                : '$_pendingCustomSurveys assigned surveys',
                            subtitle:
                                _surveyAttentionSubtitle ??
                                'Respond when you can',
                            onTap: () {
                              Navigator.pop(ctx);
                              unawaited(SurveyAttentionReminder.markActed());
                              _openSurveysFromHome();
                            },
                          ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () async {
                            await SurveyAttentionReminder.snoozeForToday();
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: PortalTheme.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Remind me later'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSurveysFromHome() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSurveysScreen()),
    );
    if (mounted) unawaited(_loadSurveyAttention());
  }

  Future<void> _loadCalendarJobs() async {
    try {
      final jobs = await _jobService.getActiveJobs();
      if (!mounted) return;
      setState(() => _activeJobs = jobs);
    } catch (_) {}
  }

  Future<void> _buildCalendarItems() async {
    final items = <HomeCalendarItem>[];

    for (final event in _allUpcomingEvents) {
      items.add(
        HomeCalendarItem(
          kind: HomeCalendarItemKind.event,
          id: event.id,
          title: event.theme,
          subtitle: homeFormatEventTimeRange(event.startTime, event.endTime),
          date: event.date,
        ),
      );
    }

    for (final job in _activeJobs) {
      if (!job.isActiveForAlumni) continue;
      items.add(
        HomeCalendarItem(
          kind: HomeCalendarItemKind.job,
          id: job.id,
          title: job.jobTitle,
          subtitle: 'Application deadline',
          date: job.applicationDeadline,
        ),
      );
    }

    await _appendSurveyCalendarItems(items);
  }

  Future<void> _appendSurveyCalendarItems(List<HomeCalendarItem> items) async {
    try {
      final userId = AppSession.userId;
      if (userId == null) return;
      final assignments = await _surveyService.getUserAssignments(userId);
      for (final a in assignments) {
        if (a.status == SurveyAssignmentStatus.completed) continue;
        final survey = await _surveyService.getSurvey(a.surveyId);
        if (survey == null || survey.closeAt == null) continue;
        if (!survey.isOpen && survey.closeAt!.isBefore(DateTime.now())) {
          continue;
        }
        final isTracer = survey.isChedGtsBuiltin;
        items.add(
          HomeCalendarItem(
            kind: isTracer
                ? HomeCalendarItemKind.tracer
                : HomeCalendarItemKind.survey,
            id: isTracer ? a.surveyId : a.surveyId,
            title: survey.title.isNotEmpty ? survey.title : a.surveyTitle,
            subtitle:
                'Deadline ${intl.DateFormat.MMMd().format(survey.closeAt!)}',
            date: survey.closeAt!,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _calendarItems = items;
          isLoadingCalendar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _calendarItems = items;
          isLoadingCalendar = false;
        });
      }
    }
  }

  Future<void> _loadAnnouncements() async {
    try {
      final userId = AppSession.userId;
      if (userId == null) return;
      final list = await _announcementService.getPublishedForUser(userId);
      if (mounted) {
        setState(() {
          announcementsCount = list.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUpcomingEvents() async {
    if (!mounted) return;
    try {
      setState(() {
        isLoadingEvents = true;
        _eventsError = null;
      });
      final events = await _eventService.getUpcomingEvents();
      events.sort((a, b) => a.date.compareTo(b.date));

      if (!mounted) return;
      setState(() {
        eventsCount = events.length;
        _allUpcomingEvents = events;
        upcomingEvents = events.take(3).toList();
        isLoadingEvents = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingEvents = false;
        _eventsError = 'Events failed to load';
      });
    }
  }

  void _startMessagesCountListener() {
    _messagesCountSubscription = _messageService
        .getUnreadMessagesCountStream()
        .listen((count) {
          if (mounted) {
            setState(() => messagesCount = count);
          }
        }, onError: (_) => _loadCounts());
  }

  /// Called when Home tab is shown again (see [MainNavigation]).
  void refreshMessagesCount() {
    _loadCounts();
  }

  /// Reloads avatar / display name (e.g. after a profile picture upload).
  void refreshUserProfile() {
    _loadUserProfile();
  }

  void _startNotificationsListener() {
    // Listen to real-time updates for unread notifications count
    _notificationsCountSubscription = _notificationService
        .getUnreadCountStream()
        .listen((count) {
          if (mounted) {
            setState(() {
              unreadNotificationsCount = count;
            });
          }
        }, onError: (_) {});
  }

  /// Creates the `users` row when an older account is missing one.
  Future<void> _ensureUserRow() async {
    try {
      final userId = AppSession.userId;
      if (userId == null) return;
      final userRow = await _supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (userRow == null) {
        await AuthService().setUserRole(userId, UserRole.user);
      }
    } catch (_) {}
  }

  Future<void> _loadCounts() async {
    try {
      // Only fetch dynamic unread count; events/jobs are updated by section loaders.
      final messagesCountValue = await _messageService.getUnreadMessagesCount();

      if (!mounted) return;
      setState(() {
        messagesCount = messagesCountValue;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    AppNavigator.routeObserver.unsubscribe(this);
    _messagesCountSubscription?.cancel();
    _notificationsCountSubscription?.cancel();
    _avatarSubscription?.cancel();
    _forumRefreshSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (_displayName ?? 'Alumni').trim();
    final firstName = displayName.split(RegExp(r'\s+')).first;
    final width = PortalBreakpoints.widthOf(context);
    final desktop = PortalBreakpoints.isExpanded(width);

    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Alumni Engagement and Support System',
        titleContent: const AessLogo(height: 30),
        automaticallyImplyLeading: false,
        actions: [
          PortalHeaderAction(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            badgeCount: unreadNotificationsCount,
            onPressed: () => showNotificationPanel(context),
          ),
        ],
      ),
      body: PortalContentFrame(
        child: RefreshIndicator(
          color: PortalTheme.navy,
          onRefresh: _loadDashboardContent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: desktop
                ? _buildDesktopBody(firstName)
                : _buildMobileBody(firstName),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._identityAndAttention(firstName),
        ..._statsBlock(),
        ..._eventsBlock(),
        ..._communityBlock(),
        ..._calendarBlock(),
        const SizedBox(height: 108),
      ],
    );
  }

  Widget _buildDesktopBody(String firstName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._identityAndAttention(firstName),
          ..._statsBlock(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [..._eventsBlock(), ..._communityBlock()],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [..._calendarBlock()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _identityAndAttention(String firstName) {
    return [
      HomeAlumniIdentityHero(
        firstName: firstName,
        fullName: _displayName,
        program: _program,
        batchYear: _batchYear,
        profileImageUrl: _profileImageUrl,
        onTap: () => _navigateToScreen(PortalTabs.profile),
      ),
      HomeNeedsAttentionPanel(
        tracerComplete: !_openTracerAttention,
        tracerPercent: _tracerCompletion,
        pendingSurveys: _pendingCustomSurveys,
        dueSoon: _attentionDueSoon,
        dueSoonLabel: _attentionDueSoonLabel,
        tracerSubtitle: _tracerAttentionSubtitle,
        surveySubtitle: _surveyAttentionSubtitle,
        onOpenTracer: () => _navigateToScreen(PortalTabs.tracer),
        onOpenSurveys: _openSurveysFromHome,
      ),
    ];
  }

  List<Widget> _statsBlock() {
    return [
      HomeStatCardsRow(
        announcementsCount: announcementsCount,
        communityTodayCount: communityTodayCount,
        eventsCount: eventsCount,
        loading: false,
        onAnnouncements: _openAnnouncements,
        onCommunity: () => _navigateToScreen(PortalTabs.community),
        onEvents: () => _navigateToScreen(PortalTabs.events),
      ),
    ];
  }

  List<Widget> _eventsBlock() {
    return [
      if (isLoadingEvents)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: HomeEventCarouselSkeleton(),
        )
      else if (_eventsError != null)
        _SectionRetry(message: _eventsError!, onRetry: _loadUpcomingEvents)
      else if (upcomingEvents.isEmpty)
        HomeEventsEmpty(onBrowse: () => _navigateToScreen(PortalTabs.events))
      else
        HomeUpcomingEventsList(
          events: upcomingEvents,
          onTap: _openEvent,
          onSeeAll: () => _navigateToScreen(PortalTabs.events),
        ),
    ];
  }

  List<Widget> _communityBlock() {
    return [
      if (isLoadingCommunity)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: HomeEventCardsSkeleton(count: 2),
        )
      else if (_communityError != null)
        _SectionRetry(message: _communityError!, onRetry: _loadCommunitySection)
      else if (_communityTopics.isEmpty)
        HomeCommunityEmpty(
          onBrowse: () => _navigateToScreen(PortalTabs.community),
        )
      else
        HomeCommunityCarousel(
          topics: _communityTopics,
          onSeeAll: () => _navigateToScreen(PortalTabs.community),
          onTapTopic: (topic) async {
            await _openForumTopic(topic.id);
            if (mounted) unawaited(_loadCommunitySection());
          },
        ),
    ];
  }

  List<Widget> _calendarBlock() {
    return [
      if (isLoadingCalendar && _calendarItems.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
              border: Border.all(color: PortalTheme.border),
            ),
          ),
        )
      else
        HomeImportantDatesCalendar(
          items: _calendarItems,
          onItemTap: _openCalendarItem,
        ),
    ];
  }

  void _openAnnouncements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserAnnouncementsScreen()),
    );
  }

  MainNavigationState? get _shell =>
      context.findAncestorStateOfType<MainNavigationState>();

  void _openCalendarItem(HomeCalendarItem item) {
    switch (item.kind) {
      case HomeCalendarItemKind.event:
        unawaited(_openEventById(item.id));
      case HomeCalendarItemKind.survey:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserSurveyTakeScreen(surveyId: item.id),
          ),
        );
      case HomeCalendarItemKind.tracer:
        _navigateToScreen(PortalTabs.tracer);
      case HomeCalendarItemKind.job:
        unawaited(_openJobById(item.id));
    }
  }

  void _openEvent(AlumniEvent event) {
    unawaited(_openEventById(event.id));
  }

  Future<void> _openEventById(
    String eventId, {
    bool openComments = false,
  }) async {
    final shell = _shell;
    if (shell != null) {
      await shell.openEvent(eventId, openComments: openComments);
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventsScreen(
          initialEventId: eventId,
          openCommentsOnLaunch: openComments,
        ),
      ),
    );
  }

  Future<void> _openJobById(String jobId) async {
    final shell = _shell;
    if (shell != null) {
      await shell.openJob(jobId);
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobPostingScreen(initialJobId: jobId)),
    );
  }

  Future<void> _openForumTopic(String topicId) async {
    final shell = _shell;
    if (shell != null) {
      await shell.openForumTopic(topicId);
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForumTopicScreen(topicId: topicId)),
    );
  }

  void _navigateToScreen(int index) {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(index);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainNavigation(initialIndex: index),
      ),
    );
  }
}

class _SectionRetry extends StatelessWidget {
  const _SectionRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
          border: Border.all(color: PortalTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: PortalTheme.bodySecondary.copyWith(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: PortalTheme.ghostButton(dense: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderActionTile extends StatelessWidget {
  const _ReminderActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PortalTheme.pageBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PortalTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PortalTheme.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: PortalTheme.navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PortalTheme.cardTitle.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PortalTheme.meta.copyWith(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: PortalTheme.navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Open',
                  style: PortalTheme.button.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
