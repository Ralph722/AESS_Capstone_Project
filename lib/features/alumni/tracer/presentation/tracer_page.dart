import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_contacts.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/alumni/tracer/data/tracer_reminder_service.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/tracer_history_screen.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/tracer_reminder_sheet.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/tracer_intro_view.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_take_screen.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/current_tracer.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/presentation/user_surveys_page.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_floating.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Tracer: built-in CHED GTS only. Assigned classic surveys live under My Surveys.
class TracerScreen extends StatefulWidget {
  const TracerScreen({
    super.key,
    this.embeddedInNav = true,
    this.requestedSurveyId,
  });

  final bool embeddedInNav;

  /// Survey a shared link asked for, if any. Access is still governed
  /// entirely by the alumnus's assignments (see [_handleRequestedSurvey]).
  final String? requestedSurveyId;

  @override
  State<TracerScreen> createState() => _TracerScreenState();
}

class _TracerScreenState extends State<TracerScreen> {
  final _surveyService = SurveyService();
  final _profileService = UserProfileService();
  List<SurveyAssignment> _assignments = [];
  List<SurveyResponseWithMeta> _history = [];
  final Map<String, Survey> _surveyById = {};
  bool _loading = true;

  String? _chedSurveyId;
  Map<String, dynamic> _chedAnswers = {};
  Map<String, dynamic> _chedPrefilled = {};
  ChedGtsContactOriginals? _chedContacts;
  bool _chedHasDraft = false;
  TracerReminder? _chedReminder;
  final _reminderService = TracerReminderService();
  bool _requestedHandled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TracerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestedSurveyId != widget.requestedSurveyId) {
      _requestedHandled = false;
      _load();
    }
  }

  /// [showPageSkeleton] false keeps current content visible (pull-to-refresh).
  Future<void> _load({bool showPageSkeleton = true}) async {
    final uid = AppSession.userId;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (showPageSkeleton && mounted) {
      setState(() => _loading = true);
    }
    final results = await Future.wait([
      _surveyService.getUserAssignments(uid),
      _surveyService.getUserSubmittedResponses(uid),
    ]);
    if (!mounted) return;

    final assignments = results[0] as List<SurveyAssignment>;
    final history = results[1] as List<SurveyResponseWithMeta>;

    final surveyMap = await _surveyService.getSurveysByIds([
      ...assignments.map((a) => a.surveyId),
      ...history.map((h) => h.response.surveyId),
      if (widget.requestedSurveyId != null) widget.requestedSurveyId!,
    ]);

    if (!mounted) return;
    // Keep the page skeleton up through CHED prefill so height does not drop.
    setState(() {
      _assignments = assignments;
      _history = history;
      _surveyById
        ..clear()
        ..addAll(surveyMap);
    });

    await _prepareChedAnswers();
    if (mounted) setState(() => _loading = false);
    _handleRequestedSurvey();
  }

  /// Explains the outcome when the alumnus arrived via a shared tracer
  /// link. When the requested tracer is the current, open assignment the
  /// normal tracer flow below already presents it — nothing extra to say.
  void _handleRequestedSurvey() {
    final id = widget.requestedSurveyId;
    if (id == null || _requestedHandled || !mounted) return;
    _requestedHandled = true;
    SurveyAssignment? assignment;
    for (final a in _assignments) {
      if (a.surveyId == id) {
        assignment = a;
        break;
      }
    }
    final survey = _surveyById[id];
    final String? message;
    if (assignment == null) {
      message =
          survey == null ||
              survey.archived ||
              survey.status == SurveyStatus.draft
          ? 'This tracer study is no longer available.'
          : 'This tracer study was not assigned to your account. '
                'If you believe this is a mistake, please contact the alumni office.';
    } else if (assignment.status == SurveyAssignmentStatus.completed) {
      message = 'You have already submitted this tracer study. Thank you!';
    } else if (survey != null &&
        CurrentTracer.isStale(assignment, survey, _currentChedAssignment)) {
      message = 'You have a newer Graduate Tracer Study to answer below.';
    } else if (survey != null && survey.isNotYetOpen) {
      message = 'This tracer study is not open yet.';
    } else if (survey != null && !survey.isOpen) {
      message = 'This tracer study is closed.';
    } else {
      message = null;
    }
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message!), behavior: SnackBarBehavior.floating),
      );
    });
  }

  List<SurveyAssignment> get _incompleteAssignments => _assignments
      .where((a) => a.status != SurveyAssignmentStatus.completed)
      .toList();

  bool _surveyIsOpen(String surveyId) =>
      _surveyById[surveyId]?.acceptsResponses == true;

  /// Incomplete + currently within schedule window (takeable now).
  List<SurveyAssignment> get _activeAssignments =>
      _incompleteAssignments.where((a) => _surveyIsOpen(a.surveyId)).toList();

  /// Newest assigned tracer; older ones left open are not asked for.
  SurveyAssignment? get _currentChedAssignment =>
      CurrentTracer.pick(_assignments, (id) => _surveyById[id]);

  SurveyAssignment? get _incompleteCurrentChed {
    final a = _currentChedAssignment;
    if (a == null || a.status == SurveyAssignmentStatus.completed) return null;
    return a;
  }

  /// Current tracer when it has not opened yet.
  SurveyAssignment? get _scheduledChedAssignment {
    final a = _incompleteCurrentChed;
    if (a == null) return null;
    return _surveyById[a.surveyId]?.isNotYetOpen == true ? a : null;
  }

  /// Current tracer when it can be answered now.
  SurveyAssignment? get _primaryChedAssignment {
    final a = _incompleteCurrentChed;
    if (a == null) return null;
    return _surveyIsOpen(a.surveyId) ? a : null;
  }

  List<SurveyAssignment> get _otherActiveAssignments => _activeAssignments
      .where((a) => _surveyById[a.surveyId]?.isChedGtsBuiltin != true)
      .toList();

  /// Loads draft + profile prefill so the intro can show progress and the
  /// answering screen opens with everything pre-filled.
  ///
  /// Does not toggle a second in-list skeleton — the page-level [_loading]
  /// skeleton stays until this finishes (see [_load]).
  Future<void> _prepareChedAnswers() async {
    final assignment = _primaryChedAssignment;
    if (assignment == null) {
      if (mounted) {
        setState(() {
          _chedSurveyId = null;
          _chedAnswers = {};
          _chedPrefilled = {};
          _chedContacts = null;
          _chedHasDraft = false;
          _chedReminder = null;
        });
      }
      return;
    }

    final uid = AppSession.userId;
    if (uid == null) return;

    _chedSurveyId = assignment.surveyId;

    try {
      final reminderFuture = _reminderService.getReminder(assignment.surveyId);
      final existing = await _surveyService.getResponse(
        assignment.surveyId,
        uid,
      );
      final profile = await _profileService.getTracerProfile(uid);

      // Profile details and initial employment snapshot (Q16-Q19) are
      // carried over and flagged with a prompt to confirm or update them.
      final prefill = profile != null
          ? ChedGtsPrefill.fromProfile(profile)
          : <String, dynamic>{};
      final merged = ChedGtsPrefill.merge(
        existing: existing?.answers ?? const {},
        prefill: prefill,
      );
      final reminder = await reminderFuture;

      if (!mounted) return;
      setState(() {
        _chedAnswers = merged;
        _chedPrefilled = prefill;
        _chedContacts = profile == null
            ? null
            : ChedGtsContactOriginals(
                email: profile.preferredEmail,
                mobile: profile.mobileNumber,
              );
        _chedReminder = reminder;
        _chedHasDraft =
            existing != null &&
            existing.submittedAt == null &&
            existing.answers.isNotEmpty;
      });
    } catch (_) {
      // Keep whatever answers we already had; page loading ends in [_load].
    }
  }

  Future<void> _openChedForm() async {
    final surveyId = _chedSurveyId;
    if (surveyId == null) return;
    final submitted = await ChedGtsTakeScreen.open(
      context,
      surveyId: surveyId,
      initialAnswers: _chedAnswers,
      prefilledAnswers: _chedPrefilled,
      closeAt: _surveyById[surveyId]?.closeAt,
      aiHelpEnabled: _surveyById[surveyId]?.aiHelpEnabled ?? true,
      contactOriginals: _chedContacts,
    );
    if (!mounted) return;
    await _load();
    if (!submitted || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Thank you! Your CHED GTS has been submitted.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PortalTheme.success,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: _openHistory,
        ),
      ),
    );
  }

  void _openHistory() {
    TracerHistoryScreen.open(context, history: _chedHistory);
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? PortalTheme.danger : PortalTheme.success,
        ),
      );
  }

  Future<void> _setReminder() async {
    final surveyId = _chedSurveyId;
    if (surveyId == null) return;
    final current = _chedReminder;
    final choice = await showTracerReminderSheet(
      context,
      closeAt: _surveyById[surveyId]?.closeAt,
      initialRepeatHourly: current?.repeatHourly ?? false,
      title: current?.isUpcoming == true
          ? 'Change your reminder'
          : 'Remind me to finish',
      dismissLabel: null,
    );
    if (choice == null || !mounted) return;
    try {
      final saved = await _reminderService.setReminder(
        surveyId: surveyId,
        remindAt: choice.remindAt,
        repeatHourly: choice.repeatHourly,
      );
      if (!mounted) return;
      setState(() => _chedReminder = saved);
      _snack("We'll remind you ${formatReminderTime(saved.remindAt)}.");
    } catch (e) {
      if (mounted) _snack(portalFriendlyError(e), error: true);
    }
  }

  Future<void> _cancelReminder() async {
    final surveyId = _chedSurveyId;
    if (surveyId == null) return;
    try {
      await _reminderService.cancelReminder(surveyId);
      if (!mounted) return;
      setState(() => _chedReminder = null);
      _snack('Reminder cancelled.');
    } catch (e) {
      if (mounted) _snack(portalFriendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Tracer',
        subtitle: 'CHED Graduate Tracer Study',
        automaticallyImplyLeading: !widget.embeddedInNav,
        actions: [
          PortalHeaderAction(
            icon: Icons.history_rounded,
            tooltip: 'Past responses',
            onPressed: _openHistory,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PortalContentFrame(
        child: _loading
            ? const TracerFormSkeleton(fieldCount: 4)
            : _activeTab(),
      ),
    );
  }

  Widget _activeTab() {
    final ched = _primaryChedAssignment;
    final scheduled = _scheduledChedAssignment;
    final others = _otherActiveAssignments;
    final width = PortalBreakpoints.widthOf(context);
    // Same 16 px side inset as Home so card edges line up across tabs.
    final padding = PortalBreakpoints.pagePadding(
      width,
    ).copyWith(left: 16, right: 16);

    return RefreshIndicator(
      onRefresh: () => _load(showPageSkeleton: false),
      color: PortalTheme.navy,
      child: ListView(
        padding: padding.copyWith(
          bottom: widget.embeddedInNav
              ? PortalFloating.bottomClearance(context)
              : 40,
        ),
        children: [
          if (ched != null)
            TracerIntroView(
              survey: _surveyById[ched.surveyId],
              fallbackTitle: ched.surveyTitle,
              answers: _chedAnswers,
              hasDraft: _chedHasDraft,
              onStart: _openChedForm,
              reminder: _chedReminder,
              onSetReminder: _setReminder,
              onCancelReminder: _cancelReminder,
            )
          else if (scheduled != null)
            _scheduledChedCard(scheduled)
          else
            _emptyActiveState(),
          // Only when there is no active CHED tracer on this screen.
          if (ched == null && others.isNotEmpty) ...[
            const SizedBox(height: PortalTheme.space4),
            _otherSurveysLinkCard(others.length),
          ],
        ],
      ),
    );
  }

  Widget _scheduledChedCard(SurveyAssignment assignment) {
    final survey = _surveyById[assignment.surveyId];
    final openAt = survey?.openAt;
    final closeAt = survey?.closeAt;
    final openLabel = openAt == null
        ? 'soon'
        : DateFormat.yMMMd().add_jm().format(openAt);

    return PortalHighlightPanel(
      variant: PortalHighlightVariant.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PortalChip(
            label: 'Scheduled',
            icon: Icons.schedule_rounded,
            tone: PortalChipTone.brand,
          ),
          const SizedBox(height: PortalTheme.space2),
          Text(
            survey?.title.isNotEmpty == true
                ? survey!.title
                : assignment.surveyTitle,
            style: PortalTheme.sectionTitle.copyWith(color: PortalTheme.navy),
          ),
          const SizedBox(height: 8),
          Text(
            'This tracer is assigned to you, but it is not open yet. '
            'You can start answering when the schedule begins.',
            style: PortalTheme.bodySecondary,
          ),
          const SizedBox(height: PortalTheme.space3),
          PortalChip(
            label: 'Opens $openLabel',
            icon: Icons.lock_clock_outlined,
            tone: PortalChipTone.warning,
          ),
          if (closeAt != null) ...[
            const SizedBox(height: 8),
            PortalChip(
              label: 'Closes ${DateFormat.yMMMd().add_jm().format(closeAt)}',
              icon: Icons.event_outlined,
              tone: PortalChipTone.neutral,
            ),
          ],
        ],
      ),
    );
  }

  Widget _otherSurveysLinkCard(int count) {
    return PortalHighlightPanel(
      variant: PortalHighlightVariant.goldEdge,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserSurveysScreen()),
        );
      },
      padding: const EdgeInsets.all(PortalTheme.space3),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PortalTheme.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            ),
            child: const Icon(Icons.poll_outlined, color: PortalTheme.navy),
          ),
          const SizedBox(width: PortalTheme.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Other assigned surveys', style: PortalTheme.cardTitle),
                const SizedBox(height: 2),
                Text(
                  count == 1
                      ? '1 survey needs attention in My Surveys'
                      : '$count surveys need attention in My Surveys',
                  style: PortalTheme.bodySecondary,
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: PortalTheme.navy),
        ],
      ),
    );
  }

  Widget _emptyActiveState() {
    final last = _lastSubmittedAt;
    final lastText = last != null
        ? DateFormat.yMMMd().add_jm().format(last)
        : null;

    return PortalHighlightPanel(
      variant: PortalHighlightVariant.soft,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: PortalTheme.navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 28,
              color: PortalTheme.navy.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: PortalTheme.space3),
          Text(
            'No CHED Tracer open right now',
            style: PortalTheme.cardTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            lastText != null
                ? 'You last submitted on $lastText. You can view it in Past responses.'
                : 'When your school publishes the official CHED GTS, it will appear here.',
            textAlign: TextAlign.center,
            style: PortalTheme.bodySecondary,
          ),
          if (_chedHistory.isNotEmpty) ...[
            const SizedBox(height: PortalTheme.space3),
            OutlinedButton.icon(
              onPressed: _openHistory,
              style: PortalTheme.secondaryButton(dense: true),
              icon: const Icon(Icons.history),
              label: const Text('View history'),
            ),
          ],
        ],
      ),
    );
  }

  bool _isChedHistoryItem(SurveyResponseWithMeta item) {
    final survey = _surveyById[item.response.surveyId];
    if (survey?.isChedGtsBuiltin == true) return true;
    return item.response.answers.keys.any(
      (k) => k.toString().startsWith('ched_'),
    );
  }

  List<SurveyResponseWithMeta> get _chedHistory =>
      _history.where(_isChedHistoryItem).toList();

  DateTime? get _lastSubmittedAt {
    final ched = _chedHistory;
    if (ched.isEmpty) return null;
    return ched.first.response.submittedAt;
  }
}
