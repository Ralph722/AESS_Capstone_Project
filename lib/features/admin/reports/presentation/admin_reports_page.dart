import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alumni_system/core/utils/export_platform.dart';

import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';

import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/admin/reports/application/ched_wave_comparison.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_coverage.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_header.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_kpi.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_insights.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_polish.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_filter_bar.dart';
import 'package:alumni_system/features/admin/reports/widgets/ched_wave_comparison_dialog.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_downloads_panel.dart';
import 'package:alumni_system/features/admin/reports/widgets/tracer_outcome_extras.dart';
import 'package:alumni_system/features/admin/reports/data/custom_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/features/surveys/data/survey_report_analytics.dart';
import 'package:alumni_system/features/surveys/application/survey_catalog_refresh.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'dart:async';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, this.onOpenAdminMenu});

  /// Opens another admin shell module (e.g. roster = 2, surveys = 10).
  final void Function(int menuIndex)? onOpenAdminMenu;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  /// Kept as alias so chart/metric accent colors stay consistent with portal.
  static const _navy = AdminReportsTheme.primary;

  static const _tabLabels = ['Overview', 'Tracer', 'Survey', 'Downloads'];
  static const _tabIcons = [
    Icons.dashboard_outlined,
    Icons.school_outlined,
    Icons.poll_outlined,
    Icons.download_outlined,
  ];

  final AlumniMemberService _memberService = AlumniMemberService();
  final EventService _eventService = EventService();
  final JobService _jobService = JobService();
  final IdTracerService _idTracerService = IdTracerService();
  final SurveyService _surveyService = SurveyService();
  final AnnouncementService _announcementService = AnnouncementService();
  final ForumService _forumService = ForumService();
  final UserProfileService _profileService = UserProfileService();

  List<AlumniEvent> _allEvents = [];
  List<JobPosting> _jobs = [];
  List<Survey> _surveys = [];
  Map<String, TracerProfile> _registeredProfiles = const {};

  AdminReportsAnalytics? _analytics;

  List<SurveyReportRollup> _surveyRollups = [];
  Future<void>? _surveyRollupsFuture;

  /// CHED wave respondents' presently-employed answers (for rate-by-wave chart).
  List<_TracerWaveEmploymentSample> _waveEmploymentSamples = const [];

  bool _isRefreshing = false;
  DateTime? _lastUpdatedAt;

  List<ReportsInsightCardData> _insightCards = const [];
  bool _insightsGenerating = false;
  bool _insightsAreAi = false;
  final ScrollController _scrollController = ScrollController();

  // Live sync: realtime change signals debounce into silent reloads, with a
  // periodic poll as a fallback for tables without realtime enabled.
  RealtimeChannel? _liveChannel;
  Timer? _liveDebounce;
  Timer? _pollTimer;
  bool _loadInFlight = false;
  bool _reloadQueued = false;

  static const _liveTables = [
    'alumni_members',
    'users',
    'events',
    'jobs',
    'employment_records',
    'surveys',
    'survey_questions',
    'survey_assignments',
    'survey_responses',
    'announcements',
    'forum_topics',
  ];

  // Task-based tabs: Overview · Tracer · Survey · Downloads.
  static const double _tabBarHeight = 52;
  late final TabController _tabController;

  /// Cohort filters for Tracer / Survey tabs only.
  ReportsDashboardFilters _dashboardFilters = ReportsDashboardFilters.empty;

  VoidCallback? _surveyCatalogListener;

  bool _downloadBusy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || !mounted) return;
      final id = _dashboardFilters.surveyId;
      if (id != null && _tabController.index == 1) {
        Survey? survey;
        for (final s in _surveys) {
          if (s.id == id) {
            survey = s;
            break;
          }
        }
        if (survey != null && !survey.isChedGtsBuiltin) {
          _dashboardFilters = _dashboardFilters.copyWith(clearSurvey: true);
        }
      }
      setState(() {});
    });
    _surveyCatalogListener = () {
      if (mounted) _loadAllData();
    };
    SurveyCatalogRefresh.instance.revision.addListener(_surveyCatalogListener!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadAllData();
      _startLiveSync();
    });
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _tabLabels.length) return;
    _tabController.animateTo(index);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: ReportsPolish.animFast,
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Analytics snapshot with global filters applied (presentation only).
  AdminReportsAnalytics _viewAnalytics(AdminReportsAnalytics source) {
    return applyReportsDashboardFilters(
      source: source,
      filters: _dashboardFilters,
    );
  }

  @override
  void dispose() {
    if (_surveyCatalogListener != null) {
      SurveyCatalogRefresh.instance.revision.removeListener(
        _surveyCatalogListener!,
      );
    }
    _liveDebounce?.cancel();
    _pollTimer?.cancel();
    final channel = _liveChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Subscribes to realtime change events on every table this dashboard
  /// reads from. Any insert/update/delete triggers a debounced silent reload,
  /// so the screen stays current without manual refreshing. A slow periodic
  /// poll acts as a safety net for tables without realtime replication.
  void _startLiveSync() {
    try {
      final channel = Supabase.instance.client.channel('admin-reports-live');
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
      // Realtime unavailable â€” the periodic poll below still keeps data fresh.
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) unawaited(_loadAllData(silent: true));
    });
  }

  /// Coalesces bursts of change events into one reload.
  void _scheduleLiveRefresh() {
    _liveDebounce?.cancel();
    _liveDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) unawaited(_loadAllData(silent: true));
    });
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (_loadInFlight) {
      _reloadQueued = true;
      return;
    }
    _loadInFlight = true;
    if (mounted && !silent) setState(() => _isRefreshing = true);
    try {
      final results = await Future.wait([
        _memberService.getAllMembers(),
        _eventService.getAllEvents(),
        _jobService.getJobsByStatus('active'),
        _idTracerService.getAllEmploymentRecords(),
        _surveyService.getAllSurveys(),
        _announcementService.getAllAnnouncements(),
        _forumService.getAllTopics(),
        _profileService.getRegisteredProfileIndex(),
      ]);

      final members = results[0] as List<AlumniMember>;
      final allEvents = results[1] as List<AlumniEvent>;
      final jobs = results[2] as List<JobPosting>;
      final records = results[3] as List<EmploymentRecord>;
      final surveys = results[4] as List<Survey>;
      final announcements = results[5] as List<Announcement>;
      final forumTopics = results[6] as List<ForumTopic>;
      final registeredProfiles = results[7] as Map<String, TracerProfile>;

      final activeMembers = members
          .where((m) => !m.isDeactivated)
          .toList(growable: false);
      final portalUsers = activeMembers.where((m) => m.isRegisteredUser).length;

      final activeAssignmentCounts = await _surveyService
          .countAssignmentsBySurvey(activeRegisteredOnly: true);
      final activeSubmittedCounts = await _surveyService
          .countSubmittedResponsesBySurvey(activeRegisteredOnly: true);
      final submittedCounts = <String, int>{
        for (final s in surveys)
          s.id: activeSubmittedCounts[s.id] ?? s.responseCount,
      };
      final adjustedSurveys = surveys
          .map(
            (s) => s.copyWith(
              assignmentCount: activeAssignmentCounts[s.id] ?? 0,
              responseCount: submittedCounts[s.id] ?? s.responseCount,
            ),
          )
          .toList(growable: false);

      final analytics = AdminReportsAnalytics(
        members: members,
        employmentRecords: records,
        surveys: adjustedSurveys,
        announcements: announcements,
        forumTopics: forumTopics,
        portalUserCount: portalUsers,
        pendingSurveyAssignments: 0,
        assignmentCountsBySurveyId: activeAssignmentCounts,
        submittedResponsesBySurveyId: submittedCounts,
      );

      if (!mounted) return;
      setState(() {
        _allEvents = allEvents;
        _jobs = jobs;
        _surveys = adjustedSurveys;
        _registeredProfiles = registeredProfiles;
        _analytics = analytics;
        _lastUpdatedAt = DateTime.now();
        _isRefreshing = false;
        // Keep AI-generated insights across background refreshes.
        if (!_insightsAreAi) {
          _insightCards = _buildPlaceholderInsights(analytics, adjustedSurveys);
        }
      });

      unawaited(_refreshSurveyReportExtras(surveys));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    } finally {
      _loadInFlight = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        unawaited(_loadAllData(silent: true));
      }
    }
  }

  Future<void> _loadSurveyRollupsFor(List<Survey> surveys) {
    final future = _doLoadSurveyRollups(surveys);
    _surveyRollupsFuture = future;
    return future;
  }

  /// Pack exports need rollups; wait for the in-flight load or trigger one.
  Future<void> _ensureSurveyRollupsLoaded() async {
    final pending = _surveyRollupsFuture;
    if (pending != null) {
      await pending;
      return;
    }
    if (_surveyRollups.isEmpty) {
      await _loadSurveyRollupsFor(_surveys);
    }
  }

  Future<void> _doLoadSurveyRollups(List<Survey> surveys) async {
    if (!mounted) return;
    final ac = _analytics;
    if (ac == null) return;

    try {
      // Cap only non-CHED rollups. All published/closed CHED tracers with
      // submissions are loaded so “All tracers” can aggregate correctly.
      const maxOtherWaves = 4;
      final published =
          surveys
              .where(
                (s) =>
                    !s.archived &&
                    (s.status == SurveyStatus.published ||
                        (s.isChedGtsBuiltin &&
                            s.status == SurveyStatus.closed)) &&
                    s.assignmentCount > 0 &&
                    ac.submittedResponseCount(s) > 0,
              )
              .toList()
            ..sort(
              (x, y) => ac
                  .submittedResponseCount(y)
                  .compareTo(ac.submittedResponseCount(x)),
            );
      final chedWaves = published.where((s) => s.isChedGtsBuiltin).toList();
      final otherWaves = published.where((s) => !s.isChedGtsBuiltin).toList();

      final selectedId = _dashboardFilters.surveyId;
      final take = <Survey>[];
      void addWave(Survey s) {
        if (take.any((t) => t.id == s.id)) return;
        take.add(s);
      }

      if (selectedId != null) {
        for (final s in surveys) {
          if (s.id == selectedId &&
              !s.archived &&
              s.isChedGtsBuiltin &&
              (s.status == SurveyStatus.published ||
                  s.status == SurveyStatus.closed)) {
            addWave(s);
            break;
          }
        }
      }
      for (final s in chedWaves) {
        addWave(s);
      }
      for (final s in otherWaves) {
        if (take.where((t) => !t.isChedGtsBuiltin).length >= maxOtherWaves) {
          break;
        }
        addWave(s);
      }

      final rollups = <SurveyReportRollup>[];
      final employmentSamples = <_TracerWaveEmploymentSample>[];

      // Sequential batches of 2 — avoids stampeding Supabase/browser memory.
      for (var i = 0; i < take.length; i += 2) {
        if (!mounted) return;
        final chunk = take.skip(i).take(2);
        final chunkResults = await Future.wait(
          chunk.map((s) async {
          final responses = await _surveyService.getSurveyResponses(s.id);
          if (responses.isEmpty) return null;
            final submitted = responses
                .where((r) => r.status == SurveyResponseStatus.submitted)
                .toList(growable: false);
            if (submitted.isEmpty) return null;

            _TracerWaveEmploymentSample? employmentSample;
          if (s.isChedGtsBuiltin) {
              // Lightweight: only ched_16 for coverage / rate-by-wave — no full agg here.
              employmentSample = _TracerWaveEmploymentSample(
              survey: s,
                answers: [
                  for (final r in submitted)
                    _ChedEmploymentAnswer(
                      userId: r.userId,
                      presentlyEmployed: _chedPresentlyEmployed(r.answers),
                      submittedAt: r.submittedAt,
                    ),
                ],
              );
            }

            // Full question aggregates only for CHED (downloads/CHED charts) —
            // and only when needed; keep classic surveys lighter.
            SurveyReportRollup? rollup;
            if (s.isChedGtsBuiltin) {
              rollup = SurveyReportRollup(
                survey: s,
                aggregates: SurveyReportAnalytics.aggregateChedResponses(
                  responses: submitted,
                ),
              );
            } else {
          final questions = await _surveyService.getQuestions(s.id);
              if (questions.isNotEmpty) {
                rollup = SurveyReportRollup(
            survey: s,
            aggregates: SurveyReportAnalytics.aggregateResponses(
              questions: questions,
                    responses: submitted,
            ),
          );
              }
            }

            return (rollup: rollup, employment: employmentSample);
        }),
      );

        for (final entry in chunkResults) {
          if (entry == null) continue;
          final rollup = entry.rollup;
          if (rollup != null) rollups.add(rollup);
          final emp = entry.employment;
          if (emp != null) employmentSamples.add(emp);
        }
      }

      employmentSamples.sort(
        (a, b) => a.survey.createdAt.compareTo(b.survey.createdAt),
      );

      if (!mounted) return;
      setState(() {
        _surveyRollups = rollups;
        _waveEmploymentSamples = employmentSamples;
      });
    } catch (_) {
      // Keep last good rollups on failure.
    }
  }

  String? _chedPresentlyEmployed(Map<String, dynamic> answers) {
    final raw = answers['ched_16'];
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  /// Loads CHED item-16 answers for [surveyId] when missing from the cache
  /// (e.g. wave outside the top-N preload).
  Future<void> _ensureSelectedWaveSample(String? surveyId) async {
    if (surveyId == null || !mounted) return;
    if (_waveEmploymentSamples.any((s) => s.survey.id == surveyId)) return;

    Survey? survey;
    for (final s in _surveys) {
      if (s.id == surveyId) {
        survey = s;
        break;
      }
    }
    if (survey == null || !survey.isChedGtsBuiltin || survey.archived) return;
    if (survey.status != SurveyStatus.published &&
        survey.status != SurveyStatus.closed) {
      return;
    }

    try {
      final responses = await _surveyService.getSurveyResponses(survey.id);
      final submitted = responses
          .where((r) => r.status == SurveyResponseStatus.submitted)
          .toList(growable: false);
      if (!mounted) return;

      final sample = _TracerWaveEmploymentSample(
        survey: survey,
        answers: [
          for (final r in submitted)
            _ChedEmploymentAnswer(
              userId: r.userId,
              presentlyEmployed: _chedPresentlyEmployed(r.answers),
              submittedAt: r.submittedAt,
            ),
        ],
      );

      SurveyReportRollup? rollup;
      if (submitted.isNotEmpty) {
        rollup = SurveyReportRollup(
          survey: survey,
          aggregates: SurveyReportAnalytics.aggregateChedResponses(
            responses: submitted,
          ),
        );
      }

      setState(() {
        _waveEmploymentSamples = [
          ..._waveEmploymentSamples.where((s) => s.survey.id != surveyId),
          sample,
        ]..sort((a, b) => a.survey.createdAt.compareTo(b.survey.createdAt));
        if (rollup != null) {
          _surveyRollups = [
            ..._surveyRollups.where((r) => r.survey.id != surveyId),
            rollup,
          ];
        }
      });
    } catch (_) {
      // Keep last good samples on failure.
    }
  }

  /// Employed / not-employed from CHED item 16 for the current filter.
  ///
  /// - One wave selected → answers on that wave only.
  /// - All tracers → latest wave answer per alumni (deduped across waves).
  ({int employed, int notEmployed, int answered, int waveCount})?
      _chedEmploymentStatusCounts(AdminReportsAnalytics a) {
    final latest = _chedLatestStatusByUser(a);
    if (latest.isEmpty) return null;

    var employed = 0;
    var notEmployed = 0;
    for (final status in latest.values) {
      if (status == ChedGtsBuiltin.yes) {
        employed++;
      } else {
        notEmployed++;
      }
    }
    final answered = employed + notEmployed;
    if (answered == 0) return null;

    final surveyId = _dashboardFilters.surveyId;
    final waveCount = _waveEmploymentSamples
        .where((s) => surveyId == null || s.survey.id == surveyId)
        .length;
    return (
      employed: employed,
      notEmployed: notEmployed,
      answered: answered,
      waveCount: waveCount,
    );
  }

  /// Latest CHED presently-employed answer per alumni in the current filter.
  Map<String, String> _chedLatestStatusByUser(AdminReportsAnalytics a) {
    final surveyId = _dashboardFilters.surveyId;
    final batch = _dashboardFilters.batchYear?.trim().toLowerCase();
    final course = _dashboardFilters.course?.trim().toLowerCase();
    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };

    final samples = [
      for (final sample in _waveEmploymentSamples)
        if (surveyId == null || sample.survey.id == surveyId) sample,
    ];
    if (samples.isEmpty) return const {};

    samples.sort(
      (a, b) => reportsSurveyDisplayDate(a.survey).compareTo(
        reportsSurveyDisplayDate(b.survey),
      ),
    );

    final latestStatusByUser = <String, String>{};
    for (final sample in samples) {
      for (final ans in sample.answers) {
        if (!_respondentMatchesCohort(
          userId: ans.userId,
          batch: batch,
          course: course,
          memberByAuth: memberByAuth,
        )) {
          continue;
        }
        final uid = ans.userId.trim();
        if (uid.isEmpty) continue;
        final status = ans.presentlyEmployed;
        if (status == null || status.isEmpty) continue;
        latestStatusByUser[uid] = status;
      }
    }
    return latestStatusByUser;
  }

  /// Alumni whose CHED answer in scope is presently employed (“Yes”).
  Set<String> _chedEmployedUserIds(AdminReportsAnalytics a) {
    return {
      for (final e in _chedLatestStatusByUser(a).entries)
        if (e.value == ChedGtsBuiltin.yes) e.key,
    };
  }

  /// Auth UIDs who submitted tracer wave(s) in the current filter (cohort-aware).
  Set<String> _tracerWaveSubmitterIds(AdminReportsAnalytics a) {
    final surveyId = _dashboardFilters.surveyId;
    final batch = _dashboardFilters.batchYear?.trim().toLowerCase();
    final course = _dashboardFilters.course?.trim().toLowerCase();
    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };
    final ids = <String>{};
    for (final sample in _waveEmploymentSamples) {
      if (surveyId != null && sample.survey.id != surveyId) continue;
      for (final ans in sample.answers) {
        final uid = ans.userId.trim();
        if (uid.isEmpty) continue;
        if (!_respondentMatchesCohort(
          userId: uid,
          batch: batch,
          course: course,
          memberByAuth: memberByAuth,
        )) {
          continue;
        }
        ids.add(uid);
      }
    }
    return ids;
  }

  /// Employment records for alumni who submitted tracer wave(s) in scope.
  ///
  /// Falls back to the full analytics set only when no CHED wave samples are
  /// loaded yet (initial load / empty).
  List<EmploymentRecord> _scopedEmploymentRecords(AdminReportsAnalytics a) {
    if (_waveEmploymentSamples.isEmpty) return a.reportEmploymentRecords;
    final submitters = _tracerWaveSubmitterIds(a);
    if (submitters.isEmpty) return const [];
    return a.reportEmploymentRecords
        .where((r) => submitters.contains(r.userId.trim()))
        .toList(growable: false);
  }

  /// Employment-record details only for alumni marked employed on CHED in scope.
  ///
  /// Prevents “Not employed” status from still showing Self-employed / salary /
  /// industry from a stale employment_records row.
  List<EmploymentRecord> _scopedEmployedDetailRecords(AdminReportsAnalytics a) {
    if (_waveEmploymentSamples.isEmpty) {
      return a.reportEmploymentRecords
          .where((r) => r.employmentStatus.toLowerCase() == 'employed')
          .toList(growable: false);
    }
    final employedIds = _chedEmployedUserIds(a);
    if (employedIds.isEmpty) return const [];
    return a.reportEmploymentRecords
        .where((r) => employedIds.contains(r.userId.trim()))
        .toList(growable: false);
  }

  Future<void> _refreshSurveyReportExtras(List<Survey> surveys) async {
    try {
      final pending = await _surveyService.countPendingSurveyAssignments(
        activeRegisteredOnly: true,
      );
      final activeAssignmentCounts = await _surveyService
          .countAssignmentsBySurvey(activeRegisteredOnly: true);
      final submittedCounts = await _surveyService
          .countSubmittedResponsesBySurvey(activeRegisteredOnly: true);
      if (!mounted) return;
      final ac = _analytics;
      if (ac == null) return;
      final adjustedSurveys = ac.surveys
          .map(
            (s) => s.copyWith(
              assignmentCount: activeAssignmentCounts[s.id] ?? 0,
              responseCount: submittedCounts[s.id] ?? s.responseCount,
            ),
          )
          .toList(growable: false);
      setState(() {
        _analytics = AdminReportsAnalytics(
          members: ac.members,
          employmentRecords: ac.employmentRecords,
          surveys: adjustedSurveys,
          announcements: ac.announcements,
          forumTopics: ac.forumTopics,
          portalUserCount: ac.portalUserCount,
          pendingSurveyAssignments: pending,
          assignmentCountsBySurveyId: activeAssignmentCounts,
          submittedResponsesBySurveyId: submittedCounts,
        );
        _surveys = adjustedSurveys;
        _lastUpdatedAt = DateTime.now();
      });
      unawaited(_reconcileSurveyResponseCounts(surveys, submittedCounts));
      await _loadSurveyRollupsFor(adjustedSurveys);
    } catch (_) {}
  }

  Future<void> _reconcileSurveyResponseCounts(
    List<Survey> surveys,
    Map<String, int> submittedCounts,
  ) async {
    for (final s in surveys) {
      final actual = submittedCounts[s.id];
      if (actual == null || actual == s.responseCount) continue;
      try {
        await _surveyService.setSurveyResponseCount(s.id, actual);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _analytics;
    if (a == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            color: AdminReportsTheme.primary,
            onRefresh: _loadAllData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : 0,
                ),
                child: const ReportsDashboardCanvas(
                  child: AdminReportsSkeleton(),
                ),
              ),
            ),
          );
        },
      );
    }
    final wide = MediaQuery.sizeOf(context).width > 900;
    final tabIndex = _tabController.index;
    final showCohortFilters = tabIndex == 1 || tabIndex == 2;
    final view = showCohortFilters ? _viewAnalytics(a) : a;
    final batchOptions = reportsFilterBatchOptions(a.members);
    final surveyOptions = reportsFilterSurveyOptions(
      a.surveys,
      tracerOnly: tabIndex == 1,
    );

    return RefreshIndicator(
      color: AdminReportsTheme.primary,
      onRefresh: _loadAllData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: ReportsDashboardCanvas(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: AdminReportsTheme.space2,
                ),
                child: _buildDashboardHeader(a),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SectionNavDelegate(
              height: _tabBarHeight,
              child: Semantics(
                label: 'Reports tabs',
                container: true,
                child: _buildTabBar(),
              ),
            ),
          ),
          if (showCohortFilters)
            SliverToBoxAdapter(
              child: ReportsDashboardCanvas(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AdminReportsTheme.space2,
                  ),
              child: Semantics(
                    label: 'Reports cohort filters',
                container: true,
                    child: ReportsCohortFilterBar(
                  filters: _dashboardFilters,
                  surveys: surveyOptions,
                  batchYears: batchOptions,
                      waveLabel: tabIndex == 1 ? 'Tracer wave' : 'Survey wave',
                      allWavesLabel: tabIndex == 1
                          ? 'All published tracers'
                          : 'All published surveys',
                  onChanged: (next) {
                    setState(() => _dashboardFilters = next);
                        unawaited(_ensureSelectedWaveSample(next.surveyId));
                  },
                    ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ReportsDashboardCanvas(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AdminReportsTheme.space3,
                  bottom: AdminReportsTheme.space4,
                ),
                child: _buildSelectedTab(
                  source: a,
                  view: view,
                  wide: wide,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Task-based tab body — one job per tab, no duplicate KPI strips.
  Widget _buildSelectedTab({
    required AdminReportsAnalytics source,
    required AdminReportsAnalytics view,
    required bool wide,
  }) {
    switch (_tabController.index) {
      case 1:
        return _buildTracerTab(view, wide);
      case 2:
        return _buildSurveysTab(view);
      case 3:
        return _buildDownloadsTab(source);
      default:
        return _buildOverviewTab(source);
    }
  }

  Widget _buildDashboardHeader(AdminReportsAnalytics a) {
    return ReportsPageHeader(
      reportDate: DateTime.now(),
      lastUpdated: _lastUpdatedAt,
      onDownloads: () => _selectTab(3),
      onAiSummary: () {
        _selectTab(0);
        _generateInsights();
      },
    );
  }

  List<ReportsInsightCardData> _insightCardsWithActions(
    List<ReportsInsightCardData> cards,
  ) {
    return [
      for (final card in cards)
        if (card.action != null)
          card
        else
          card.copyWith(
            actionLabel: insightActionForKind(card.kind)?.$1,
            action: insightActionForKind(card.kind)?.$2,
          ),
    ];
  }

  void _handleInsightAction(ReportsInsightAction action) {
    switch (action) {
      case ReportsInsightAction.openAlumniTracer:
        _selectTab(1);
      case ReportsInsightAction.openSurveys:
      case ReportsInsightAction.openParticipation:
        _selectTab(2);
      case ReportsInsightAction.openExportHub:
        _selectTab(3);
      case ReportsInsightAction.openExportEmployment:
        _selectTab(3);
      case ReportsInsightAction.openRosterModule:
        final open = widget.onOpenAdminMenu;
        if (open != null) {
          open(2);
        } else {
          _selectTab(1);
        }
      case ReportsInsightAction.openSurveysModule:
        final open = widget.onOpenAdminMenu;
        if (open != null) {
          open(10);
        } else {
          _selectTab(2);
        }
    }
  }

  List<ReportsInsightCardData> _buildPlaceholderInsights(
    AdminReportsAnalytics a,
    List<Survey> surveys,
  ) {
    final ched = surveys.where((s) => !s.archived && s.isChedGtsBuiltin);
    return buildHeuristicReportInsights(
      a,
      chedPublished: ched
          .where((s) => s.status == SurveyStatus.published)
          .length,
      chedResponses: ched.fold<int>(
        0,
        (sum, s) => sum + a.submittedResponseCount(s),
      ),
    );
  }

  Future<void> _generateInsights() async {
    final source = _analytics;
    if (source == null || _insightsGenerating) return;
    final a = _viewAnalytics(source);
    setState(() => _insightsGenerating = true);
    try {
      final cards = await generateReportInsights(
        analytics: a,
        surveys: a.surveys,
      );
      if (!mounted) return;
      setState(() {
        _insightCards = cards;
        _insightsAreAi = true;
        _insightsGenerating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _insightsGenerating = false);
    }
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: AdminReportsTheme.primary,
        indicatorWeight: 3,
        labelColor: AdminReportsTheme.primary,
        unselectedLabelColor: AdminReportsTheme.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          for (var i = 0; i < _tabLabels.length; i++)
            Tab(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Icon(_tabIcons[i], size: 17),
                    const SizedBox(width: 7),
                  Text(_tabLabels[i]),
                ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Overview: system pulse — KPIs, attention, light trend, jump links.
  Widget _buildOverviewTab(AdminReportsAnalytics a) {
    return ReportsSectionStack(
      children: [
        ReportsSectionShell(
          icon: Icons.insights_outlined,
          title: 'At a glance',
          subtitle: 'System status across roster, tracer, and surveys.',
          actions: [
            ReportsSectionAction(
              label: 'Downloads',
              icon: Icons.download_outlined,
              onPressed: () => _selectTab(3),
            ),
          ],
          child: _buildMetricsGrid(_overviewMetrics(a)),
        ),
        ReportsSectionShell(
          icon: Icons.priority_high_outlined,
          title: 'Needs attention',
          child: _buildAttentionList(a),
        ),
        ReportsSectionShell(
          icon: Icons.grid_view_outlined,
          title: 'Go to detail',
          subtitle: 'Jump into the workspace you need next.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth >= 640;
              final tiles = [
                ReportsNavTile(
                  icon: Icons.school_outlined,
                  title: 'Tracer outcomes',
                  subtitle: 'Coverage, employment, and CHED waves',
                  onTap: () => _selectTab(1),
                  color: Colors.deepPurple,
                ),
                ReportsNavTile(
                  icon: Icons.poll_outlined,
                  title: 'Survey portfolio',
                  subtitle: 'Response health and low responders',
                  onTap: () => _selectTab(2),
                  color: _navy,
                ),
                ReportsNavTile(
                  icon: Icons.open_in_new,
                  title: 'Surveys module',
                  subtitle: 'Question-level charts and wave tools',
                  onTap: () {
                    final open = widget.onOpenAdminMenu;
                    if (open != null) open(10);
                  },
                  color: Colors.teal.shade700,
                ),
                ReportsNavTile(
                  icon: Icons.download_outlined,
                  title: 'Downloads',
                  subtitle: 'Preset packs and wave comparison',
                  onTap: () => _selectTab(3),
                  color: Colors.orange.shade800,
                ),
              ];
              if (!twoCol) {
                return Column(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      tiles[i],
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 8),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: tiles[2]),
                      const SizedBox(width: 8),
                      Expanded(child: tiles[3]),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        _buildOverviewCoverageStrip(a),
        _buildAiInsightsSection(a),
        ReportsSectionShell(
          icon: Icons.show_chart_outlined,
          title: 'Roster growth',
          subtitle: 'Cumulative roster over 12 months.',
          initiallyExpanded: false,
          child: _isRefreshing
              ? const ReportsChartSkeleton(height: ReportsChartHeights.hero)
              : _buildRosterGrowthLineChart(a),
        ),
      ],
    );
  }

  Widget _buildTracerTab(AdminReportsAnalytics a, bool wide) {
    final chedStatus = _chedEmploymentStatusCounts(a);
    final waveScoped = _dashboardFilters.surveyId != null;
    final scopeCount = chedStatus?.answered ?? 0;
    final waveCount = chedStatus?.waveCount ?? _employmentRateByWavePoints(a).length;
    final scopeNoun = waveScoped
        ? 'CHED employment answers'
        : (waveCount <= 1
            ? 'CHED employment answers'
            : 'alumni (latest wave across $waveCount tracers)');
    final scope = _dashboardFilters.scopeLabel(
      surveys: _surveys,
      responseOrRecordCount: scopeCount,
      countNoun: scopeNoun,
    );
    final empty = chedStatus == null &&
        _chedChoiceCounts('ched_24a').isEmpty &&
        _employmentRateByWavePoints(a).isEmpty &&
        _scopedEmploymentRecords(a).isEmpty;

    return ReportsSectionStack(
      children: [
        _buildTracerCoverageSection(a),
        ReportsSectionShell(
          icon: Icons.work_outline,
          title: 'Employment outcomes',
          subtitle: waveScoped
              ? 'Status from this tracer wave (CHED presently employed).'
              : 'Compare published tracer waves, then batch and course outcomes.',
          trailing: ReportsDetailsButton(
            title: 'Employment outcomes',
            body: ReportsDetailsButton.compose(
              definition: waveScoped
                  ? 'Shows whether graduates on this tracer said they are '
                      'currently employed.'
                  : 'Shows whether graduates said they are currently employed. '
                      'If someone answered more than one tracer, only their '
                      'latest answer is counted here.',
              calculation:
                  'Employed means they answered “Yes”. Not employed means '
                  '“No” or “Never employed”.',
              scope: scope,
              limitation:
                  'When comparing all tracers, you will see answers by wave, '
                  'batch, and course. Charts for employment type, salary, '
                  'location, and industry include only those who said they '
                  'are currently employed.',
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Export this filtered Tracer view',
              enabled: !_downloadBusy,
              onSelected: (value) {
                if (value == 'downloads') {
                  _selectTab(3);
                  return;
                }
                final format = value == 'excel'
                    ? CustomReportFormat.excel
                    : CustomReportFormat.pdf;
                unawaited(_exportTracerFilteredView(a, format: format));
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'pdf',
                  child: Text('Export PDF (this filter)'),
                ),
                PopupMenuItem(
                  value: 'excel',
                  child: Text('Export Excel (this filter)'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'downloads',
                  child: Text('Open Downloads tab'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download_outlined,
                      size: 14,
                      color: _downloadBusy
                          ? AdminReportsTheme.textMuted
                          : AdminReportsTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _downloadBusy ? 'Exporting…' : 'Export view',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _downloadBusy
                            ? AdminReportsTheme.textMuted
                            : AdminReportsTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReportsScopeCaption(text: scope),
              if (empty)
                ReportsChartEmptyState(
                  message: waveScoped
                      ? 'No employment or CHED outcome data on this tracer yet. '
                          'Publish the wave and wait for submissions.'
                      : 'No employment or CHED outcome data for this filter yet. '
                          'Widen batch/course filters or wait for tracer submissions.',
                  icon: Icons.work_off_outlined,
                )
              else ...[
                _buildEmploymentRateByWaveChart(a),
                const SizedBox(height: AdminReportsTheme.gutter),
                _buildTracerIntelligenceBody(a, wide),
              ],
            ],
          ),
        ),
        ReportsSectionShell(
          icon: Icons.timeline_outlined,
          title: 'Same alumni across waves',
          subtitle:
              'Employment status over time for people who answered more than one tracer.',
          initiallyExpanded: false,
          trailing: ReportsDetailsButton(
            title: 'Same alumni across waves',
            body: ReportsDetailsButton.compose(
              definition:
                  'Lists graduates who answered at least two tracer surveys, '
                  'so you can see how their employment status changed over time.',
              calculation:
                  'Each chip is that person’s employment answer on that tracer '
                  '(Yes, No, or Never employed), shown in date order.',
              scope: scope,
              limitation:
                  'A person appears here if they used the same portal account '
                  'on more than one tracer. Batch and course filters still apply.',
            ),
          ),
          child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              ReportsScopeCaption(text: scope),
              TracerLongitudinalPanel(
                rows: _longitudinalRows(a),
                onOpenPerson: (row) {
                  unawaited(
                    showTracerRespondentsDialog(
                      context: context,
                      title: row.displayName,
                      subtitle:
                          '${row.points.length} waves · employment status over time',
                      rows: [
                        for (final p in row.points)
                          TracerRespondentRow(
                            userId: row.userId,
                            displayName: p.waveLabel,
                            subtitle: DateFormat.yMMMd().format(p.waveDate),
                            status: p.status,
                          ),
                      ],
                    ),
                  );
                },
              ),
                  ],
                ),
        ),
        ReportsSectionShell(
          icon: Icons.pie_chart_outline,
          title: 'Roster context',
          subtitle: 'Batch and course mix for the current filter.',
          initiallyExpanded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReportsScopeCaption(text: scope),
              _buildRosterCharts(a, wide),
              const SizedBox(height: AdminReportsTheme.gutter),
              _isRefreshing
                  ? const ReportsChartSkeleton(
                      height: ReportsChartHeights.standard,
                    )
                  : _buildCourseComparisonTable(a),
            ],
          ),
        ),
      ],
    );
  }

  TracerCoverageSnapshot _coverageFor(AdminReportsAnalytics a) {
    return buildTracerCoverage(
      members: a.activeRoster,
      tracerSubmitterUserIds: _tracerSubmitterIds(),
      filters: _dashboardFilters,
      surveys: _surveys,
    );
  }

  /// Auth UIDs who submitted the selected tracer wave(s).
  Set<String> _tracerSubmitterIds() {
    final surveyId = _dashboardFilters.surveyId;
    final ids = <String>{};
    for (final sample in _waveEmploymentSamples) {
      if (surveyId != null && sample.survey.id != surveyId) continue;
      for (final ans in sample.answers) {
        final uid = ans.userId.trim();
        if (uid.isNotEmpty) ids.add(uid);
      }
    }
    return ids;
  }

  Widget _buildOverviewCoverageStrip(AdminReportsAnalytics a) {
    // Overview uses system-wide scope (no cohort filters on this tab).
    final coverage = buildTracerCoverage(
      members: a.activeRoster,
      tracerSubmitterUserIds: {
        for (final sample in _waveEmploymentSamples)
          for (final ans in sample.answers)
            if (ans.userId.trim().isNotEmpty) ans.userId.trim(),
      },
      filters: ReportsDashboardFilters.empty,
      surveys: _surveys,
    );

    return ReportsSectionShell(
      icon: Icons.groups_outlined,
      title: 'Tracer coverage',
      subtitle: 'Roster → registered → submitted a tracer wave.',
      initiallyExpanded: false,
      trailing: ReportsDetailsButton(
        title: 'Tracer coverage',
        body: ReportsDetailsButton.compose(
          definition: coverage.definition,
          scope: 'System-wide (Overview ignores cohort filters).',
          limitation:
              'Different from “Profile complete,” which is the tracer profile flag on the roster.',
        ),
      ),
      actions: [
        ReportsSectionAction(
          label: 'Open Tracer',
          icon: Icons.school_outlined,
          onPressed: () => _selectTab(1),
        ),
      ],
      child: ReportsResponsiveGrid(
        minItemWidth: 160,
        maxColumns: 3,
        itemCount: 3,
        itemBuilder: (context, i) {
          switch (i) {
            case 0:
              return _coverageKpiTile(
                label: 'Not registered',
                value: '${coverage.notRegistered}',
                hint: 'Roster only',
                color: Colors.orange.shade800,
                icon: Icons.person_off_outlined,
              );
            case 1:
              return _coverageKpiTile(
                label: 'Registered, no tracer',
                value: '${coverage.registeredNoTracer}',
                hint: 'No CHED submit',
                color: Colors.deepPurple,
                icon: Icons.mark_email_unread_outlined,
              );
            default:
              return _coverageKpiTile(
                label: 'Took a tracer',
                value: '${coverage.tookTracer}',
                hint:
                    '${(coverage.tracerTakeRateAmongRegistered * 100).toStringAsFixed(0)}% of registered',
                color: Colors.green.shade700,
                icon: Icons.assignment_turned_in_outlined,
              );
          }
        },
      ),
    );
  }

  Widget _buildTracerCoverageSection(AdminReportsAnalytics a) {
    final coverage = _coverageFor(a);
    final scope = _dashboardFilters.scopeLabel(
      surveys: _surveys,
      responseOrRecordCount: coverage.rosterTotal,
      countNoun: 'roster alumni',
    );

    if (coverage.rosterTotal == 0) {
      return ReportsSectionShell(
        icon: Icons.groups_outlined,
        title: 'Coverage',
        subtitle: 'Roster → registered → took tracer',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReportsScopeCaption(text: scope),
            const ReportsChartEmptyState(
              message:
                  'No roster alumni in this filter yet. Clear batch/course or add roster rows.',
              icon: Icons.groups_outlined,
            ),
          ],
        ),
      );
    }

    return ReportsSectionShell(
      icon: Icons.groups_outlined,
      title: 'Coverage',
      subtitle: 'Roster → registered → took tracer',
      trailing: ReportsDetailsButton(
        title: 'Coverage',
        body: ReportsDetailsButton.compose(
          definition: coverage.definition,
          scope: scope,
          limitation:
              '“Took tracer” means submitted the wave — not the same as '
              '“Profile complete” on Overview.',
        ),
      ),
      actions: [
        ReportsSectionAction(
          label: 'Open roster',
          icon: Icons.school_outlined,
          onPressed: () {
            final open = widget.onOpenAdminMenu;
            if (open != null) open(2);
          },
        ),
        ReportsSectionAction(
          label: 'Open Surveys',
          icon: Icons.poll_outlined,
          onPressed: () {
            final open = widget.onOpenAdminMenu;
            if (open != null) open(10);
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportsScopeCaption(text: scope),
          ReportsResponsiveGrid(
            minItemWidth: 160,
            maxColumns: 3,
            itemCount: 3,
            itemBuilder: (context, i) {
              switch (i) {
                case 0:
                  return _coverageKpiTile(
                    label: 'Not registered',
                    value: '${coverage.notRegistered}',
                    hint: 'On roster only',
                    color: Colors.orange.shade800,
                    icon: Icons.person_off_outlined,
                  );
                case 1:
                  return _coverageKpiTile(
                    label: 'Registered, no tracer',
                    value: '${coverage.registeredNoTracer}',
                    hint: 'Need follow-up',
                    color: Colors.deepPurple,
                    icon: Icons.mark_email_unread_outlined,
                  );
                default:
                  return _coverageKpiTile(
                    label: 'Took tracer',
                    value: '${coverage.tookTracer}',
                    hint:
                        '${(coverage.tracerTakeRateAmongRegistered * 100).toStringAsFixed(0)}% of registered',
                    color: Colors.green.shade700,
                    icon: Icons.assignment_turned_in_outlined,
                  );
              }
            },
          ),
          const SizedBox(height: AdminReportsTheme.gutter),
          _buildCoverageFunnelChart(coverage),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (coverage.notRegistered > 0)
                OutlinedButton.icon(
                  onPressed: () {
                    final open = widget.onOpenAdminMenu;
                    if (open != null) open(2);
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: Text('Follow up ${coverage.notRegistered} unregistered'),
                ),
              if (coverage.registeredNoTracer > 0)
                OutlinedButton.icon(
                  onPressed: () {
                    final open = widget.onOpenAdminMenu;
                    if (open != null) open(10);
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: Text(
                    'Remind ${coverage.registeredNoTracer} without tracer',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coverageKpiTile({
    required String label,
    required String value,
    required String hint,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AdminReportsTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.05,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: AdminReportsTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageFunnelChart(TracerCoverageSnapshot coverage) {
    final stages = <({String label, int value, Color color})>[
      (
        label: 'Roster',
        value: coverage.rosterTotal,
        color: AdminReportsTheme.primary,
      ),
      (
        label: 'Registered',
        value: coverage.registered,
        color: Colors.blue.shade700,
      ),
      (
        label: 'Took tracer',
        value: coverage.tookTracer,
        color: Colors.green.shade700,
      ),
    ];
    final maxY = stages
        .map((s) => s.value)
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble()
        .clamp(1, double.infinity);

    return _chartCard(
      title: 'Coverage funnel',
      details: ReportsDetailsButton.compose(
        definition:
            'Steps from total roster size, to registered portal accounts, '
            'to graduates who submitted a tracer.',
        scope: coverage.waveLabel,
      ),
      height: ReportsChartHeights.hero,
      hero: true,
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < 0 || groupIndex >= stages.length) {
                        return null;
                      }
                      final s = stages[groupIndex];
                      return BarTooltipItem(
                        '${s.label}\n${s.value}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= stages.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            stages[i].label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < stages.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: stages[i].value.toDouble(),
                          color: stages[i].color,
                          width: 36,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              swapAnimationDuration: Duration.zero,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registered take-rate '
            '${(coverage.tracerTakeRateAmongRegistered * 100).toStringAsFixed(0)}%'
            ' · Roster take-rate '
            '${(coverage.tracerTakeRateAmongRoster * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminReportsTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurveysTab(AdminReportsAnalytics a) {
    final assigned = a.totalSurveyAssignments;
    final submitted = a.totalSurveyResponses;
    final pending = (assigned - submitted).clamp(0, assigned);
    final responseRate = assigned == 0 ? 0.0 : submitted / assigned;
    final dropOff = assigned == 0 ? 0.0 : pending / assigned;
    final scope = _dashboardFilters.scopeLabel(
      surveys: _surveys,
      responseOrRecordCount: submitted,
      countNoun: 'submitted responses',
    );

    return ReportsSectionStack(
      children: [
        ReportsSectionShell(
          icon: Icons.how_to_vote_outlined,
          title: 'Response health',
          subtitle: 'Portfolio view — open Surveys for question-level charts.',
          actions: [
            ReportsSectionAction(
              label: 'Open Surveys',
              icon: Icons.open_in_new,
              onPressed: () {
                final open = widget.onOpenAdminMenu;
                if (open != null) open(10);
              },
            ),
            ReportsSectionAction(
              label: 'Downloads',
              icon: Icons.download_outlined,
              onPressed: () => _selectTab(3),
            ),
          ],
          child: _isRefreshing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    ReportsChartSkeleton(height: 150),
                    SizedBox(height: AdminReportsTheme.space2),
                    ReportsChartSkeleton(height: ReportsChartHeights.hero),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReportsScopeCaption(text: scope),
                    Text(
                      '${a.publishedSurveys} live · ${a.draftSurveys} drafts · '
                      '${a.closedSurveys} closed',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AdminReportsTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AdminReportsTheme.space2),
                    if (assigned == 0)
                      const ReportsChartEmptyState(
                        message: 'No survey assignments in this filter yet.',
                        icon: Icons.poll_outlined,
                      )
                    else ...[
                    _buildParticipationFunnel(
                      assigned: assigned,
                      submitted: submitted,
                      pending: pending,
                      responseRate: responseRate,
                      dropOff: dropOff,
                    ),
                    const SizedBox(height: AdminReportsTheme.space2),
                    _buildParticipationBySurveyChart(a),
                    const SizedBox(height: AdminReportsTheme.space2),
                    _buildLowResponseList(a),
                  ],
                  ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadsTab(AdminReportsAnalytics a) {
    return ReportsDownloadsPanel(
      busy: _downloadBusy,
      onDownload: (preset, {required format, required printPreview}) {
        return _downloadPreset(
          a,
          preset,
          format: format,
          printPreview: printPreview,
        );
      },
    );
  }

  Widget _buildAttentionList(AdminReportsAnalytics a) {
    final items = <_AttentionItem>[];
    if (a.registeredWithoutTracerComplete > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.assignment_late_outlined,
          color: Colors.deepPurple,
          title:
              '${a.registeredWithoutTracerComplete} need a complete tracer profile',
          subtitle:
              '${a.tracerCompleteCount}/${a.registeredOnRoster} registered complete',
          actionLabel: 'Tracer',
          onAction: () => _selectTab(1),
        ),
      );
    }
    if (a.pendingSurveyAssignments > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.mark_email_unread_outlined,
          color: _navy,
          title: '${a.pendingSurveyAssignments} survey assignments waiting',
          subtitle:
              '${a.totalSurveyResponses}/${a.totalSurveyAssignments} submitted',
          actionLabel: 'Survey',
          onAction: () => _selectTab(2),
        ),
      );
    }
    if (a.reportEmploymentCount == 0 && a.registeredOnRoster > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.work_off_outlined,
          color: Colors.orange.shade800,
          title: 'No employment submissions yet',
          subtitle: 'Employment charts stay empty until alumni submit data.',
          actionLabel: 'Tracer',
          onAction: () => _selectTab(1),
        ),
      );
    }
    if (a.unclaimedRoster > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.person_off_outlined,
          color: Colors.blueGrey,
          title: '${a.unclaimedRoster} roster alumni not registered',
          subtitle:
              '${a.registeredOnRoster}/${a.rosterTotal} have portal accounts',
          actionLabel: 'Roster',
          onAction: () {
            final open = widget.onOpenAdminMenu;
            if (open != null) open(2);
          },
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AdminReportsTheme.success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(
            color: AdminReportsTheme.success.withValues(alpha: 0.25),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AdminReportsTheme.success),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nothing urgent — follow-ups look on track.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AdminReportsTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _buildAttentionCard(items[i]),
        ],
      ],
    );
  }

  Widget _buildAttentionCard(_AttentionItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onAction,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
            color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Row(
        children: [
          Container(
                width: 34,
                height: 34,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
            ),
                child: Icon(item.icon, color: item.color, size: 17),
          ),
              const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                        fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AdminReportsTheme.textPrimary,
                        height: 1.25,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                        fontSize: 11.5,
                        color: AdminReportsTheme.textMuted,
                        height: 1.3,
                  ),
                ),
              ],
            ),
          ),
              const SizedBox(width: 6),
              Text(
                item.actionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: item.color,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: item.color),
            ],
          ),
        ),
      ),
    );
  }

  /// Five headline KPIs only — detail lives on Tracer / Surveys tabs.
  List<_Metric> _overviewMetrics(AdminReportsAnalytics a) {
    final regStatus = reportsKpiStatusFromRate(a.registrationRate);
    final tracerStatus = reportsKpiStatusFromRate(a.tracerCompletionRate);
    final surveyStatus = reportsKpiStatusFromRate(a.surveyResponseRate);
    final employmentStatus = reportsKpiStatusFromRate(
      a.employmentRateAmongSubmissions,
    );
    final pendingStatus = a.pendingSurveyAssignments == 0
        ? ReportsKpiStatus.positive
        : (a.pendingSurveyAssignments > 20
              ? ReportsKpiStatus.attention
              : ReportsKpiStatus.watch);

    return [
      _Metric(
        label: 'Registered alumni',
        value: a.registeredOnRoster.toString(),
        icon: Icons.how_to_reg,
        color: Colors.blue,
        comparisonLabel: 'of ${a.rosterTotal} roster',
        details: ReportsDetailsButton.compose(
          definition: 'Alumni on the roster who already have a portal account.',
          calculation:
              '${a.registeredOnRoster} registered out of ${a.rosterTotal} on the active roster.',
          scope: 'Overview for the whole system (cohort filters do not apply here).',
        ),
        status: regStatus,
        statusLabel: reportsKpiStatusLabel(regStatus),
      ),
      _Metric(
        label: 'Profile complete',
        value: '${(a.tracerCompletionRate * 100).toStringAsFixed(0)}%',
        icon: Icons.assignment_turned_in,
        color: Colors.deepPurple,
        comparisonLabel:
            '${a.tracerCompleteCount}/${a.registeredOnRoster} registered',
        details: ReportsDetailsButton.compose(
          definition:
              'Registered alumni whose profile is marked complete in the roster.',
          calculation:
              '${a.tracerCompleteCount} complete out of ${a.registeredOnRoster} registered.',
          scope: 'Based on the roster profile status — not tracer survey submission.',
          limitation:
              'This is different from “Took tracer”, which counts completed '
              'tracer surveys.',
        ),
        status: tracerStatus,
        statusLabel: reportsKpiStatusLabel(tracerStatus),
      ),
      _Metric(
        label: 'Survey completion',
        value: '${(a.surveyResponseRate * 100).toStringAsFixed(0)}%',
        icon: Icons.check_circle_outline,
        color: _navy,
        comparisonLabel:
            '${a.totalSurveyResponses}/${a.totalSurveyAssignments} assignments',
        details: ReportsDetailsButton.compose(
          definition: 'Share of survey invitations that received a submitted response.',
          calculation:
              '${a.totalSurveyResponses} submitted out of ${a.totalSurveyAssignments} assigned.',
          scope: 'All survey waves included in this overview.',
        ),
        status: surveyStatus,
        statusLabel: reportsKpiStatusLabel(surveyStatus),
      ),
      _Metric(
        label: 'Employment rate',
        value: a.reportEmploymentCount == 0
            ? '—'
            : '${(a.employmentRateAmongSubmissions * 100).toStringAsFixed(0)}%',
        icon: Icons.work_outline,
        color: Colors.green.shade700,
        comparisonLabel: a.reportEmploymentCount == 0
            ? 'No data yet'
            : '${a.employedCount}/${a.reportEmploymentCount} submissions',
        details: ReportsDetailsButton.compose(
          definition: AdminReportsAnalytics.employmentRateDefinition,
          calculation: a.reportEmploymentCount == 0
              ? 'No employment information is available yet.'
              : '${a.employedCount} employed out of ${a.reportEmploymentCount} '
                  'with employment information.',
          scope: 'Registered alumni with employment information on file '
              '(each person counted once).',
          limitation:
              'If the data set is large, results may be capped. Tracer employment '
              'charts use survey answers instead.',
        ),
        status: a.reportEmploymentCount == 0
            ? ReportsKpiStatus.neutral
            : employmentStatus,
        statusLabel: a.reportEmploymentCount == 0
            ? 'No data'
            : reportsKpiStatusLabel(employmentStatus),
      ),
      _Metric(
        label: 'Pending surveys',
        value: a.pendingSurveyAssignments.toString(),
        icon: Icons.mark_email_unread_outlined,
        color: Colors.orange.shade800,
        comparisonLabel: a.pendingSurveyAssignments == 0
            ? 'Clear'
            : 'Awaiting response',
        details: ReportsDetailsButton.compose(
          definition: 'Assignments that still need an alumni response.',
          calculation:
              '${a.totalSurveyAssignments} assigned − ${a.totalSurveyResponses} submitted.',
          scope: 'Portfolio assignments across survey waves.',
        ),
        status: pendingStatus,
        statusLabel: a.pendingSurveyAssignments == 0
            ? 'Clear'
            : reportsKpiStatusLabel(pendingStatus),
      ),
    ];
  }

  /// Month keys for the last [months] calendar months (oldest → newest).
  List<DateTime> _monthWindow({int months = 12}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1));
    return [
      for (var i = 0; i < months; i++) DateTime(start.year, start.month + i),
    ];
  }

  String _monthLabel(DateTime month) {
    const names = [
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
    return '${names[month.month - 1]} ${month.year.toString().substring(2)}';
  }

  /// Monthly new counts + cumulative totals from real event dates.
  ({List<double> monthly, List<double> cumulative}) _monthlySeries(
    Iterable<DateTime> dates, {
    int months = 12,
  }) {
    final window = _monthWindow(months: months);
    final buckets = List<double>.filled(window.length, 0);
    for (final d in dates) {
      final key = DateTime(d.year, d.month);
      for (var i = 0; i < window.length; i++) {
        if (window[i].year == key.year && window[i].month == key.month) {
          buckets[i] += 1;
          break;
        }
      }
    }
    final cumulative = <double>[];
    var running = 0.0;
    // Seed cumulative with records before the window so the line reflects
    // total growth, not only the last 12 months.
    final windowStart = window.first;
    for (final d in dates) {
      final key = DateTime(d.year, d.month);
      if (key.isBefore(windowStart)) running += 1;
    }
    for (final v in buckets) {
      running += v;
      cumulative.add(running);
    }
    return (monthly: buckets, cumulative: cumulative);
  }


  Widget _buildRosterGrowthLineChart(AdminReportsAnalytics a) {
    final series = _monthlySeries(a.activeRoster.map((m) => m.createdAt));
    final registeredSeries = _monthlySeries(
      a.activeRoster.where((m) => m.isRegisteredUser).map((m) => m.createdAt),
    );
    final months = _monthWindow();
    if (series.cumulative.every((v) => v == 0)) {
      return _chartCard(
        title: 'Alumni roster growth',
        details: ReportsDetailsButton.compose(
          definition: 'Cumulative roster entries by month the record was added.',
        ),
        height: ReportsChartHeights.hero,
        hero: true,
        child: const ReportsChartEmptyState(
          message: 'No roster timestamps available yet',
          icon: Icons.show_chart_outlined,
        ),
      );
    }

    final maxY = [
      ...series.cumulative,
      ...registeredSeries.cumulative,
    ].fold<double>(0, (m, v) => v > m ? v : m);

    return _chartCard(
      title: 'Alumni roster growth',
      details: ReportsDetailsButton.compose(
        definition:
            'Cumulative roster vs registered alumni by record created month.',
      ),
      height: ReportsChartHeights.hero,
      hero: true,
      child: _lineChart(
        months: months,
        maxY: (maxY * 1.15).clamp(4, double.infinity),
        series: [
          _LineSeries(
            label: 'Total roster',
            color: _navy,
            values: series.cumulative,
          ),
          _LineSeries(
            label: 'Registered',
            color: Colors.blue,
            values: registeredSeries.cumulative,
          ),
        ],
      ),
    );
  }


  Widget _lineChart({
    required List<DateTime> months,
    required double maxY,
    required List<_LineSeries> series,
    bool yAsPercent = false,
  }) {
    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (months.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineTouchData: const LineTouchData(enabled: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= months.length) {
                        return const SizedBox.shrink();
                      }
                      // Show every other label to avoid crowding.
                      if (i % 2 != 0 && months.length > 8) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _monthLabel(months[i]),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: yAsPercent ? 36 : 32,
                    getTitlesWidget: (value, meta) {
                      if (!yAsPercent && value != value.roundToDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        yAsPercent
                            ? '${value.toInt()}%'
                            : value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < s.values.length; i++)
                        FlSpot(i.toDouble(), s.values[i]),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: s.color,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: series.length == 1,
                      color: s.color.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ),
            duration: Duration.zero,
          ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 4,
            children: [for (final s in series) _legendItem(s.color, s.label)],
          ),
        ],
      ],
    );
  }

  Widget _buildAiInsightsSection(AdminReportsAnalytics a) {
    return ReportsInsightsPanel(
      cards: _insightCardsWithActions(
        _insightCards.isEmpty
            ? _buildPlaceholderInsights(a, _surveys)
            : _insightCards,
      ),
      isGenerating: _insightsGenerating,
      isAiGenerated: _insightsAreAi,
      onGenerate: _generateInsights,
      onInsightAction: _handleInsightAction,
    );
  }

  /// Employment rate per published/closed CHED tracer wave (not by calendar month).
  Widget _buildEmploymentRateByWaveChart(AdminReportsAnalytics a) {
    final points = _employmentRateByWavePoints(a);
    if (points.isEmpty) {
      return _chartCard(
        title: 'Employment rate by tracer',
        details: ReportsDetailsButton.compose(
          definition:
              'Share of graduates who said they are currently employed, '
              'shown for each published tracer.',
          calculation:
              'Employed answers divided by total employment answers on that tracer.',
          limitation:
              'This uses tracer survey answers. It may differ from the '
              'employment rate on the Overview tab.',
        ),
        height: ReportsChartHeights.hero,
        hero: true,
        child: const ReportsChartEmptyState(
          message: 'No published tracer waves with employment answers yet',
          icon: Icons.show_chart_outlined,
        ),
      );
    }

    return _chartCard(
      title: 'Employment rate by tracer',
      details: ReportsDetailsButton.compose(
        definition:
            'Share of graduates who said they are currently employed, '
            'shown for each published tracer.',
        calculation:
            'Employed answers divided by total employment answers on that tracer.',
        limitation:
            'This uses tracer survey answers. It may differ from the '
            'employment rate on the Overview tab.',
      ),
      height: ReportsChartHeights.hero,
      hero: true,
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble().clamp(0, double.infinity),
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touched) {
                      return [
                        for (final t in touched)
                          if (t.x.toInt() >= 0 && t.x.toInt() < points.length)
                            LineTooltipItem(
                              '${points[t.x.toInt()].label}\n'
                              '${points[t.x.toInt()].rate.toStringAsFixed(0)}% '
                              '(${points[t.x.toInt()].employed}/'
                              '${points[t.x.toInt()].answered})',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      ];
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (points.length > 6 && i % 2 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            points[i].shortLabel,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].rate),
                    ],
                    isCurved: points.length > 2,
                    curveSmoothness: 0.2,
                    color: Colors.green.shade700,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.green.shade700,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.shade700.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            points.length == 1
                ? '1 tracer wave in scope'
                : '${points.length} tracer waves in chronological order',
            style: const TextStyle(
              fontSize: 11,
              color: AdminReportsTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  List<_WaveEmploymentRatePoint> _employmentRateByWavePoints(
    AdminReportsAnalytics a,
  ) {
    final surveyId = _dashboardFilters.surveyId;
    final batch = _dashboardFilters.batchYear?.trim().toLowerCase();
    final course = _dashboardFilters.course?.trim().toLowerCase();

    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };

    final points = <_WaveEmploymentRatePoint>[];
    for (final sample in _waveEmploymentSamples) {
      if (surveyId != null && sample.survey.id != surveyId) continue;

      var answered = 0;
      var employed = 0;
      for (final ans in sample.answers) {
        if (!_respondentMatchesCohort(
          userId: ans.userId,
          batch: batch,
          course: course,
          memberByAuth: memberByAuth,
        )) {
          continue;
        }
        final status = ans.presentlyEmployed;
        if (status == null || status.isEmpty) continue;
        answered++;
        if (status == ChedGtsBuiltin.yes) employed++;
      }
      if (answered == 0) continue;
      points.add(
        _WaveEmploymentRatePoint(
          surveyId: sample.survey.id,
          label: sample.survey.title,
          shortLabel: _waveShortLabel(sample.survey),
          rate: employed / answered * 100,
          employed: employed,
          answered: answered,
          createdAt: sample.survey.createdAt,
        ),
      );
    }
    return points;
  }

  bool _respondentMatchesCohort({
    required String userId,
    required String? batch,
    required String? course,
    required Map<String, AlumniMember> memberByAuth,
  }) {
    if (batch == null && course == null) return true;
    final uid = userId.trim();
    final member = memberByAuth[uid];
    final profile = _registeredProfiles[uid];

    final memberBatch = member == null
        ? ''
        : (member.batchYear.trim().isNotEmpty
              ? member.batchYear.trim()
              : (member.yearGraduated ?? '').trim());
    final profileBatch = profile == null
        ? ''
        : (profile.batchYear.trim().isNotEmpty
              ? profile.batchYear.trim()
              : profile.yearGraduated.trim());
    final resolvedBatch =
        memberBatch.isNotEmpty ? memberBatch : profileBatch;

    final resolvedCourse = (member?.course.trim().isNotEmpty == true)
        ? member!.course.trim()
        : (profile?.program.trim() ?? '');

    if (batch != null && resolvedBatch.toLowerCase() != batch) return false;
    if (course != null && resolvedCourse.toLowerCase() != course) return false;
    return true;
  }

  String _waveShortLabel(Survey survey) {
    final stamp = DateFormat('MMM yy').format(reportsSurveyDisplayDate(survey));
    final title = survey.title.trim();
    if (title.isEmpty) return stamp;
    final short = title.length <= 14 ? title : '${title.substring(0, 12)}…';
    return '$stamp\n$short';
  }

  Widget _buildTracerIntelligenceBody(AdminReportsAnalytics a, bool wide) {
    if (_isRefreshing) {
      return Column(
        children: [
          const ReportsChartSkeleton(height: ReportsChartHeights.standard),
          const SizedBox(height: AdminReportsTheme.gutter),
          ReportsChartGrid.twoColumn(
            left: const ReportsChartSkeleton(),
            right: const ReportsChartSkeleton(),
          ),
        ],
      );
    }

    final showAllComparisons = _dashboardFilters.surveyId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmploymentPieChart(a),
        if (showAllComparisons) ...[
          const SizedBox(height: AdminReportsTheme.sectionGap),
          _buildCompareAcrossHeader(),
          const SizedBox(height: AdminReportsTheme.gutter),
          _buildWaveComparisonChart(a),
          const SizedBox(height: AdminReportsTheme.gutter),
        ReportsChartGrid.twoColumn(
            left: _buildAnswersByBatchChart(a),
            right: _buildAnswersByCourseChart(a),
        ),
        ],
        const SizedBox(height: AdminReportsTheme.sectionGap),
        _buildEmployedDetailsHeader(),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsChartGrid.twoColumn(
          left: _buildEmploymentTypeChart(a),
          right: _buildSalaryRangeChart(a),
        ),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsChartGrid.twoColumn(
          left: _buildGraduateLocationChart(a),
          right: _buildIndustryBarChart(a),
        ),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsChartGrid.twoColumn(
          left: _buildDegreeAlignmentChart(),
          right: _buildFurtherEducationChart(),
        ),
        const SizedBox(height: AdminReportsTheme.sectionGap),
        _buildChedOutcomesHeader(),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsChartGrid.twoColumn(
          left: _buildChedChoiceChart(
            title: 'Reasons not employed',
            questionId: 'ched_17',
            definition:
                'Reasons graduates gave for not being employed yet '
                '(more than one reason may be selected).',
            emptyMessage: 'No not-employed reason answers yet',
            color: Colors.orange.shade800,
            emptyIcon: Icons.person_off_outlined,
          ),
          right: _buildChedChoiceChart(
            title: 'Present employment status',
            questionId: 'ched_18',
            definition:
                'How graduates describe their current job status '
                '(for example regular, temporary, casual, contractual, '
                'or self-employed).',
            emptyMessage: 'No present employment status answers yet',
            color: Colors.indigo.shade700,
          ),
        ),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsChartGrid.twoColumn(
          left: _buildChedChoiceChart(
            title: 'Place of work',
            questionId: 'ched_21',
            definition: 'Whether graduates work locally or abroad.',
            emptyMessage: 'No place-of-work answers yet',
            color: Colors.teal.shade700,
          ),
          right: _buildChedChoiceChart(
            title: 'First job after college',
            questionId: 'ched_22',
            definition:
                'Whether the current or reported job is their first job '
                'after college.',
            emptyMessage: 'No first-job answers yet',
            color: Colors.blueGrey.shade700,
          ),
        ),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsChartGrid.twoColumn(
          left: _buildChedChoiceChart(
            title: 'Time to first job',
            questionId: 'ched_29',
            definition: 'How long it took graduates to land their first job.',
            emptyMessage: 'No time-to-first-job answers yet',
            color: Colors.deepOrange.shade700,
          ),
          right: _buildChedChoiceChart(
            title: 'Initial monthly earning',
            questionId: 'ched_31',
            definition:
                'Reported initial gross monthly earnings in the first job.',
            emptyMessage: 'No initial earning answers yet',
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: AdminReportsTheme.gutter),
        _buildChedChoiceChart(
          title: 'Curriculum relevant to first job',
          questionId: 'ched_32',
          definition:
              'Whether graduates felt their college curriculum was relevant '
              'to their first job.',
          emptyMessage: 'No curriculum-relevance answers yet',
          color: Colors.purple.shade700,
          emptyIcon: Icons.school_outlined,
        ),
      ],
    );
  }

  Widget _buildChedOutcomesHeader() {
    return const Row(
      children: [
        Icon(
          Icons.fact_check_outlined,
          size: 16,
          color: AdminReportsTheme.textMuted,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More CHED GTS outcomes',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AdminReportsTheme.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Official tracer items beyond employment status and degree alignment.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChedChoiceChart({
    required String title,
    required String questionId,
    required String definition,
    required String emptyMessage,
    required Color color,
    IconData emptyIcon = Icons.bar_chart_outlined,
  }) {
    return _distributionBarCard(
      title: title,
      details: ReportsDetailsButton.compose(
        definition: definition,
        scope: 'Submitted tracer answers within the filters you selected.',
        limitation:
            'When answers come from more than one tracer, totals are combined '
            'and may be approximate.',
      ),
      entries: _chedChoiceCounts(questionId),
      emptyMessage: emptyMessage,
      color: color,
      emptyIcon: emptyIcon,
    );
  }

  Widget _buildCompareAcrossHeader() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AdminReportsTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.compare_arrows_outlined,
            size: 17,
            color: AdminReportsTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compare across waves',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AdminReportsTheme.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Published tracers side by side, then who answered by batch and course. Tap a bar for names.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployedDetailsHeader() {
    return const Row(
      children: [
        Icon(
          Icons.work_outline,
          size: 16,
          color: AdminReportsTheme.textMuted,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Employed details',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AdminReportsTheme.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Only alumni with CHED presently employed = Yes. Not a wave comparison.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Counts non-empty field values on CHED-employed alumni employment records.
  List<MapEntry<String, int>> _employmentFieldCounts(
    AdminReportsAnalytics a,
    String? Function(EmploymentRecord r) fieldOf, {
    int limit = 8,
    bool employedOnly = false,
  }) {
    final counts = <String, int>{};
    // Detail charts must follow CHED employed status, not stale record status.
    final records = employedOnly
        ? _scopedEmployedDetailRecords(a)
        : _scopedEmploymentRecords(a);
    for (final r in records) {
      if (employedOnly &&
          _waveEmploymentSamples.isEmpty &&
          r.employmentStatus.toLowerCase() != 'employed') {
        continue;
      }
      final raw = (fieldOf(r) ?? '').trim();
      final key = raw.isEmpty ? 'Not specified' : raw;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = counts.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }

  List<MapEntry<String, int>> _industryCounts(
    List<EmploymentRecord> records, {
    int limit = 10,
  }) {
    final counts = <String, int>{};
    for (final r in records) {
      final key = (r.industry ?? '').trim().isEmpty
          ? 'Not specified'
          : r.industry!.trim();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = counts.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }

  /// Merges CHED choice % across rollups into approximate answer counts.
  List<MapEntry<String, int>> _chedChoiceCounts(String questionId) {
    final counts = <String, int>{};
    for (final rollup in _surveyRollups) {
      if (!rollup.survey.isChedGtsBuiltin) continue;
      if (_dashboardFilters.surveyId != null &&
          rollup.survey.id != _dashboardFilters.surveyId) {
        continue;
      }
      for (final agg in rollup.aggregates) {
        if (agg.questionId != questionId) continue;
        for (final e in agg.choicePercentages.entries) {
          final n = ((e.value / 100) * agg.answeredCount).round();
          if (n <= 0) continue;
          counts[e.key] = (counts[e.key] ?? 0) + n;
        }
      }
    }
    final list = counts.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    return list;
  }

  static const _noChedEmployedDetails =
      'No employed graduates in this filter yet. '
      'This chart only includes alumni who said they are currently employed.';

  Widget _buildEmploymentTypeChart(AdminReportsAnalytics a) {
    final types = _employmentFieldCounts(
      a,
      (r) => r.employmentType,
      employedOnly: true,
    );
    return _distributionBarCard(
      title: 'Employment type',
      details: ReportsDetailsButton.compose(
        definition:
            'How employed graduates describe their work arrangement '
            '(for example full-time, part-time, contract, or self-employed).',
        scope:
            'Only alumni who answered that they are currently employed, '
            'within the filters you selected.',
        limitation:
            'Drawn from each graduate’s employment details — not from the '
            'whole roster.',
      ),
      entries: types,
      emptyMessage: _noChedEmployedDetails,
      color: Colors.indigo,
    );
  }

  Widget _buildSalaryRangeChart(AdminReportsAnalytics a) {
    final ranges = _employmentFieldCounts(
      a,
      (r) => r.salaryRange,
      employedOnly: true,
      limit: 10,
    );
    return _distributionBarCard(
      title: 'Salary range',
      details: ReportsDetailsButton.compose(
        definition: 'Reported salary bands among currently employed graduates.',
        scope:
            'Only alumni who answered that they are currently employed, '
            'within the filters you selected.',
      ),
      entries: ranges,
      emptyMessage: _noChedEmployedDetails,
      color: Colors.teal.shade700,
    );
  }

  Widget _buildGraduateLocationChart(AdminReportsAnalytics a) {
    final locations = _employmentFieldCounts(
      a,
      (r) {
      final province = (r.province ?? '').trim();
      if (province.isNotEmpty) return province;
      final city = (r.city ?? '').trim();
      if (city.isNotEmpty) return city;
      return (r.country ?? '').trim();
      },
      employedOnly: true,
      limit: 8,
    );
    return _distributionBarCard(
      title: 'Graduate location',
      details: ReportsDetailsButton.compose(
        definition:
            'Where employed graduates reported working or living '
            '(province, city, or country when available).',
        scope:
            'Only alumni who answered that they are currently employed, '
            'within the filters you selected.',
      ),
      entries: locations,
      emptyMessage: _noChedEmployedDetails,
      color: Colors.brown.shade600,
    );
  }

  /// Side-by-side wave outcomes for All-tracers mode (grouped bars).
  Widget _buildWaveComparisonChart(AdminReportsAnalytics a) {
    final points = _employmentRateByWavePoints(a);
    final rows = [
      for (final p in points)
        (
          label: p.label,
          shortLabel: DateFormat('MMM d').format(p.createdAt),
          answered: p.answered,
          employed: p.employed,
          rate: p.rate,
        ),
    ];
    return _buildGroupedComparisonChart(
      title: 'By published tracer',
      details: ReportsDetailsButton.compose(
        definition:
            'Compares each published tracer: how many answered, and how many '
            'said they are employed.',
        calculation:
            'Blue bars are answers. Green bars are employed (“Yes”). '
            'The rate is employed ÷ answers. Tap a bar to see who answered.',
      ),
      rows: rows,
      emptyMessage: 'No tracer waves with employment answers yet',
      emptyIcon: Icons.compare_arrows_outlined,
      onBarTap: (i) {
        if (i < 0 || i >= points.length) return;
        unawaited(
          _openWaveRespondentsDialog(a, surveyId: points[i].surveyId),
        );
      },
    );
  }

  List<({String label, int employed, int answered, double rate})>
      _chedEmploymentGroupRates(
    AdminReportsAnalytics a, {
    required String Function(AlumniMember? member, TracerProfile? profile)
        groupOf,
  }) {
    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };

    final employed = <String, int>{};
    final answered = <String, int>{};
    final statuses = _chedLatestStatusByUser(a);

    for (final e in statuses.entries) {
      final uid = e.key;
      final member = memberByAuth[uid];
      final profile = _registeredProfiles[uid];
      final label = groupOf(member, profile).trim();
      final key = label.isEmpty ? 'Unknown' : label;
      answered[key] = (answered[key] ?? 0) + 1;
      if (e.value == ChedGtsBuiltin.yes) {
        employed[key] = (employed[key] ?? 0) + 1;
      }
    }

    final keys = answered.keys.toList()
      ..sort((x, y) => (answered[y] ?? 0).compareTo(answered[x] ?? 0));
    return [
      for (final k in keys.take(8))
        (
          label: k,
          employed: employed[k] ?? 0,
          answered: answered[k] ?? 0,
          rate: (answered[k] ?? 0) == 0
              ? 0.0
              : (employed[k] ?? 0) / answered[k]! * 100,
        ),
    ];
  }

  Widget _buildAnswersByBatchChart(AdminReportsAnalytics a) {
    final grouped = _chedEmploymentGroupRates(
      a,
      groupOf: (member, profile) {
        final memberBatch = member == null
            ? ''
            : (member.batchYear.trim().isNotEmpty
                  ? member.batchYear.trim()
                  : (member.yearGraduated ?? '').trim());
        final profileBatch = profile == null
            ? ''
            : (profile.batchYear.trim().isNotEmpty
                  ? profile.batchYear.trim()
                  : profile.yearGraduated.trim());
        return memberBatch.isNotEmpty ? memberBatch : profileBatch;
      },
    );
    final rows = [
      for (final r in grouped)
        (
          label: r.label,
          shortLabel: r.label.length > 8 ? '${r.label.substring(0, 7)}…' : r.label,
          answered: r.answered,
          employed: r.employed,
          rate: r.rate,
        ),
    ];
    return _buildGroupedComparisonChart(
      title: 'By batch',
      details: ReportsDetailsButton.compose(
        definition:
            'Employment answers grouped by batch or year graduated. '
            'When viewing all tracers, each person is counted from their latest answer.',
        calculation:
            'Blue bars are alumni who answered. Green bars are currently employed. '
            'Tap a bar to see who answered.',
      ),
      rows: rows,
      emptyMessage: 'No batch-linked tracer answers yet',
      emptyIcon: Icons.calendar_today_outlined,
      compact: true,
      onBarTap: (i) {
        if (i < 0 || i >= grouped.length) return;
        unawaited(
          _openCohortRespondentsDialog(
            a,
            groupLabel: grouped[i].label,
            groupOf: (member, profile) {
              final memberBatch = member == null
                  ? ''
                  : (member.batchYear.trim().isNotEmpty
                        ? member.batchYear.trim()
                        : (member.yearGraduated ?? '').trim());
              final profileBatch = profile == null
                  ? ''
                  : (profile.batchYear.trim().isNotEmpty
                        ? profile.batchYear.trim()
                        : profile.yearGraduated.trim());
              return memberBatch.isNotEmpty ? memberBatch : profileBatch;
            },
          ),
        );
      },
    );
  }

  Widget _buildAnswersByCourseChart(AdminReportsAnalytics a) {
    final grouped = _chedEmploymentGroupRates(
      a,
      groupOf: (member, profile) {
        if (member?.course.trim().isNotEmpty == true) return member!.course;
        return profile?.program.trim() ?? '';
      },
    );
    final rows = [
      for (final r in grouped)
        (
          label: r.label,
          shortLabel: r.label.length > 10 ? '${r.label.substring(0, 9)}…' : r.label,
          answered: r.answered,
          employed: r.employed,
          rate: r.rate,
        ),
    ];
    return _buildGroupedComparisonChart(
      title: 'By course',
      details: ReportsDetailsButton.compose(
        definition:
            'Employment answers grouped by program or course. '
            'When viewing all tracers, each person is counted from their latest answer.',
        calculation:
            'Blue bars are alumni who answered. Green bars are currently employed. '
            'Tap a bar to see who answered.',
      ),
      rows: rows,
      emptyMessage: 'No course-linked tracer answers yet',
      emptyIcon: Icons.school_outlined,
      compact: true,
      onBarTap: (i) {
        if (i < 0 || i >= grouped.length) return;
        unawaited(
          _openCohortRespondentsDialog(
            a,
            groupLabel: grouped[i].label,
            groupOf: (member, profile) {
              if (member?.course.trim().isNotEmpty == true) {
                return member!.course;
              }
              return profile?.program.trim() ?? '';
            },
          ),
        );
      },
    );
  }

  /// Grouped bars: answers (blue) vs employed (green) per category.
  Widget _buildGroupedComparisonChart({
    required String title,
    required String details,
    required List<
            ({
              String label,
              String shortLabel,
              int answered,
              int employed,
              double rate,
            })>
        rows,
    required String emptyMessage,
    IconData emptyIcon = Icons.bar_chart_outlined,
    bool compact = false,
    ValueChanged<int>? onBarTap,
  }) {
    if (rows.isEmpty) {
      return _chartCard(
        title: title,
        details: details,
        height: ReportsChartHeights.standard,
        child: ReportsChartEmptyState(message: emptyMessage, icon: emptyIcon),
      );
    }

    final maxY = rows
        .map((r) => r.answered)
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble()
        .clamp(1, double.infinity);
    final totalAnswered = rows.fold<int>(0, (s, r) => s + r.answered);

    return _chartCard(
      title: title,
      details: details,
      height: compact ? ReportsChartHeights.standard : ReportsChartHeights.hero,
      hero: !compact,
      child: Column(
        children: [
          ReportsSmallNBanner(
            n: totalAnswered,
            noun: 'answers across categories',
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.25,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchCallback: (event, response) {
                    if (onBarTap == null) return;
                    // Prefer tap-down so the spot is still present (esp. on web).
                    if (event is! FlTapDownEvent) return;
                    final spot = response?.spot;
                    if (spot == null) return;
                    onBarTap(spot.touchedBarGroupIndex);
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < 0 || groupIndex >= rows.length) {
                        return null;
                      }
                      final r = rows[groupIndex];
                      final series = rodIndex == 0 ? 'Answers' : 'Employed';
                      final value = rodIndex == 0 ? r.answered : r.employed;
                      return BarTooltipItem(
                        '${r.label}\n'
                        '$series: $value\n'
                        'Rate: ${r.rate.toStringAsFixed(0)}%'
                        '${onBarTap == null ? '' : '\nTap to list respondents'}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: compact ? 28 : 36,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= rows.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            rows[i].shortLabel,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AdminReportsTheme.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AdminReportsTheme.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AdminReportsTheme.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < rows.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: rows[i].answered.toDouble(),
                          color: Colors.blue.shade700,
                          width: compact ? 10 : 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: rows[i].employed.toDouble(),
                          color: Colors.green.shade600,
                          width: compact ? 10 : 12,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              swapAnimationDuration: Duration.zero,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _legendItem(Colors.blue.shade700, 'Answers'),
              _legendItem(Colors.green.shade600, 'Employed'),
              Text(
                rows.length == 1
                    ? '1 category — tap the bar to list respondents'
                    : onBarTap == null
                        ? '${rows.length} categories compared'
                        : '${rows.length} categories · tap a bar for names',
                style: const TextStyle(
                  fontSize: 11,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDegreeAlignmentChart() {
    final entries = _chedChoiceCounts('ched_24a');
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final details = ReportsDetailsButton.compose(
      definition:
          'Whether the graduate’s first job relates to their degree.',
      scope: 'Submitted tracer answers within the filters you selected.',
    );
    return _chartCard(
      title: 'Degree alignment',
      details: details,
      height: total > 0 && total < _chartMinUsefulN
          ? null
          : ReportsChartHeights.standard,
      child: total == 0
          ? const ReportsChartEmptyState(
              message: 'No degree-alignment responses yet',
              icon: Icons.school_outlined,
            )
          : total < _chartMinUsefulN
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReportsSmallNBanner(n: total, noun: 'answers'),
                    ReportsRankedSummary(
                      entries: entries,
                      totalLabel: 'answers',
                      accent: Colors.green,
                    ),
                  ],
            )
          : _pieWithCenter(
              total: total,
              centerLabel: 'Answers',
              sections: [
                for (final e in entries)
                  _PieSlice(
                    e.key,
                    e.value,
                    e.key.toLowerCase() == 'yes'
                        ? Colors.green
                        : e.key.toLowerCase() == 'no'
                        ? Colors.orange
                        : Colors.blueGrey,
                  ),
              ],
            ),
    );
  }

  Widget _buildFurtherEducationChart() {
    final entries = _chedChoiceCounts('ched_15b');
    return _distributionBarCard(
      title: 'Further studies',
      details: ReportsDetailsButton.compose(
        definition: 'Reasons graduates gave for pursuing further studies.',
        scope: 'Submitted tracer answers within the filters you selected.',
      ),
      entries: entries,
      emptyMessage: 'No further-studies responses yet',
      color: Colors.deepPurple,
      emptyIcon: Icons.menu_book_outlined,
    );
  }

  Widget _distributionBarCard({
    required String title,
    String? details,
    required List<MapEntry<String, int>> entries,
    required String emptyMessage,
    required Color color,
    IconData emptyIcon = Icons.bar_chart_outlined,
  }) {
    if (entries.isEmpty || entries.every((e) => e.value == 0)) {
      return _chartCard(
        title: title,
        details: details,
        height: ReportsChartHeights.standard,
        child: ReportsChartEmptyState(
          message: emptyMessage,
          icon: emptyIcon,
        ),
      );
    }

    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total < _chartMinUsefulN) {
      return _chartCard(
        title: title,
        details: details,
        height: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReportsSmallNBanner(n: total, noun: 'responses'),
            ReportsRankedSummary(
              entries: entries,
              totalLabel: 'responses',
              accent: color,
            ),
          ],
        ),
      );
    }

    final maxY = entries.map((e) => e.value).reduce((x, y) => x > y ? x : y);

    return _chartCard(
      title: title,
      details: details,
      height: ReportsChartHeights.standard,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY + 2.0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final label = entries[i].key;
                  final short = label.length > 10
                      ? '${label.substring(0, 8)}…'
                      : label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      short,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    color: color,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        swapAnimationDuration: Duration.zero,
      ),
    );
  }

  // —— Phase 6: Participation analytics ——

  /// Non-archived surveys with assignments (respects the survey filter).
  List<Survey> _participationSurveys(AdminReportsAnalytics a) {
    final surveyId = _dashboardFilters.surveyId;
    final list =
        a.surveys
            .where(
              (s) =>
                  !s.archived &&
                  a.assignmentCount(s) > 0 &&
                  (surveyId == null || s.id == surveyId),
            )
            .toList()
          ..sort((x, y) {
            final xr = a.submittedResponseCount(x) / a.assignmentCount(x);
            final yr = a.submittedResponseCount(y) / a.assignmentCount(y);
            return yr.compareTo(xr);
          });
    return list;
  }

  Widget _buildParticipationFunnel({
    required int assigned,
    required int submitted,
    required int pending,
    required double responseRate,
    required double dropOff,
  }) {
    return ReportsHoverSurface(
      borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
      semanticLabel:
          'Response funnel: $assigned assigned, $submitted submitted, '
          '$pending pending',
      child: Container(
        padding: const EdgeInsets.all(AdminReportsTheme.space3),
        decoration: BoxDecoration(
          color: AdminReportsTheme.surface,
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(color: AdminReportsTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _funnelStat(
                    'Assigned',
                    assigned.toString(),
                    Icons.assignment_outlined,
                    Colors.indigo,
                    tooltip:
                        'Active survey assignments across non-archived '
                        'surveys.',
                  ),
                ),
                const _FunnelArrow(),
                Expanded(
                  child: _funnelStat(
                    'Submitted',
                    submitted.toString(),
                    Icons.task_alt,
                    Colors.green,
                    sub: '${(responseRate * 100).toStringAsFixed(0)}% response',
                    tooltip:
                        'Submitted responses ÷ assignments = response rate.',
                  ),
                ),
                const _FunnelArrow(),
                Expanded(
                  child: _funnelStat(
                    'Pending',
                    pending.toString(),
                    Icons.hourglass_empty,
                    Colors.orange,
                    sub: '${(dropOff * 100).toStringAsFixed(0)}% drop-off',
                    tooltip: 'Assignments without a submitted response yet.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    Expanded(
                      flex: (responseRate * 1000).round().clamp(0, 1000),
                      child: Container(color: Colors.green),
                    ),
                    Expanded(
                      flex: (dropOff * 1000).round().clamp(0, 1000),
                      child: Container(color: Colors.orange.shade300),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.green, 'Submitted'),
                const SizedBox(width: 16),
                _legendItem(Colors.orange.shade300, 'Pending / drop-off'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _funnelStat(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? sub,
    String? tooltip,
  }) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AdminReportsTheme.textPrimary,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AdminReportsTheme.textSecondary,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
    if (tooltip == null) return column;
    return Tooltip(message: tooltip, child: column);
  }

  Widget _buildParticipationBySurveyChart(AdminReportsAnalytics a) {
    final list = _participationSurveys(a).take(8).toList();
    if (list.isEmpty) {
      return _chartCard(
        title: 'Participation by survey',
        details: ReportsDetailsButton.compose(
          definition: 'Completion rate per published survey wave.',
          limitation: 'Amber bars mark waves under 40% response.',
        ),
        height: ReportsChartHeights.hero,
        hero: true,
        child: const ReportsChartEmptyState(
          message: 'No survey assignment data yet',
          icon: Icons.how_to_vote_outlined,
        ),
      );
    }

    double rateOf(Survey s) => a.assignmentCount(s) == 0
        ? 0
        : a.submittedResponseCount(s) / a.assignmentCount(s);

    return _chartCard(
      title: 'Participation by survey',
      details: ReportsDetailsButton.compose(
        definition: 'Completion rate per published survey wave.',
        limitation: 'Amber bars mark waves under 40% response.',
      ),
      height: ReportsChartHeights.hero,
      hero: true,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= list.length) {
                    return const SizedBox.shrink();
                  }
                  final title = list[i].title;
                  final short = title.length > 12
                      ? '${title.substring(0, 10)}…'
                      : title;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      short,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  '${(value * 100).toInt()}%',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < list.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: rateOf(list[i]),
                    color: rateOf(list[i]) < 0.4
                        ? AdminReportsTheme.warning
                        : _navy,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        swapAnimationDuration: Duration.zero,
      ),
    );
  }

  Widget _buildLowResponseList(AdminReportsAnalytics a) {
    final low = _participationSurveys(a).where((s) {
      final rate = a.submittedResponseCount(s) / a.assignmentCount(s);
      return rate < 0.4;
    }).toList();

    if (low.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AdminReportsTheme.space2),
        decoration: BoxDecoration(
          color: AdminReportsTheme.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(
            color: AdminReportsTheme.success.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: const [
            Icon(
              Icons.check_circle_outline,
              color: AdminReportsTheme.success,
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No low-response surveys — all active waves are at or above 40% '
                'completion.',
                style: TextStyle(
                  fontSize: 13,
                  color: AdminReportsTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AdminReportsTheme.space2),
      decoration: BoxDecoration(
        color: AdminReportsTheme.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(
          color: AdminReportsTheme.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.priority_high_rounded,
                color: AdminReportsTheme.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Needs follow-up · ${low.length} low-response survey(s)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminReportsTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final s in low.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AdminReportsTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${a.submittedResponseCount(s)}/${a.assignmentCount(s)} · '
                    '${(a.submittedResponseCount(s) / a.assignmentCount(s) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminReportsTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // —— Phase 7: Course analytics ——

  /// Per-course roster + outcome stats, linked through registered members.
  ///
  /// Employment figures reuse [AdminReportsAnalytics.reportEmploymentRecords]
  /// (deduped, roster-linked) — no new formulas, just a per-course split.
  List<_CourseStat> _courseStats(AdminReportsAnalytics a) {
    final byCourse = <String, List<AlumniMember>>{};
    final uidCourse = <String, String>{};
    final sidCourse = <String, String>{};
    for (final m in a.activeRoster) {
      final course = m.course.trim().isEmpty ? 'Unknown' : m.course.trim();
      byCourse.putIfAbsent(course, () => []).add(m);
      final uid = (m.authUid ?? '').trim();
      if (uid.isNotEmpty) uidCourse[uid] = course;
      final sid = AlumniMemberService.normalizeStudentId(m.studentId);
      if (sid.isNotEmpty) sidCourse[sid] = course;
    }

    final submissions = <String, int>{};
    final employed = <String, int>{};
    for (final r in _scopedEmploymentRecords(a)) {
      final uid = r.userId.trim();
      var course = uid.isNotEmpty ? uidCourse[uid] : null;
      course ??= sidCourse[AlumniMemberService.normalizeStudentId(r.schoolId)];
      if (course == null) continue;
      submissions[course] = (submissions[course] ?? 0) + 1;
      if (r.employmentStatus.toLowerCase() == 'employed') {
        employed[course] = (employed[course] ?? 0) + 1;
      }
    }

    final stats = [
      for (final e in byCourse.entries)
        _CourseStat(
          course: e.key,
          total: e.value.length,
          registered: e.value.where((m) => m.isRegisteredUser).length,
          tracerComplete: e.value.where((m) => m.tracerProfileComplete).length,
          employmentSubmissions: submissions[e.key] ?? 0,
          employed: employed[e.key] ?? 0,
        ),
    ]..sort((x, y) => y.total.compareTo(x.total));
    return stats;
  }

  Widget _buildCourseComparisonTable(AdminReportsAnalytics a) {
    final stats = _courseStats(a);
    if (stats.isEmpty) {
      return const ReportsChartEmptyState(
        message: 'No roster data yet — import alumni to compare courses',
        icon: Icons.menu_book_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) _courseTableHeader(),
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0 || wide) const SizedBox(height: 8),
              _courseRow(stats[i], wide),
            ],
            const SizedBox(height: 10),
            const Text(
              'Employment rate counts employed tracer submitters per course. '
              'Courses without submissions show “—”.',
              style: TextStyle(
                fontSize: 11.5,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _courseTableHeader() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AdminReportsTheme.textSecondary,
      letterSpacing: 0.4,
    );

    Widget head(int flex, String label, String tooltip) => Expanded(
      flex: flex,
      child: Tooltip(
        message: tooltip,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: style),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          head(3, 'COURSE', 'Course recorded on the alumni roster.'),
          head(2, 'ALUMNI', 'Active roster entries for this course.'),
          head(3, 'REGISTERED', 'Portal accounts ÷ roster entries.'),
          head(
            3,
            'TRACER COMPLETE',
            'Complete tracer profiles ÷ registered members.',
          ),
          head(
            3,
            'EMPLOYMENT RATE',
            'Employed ÷ tracer submitters for this course.',
          ),
        ],
      ),
    );
  }

  Widget _courseRow(_CourseStat s, bool wide) {
    return ReportsHoverSurface(
      borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
      semanticLabel:
          '${s.course}: ${s.total} alumni, '
          '${s.registered} registered, ${s.tracerComplete} tracer complete',
      child: _courseRowBody(s, wide),
    );
  }

  Widget _courseRowBody(_CourseStat s, bool wide) {
    final card = BoxDecoration(
      color: AdminReportsTheme.surface,
      borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
      border: Border.all(color: AdminReportsTheme.border),
    );

    if (!wide) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.course,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AdminReportsTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${s.total} alumni',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminReportsTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _courseStatBar(
              'Registered',
              s.registrationRate,
              '${s.registered}/${s.total}',
              _navy,
            ),
            const SizedBox(height: 8),
            _courseStatBar(
              'Tracer complete',
              s.tracerRate,
              '${s.tracerComplete}/${s.registered}',
              Colors.teal,
              showDash: s.registered == 0,
            ),
            const SizedBox(height: 8),
            _courseStatBar(
              'Employment',
              s.employmentRate,
              '${s.employed}/${s.employmentSubmissions}',
              Colors.green,
              showDash: s.employmentSubmissions == 0,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: card,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              s.course,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminReportsTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              s.total.toString(),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AdminReportsTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _courseStatBar(
                null,
                s.registrationRate,
                '${s.registered}/${s.total}',
                _navy,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _courseStatBar(
                null,
                s.tracerRate,
                '${s.tracerComplete}/${s.registered}',
                Colors.teal,
                showDash: s.registered == 0,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _courseStatBar(
              null,
              s.employmentRate,
              '${s.employed}/${s.employmentSubmissions}',
              Colors.green,
              showDash: s.employmentSubmissions == 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _courseStatBar(
    String? label,
    double rate,
    String counts,
    Color color, {
    bool showDash = false,
  }) {
    final percentText = showDash ? '—' : '${(rate * 100).toStringAsFixed(0)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (label != null) ...[
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminReportsTheme.textSecondary,
                  ),
                ),
              ),
            ],
            Text(
              percentText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: showDash ? AdminReportsTheme.textMuted : color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              showDash ? 'no data' : counts,
              style: const TextStyle(
                fontSize: 11,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: showDash ? 0 : rate.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AdminReportsTheme.border.withValues(alpha: 0.6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRosterCharts(AdminReportsAnalytics a, bool wide) {
    if (_isRefreshing) {
      return ReportsChartGrid.heroSide(
        hero: const ReportsChartSkeleton(height: ReportsChartHeights.hero),
        side: const ReportsChartSkeleton(height: ReportsChartHeights.hero),
      );
    }
    return ReportsChartGrid.heroSide(
      hero: _buildBatchBarChart(a),
      side: _buildCoursePieChart(a),
    );
  }

  Widget _buildMetricsGrid(List<_Metric> metrics) {
    if (_isRefreshing) {
      return ReportsResponsiveGrid(
        itemCount: metrics.isEmpty ? 4 : metrics.length,
        maxColumns: 4,
        minItemWidth: 240,
        itemBuilder: (context, i) => const ReportsKpiCardSkeleton(),
      );
    }
    return ReportsResponsiveGrid(
      itemCount: metrics.length,
      maxColumns: 4,
      minItemWidth: 240,
      itemBuilder: (context, i) => _buildSummaryCard(metrics[i]),
    );
  }

  Widget _buildSummaryCard(_Metric metric) {
    return ReportsKpiCard(
      label: metric.label,
      value: metric.value,
      icon: metric.icon,
      color: metric.color,
      comparisonLabel: metric.comparisonLabel,
      details: metric.details,
      status: metric.status,
      statusLabel: metric.statusLabel,
    );
  }

  /// Prefer a ranked summary when the sample is too small for a useful chart.
  static const _chartMinUsefulN = 5;

  Widget _chartCard({
    required String title,
    String? subtitle,
    String? details,
    required double? height,
    required Widget child,
    bool hero = false,
  }) {
    return ReportsHoverSurface(
      semanticLabel: '$title chart',
      child: ReportsChartSurface(
        title: title,
        subtitle: subtitle,
        details: details,
        height: height,
        hero: hero,
        child: RepaintBoundary(child: child),
      ),
    );
  }

  Widget _buildBatchBarChart(AdminReportsAnalytics a) {
    final batches = a.topBatchYears(limit: 8);
    if (batches.isEmpty) {
      return _chartCard(
        title: 'Roster by batch year',
        details: ReportsDetailsButton.compose(
          definition: 'Alumni on the active roster grouped by batch year.',
        ),
        height: ReportsChartHeights.hero,
        hero: true,
        child: const ReportsChartEmptyState(
          message: 'No roster data yet',
          icon: Icons.groups_outlined,
        ),
      );
    }

    final maxY = batches.map((e) => e.value).reduce((x, y) => x > y ? x : y);

    return _chartCard(
      title: 'Roster by batch year',
      details: ReportsDetailsButton.compose(
        definition: 'Alumni on the active roster grouped by batch year.',
      ),
      height: ReportsChartHeights.hero,
      hero: true,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY + 4.0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= batches.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      batches[i].key,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < batches.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: batches[i].value.toDouble(),
                    color: _navy,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        swapAnimationDuration: Duration.zero,
      ),
    );
  }

  Widget _buildCoursePieChart(AdminReportsAnalytics a) {
    final courses = a.topCourses();
    final details = ReportsDetailsButton.compose(
      definition: 'Alumni on the active roster grouped by program or course.',
    );
    if (courses.isEmpty) {
      return _chartCard(
        title: 'Roster by course',
        details: details,
        height: ReportsChartHeights.hero,
        child: const ReportsChartEmptyState(
          message: 'No roster data yet',
          icon: Icons.school_outlined,
        ),
      );
    }

    final colors = [
      _navy,
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.brown,
    ];
    final total = courses.fold<int>(0, (s, e) => s + e.value);

    if (total < _chartMinUsefulN) {
    return _chartCard(
      title: 'Roster by course',
        details: details,
        height: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReportsSmallNBanner(n: total, noun: 'alumni'),
            ReportsRankedSummary(
              entries: courses,
              totalLabel: 'alumni',
              accent: _navy,
            ),
          ],
        ),
      );
    }

    return _chartCard(
      title: 'Roster by course',
      details: details,
      height: ReportsChartHeights.hero,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 44,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  for (var i = 0; i < courses.length; i++)
                    PieChartSectionData(
                      color: colors[i % colors.length],
                      value: courses[i].value.toDouble(),
                      title:
                          '${(courses[i].value / total * 100).toStringAsFixed(0)}%',
                      radius: 36,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              swapAnimationDuration: Duration.zero,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              for (var i = 0; i < courses.length; i++)
                _legendItem(
                  colors[i % colors.length],
                  '${courses[i].key} (${courses[i].value})',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentPieChart(AdminReportsAnalytics a) {
    final ched = _chedEmploymentStatusCounts(a);
    final waveScoped = _dashboardFilters.surveyId != null;
    final int employed;
    final int unemployed;
    final String details;
    final String emptyMessage;
    final String centerLabel;
    final String totalLabel;

    if (ched != null) {
      employed = ched.employed;
      unemployed = ched.notEmployed;
      centerLabel = 'Alumni';
      totalLabel = 'alumni';
      emptyMessage = waveScoped
          ? 'No presently-employed answers on this tracer wave yet'
          : 'No presently-employed answers across tracer waves yet';
      details = ReportsDetailsButton.compose(
        definition: waveScoped
            ? 'Share of graduates on this tracer who said they are currently employed.'
            : 'Share of graduates who said they are currently employed. '
                'If someone answered more than one tracer, only their latest '
                'answer is counted.',
        calculation:
            'Employed means “Yes”. Not employed means “No” or “Never employed”.',
        scope: _dashboardFilters.scopeLabel(
          surveys: _surveys,
          responseOrRecordCount: ched.answered,
          countNoun: ched.waveCount <= 1
              ? 'employment answers'
              : 'alumni across ${ched.waveCount} tracer waves',
        ),
        limitation:
            'Based on tracer survey answers. The employment rate by wave '
            'chart still shows each tracer separately.',
      );
    } else {
      employed = a.employedCount;
      unemployed = a.unemployedCount;
      centerLabel = 'Alumni';
      totalLabel = 'alumni';
      emptyMessage = 'No employment submissions yet';
      details = ReportsDetailsButton.compose(
        definition:
            'Employed versus not employed among alumni who submitted '
            'employment information.',
        calculation: AdminReportsAnalytics.employmentRateDefinition,
        scope:
            'Uses employment submissions on file while tracer answers load.',
      );
    }

    final total = employed + unemployed;
    final entries = <MapEntry<String, int>>[
      MapEntry('Employed', employed),
      MapEntry('Not employed', unemployed),
    ].where((e) => e.value > 0).toList();

    return _chartCard(
      title: 'Employment status',
      details: details,
      height: total > 0 && total < _chartMinUsefulN
          ? null
          : ReportsChartHeights.standard,
      child: total == 0
          ? ReportsChartEmptyState(
              message: emptyMessage,
              icon: Icons.work_outline,
            )
          : total < _chartMinUsefulN
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReportsSmallNBanner(n: total, noun: totalLabel),
                    ReportsRankedSummary(
                      entries: entries,
                      totalLabel: totalLabel,
                      accent: Colors.green,
                    ),
                  ],
            )
          : _pieWithCenter(
              total: total,
                  centerLabel: centerLabel,
              sections: [
                _PieSlice('Employed', employed, Colors.green),
                    _PieSlice('Not employed', unemployed, Colors.orange),
              ],
            ),
    );
  }

  Widget _buildIndustryBarChart(AdminReportsAnalytics a) {
    final industries = _industryCounts(_scopedEmployedDetailRecords(a), limit: 10);
    final industryDetailsText = ReportsDetailsButton.compose(
      definition:
          'Top industries or sectors reported by currently employed graduates.',
      scope:
          'Only alumni who answered that they are currently employed, '
          'within the filters you selected.',
    );
    if (industries.isEmpty) {
      return _chartCard(
        title: 'Industry (employed)',
        details: industryDetailsText,
        height: ReportsChartHeights.standard,
        child: const ReportsChartEmptyState(
          message: _noChedEmployedDetails,
          icon: Icons.factory_outlined,
        ),
      );
    }

    final total = industries.fold<int>(0, (s, e) => s + e.value);
    if (total < _chartMinUsefulN) {
      return _chartCard(
        title: 'Industry (employed)',
        details: industryDetailsText,
        height: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReportsSmallNBanner(n: total, noun: 'alumni'),
            ReportsRankedSummary(
              entries: industries,
              totalLabel: 'alumni',
              accent: Colors.blueGrey,
            ),
          ],
        ),
      );
    }

    final maxY = industries.map((e) => e.value).reduce((x, y) => x > y ? x : y);

    return _chartCard(
      title: 'Industry (employed)',
      details: industryDetailsText,
      height: ReportsChartHeights.standard,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY + 2.0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= industries.length) {
                    return const SizedBox.shrink();
                  }
                  final label = industries[i].key;
                  final short = label.length > 10
                      ? '${label.substring(0, 8)}â€¦'
                      : label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      short,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < industries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: industries[i].value.toDouble(),
                    color: Colors.teal.shade600,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
        swapAnimationDuration: Duration.zero,
      ),
    );
  }

  Widget _pieWithCenter({
    required int total,
    required String centerLabel,
    required List<_PieSlice> sections,
  }) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final s in sections)
                      if (s.value > 0)
                        PieChartSectionData(
                          color: s.color,
                          value: s.value.toDouble(),
                          title: total == 0
                              ? ''
                              : '${(s.value / total * 100).toStringAsFixed(0)}%',
                          radius: 38,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ],
                ),
                swapAnimationDuration: Duration.zero,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  Text(
                    centerLabel,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final s in sections)
              if (s.value > 0) _legendItem(s.color, '${s.label}: ${s.value}'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  String _displayNameForUid(AdminReportsAnalytics a, String uid) {
    final key = uid.trim();
    for (final m in a.activeRoster) {
      if (m.authUid?.trim() == key && m.fullName.trim().isNotEmpty) {
        return m.fullName.trim();
      }
    }
    final profile = _registeredProfiles[key];
    if (profile != null && profile.displayName.trim().isNotEmpty) {
      return profile.displayName.trim();
    }
    if (key.length <= 8) return 'Alumni $key';
    return 'Alumni ${key.substring(0, 8)}…';
  }

  Future<void> _openWaveRespondentsDialog(
    AdminReportsAnalytics a, {
    required String surveyId,
  }) async {
    _TracerWaveEmploymentSample? sample;
    for (final s in _waveEmploymentSamples) {
      if (s.survey.id == surveyId) {
        sample = s;
        break;
      }
    }
    if (sample == null) {
      await _ensureSelectedWaveSample(surveyId);
      for (final s in _waveEmploymentSamples) {
        if (s.survey.id == surveyId) {
          sample = s;
          break;
        }
      }
    }
    if (!mounted) return;

    final batch = _dashboardFilters.batchYear?.trim().toLowerCase();
    final course = _dashboardFilters.course?.trim().toLowerCase();
    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };

    final rows = <TracerRespondentRow>[];
    if (sample != null) {
      for (final ans in sample.answers) {
        final uid = ans.userId.trim();
        if (uid.isEmpty) continue;
        if (!_respondentMatchesCohort(
          userId: uid,
          batch: batch,
          course: course,
          memberByAuth: memberByAuth,
        )) {
          continue;
        }
        final status = ans.presentlyEmployed;
        if (status == null || status.isEmpty) continue;
        rows.add(
          TracerRespondentRow(
            userId: uid,
            displayName: _displayNameForUid(a, uid),
            subtitle: ans.submittedAt == null
                ? null
                : 'Submitted ${DateFormat.yMMMd().format(ans.submittedAt!)}',
            status: status,
          ),
        );
      }
    }
    rows.sort(
      (x, y) => x.displayName.toLowerCase().compareTo(y.displayName.toLowerCase()),
    );

    final title = sample?.survey.title.trim().isNotEmpty == true
        ? sample!.survey.title.trim()
        : 'Tracer wave';
    await showTracerRespondentsDialog(
      context: context,
      title: title,
      subtitle:
          '${rows.length} respondent${rows.length == 1 ? '' : 's'} · CHED presently employed',
      rows: rows,
    );
  }

  Future<void> _openCohortRespondentsDialog(
    AdminReportsAnalytics a, {
    required String groupLabel,
    required String Function(AlumniMember? member, TracerProfile? profile)
        groupOf,
  }) async {
    final statuses = _chedLatestStatusByUser(a);
    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };
    final want = groupLabel.trim().isEmpty ? 'Unknown' : groupLabel.trim();
    final rows = <TracerRespondentRow>[];
    for (final e in statuses.entries) {
      final uid = e.key;
      final member = memberByAuth[uid];
      final profile = _registeredProfiles[uid];
      final label = groupOf(member, profile).trim();
      final key = label.isEmpty ? 'Unknown' : label;
      if (key != want) continue;
      rows.add(
        TracerRespondentRow(
          userId: uid,
          displayName: _displayNameForUid(a, uid),
          subtitle: key,
          status: e.value,
        ),
      );
    }
    rows.sort(
      (x, y) => x.displayName.toLowerCase().compareTo(y.displayName.toLowerCase()),
    );
    await showTracerRespondentsDialog(
      context: context,
      title: want,
      subtitle:
          '${rows.length} alumni · latest wave employment status in filter',
      rows: rows,
    );
  }

  List<TracerLongitudinalRow> _longitudinalRows(AdminReportsAnalytics a) {
    final batch = _dashboardFilters.batchYear?.trim().toLowerCase();
    final course = _dashboardFilters.course?.trim().toLowerCase();
    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };

    final byUser = <String, List<TracerWaveStatusPoint>>{};
    final samples = [..._waveEmploymentSamples]..sort(
        (x, y) => reportsSurveyDisplayDate(x.survey).compareTo(
          reportsSurveyDisplayDate(y.survey),
        ),
      );

    for (final sample in samples) {
      final waveDate = reportsSurveyDisplayDate(sample.survey);
      final waveLabel = sample.survey.title.trim().isEmpty
          ? DateFormat.yMMMd().format(waveDate)
          : sample.survey.title.trim();
      for (final ans in sample.answers) {
        final uid = ans.userId.trim();
        if (uid.isEmpty) continue;
        if (!_respondentMatchesCohort(
          userId: uid,
          batch: batch,
          course: course,
          memberByAuth: memberByAuth,
        )) {
          continue;
        }
        final status = ans.presentlyEmployed;
        if (status == null || status.isEmpty) continue;
        byUser.putIfAbsent(uid, () => <TracerWaveStatusPoint>[]).add(
              TracerWaveStatusPoint(
                waveLabel: waveLabel,
                waveDate: waveDate,
                status: status,
              ),
            );
      }
    }

    final rows = <TracerLongitudinalRow>[
      for (final e in byUser.entries)
        if (e.value.length >= 2)
          TracerLongitudinalRow(
            userId: e.key,
            displayName: _displayNameForUid(a, e.key),
            points: e.value,
          ),
    ]..sort(
        (x, y) => x.displayName.toLowerCase().compareTo(y.displayName.toLowerCase()),
      );
    return rows;
  }

  /// One-click export of the currently filtered Tracer analytics view.
  Future<void> _exportTracerFilteredView(
    AdminReportsAnalytics a, {
    required CustomReportFormat format,
  }) async {
    final waveScoped = _dashboardFilters.surveyId != null;
    final title = waveScoped
        ? 'Tracer filtered view'
        : 'Tracer comparison (filtered)';
    final preset = ReportsDownloadPreset(
      id: 'tracer_view',
      title: title,
      description: 'Export of the current Tracer tab filters.',
      icon: Icons.filter_alt_outlined,
      sections: const [
        CustomReportSectionId.executiveKpis,
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.surveyQuestions,
        CustomReportSectionId.employmentRecords,
      ],
    );
    await _downloadPreset(
      a,
      preset,
      format: format,
      printPreview: false,
    );
  }

  Future<void> _downloadPreset(
    AdminReportsAnalytics a,
    ReportsDownloadPreset preset, {
    required CustomReportFormat format,
    required bool printPreview,
  }) async {
    if (!printPreview && !requireWebExport(context)) return;

    if (preset.needsWavePicker || preset.id == 'ched_wave_compare') {
      await _downloadChedWaveComparison(
        a,
        format: format,
        printPreview: printPreview,
      );
      return;
    }

    setState(() => _downloadBusy = true);
    try {
      final needsRollups = preset.sections.contains(
            CustomReportSectionId.surveyQuestions,
          ) ||
          preset.sections.contains(CustomReportSectionId.surveyParticipation);
      if (needsRollups) {
        await _ensureSurveyRollupsLoaded();
      }
      if (!mounted) return;

      final now = DateTime.now();
      final template = CustomReportTemplate(
        id: 'preset_${preset.id}',
        name: preset.title,
        sections: List.of(preset.sections),
        format: format,
        filters: CustomReportFilters(
          batchYears: [
            if (_dashboardFilters.batchYear != null)
              _dashboardFilters.batchYear!,
          ],
          courses: [
            if (_dashboardFilters.course != null) _dashboardFilters.course!,
          ],
        ),
        createdAt: now,
        updatedAt: now,
      );

      final doc = CustomReportExportService.buildDocument(
        template: template,
      analytics: a,
      events: _allEvents,
      jobs: _jobs,
      rollups: _surveyRollups,
        profilesByAuthUid: _registeredProfiles,
      );

      if (printPreview) {
        final bytes = await CustomReportExportService.toPdf(doc);
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: doc.title);
        return;
      }

      final bytes = await CustomReportExportService.exportBytes(
        doc: doc,
        format: format,
      );
      if (!mounted) return;
      final ok = tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName:
            '${preset.id}_${DateFormat('yyyyMMdd').format(now)}.${format.fileExtension}',
        mimeType: format.mimeType,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded ${preset.title} (${format.label}).')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloadBusy = false);
    }
  }

  Future<void> _downloadChedWaveComparison(
    AdminReportsAnalytics a, {
    required CustomReportFormat format,
    required bool printPreview,
  }) async {
    final chedWaves = a.surveys
        .where(
          (s) =>
              !s.archived &&
              s.isChedGtsBuiltin &&
              (s.status == SurveyStatus.published ||
                  s.status == SurveyStatus.closed) &&
              a.submittedResponseCount(s) > 0,
        )
        .toList();

    final selection = await showChedWaveComparisonDialog(
      context: context,
      chedWaves: chedWaves,
      batchYears: reportsFilterBatchOptions(a.members),
      initialBatchYear: _dashboardFilters.batchYear,
      initialCourse: _dashboardFilters.course,
    );
    if (selection == null || !mounted) return;
    if (selection.surveys.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least two Official CHED GTS waves.'),
        ),
      );
      return;
    }

    setState(() => _downloadBusy = true);
    try {
      final batch = selection.batchYear?.trim().toLowerCase();
      final course = selection.course?.trim().toLowerCase();
      final memberByAuth = <String, AlumniMember>{
        for (final m in a.activeRoster)
          if (m.authUid != null && m.authUid!.trim().isNotEmpty)
            m.authUid!.trim(): m,
      };

      final responsesBySurveyId = <String, List<SurveyResponse>>{};
      for (final survey in selection.surveys) {
        final responses = await _surveyService.getSurveyResponses(survey.id);
        final submitted = responses
            .where((r) => r.status == SurveyResponseStatus.submitted)
            .where(
              (r) => _respondentMatchesCohort(
                userId: r.userId,
                batch: batch,
                course: course,
                memberByAuth: memberByAuth,
              ),
            )
            .toList(growable: false);
        responsesBySurveyId[survey.id] = submitted;
    }
    if (!mounted) return;

      final report = ChedWaveComparisonReport.build(
        selectedSurveys: selection.surveys,
        responsesBySurveyId: responsesBySurveyId,
        batchFilter: selection.batchYear,
        courseFilter: selection.course,
      );
      final doc =
          CustomReportExportService.buildChedWaveComparisonDocument(report);
      final now = DateTime.now();

    if (printPreview) {
      final bytes = await CustomReportExportService.toPdf(doc);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: doc.title);
      return;
    }

    final bytes = await CustomReportExportService.exportBytes(
      doc: doc,
        format: format,
    );
    if (!mounted) return;
    final ok = tryDownloadBytesOnWeb(
      context,
      bytes: bytes,
        fileName:
            'ched_wave_compare_${DateFormat('yyyyMMdd').format(now)}.${format.fileExtension}',
        mimeType: format.mimeType,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded CHED wave comparison (${format.label}).',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloadBusy = false);
    }
  }
}

class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
}

/// Per-course roster + outcome stats for the course comparison table.
class _CourseStat {
  const _CourseStat({
    required this.course,
    required this.total,
    required this.registered,
    required this.tracerComplete,
    required this.employmentSubmissions,
    required this.employed,
  });

  final String course;
  final int total;
  final int registered;
  final int tracerComplete;
  final int employmentSubmissions;
  final int employed;

  double get registrationRate => total == 0 ? 0 : registered / total;
  double get tracerRate => registered == 0 ? 0 : tracerComplete / registered;
  double get employmentRate =>
      employmentSubmissions == 0 ? 0 : employed / employmentSubmissions;
}

/// Small arrow separating the participation funnel stages.
class _FunnelArrow extends StatelessWidget {
  const _FunnelArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right,
        size: 18,
        color: AdminReportsTheme.textMuted,
      ),
    );
  }
}

/// Pins the section navigation bar below the header while the dashboard scrolls.
class _SectionNavDelegate extends SliverPersistentHeaderDelegate {
  _SectionNavDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: AdminReportsTheme.background,
        child: Center(child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionNavDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.comparisonLabel,
    this.details,
    this.status,
    this.statusLabel,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? comparisonLabel;
  final String? details;
  final ReportsKpiStatus? status;
  final String? statusLabel;
}


class _PieSlice {
  const _PieSlice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _LineSeries {
  const _LineSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<double> values;
}

class _TracerWaveEmploymentSample {
  const _TracerWaveEmploymentSample({
    required this.survey,
    required this.answers,
  });

  final Survey survey;
  final List<_ChedEmploymentAnswer> answers;
}

class _ChedEmploymentAnswer {
  const _ChedEmploymentAnswer({
    required this.userId,
    required this.presentlyEmployed,
    this.submittedAt,
  });

  final String userId;
  final String? presentlyEmployed;
  final DateTime? submittedAt;
}

class _WaveEmploymentRatePoint {
  const _WaveEmploymentRatePoint({
    required this.surveyId,
    required this.label,
    required this.shortLabel,
    required this.rate,
    required this.employed,
    required this.answered,
    required this.createdAt,
  });

  final String surveyId;
  final String label;
  final String shortLabel;
  final double rate;
  final int employed;
  final int answered;
  final DateTime createdAt;
}
