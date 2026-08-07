import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_form.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
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
  final _wizardAnchorKey = GlobalKey();

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

  int _chedOverallPercent(Map<String, dynamic> answers) {
    final visible = ChedGtsVisibility.visibleItemIds(answers);
    final requiredIds = ChedGtsBuiltin.items
        .where((i) => i.required && visible.contains(i.id))
        .map((i) => i.id)
        .toList();
    if (requiredIds.isEmpty) return 0;
    final missing = ChedGtsVisibility.missingRequired(answers);
    final done = requiredIds.length - missing.length;
    return ((done / requiredIds.length) * 100).round().clamp(0, 100);
  }

  void _scrollToWizard() {
    final ctx = _wizardAnchorKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: PortalTheme.normal,
        curve: PortalTheme.ease,
        alignment: 0.05,
      );
      return;
    }
    if (_activeScrollController.hasClients) {
      _activeScrollController.animateTo(
        220,
        duration: PortalTheme.normal,
        curve: PortalTheme.ease,
      );
    }
  }

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
        padding: padding.copyWith(bottom: 40),
        children: [
          if (ched != null) ...[
            _chedStatusHero(ched),
            const SizedBox(height: PortalTheme.space3),
            if (_inlineLoading)
              const PortalCardListSkeleton(count: 4, shrinkWrap: true)
            else
              KeyedSubtree(
                key: _wizardAnchorKey,
                child: ChedGtsWizard(
                  title: _surveyById[ched.surveyId]?.title ?? ched.surveyTitle,
                  answers: _inlineAnswers,
                  saving: _inlineSaving,
                  scrollController: _activeScrollController,
                  onChanged: (a) => setState(() => _inlineAnswers = a),
                  onSaveDraft: () => _saveInline(submit: false),
                  onSubmit: () => _saveInline(submit: true),
                ),
              ),
          ] else if (scheduled != null)
            _scheduledChedCard(scheduled)
          else
            _emptyActiveState(),
          if (others.isNotEmpty) ...[
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

  Widget _chedStatusHero(SurveyAssignment assignment) {
    final percent = _chedOverallPercent(_inlineAnswers);
    final isComplete = percent >= 100;
    final status = assignment.status;
    final closeAt = _surveyById[assignment.surveyId]?.closeAt;

    final (PortalChipTone chipTone, String chipLabel, IconData chipIcon) =
        switch (status) {
      SurveyAssignmentStatus.notStarted => (
          PortalChipTone.warning,
          'Not started',
          Icons.flag_outlined,
        ),
      SurveyAssignmentStatus.inProgress => (
          PortalChipTone.brand,
          'In progress',
          Icons.edit_note_outlined,
        ),
      SurveyAssignmentStatus.completed => (
          PortalChipTone.success,
          'Complete',
          Icons.check_circle_outline,
        ),
    };

    final headline = isComplete
        ? 'Ready to submit'
        : status == SurveyAssignmentStatus.notStarted
            ? 'Your CHED tracer is waiting'
            : 'Keep going — you\'re making progress';

    final body = isComplete
        ? 'All required items are answered. Review your responses below, then submit to finish.'
        : 'This official questionnaire helps CHED and USTP track graduate outcomes. '
            'Your answers are confidential and typically take 15–20 minutes.';

    return PortalHighlightPanel(
      variant: PortalHighlightVariant.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PortalChip(
                label: chipLabel,
                icon: chipIcon,
                tone: chipTone,
              ),
              if (closeAt != null) ...[
                const SizedBox(width: 8),
                PortalChip(
                  label: 'Due ${DateFormat.MMMd().format(closeAt)}',
                  icon: Icons.event_outlined,
                  tone: PortalChipTone.gold,
                ),
              ],
            ],
          ),
          const SizedBox(height: PortalTheme.space3),
          Text(
            headline,
            style: PortalTheme.cardTitle.copyWith(color: PortalTheme.textOnNavy),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: PortalTheme.body.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: PortalTheme.space3),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$percent% complete',
                          style: PortalTheme.meta.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isComplete ? 'All required done' : 'Required items',
                          style: PortalTheme.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(PortalTheme.gold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PortalTheme.space3),
          _sectionOverviewRow(),
          const SizedBox(height: PortalTheme.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _scrollToWizard,
              style: PortalTheme.goldAccentButton(),
              icon: Icon(isComplete ? Icons.fact_check_outlined : Icons.arrow_forward_rounded),
              label: Text(isComplete ? 'Review & submit' : 'Continue tracer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionOverviewRow() {
    const sections = ChedGtsSection.values;
    final visible = ChedGtsVisibility.visibleItemIds(_inlineAnswers);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final section in sections)
          _SectionStatusChip(
            label: _sectionShortLabel(section),
            complete: ChedGtsVisibility
                .missingRequiredInSection(_inlineAnswers, section)
                .isEmpty,
            hasItems: ChedGtsBuiltin.items
                .any((i) => i.section == section && visible.contains(i.id)),
          ),
      ],
    );
  }

  String _sectionShortLabel(ChedGtsSection section) {
    final item = ChedGtsBuiltin.items.firstWhere(
      (i) => i.section == section,
      orElse: () => ChedGtsBuiltin.items.first,
    );
    final title = item.sectionTitle;
    if (title.startsWith('Section ')) {
      return title.split(' ').take(2).join(' ');
    }
    return title.length > 12 ? '${title.substring(0, 10)}…' : title;
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
        padding: padding.copyWith(bottom: 40),
        itemCount: chedHistory.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: PortalTheme.space3),
              child: PortalSectionHeader(
                title: 'Submission history',
                subtitle: '${chedHistory.length} CHED response${chedHistory.length == 1 ? '' : 's'} on file',
              ),
            );
          }

          final item = chedHistory[index - 1];
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

class _SectionStatusChip extends StatelessWidget {
  const _SectionStatusChip({
    required this.label,
    required this.complete,
    required this.hasItems,
  });

  final String label;
  final bool complete;
  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    if (!hasItems) {
      return PortalChip(
        label: label,
        tone: PortalChipTone.neutral,
        icon: Icons.remove_circle_outline,
      );
    }
    return PortalChip(
      label: label,
      tone: complete ? PortalChipTone.success : PortalChipTone.gold,
      icon: complete ? Icons.check : Icons.radio_button_unchecked,
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
    return Container(
      margin: const EdgeInsets.only(bottom: PortalTheme.space2),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: PortalTheme.border),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: PortalTheme.space3,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          title: Text(title, style: PortalTheme.cardTitle.copyWith(fontSize: 15)),
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
    );
  }
}
