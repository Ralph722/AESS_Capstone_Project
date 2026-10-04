import 'package:flutter/material.dart';
import 'dart:async';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/messages/presentation/admin_messages_page.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/messages/data/message_open_bus.dart';
import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/feedback/data/feedback_service.dart';
import 'package:alumni_system/features/admin/activity/presentation/admin_activity_logs_page.dart';
import 'package:alumni_system/features/admin/archives/presentation/admin_archives_page.dart';
import 'package:alumni_system/features/admin/dashboard/presentation/admin_dashboard_home.dart';
import 'package:alumni_system/features/admin/dashboard/application/admin_dashboard_metrics.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_activity_trend.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_events_page.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_dashboard_shell.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/user/portal_overlay_theme.dart';

import 'package:alumni_system/features/admin/jobs/presentation/admin_job_management_page.dart';
import 'package:alumni_system/features/admin/roster/presentation/admin_alumni_members_page.dart';
import 'package:alumni_system/features/admin/reports/presentation/admin_reports_page.dart';
import 'package:alumni_system/features/admin/surveys/presentation/admin_surveys_page.dart';
import 'package:alumni_system/features/admin/announcements/presentation/admin_announcements_page.dart';
import 'package:alumni_system/features/admin/forum/presentation/admin_forum_page.dart';
import 'package:alumni_system/features/admin/feedback/presentation/admin_feedback_page.dart';
import 'package:alumni_system/features/admin/dss/presentation/admin_dss_page.dart';
import 'package:alumni_system/features/ai/presentation/ai_assistant_page.dart';
import 'package:alumni_system/features/surveys/application/survey_catalog_refresh.dart';

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});

  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb> {
  final AuthService _authService = AuthService();
  final EventService _eventService = EventService();
  final AuditService _auditService = AuditService();
  final JobService _jobService = JobService();
  final MessageService _messageService = MessageService();
  final AlumniMemberService _memberService = AlumniMemberService();
  final SurveyService _surveyService = SurveyService();
  final AnnouncementService _announcementService = AnnouncementService();
  final IdTracerService _idTracerService = IdTracerService();
  final FeedbackService _feedbackService = FeedbackService();
  final ForumService _forumService = ForumService();

  int _selectedMenuItem = 0;

  /// User override for sidebar collapse; null means follow viewport auto rule.
  bool? _sidebarCollapsedOverride;
  List<AlumniEvent> activeEvents = [];
  bool feedsLoading = false;
  AdminDashboardMetrics metrics = const AdminDashboardMetrics();
  List<AuditLog> recentActivity = [];
  DashboardActivityTrend activityTrend = const DashboardActivityTrend();

  StreamSubscription<int>? _adminUnreadSubscription;
  StreamSubscription<int>? _openFeedbackSubscription;
  StreamSubscription<String>? _messageOpenSubscription;
  VoidCallback? _surveyCatalogListener;
  final Map<int, Widget> _pageCache = {};
  final Set<int> _visitedMenuItems = {0};
  static const List<int> _pageOrder = <int>[
    0,
    1,
    2,
    4,
    5,
    6,
    7,
    9,
    15,
    10,
    11,
    12,
    13,
    14,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => PortalOverlayTheme.suspended.value = true,
    );
    _loadCriticalMetrics();
    _loadFeedPanels();
    _startDashboardLiveListeners();
    _surveyCatalogListener = () {
      if (!mounted) return;
      _pageCache.remove(9);
      if (_selectedMenuItem == 9) {
        setState(() {
          _pageCache[9] = _buildPageForMenu(9);
        });
      }
      unawaited(_refreshSurveyResponseAttentionCount());
    };
    SurveyCatalogRefresh.instance.revision.addListener(_surveyCatalogListener!);
    // Any MessageOpenBus deep-link (Jobs Interested, notifications, etc.)
    // must switch the shell to Messages so the conversation is visible.
    _messageOpenSubscription = MessageOpenBus.stream.listen((_) {
      if (!mounted) return;
      if (_selectedMenuItem != 6) {
        _onMenuSelected(6);
      }
    });
  }

  /// Fast aggregate counts — dashboard paints immediately with zeros, then updates.
  Future<void> _loadCriticalMetrics() async {
    try {
      final results = await Future.wait([
        _eventService.getTotalEventsCount(),
        _eventService.getArchivedEventsCount(),
        _jobService.getTotalJobsCount(),
        _jobService.getActiveJobsCount(),
        _messageService.getAdminUnreadUserMessagesCount(),
        _memberService.getDashboardRosterCounts(),
        _surveyService.getAdminDashboardSurveyStats(),
        _announcementService.countPublishedAnnouncements(),
        _forumService.getTopicCount(),
        _idTracerService.getActiveRegisteredRecordsCount(),
        _feedbackService.countOpenFeedback(),
      ]);

      final totalEvents = results[0] as int;
      final archivedCount = results[1] as int;
      final totalJobs = results[2] as int;
      final activeJobs = results[3] as int;
      final unreadCount = results[4] as int;
      final rosterCounts =
          results[5]
              as ({int active, int registeredActive, int tracerCompleteActive});
      final surveyStats =
          results[6]
              as ({
                int publishedCount,
                int totalAssignments,
                int totalResponses,
                int unreadResponses,
              });
      final publishedAnnouncements = results[7] as int;
      final forumCount = results[8] as int;
      final employmentCount = results[9] as int;
      final openFeedback = results[10] as int;

      if (!mounted) return;
      setState(() {
        metrics = AdminDashboardMetrics(
          rosterTotal: rosterCounts.active,
          registeredOnRoster: rosterCounts.registeredActive,
          tracerCompleteCount: rosterCounts.tracerCompleteActive,
          employmentSubmissions: employmentCount,
          pendingSurveyAssignments: surveyStats.unreadResponses,
          totalSurveyAssignments: surveyStats.totalAssignments,
          totalSurveyResponses: surveyStats.totalResponses,
          publishedSurveys: surveyStats.publishedCount,
          totalEvents: totalEvents,
          activeEventsCount: metrics.activeEventsCount,
          archivedEventsCount: archivedCount,
          upcomingEventsCount: metrics.upcomingEventsCount,
          portalAccounts: rosterCounts.registeredActive,
          totalJobs: totalJobs,
          activeJobs: activeJobs,
          unreadMessages: unreadCount,
          publishedAnnouncements: publishedAnnouncements,
          forumTopics: forumCount,
          openFeedback: openFeedback,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading dashboard metrics: $e')),
      );
    }
  }

  /// Heavier lists load after first paint (events list, activity feed).
  Future<void> _loadFeedPanels({bool showLoadingIndicator = true}) async {
    if (!mounted) return;
    final hasExistingFeeds =
        activeEvents.isNotEmpty || recentActivity.isNotEmpty;
    if (showLoadingIndicator && !hasExistingFeeds) {
      setState(() => feedsLoading = true);
    }
    try {
      final results = await Future.wait([
        _eventService.getActiveEvents(runAutoArchive: false),
        _auditService.getAllAuditLogs(limit: 8),
        _auditService.getAllAuditLogs(limit: 500),
      ]);
      final events = results[0] as List<AlumniEvent>;
      final recentLogs = results[1] as List<AuditLog>;
      final trendLogs = results[2] as List<AuditLog>;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final upcoming = events.where((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return !d.isBefore(todayStart);
      }).length;

      if (!mounted) return;
      setState(() {
        activeEvents = events;
        recentActivity = recentLogs;
        activityTrend = DashboardActivityTrend.fromAuditLogs(trendLogs);
        feedsLoading = false;
        metrics = AdminDashboardMetrics(
          rosterTotal: metrics.rosterTotal,
          registeredOnRoster: metrics.registeredOnRoster,
          tracerCompleteCount: metrics.tracerCompleteCount,
          employmentSubmissions: metrics.employmentSubmissions,
          pendingSurveyAssignments: metrics.pendingSurveyAssignments,
          totalSurveyAssignments: metrics.totalSurveyAssignments,
          totalSurveyResponses: metrics.totalSurveyResponses,
          publishedSurveys: metrics.publishedSurveys,
          totalEvents: metrics.totalEvents,
          activeEventsCount: events.length,
          archivedEventsCount: metrics.archivedEventsCount,
          upcomingEventsCount: upcoming,
          portalAccounts: metrics.portalAccounts,
          totalJobs: metrics.totalJobs,
          activeJobs: metrics.activeJobs,
          unreadMessages: metrics.unreadMessages,
          publishedAnnouncements: metrics.publishedAnnouncements,
          forumTopics: metrics.forumTopics,
          openFeedback: metrics.openFeedback,
        );
      });
    } catch (_) {
      if (mounted) setState(() => feedsLoading = false);
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadCriticalMetrics(),
      _loadFeedPanels(showLoadingIndicator: true),
    ]);
  }

  /// Reload KPIs, attention counts, events, and activity when returning to home.
  Future<void> _refreshDashboardOnReturn() async {
    await Future.wait([
      _loadCriticalMetrics(),
      _loadFeedPanels(showLoadingIndicator: false),
    ]);
  }

  AdminDashboardMetrics _metricsWith({
    int? rosterTotal,
    int? registeredOnRoster,
    int? tracerCompleteCount,
    int? employmentSubmissions,
    int? pendingSurveyAssignments,
    int? totalSurveyAssignments,
    int? totalSurveyResponses,
    int? publishedSurveys,
    int? totalEvents,
    int? activeEventsCount,
    int? archivedEventsCount,
    int? upcomingEventsCount,
    int? portalAccounts,
    int? totalJobs,
    int? activeJobs,
    int? unreadMessages,
    int? publishedAnnouncements,
    int? forumTopics,
    int? openFeedback,
  }) {
    return AdminDashboardMetrics(
      rosterTotal: rosterTotal ?? metrics.rosterTotal,
      registeredOnRoster: registeredOnRoster ?? metrics.registeredOnRoster,
      tracerCompleteCount: tracerCompleteCount ?? metrics.tracerCompleteCount,
      employmentSubmissions:
          employmentSubmissions ?? metrics.employmentSubmissions,
      pendingSurveyAssignments:
          pendingSurveyAssignments ?? metrics.pendingSurveyAssignments,
      totalSurveyAssignments:
          totalSurveyAssignments ?? metrics.totalSurveyAssignments,
      totalSurveyResponses:
          totalSurveyResponses ?? metrics.totalSurveyResponses,
      publishedSurveys: publishedSurveys ?? metrics.publishedSurveys,
      totalEvents: totalEvents ?? metrics.totalEvents,
      activeEventsCount: activeEventsCount ?? metrics.activeEventsCount,
      archivedEventsCount: archivedEventsCount ?? metrics.archivedEventsCount,
      upcomingEventsCount: upcomingEventsCount ?? metrics.upcomingEventsCount,
      portalAccounts: portalAccounts ?? metrics.portalAccounts,
      totalJobs: totalJobs ?? metrics.totalJobs,
      activeJobs: activeJobs ?? metrics.activeJobs,
      unreadMessages: unreadMessages ?? metrics.unreadMessages,
      publishedAnnouncements:
          publishedAnnouncements ?? metrics.publishedAnnouncements,
      forumTopics: forumTopics ?? metrics.forumTopics,
      openFeedback: openFeedback ?? metrics.openFeedback,
    );
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    }
  }

  void _onMenuSelected(int index) {
    setState(() {
      final previous = _selectedMenuItem;
      _selectedMenuItem = index;
      _visitedMenuItems.add(index);
      // Evict Alumni Directory when leaving so base64 roster state is released.
      if (previous == 2 && index != 2) {
        _pageCache.remove(2);
        _visitedMenuItems.remove(2);
      }
      // Dashboard (0) and Archives (4) rebuild for fresh metrics / flex layout.
      // Forum (12) always rebuilds so deletes made in the DB dashboard aren't
      // stuck behind a stale StreamBuilder in the page cache.
      if (index == 9 || index == 12) {
        _pageCache.remove(index);
        _pageCache[index] = _buildPageForMenu(index);
      } else if (index != 0 && index != 4) {
        _pageCache[index] ??= _buildPageForMenu(index);
      }
    });
    if (index == 0) {
      _refreshDashboardOnReturn();
    } else if (index == 10) {
      _refreshSurveyResponseAttentionCount();
    }
  }

  Future<void> _refreshSurveyResponseAttentionCount() async {
    try {
      final stats = await _surveyService.getAdminDashboardSurveyStats();
      if (!mounted) return;
      setState(() {
        metrics = _metricsWith(
          pendingSurveyAssignments: stats.unreadResponses,
          totalSurveyAssignments: stats.totalAssignments,
          totalSurveyResponses: stats.totalResponses,
          publishedSurveys: stats.publishedCount,
        );
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Desktop admin: always keep a persistent sidebar. Auto-collapse to a
    // mini-rail under 1100px (Console pattern) unless the user overrides.
    final autoCollapsed = screenWidth < 1100;
    final sidebarCollapsed = _sidebarCollapsedOverride ?? autoCollapsed;

    final sidebar = AdminDashboardSidebar(
      selectedMenuItem: _selectedMenuItem,
      onMenuSelected: _onMenuSelected,
      currentUser: currentUser,
      onLogout: _logout,
      collapsed: sidebarCollapsed,
      onToggleCollapse: () {
        setState(() {
          _sidebarCollapsedOverride = !sidebarCollapsed;
        });
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Row(
        children: [
          sidebar,
          Expanded(
            child: Column(
              children: [
                AdminDashboardTopHeader(
                  currentUser: currentUser,
                  onMenuSelected: _onMenuSelected,
                  metrics: metrics,
                  selectedMenuItem: _selectedMenuItem,
                  onLogout: _logout,
                ),
                Expanded(
                  child: Container(
                    padding: AdminDensity.shellPaddingForWidth(screenWidth),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final selectedIndex = _pageOrder.indexOf(_selectedMenuItem);
    final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;
    return IndexedStack(
      index: safeIndex,
      sizing: StackFit.expand,
      children: _pageOrder
          .map((menuItem) {
            if (!_visitedMenuItems.contains(menuItem)) {
              return const SizedBox.shrink();
            }
            if (menuItem == 0 || menuItem == 4) {
              return _buildPageForMenu(menuItem);
            }
            return _pageCache[menuItem] ?? const SizedBox.shrink();
          })
          .toList(growable: false),
    );
  }

  Widget _buildPageForMenu(int menuItem) {
    switch (menuItem) {
      case 0:
        return AdminDashboardHome(
          isLoading: feedsLoading,
          metrics: metrics,
          activeEvents: activeEvents,
          recentActivity: recentActivity,
          activityTrend: activityTrend,
          onMenuSelected: _onMenuSelected,
          onRefresh: _loadAllData,
        );
      case 1:
        return const AdminEventsScreen();
      case 2:
        return const AdminAlumniMembersScreen();
      case 4:
        return const AdminArchivesScreen();
      case 5:
        return AdminJobManagement(onOpenAdminMenu: _onMenuSelected);
      case 6:
        return const AdminMessagesScreen(hideAppBar: true);
      case 7:
        return const AdminActivityLogsScreen();
      case 9:
        return AdminReportsScreen(
          key: ValueKey(SurveyCatalogRefresh.instance.revision.value),
          onOpenAdminMenu: _onMenuSelected,
        );
      case 10:
        return const AdminSurveysScreen();
      case 11:
        return const AdminAnnouncementsScreen();
      case 12:
        return const AdminForumScreen();
      case 13:
        return const AiAssistantScreen(isAdmin: true);
      case 14:
        return const AdminFeedbackScreen();
      case 15:
        return AdminDssScreen(onOpenAdminMenu: _onMenuSelected);
      default:
        return const SizedBox.shrink();
    }
  }

  void _startDashboardLiveListeners() {
    _adminUnreadSubscription?.cancel();
    _adminUnreadSubscription = _messageService
        .watchAdminUnreadUserMessagesCount()
        .listen((unread) {
          if (!mounted) return;
          setState(() => metrics = _metricsWith(unreadMessages: unread));
        });

    _openFeedbackSubscription?.cancel();
    _openFeedbackSubscription = _feedbackService
        .watchOpenFeedbackCount()
        .listen((open) {
          if (!mounted) return;
          setState(() => metrics = _metricsWith(openFeedback: open));
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => PortalOverlayTheme.suspended.value = false,
    );
    _adminUnreadSubscription?.cancel();
    _openFeedbackSubscription?.cancel();
    _messageOpenSubscription?.cancel();
    if (_surveyCatalogListener != null) {
      SurveyCatalogRefresh.instance.revision.removeListener(
        _surveyCatalogListener!,
      );
    }
    super.dispose();
  }
}
