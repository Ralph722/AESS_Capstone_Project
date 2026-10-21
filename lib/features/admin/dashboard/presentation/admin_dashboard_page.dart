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
import 'package:alumni_system/features/admin/dashboard/application/dashboard_insights.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/profile/data/admin_profile_service.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_events_page.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_dashboard_shell.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, RealtimeChannel, Supabase;

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});

  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  late final AdminProfileController _profile = AdminProfileController(
    initial: AdminProfile.fromUser(_authService.getCurrentUser()),
  );
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
  final DssRepository _dssRepository = DssRepository();

  int _selectedMenuItem = 0;

  /// User override for sidebar collapse; null means follow viewport auto rule.
  bool? _sidebarCollapsedOverride;
  List<AlumniEvent> activeEvents = [];
  bool feedsLoading = false;
  bool feedsFailed = false;
  bool metricsLoaded = false;
  bool metricsFailed = false;
  DashboardInsights? insights;
  bool insightsFailed = false;
  AdminDashboardMetrics metrics = const AdminDashboardMetrics();
  List<AuditLog> recentActivity = [];
  DashboardActivityTrend activityTrend = const DashboardActivityTrend();
  DateTime? lastUpdated;

  // Live sync while the Dashboard is on screen: realtime change signals
  // debounce into silent reloads, and a poll covers the tables that are not
  // in the realtime publication (roster, jobs, responses, audit logs).
  RealtimeChannel? _liveChannel;
  Timer? _liveDebounce;
  Timer? _livePoll;
  bool _liveRefreshInFlight = false;
  bool _liveRefreshQueued = false;
  bool _appVisible = true;
  DateTime? _insightsLoadedAt;

  /// Only tables in the `supabase_realtime` publication; subscribing to any
  /// other table makes the whole channel fail.
  static const _liveTables = [
    'events',
    'announcements',
    'feedback',
    'survey_assignments',
    'forum_topics',
  ];
  static const _livePollInterval = Duration(seconds: 30);

  /// Insights read the whole roster, so the poll refreshes them less often.
  static const _insightsMaxAge = Duration(minutes: 2);

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
    _profile.refresh();
    _loadCriticalMetrics();
    _loadFeedPanels();
    _loadInsights();
    _startDashboardLiveListeners();
    WidgetsBinding.instance.addObserver(this);
    _startLiveSync();
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
  /// A [silent] failure keeps the last figures and shows no snackbar.
  Future<void> _loadCriticalMetrics({bool silent = false}) async {
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
        metricsLoaded = true;
        metricsFailed = false;
        lastUpdated = DateTime.now();
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
      debugPrint('Dashboard metrics load failed: $e');
      if (!mounted) return;
      if (silent && metricsLoaded) return;
      setState(() => metricsFailed = true);
      if (silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't load dashboard figures. Try again."),
        ),
      );
    }
  }

  /// Heavier lists load after first paint (events list, activity feed).
  /// A [silent] failure keeps the lists already on screen.
  Future<void> _loadFeedPanels({
    bool showLoadingIndicator = true,
    bool silent = false,
  }) async {
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
        feedsFailed = false;
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
    } catch (e) {
      debugPrint('Dashboard feed load failed: $e');
      final hasFeeds = activeEvents.isNotEmpty || recentActivity.isNotEmpty;
      if (silent && hasFeeds && !feedsFailed) return;
      if (mounted) {
        setState(() {
          feedsLoading = false;
          feedsFailed = true;
        });
      }
    }
  }

  /// Read-only Directory, tracer, employment, survey, job and Program Insights
  /// figures. Program Insights failing on its own only blanks its own figures.
  /// A [silent] failure keeps the last insights on screen.
  Future<void> _loadInsights({bool silent = false}) async {
    try {
      final results = await Future.wait<Object?>([
        _memberService.getAllMembers(),
        _surveyService.getAllSurveys(),
        _surveyService.countAssignmentsBySurvey(activeRegisteredOnly: true),
        _surveyService.countSubmittedResponsesBySurvey(
          activeRegisteredOnly: true,
        ),
        _idTracerService.getAllEmploymentRecords(),
        _jobService.getJobsByStatus('active'),
        _loadInsightFlags(),
      ]);
      final surveys = results[1] as List<Survey>;
      final submitted = results[3] as Map<String, int>;
      final tracerIds = await _tracerSubmitterIds(surveys, submitted);
      final built = DashboardInsights.build(
        members: results[0] as List<AlumniMember>,
        surveys: surveys,
        assignmentCounts: results[2] as Map<String, int>,
        submittedCounts: submitted,
        tracerSubmitterIds: tracerIds,
        employmentRecords: results[4] as List<EmploymentRecord>,
        activeJobs: results[5] as List<JobPosting>,
        flags: results[6] as List<DssFlag>?,
      );
      if (!mounted) return;
      _insightsLoadedAt = DateTime.now();
      setState(() {
        insights = built;
        insightsFailed = false;
      });
    } catch (e) {
      debugPrint('Dashboard insights load failed: $e');
      if (silent && insights != null) return;
      if (mounted) setState(() => insightsFailed = true);
    }
  }

  Future<List<DssFlag>?> _loadInsightFlags() async {
    try {
      return await _dssRepository.listFlags(limit: 500);
    } catch (e) {
      debugPrint('Dashboard Program Insights load failed: $e');
      return null;
    }
  }

  /// Auth UIDs who submitted a published or closed CHED tracer wave (the
  /// waves Reports & Analytics counts for "Tracer reach").
  Future<Set<String>> _tracerSubmitterIds(
    List<Survey> surveys,
    Map<String, int> submittedCounts,
  ) async {
    final waves = surveys.where(
      (s) =>
          s.isChedGtsBuiltin &&
          !s.archived &&
          (s.status == SurveyStatus.published ||
              s.status == SurveyStatus.closed) &&
          (submittedCounts[s.id] ?? s.responseCount) > 0,
    );
    final responses = await Future.wait(
      waves.map((s) => _surveyService.getSurveyResponses(s.id)),
    );
    return {
      for (final list in responses)
        for (final r in list)
          if (r.userId.trim().isNotEmpty) r.userId.trim(),
    };
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadCriticalMetrics(),
      _loadFeedPanels(showLoadingIndicator: true),
      _loadInsights(),
    ]);
  }

  bool get _dashboardOnScreen => _selectedMenuItem == 0 && _appVisible;

  /// Silent reload of every dashboard figure. Overlapping requests collapse
  /// into one follow-up run.
  Future<void> _liveRefresh({bool includeInsights = true}) async {
    if (_liveRefreshInFlight) {
      _liveRefreshQueued = true;
      return;
    }
    _liveRefreshInFlight = true;
    try {
      await Future.wait([
        _loadCriticalMetrics(silent: true),
        _loadFeedPanels(showLoadingIndicator: false, silent: true),
        if (includeInsights) _loadInsights(silent: true),
      ]);
    } finally {
      _liveRefreshInFlight = false;
      if (_liveRefreshQueued && mounted) {
        _liveRefreshQueued = false;
        unawaited(_liveRefresh());
      }
    }
  }

  void _startLiveSync() {
    try {
      final channel = Supabase.instance.client.channel(
        'admin-dashboard-live-${DateTime.now().microsecondsSinceEpoch}',
      );
      for (final table in _liveTables) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => _scheduleLiveRefresh(),
        );
      }
      channel.subscribe();
      _liveChannel = channel;
    } catch (_) {
      // Realtime unavailable — the poll below still keeps figures current.
    }
    _livePoll?.cancel();
    _livePoll = Timer.periodic(_livePollInterval, (_) {
      if (!mounted || !_dashboardOnScreen) return;
      final loadedAt = _insightsLoadedAt;
      final insightsStale =
          loadedAt == null ||
          DateTime.now().difference(loadedAt) >= _insightsMaxAge;
      unawaited(_liveRefresh(includeInsights: insightsStale));
    });
  }

  /// Coalesces bursts of change events into one reload. Changes made while
  /// another page is open are picked up when the admin returns.
  void _scheduleLiveRefresh() {
    if (!mounted || !_dashboardOnScreen) return;
    _liveDebounce?.cancel();
    _liveDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _dashboardOnScreen) unawaited(_liveRefresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A blurred window (inactive) is still on screen, e.g. on a second monitor.
    final visible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (visible == _appVisible) return;
    _appVisible = visible;
    if (visible && _selectedMenuItem == 0) unawaited(_liveRefresh());
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
      unawaited(_liveRefresh());
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
    // Phone: drawer navigation. Tablet/desktop: persistent sidebar that
    // auto-collapses to a mini-rail under 1100px unless the user overrides.
    final useDrawer = AdminDensity.useDrawerNavigation(screenWidth);
    final autoCollapsed = AdminDensity.autoCollapseSidebar(screenWidth);
    final sidebarCollapsed = _sidebarCollapsedOverride ?? autoCollapsed;

    void selectFromDrawer(int index) {
      Navigator.of(context).maybePop();
      _onMenuSelected(index);
    }

    final sidebar = AdminDashboardSidebar(
      selectedMenuItem: _selectedMenuItem,
      onMenuSelected: useDrawer ? selectFromDrawer : _onMenuSelected,
      currentUser: currentUser,
      collapsed: useDrawer ? false : sidebarCollapsed,
      onToggleCollapse: useDrawer
          ? null
          : () {
              setState(() {
                _sidebarCollapsedOverride = !sidebarCollapsed;
              });
            },
    );

    Widget bodyColumn({VoidCallback? onOpenNavigation}) {
      return Column(
        children: [
          AdminDashboardTopHeader(
            profile: _profile,
            onMenuSelected: _onMenuSelected,
            metrics: metrics,
            selectedMenuItem: _selectedMenuItem,
            onLogout: _logout,
            onOpenNavigation: onOpenNavigation,
          ),
          Expanded(
            child: Container(
              padding: AdminDensity.shellPaddingForWidth(screenWidth),
              child: _buildContent(),
            ),
          ),
        ],
      );
    }

    if (useDrawer) {
      return Scaffold(
        backgroundColor: AdminColors.shellBackground,
        drawer: Drawer(
          width: AdminDashboardSidebar.expandedWidth,
          backgroundColor: Colors.transparent,
          child: sidebar,
        ),
        body: Builder(
          builder: (scaffoldContext) => bodyColumn(
            onOpenNavigation: () => Scaffold.of(scaffoldContext).openDrawer(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AdminColors.shellBackground,
      body: Row(
        children: [
          sidebar,
          Expanded(child: bodyColumn()),
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
        return ValueListenableBuilder<AdminProfile>(
          valueListenable: _profile,
          builder: (context, profile, _) => AdminDashboardHome(
            isLoading: feedsLoading,
            metrics: metrics,
            activeEvents: activeEvents,
            recentActivity: recentActivity,
            activityTrend: activityTrend,
            onMenuSelected: _onMenuSelected,
            onRefresh: _loadAllData,
            metricsLoaded: metricsLoaded,
            metricsFailed: metricsFailed,
            feedsFailed: feedsFailed,
            insights: insights,
            insightsFailed: insightsFailed,
            adminName: profile.name,
            lastUpdated: lastUpdated,
          ),
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
    WidgetsBinding.instance.removeObserver(this);
    _liveDebounce?.cancel();
    _livePoll?.cancel();
    final channel = _liveChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    _adminUnreadSubscription?.cancel();
    _openFeedbackSubscription?.cancel();
    _messageOpenSubscription?.cancel();
    if (_surveyCatalogListener != null) {
      SurveyCatalogRefresh.instance.revision.removeListener(
        _surveyCatalogListener!,
      );
    }
    _profile.dispose();
    super.dispose();
  }
}
