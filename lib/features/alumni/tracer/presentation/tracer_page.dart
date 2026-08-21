import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_wizard.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/presentation/user_surveys_page.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Tracer: built-in CHED GTS only. Assigned classic surveys live under My Surveys.
class TracerScreen extends StatefulWidget {
  const TracerScreen({super.key, this.embeddedInNav = true});

  final bool embeddedInNav;

  @override
  State<TracerScreen> createState() => _TracerScreenState();
}

class _TracerScreenState extends State<TracerScreen>
    with SingleTickerProviderStateMixin {
  final _surveyService = SurveyService();
  final _profileService = UserProfileService();
  final _idTracerService = IdTracerService();
  late TabController _tabs;

  List<SurveyAssignment> _assignments = [];
  List<SurveyResponseWithMeta> _history = [];
  final Map<String, Survey> _surveyById = {};
  bool _loading = true;

  String? _inlineSurveyId;
  Map<String, dynamic> _inlineAnswers = {};
  bool _inlineLoading = false;
  bool _inlineSaving = false;
  final _activeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _activeScrollController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AppSession.userId;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final results = await Future.wait([
      _surveyService.getUserAssignments(uid),
      _surveyService.getUserSubmittedResponses(uid),
    ]);
    if (!mounted) return;

    final assignments = results[0] as List<SurveyAssignment>;
    final history = results[1] as List<SurveyResponseWithMeta>;

    final surveyMap = <String, Survey>{};
    for (final a in assignments) {
      final s = await _surveyService.getSurvey(a.surveyId);
      if (s != null) surveyMap[a.surveyId] = s;
    }
    for (final h in history) {
      if (!surveyMap.containsKey(h.response.surveyId)) {
        final s = await _surveyService.getSurvey(h.response.surveyId);
        if (s != null) surveyMap[h.response.surveyId] = s;
      }
    }

    if (!mounted) return;
    setState(() {
      _assignments = assignments;
      _history = history;
      _surveyById
        ..clear()
        ..addAll(surveyMap);
      _loading = false;
    });

    await _prepareInlineChedForm();
  }

  List<SurveyAssignment> get _incompleteAssignments => _assignments
      .where((a) => a.status != SurveyAssignmentStatus.completed)
      .toList();

  bool _surveyIsOpen(String surveyId) =>
      _surveyById[surveyId]?.acceptsResponses == true;

  /// Incomplete + currently within schedule window (takeable now).
  List<SurveyAssignment> get _activeAssignments => _incompleteAssignments
      .where((a) => _surveyIsOpen(a.surveyId))
      .toList();

  /// Incomplete CHED assignment that has not opened yet.
  SurveyAssignment? get _scheduledChedAssignment {
    for (final a in _incompleteAssignments) {
      final s = _surveyById[a.surveyId];
      if (s?.isChedGtsBuiltin == true && s?.isNotYetOpen == true) return a;
    }
    return null;
  }

  SurveyAssignment? get _primaryChedAssignment {
    for (final a in _activeAssignments) {
      final s = _surveyById[a.surveyId];
      if (s?.isChedGtsBuiltin == true) return a;
    }
    return null;
  }

  List<SurveyAssignment> get _otherActiveAssignments => _activeAssignments
      .where((a) => _surveyById[a.surveyId]?.isChedGtsBuiltin != true)
      .toList();

  Future<void> _prepareInlineChedForm() async {
    final assignment = _primaryChedAssignment;
    if (assignment == null) {
      if (mounted) {
        setState(() {
          _inlineSurveyId = null;
          _inlineAnswers = {};
          _inlineLoading = false;
        });
      }
      return;
    }

    final uid = AppSession.userId;
    if (uid == null) return;

    setState(() {
      _inlineSurveyId = assignment.surveyId;
      _inlineLoading = true;
    });

    try {
      final existing = await _surveyService.getResponse(
        assignment.surveyId,
        uid,
      );
      final profile = await _profileService.getTracerProfile(uid);
      EmploymentRecord? employment;
      try {
        employment = await _idTracerService.getCurrentUserRecord();
      } catch (_) {}

      final prefill = profile != null
          ? ChedGtsPrefill.fromProfile(profile, employment: employment)
          : <String, dynamic>{};
      final merged = ChedGtsPrefill.merge(
        existing: existing?.answers ?? const {},
        prefill: prefill,
      );

      if (!mounted) return;
      setState(() {
        _inlineAnswers = merged;
        _inlineLoading = false;
      });
      unawaited(_surveyService.recordSurveyOpened(assignment.surveyId));
    } catch (_) {
      if (mounted) setState(() => _inlineLoading = false);
    }
  }

  Future<void> _saveInline({required bool submit}) async {
    final surveyId = _inlineSurveyId;
    if (surveyId == null) return;

    setState(() => _inlineSaving = true);
    try {
      await _surveyService.saveResponse(
        surveyId: surveyId,
        answers: _inlineAnswers,
        submit: submit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(submit ? 'CHED GTS submitted' : 'Draft saved'),
          backgroundColor: PortalTheme.success,
        ),
      );
      await _load();
      if (submit && mounted) _tabs.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(portalFriendlyError(e)),
          backgroundColor: PortalTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _inlineSaving = false);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(47),
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                indicatorColor: PortalTheme.gold,
                indicatorWeight: 3,
                labelColor: PortalTheme.navy,
                unselectedLabelColor: PortalTheme.textSecondary,
                labelStyle: PortalTheme.meta.copyWith(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Active Tracer'),
                  Tab(text: 'History'),
                ],
              ),
              Container(height: 1, color: PortalTheme.border),
            ],
          ),
        ),
      ),
      body: _loading
          ? const PortalCardListSkeleton()
          : TabBarView(
              controller: _tabs,
              children: [_activeTab(), _historyTab()],
            ),
    );
  }

  Widget _activeTab() {
    final ched = _primaryChedAssignment;
    final scheduled = _scheduledChedAssignment;
    final others = _otherActiveAssignments;
    final width = PortalBreakpoints.widthOf(context);
    final padding = PortalBreakpoints.pagePadding(width);

    return RefreshIndicator(
      onRefresh: _load,
      color: PortalTheme.navy,
      child: ListView(
        controller: _activeScrollController,
        padding: padding.copyWith(bottom: widget.embeddedInNav ? 108 : 40),
        children: [
          if (ched != null) ...[
            if (_inlineLoading)
              const PortalCardListSkeleton(count: 4, shrinkWrap: true)
            else
              ChedGtsWizard(
                title: _surveyById[ched.surveyId]?.title ?? ched.surveyTitle,
                answers: _inlineAnswers,
                saving: _inlineSaving,
                scrollController: _activeScrollController,
                onChanged: (a) => setState(() => _inlineAnswers = a),
                onSaveDraft: () => _saveInline(submit: false),
                onSubmit: () => _saveInline(submit: true),
              ),
          ] else if (scheduled != null)
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
                ? 'You last submitted on $lastText. Past CHED responses are in History.'
                : 'When your school publishes the official CHED GTS, it will appear here.',
            textAlign: TextAlign.center,
            style: PortalTheme.bodySecondary,
          ),
          if (_chedHistory.isNotEmpty) ...[
            const SizedBox(height: PortalTheme.space3),
            OutlinedButton.icon(
              onPressed: () => _tabs.animateTo(1),
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

  Widget _historyTab() {
    final chedHistory = _chedHistory;
    final width = PortalBreakpoints.widthOf(context);
    final padding = PortalBreakpoints.pagePadding(width);

    if (chedHistory.isEmpty) {
      return const PortalEmptyState(
        icon: Icons.history_outlined,
        title: 'No CHED history yet',
        subtitle:
            'Submitted CHED Graduate Tracer responses will appear here for your records.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: PortalTheme.navy,
      child: ListView.builder(
        padding: padding.copyWith(bottom: widget.embeddedInNav ? 108 : 40),
        itemCount: chedHistory.length,
        itemBuilder: (context, index) {
          final item = chedHistory[index];
          final submitted = item.response.submittedAt;
          return _HistoryResponseCard(
            title: item.surveyTitle,
            submittedLabel: submitted != null
                ? DateFormat.yMMMd().add_jm().format(submitted)
                : 'Submitted',
            answers: item.response.answers,
          );
        },
      ),
    );
  }
}

class _HistoryResponseCard extends StatelessWidget {
  const _HistoryResponseCard({
    required this.title,
    required this.submittedLabel,
    required this.answers,
  });

  final String title;
  final String submittedLabel;
  final Map<String, dynamic> answers;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
      side: BorderSide(color: PortalTheme.border.withValues(alpha: 0.75)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: Material(
        color: PortalTheme.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: PortalTheme.navy.withValues(alpha: 0.06),
            highlightColor: PortalTheme.navy.withValues(alpha: 0.04),
            hoverColor: PortalTheme.navy.withValues(alpha: 0.03),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: PortalTheme.space3,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PortalTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
              ),
              child: const Icon(
                Icons.verified_outlined,
                color: PortalTheme.success,
                size: 20,
              ),
            ),
            title: Text(
              title,
              style: PortalTheme.cardTitle.copyWith(fontSize: 15),
            ),
            subtitle: Text(
              'Submitted $submittedLabel',
              style: PortalTheme.meta,
            ),
            children: [
              ChedGtsForm(
                answers: answers,
                onChanged: (_) {},
                readOnly: true,
                showIntro: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
