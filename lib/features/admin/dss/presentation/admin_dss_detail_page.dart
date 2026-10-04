import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/admin/announcements/presentation/admin_announcement_editor_page.dart';
import 'package:alumni_system/features/admin/dss/application/dss_ai_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluation_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_impact.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_suggestion_themes.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/dss/widgets/dss_action_dialogs.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Inline DSS flag detail panel (Surveys-style workspace).
class AdminDssDetailPanel extends StatefulWidget {
  const AdminDssDetailPanel({
    super.key,
    required this.flagId,
    required this.onClose,
    this.onOpenAdminMenu,
  });

  final String flagId;
  final Future<void> Function() onClose;
  final void Function(int menuIndex)? onOpenAdminMenu;

  @override
  State<AdminDssDetailPanel> createState() => _AdminDssDetailPanelState();
}

class _AdminDssDetailPanelState extends State<AdminDssDetailPanel> {
  final _repo = DssRepository();
  final _eval = DssEvaluationService();
  final _ai = DssAiService();
  final _themes = DssSuggestionThemeService();
  final _announcements = AnnouncementService();
  final _noteCtrl = TextEditingController();
  final _interventionDetailCtrl = TextEditingController();

  DssFlag? _flag;
  List<DssFlagNote> _notes = [];
  List<_AdminOption> _admins = [];
  bool _loading = true;
  bool _saving = false;
  bool _rechecking = false;
  String? _aiPhrase;
  DssSuggestionSummary? _suggestions;
  bool _loadingSuggestions = false;
  String? _error;
  String? _intervention;
  String? _assignedTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _interventionDetailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final flag = await _repo.getFlag(widget.flagId);
      final notes = flag == null
          ? <DssFlagNote>[]
          : await _repo.listNotes(flag.id);
      final admins = await _repo.listAdminUsers();
      if (!mounted) return;
      setState(() {
        _flag = flag;
        _notes = notes;
        _admins = admins
            .map(
              (a) => _AdminOption(
                id: a.id,
                label: a.displayName.isEmpty ? a.email : a.displayName,
              ),
            )
            .toList();
        _assignedTo = flag?.assignedTo;
        _intervention = flag?.interventionType;
        // Drop a saved intervention if it doesn't belong to this rule's list
        // (except keep it so historical resolves still display).
        if (flag != null && _intervention != null) {
          final allowed = DssCopy.interventionsForRule(flag.ruleId);
          if (!allowed.contains(_intervention) &&
              flag.status != DssFlagStatus.resolved &&
              flag.status != DssFlagStatus.dismissed) {
            _intervention = null;
          }
        }
        if ((flag?.interventionDetail ?? '').isNotEmpty) {
          _interventionDetailCtrl.text = flag!.interventionDetail!;
        }
        _loading = false;
        if (flag == null) _error = 'Flag not found.';
      });
      if (flag != null) _phraseAi(flag);
      if (flag != null && _suggestions == null) _loadSuggestions(flag);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _phraseAi(DssFlag flag) async {
    try {
      final text = await _ai.phraseFlag(flag);
      if (!mounted) return;
      setState(() => _aiPhrase = text);
    } catch (_) {}
  }

  Future<void> _loadSuggestions(DssFlag flag) async {
    if (!DssSuggestionThemeService.appliesTo(flag)) return;
    setState(() => _loadingSuggestions = true);
    try {
      final summary = await _themes.summarize(flag);
      if (!mounted) return;
      setState(() => _suggestions = summary);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _setStatus(DssFlagStatus status) async {
    final flag = _flag;
    if (flag == null) return;

    if (status == DssFlagStatus.resolved) {
      if (flag.status != DssFlagStatus.inProgress) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Click Start first, then Resolve when work is done.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final intervention = _intervention?.trim();
      if (intervention == null || intervention.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose an intervention before resolving.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (intervention == 'Other' &&
          _interventionDetailCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Describe the “Other” intervention.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_noteCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add a short note describing what you did.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final hasLinked =
          (flag.linkedAnnouncementId ?? '').trim().isNotEmpty;
      final hasOfflineProof = intervention == 'Other' &&
          _interventionDetailCtrl.text.trim().isNotEmpty;
      if (!hasLinked && !hasOfflineProof) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add proof first: Draft reminder, or choose Other and describe the offline action.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      DssMetricSnapshot? snap;
      DssImpactVerdict? verdict;
      DateTime? verifyDue;
      if (status == DssFlagStatus.resolved) {
        snap = await _eval.recomputeMetricForFlag(flag);
        verdict = DssImpact.compute(
          ruleId: flag.ruleId,
          operator: flag.ruleOperator ?? 'gte',
          threshold: flag.thresholdSnapshot,
          minN: flag.ruleMinN ?? 0,
          category: flag.ruleCategory ?? DssRuleCategory.outcome,
          baseline: flag.baselineValue ?? flag.metricValue,
          followup: snap.metricValue,
          sampleN: snap.sampleN,
        );
        verifyDue = DateTime.now().add(DssImpact.verifyDelay);
      }

      final detail = _intervention == 'Other'
          ? _interventionDetailCtrl.text.trim()
          : (_interventionDetailCtrl.text.trim().isEmpty
                ? null
                : _interventionDetailCtrl.text.trim());

      await _repo.updateFlagStatus(
        flag: flag,
        status: status,
        note: _noteCtrl.text,
        interventionType:
            status == DssFlagStatus.resolved ? _intervention : null,
        interventionDetail:
            status == DssFlagStatus.resolved ? detail : null,
        followupValue: snap?.metricValue,
        followupSampleN: snap?.sampleN,
        impactVerdict: verdict?.dbValue,
        verifyDueAt: verifyDue,
      );
      _noteCtrl.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == DssFlagStatus.resolved && verdict != null
                ? 'Resolved · ${verdict.label}. Recheck impact in 7 days.'
                : 'Marked ${status.label}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reopen() async {
    final flag = _flag;
    if (flag == null) return;
    setState(() => _saving = true);
    try {
      await _repo.updateFlagStatus(
        flag: flag,
        status: DssFlagStatus.open,
        note: _noteCtrl.text.trim().isEmpty
            ? 'Reopened for follow-up'
            : _noteCtrl.text,
        clearResolvedAt: true,
      );
      _noteCtrl.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flag reopened'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not reopen (another active flag may already exist for this cohort): $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recheckImpact() async {
    final flag = _flag;
    if (flag == null) return;
    setState(() => _rechecking = true);
    try {
      final snap = await _eval.recomputeMetricForFlag(flag);
      final verdict = DssImpact.compute(
        ruleId: flag.ruleId,
        operator: flag.ruleOperator ?? 'gte',
        threshold: flag.thresholdSnapshot,
        minN: flag.ruleMinN ?? 0,
        category: flag.ruleCategory ?? DssRuleCategory.outcome,
        baseline: flag.baselineValue ?? flag.metricValue,
        followup: snap.metricValue,
        sampleN: snap.sampleN,
      );
      final nextDue = verdict == DssImpactVerdict.stillFlagged ||
              verdict == DssImpactVerdict.insufficientData
          ? DateTime.now().add(DssImpact.verifyDelay)
          : null;
      await _repo.recordImpactRecheck(
        flag: flag,
        followupValue: snap.metricValue,
        followupSampleN: snap.sampleN,
        impactVerdict: verdict.dbValue,
        nextVerifyDueAt: nextDue,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impact: ${verdict.label}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recheck failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _rechecking = false);
    }
  }

  Future<void> _createReminderAnnouncement() async {
    final flag = _flag;
    if (flag == null) return;
    setState(() => _saving = true);
    try {
      final title =
          'Tracer reminder: ${flag.cohortLabel}';
      final body =
          'Please complete the graduate tracer survey'
          '${flag.surveyTitle.trim().isEmpty ? '' : ' (“${flag.surveyTitle.trim()}”)'}'
          ' for ${flag.cohortLabel}.\n\n'
          'Your response helps USTP improve programs and career support.\n\n'
          '(Draft created from Program Insights.)';
      final id = await _announcements.createAnnouncement(
        title: title,
        body: body,
      );
      await _repo.linkAnnouncement(flagId: flag.id, announcementId: id);
      await _repo.addNote(
        flagId: flag.id,
        note: 'Created reminder announcement draft ($id)',
        eventType: DssNoteEventType.announcement,
        metadata: {'announcement_id': id, 'title': title},
      );
      await _load();
      if (!mounted) return;
      await showAdminAnnouncementEditor(
        context: context,
        announcementId: id,
        onChanged: () {},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create announcement: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addNoteOnly() async {
    final flag = _flag;
    if (flag == null || _noteCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _repo.addNote(flagId: flag.id, note: _noteCtrl.text);
      _noteCtrl.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save note: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _jump(int menuIndex) {
    widget.onClose();
    widget.onOpenAdminMenu?.call(menuIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _flag == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DssPageHeader(
            title: 'Flag detail',
            onBack: () => widget.onClose(),
            actions: const [],
          ),
          Expanded(child: Center(child: Text(_error ?? 'Not found'))),
        ],
      );
    }

    final flag = _flag!;
    final df = DateFormat.yMMMd().add_jm();
    final playbook = DssCopy.displayPlaybook(flag);
    final showSuggestions = DssSuggestionThemeService.appliesTo(flag);
    final wide = MediaQuery.sizeOf(context).width >= AdminDensity.desktopSplitMin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DssPageHeader(
          title: DssCopy.displayTitle(flag),
          subtitle: flag.cohortLabel +
              (flag.surveyTitle.isEmpty ? '' : ' · ${flag.surveyTitle}'),
          onBack: () => widget.onClose(),
          backTooltip: 'Back to recommendations',
          actions: [
            DssStatusChip(status: flag.status),
          ],
        ),
        const SizedBox(height: AdminDssTheme.space2),
        Expanded(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: ListView(
                        children: [
                          _findingCard(flag, playbook),
                          const SizedBox(height: AdminDssTheme.space2),
                          if (showSuggestions) ...[
                            _suggestionsCard(),
                            const SizedBox(height: AdminDssTheme.space2),
                          ],
                          if (flag.status == DssFlagStatus.resolved ||
                              flag.followupValue != null ||
                              flag.impactVerdict != null) ...[
                            _impactCard(flag),
                            const SizedBox(height: AdminDssTheme.space2),
                          ],
                          _actCard(flag),
                        ],
                      ),
                    ),
                    const SizedBox(width: AdminDssTheme.space2),
                    Expanded(
                      flex: 2,
                      child: ListView(
                        children: [
                          _statusCard(flag),
                          const SizedBox(height: AdminDssTheme.space2),
                          _notesCard(df),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
                  children: [
                    _findingCard(flag, playbook),
                    const SizedBox(height: AdminDssTheme.space2),
                    if (showSuggestions) ...[
                      _suggestionsCard(),
                      const SizedBox(height: AdminDssTheme.space2),
                    ],
                    if (flag.status == DssFlagStatus.resolved ||
                        flag.followupValue != null ||
                        flag.impactVerdict != null) ...[
                      _impactCard(flag),
                      const SizedBox(height: AdminDssTheme.space2),
                    ],
                    _actCard(flag),
                    const SizedBox(height: AdminDssTheme.space2),
                    _statusCard(flag),
                    const SizedBox(height: AdminDssTheme.space2),
                    _notesCard(df),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _findingCard(DssFlag flag, List<DssPlaybookStep> playbook) {
    final shownPlaybook =
        playbook.isNotEmpty ? playbook : DssCopy.displayPlaybook(flag);
    final why = DssCopy.whyFlagged(flag);
    final next = DssCopy.displayRecommendedAction(flag);
    final headline = DssCopy.displayHeadline(flag);
    // Data-quality flags already explain the issue in [why] + chips;
    // the long headline mostly restates the same numbers.
    final showHeadline = flag.ruleId != 'DATA_QUALITY_LOW' &&
        !_isNearDuplicate(headline, why);
    final showAi = _aiPhrase != null &&
        !_isNearDuplicate(_aiPhrase!, why) &&
        !_isNearDuplicate(_aiPhrase!, '$why $next');

    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What we found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            why,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          if (showHeadline) ...[
            const SizedBox(height: 6),
            Text(
              headline,
              style: const TextStyle(
                color: AdminDssTheme.textSecondary,
                height: 1.4,
                fontSize: 12.5,
              ),
            ),
          ],
          if (showAi) ...[
            const SizedBox(height: 10),
            Text(
              _aiPhrase!,
              softWrap: true,
              style: const TextStyle(
                fontSize: 12.5,
                color: AdminDssTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kv(DssCopy.metricLabel(flag), DssCopy.metricValueLabel(flag)),
              if (DssCopy.trendLabel(flag) case final trend?)
                _kv('Not employed', trend),
              _kv('Answers', DssCopy.responsesLabel(flag)),
              _kv('Group', DssCopy.rosterLabel(flag)),
              if (flag.cohortLevel != DssCohortLevel.batch)
                DssMetaChip(
                  label: flag.cohortLevel.label,
                  icon: Icons.merge_type,
                  color: AdminDssTheme.info,
                ),
              if (flag.certainty != null) DssCertaintyChip(flag: flag),
            ],
          ),
          if (DssCopy.rollupNote(flag) case final note?) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminDssTheme.textSecondary,
              ),
            ),
          ],
          if (flag.certainty != null) ...[
            const SizedBox(height: 8),
            Text(
              DssCopy.certaintyHint(flag),
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminDssTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            DssCopy.sourceLabel(flag),
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AdminDssTheme.textMuted,
            ),
          ),
          if (flag.confidence == DssConfidence.low) ...[
            const SizedBox(height: 8),
            Text(
              DssCopy.confidenceLabel(flag),
              style: const TextStyle(
                fontSize: 12,
                color: AdminDssTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'What to do next',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next,
            style: const TextStyle(
              color: AdminDssTheme.textSecondary,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          if (shownPlaybook.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...shownPlaybook.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.key + 1}.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminDssTheme.primary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.value.step,
                        style: const TextStyle(
                          color: AdminDssTheme.textSecondary,
                          height: 1.35,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _suggestionsCard() {
    final s = _suggestions;
    const muted = TextStyle(fontSize: 12, height: 1.35, color: AdminDssTheme.textMuted);
    const secondary =
        TextStyle(fontSize: 12, height: 1.35, color: AdminDssTheme.textSecondary);

    final children = <Widget>[
      const Text(
        'What alumni suggest',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: AdminDssTheme.textPrimary,
        ),
      ),
      const SizedBox(height: 6),
    ];

    if (s == null) {
      children.add(
        _loadingSuggestions
            ? const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Reading curriculum suggestions…', style: secondary),
                ],
              )
            : const Text('Could not load curriculum suggestions.', style: muted),
      );
      return DssSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }

    if (s.texts.isEmpty) {
      children.add(
        Text(
          'No written curriculum suggestions (Q34) from the '
          '${s.respondents} respondent(s) in this group yet.',
          style: secondary,
        ),
      );
    } else {
      final aiLimited =
          s.byAi && s.texts.length > DssSuggestionThemeService.maxTexts;
      children.addAll([
        Text(
          '${s.texts.length} written suggestion(s) from ${s.respondents} '
          'respondent(s) in this group (Q34).',
          style: secondary,
        ),
        const SizedBox(height: 2),
        Text(
          s.byAi
              ? 'Grouped by AI${aiLimited ? ' (first ${DssSuggestionThemeService.maxTexts} suggestions)' : ''}. '
                    'Quotes are the alumni\'s own words.'
              : 'Grouped by keywords. Quotes are the alumni\'s own words.',
          style: muted,
        ),
        const SizedBox(height: 8),
        if (s.themes.isEmpty)
          const Text(
            'No common themes found. Read the suggestions in Survey responses.',
            style: secondary,
          )
        else
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [for (final t in s.themes) _themeTile(s, t)],
            ),
          ),
        if (s.themes.isNotEmpty && s.themed < s.texts.length) ...[
          const SizedBox(height: 4),
          Text(
            '${s.texts.length - s.themed} suggestion(s) did not fit a theme.',
            style: muted,
          ),
        ],
      ]);
    }

    final top = s.topCompetencies.take(6).toList();
    if (top.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 12),
        const Text(
          'Competencies alumni found useful (Q33)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            color: AdminDssTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in top)
              DssMetaChip(
                label: '${c.key} (${c.value})',
                color: AdminDssTheme.primary,
              ),
          ],
        ),
      ]);
    }

    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _themeTile(DssSuggestionSummary s, DssTheme theme) {
    final quotes = s.quotes(theme);
    Widget quote(String q, {int? maxLines}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '“$q”',
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          fontStyle: FontStyle.italic,
          color: AdminDssTheme.textSecondary,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AdminDssTheme.surface,
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
        border: Border.all(color: AdminDssTheme.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        dense: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                theme.label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AdminDssTheme.textPrimary,
                ),
              ),
            ),
            DssMetaChip(
              label: '${theme.count} mention${theme.count == 1 ? '' : 's'}',
              color: AdminDssTheme.primary,
            ),
          ],
        ),
        subtitle: quotes.isEmpty ? null : quote(quotes.first, maxLines: 2),
        children: [
          for (final q in quotes.take(12))
            Align(alignment: Alignment.centerLeft, child: quote(q)),
          if (quotes.length > 12)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${quotes.length - 12} more',
                style: const TextStyle(fontSize: 11.5, color: AdminDssTheme.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  /// True when [candidate] mostly restates [anchor] (avoids stacked duplicates).
  bool _isNearDuplicate(String candidate, String anchor) {
    final a = anchor.toLowerCase().trim();
    final c = candidate.toLowerCase().trim();
    if (a.isEmpty || c.isEmpty) return false;
    if (c == a) return true;
    if (c.contains(a) || a.contains(c)) return true;
    final aWords = a.split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();
    final cWords = c.split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();
    if (aWords.isEmpty) return false;
    final overlap = aWords.intersection(cWords).length / aWords.length;
    return overlap >= 0.75;
  }

  Widget _impactCard(DssFlag flag) {
    final verdict = DssImpactVerdictX.fromDb(flag.impactVerdict);
    final baseline = flag.baselineValue ?? flag.metricValue;
    final followup = flag.followupValue;
    final df = DateFormat.yMMMd();
    final due = flag.verifyDueAt;
    final dueOverdue =
        due != null && due.isBefore(DateTime.now()) && verdict != DssImpactVerdict.improved;

    Color verdictColor = AdminDssTheme.textSecondary;
    if (verdict == DssImpactVerdict.improved) {
      verdictColor = AdminDssTheme.success;
    } else if (verdict == DssImpactVerdict.stillFlagged) {
      verdictColor = AdminDssTheme.danger;
    } else if (verdict == DssImpactVerdict.insufficientData) {
      verdictColor = AdminDssTheme.warning;
    }

    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Impact check',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AdminDssTheme.textPrimary,
                  ),
                ),
              ),
              if (verdict != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: verdictColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    verdict.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: verdictColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            followup == null
                ? 'No follow-up metric yet. Recheck after you collect more data.'
                : 'Before ${DssImpact.formatMetric(flag.ruleId, baseline)} → '
                    'Now ${DssImpact.formatMetric(flag.ruleId, followup)}'
                    '${flag.interventionType == null ? '' : ' · ${flag.interventionType}'}',
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AdminDssTheme.textSecondary,
            ),
          ),
          if (verdict != null) ...[
            const SizedBox(height: 6),
            Text(
              verdict.hint,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AdminDssTheme.textMuted,
              ),
            ),
          ],
          if (due != null) ...[
            const SizedBox(height: 8),
            Text(
              dueOverdue
                  ? 'Verify due: ${df.format(due.toLocal())} (overdue)'
                  : 'Next verify by ${df.format(due.toLocal())}',
              style: TextStyle(
                fontSize: 12,
                color: dueOverdue
                    ? AdminDssTheme.warning
                    : AdminDssTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _rechecking || _saving ? null : _recheckImpact,
            icon: _rechecking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(_rechecking ? 'Checking…' : 'Recheck now'),
            style: dssOutlinedButtonStyle(),
          ),
        ],
      ),
    );
  }

  Future<void> _runOneClick(DssFlag flag) async {
    final isJobs = flag.ruleId == 'UNEMPLOYMENT_HIGH';
    final dialog = isJobs ? showDssJobMatchDialog : showDssReminderDialog;
    final result = await dialog(context, flag);
    if (result == null || !mounted) return;
    final skipped = result.selected - result.sent;
    final what = isJobs
        ? '${result.jobs} job posting(s) sent to ${result.sent} alumni'
        : 'Reminder sent to ${result.sent} alumni';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skipped > 0
              ? '$what. $skipped skipped (already notified today or no longer eligible).'
              : '$what. Logged on this flag.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Widget _actCard(DssFlag flag) {
    final closed = flag.status == DssFlagStatus.resolved ||
        flag.status == DssFlagStatus.dismissed;
    final oneClick = switch (flag.ruleId) {
      'DATA_QUALITY_LOW' => (
        label: 'Send reminders',
        icon: Icons.notifications_active_outlined,
      ),
      'UNEMPLOYMENT_HIGH' => (
        label: 'Send matching jobs',
        icon: Icons.work_outline,
      ),
      _ => null,
    };
    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Act in AESS',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (oneClick != null)
                FilledButton.icon(
                  onPressed:
                      _saving || closed ? null : () => _runOneClick(flag),
                  icon: Icon(oneClick.icon, size: 16),
                  label: Text(oneClick.label),
                  style: dssFilledButtonStyle(),
                ),
              if (oneClick == null)
                FilledButton.icon(
                  onPressed: _saving ? null : _createReminderAnnouncement,
                  icon: const Icon(Icons.campaign_outlined, size: 16),
                  label: Text(
                    flag.linkedAnnouncementId == null
                        ? 'Draft reminder'
                        : 'New reminder draft',
                  ),
                  style: dssFilledButtonStyle(),
                )
              else
                OutlinedButton.icon(
                  onPressed: _saving ? null : _createReminderAnnouncement,
                  icon: const Icon(Icons.campaign_outlined, size: 16),
                  label: Text(
                    flag.linkedAnnouncementId == null
                        ? 'Draft announcement'
                        : 'New announcement draft',
                  ),
                  style: dssOutlinedButtonStyle(),
                ),
              OutlinedButton.icon(
                onPressed: widget.onOpenAdminMenu == null
                    ? null
                    : () => _jump(10),
                icon: const Icon(Icons.poll_outlined, size: 16),
                label: const Text('Open Surveys'),
                style: dssOutlinedButtonStyle(),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenAdminMenu == null
                    ? null
                    : () => _jump(9),
                icon: const Icon(Icons.bar_chart, size: 16),
                label: const Text('Reports'),
                style: dssOutlinedButtonStyle(),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenAdminMenu == null
                    ? null
                    : () => _jump(2),
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('Directory'),
                style: dssOutlinedButtonStyle(),
              ),
              if (flag.ruleId == 'UNEMPLOYMENT_HIGH' ||
                  flag.ruleId == 'SALARY_STAGNATION')
                OutlinedButton.icon(
                  onPressed: widget.onOpenAdminMenu == null
                      ? null
                      : () => _jump(5),
                  icon: const Icon(Icons.work_outline, size: 16),
                  label: const Text('Jobs'),
                  style: dssOutlinedButtonStyle(),
                ),
            ],
          ),
          if (flag.linkedAnnouncementId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Linked draft: ${flag.linkedAnnouncementId}',
              style: const TextStyle(
                fontSize: 11,
                color: AdminDssTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(DssFlag flag) {
    final closed = flag.status == DssFlagStatus.resolved ||
        flag.status == DssFlagStatus.dismissed;
    final started = flag.status == DssFlagStatus.inProgress || closed;
    final hasIntervention = (_intervention ?? '').trim().isNotEmpty;
    final hasNote = _noteCtrl.text.trim().isNotEmpty;
    final hasAssigned = (_assignedTo ?? '').trim().isNotEmpty;
    final hasLinked = (flag.linkedAnnouncementId ?? '').trim().isNotEmpty;
    final hasOfflineProof = _intervention == 'Other' &&
        _interventionDetailCtrl.text.trim().isNotEmpty;
    final hasProof = hasLinked || hasOfflineProof;
    final canResolve = flag.status == DssFlagStatus.inProgress &&
        hasIntervention &&
        hasNote &&
        hasProof &&
        (_intervention != 'Other' || hasOfflineProof);

    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update status',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            closed
                ? 'This flag is closed. Reopen if the issue returns.'
                : 'Start → act → Resolve. Proof = reminder draft or Other + details.',
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminDssTheme.textMuted,
            ),
          ),
          if (!closed) ...[
            const SizedBox(height: 10),
            _resolveChecklist(
              started: started,
              assigned: hasAssigned,
              intervention: hasIntervention,
              note: hasNote,
              proof: hasProof,
            ),
          ],
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final options = List<String>.from(
                DssCopy.interventionsForRule(flag.ruleId),
              );
              if (_intervention != null &&
                  _intervention!.isNotEmpty &&
                  !options.contains(_intervention)) {
                options.insert(0, _intervention!);
              }
              final value =
                  options.contains(_intervention) ? _intervention : null;
              return DropdownButtonFormField<String>(
                key: ValueKey('intervention-${flag.ruleId}-$value'),
                initialValue: value,
                decoration:
                    _fieldDecoration('Intervention (required to resolve)'),
                items: options
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (v) => setState(() => _intervention = v),
              );
            },
          ),
          if (_intervention == 'Other') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _interventionDetailCtrl,
              minLines: 2,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecoration(
                'Describe offline action (counts as proof)',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(_assignedTo ?? ''),
            initialValue: _assignedTo ?? '',
            decoration: _fieldDecoration('Assign owner'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Unassigned')),
              ..._admins.map(
                (a) => DropdownMenuItem(value: a.id, child: Text(a.label)),
              ),
            ],
            onChanged: _saving
                ? null
                : (v) async {
                    final id = (v == null || v.isEmpty) ? null : v;
                    final label = id == null
                        ? null
                        : _admins
                            .where((a) => a.id == id)
                            .map((a) => a.label)
                            .firstOrNull;
                    setState(() {
                      _assignedTo = id;
                      _saving = true;
                    });
                    try {
                      await _repo.assignOwner(
                        flagId: flag.id,
                        userId: id,
                        ownerLabel: label,
                      );
                      await _load();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Assign failed: $e'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(
              closed ? 'Admin note' : 'Admin note (required to resolve)',
            ).copyWith(
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (flag.status == DssFlagStatus.open)
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () => _setStatus(DssFlagStatus.inProgress),
                  style: dssFilledButtonStyle(),
                  child: const Text('Start'),
                ),
              if (flag.status == DssFlagStatus.inProgress)
                FilledButton(
                  onPressed: _saving || !canResolve
                      ? null
                      : () => _setStatus(DssFlagStatus.resolved),
                  style: dssFilledButtonStyle(background: AdminDssTheme.success),
                  child: const Text('Resolve'),
                ),
              if (flag.status == DssFlagStatus.open)
                Tooltip(
                  message: 'Start the flag before resolving',
                  child: FilledButton(
                    onPressed: null,
                    style: dssFilledButtonStyle(
                      background: AdminDssTheme.success,
                    ),
                    child: const Text('Resolve'),
                  ),
                ),
              if (flag.status != DssFlagStatus.dismissed && !closed)
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _setStatus(DssFlagStatus.dismissed),
                  style: dssOutlinedButtonStyle(),
                  child: const Text('Dismiss'),
                ),
              if (closed)
                FilledButton(
                  onPressed: _saving ? null : _reopen,
                  style: dssFilledButtonStyle(),
                  child: const Text('Reopen'),
                ),
              OutlinedButton(
                onPressed: _saving ? null : _addNoteOnly,
                style: dssOutlinedButtonStyle(),
                child: const Text('Add note'),
              ),
            ],
          ),
          if (flag.status == DssFlagStatus.inProgress && !canResolve) ...[
            const SizedBox(height: 8),
            Text(
              !hasProof
                  ? 'Resolve unlocks after Draft reminder (or Other + details) and a note.'
                  : 'Finish the checklist items above to unlock Resolve.',
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminDssTheme.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resolveChecklist({
    required bool started,
    required bool assigned,
    required bool intervention,
    required bool note,
    required bool proof,
  }) {
    Widget row(bool ok, String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 15,
              color: ok ? AdminDssTheme.success : AdminDssTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: ok
                      ? AdminDssTheme.textPrimary
                      : AdminDssTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(started, 'Started'),
        row(assigned, 'Owner assigned (recommended)'),
        row(intervention, 'Intervention chosen'),
        row(note, 'Resolution note ready'),
        row(proof, 'Proof: reminder draft or Other details'),
      ],
    );
  }

  Widget _notesCard(DateFormat df) {
    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Action log',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a row to view the full entry.',
            style: TextStyle(fontSize: 11.5, color: AdminDssTheme.textMuted),
          ),
          const SizedBox(height: 8),
          if (_notes.isEmpty)
            const Text(
              'No notes yet.',
              style: TextStyle(color: AdminDssTheme.textMuted, fontSize: 12.5),
            )
          else
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: [
                  for (final n in _notes) _actionLogTile(n, df),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionLogTile(DssFlagNote n, DateFormat df) {
    final typeColor = switch (n.eventType) {
      DssNoteEventType.status => AdminDssTheme.info,
      DssNoteEventType.impact => AdminDssTheme.warning,
      DssNoteEventType.assign => AdminDssTheme.primary,
      DssNoteEventType.announcement => AdminDssTheme.success,
      DssNoteEventType.reopen => AdminDssTheme.danger,
      DssNoteEventType.action => AdminDssTheme.navy,
      DssNoteEventType.note => AdminDssTheme.textSecondary,
    };
    final meta = n.metadata;
    final intervention = meta['intervention']?.toString();
    final detail = meta['intervention_detail']?.toString();
    final verdict = meta['impact_verdict']?.toString();
    final followup = meta['followup_value'];
    final baseline = meta['baseline_value'];
    final announcementId = meta['announcement_id']?.toString();
    final ownerLabel = meta['owner_label']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AdminDssTheme.surface,
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
        border: Border.all(color: AdminDssTheme.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        dense: true,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                n.eventType.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: typeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                n.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AdminDssTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${n.authorName.isEmpty ? 'Admin' : n.authorName}'
            ' · ${df.format(n.createdAt.toLocal())}'
            '${n.statusFrom != null && n.statusTo != null && n.statusFrom != n.statusTo ? ' · ${n.statusFrom} → ${n.statusTo}' : ''}',
            style: const TextStyle(
              fontSize: 11,
              color: AdminDssTheme.textMuted,
            ),
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              n.note,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AdminDssTheme.textPrimary,
              ),
            ),
          ),
          if (intervention != null && intervention.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Intervention: $intervention',
              style: const TextStyle(
                fontSize: 12,
                color: AdminDssTheme.textSecondary,
              ),
            ),
          ],
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Details: $detail',
              style: const TextStyle(
                fontSize: 12,
                color: AdminDssTheme.textSecondary,
              ),
            ),
          ],
          if (verdict != null && verdict.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Impact: ${DssImpactVerdictX.fromDb(verdict)?.label ?? verdict}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminDssTheme.textPrimary,
              ),
            ),
          ],
          if (baseline != null || followup != null) ...[
            const SizedBox(height: 4),
            Text(
              'Metric: ${baseline ?? '—'} → ${followup ?? '—'}',
              style: const TextStyle(
                fontSize: 12,
                color: AdminDssTheme.textSecondary,
              ),
            ),
          ],
          if (announcementId != null && announcementId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Announcement: $announcementId',
              style: const TextStyle(
                fontSize: 12,
                color: AdminDssTheme.textSecondary,
              ),
            ),
          ],
          if (ownerLabel != null && ownerLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Owner: $ownerLabel',
              style: const TextStyle(
                fontSize: 12,
                color: AdminDssTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    final radius = BorderRadius.circular(AdminDssTheme.radiusSm);
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: AdminDssTheme.textSecondary,
      ),
      filled: true,
      fillColor: AdminDssTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AdminDssTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AdminDssTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AdminDssTheme.primary, width: 1.5),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminDssTheme.surface,
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(fontSize: 12, color: AdminDssTheme.textMuted),
            ),
            TextSpan(
              text: v,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminDssTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminOption {
  const _AdminOption({required this.id, required this.label});
  final String id;
  final String label;
}

/// Backward-compatible route wrapper (unused by main panel flow).
class AdminDssDetailPage extends StatelessWidget {
  const AdminDssDetailPage({
    super.key,
    required this.flagId,
    this.onOpenAdminMenu,
  });

  final String flagId;
  final void Function(int menuIndex)? onOpenAdminMenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDssTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AdminDensity.space3),
          child: AdminDssDetailPanel(
            flagId: flagId,
            onOpenAdminMenu: onOpenAdminMenu,
            onClose: () async => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
