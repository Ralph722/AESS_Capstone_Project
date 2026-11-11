import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alumni_system/core/constants/ustp_colors.dart';
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
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/institutional_ched_templates.dart';
import 'package:alumni_system/features/admin/reports/application/report_file_names.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_coverage.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_tab_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:alumni_system/features/admin/reports/models/report_filter_config.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_header.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_kpi.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_insights.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_polish.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_filter_bar.dart';
import 'package:alumni_system/features/admin/reports/widgets/ched_wave_comparison_dialog.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_alumni_list_panel.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_builder_mode_switch.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_builder.dart';
import 'package:alumni_system/shared/widgets/personal_data_export_dialog.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_bento.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_download_config_dialog.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_downloads_panel.dart';
import 'package:alumni_system/features/admin/reports/widgets/tracer_outcome_extras.dart';
import 'package:alumni_system/features/admin/reports/data/custom_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/data/gts_saved_report_service.dart';
import 'package:alumni_system/features/admin/reports/data/institutional_cohort_comparison_service.dart';
import 'package:alumni_system/features/admin/reports/data/institutional_gts_participation_quality_service.dart';
import 'package:alumni_system/features/admin/reports/data/institutional_gts_summary_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_tab_bar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
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

  static const _tabLabels = [
    'Overview',
    'Tracer',
    'Survey',
    'Downloads',
    'Builder',
  ];
  static const _tabIcons = [
    Icons.dashboard_outlined,
    Icons.school_outlined,
    Icons.poll_outlined,
    Icons.download_outlined,
    Icons.tune_outlined,
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

  TracerTabStats? _tracerStatsCache;
  Object? _tracerStatsKey;

  List<ReportsInsightCardData> _insightCards = const [];
  bool _insightsGenerating = false;
  bool _insightsAreAi = false;

  /// Overview action center: 0 = needs attention, 1 = insights.
  int _overviewActionView = 0;

  /// Tracer topic: 0 School-to-work, 1 Curriculum, 2 Placement, 3 Studies,
  /// 4 Waves (cross-wave compare).
  int _tracerTopic = 0;

  bool get _tracerWavesMode => _tracerTopic == 4;

  /// Job level card (Q30): 0 = first job, 1 = present job.
  int _jobLevelTab = 0;

  /// Retention / mobility card: 0 stay (Q23), 1 accept (Q25), 2 change (Q26).
  int _mobilityTab = 0;

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
    'surveys',
    'survey_questions',
    'survey_assignments',
    'survey_responses',
    'announcements',
    'forum_topics',
  ];

  // Task-based tabs: Overview · Tracer · Survey · Downloads.
  static const double _tabBarHeight = 46;
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

  /// Report builder settings, kept while switching tabs.
  GtsReportConfig? _builderConfig;
  late final _savedReports = GtsSavedReportService();
  final _builderRespondents = <String, List<GtsRespondent>>{};
  var _builderMode = GtsBuilderMode.list;
  GtsListConfig? _listConfig;
  final _listResponses = <String, List<GtsListResponse>>{};

  /// Saved reports each builder mode has open, kept across tab switches.
  GtsSavedReport? _builderOpen;
  GtsSavedReport? _listOpen;

  /// Opens a saved report from the other builder mode in its own mode.
  void _openSavedInMode(GtsSavedReport report) {
    try {
      if (report.isList) {
        final settings = report.listSettings.copyWith(title: report.name);
        setState(() {
          _listConfig = settings;
          _listOpen = report;
          _builderMode = GtsBuilderMode.list;
        });
      } else {
        final settings = report.settings.copyWith(title: report.name);
        setState(() {
          _builderConfig = settings;
          _builderOpen = report;
          _builderMode = GtsBuilderMode.summary;
        });
      }
    } on FormatException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || !mounted) return;
      if (_tabController.index == 1) {
        final id = _dashboardFilters.surveyId;
        if (id != null) {
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
        if (_tracerWavesMode) {
          _dashboardFilters = ReportsDashboardFilters(
            batchYear: _dashboardFilters.batchYear,
            course: _dashboardFilters.course,
          );
        } else {
          _ensureTracerOutcomesWaveSelected();
        }
        unawaited(_ensureSelectedWaveSample(_dashboardFilters.surveyId));
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
        if (_tabController.index == 1 && !_tracerWavesMode) {
          _ensureTracerOutcomesWaveSelected();
        }
      });

      unawaited(_refreshSurveyReportExtras(surveys));
      if (_tabController.index == 1) {
        unawaited(_ensureSelectedWaveSample(_dashboardFilters.surveyId));
      }
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
              // Per-person answers so Tracer cards can follow cohort filters
              // and use each graduate's latest submission.
              employmentSample = _TracerWaveEmploymentSample(
                survey: s,
                answers: [
                  for (final r in submitted)
                    _ChedEmploymentAnswer(
                      userId: r.userId,
                      presentlyEmployed: _chedPresentlyEmployed(r.answers),
                      submittedAt: r.submittedAt,
                      answers: r.answers,
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
              answers: r.answers,
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

  /// Tracer tab numbers for the current wave, course and batch filters.
  TracerTabStats _tracerStats(AdminReportsAnalytics a) {
    final key = (
      a,
      _waveEmploymentSamples,
      _dashboardFilters.surveyId,
      _dashboardFilters.course,
      _dashboardFilters.batchYear,
    );
    final cached = _tracerStatsCache;
    if (cached != null && _tracerStatsKey == key) return cached;

    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };
    final samples = [..._waveEmploymentSamples]
      ..sort(
        (x, y) => reportsSurveyDisplayDate(
          x.survey,
        ).compareTo(reportsSurveyDisplayDate(y.survey)),
      );
    final stats = TracerTabStats(
      waves: [
        for (final s in samples)
          (
            surveyId: s.survey.id,
            respondents: [
              for (final ans in s.answers)
                _gtsRespondent(s.survey.id, ans, memberByAuth),
            ],
          ),
      ],
      surveyId: _dashboardFilters.surveyId,
      course: _dashboardFilters.course,
      batch: _dashboardFilters.batchYear,
    );
    _tracerStatsCache = stats;
    _tracerStatsKey = key;
    return stats;
  }

  static GtsRespondent _gtsRespondent(
    String surveyId,
    _ChedEmploymentAnswer ans,
    Map<String, AlumniMember> memberByAuth,
  ) {
    final member = memberByAuth[ans.userId.trim()];
    return GtsRespondent(
      userId: ans.userId.trim(),
      surveyId: surveyId,
      answers: ans.answers,
      course: member?.course ?? '',
      yearGraduated: member?.batchYear ?? '',
      onActiveRoster: member != null,
    );
  }

  /// Item 16 for the current filter: one wave's answers, or each graduate's
  /// latest answer across waves. Null before any answer is loaded.
  ({int employed, int notEmployed, int answered, int waveCount, bool small})?
  _chedEmploymentStatusCounts(AdminReportsAnalytics a) {
    final row = _tracerStats(a).employment;
    if (row.answered == 0) return null;
    final employed = TracerTabStats.yes(row);
    final surveyId = _dashboardFilters.surveyId;
    return (
      employed: employed,
      notEmployed: row.answered - employed,
      answered: row.answered,
      waveCount: _waveEmploymentSamples
          .where((s) => surveyId == null || s.survey.id == surveyId)
          .length,
      small: row.isSmall,
    );
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
              child: ReportsDashboardCanvas(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildDashboardHeader(),
                ),
              ),
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
                          showWaveFilter:
                              tabIndex != 1 || !_tracerWavesMode,
                          includeAllWavesOption: tabIndex != 1,
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
                    top: AdminReportsTheme.space2,
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
                              AdminReportsTheme.space2 -
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
      case 4:
        return _buildBuilderTab(source);
      default:
        return _buildOverviewTab(source, fitHeight: fitHeight);
    }
  }

  Widget _buildDashboardHeader() {
    return ReportsPageHeader(
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

  /// Rounded card-framed underline section tabs (pins cleanly when scrolled).
  Widget _buildTabBar({required bool pinned}) {
    final radius = BorderRadius.circular(AdminSurfaces.radiusMd);
    return AdminTabBar(
      controller: _tabController,
      tabs: [
        for (var i = 0; i < _tabLabels.length; i++)
          AdminTabSpec(
            label: _tabLabels[i],
            icon: _tabIcons[i],
          ),
      ],
      isScrollable: true,
      background: AdminColors.card,
      borderRadius: radius,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      border: Border.all(
        color: AdminColors.border.withValues(alpha: pinned ? 1.0 : 0.9),
      ),
      boxShadow: pinned
          ? AdminSurfaces.cardShadow
          : const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
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
          flex: const [11, 7, 6],
          naturalHeight: 288,
          children: [
            _overviewTrendCard(a),
            _overviewProgramCard(a),
            _overviewFunnelCard(a, coverage),
          ],
        ),
        ReportsBentoRow(
          flex: const [4, 4, 4],
          naturalHeight: 288,
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
        label: 'Alumni list',
        value: '${a.rosterTotal}',
        icon: Icons.groups_outlined,
        accent: UstpColors.blue,
        pillLabel: addedThisMonth > 0
            ? '+$addedThisMonth this month'
            : 'None new this month',
        pillColor: addedThisMonth > 0
            ? AdminReportsTheme.success
            : AdminReportsTheme.textSecondary,
        rows: [
          ReportsStatRow('Registered', '${a.registeredOnRoster}'),
          ReportsStatRow('Unclaimed', '${a.unclaimedRoster}'),
          ReportsStatRow('Registration rate', _pct(a.registrationRate)),
        ],
        details: ReportsDetailsButton.compose(
          definition:
              'Active alumni on the alumni list, and how many already have a '
              'portal account.',
          calculation:
              '${a.registeredOnRoster} registered out of ${a.rosterTotal} on '
              'the alumni list. "This month" counts alumni list records added '
              'since the 1st.',
          scope: scope,
        ),
      ),
      ReportsStatCard(
        label: 'Tracer reach',
        value: _pct(coverage.tracerTakeRateAmongRegistered),
        icon: Icons.school_outlined,
        accent: UstpColors.midBlue,
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
              '"Profile complete" is the alumni list profile flag, not a tracer '
              'submission.',
        ),
      ),
      ReportsStatCard(
        label: 'Survey completion',
        value: _pct(a.surveyResponseRate),
        icon: Icons.poll_outlined,
        accent: UstpColors.skyBlue,
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
      ),
      ReportsStatCard(
        label: 'Employment rate',
        value: hasEmployment ? _pct(a.employmentRateAmongSubmissions) : '—',
        icon: Icons.work_outline,
        accent: UstpColors.blue,
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
      title: 'Alumni list & registration trend',
      caption: 'Cumulative alumni, last 12 months',
      details: ReportsDetailsButton.compose(
        definition:
            'Cumulative alumni list vs registered alumni by the month the alumni list '
            'record was added.',
        scope: 'System-wide.',
        limitation:
            'Registered alumni are plotted by alumni list record date, not by '
            'account sign-up date.',
      ),
      trailing: empty
          ? null
          : const Wrap(
              spacing: 12,
              children: [
                ReportsLegendDot(
                  color: AdminReportsTheme.primary,
                  label: 'Alumni list',
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
              message: 'No alumni list timestamps available yet',
              icon: Icons.show_chart_outlined,
            )
          : ReportsTrendChart(
              labels: labels,
              series: [
                ReportsTrendSeries(
                  label: 'Alumni list',
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
      caption: '${courses.length} programs on the alumni list',
      details: ReportsDetailsButton.compose(
        definition: 'Active alumni list members grouped by their program (course).',
        calculation:
            'Top $maxSlices programs by headcount; the rest are grouped as '
            '"Other programs".',
        scope: 'System-wide.',
      ),
      child: entries.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No alumni on the list yet',
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
      caption: 'Share of the alumni list at each step',
      details: ReportsDetailsButton.compose(
        definition:
            'How far alumni list members have moved: registered a portal account, '
            'submitted a tracer wave, and completed their profile.',
        calculation: 'Each step is shown as a share of the full alumni list.',
        scope: 'System-wide.',
        limitation:
            '"Took tracer" and "Profile complete" are tracked separately, so '
            'the last step can be larger than the one before it.',
      ),
      child: a.rosterTotal == 0
          ? const ReportsChartEmptyState(
              message: 'No alumni on the list yet',
              icon: Icons.filter_alt_outlined,
            )
          : ReportsFunnelBars(
              steps: [
                ReportsFunnelStep(
                  label: 'Alumni list',
                  value: a.rosterTotal,
                  color: UstpColors.blue,
                ),
                ReportsFunnelStep(
                  label: 'Registered',
                  value: a.registeredOnRoster,
                  color: UstpColors.midBlue,
                ),
                ReportsFunnelStep(
                  label: 'Took tracer',
                  value: coverage.tookTracer,
                  color: UstpColors.skyBlue,
                ),
                ReportsFunnelStep(
                  label: 'Profile complete',
                  value: a.tracerCompleteCount,
                  color: UstpColors.gold,
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
        definition: 'Active alumni list members grouped by batch (graduation) year.',
        calculation: 'The largest batch is highlighted in gold.',
        scope: 'System-wide, latest 8 batch years.',
      ),
      child: batches.isEmpty
          ? const ReportsChartEmptyState(
              message: 'No batch years on the alumni list yet',
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
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: AdminColors.primary,
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

  static const _tracerTopicLabels = [
    'School-to-work',
    'Curriculum',
    'Placement',
    'Studies',
    'Waves',
  ];

  /// Tracer: KPI strip plus topic / Waves bento views.
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
                    options: _tracerTopicLabels,
                    selected: _tracerTopic,
                    onChanged: _onTracerTopicChanged,
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
          rows: _tracerWavesMode
              ? _tracerWavesRows(a)
              : _tracerTopicRows(a),
        ),
      ],
    );
  }

  void _onTracerTopicChanged(int i) {
    setState(() {
      _tracerTopic = i;
      if (_tracerWavesMode) {
        // Waves compares all published tracers; keep batch/course only.
        _dashboardFilters = ReportsDashboardFilters(
          batchYear: _dashboardFilters.batchYear,
          course: _dashboardFilters.course,
        );
      } else {
        _ensureTracerOutcomesWaveSelected();
      }
    });
    unawaited(_ensureSelectedWaveSample(_dashboardFilters.surveyId));
  }

  /// Outcomes always scopes to one concrete published tracer.
  void _ensureTracerOutcomesWaveSelected() {
    if (_dashboardFilters.surveyId != null) {
      final stillThere = _surveys.any(
        (s) =>
            s.id == _dashboardFilters.surveyId &&
            s.isChedGtsBuiltin &&
            !s.archived,
      );
      if (stillThere) return;
    }
    final tracers = reportsFilterSurveyOptions(_surveys, tracerOnly: true);
    if (tracers.isEmpty) return;
    // Newest first; preserve batch/course when auto-picking a wave.
    _dashboardFilters = _dashboardFilters.copyWith(surveyId: tracers.first.id);
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
      'Tracer answers of graduates linked to the alumni list with a course '
      '(the graduates Program Insights counts), within the filters you '
      'selected.';

  String get _tracerCountingNote => _tracerWavesMode
      ? 'Each graduate is counted once per wave shown. Groups with fewer '
            'than 5 answers are hidden.'
      : 'Counts are for the selected tracer wave. Groups with fewer than 5 '
            'answers are hidden.';

  static const _notEnoughData =
      'Not enough data: fewer than 5 answers in this filter.';

  String _chedDetails(String definition) => ReportsDetailsButton.compose(
    definition: definition,
    scope: _chedAnswerScope,
    limitation: _tracerCountingNote,
  );

  static const _employedOnlyScope =
      'Only graduates who answered item 16 "Yes" (currently employed), '
      'within the filters you selected.';

  ({int yes, int total, bool small}) _chedYesShare(String questionId) {
    final c = _tracerCounts(questionId);
    return (
      yes: c.small ? 0 : c.counts[ChedGtsBuiltin.yes] ?? 0,
      total: c.answered,
      small: c.small,
    );
  }

  /// [measure]'s answer counts in the current filter. Questionnaire order
  /// (zero bins kept, an unused "Others" dropped), or largest first with
  /// [byCount]. [answered] is the share base; [small] hides the numbers.
  /// [gridColumn] scopes matrix measures such as job level (Q30).
  _TracerCounts _tracerCounts(
    String measure, {
    bool employedOnly = false,
    bool byCount = false,
    int? topN,
    String? gridColumn,
  }) {
    final a = _analytics;
    if (a == null) {
      return (entries: const [], counts: const {}, answered: 0, small: false);
    }
    final result = _tracerStats(a).run(
      measure,
      employedOnly: employedOnly,
      byCount: byCount,
      topN: topN,
      gridColumn: gridColumn,
    );
    final row = result.total;
    return (
      entries: [
        for (final c in result.categories)
          if (c != ChedGtsBuiltin.othersSpecify || (row.counts[c] ?? 0) > 0)
            MapEntry(c, row.counts[c] ?? 0),
      ],
      counts: row.counts,
      answered: row.answered,
      small: row.isSmall,
    );
  }

  static const _jobLevelFirstCol = '30.1. First Job';
  static const _jobLevelPresentCol = '30.2. Current or Present Job';

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
      child: Container(
        height: _viewBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          border: Border.all(color: AdminColors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 15,
              color: _downloadBusy
                  ? AdminColors.textSecondary
                  : AdminColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              _downloadBusy ? 'Exporting…' : 'Export view',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _downloadBusy
                    ? AdminColors.textSecondary
                    : AdminColors.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: _downloadBusy
                  ? AdminColors.textSecondary
                  : AdminColors.primary,
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
    final hidden = answered == 0 || (ched?.small ?? false);
    final employmentRate = hidden ? 0.0 : employed / answered;
    final employmentStatus = hidden
        ? ReportsKpiStatus.neutral
        : reportsKpiStatusFromRate(employmentRate);

    final traced = coverage.tookTracer;
    final assigned = _tracerAssignedForKpi(a);
    // Prefer survey assignments for a single wave; fall back to registered
    // when comparing all waves (assignment sums would double-count people).
    final usesAssignments = !_tracerWavesMode && assigned > 0;
    final denom = usesAssignments ? assigned : coverage.registered;
    final responseRate = denom == 0 ? 0.0 : traced / denom;
    final responseStatus = denom == 0
        ? ReportsKpiStatus.neutral
        : reportsKpiStatusFromRate(responseRate);
    final pending = usesAssignments
        ? (assigned - traced).clamp(0, assigned)
        : coverage.registeredNoTracer;

    return [
      ReportsStatCard(
        label: 'Total traced',
        value: denom == 0 ? '$traced' : '$traced / $denom',
        icon: Icons.assignment_turned_in_outlined,
        accent: UstpColors.blue,
        pillLabel: denom == 0
            ? 'No data'
            : '${_pct(responseRate)} response rate',
        pillColor: reportsStatusColor(responseStatus),
        rows: [
          ReportsStatRow(
            usesAssignments ? 'Assigned' : 'Registered',
            '$denom',
          ),
          ReportsStatRow(
            usesAssignments ? 'Pending assignments' : 'Registered, no tracer',
            '$pending',
          ),
          ReportsStatRow(
            'Share of alumni list',
            _pct(coverage.tracerTakeRateAmongRoster),
          ),
        ],
        details: ReportsDetailsButton.compose(
          definition:
              'Completed tracer submissions in the current filter, shown '
              'against ${usesAssignments ? 'wave assignments' : 'registered alumni'}.',
          calculation: usesAssignments
              ? '$traced submitted ÷ $assigned assigned '
                  '(${_pct(responseRate)} response rate).'
              : '$traced of $denom registered alumni '
                  '(${_pct(responseRate)} response rate). '
                  'Waves mode uses registered alumni as the base so people '
                  'are not double-counted across waves.',
          scope: coverage.waveLabel,
          limitation: coverage.scopedToWave
              ? 'Alumni list is as of this wave’s open/publish date, not '
                  'today’s full list. “Traced” means submitted the wave — '
                  'not the same as “Profile complete” on Overview.'
              : '“Traced” means submitted the wave — not the same as '
                  '“Profile complete” on Overview.',
        ),
      ),
      ReportsStatCard(
        label: 'Employment rate',
        value: hidden ? '—' : _pct(employmentRate),
        icon: Icons.work_outline,
        accent: UstpColors.midBlue,
        pillLabel: answered == 0
            ? 'No data'
            : hidden
            ? 'Not enough data'
            : reportsKpiStatusLabel(employmentStatus),
        pillColor: reportsStatusColor(employmentStatus),
        rows: [
          ReportsStatRow('Employed (Yes)', hidden ? '—' : '$employed'),
          ReportsStatRow(
            'Not / never employed',
            hidden ? '—' : '${ched?.notEmployed ?? 0}',
          ),
          ReportsStatRow('Answered item 16', hidden ? '—' : '$answered'),
        ],
        details: ReportsDetailsButton.compose(
          definition:
              'Share of graduates who said they are currently employed '
              '(item 16) on the tracer.',
          calculation:
              'Employed means "Yes". Not employed means "No" or "Never '
              'employed", so 100% minus this rate is the Program Insights '
              'not-employed rate.',
          scope: scope,
          limitation: _tracerCountingNote,
        ),
      ),
      _yesShareKpi(
        label: 'Degree alignment',
        icon: Icons.school_outlined,
        accent: UstpColors.skyBlue,
        share: _chedYesShare('ched_24a'),
        yesLabel: 'Aligned',
        noLabel: 'Not aligned',
        definition:
            'Share of graduates whose first job relates to the course they '
            'took in college (item 24 / field of study alignment).',
        askedOf:
            'Item 24 is only asked of employed graduates whose current job '
            'is their first job (item 22 = Yes).',
      ),
      _yesShareKpi(
        label: 'Curriculum relevance',
        icon: Icons.menu_book_outlined,
        accent: UstpColors.blue,
        share: _chedYesShare('ched_32'),
        yesLabel: 'Relevant',
        noLabel: 'Not relevant',
        definition:
            'Share of graduates who felt their college curriculum was '
            'relevant to their first job (item 32).',
        askedOf: 'Item 32 is only asked of employed graduates (item 16 = Yes).',
      ),
    ];
  }

  /// Assignment count for the selected tracer wave, or 0 when none / Waves mode.
  int _tracerAssignedForKpi(AdminReportsAnalytics a) {
    final surveyId = _dashboardFilters.surveyId;
    if (surveyId == null) return 0;
    for (final s in a.surveys) {
      if (s.id == surveyId) return a.assignmentCount(s);
    }
    return 0;
  }

  Widget _yesShareKpi({
    required String label,
    required IconData icon,
    required Color accent,
    required ({int yes, int total, bool small}) share,
    required String yesLabel,
    required String noLabel,
    required String definition,
    String? askedOf,
  }) {
    final hidden = share.total == 0 || share.small;
    final rate = hidden ? 0.0 : share.yes / share.total;
    final status = hidden
        ? ReportsKpiStatus.neutral
        : reportsKpiStatusFromRate(rate);
    return ReportsStatCard(
      label: label,
      value: hidden ? '—' : _pct(rate),
      icon: icon,
      accent: accent,
      pillLabel: share.total == 0
          ? 'No data'
          : hidden
          ? 'Not enough data'
          : reportsKpiStatusLabel(status),
      pillColor: reportsStatusColor(status),
      rows: [
        ReportsStatRow(yesLabel, hidden ? '—' : '${share.yes}'),
        ReportsStatRow(noLabel, hidden ? '—' : '${share.total - share.yes}'),
        ReportsStatRow('Answers', hidden ? '—' : '${share.total}'),
      ],
      details: ReportsDetailsButton.compose(
        definition: definition,
        calculation: '"Yes" answers divided by all answers to this question.',
        scope: _chedAnswerScope,
        limitation: [
          ?askedOf,
          _tracerCountingNote,
        ].join(' '),
      ),
    );
  }

  // ── Tracer · Outcomes (single wave, topic tabs) ──

  List<ReportsBentoRow> _tracerTopicRows(AdminReportsAnalytics a) {
    return switch (_tracerTopic) {
      1 => _tracerCurriculumRows(),
      2 => _tracerPlacementRows(a),
      3 => _tracerStudiesRows(),
      4 => _tracerWavesRows(a),
      _ => _tracerSchoolToWorkRows(),
    };
  }

  List<ReportsBentoRow> _tracerSchoolToWorkRows() {
    return [
      ReportsBentoRow(
        flex: const [4, 4, 4],
        naturalHeight: 300,
        children: [
          _bentoDistributionCard(
            title: 'Time to first job',
            details: _chedDetails(
              'How long it took graduates to land their first job '
              '(item 29) on this tracer wave.',
            ),
            data: _tracerCounts('ched_29'),
            emptyMessage: 'No time-to-first-job answers yet',
            emptyIcon: Icons.schedule_outlined,
            color: UstpColors.blue,
          ),
          _bentoDistributionCard(
            title: 'First job after college',
            details: _chedDetails(
              'Whether the present job is the graduate’s first job after '
              'college (item 22).',
            ),
            data: _tracerCounts('ched_22', employedOnly: true),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.work_history_outlined,
            color: UstpColors.midBlue,
            noun: 'employed graduates',
          ),
          _bentoDistributionCard(
            title: 'Duration in first job',
            details: _chedDetails(
              'How long graduates stayed in their first job (item 27) on '
              'this tracer wave.',
            ),
            data: _tracerCounts('ched_27', employedOnly: true),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.timelapse_outlined,
            color: UstpColors.darkNavy,
            noun: 'employed graduates',
          ),
        ],
      ),
      ReportsBentoRow(
        flex: const [6, 6],
        naturalHeight: 300,
        children: [
          _tracerJobLevelCard(),
          _bentoDistributionCard(
            title: 'Job search channels',
            details: ReportsDetailsButton.compose(
              definition:
                  'How graduates found their first job (item 28) among '
                  'those currently employed on this wave.',
              scope: _employedOnlyScope,
              limitation: _tracerCountingNote,
            ),
            data: _tracerCounts('ched_28', employedOnly: true, byCount: true),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.travel_explore_outlined,
            color: UstpColors.midBlue,
            noun: 'employed graduates',
          ),
        ],
      ),
    ];
  }

  List<ReportsBentoRow> _tracerCurriculumRows() {
    return [
      ReportsBentoRow(
        flex: const [6, 6],
        naturalHeight: 204,
        children: [
          _bentoDistributionCard(
            title: 'Curriculum relevance',
            details: _chedDetails(
              'Whether graduates felt the college curriculum was relevant '
              'to their first job (item 32).',
            ),
            data: _tracerCounts('ched_32', employedOnly: true),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.menu_book_outlined,
            color: UstpColors.blue,
            noun: 'employed graduates',
          ),
          _bentoDistributionCard(
            title: 'First job related to course',
            details: _chedDetails(
              'Whether the first job related to the course taken in college '
              '(item 24).',
            ),
            data: _tracerCounts('ched_24a'),
            emptyMessage: 'No course-relatedness answers yet',
            emptyIcon: Icons.school_outlined,
            color: UstpColors.midBlue,
          ),
        ],
      ),
      ReportsBentoRow(
        flex: const [12],
        naturalHeight: 308,
        children: [
          _bentoDistributionCard(
            title: 'Useful competencies',
            details: ReportsDetailsButton.compose(
              definition:
                  'Competencies from college that graduates found useful '
                  'in their first job (item 33). Graduates may select more '
                  'than one.',
              scope:
                  'Asked when curriculum was marked relevant (item 32 = Yes), '
                  'among employed graduates in the selected filters.',
              limitation: _tracerCountingNote,
            ),
            data: _tracerCounts('ched_33', byCount: true),
            emptyMessage: 'No competency answers yet',
            emptyIcon: Icons.psychology_outlined,
            color: UstpColors.blue,
          ),
        ],
      ),
    ];
  }

  List<ReportsBentoRow> _tracerPlacementRows(AdminReportsAnalytics a) {
    return [
      ReportsBentoRow(
        flex: const [4, 4, 4],
        naturalHeight: 300,
        children: [
          _tracerStatusCard(a),
          _tracerEmploymentTypeCard(),
          _bentoDistributionCard(
            title: 'Place of work',
            details: ReportsDetailsButton.compose(
              definition:
                  'Where employed graduates work: local or abroad (item 21) '
                  'on this tracer wave.',
              scope: _employedOnlyScope,
              limitation: _tracerCountingNote,
            ),
            data: _tracerCounts('ched_21', employedOnly: true),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.place_outlined,
            color: UstpColors.darkNavy,
            noun: 'employed graduates',
          ),
        ],
      ),
      ReportsBentoRow(
        flex: const [4, 4, 4],
        naturalHeight: 300,
        children: [
          _bentoDistributionCard(
            title: 'Industry (employed)',
            details: ReportsDetailsButton.compose(
              definition:
                  'Top 10 industries or sectors (item 20) reported by '
                  'currently employed graduates on this tracer wave.',
              scope: _employedOnlyScope,
              limitation: _tracerCountingNote,
            ),
            data: _tracerCounts(
              'ched_20',
              employedOnly: true,
              byCount: true,
              topN: 10,
            ),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.factory_outlined,
            color: UstpColors.blue,
            noun: 'employed graduates',
          ),
          _bentoDistributionCard(
            title: 'Initial monthly earning',
            details: ReportsDetailsButton.compose(
              definition:
                  'Initial gross monthly earning in the first job (item 31), '
                  'among graduates who are currently employed on this wave.',
              scope: _employedOnlyScope,
              limitation: _tracerCountingNote,
            ),
            data: _tracerCounts('ched_31', employedOnly: true),
            emptyMessage: _noChedEmployedDetails,
            emptyIcon: Icons.payments_outlined,
            color: UstpColors.midBlue,
            noun: 'employed graduates',
          ),
          _bentoDistributionCard(
            title: 'Reasons not employed',
            details: _chedDetails(
              'Reasons graduates gave for not being employed yet (item 17) '
              'on this tracer wave.',
            ),
            data: _tracerCounts('ched_17', byCount: true),
            emptyMessage: 'No not-employed reason answers yet',
            emptyIcon: Icons.person_off_outlined,
            color: UstpColors.darkNavy,
          ),
        ],
      ),
      ReportsBentoRow(
        flex: const [12],
        naturalHeight: 300,
        children: [_tracerMobilityCard()],
      ),
      ReportsBentoRow(
        flex: const [6, 6],
        naturalHeight: 280,
        children: [
          _tracerGroupRateCard(a, byBatch: true),
          _tracerGroupRateCard(a, byBatch: false),
        ],
      ),
    ];
  }

  List<ReportsBentoRow> _tracerStudiesRows() {
    return [
      ReportsBentoRow(
        flex: const [12],
        naturalHeight: 320,
        children: [
          _bentoDistributionCard(
            title: 'Reasons for advanced studies',
            details: ReportsDetailsButton.compose(
              definition:
                  'Reasons graduates gave for pursuing advance studies '
                  '(item 15b) on this tracer wave.',
              scope: _chedAnswerScope,
              limitation:
                  '$_tracerCountingNote Professional exam tables (item 13) '
                  'and training lists (item 15a) are available from the '
                  'survey Excel pack, not as charts here.',
            ),
            data: _tracerCounts('ched_15b', byCount: true),
            emptyMessage: 'No further-studies responses yet',
            emptyIcon: Icons.menu_book_outlined,
            color: UstpColors.blue,
          ),
        ],
      ),
    ];
  }

  Widget _tracerMobilityCard() {
    const specs = <(String, String, String)>[
      (
        'Reasons for staying',
        'ched_23',
        'Reasons employed graduates gave for staying on the job (item 23).',
      ),
      (
        'Reasons for accepting',
        'ched_24b',
        'Reasons graduates gave for accepting the job (item 25).',
      ),
      (
        'Reasons for changing',
        'ched_25',
        'Reasons graduates gave for changing jobs (item 26).',
      ),
    ];
    final spec = specs[_mobilityTab.clamp(0, specs.length - 1)];
    final data = _tracerCounts(spec.$2, byCount: true);
    final answered = data.answered;
    return ReportsBentoCard(
      title: 'Retention & job change reasons',
      caption: answered == 0 || data.small
          ? null
          : 'n = $answered graduates',
      details: ReportsDetailsButton.compose(
        definition: spec.$3,
        scope: _chedAnswerScope,
        limitation: _tracerCountingNote,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ReportsSegmentedToggle(
              options: const ['Stay', 'Accept', 'Change'],
              selected: _mobilityTab,
              onChanged: (i) => setState(() => _mobilityTab = i),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: answered == 0
                ? ReportsChartEmptyState(
                    message: 'No ${spec.$1.toLowerCase()} answers yet',
                    icon: Icons.swap_horiz_outlined,
                  )
                : data.small
                ? const ReportsChartEmptyState(
                    message: _notEnoughData,
                    icon: Icons.swap_horiz_outlined,
                  )
                : ReportsProgressList(
                    items: [
                      for (final e in data.entries)
                        if (e.value > 0)
                          ReportsProgressItem(
                            label: e.key,
                            detail: '${e.value}',
                            fraction: e.value / answered,
                            color: AdminReportsTheme.primary,
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tracerJobLevelCard() {
    final column =
        _jobLevelTab == 0 ? _jobLevelFirstCol : _jobLevelPresentCol;
    final data = _tracerCounts(
      'ched_30',
      employedOnly: true,
      gridColumn: column,
    );
    final answered = data.answered;
    return ReportsBentoCard(
      title: 'Job level position',
      caption: answered == 0 || data.small
          ? null
          : 'n = $answered employed graduates',
      details: ReportsDetailsButton.compose(
        definition:
            'Job level on the first job versus the current or present job '
            '(item 30). Each graduate ticks one level per column.',
        scope: _employedOnlyScope,
        limitation: _tracerCountingNote,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ReportsSegmentedToggle(
              options: const ['First job', 'Present job'],
              selected: _jobLevelTab,
              onChanged: (i) => setState(() => _jobLevelTab = i),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: answered == 0
                ? const ReportsChartEmptyState(
                    message: _noChedEmployedDetails,
                    icon: Icons.stairs_outlined,
                  )
                : data.small
                ? const ReportsChartEmptyState(
                    message: _notEnoughData,
                    icon: Icons.stairs_outlined,
                  )
                : ReportsProgressList(
                    items: [
                      for (final e in data.entries)
                        if (e.value > 0)
                          ReportsProgressItem(
                            label: e.key,
                            detail: '${e.value}',
                            fraction: e.value / answered,
                            color: AdminReportsTheme.primary,
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tracerRateByWaveCard(AdminReportsAnalytics a) {
    final points = _employmentRateByWavePoints(a);
    final Widget child;
    if (points.length < 2) {
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
            color: UstpColors.blue,
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
      caption: '${points.length} waves in chronological order',
      details: ReportsDetailsButton.compose(
        definition:
            'Share of graduates who said they are currently employed, shown '
            'for each published tracer. Optional batch and course filters '
            'apply across every wave.',
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
    final employed = ched?.employed ?? a.employedCount;
    final notEmployed = ched?.notEmployed ?? a.unemployedCount;
    final total = employed + notEmployed;
    final details = ched != null
        ? ReportsDetailsButton.compose(
            definition:
                'Share of graduates on this tracer wave who said they are '
                'currently employed.',
            calculation:
                'Employed means "Yes". Not employed means "No" or "Never '
                'employed".',
            scope: _tracerScope(a),
            limitation: _tracerCountingNote,
          )
        : ReportsDetailsButton.compose(
            definition:
                'Employed versus not employed among alumni who submitted '
                'employment information.',
            calculation: AdminReportsAnalytics.employmentRateDefinition,
            scope:
                'Uses employment submissions on file while tracer answers load.',
          );
    final small = ched?.small ?? false;
    return ReportsBentoCard(
      title: 'Employment status',
      caption: total == 0 || small ? null : _sampleCaption(total, 'answers'),
      details: details,
      child: small
          ? const ReportsChartEmptyState(
              message: _notEnoughData,
              icon: Icons.work_outline,
            )
          : total == 0
          ? ReportsChartEmptyState(
              message: ched == null
                  ? 'No employment submissions yet'
                  : 'No presently-employed answers on this tracer wave yet',
              icon: Icons.work_outline,
            )
          : ReportsDonutBreakdown(
              pie: true,
              entries: [
                ReportsDonutEntry(
                  label: 'Employed',
                  value: employed,
                  color: UstpColors.blue,
                ),
                ReportsDonutEntry(
                  label: 'Not employed',
                  value: notEmployed,
                  color: UstpColors.gold,
                ),
              ],
            ),
    );
  }

  Widget _tracerEmploymentTypeCard() {
    final types = _tracerCounts('ched_18', employedOnly: true, byCount: true);
    final total = types.answered;
    return ReportsBentoCard(
      title: 'Employment type',
      caption: total == 0 || types.small
          ? null
          : 'n = $total employed graduates',
      details: ReportsDetailsButton.compose(
        definition:
            'How employed graduates describe their present job status '
            '(item 18), for example regular, temporary, contractual or '
            'self-employed.',
        scope: _employedOnlyScope,
        limitation: _tracerCountingNote,
      ),
      child: total == 0
          ? const ReportsChartEmptyState(
              message: _noChedEmployedDetails,
              icon: Icons.badge_outlined,
            )
          : types.small
          ? const ReportsChartEmptyState(
              message: _notEnoughData,
              icon: Icons.badge_outlined,
            )
          : ReportsDonutBreakdown(
              pie: true,
              entries: _donutEntries(types.entries),
            ),
    );
  }

  /// Bars of [data]; each bar is its share of the graduates who answered.
  Widget _bentoDistributionCard({
    required String title,
    required String details,
    required _TracerCounts data,
    required String emptyMessage,
    required Color color,
    IconData emptyIcon = Icons.bar_chart_outlined,
    String noun = 'graduates',
  }) {
    final answered = data.answered;
    return ReportsBentoCard(
      title: title,
      caption: answered == 0 || data.small ? null : 'n = $answered $noun',
      details: details,
      child: answered == 0
          ? ReportsChartEmptyState(message: emptyMessage, icon: emptyIcon)
          : data.small
          ? ReportsChartEmptyState(message: _notEnoughData, icon: emptyIcon)
          : ReportsProgressList(
              items: [
                for (final e in data.entries)
                  if (e.value > 0)
                    ReportsProgressItem(
                      label: e.key,
                      detail: '${e.value}',
                      fraction: e.value / answered,
                      color: color,
                    ),
              ],
            ),
    );
  }

  // ── Tracer · Waves (compare all published tracers) ──

  List<ReportsBentoRow> _tracerWavesRows(AdminReportsAnalytics a) {
    return [
      ReportsBentoRow(
        flex: const [5, 7],
        naturalHeight: 300,
        children: [
          _tracerRateByWaveCard(a),
          _tracerWaveBarsCard(a),
        ],
      ),
      ReportsBentoRow(
        flex: const [12],
        naturalHeight: 320,
        children: [_tracerLongitudinalCard(a)],
      ),
    ];
  }

  Widget _tracerWaveBarsCard(AdminReportsAnalytics a) {
    final points = _employmentRateByWavePoints(a);
    return ReportsBentoCard(
      title: 'By published tracer',
      caption: points.isEmpty ? null : 'Tap a bar to list respondents',
      details: ReportsDetailsButton.compose(
        definition:
            'Compares each published tracer: how many answered, and how many '
            'said they are employed. Optional batch and course filters apply '
            'across every wave.',
        calculation:
            'The rate is employed ÷ answers. Tap a bar to see who answered.',
      ),
      trailing: points.isEmpty
          ? null
          : const Wrap(
              spacing: 10,
              children: [
                ReportsLegendDot(
                  color: UstpColors.blue,
                  label: 'Answers',
                ),
                ReportsLegendDot(
                  color: UstpColors.gold,
                  label: 'Employed',
                ),
              ],
            ),
      child: points.isEmpty
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
                  color: UstpColors.blue,
                  values: [for (final p in points) p.answered],
                ),
                ReportsBarSeries(
                  label: 'Employed',
                  color: UstpColors.gold,
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
    final groupBy = byBatch
        ? GtsFieldDictionary.yearGraduated
        : GtsFieldDictionary.course;
    final grouped =
        [
          for (final row in _tracerStats(a).run('ched_16', groupBy: groupBy).rows)
            if (row.answered > 0) row,
        ]..sort((x, y) => y.answered.compareTo(x.answered));
    final total = grouped.fold<int>(0, (s, r) => s + r.answered);
    return ReportsBentoCard(
      title: byBatch ? 'Employment by batch' : 'Employment by course',
      caption: total == 0 ? null : 'n = $total answers',
      details: ReportsDetailsButton.compose(
        definition: byBatch
            ? 'Employment answers grouped by the graduation year on the '
                  'alumni list.'
            : 'Employment answers grouped by the course on the alumni list.',
        calculation:
            'Employed ("Yes" on item 16) ÷ graduates who answered, per '
            'group. Tap a row to see who answered.',
        scope: _chedAnswerScope,
        limitation: _tracerCountingNote,
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
                for (final r in grouped.take(8))
                  if (r.groupValues.first case final label)
                    r.isSmall
                        ? ReportsProgressItem(
                            label: label,
                            detail: 'Not enough data',
                            fraction: 0,
                            color: AdminReportsTheme.textSecondary,
                          )
                        : ReportsProgressItem(
                            label: label,
                            detail: '${TracerTabStats.yes(r)}/${r.answered}',
                            fraction: TracerTabStats.yes(r) / r.answered,
                            color: reportsStatusColor(
                              reportsKpiStatusFromRate(
                                TracerTabStats.yes(r) / r.answered,
                              ),
                            ),
                            onTap: () => unawaited(
                              _openCohortRespondentsDialog(
                                a,
                                groupBy: groupBy,
                                groupLabel: label,
                              ),
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
        definition:
            'Lists graduates who answered at least two tracer surveys. '
            'Optional batch and course filters still apply.',
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _scopePill(scope)),
              const SizedBox(width: 8),
              _bentoLink(
                'Open Surveys',
                () => _openAdminMenuOr(10, 2),
              ),
              const SizedBox(width: 6),
              _bentoLink('Downloads', () => _selectTab(3)),
            ],
          ),
        ),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsBentoGrid(
          fitHeight: gridFit,
          kpis: _surveyKpis(a, scope),
          rows: [
            ReportsBentoRow(
              flex: const [10, 7, 7],
              naturalHeight: 300,
              children: [
                _surveyParticipationCard(a),
                _surveySplitCard(a),
                _surveyFollowUpCard(a),
              ],
            ),
            ReportsBentoRow(
              flex: const [6, 6],
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
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            border: Border.all(color: AdminColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 13,
                color: AdminColors.primary,
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
                    color: AdminColors.primary,
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
        accent: UstpColors.blue,
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
        accent: UstpColors.midBlue,
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
        accent: UstpColors.skyBlue,
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
        accent: UstpColors.blue,
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
                  () {
                    final title =
                        s.title.trim().isEmpty ? 'Survey' : s.title.trim();
                    return title.length > 10
                        ? '${title.substring(0, 9)}…'
                        : title;
                  }(),
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
                  color: UstpColors.blue,
                ),
                ReportsDonutEntry(
                  label: 'Pending',
                  value: pending,
                  color: UstpColors.gold,
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
                        ? AdminReportsTheme.textSecondary
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

  Widget _buildBuilderTab(AdminReportsAnalytics a) {
    DateTime opened(Survey s) => s.publishedAt ?? s.openAt ?? s.createdAt;
    final waves =
        a.surveys
            .where(
              (s) =>
                  s.isChedGtsBuiltin &&
                  !s.archived &&
                  (s.status == SurveyStatus.published ||
                      s.status == SurveyStatus.closed),
            )
            .toList()
          ..sort((x, y) => opened(y).compareTo(opened(x)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GtsBuilderModeSwitch(
          mode: _builderMode,
          onChanged: (m) => setState(() => _builderMode = m),
        ),
        const SizedBox(height: 16),
        switch (_builderMode) {
          GtsBuilderMode.list => GtsAlumniListPanel(
            waves: waves,
            roster: a.members,
            responseCache: _listResponses,
            initialConfig: _listConfig,
            onConfigChanged: (c) => _listConfig = c,
            savedReports: _savedReports,
            initialOpen: _listOpen,
            onOpenChanged: (r) => _listOpen = r,
            onOpenSummary: _openSavedInMode,
          ),
          GtsBuilderMode.summary => GtsReportBuilderPanel(
            waves: waves,
            savedReports: _savedReports,
            respondentCache: _builderRespondents,
            initialConfig: _builderConfig,
            onConfigChanged: (c) => _builderConfig = c,
            initialOpen: _builderOpen,
            onOpenChanged: (r) => _builderOpen = r,
            onOpenList: _openSavedInMode,
          ),
        },
      ],
    );
  }

  CustomReportFilters _presetExportFilters([
    ReportFilterSelection? selection,
  ]) {
    final batch = selection?.batchYear ?? _dashboardFilters.batchYear;
    final course = selection?.course ?? _dashboardFilters.course;
    return CustomReportFilters(
      batchYears: [if (batch != null && batch.trim().isNotEmpty) batch],
      courses: [if (course != null && course.trim().isNotEmpty) course],
      registration: CustomReportRegistrationFilter.values.firstWhere(
        (e) => e.name == selection?.registrationStatus,
        orElse: () => CustomReportRegistrationFilter.all,
      ),
      tracer: CustomReportTracerFilter.values.firstWhere(
        (e) => e.name == selection?.tracerStatus,
        orElse: () => CustomReportTracerFilter.all,
      ),
      employment: CustomReportEmploymentFilter.values.firstWhere(
        (e) => e.name == selection?.employmentStatus,
        orElse: () => CustomReportEmploymentFilter.all,
      ),
    );
  }

  ReportFilterSelection _seedDownloadFilters() => ReportFilterSelection(
        batchYear: _dashboardFilters.batchYear,
        course: _dashboardFilters.course,
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
      // Question summaries only ship in the CHED pack, which uses CHED waves.
      final chedQuestions = CustomReportExportService.buildDocument(
        template: CustomReportTemplate(
          id: 'preset_preview_ched',
          name: 'Preview',
          sections: const [CustomReportSectionId.surveyQuestions],
          format: CustomReportFormat.pdf,
          filters: _presetExportFilters(),
          createdAt: now,
          updatedAt: now,
        ),
        analytics: a,
        events: _allEvents,
        jobs: _jobs,
        rollups: _chedRollups(),
        profilesByAuthUid: _registeredProfiles,
      ).sections.single;
      counts = {
        for (final s in [
          ...doc.sections.where(
            (s) => s.id != CustomReportSectionId.surveyQuestions,
          ),
          chedQuestions,
        ])
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
          color: _navy,
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
          color: AdminColors.warning,
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
          color: _navy,
          title: '${a.unclaimedRoster} alumni list members not registered',
          subtitle:
              '${a.registeredOnRoster}/${a.rosterTotal} have portal accounts',
          actionLabel: 'Alumni directory',
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
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AdminColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            border: Border.all(color: AdminColors.border.withValues(alpha: 0.8)),
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
                        color: AdminReportsTheme.textSecondary,
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

  /// Item 16 per wave in the current course and batch filters; waves with
  /// fewer than 5 answers are left out.
  List<_WaveEmploymentRatePoint> _employmentRateByWavePoints(
    AdminReportsAnalytics a,
  ) {
    final surveys = {for (final s in _waveEmploymentSamples) s.survey.id: s};
    return [
      for (final w in _tracerStats(a).employmentByWave())
        if (surveys[w.surveyId]?.survey case final survey?)
          if (w.row.answered > 0 && !w.row.isSmall)
            _WaveEmploymentRatePoint(
              surveyId: w.surveyId,
              label: survey.title,
              shortLabel: _waveShortLabel(survey),
              rate: TracerTabStats.yes(w.row) / w.row.answered * 100,
              employed: TracerTabStats.yes(w.row),
              answered: w.row.answered,
              createdAt: survey.createdAt,
            ),
    ];
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

  List<SurveyReportRollup> _chedRollups() => [
    for (final r in _surveyRollups)
      if (r.survey.isChedGtsBuiltin) r,
  ];

  /// Per-wave CHED question rollups for the Tracer tab filters: the selected
  /// wave only, counting only respondents inside the batch / course filters.
  List<SurveyReportRollup> _tracerViewRollups() {
    final source = _analytics;
    if (source == null) return const [];
    final surveyId = _dashboardFilters.surveyId;
    final batch = _dashboardFilters.batchYear?.trim().toLowerCase();
    final course = _dashboardFilters.course?.trim().toLowerCase();
    final memberByAuth = <String, AlumniMember>{
      for (final m in source.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };

    return [
      for (final sample in _waveEmploymentSamples)
        if (surveyId == null || sample.survey.id == surveyId)
          SurveyReportRollup(
            survey: sample.survey,
            aggregates: SurveyReportAnalytics.aggregateChedResponses(
              responses: [
                for (final ans in sample.answers)
                  if (_respondentMatchesCohort(
                    userId: ans.userId,
                    batch: batch,
                    course: course,
                    memberByAuth: memberByAuth,
                  ))
                    SurveyResponse(
                      surveyId: sample.survey.id,
                      userId: ans.userId,
                      answers: ans.answers,
                      status: SurveyResponseStatus.submitted,
                      submittedAt: ans.submittedAt,
                      updatedAt: ans.submittedAt ?? sample.survey.createdAt,
                    ),
              ],
            ),
          ),
    ];
  }

  static const _noChedEmployedDetails =
      'No employed graduates in this filter yet. '
      'This chart only includes alumni who said they are currently employed.';

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
        if (!_gtsRespondent(
              sample.survey.id,
              ans,
              memberByAuth,
            ).isRosterLinked ||
            !_respondentMatchesCohort(
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
    required String groupBy,
    required String groupLabel,
  }) async {
    final rows = <TracerRespondentRow>[
      for (final r in _tracerStats(a).membersOf(groupBy, groupLabel))
        if (r.answers['ched_16']?.toString().trim() ?? '' case final status
            when status.isNotEmpty)
          TracerRespondentRow(
            userId: r.userId,
            displayName: _displayNameForUid(a, r.userId),
            subtitle: groupLabel,
            status: status,
          ),
    ];
    rows.sort(
      (x, y) =>
          x.displayName.toLowerCase().compareTo(y.displayName.toLowerCase()),
    );
    await showTracerRespondentsDialog(
      context: context,
      title: groupLabel,
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
        if (!_gtsRespondent(
              sample.survey.id,
              ans,
              memberByAuth,
            ).isRosterLinked ||
            !_respondentMatchesCohort(
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
    final wavesView = _tracerWavesMode;
    final title = wavesView
        ? 'Tracer waves comparison (filtered)'
        : 'Tracer outcomes (filtered)';
    final preset = ReportsDownloadPreset(
      id: 'tracer_view',
      title: title,
      description: wavesView
          ? 'Export of cross-wave Tracer comparison with current batch/course '
                'filters.'
          : 'Export of the selected tracer wave with current batch/course '
                'filters.',
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

    var activeFormat = format;
    var activePrint = printPreview;
    var selection = _seedDownloadFilters();
    if (preset.needsConfigDialog) {
      final configured = await showReportsDownloadConfigDialog(
        context: context,
        preset: preset,
        initialFormat: format,
        printPreview: printPreview,
        batchYears: reportsFilterBatchOptions(a.members),
        chedWaves: _chedComparisonWaves(a),
        initialFilters: selection,
      );
      if (configured == null || !mounted) return;
      selection = configured.filters;
      activeFormat = configured.format;
      activePrint = configured.printPreview;
    }

    if (InstitutionalChedTemplates.isOutcomePreset(preset.id)) {
      await _downloadInstitutionalChedOutcomeReport(
        a,
        presetId: preset.id,
        format: activeFormat,
        printPreview: activePrint,
        filters: selection,
      );
      return;
    }

    if (preset.id == InstitutionalChedTemplates.gtsParticipationQuality) {
      await _downloadGtsParticipationQuality(
        a,
        format: activeFormat,
        printPreview: activePrint,
        filters: selection,
      );
      return;
    }

    final personal = preset.sections.any(
      CustomReportExportService.personalSections.contains,
    );
    if (personal &&
        (!await confirmPersonalDataExport(
              context,
              what: 'The ${preset.title} file',
            ) ||
            !mounted)) {
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
        format: activeFormat,
        filters: _presetExportFilters(selection),
        createdAt: now,
        updatedAt: now,
      );

      final doc = CustomReportExportService.buildDocument(
        template: template,
        analytics: a,
        events: _allEvents,
        jobs: _jobs,
        rollups: switch (preset.id) {
          'tracer_view' => _tracerViewRollups(),
          'ched' => _chedRollups(),
          _ => _surveyRollups,
        },
        profilesByAuthUid: _registeredProfiles,
      );

      if (activePrint) {
        final bytes = await CustomReportExportService.toPdf(doc);
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: doc.title);
        return;
      }

      final bytes = await CustomReportExportService.exportBytes(
        doc: doc,
        format: activeFormat,
      );
      if (!mounted) return;
      final stem = preset.catalogId == null
          ? 'AESS_Report'
          : (AessReportCatalog.byId(preset.catalogId!)?.fileNameStem ??
              'AESS_Report');
      final ok = tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName: ReportFileNames.dated(
          stem: stem,
          extension: activeFormat.fileExtension,
          cohortScope: ReportFileNames.cohortScopeLabel(
            batchYear: selection.batchYear,
            course: selection.course,
          ),
          at: now,
        ),
        mimeType: activeFormat.mimeType,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded ${preset.title} (${activeFormat.label}).',
            ),
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

  Future<
      ({
        List<Survey> waves,
        Map<String, List<SurveyResponse>> responsesBySurveyId,
        Map<String, AlumniMember> memberByAuth,
        int assigned,
        int submitted,
        int pending,
      })?
  > _loadInstitutionalChedScope(
    AdminReportsAnalytics a,
    ReportFilterSelection filters,
  ) async {
    final allWaves = _chedComparisonWaves(a);
    if (allWaves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Need at least one Official CHED GTS wave with submissions.',
          ),
        ),
      );
      return null;
    }

    final selected = filters.surveyIds.isEmpty
        ? allWaves
        : allWaves
            .where((s) => filters.surveyIds.contains(s.id))
            .toList(growable: false);
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one Official CHED wave.')),
      );
      return null;
    }

    final batch = filters.batchYear?.trim().toLowerCase();
    final course = filters.course?.trim().toLowerCase();
    final memberByAuth = <String, AlumniMember>{
      for (final m in a.activeRoster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };

    final responsesBySurveyId = <String, List<SurveyResponse>>{};
    var assigned = 0;
    var submitted = 0;
    for (final survey in selected) {
      final responses = await _surveyService.getSurveyResponses(survey.id);
      final submittedRows = responses
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
      responsesBySurveyId[survey.id] = submittedRows;
      submitted += submittedRows.length;
      final waveAssigned =
          a.assignmentCountsBySurveyId[survey.id] ?? survey.assignmentCount;
      assigned += waveAssigned;
    }
    final pending = (assigned - submitted).clamp(0, assigned);
    return (
      waves: selected,
      responsesBySurveyId: responsesBySurveyId,
      memberByAuth: memberByAuth,
      assigned: assigned,
      submitted: submitted,
      pending: pending,
    );
  }

  Future<void> _downloadInstitutionalChedOutcomeReport(
    AdminReportsAnalytics a, {
    required String presetId,
    required CustomReportFormat format,
    required bool printPreview,
    required ReportFilterSelection filters,
  }) async {
    setState(() => _downloadBusy = true);
    try {
      final scope = await _loadInstitutionalChedScope(a, filters);
      if (scope == null || !mounted) return;

      final title = InstitutionalChedTemplates.reportTitle(presetId);
      final summary = InstitutionalGtsSummaryService.build(
        waves: scope.waves,
        responsesBySurveyId: scope.responsesBySurveyId,
        assigned: scope.assigned,
        submitted: scope.submitted,
        pending: scope.pending,
        batchFilter: filters.batchYear,
        courseFilter: filters.course,
        fields: InstitutionalChedTemplates.fieldsFor(presetId),
        reportTitle: title,
        sectionTwoTitle: InstitutionalChedTemplates.sectionTwoTitle(presetId),
      );
      final stem = InstitutionalChedTemplates.fileStem(presetId);

      // T5 compliance pack always includes a batch/program comparison section.
      final InstitutionalCohortComparisonReport? cohort =
          presetId == InstitutionalChedTemplates.chedComplianceMaster
              ? InstitutionalCohortComparisonService.build(
                  waves: scope.waves,
                  responsesBySurveyId: scope.responsesBySurveyId,
                  memberByAuth: scope.memberByAuth,
                  dimension: filters.surveyType == 'course'
                      ? InstitutionalCompareDimension.course
                      : InstitutionalCompareDimension.batch,
                  batchFilter: filters.batchYear,
                  courseFilter: filters.course,
                )
              : null;

      if (printPreview || format == CustomReportFormat.pdf) {
        final bytes = await InstitutionalGtsSummaryService.toPdf(
          summary,
          cohortComparison: cohort,
        );
        if (!mounted) return;
        if (printPreview) {
          await Printing.layoutPdf(onLayout: (_) async => bytes, name: title);
          return;
        }
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: ReportFileNames.dated(
            stem: stem,
            extension: 'pdf',
            cohortScope: ReportFileNames.cohortScopeLabel(
              batchYear: filters.batchYear,
              course: filters.course,
            ),
          ),
          mimeType: 'application/pdf',
        );
      } else if (format == CustomReportFormat.excel) {
        final bytes = InstitutionalGtsSummaryService.toExcel(
          summary,
          cohortComparison: cohort,
        );
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: ReportFileNames.dated(
            stem: stem,
            extension: 'xlsx',
            cohortScope: ReportFileNames.cohortScopeLabel(
              batchYear: filters.batchYear,
              course: filters.course,
            ),
          ),
          mimeType: format.mimeType,
        );
      } else {
        final bytes = InstitutionalGtsSummaryService.toCsvBytes(
          summary,
          cohortComparison: cohort,
        );
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: ReportFileNames.dated(
            stem: stem,
            extension: 'csv',
            cohortScope: ReportFileNames.cohortScopeLabel(
              batchYear: filters.batchYear,
              course: filters.course,
            ),
          ),
          mimeType: format.mimeType,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $title (${format.label}).')),
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

  Future<void> _downloadGtsParticipationQuality(
    AdminReportsAnalytics a, {
    required CustomReportFormat format,
    required bool printPreview,
    required ReportFilterSelection filters,
  }) async {
    setState(() => _downloadBusy = true);
    try {
      final scope = await _loadInstitutionalChedScope(a, filters);
      if (scope == null || !mounted) return;

      final assignedBySurveyId = <String, int>{
        for (final w in scope.waves)
          w.id: a.assignmentCountsBySurveyId[w.id] ?? w.assignmentCount,
      };
      final report = InstitutionalGtsParticipationQualityService.build(
        waves: scope.waves,
        responsesBySurveyId: scope.responsesBySurveyId,
        assignedBySurveyId: assignedBySurveyId,
        batchFilter: filters.batchYear,
        courseFilter: filters.course,
      );
      final title = InstitutionalChedTemplates.reportTitle(
        InstitutionalChedTemplates.gtsParticipationQuality,
      );
      final stem = InstitutionalChedTemplates.fileStem(
        InstitutionalChedTemplates.gtsParticipationQuality,
      );

      if (printPreview || format == CustomReportFormat.pdf) {
        final bytes =
            await InstitutionalGtsParticipationQualityService.toPdf(report);
        if (!mounted) return;
        if (printPreview) {
          await Printing.layoutPdf(onLayout: (_) async => bytes, name: title);
          return;
        }
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: ReportFileNames.dated(
            stem: stem,
            extension: 'pdf',
            cohortScope: ReportFileNames.cohortScopeLabel(
              batchYear: filters.batchYear,
              course: filters.course,
            ),
          ),
          mimeType: 'application/pdf',
        );
      } else if (format == CustomReportFormat.excel) {
        final bytes =
            InstitutionalGtsParticipationQualityService.toExcel(report);
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: ReportFileNames.dated(
            stem: stem,
            extension: 'xlsx',
            cohortScope: ReportFileNames.cohortScopeLabel(
              batchYear: filters.batchYear,
              course: filters.course,
            ),
          ),
          mimeType: format.mimeType,
        );
      } else {
        final bytes =
            InstitutionalGtsParticipationQualityService.toCsvBytes(report);
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: ReportFileNames.dated(
            stem: stem,
            extension: 'csv',
            cohortScope: ReportFileNames.cohortScopeLabel(
              batchYear: filters.batchYear,
              course: filters.course,
            ),
          ),
          mimeType: format.mimeType,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $title (${format.label}).')),
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

/// One measure's counts on the Tracer tab; [small] means fewer than 5
/// answers, so the numbers are not shown.
typedef _TracerCounts = ({
  List<MapEntry<String, int>> entries,
  Map<String, int> counts,
  int answered,
  bool small,
});

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
    this.answers = const {},
  });

  final String userId;
  final String? presentlyEmployed;
  final DateTime? submittedAt;

  /// Full CHED answer map of this submission.
  final Map<String, dynamic> answers;
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
