import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import 'package:alumni_system/features/admin/reports/widgets/reports_bento.dart';
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

  List<ReportsInsightCardData> _insightCards = const [];
  bool _insightsGenerating = false;
  bool _insightsAreAi = false;

  /// Overview action center: 0 = needs attention, 1 = insights.
  int _overviewActionView = 0;

  /// Tracer view: 0 = outcomes, 1 = career path, 2 = cohorts & waves.
  int _tracerView = 0;

  /// Measured height of the cohort filter block (varies when it wraps).
  double _filterBlockHeight = 0;
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
  static const double _tabBarHeight = 48;
  late final TabController _tabController;

  /// Cohort filters for Tracer / Survey tabs only.
  ReportsDashboardFilters _dashboardFilters = ReportsDashboardFilters.empty;

  VoidCallback? _surveyCatalogListener;

  bool _downloadBusy = false;
  DateTime? _lastLoadedAt;
  bool _manualRefreshing = false;
  String? _downloadingPresetId;
  Object? _exportCountsKey;
  Map<CustomReportSectionId, int?> _exportCounts = const {};

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
        _lastLoadedAt = DateTime.now();
        // Keep AI-generated insights across background refreshes.
        if (!_insightsAreAi) {
          _insightCards = _buildPlaceholderInsights(analytics, adjustedSurveys);
        }
      });

      unawaited(_refreshSurveyReportExtras(surveys));
    } catch (e) {
      if (!mounted) return;
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
      (a, b) => reportsSurveyDisplayDate(
        a.survey,
      ).compareTo(reportsSurveyDisplayDate(b.survey)),
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
      });
      await _loadSurveyRollupsFor(adjustedSurveys);
    } catch (_) {}
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
    final tabIndex = _tabController.index;
    final showCohortFilters = tabIndex == 1 || tabIndex == 2;
    final view = showCohortFilters ? _viewAnalytics(a) : a;
    final batchOptions = reportsFilterBatchOptions(a.members);
    final surveyOptions = reportsFilterSurveyOptions(
      a.surveys,
      tracerOnly: tabIndex == 1,
    );

    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        color: AdminReportsTheme.primary,
        onRefresh: _loadAllData,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: ReportsDashboardCanvas(child: _buildDashboardHeader()),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SectionNavDelegate(
                height: _tabBarHeight,
                tabIndex: tabIndex,
                builder: (pinned) => Semantics(
                  label: 'Reports tabs',
                  container: true,
                  child: _buildTabBar(pinned: pinned),
                ),
              ),
            ),
            if (showCohortFilters)
              SliverToBoxAdapter(
                child: _HeightReporter(
                  onHeight: (h) {
                    if ((h - _filterBlockHeight).abs() > 0.5) {
                      setState(() => _filterBlockHeight = h);
                    }
                  },
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
                          waveLabel: tabIndex == 1
                              ? 'Tracer wave'
                              : 'Survey wave',
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
                    fitHeight: constraints.hasBoundedHeight
                        ? constraints.maxHeight -
                              ReportsPageHeader.height -
                              _tabBarHeight -
                              (showCohortFilters ? _filterBlockHeight : 0) -
                              AdminReportsTheme.space3 -
                              AdminReportsTheme.space4
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Task-based tab body — one job per tab, no duplicate KPI strips.
  Widget _buildSelectedTab({
    required AdminReportsAnalytics source,
    required AdminReportsAnalytics view,
    double? fitHeight,
  }) {
    switch (_tabController.index) {
      case 1:
        return _buildTracerTab(view, fitHeight: fitHeight);
      case 2:
        return _buildSurveysTab(view, fitHeight: fitHeight);
      case 3:
        return _buildDownloadsTab(source, fitHeight: fitHeight);
      default:
        return _buildOverviewTab(source, fitHeight: fitHeight);
    }
  }

  static const _tabSubtitles = [
    'System-wide pulse of alumni, tracer, and survey activity.',
    'Employment outcomes and career paths of graduates.',
    'Response health across alumni surveys.',
    'Ready-made report packs for the office.',
  ];

  Widget _buildDashboardHeader() {
    return ReportsPageHeader(
      subtitle: _tabSubtitles[_tabController.index],
      updatedAt: _lastLoadedAt,
      refreshing: _manualRefreshing,
      onRefresh: _refreshFromHeader,
    );
  }

  Future<void> _refreshFromHeader() async {
    setState(() => _manualRefreshing = true);
    try {
      await _loadAllData();
    } finally {
      if (mounted) setState(() => _manualRefreshing = false);
    }
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

  /// Bottom half of the header card; becomes a standalone card once pinned.
  Widget _buildTabBar({required bool pinned}) {
    const radius = Radius.circular(AdminReportsTheme.radiusLg);
    final pillRadius = BorderRadius.circular(AdminReportsTheme.radiusMd);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: pinned
            ? const BorderRadius.all(radius)
            : const BorderRadius.vertical(bottom: radius),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: pinned
            ? AdminReportsTheme.cardShadow
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: TabBar(
        controller: _tabController,
        tabAlignment: TabAlignment.fill,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(vertical: 2),
        indicator: BoxDecoration(
          borderRadius: pillRadius,
          gradient: const LinearGradient(
            colors: [AdminReportsTheme.primary, Color(0xFF2E2A7A)],
          ),
          boxShadow: [
            BoxShadow(
              color: AdminReportsTheme.primary.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        splashBorderRadius: pillRadius,
        overlayColor: WidgetStatePropertyAll(
          AdminReportsTheme.primary.withValues(alpha: 0.05),
        ),
        labelColor: Colors.white,
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
                    Icon(
                      _tabIcons[i],
                      size: 17,
                      color: _tabController.index == i
                          ? AdminReportsTheme.gold
                          : null,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _tabLabels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Overview: bento pulse — KPI strip, growth and composition charts, and an
  /// action center. System-wide; cohort filters do not apply here.
  Widget _buildOverviewTab(AdminReportsAnalytics a, {double? fitHeight}) {
    final coverage = _systemTracerCoverage(a);
    return ReportsBentoGrid(
      fitHeight: fitHeight,
      kpis: _overviewKpis(a, coverage),
      rows: [
        ReportsBentoRow(
          flex: const [5, 4, 3],
          naturalHeight: 300,
          children: [
            _overviewTrendCard(a),
            _overviewProgramCard(a),
            _overviewFunnelCard(a, coverage),
          ],
        ),
        ReportsBentoRow(
          flex: const [5, 4, 3],
          naturalHeight: 300,
          children: [
            _overviewSurveyHealthCard(a),
            _overviewBatchCard(a),
            _overviewActionCenter(a),
          ],
        ),
      ],
    );
  }

  String _pct(double rate) => '${(rate * 100).toStringAsFixed(0)}%';

  void _openAdminMenuOr(int menu, int fallbackTab) {
    final open = widget.onOpenAdminMenu;
    if (open != null) {
      open(menu);
    } else {
      _selectTab(fallbackTab);
    }
  }

  List<Widget> _overviewKpis(
    AdminReportsAnalytics a,
    TracerCoverageSnapshot coverage,
  ) {
    const scope =
        'Overview for the whole system (cohort filters do not apply here).';
    final now = DateTime.now();
    final addedThisMonth = a.activeRoster
        .where(
          (m) => m.createdAt.year == now.year && m.createdAt.month == now.month,
        )
        .length;
    final tracerStatus = reportsKpiStatusFromRate(
      coverage.tracerTakeRateAmongRegistered,
    );
    final surveyStatus = reportsKpiStatusFromRate(a.surveyResponseRate);
    final hasEmployment = a.reportEmploymentCount > 0;
    final employmentStatus = hasEmployment
        ? reportsKpiStatusFromRate(a.employmentRateAmongSubmissions)
        : ReportsKpiStatus.neutral;

    return [
      ReportsStatCard(
        label: 'Alumni roster',
        value: '${a.rosterTotal}',
        icon: Icons.groups_outlined,
        accent: AdminReportsTheme.primary,
        pillLabel: addedThisMonth > 0
            ? '+$addedThisMonth this month'
            : 'None new this month',
        pillColor: addedThisMonth > 0
            ? AdminReportsTheme.success
            : AdminReportsTheme.textMuted,
        rows: [
          ReportsStatRow('Registered', '${a.registeredOnRoster}'),
          ReportsStatRow('Unclaimed', '${a.unclaimedRoster}'),
          ReportsStatRow('Registration rate', _pct(a.registrationRate)),
        ],
        details: ReportsDetailsButton.compose(
          definition:
              'Active alumni on the roster, and how many already have a '
              'portal account.',
          calculation:
              '${a.registeredOnRoster} registered out of ${a.rosterTotal} on '
              'the active roster. "This month" counts roster records added '
              'since the 1st.',
          scope: scope,
        ),
        onTap: () => _openAdminMenuOr(2, 1),
      ),
      ReportsStatCard(
        label: 'Tracer reach',
        value: _pct(coverage.tracerTakeRateAmongRegistered),
        icon: Icons.school_outlined,
        accent: ReportsBentoPalette.at(1),
        pillLabel: reportsKpiStatusLabel(tracerStatus),
        pillColor: reportsStatusColor(tracerStatus),
        rows: [
          ReportsStatRow('Took tracer', '${coverage.tookTracer}'),
          ReportsStatRow(
            'Registered, no tracer',
            '${coverage.registeredNoTracer}',
          ),
          ReportsStatRow(
            'Profile complete',
            '${a.tracerCompleteCount}/${a.registeredOnRoster}',
          ),
        ],
        details: ReportsDetailsButton.compose(
          definition: coverage.definition,
          calculation:
              '${coverage.tookTracer} of ${coverage.registered} registered '
              'alumni submitted a tracer wave.',
          scope: scope,
          limitation:
              '"Profile complete" is the roster profile flag, not a tracer '
              'submission.',
        ),
        onTap: () => _selectTab(1),
      ),
      ReportsStatCard(
        label: 'Survey completion',
        value: _pct(a.surveyResponseRate),
        icon: Icons.poll_outlined,
        accent: ReportsBentoPalette.at(4),
        pillLabel: reportsKpiStatusLabel(surveyStatus),
        pillColor: reportsStatusColor(surveyStatus),
        rows: [
          ReportsStatRow('Submitted', '${a.totalSurveyResponses}'),
          ReportsStatRow('Pending', '${a.pendingSurveyAssignments}'),
          ReportsStatRow('Published surveys', '${a.publishedSurveys}'),
        ],
        details: ReportsDetailsButton.compose(
          definition:
              'Share of survey invitations that received a submitted response.',
          calculation:
              '${a.totalSurveyResponses} submitted out of '
              '${a.totalSurveyAssignments} assigned.',
          scope: 'All survey waves included in this overview.',
        ),
        onTap: () => _selectTab(2),
      ),
      ReportsStatCard(
        label: 'Employment rate',
        value: hasEmployment ? _pct(a.employmentRateAmongSubmissions) : '—',
        icon: Icons.work_outline,
        accent: AdminReportsTheme.success,
        pillLabel: hasEmployment
            ? reportsKpiStatusLabel(employmentStatus)
            : 'No data',
        pillColor: reportsStatusColor(employmentStatus),
        rows: [
          ReportsStatRow('Employed', '${a.employedCount}'),
          ReportsStatRow('Not employed', '${a.unemployedCount}'),
          ReportsStatRow('Records on file', '${a.reportEmploymentCount}'),
        ],
        details: ReportsDetailsButton.compose(
          definition: AdminReportsAnalytics.employmentRateDefinition,
          calculation: hasEmployment
              ? '${a.employedCount} employed out of ${a.reportEmploymentCount} '
                    'with employment information.'
              : 'No employment information is available yet.',
          scope:
              'Registered alumni with employment information on file '
              '(each person counted once).',
          limitation:
              'If the data set is large, results may be capped. Tracer '
              'employment charts use survey answers instead.',
        ),
        onTap: () => _selectTab(1),
      ),
    ];
  }

  Widget _overviewTrendCard(AdminReportsAnalytics a) {
    final roster = _monthlySeries(a.activeRoster.map((m) => m.createdAt));
    final registered = _monthlySeries(
      a.activeRoster.where((m) => m.isRegisteredUser).map((m) => m.createdAt),
    );
    final labels = [for (final m in _monthWindow()) _monthLabel(m)];
    final empty = roster.cumulative.every((v) => v == 0);
    return ReportsBentoCard(
      title: 'Roster & registration trend',
      caption: 'Cumulative alumni, last 12 months',
      details: ReportsDetailsButton.compose(
        definition:
            'Cumulative roster vs registered alumni by the month the roster '
            'record was added.',
        scope: 'System-wide.',
        limitation:
            'Registered alumni are plotted by roster record date, not by '
            'account sign-up date.',
      ),
      trailing: empty
          ? null
          : const Wrap(
              spacing: 12,
              children: [
                ReportsLegendDot(
                  color: AdminReportsTheme.primary,
                  label: 'Roster',
                ),
                ReportsLegendDot(
                  color: AdminReportsTheme.gold,
                  label: 'Registered',
                  dashed: true,
                ),
              ],
            ),
      child: empty
          ? const ReportsChartEmptyState(
              message: 'No roster timestamps available yet',
              icon: Icons.show_chart_outlined,
            )
          : ReportsTrendChart(
              labels: labels,
              series: [
                ReportsTrendSeries(
                  label: 'Roster',
                  color: AdminReportsTheme.primary,
                  values: roster.cumulative,
                ),
                ReportsTrendSeries(
                  label: 'Registered',
                  color: AdminReportsTheme.gold,
                  values: registered.cumulative,
                  filled: false,
                ),
              ],
            ),
    );
  }

  Widget _overviewProgramCard(AdminReportsAnalytics a) {
    const maxSlices = 5;
    final courses = a.topCourses();
    final entries = <ReportsDonutEntry>[
      for (var i = 0; i < courses.length && i < maxSlices; i++)
        ReportsDonutEntry(
          label: courses[i].key,
          value: courses[i].value,
          color: ReportsBentoPalette.at(i),
        ),
      if (courses.length > maxSlices)
        ReportsDonutEntry(
          label: 'Other programs',
          value: courses
              .skip(maxSlices)
              .fold<int>(0, (sum, e) => sum + e.value),
          color: ReportsBentoPalette.at(6),
        ),
    ];
    return ReportsBentoCard(
      title: 'Alumni by program',
      caption: '${courses.length} programs on the roster',
      details: ReportsDetailsButton.compose(
        definition: 'Active roster alumni grouped by their program (course).',
        calculation:
            'Top $maxSlices programs by headcount; the rest are grouped as '
            '"Other programs".',
        scope: 'System-wide.',
      ),
      child: entries.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No roster alumni yet',
              icon: Icons.donut_large_outlined,
            )
          : ReportsDonutBreakdown(
              entries: entries,
              centerValue: reportsCompactNumber(a.rosterTotal),
              centerLabel: 'Alumni',
            ),
    );
  }

  Widget _overviewFunnelCard(
    AdminReportsAnalytics a,
    TracerCoverageSnapshot coverage,
  ) {
    return ReportsBentoCard(
      title: 'Engagement funnel',
      caption: 'Share of the roster at each step',
      details: ReportsDetailsButton.compose(
        definition:
            'How far roster alumni have moved: registered a portal account, '
            'submitted a tracer wave, and completed their profile.',
        calculation: 'Each step is shown as a share of the full roster.',
        scope: 'System-wide.',
        limitation:
            '"Took tracer" and "Profile complete" are tracked separately, so '
            'the last step can be larger than the one before it.',
      ),
      child: a.rosterTotal == 0
          ? const ReportsChartEmptyState(
              message: 'No roster alumni yet',
              icon: Icons.filter_alt_outlined,
            )
          : ReportsFunnelBars(
              steps: [
                ReportsFunnelStep(
                  label: 'Roster',
                  value: a.rosterTotal,
                  color: AdminReportsTheme.primary,
                ),
                ReportsFunnelStep(
                  label: 'Registered',
                  value: a.registeredOnRoster,
                  color: ReportsBentoPalette.at(1),
                ),
                ReportsFunnelStep(
                  label: 'Took tracer',
                  value: coverage.tookTracer,
                  color: ReportsBentoPalette.at(2),
                ),
                ReportsFunnelStep(
                  label: 'Profile complete',
                  value: a.tracerCompleteCount,
                  color: AdminReportsTheme.gold,
                ),
              ],
            ),
    );
  }

  Widget _overviewSurveyHealthCard(AdminReportsAnalytics a) {
    final surveys = a.surveysForChart;
    return ReportsBentoCard(
      title: 'Survey response health',
      caption: 'Top surveys by response rate',
      details: ReportsDetailsButton.compose(
        definition: 'Response rate for each survey that has assignments.',
        calculation: 'Submitted responses divided by assignments per survey.',
        scope: 'Up to 6 non-archived surveys with assignments.',
      ),
      trailing: _bentoLink('Open Surveys', () => _openAdminMenuOr(10, 2)),
      child: surveys.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No surveys with assignments yet',
              icon: Icons.poll_outlined,
            )
          : ReportsProgressList(
              items: [
                for (final s in surveys)
                  () {
                    final submitted = a.submittedResponseCount(s);
                    final assigned = a.assignmentCount(s);
                    final rate = assigned == 0 ? 0.0 : submitted / assigned;
                    return ReportsProgressItem(
                      label: s.title,
                      detail: '$submitted/$assigned',
                      fraction: rate,
                      color: reportsStatusColor(reportsKpiStatusFromRate(rate)),
                    );
                  }(),
              ],
            ),
    );
  }

  Widget _overviewBatchCard(AdminReportsAnalytics a) {
    final batches = a.topBatchYears();
    return ReportsBentoCard(
      title: 'Alumni by batch year',
      caption: 'Most recent ${batches.length} batches',
      details: ReportsDetailsButton.compose(
        definition: 'Active roster alumni grouped by batch (graduation) year.',
        calculation: 'The largest batch is highlighted in gold.',
        scope: 'System-wide, latest 8 batch years.',
      ),
      child: batches.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No batch years on the roster yet',
            )
          : ReportsColumnChart(
              labels: [for (final b in batches) b.key],
              values: [for (final b in batches) b.value],
            ),
    );
  }

  Widget _overviewActionCenter(AdminReportsAnalytics a) {
    final attention = _attentionItems(a);
    final insights = _insightCardsWithActions(
      _insightCards.isEmpty
          ? _buildPlaceholderInsights(a, _surveys)
          : _insightCards,
    );
    final showInsights = _overviewActionView == 1;
    return ReportsBentoCard(
      title: 'Action center',
      caption: showInsights
          ? (_insightsAreAi ? 'AI-generated summary' : 'Rule-based highlights')
          : (attention.isEmpty
                ? 'All clear'
                : '${attention.length} follow-ups'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ReportsSegmentedToggle(
              options: const ['Attention', 'Insights'],
              selected: _overviewActionView,
              onChanged: (i) => setState(() => _overviewActionView = i),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: showInsights
                ? _buildInsightList(insights)
                : _buildAttentionList(attention),
          ),
        ],
      ),
    );
  }

  Widget _bentoLink(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminReportsTheme.primary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AdminReportsTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightList(List<ReportsInsightCardData> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final card = cards[i];
              final action = card.action;
              return _compactActionRow(
                icon: card.icon,
                color: card.isError
                    ? AdminReportsTheme.danger
                    : AdminReportsTheme.primary,
                title: card.title,
                subtitle: card.body,
                subtitleLines: 2,
                onTap: action == null
                    ? null
                    : () => _handleInsightAction(action),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _insightsGenerating ? null : _generateInsights,
            style: TextButton.styleFrom(
              foregroundColor: AdminReportsTheme.primary,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: _insightsGenerating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(
              _insightsGenerating
                  ? 'Generating…'
                  : (_insightsAreAi ? 'Regenerate' : 'Generate AI summary'),
            ),
          ),
        ),
      ],
    );
  }

  static const double _viewBarHeight = 36;

  /// Tracer: filtered KPI strip plus three switchable bento views.
  Widget _buildTracerTab(AdminReportsAnalytics a, {double? fitHeight}) {
    final coverage = _coverageFor(a);
    final gridFit = fitHeight == null
        ? null
        : fitHeight - _viewBarHeight - AdminReportsTheme.gutter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _viewBarHeight,
          child: Row(
            children: [
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ReportsSegmentedToggle(
                    options: const [
                      'Outcomes',
                      'Career path',
                      'Cohorts & waves',
                    ],
                    selected: _tracerView,
                    onChanged: (i) => setState(() => _tracerView = i),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _tracerExportMenu(a),
            ],
          ),
        ),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsBentoGrid(
          fitHeight: gridFit,
          kpis: _tracerKpis(a, coverage),
          rows: switch (_tracerView) {
            1 => _tracerCareerRows(a),
            2 => _tracerCohortRows(a),
            _ => _tracerOutcomeRows(a, coverage),
          },
        ),
      ],
    );
  }

  String _tracerScope(AdminReportsAnalytics a) {
    final chedStatus = _chedEmploymentStatusCounts(a);
    final waveScoped = _dashboardFilters.surveyId != null;
    final waveCount =
        chedStatus?.waveCount ?? _employmentRateByWavePoints(a).length;
    return _dashboardFilters.scopeLabel(
      surveys: _surveys,
      responseOrRecordCount: chedStatus?.answered ?? 0,
      countNoun: waveScoped || waveCount <= 1
          ? 'CHED employment answers'
          : 'alumni (latest wave across $waveCount tracers)',
    );
  }

  String _sampleCaption(int n, String noun) =>
      n > 0 && n < 5 ? 'Small sample · n = $n $noun' : 'n = $n $noun';

  static const _chedAnswerScope =
      'Submitted tracer answers within the filters you selected.';

  String _chedDetails(String definition) => ReportsDetailsButton.compose(
    definition: definition,
    scope: _chedAnswerScope,
    limitation:
        'When answers come from more than one tracer, totals are combined '
        'and may be approximate.',
  );

  static const _employedOnlyScope =
      'Only alumni who answered that they are currently employed, '
      'within the filters you selected.';

  String _batchOf(AlumniMember? member, TracerProfile? profile) {
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
  }

  String _courseOf(AlumniMember? member, TracerProfile? profile) {
    if (member?.course.trim().isNotEmpty == true) return member!.course;
    return profile?.program.trim() ?? '';
  }

  ({int yes, int total}) _chedYesShare(String questionId) {
    final entries = _chedChoiceCounts(questionId);
    return (
      yes: entries
          .where((e) => e.key.toLowerCase() == 'yes')
          .fold<int>(0, (s, e) => s + e.value),
      total: entries.fold<int>(0, (s, e) => s + e.value),
    );
  }

  /// CHED choice counts in questionnaire order; unanswered bins show as 0.
  List<MapEntry<String, int>> _chedOrderedCounts(String questionId) {
    final counts = {
      for (final e in _chedChoiceCounts(questionId)) e.key: e.value,
    };
    final options =
        ChedGtsBuiltin.byId(questionId)?.options ?? const <String>[];
    return [
      for (final o in options)
        if (o != ChedGtsBuiltin.othersSpecify || (counts[o] ?? 0) > 0)
          MapEntry(o, counts[o] ?? 0),
      for (final e in counts.entries)
        if (!options.contains(e.key)) e,
    ];
  }

  static String _chedShortLabel(String option) {
    const short = {
      'Less than a month': '<1 mo',
      '1 to 6 months': '1–6 mo',
      '7 to 11 months': '7–11 mo',
      '1 year to less than 2 years': '1–2 yr',
      '2 years to less than 3 years': '2–3 yr',
      '3 years to less than 4 years': '3–4 yr',
      ChedGtsBuiltin.othersSpecify: 'Other',
      'Below P5,000.00': '<5k',
      'P5,000.00 to less than P10,000.00': '5–10k',
      'P10,000.00 to less than P15,000.00': '10–15k',
      'P15,000.00 to less than P20,000.00': '15–20k',
      'P20,000.00 to less than P25,000.00': '20–25k',
      'P25,000.00 and above': '25k+',
    };
    return short[option] ??
        (option.length > 8 ? '${option.substring(0, 7)}…' : option);
  }

  /// Top [maxSlices] entries as donut slices, remainder grouped as "Other".
  List<ReportsDonutEntry> _donutEntries(
    List<MapEntry<String, int>> entries, {
    int maxSlices = 5,
  }) {
    final nonZero = [
      for (final e in entries)
        if (e.value > 0) e,
    ];
    return [
      for (var i = 0; i < nonZero.length && i < maxSlices; i++)
        ReportsDonutEntry(
          label: nonZero[i].key,
          value: nonZero[i].value,
          color: ReportsBentoPalette.at(i),
        ),
      if (nonZero.length > maxSlices)
        ReportsDonutEntry(
          label: 'Other',
          value: nonZero.skip(maxSlices).fold<int>(0, (s, e) => s + e.value),
          color: ReportsBentoPalette.at(6),
        ),
    ];
  }

  Widget _tracerExportMenu(AdminReportsAnalytics a) {
    return PopupMenuButton<String>(
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
        PopupMenuItem(value: 'pdf', child: Text('Export PDF (this filter)')),
        PopupMenuItem(
          value: 'excel',
          child: Text('Export Excel (this filter)'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(value: 'downloads', child: Text('Open Downloads tab')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 15,
              color: _downloadBusy
                  ? AdminReportsTheme.textMuted
                  : AdminReportsTheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              _downloadBusy ? 'Exporting\u2026' : 'Export view',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _downloadBusy
                    ? AdminReportsTheme.textMuted
                    : AdminReportsTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tracerKpis(
    AdminReportsAnalytics a,
    TracerCoverageSnapshot coverage,
  ) {
    final scope = _tracerScope(a);
    final ched = _chedEmploymentStatusCounts(a);
    final answered = ched?.answered ?? 0;
    final employed = ched?.employed ?? 0;
    final takeRate = coverage.tracerTakeRateAmongRegistered;
    final takeStatus = coverage.registered == 0
        ? ReportsKpiStatus.neutral
        : reportsKpiStatusFromRate(takeRate);
    final employmentRate = answered == 0 ? 0.0 : employed / answered;
    final employmentStatus = answered == 0
        ? ReportsKpiStatus.neutral
        : reportsKpiStatusFromRate(employmentRate);

    return [
      ReportsStatCard(
        label: 'Tracer responses',
        value: '${coverage.tookTracer}',
        icon: Icons.assignment_turned_in_outlined,
        accent: AdminReportsTheme.primary,
        pillLabel: coverage.registered == 0
            ? 'No data'
            : '${_pct(takeRate)} of registered',
        pillColor: reportsStatusColor(takeStatus),
        rows: [
          ReportsStatRow(
            'Registered, no tracer',
            '${coverage.registeredNoTracer}',
          ),
          ReportsStatRow('Not registered', '${coverage.notRegistered}'),
          ReportsStatRow(
            'Share of roster',
            _pct(coverage.tracerTakeRateAmongRoster),
          ),
        ],
        details: ReportsDetailsButton.compose(
          definition: coverage.definition,
          calculation:
              '${coverage.tookTracer} of ${coverage.registered} registered '
              'alumni (${coverage.rosterTotal} on the roster) submitted a '
              'tracer.',
          scope: coverage.waveLabel,
          limitation:
              '“Took tracer” means submitted the wave — not the same as '
              '“Profile complete” on Overview.',
        ),
      ),
      ReportsStatCard(
        label: 'Employment rate',
        value: answered == 0 ? '—' : _pct(employmentRate),
        icon: Icons.work_outline,
        accent: AdminReportsTheme.success,
        pillLabel: answered == 0
            ? 'No data'
            : reportsKpiStatusLabel(employmentStatus),
        pillColor: reportsStatusColor(employmentStatus),
        rows: [
          ReportsStatRow('Employed', '$employed'),
          ReportsStatRow('Not employed', '${ched?.notEmployed ?? 0}'),
          ReportsStatRow('Tracer waves', '${ched?.waveCount ?? 0}'),
        ],
        details: ReportsDetailsButton.compose(
          definition:
              'Share of graduates who said they are currently employed on '
              'the tracer.',
          calculation:
              'Employed means "Yes". Not employed means "No" or "Never '
              'employed".',
          scope: scope,
          limitation:
              'Rates use the latest answer per person when multiple tracer '
              'waves are in scope.',
        ),
      ),
      _yesShareKpi(
        label: 'Degree aligned',
        icon: Icons.school_outlined,
        accent: ReportsBentoPalette.at(1),
        share: _chedYesShare('ched_24a'),
        yesLabel: 'Aligned',
        noLabel: 'Not aligned',
        definition:
            'Share of graduates whose first job relates to the course they '
            'took in college.',
      ),
      _yesShareKpi(
        label: 'Curriculum relevant',
        icon: Icons.menu_book_outlined,
        accent: ReportsBentoPalette.at(4),
        share: _chedYesShare('ched_32'),
        yesLabel: 'Relevant',
        noLabel: 'Not relevant',
        definition:
            'Share of graduates who felt their college curriculum was '
            'relevant to their first job.',
      ),
    ];
  }

  Widget _yesShareKpi({
    required String label,
    required IconData icon,
    required Color accent,
    required ({int yes, int total}) share,
    required String yesLabel,
    required String noLabel,
    required String definition,
  }) {
    final rate = share.total == 0 ? 0.0 : share.yes / share.total;
    final status = share.total == 0
        ? ReportsKpiStatus.neutral
        : reportsKpiStatusFromRate(rate);
    return ReportsStatCard(
      label: label,
      value: share.total == 0 ? '—' : _pct(rate),
      icon: icon,
      accent: accent,
      pillLabel: share.total == 0 ? 'No data' : reportsKpiStatusLabel(status),
      pillColor: reportsStatusColor(status),
      rows: [
        ReportsStatRow(yesLabel, '${share.yes}'),
        ReportsStatRow(noLabel, '${share.total - share.yes}'),
        ReportsStatRow('Answers', '${share.total}'),
      ],
      details: ReportsDetailsButton.compose(
        definition: definition,
        calculation: '"Yes" answers divided by all answers to this question.',
        scope: _chedAnswerScope,
        limitation:
            'When answers come from more than one tracer, totals are '
            'combined and may be approximate.',
      ),
    );
  }

  // ── Tracer · Outcomes ──

  List<ReportsBentoRow> _tracerOutcomeRows(
    AdminReportsAnalytics a,
    TracerCoverageSnapshot coverage,
  ) {
    return [
      ReportsBentoRow(
        flex: const [5, 4, 3],
        naturalHeight: 300,
        children: [
          _tracerRateByWaveCard(a),
          _tracerStatusCard(a),
          _tracerCoverageCard(coverage),
        ],
      ),
      ReportsBentoRow(
        flex: const [5, 4, 3],
        naturalHeight: 300,
        children: [
          _bentoDistributionCard(
            title: 'Industry (employed)',
            details: ReportsDetailsButton.compose(
              definition:
                  'Top industries or sectors reported by currently employed '
                  'graduates.',
              scope: _employedOnlyScope,
            ),
            entries: _industryCounts(_scopedEmployedDetailRecords(a)),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.factory_outlined,
            color: AdminReportsTheme.primary,
            noun: 'employed alumni',
          ),
          _tracerEmploymentTypeCard(a),
          _bentoDistributionCard(
            title: 'Salary range',
            details: ReportsDetailsButton.compose(
              definition:
                  'Reported salary bands among currently employed graduates.',
              scope: _employedOnlyScope,
            ),
            entries: _employmentFieldCounts(
              a,
              (r) => r.salaryRange,
              employedOnly: true,
              limit: 10,
            ),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.payments_outlined,
            color: ReportsBentoPalette.at(1),
            noun: 'employed alumni',
          ),
        ],
      ),
    ];
  }

  Widget _tracerRateByWaveCard(AdminReportsAnalytics a) {
    final waveScoped = _dashboardFilters.surveyId != null;
    final points = waveScoped
        ? const <_WaveEmploymentRatePoint>[]
        : _employmentRateByWavePoints(a);
    final Widget child;
    if (waveScoped) {
      child = const ReportsChartEmptyState(
        message:
            'Choose "All published tracers" in the filters to compare '
            'waves.',
        icon: Icons.show_chart_outlined,
      );
    } else if (points.length < 2) {
      child = ReportsChartEmptyState(
        message: points.isEmpty
            ? 'No published tracer waves with employment answers yet'
            : 'Only 1 tracer wave has answers so far. The trend appears once '
                  'a second wave is submitted.',
        icon: Icons.show_chart_outlined,
      );
    } else {
      child = ReportsTrendChart(
        labels: [for (final p in points) p.shortLabel.split('\n').first],
        maxY: 100,
        valueSuffix: '%',
        showDots: true,
        series: [
          ReportsTrendSeries(
            label: 'Employment rate',
            color: AdminReportsTheme.success,
            values: [for (final p in points) p.rate],
          ),
        ],
        tooltipBuilder: (_, i) =>
            '${points[i].label}\n${points[i].rate.toStringAsFixed(0)}% '
            '(${points[i].employed}/${points[i].answered})',
      );
    }
    return ReportsBentoCard(
      title: 'Employment rate by tracer wave',
      caption: waveScoped
          ? 'One wave selected'
          : '${points.length} waves in chronological order',
      details: ReportsDetailsButton.compose(
        definition:
            'Share of graduates who said they are currently employed, shown '
            'for each published tracer.',
        calculation:
            'Employed answers divided by total employment answers on that '
            'tracer.',
        limitation:
            'This uses tracer survey answers. It may differ from the '
            'employment rate on the Overview tab.',
      ),
      child: child,
    );
  }

  Widget _tracerStatusCard(AdminReportsAnalytics a) {
    final ched = _chedEmploymentStatusCounts(a);
    final waveScoped = _dashboardFilters.surveyId != null;
    final employed = ched?.employed ?? a.employedCount;
    final notEmployed = ched?.notEmployed ?? a.unemployedCount;
    final total = employed + notEmployed;
    final details = ched != null
        ? ReportsDetailsButton.compose(
            definition: waveScoped
                ? 'Share of graduates on this tracer who said they are '
                      'currently employed.'
                : 'Share of graduates who said they are currently employed. '
                      'Latest answer counted per person.',
            calculation:
                'Employed means "Yes". Not employed means "No" or "Never '
                'employed".',
            scope: _tracerScope(a),
            limitation: 'Based on tracer survey answers.',
          )
        : ReportsDetailsButton.compose(
            definition:
                'Employed versus not employed among alumni who submitted '
                'employment information.',
            calculation: AdminReportsAnalytics.employmentRateDefinition,
            scope:
                'Uses employment submissions on file while tracer answers load.',
          );
    return ReportsBentoCard(
      title: 'Employment status',
      caption: total == 0 ? null : _sampleCaption(total, 'answers'),
      details: details,
      child: total == 0
          ? ReportsChartEmptyState(
              message: ched == null
                  ? 'No employment submissions yet'
                  : (waveScoped
                        ? 'No presently-employed answers on this tracer wave '
                              'yet'
                        : 'No presently-employed answers across tracer waves '
                              'yet'),
              icon: Icons.work_outline,
            )
          : ReportsDonutBreakdown(
              entries: [
                ReportsDonutEntry(
                  label: 'Employed',
                  value: employed,
                  color: AdminReportsTheme.success,
                ),
                ReportsDonutEntry(
                  label: 'Not employed',
                  value: notEmployed,
                  color: AdminReportsTheme.gold,
                ),
              ],
              centerValue: _pct(employed / total),
              centerLabel: 'Employed',
            ),
    );
  }

  Widget _tracerCoverageCard(TracerCoverageSnapshot coverage) {
    final open = widget.onOpenAdminMenu;
    return ReportsBentoCard(
      title: 'Coverage funnel',
      caption:
          '${_pct(coverage.tracerTakeRateAmongRegistered)} of registered took '
          'a tracer',
      details: ReportsDetailsButton.compose(
        definition: coverage.definition,
        calculation:
            'Registered take-rate '
            '${_pct(coverage.tracerTakeRateAmongRegistered)} · roster '
            'take-rate ${_pct(coverage.tracerTakeRateAmongRoster)}.',
        scope: coverage.waveLabel,
        limitation:
            '“Took tracer” means submitted the wave — not the same as '
            '“Profile complete” on Overview.',
      ),
      child: coverage.rosterTotal == 0
          ? const ReportsChartEmptyState(
              message:
                  'No roster alumni in this filter yet. Clear batch/course or '
                  'add roster rows.',
              icon: Icons.groups_outlined,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ReportsFunnelBars(
                    steps: [
                      ReportsFunnelStep(
                        label: 'Roster',
                        value: coverage.rosterTotal,
                        color: AdminReportsTheme.primary,
                      ),
                      ReportsFunnelStep(
                        label: 'Registered',
                        value: coverage.registered,
                        color: ReportsBentoPalette.at(1),
                      ),
                      ReportsFunnelStep(
                        label: 'Took tracer',
                        value: coverage.tookTracer,
                        color: AdminReportsTheme.success,
                      ),
                    ],
                  ),
                ),
                if (open != null &&
                    (coverage.notRegistered > 0 ||
                        coverage.registeredNoTracer > 0)) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      if (coverage.notRegistered > 0)
                        _bentoLink(
                          'Follow up ${coverage.notRegistered} unregistered',
                          () => open(2),
                        ),
                      if (coverage.registeredNoTracer > 0)
                        _bentoLink(
                          'Remind ${coverage.registeredNoTracer} without '
                          'tracer',
                          () => open(10),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _tracerEmploymentTypeCard(AdminReportsAnalytics a) {
    final types = _employmentFieldCounts(
      a,
      (r) => r.employmentType,
      employedOnly: true,
    );
    final total = types.fold<int>(0, (s, e) => s + e.value);
    return ReportsBentoCard(
      title: 'Employment type',
      caption: total == 0 ? null : _sampleCaption(total, 'employed alumni'),
      details: ReportsDetailsButton.compose(
        definition:
            'How employed graduates describe their work arrangement (for '
            'example full-time, part-time, contract, or self-employed).',
        scope: _employedOnlyScope,
        limitation:
            'Drawn from each graduate’s employment details — not from the '
            'whole roster.',
      ),
      child: total == 0
          ? const ReportsChartEmptyState(
              message: _noChedEmployedDetails,
              icon: Icons.badge_outlined,
            )
          : ReportsDonutBreakdown(
              entries: _donutEntries(types),
              centerValue: reportsCompactNumber(total),
              centerLabel: 'Employed',
            ),
    );
  }

  Widget _bentoDistributionCard({
    required String title,
    required String details,
    required List<MapEntry<String, int>> entries,
    required String emptyMessage,
    required Color color,
    IconData emptyIcon = Icons.bar_chart_outlined,
    String noun = 'answers',
  }) {
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return ReportsBentoCard(
      title: title,
      caption: total == 0 ? null : _sampleCaption(total, noun),
      details: details,
      child: total == 0
          ? ReportsChartEmptyState(message: emptyMessage, icon: emptyIcon)
          : ReportsProgressList(
              items: [
                for (final e in entries)
                  if (e.value > 0)
                    ReportsProgressItem(
                      label: e.key,
                      detail: '${e.value}',
                      fraction: e.value / total,
                      color: color,
                    ),
              ],
            ),
    );
  }

  // ── Tracer · Career path ──

  List<ReportsBentoRow> _tracerCareerRows(AdminReportsAnalytics a) {
    return [
      ReportsBentoRow(
        flex: const [4, 4, 4],
        naturalHeight: 280,
        children: [
          _chedColumnCard(
            title: 'Time to first job',
            questionId: 'ched_29',
            definition: 'How long it took graduates to land their first job.',
            emptyMessage: 'No time-to-first-job answers yet',
          ),
          _chedColumnCard(
            title: 'Initial monthly earning',
            questionId: 'ched_31',
            definition:
                'Reported initial gross monthly earnings in the first job.',
            emptyMessage: 'No initial earning answers yet',
          ),
          _chedDonutCard(
            title: 'Present employment status',
            questionId: 'ched_18',
            definition: 'How graduates describe their current job status.',
            emptyMessage: 'No present employment status answers yet',
          ),
        ],
      ),
      ReportsBentoRow(
        flex: const [3, 3, 3, 3],
        naturalHeight: 280,
        children: [
          _bentoDistributionCard(
            title: 'Reasons not employed',
            details: _chedDetails(
              'Reasons graduates gave for not being employed yet.',
            ),
            entries: _chedChoiceCounts('ched_17'),
            emptyMessage: 'No not-employed reason answers yet',
            emptyIcon: Icons.person_off_outlined,
            color: AdminReportsTheme.gold,
          ),
          _bentoDistributionCard(
            title: 'Further studies',
            details: ReportsDetailsButton.compose(
              definition:
                  'Reasons graduates gave for pursuing further studies.',
              scope: _chedAnswerScope,
            ),
            entries: _chedChoiceCounts('ched_15b'),
            emptyMessage: 'No further-studies responses yet',
            emptyIcon: Icons.menu_book_outlined,
            color: ReportsBentoPalette.at(1),
          ),
          _bentoDistributionCard(
            title: 'Graduate location',
            details: ReportsDetailsButton.compose(
              definition:
                  'Where employed graduates reported working or living '
                  '(province, city, or country when available).',
              scope: _employedOnlyScope,
            ),
            entries: _employmentFieldCounts(a, (r) {
              final province = (r.province ?? '').trim();
              if (province.isNotEmpty) return province;
              final city = (r.city ?? '').trim();
              if (city.isNotEmpty) return city;
              return (r.country ?? '').trim();
            }, employedOnly: true),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.place_outlined,
            color: ReportsBentoPalette.at(4),
            noun: 'employed alumni',
          ),
          _careerAlignmentCard(),
        ],
      ),
    ];
  }

  Widget _chedColumnCard({
    required String title,
    required String questionId,
    required String definition,
    required String emptyMessage,
  }) {
    final entries = _chedOrderedCounts(questionId);
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return ReportsBentoCard(
      title: title,
      caption: total == 0 ? null : _sampleCaption(total, 'answers'),
      details: _chedDetails(definition),
      child: total == 0
          ? ReportsChartEmptyState(message: emptyMessage)
          : ReportsColumnChart(
              labels: [for (final e in entries) _chedShortLabel(e.key)],
              tooltipLabels: [for (final e in entries) e.key],
              values: [for (final e in entries) e.value],
            ),
    );
  }

  Widget _chedDonutCard({
    required String title,
    required String questionId,
    required String definition,
    required String emptyMessage,
  }) {
    final entries = _chedOrderedCounts(questionId);
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    return ReportsBentoCard(
      title: title,
      caption: total == 0 ? null : _sampleCaption(total, 'answers'),
      details: _chedDetails(definition),
      child: total == 0
          ? ReportsChartEmptyState(
              message: emptyMessage,
              icon: Icons.donut_large_outlined,
            )
          : ReportsDonutBreakdown(
              entries: _donutEntries(entries),
              centerValue: reportsCompactNumber(total),
              centerLabel: 'Answers',
            ),
    );
  }

  Widget _careerAlignmentCard() {
    const questions = [
      ('Place of work', 'ched_21'),
      ('First job after college', 'ched_22'),
      ('First job related to degree', 'ched_24a'),
      ('Curriculum relevant to first job', 'ched_32'),
    ];
    final colors = [
      AdminReportsTheme.primary,
      AdminReportsTheme.gold,
      ReportsBentoPalette.at(2),
      ReportsBentoPalette.at(4),
      ReportsBentoPalette.at(6),
    ];
    final items = [
      for (final (label, id) in questions)
        ReportsSplitItem(
          label: label,
          entries: [
            for (final (i, e) in _chedOrderedCounts(id).indexed)
              ReportsDonutEntry(
                label: e.key,
                value: e.value,
                color: colors[i % colors.length],
              ),
          ],
        ),
    ];
    return ReportsBentoCard(
      title: 'Career alignment',
      caption: 'Yes / no and local / abroad splits',
      details: _chedDetails(
        'Place of work, whether this is the first job after college, whether '
        'it relates to the degree, and whether the curriculum was relevant.',
      ),
      child: items.every((i) => i.total == 0)
          ? const ReportsChartEmptyState(
              message: 'No career alignment answers yet',
              icon: Icons.alt_route_outlined,
            )
          : ReportsSplitBars(items: items),
    );
  }

  // ── Tracer · Cohorts & waves ──

  List<ReportsBentoRow> _tracerCohortRows(AdminReportsAnalytics a) {
    return [
      ReportsBentoRow(
        flex: const [4, 4, 4],
        naturalHeight: 280,
        children: [
          _tracerWaveBarsCard(a),
          _tracerGroupRateCard(a, byBatch: true),
          _tracerGroupRateCard(a, byBatch: false),
        ],
      ),
      ReportsBentoRow(
        flex: const [7, 5],
        naturalHeight: 320,
        children: [_tracerCourseTableCard(a), _tracerLongitudinalCard(a)],
      ),
    ];
  }

  Widget _tracerWaveBarsCard(AdminReportsAnalytics a) {
    final waveScoped = _dashboardFilters.surveyId != null;
    final points = waveScoped
        ? const <_WaveEmploymentRatePoint>[]
        : _employmentRateByWavePoints(a);
    return ReportsBentoCard(
      title: 'By published tracer',
      caption: points.isEmpty ? null : 'Tap a bar to list respondents',
      details: ReportsDetailsButton.compose(
        definition:
            'Compares each published tracer: how many answered, and how many '
            'said they are employed.',
        calculation:
            'The rate is employed ÷ answers. Tap a bar to see who answered.',
      ),
      trailing: points.isEmpty
          ? null
          : const Wrap(
              spacing: 10,
              children: [
                ReportsLegendDot(
                  color: AdminReportsTheme.primary,
                  label: 'Answers',
                ),
                ReportsLegendDot(
                  color: AdminReportsTheme.success,
                  label: 'Employed',
                ),
              ],
            ),
      child: waveScoped
          ? const ReportsChartEmptyState(
              message:
                  'Choose "All published tracers" in the filters to '
                  'compare waves.',
              icon: Icons.compare_arrows_outlined,
            )
          : points.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No tracer waves with employment answers yet',
              icon: Icons.compare_arrows_outlined,
            )
          : ReportsGroupedBarChart(
              labels: [for (final p in points) p.shortLabel.split('\n').first],
              tooltipTitles: [for (final p in points) p.label],
              series: [
                ReportsBarSeries(
                  label: 'Answers',
                  color: AdminReportsTheme.primary,
                  values: [for (final p in points) p.answered],
                ),
                ReportsBarSeries(
                  label: 'Employed',
                  color: AdminReportsTheme.success,
                  values: [for (final p in points) p.employed],
                ),
              ],
              tooltipFooter: (i) =>
                  'Rate ${points[i].rate.toStringAsFixed(0)}% · tap for names',
              onGroupTap: (i) {
                if (i < 0 || i >= points.length) return;
                unawaited(
                  _openWaveRespondentsDialog(a, surveyId: points[i].surveyId),
                );
              },
            ),
    );
  }

  Widget _tracerGroupRateCard(
    AdminReportsAnalytics a, {
    required bool byBatch,
  }) {
    final groupOf = byBatch ? _batchOf : _courseOf;
    final grouped = _chedEmploymentGroupRates(a, groupOf: groupOf);
    final total = grouped.fold<int>(0, (s, r) => s + r.answered);
    return ReportsBentoCard(
      title: byBatch ? 'Employment by batch' : 'Employment by course',
      caption: total == 0 ? null : _sampleCaption(total, 'answers'),
      details: ReportsDetailsButton.compose(
        definition: byBatch
            ? 'Employment answers grouped by batch or year graduated.'
            : 'Employment answers grouped by program or course.',
        calculation:
            'Employed ÷ alumni who answered, per group. When viewing all '
            'tracers, each person is counted from their latest answer. Tap a '
            'row to see who answered.',
      ),
      child: grouped.isEmpty
          ? ReportsChartEmptyState(
              message: byBatch
                  ? 'No batch-linked tracer answers yet'
                  : 'No course-linked tracer answers yet',
              icon: byBatch
                  ? Icons.calendar_today_outlined
                  : Icons.school_outlined,
            )
          : ReportsProgressList(
              items: [
                for (final r in grouped)
                  ReportsProgressItem(
                    label: r.label,
                    detail: '${r.employed}/${r.answered}',
                    fraction: r.rate / 100,
                    color: reportsStatusColor(
                      reportsKpiStatusFromRate(r.rate / 100),
                    ),
                    onTap: () => unawaited(
                      _openCohortRespondentsDialog(
                        a,
                        groupLabel: r.label,
                        groupOf: groupOf,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _tracerCourseTableCard(AdminReportsAnalytics a) {
    final stats = _courseStats(a);
    return ReportsBentoCard(
      title: 'Course comparison',
      caption: '${stats.length} courses in this filter',
      details: ReportsDetailsButton.compose(
        definition:
            'Per-course roster size, registration, tracer profile completion, '
            'and employment rate.',
        calculation:
            'Employment rate counts employed tracer submitters per course. '
            'Courses without submissions show “—”.',
        scope: 'Roster alumni within the batch and course filters.',
      ),
      child: stats.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No roster data yet — import alumni to compare courses',
              icon: Icons.menu_book_outlined,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _courseTableHeader(),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: stats.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, i) => _courseRow(stats[i], true),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tracerLongitudinalCard(AdminReportsAnalytics a) {
    final rows = _longitudinalRows(a);
    return ReportsBentoCard(
      title: 'Same alumni across waves',
      caption: '${rows.length} alumni answered 2+ waves',
      details: ReportsDetailsButton.compose(
        definition: 'Lists graduates who answered at least two tracer surveys.',
        calculation:
            'Each chip is that person\'s employment answer on that tracer.',
        scope: _tracerScope(a),
        limitation:
            'A person appears here if they used the same portal account on '
            'more than one tracer.',
      ),
      child: SingleChildScrollView(
        child: TracerLongitudinalPanel(
          rows: rows,
          onOpenPerson: _openLongitudinalPerson,
        ),
      ),
    );
  }

  void _openLongitudinalPerson(TracerLongitudinalRow row) {
    unawaited(
      showTracerRespondentsDialog(
        context: context,
        title: row.displayName,
        subtitle:
            '${row.points.length} waves \u00b7 employment status over time',
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

  /// System-wide tracer coverage for Overview (cohort filters do not apply).
  TracerCoverageSnapshot _systemTracerCoverage(AdminReportsAnalytics a) {
    return buildTracerCoverage(
      members: a.activeRoster,
      tracerSubmitterUserIds: {
        for (final sample in _waveEmploymentSamples)
          for (final ans in sample.answers)
            if (ans.userId.trim().isNotEmpty) ans.userId.trim(),
      },
      filters: ReportsDashboardFilters.empty,
      surveys: _surveys,
    );
  }

  // ── Surveys ──

  static const double _lowResponseThreshold = 0.40;

  /// Surveys: response-health KPI strip plus two bento rows.
  Widget _buildSurveysTab(AdminReportsAnalytics a, {double? fitHeight}) {
    final gridFit = fitHeight == null
        ? null
        : fitHeight - _viewBarHeight - AdminReportsTheme.gutter;
    final scope = _dashboardFilters.scopeLabel(
      surveys: _surveys,
      responseOrRecordCount: a.totalSurveyResponses,
      countNoun: 'submitted responses',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _viewBarHeight,
          child: Row(
            children: [
              Expanded(flex: 3, child: _scopePill(scope)),
              const SizedBox(width: 8),
              Flexible(
                child: _bentoLink(
                  'Open Surveys',
                  () => _openAdminMenuOr(10, 2),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(child: _bentoLink('Downloads', () => _selectTab(3))),
            ],
          ),
        ),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsBentoGrid(
          fitHeight: gridFit,
          kpis: _surveyKpis(a, scope),
          rows: [
            ReportsBentoRow(
              flex: const [5, 4, 3],
              naturalHeight: 300,
              children: [
                _surveyParticipationCard(a),
                _surveySplitCard(a),
                _surveyFollowUpCard(a),
              ],
            ),
            ReportsBentoRow(
              flex: const [7, 5],
              naturalHeight: 300,
              children: [
                _surveyWindowsCard(a),
                _surveyQuestionCompletionCard(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _scopePill(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: text,
        waitDuration: const Duration(milliseconds: 500),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AdminReportsTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AdminReportsTheme.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 13,
                color: AdminReportsTheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AdminReportsTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _surveyRate(AdminReportsAnalytics a, Survey s) {
    final assigned = a.assignmentCount(s);
    return assigned == 0 ? 0.0 : a.submittedResponseCount(s) / assigned;
  }

  /// Surveys under [_lowResponseThreshold], lowest response first.
  List<Survey> _lowResponseSurveys(AdminReportsAnalytics a) {
    return _participationSurveys(a)
        .where((s) => _surveyRate(a, s) < _lowResponseThreshold)
        .toList()
        .reversed
        .toList();
  }

  /// Published, non-archived surveys (respects the survey filter).
  List<Survey> _publishedSurveysInScope(AdminReportsAnalytics a) {
    final surveyId = _dashboardFilters.surveyId;
    return [
      for (final s in a.surveys)
        if (!s.archived &&
            s.status == SurveyStatus.published &&
            (surveyId == null || s.id == surveyId))
          s,
    ];
  }

  bool _closesWithinWeek(Survey s) {
    final close = s.closeAt;
    return s.isOpen &&
        close != null &&
        close.isBefore(DateTime.now().add(const Duration(days: 7)));
  }

  List<Widget> _surveyKpis(AdminReportsAnalytics a, String scope) {
    final assigned = a.totalSurveyAssignments;
    final submitted = a.totalSurveyResponses;
    final pending = (assigned - submitted).clamp(0, assigned);
    final rate = assigned == 0 ? 0.0 : submitted / assigned;
    final dropOff = assigned == 0 ? 0.0 : pending / assigned;
    final rateStatus = assigned == 0
        ? ReportsKpiStatus.neutral
        : reportsKpiStatusFromRate(rate);
    final participating = _participationSurveys(a);
    final waiting = participating
        .where((s) => a.assignmentCount(s) > a.submittedResponseCount(s))
        .length;
    final lowCount = _lowResponseSurveys(a).length;

    final published = _publishedSurveysInScope(a);
    final open = published.where((s) => s.isOpen).toList();
    final closingSoon = open.where(_closesWithinWeek).length;
    final scheduled = published.where((s) => s.isNotYetOpen).length;
    final noCloseDate = open.where((s) => s.closeAt == null).length;
    final portfolio = a.publishedSurveys + a.draftSurveys + a.closedSurveys;

    return [
      ReportsStatCard(
        label: 'Response rate',
        value: assigned == 0 ? '—' : _pct(rate),
        icon: Icons.how_to_vote_outlined,
        accent: AdminReportsTheme.primary,
        pillLabel: assigned == 0
            ? 'No data'
            : reportsKpiStatusLabel(rateStatus),
        pillColor: reportsStatusColor(rateStatus),
        rows: [
          ReportsStatRow('Submitted', '$submitted'),
          ReportsStatRow('Assigned', '$assigned'),
          ReportsStatRow('Surveys with assignments', '${participating.length}'),
        ],
        details: ReportsDetailsButton.compose(
          definition:
              'Share of survey assignments that have a submitted response.',
          calculation: 'Submitted responses divided by assignments.',
          scope: scope,
          limitation:
              'Only the survey filter changes these numbers; batch and course '
              'filters do not split survey assignments.',
        ),
      ),
      ReportsStatCard(
        label: 'Pending responses',
        value: '$pending',
        icon: Icons.hourglass_bottom_outlined,
        accent: AdminReportsTheme.gold,
        pillLabel: assigned == 0 ? 'No data' : '${_pct(dropOff)} drop-off',
        pillColor: reportsStatusColor(rateStatus),
        rows: [
          ReportsStatRow('Low-response surveys', '$lowCount'),
          ReportsStatRow('Surveys still waiting', '$waiting'),
          ReportsStatRow('Drop-off', assigned == 0 ? '—' : _pct(dropOff)),
        ],
        details: ReportsDetailsButton.compose(
          definition: 'Assignments that have not been submitted yet.',
          calculation:
              'Assignments minus submitted responses. Drop-off is pending '
              'divided by assignments. Low response means under '
              '${(_lowResponseThreshold * 100).round()}%.',
          scope: scope,
        ),
      ),
      ReportsStatCard(
        label: 'Open for responses',
        value: '${open.length}',
        icon: Icons.event_available_outlined,
        accent: AdminReportsTheme.success,
        pillLabel: open.isEmpty
            ? 'None open'
            : closingSoon > 0
            ? '$closingSoon closing ≤ 7 days'
            : 'None closing soon',
        pillColor: reportsStatusColor(
          open.isEmpty
              ? ReportsKpiStatus.neutral
              : closingSoon > 0
              ? ReportsKpiStatus.watch
              : ReportsKpiStatus.positive,
        ),
        rows: [
          ReportsStatRow('Closing within 7 days', '$closingSoon'),
          ReportsStatRow('Scheduled (not yet open)', '$scheduled'),
          ReportsStatRow('Open with no close date', '$noCloseDate'),
        ],
        details: ReportsDetailsButton.compose(
          definition: 'Published surveys that alumni can answer right now.',
          calculation:
              'Open means published and inside the survey\'s open and close '
              'dates (if set).',
          scope: 'Published, non-archived surveys within the survey filter.',
        ),
      ),
      ReportsStatCard(
        label: 'Live surveys',
        value: '${a.publishedSurveys}',
        icon: Icons.poll_outlined,
        accent: ReportsBentoPalette.at(1),
        pillLabel: '$portfolio in portfolio',
        pillColor: reportsStatusColor(ReportsKpiStatus.neutral),
        rows: [
          ReportsStatRow('Drafts', '${a.draftSurveys}'),
          ReportsStatRow('Closed', '${a.closedSurveys}'),
          ReportsStatRow('Archived', '${a.archivedSurveys}'),
        ],
        details: ReportsDetailsButton.compose(
          definition: 'Surveys by status in the Surveys module.',
          calculation:
              'Live means published. Portfolio counts live, draft, and '
              'closed surveys; archived surveys are listed separately.',
          scope: scope,
        ),
      ),
    ];
  }

  Widget _surveyParticipationCard(AdminReportsAnalytics a) {
    final list = _participationSurveys(a).take(8).toList();
    return ReportsBentoCard(
      title: 'Participation by survey',
      caption: list.isEmpty ? null : 'Top ${list.length} by response rate',
      details: ReportsDetailsButton.compose(
        definition:
            'Assignments and submitted responses for each survey that has '
            'assignments.',
        calculation: 'Response rate is submitted ÷ assigned per survey.',
        scope: 'Up to 8 non-archived surveys within the survey filter.',
      ),
      trailing: list.isEmpty
          ? null
          : Wrap(
              spacing: 10,
              children: [
                ReportsLegendDot(
                  color: ReportsBentoPalette.at(5),
                  label: 'Assigned',
                ),
                const ReportsLegendDot(
                  color: AdminReportsTheme.primary,
                  label: 'Submitted',
                ),
              ],
            ),
      child: list.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No surveys with assignments in this filter yet',
              icon: Icons.poll_outlined,
            )
          : ReportsGroupedBarChart(
              labels: [
                for (final s in list)
                  s.title.length > 10 ? '${s.title.substring(0, 9)}…' : s.title,
              ],
              tooltipTitles: [for (final s in list) s.title],
              series: [
                ReportsBarSeries(
                  label: 'Assigned',
                  color: ReportsBentoPalette.at(5),
                  values: [for (final s in list) a.assignmentCount(s)],
                ),
                ReportsBarSeries(
                  label: 'Submitted',
                  color: AdminReportsTheme.primary,
                  values: [for (final s in list) a.submittedResponseCount(s)],
                ),
              ],
              tooltipFooter: (i) =>
                  'Response rate ${_pct(_surveyRate(a, list[i]))}',
            ),
    );
  }

  Widget _surveySplitCard(AdminReportsAnalytics a) {
    final assigned = a.totalSurveyAssignments;
    final submitted = a.totalSurveyResponses;
    final pending = (assigned - submitted).clamp(0, assigned);
    return ReportsBentoCard(
      title: 'Response split',
      caption: assigned == 0 ? null : _sampleCaption(assigned, 'assignments'),
      details: ReportsDetailsButton.compose(
        definition: 'Submitted versus still-pending survey assignments.',
        calculation: 'The centre shows submitted ÷ assigned.',
        scope: 'Non-archived surveys within the survey filter.',
      ),
      child: assigned == 0
          ? const ReportsChartEmptyState(
              message: 'No survey assignments in this filter yet',
              icon: Icons.donut_large_outlined,
            )
          : ReportsDonutBreakdown(
              centerValue: _pct(submitted / assigned),
              centerLabel: 'responded',
              entries: [
                ReportsDonutEntry(
                  label: 'Submitted',
                  value: submitted,
                  color: AdminReportsTheme.success,
                ),
                ReportsDonutEntry(
                  label: 'Pending',
                  value: pending,
                  color: AdminReportsTheme.gold,
                ),
              ],
            ),
    );
  }

  Widget _surveyFollowUpCard(AdminReportsAnalytics a) {
    final hasAssignments = _participationSurveys(a).isNotEmpty;
    final low = _lowResponseSurveys(a);
    final threshold = '${(_lowResponseThreshold * 100).round()}%';
    return ReportsBentoCard(
      title: 'Needs follow-up',
      caption: low.isEmpty ? null : '${low.length} below $threshold response',
      details: ReportsDetailsButton.compose(
        definition:
            'Surveys whose response rate is below $threshold, lowest first.',
        calculation:
            'Submitted ÷ assigned per survey. Tap a survey to open the '
            'Surveys module and send reminders.',
        scope:
            'Non-archived surveys with assignments within the survey '
            'filter.',
      ),
      child: !hasAssignments
          ? const ReportsChartEmptyState(
              message: 'No surveys with assignments yet',
              icon: Icons.poll_outlined,
            )
          : low.isEmpty
          ? ReportsChartEmptyState(
              message: 'Every survey is at or above $threshold response',
              icon: Icons.check_circle_outline,
            )
          : ReportsProgressList(
              items: [
                for (final s in low)
                  ReportsProgressItem(
                    label: s.title,
                    detail:
                        '${a.submittedResponseCount(s)}/${a.assignmentCount(s)}',
                    fraction: _surveyRate(a, s),
                    color: _surveyRate(a, s) < 0.2
                        ? AdminReportsTheme.danger
                        : AdminReportsTheme.warning,
                    onTap: () => _openAdminMenuOr(10, 2),
                  ),
              ],
            ),
    );
  }

  String _surveyDate(DateTime d) {
    final local = d.toLocal();
    return local.year == DateTime.now().year
        ? DateFormat('MMM d').format(local)
        : DateFormat('MMM d, y').format(local);
  }

  String _surveyWindowLabel(Survey s) {
    if (s.isOpen) {
      final close = s.closeAt;
      return close == null ? 'No close date' : 'Closes ${_surveyDate(close)}';
    }
    if (s.isNotYetOpen) return 'Opens ${_surveyDate(s.openAt!)}';
    final close = s.closeAt;
    return close == null ? 'Not open' : 'Past close · ${_surveyDate(close)}';
  }

  /// Open (soonest close first), then scheduled, then past close.
  int _surveyWindowRank(Survey s) => s.isOpen
      ? 0
      : s.isNotYetOpen
      ? 1
      : 2;

  Widget _surveyWindowsCard(AdminReportsAnalytics a) {
    final far = DateTime(9999);
    final surveys = _publishedSurveysInScope(a)
      ..sort((x, y) {
        final rank = _surveyWindowRank(x).compareTo(_surveyWindowRank(y));
        if (rank != 0) return rank;
        final xd = (x.isNotYetOpen ? x.openAt : x.closeAt) ?? far;
        final yd = (y.isNotYetOpen ? y.openAt : y.closeAt) ?? far;
        return _surveyWindowRank(x) == 2 ? yd.compareTo(xd) : xd.compareTo(yd);
      });
    final open = surveys.where((s) => s.isOpen).length;
    final scheduled = surveys.where((s) => s.isNotYetOpen).length;
    return ReportsBentoCard(
      title: 'Survey windows',
      caption: surveys.isEmpty ? null : '$open open · $scheduled scheduled',
      details: ReportsDetailsButton.compose(
        definition:
            'Each published survey with its response window and response '
            'rate.',
        calculation:
            'Open surveys come first, soonest close date first. The bar is '
            'submitted ÷ assigned. Tap a survey to open the Surveys module.',
        scope: 'Published, non-archived surveys within the survey filter.',
      ),
      child: surveys.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No published surveys in this filter',
              icon: Icons.event_note_outlined,
            )
          : ReportsProgressList(
              items: [
                for (final s in surveys)
                  ReportsProgressItem(
                    label: s.title,
                    detail: a.assignmentCount(s) == 0
                        ? '${_surveyWindowLabel(s)} · not assigned'
                        : _surveyWindowLabel(s),
                    fraction: _surveyRate(a, s),
                    color: a.assignmentCount(s) == 0
                        ? AdminReportsTheme.textMuted
                        : reportsStatusColor(
                            reportsKpiStatusFromRate(_surveyRate(a, s)),
                          ),
                    onTap: () => _openAdminMenuOr(10, 2),
                  ),
              ],
            ),
    );
  }

  Widget _surveyQuestionCompletionCard() {
    final surveyId = _dashboardFilters.surveyId;
    final rollups = [
      for (final r in _surveyRollups)
        if (!r.survey.isChedGtsBuiltin &&
            !r.survey.archived &&
            (surveyId == null || r.survey.id == surveyId))
          r,
    ];
    final questions =
        <({String prompt, String survey, int answered, int total})>[
          for (final r in rollups)
            for (final q in r.aggregates)
              if (q.totalResponses > 0 &&
                  !r.survey.visibilityRules.containsKey(q.questionId))
                (
                  prompt: q.prompt.trim().isEmpty
                      ? q.questionId
                      : q.prompt.trim(),
                  survey: r.survey.title,
                  answered: q.answeredCount,
                  total: q.totalResponses,
                ),
        ]..sort((x, y) {
          final byRate = (x.answered / x.total).compareTo(y.answered / y.total);
          return byRate != 0 ? byRate : x.prompt.compareTo(y.prompt);
        });
    return ReportsBentoCard(
      title: 'Question completion',
      caption: questions.isEmpty
          ? null
          : 'Least answered first · ${rollups.length} '
                '${rollups.length == 1 ? 'survey' : 'surveys'}',
      details: ReportsDetailsButton.compose(
        definition:
            'How many respondents answered each question, least answered '
            'first — useful for spotting confusing or optional questions.',
        calculation: 'Answers to the question ÷ submitted responses.',
        scope:
            'Custom surveys with submitted responses within the survey '
            'filter.',
        limitation:
            'CHED tracer waves (shown on the Tracer tab) and questions shown '
            'only after a specific answer are left out, because they are '
            'skipped by design. Question stats load for up to 4 published '
            'custom surveys with the most responses.',
      ),
      child: questions.isEmpty
          ? ReportsChartEmptyState(
              message: surveyId == null
                  ? 'Custom surveys with submitted responses will appear here'
                  : 'No question stats for this survey here — open it in '
                        'Surveys for question-level charts',
              icon: Icons.quiz_outlined,
            )
          : ReportsProgressList(
              items: [
                for (final q in questions.take(12))
                  ReportsProgressItem(
                    label: rollups.length > 1
                        ? '${q.prompt} · ${q.survey}'
                        : q.prompt,
                    detail: '${q.answered}/${q.total}',
                    fraction: q.answered / q.total,
                    color: reportsStatusColor(
                      reportsKpiStatusFromRate(q.answered / q.total),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDownloadsTab(AdminReportsAnalytics a, {double? fitHeight}) {
    final batch = _dashboardFilters.batchYear;
    final course = _dashboardFilters.course;
    return ReportsDownloadsPanel(
      busy: _downloadBusy,
      busyPresetId: _downloadingPresetId,
      fitHeight: fitHeight,
      rowCounts: _exportRowCounts(a),
      chedWaveCount: _chedComparisonWaves(a).length,
      filterLabel:
          '${batch == null ? 'All batches' : 'Batch $batch'} · '
          '${course ?? 'All courses'}',
      onClearFilters: batch == null && course == null
          ? null
          : () => setState(
              () => _dashboardFilters = _dashboardFilters.copyWith(
                clearBatch: true,
                clearCourse: true,
              ),
            ),
      onDownload: (preset, {required format, required printPreview}) async {
        setState(() => _downloadingPresetId = preset.id);
        try {
          await _downloadPreset(
            a,
            preset,
            format: format,
            printPreview: printPreview,
          );
        } finally {
          if (mounted) setState(() => _downloadingPresetId = null);
        }
      },
    );
  }

  CustomReportFilters _presetExportFilters() => CustomReportFilters(
    batchYears: [
      if (_dashboardFilters.batchYear != null) _dashboardFilters.batchYear!,
    ],
    courses: [if (_dashboardFilters.course != null) _dashboardFilters.course!],
  );

  static const _rollupSections = {
    CustomReportSectionId.surveyQuestions,
    CustomReportSectionId.surveyParticipation,
  };

  /// Rows per export section, built with the same builder as the download.
  /// Cached until the data or the batch / course filters change.
  Map<CustomReportSectionId, int?> _exportRowCounts(AdminReportsAnalytics a) {
    final key = (
      a,
      _surveyRollups,
      _registeredProfiles,
      _allEvents,
      _jobs,
      _dashboardFilters.batchYear,
      _dashboardFilters.course,
    );
    if (key == _exportCountsKey) return _exportCounts;

    final sections = <CustomReportSectionId>{
      for (final p in ReportsDownloadsPanel.presets)
        for (final s in p.sections)
          if (s != CustomReportSectionId.chedWaveComparison) s,
    };
    final rollupsPending = _surveyRollups.isEmpty;
    var counts = <CustomReportSectionId, int?>{};
    try {
      final now = DateTime.now();
      final doc = CustomReportExportService.buildDocument(
        template: CustomReportTemplate(
          id: 'preset_preview',
          name: 'Preview',
          sections: sections.toList(),
          format: CustomReportFormat.pdf,
          filters: _presetExportFilters(),
          createdAt: now,
          updatedAt: now,
        ),
        analytics: a,
        events: _allEvents,
        jobs: _jobs,
        rollups: _surveyRollups,
        profilesByAuthUid: _registeredProfiles,
      );
      counts = {
        for (final s in doc.sections)
          s.id: rollupsPending && _rollupSections.contains(s.id)
              ? null
              : s.rowCount,
      };
    } catch (_) {
      counts = {};
    }
    _exportCountsKey = key;
    _exportCounts = counts;
    return counts;
  }

  /// Official CHED GTS waves that can be compared.
  List<Survey> _chedComparisonWaves(AdminReportsAnalytics a) {
    return a.surveys
        .where(
          (s) =>
              !s.archived &&
              s.isChedGtsBuiltin &&
              (s.status == SurveyStatus.published ||
                  s.status == SurveyStatus.closed) &&
              a.submittedResponseCount(s) > 0,
        )
        .toList();
  }

  List<_AttentionItem> _attentionItems(AdminReportsAnalytics a) {
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

    return items;
  }

  Widget _buildAttentionList(List<_AttentionItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AdminReportsTheme.success,
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              'Nothing urgent — follow-ups look on track.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AdminReportsTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final item = items[i];
        return _compactActionRow(
          icon: item.icon,
          color: item.color,
          title: item.title,
          subtitle: item.subtitle,
          tooltip: 'Open ${item.actionLabel}',
          onTap: item.onAction,
        );
      },
    );
  }

  Widget _compactActionRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    int subtitleLines = 1,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AdminReportsTheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AdminReportsTheme.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: subtitleLines,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminReportsTheme.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? row : Tooltip(message: tooltip, child: row);
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
    final resolvedBatch = memberBatch.isNotEmpty ? memberBatch : profileBatch;

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
            Flexible(
              child: Text(
                showDash ? 'no data' : counts,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AdminReportsTheme.textMuted,
                ),
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
      (x, y) =>
          x.displayName.toLowerCase().compareTo(y.displayName.toLowerCase()),
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
      (x, y) =>
          x.displayName.toLowerCase().compareTo(y.displayName.toLowerCase()),
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
    final samples = [..._waveEmploymentSamples]
      ..sort(
        (x, y) => reportsSurveyDisplayDate(
          x.survey,
        ).compareTo(reportsSurveyDisplayDate(y.survey)),
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
        byUser
            .putIfAbsent(uid, () => <TracerWaveStatusPoint>[])
            .add(
              TracerWaveStatusPoint(
                waveLabel: waveLabel,
                waveDate: waveDate,
                status: status,
              ),
            );
      }
    }

    final rows =
        <TracerLongitudinalRow>[
          for (final e in byUser.entries)
            if (e.value.length >= 2)
              TracerLongitudinalRow(
                userId: e.key,
                displayName: _displayNameForUid(a, e.key),
                points: e.value,
              ),
        ]..sort(
          (x, y) => x.displayName.toLowerCase().compareTo(
            y.displayName.toLowerCase(),
          ),
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
    await _downloadPreset(a, preset, format: format, printPreview: false);
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
      final needsRollups =
          preset.sections.contains(CustomReportSectionId.surveyQuestions) ||
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
        filters: _presetExportFilters(),
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
          SnackBar(
            content: Text('Downloaded ${preset.title} (${format.label}).'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    } finally {
      if (mounted) setState(() => _downloadBusy = false);
    }
  }

  Future<void> _downloadChedWaveComparison(
    AdminReportsAnalytics a, {
    required CustomReportFormat format,
    required bool printPreview,
  }) async {
    final chedWaves = _chedComparisonWaves(a);

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
      final doc = CustomReportExportService.buildChedWaveComparisonDocument(
        report,
      );
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
            content: Text('Downloaded CHED wave comparison (${format.label}).'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
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

/// Reports its child's laid-out height after each build.
class _HeightReporter extends StatefulWidget {
  const _HeightReporter({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<_HeightReporter> createState() => _HeightReporterState();
}

class _HeightReporterState extends State<_HeightReporter> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = context.size?.height;
      if (height != null) widget.onHeight(height);
    });
    return widget.child;
  }
}

/// Pins the section navigation bar below the header while the dashboard scrolls.
class _SectionNavDelegate extends SliverPersistentHeaderDelegate {
  _SectionNavDelegate({
    required this.builder,
    required this.height,
    required this.tabIndex,
  });

  /// Receives `true` once the header above has scrolled away.
  final Widget Function(bool pinned) builder;
  final double height;
  final int tabIndex;

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
        child: builder(shrinkOffset > 0),
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionNavDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.tabIndex != tabIndex;
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
