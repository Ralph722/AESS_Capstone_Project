import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/admin/announcements/presentation/admin_announcement_editor_page.dart';
import 'package:alumni_system/features/admin/dss/application/dss_ai_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluation_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_impact.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_priority.dart';
import 'package:alumni_system/features/admin/dss/application/dss_suggestion_themes.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/dss/widgets/dss_accountability_cards.dart';
import 'package:alumni_system/features/admin/dss/widgets/dss_action_dialogs.dart';
import 'package:alumni_system/features/admin/dss/widgets/dss_outcome_card.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';

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

  /// Kept for callers; sidebar shortcuts were removed from Act in AESS.
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
  final _planDescriptionCtrl = TextEditingController();
  final _planExpectedCtrl = TextEditingController();
  final _planTargetCtrl = TextEditingController();
  final _mainScroll = ScrollController();
  final _planKey = GlobalKey();
  final _ownerKey = GlobalKey();
  final _proofKey = GlobalKey();
  final _actKey = GlobalKey();
  final _timelineKey = GlobalKey();
  DateTime _planStartedOn = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  bool _planDetailsExpanded = false;
  String _planTargetBaseline = '';

  DssFlag? _flag;
  List<DssFlagNote> _notes = [];
  List<DssFlagEvidence> _evidence = [];
  bool _hasAccountability = false;
  List<DssIntervention> _interventions = [];
  bool _hasOutcomes = false;
  DssOutcomeCheck? _outcomeCheck;
  List<_AdminOption> _admins = [];
  bool _loading = true;
  bool _saving = false;
  bool _rechecking = false;
  DssAiExplanation? _aiExplanation;
  bool _explaining = false;
  DssSuggestionSummary? _suggestions;
  bool _loadingSuggestions = false;
  String? _error;
  String? _intervention;
  String? _assignedTo;
  late String _flagId = widget.flagId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _interventionDetailCtrl.dispose();
    _planDescriptionCtrl.dispose();
    _planExpectedCtrl.dispose();
    _planTargetCtrl.dispose();
    _mainScroll.dispose();
    super.dispose();
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _syncPlanFields(DssFlag? flag, List<DssIntervention> interventions) {
    DssIntervention? undecided;
    for (final i in interventions) {
      if (!i.isDecided) {
        undecided = i;
        break;
      }
    }
    if (undecided != null) {
      _intervention = undecided.interventionType;
      _planDescriptionCtrl.text = undecided.description;
      _planExpectedCtrl.text = undecided.expectedOutcome;
      _planStartedOn = _dayOnly(undecided.startedOn);
      _planTargetBaseline = dssFormatOutcomeTarget(
        undecided.successMetric,
        undecided.successTarget,
      );
      _planTargetCtrl.text = _planTargetBaseline;
      _planDetailsExpanded =
          undecided.description.isNotEmpty ||
          undecided.expectedOutcome.isNotEmpty;
      return;
    }
    if (flag == null) return;
    final defaults = dssOutcomeDefaults(flag);
    _planTargetBaseline = dssFormatOutcomeTarget(
      defaults.metric,
      defaults.target,
    );
    _planTargetCtrl.text = _planTargetBaseline;
    _planDescriptionCtrl.clear();
    _planExpectedCtrl.clear();
    _planStartedOn = _dayOnly(flag.startDate ?? DateTime.now());
    _planDetailsExpanded = false;
  }

  bool get _planDirty {
    final flag = _flag;
    if (flag == null) return false;
    final undecided = _undecidedIntervention;
    final type = (_intervention ?? '').trim();
    if (undecided != null) {
      return type != undecided.interventionType ||
          _planDescriptionCtrl.text.trim() != undecided.description ||
          _planExpectedCtrl.text.trim() != undecided.expectedOutcome ||
          _planTargetCtrl.text.trim() != _planTargetBaseline ||
          _dayOnly(_planStartedOn) != _dayOnly(undecided.startedOn);
    }
    if (type.isEmpty) return false;
    return _planDescriptionCtrl.text.trim().isNotEmpty ||
        _planExpectedCtrl.text.trim().isNotEmpty ||
        _planTargetCtrl.text.trim() != _planTargetBaseline ||
        _dayOnly(_planStartedOn) !=
            _dayOnly(flag.startDate ?? DateTime.now());
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final flag = await _repo.getFlag(_flagId);
      final notes = flag == null
          ? <DssFlagNote>[]
          : await _repo.listNotes(flag.id);
      final hasAccountability = await _repo.hasAccountability();
      final evidence = flag == null || !hasAccountability
          ? <DssFlagEvidence>[]
          : await _repo.listEvidence(flag.id);
      final hasOutcomes = await _repo.hasOutcomes();
      final interventions = flag == null || !hasOutcomes
          ? <DssIntervention>[]
          : await _repo.listInterventions(flag.findingKey);
      final admins = await _repo.listAdminUsers();
      if (!mounted) return;
      setState(() {
        _flag = flag;
        _notes = notes;
        _evidence = evidence;
        _hasAccountability = hasAccountability;
        _interventions = interventions;
        _hasOutcomes = hasOutcomes;
        _outcomeCheck = null;
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
          if (!allowed.contains(_intervention) && !flag.status.isClosed) {
            _intervention = null;
          }
        }
        if ((flag?.interventionDetail ?? '').isNotEmpty) {
          _interventionDetailCtrl.text = flag!.interventionDetail!;
        } else {
          _interventionDetailCtrl.clear();
        }
        _syncPlanFields(flag, interventions);
        // Prefer flag.interventionType when no undecided plan yet.
        if (_undecidedIntervention == null && flag?.interventionType != null) {
          final allowed = DssCopy.interventionsForRule(flag!.ruleId);
          if (allowed.contains(flag.interventionType) || flag.status.isClosed) {
            _intervention = flag.interventionType;
          }
        }
        _loading = false;
        if (flag == null) _error = 'Flag not found.';
      });
      if (flag != null && _suggestions == null) _loadSuggestions(flag);
      final undecided = _undecidedIntervention;
      if (undecided != null) _checkOutcome(undecided, silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Asks AI to explain the finding; only on request.
  Future<void> _explainWithAi(DssFlag flag) async {
    setState(() => _explaining = true);
    try {
      final result = await _ai.explainFlag(flag);
      if (!mounted || _flag?.id != flag.id) return;
      setState(() => _aiExplanation = result);
    } finally {
      if (mounted) setState(() => _explaining = false);
    }
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
      final hasLinked = (flag.linkedAnnouncementId ?? '').trim().isNotEmpty;
      final hasOfflineProof =
          intervention == 'Other' &&
          _interventionDetailCtrl.text.trim().isNotEmpty;
      if (!hasLinked && !hasOfflineProof && _evidence.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add proof first: Draft reminder, an evidence entry, or choose Other and describe the offline action.',
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

      if (status == DssFlagStatus.inProgress && _hasOutcomes && _planDirty) {
        await _persistPlan(flag, requireType: true);
      }
      if (status == DssFlagStatus.resolved && _hasOutcomes) {
        await _persistPlan(flag, requireType: true, forResolve: true);
      }

      await _repo.updateFlagStatus(
        flag: flag,
        status: status,
        note: _noteCtrl.text,
        interventionType: status == DssFlagStatus.resolved
            ? _intervention
            : null,
        interventionDetail: status == DssFlagStatus.resolved ? detail : null,
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
                ? 'Resolved. Coverage re-check: ${verdict.label}.'
                      '${_hasOutcomes ? ' The outcome is judged from the next tracer wave.' : ''}'
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
          content: Text('Finding reopened'),
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
      final nextDue =
          verdict == DssImpactVerdict.stillFlagged ||
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
          content: Text('Coverage re-check: ${verdict.label}'),
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
      final title = 'Tracer reminder: ${flag.cohortLabel}';
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

  Future<void> _addEvidence() async {
    final flag = _flag;
    if (flag == null) return;
    final draft = await showDssAddEvidenceDialog(context);
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _repo.addEvidence(
        flag: flag,
        type: draft.type,
        title: draft.title,
        date: draft.date,
        description: draft.description,
        link: draft.link,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not add evidence: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeEvidence(DssFlagEvidence entry) async {
    final flag = _flag;
    if (flag == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: AdminDialogStandards.shape,
        elevation: AdminDialogStandards.elevation,
        title: const Text('Remove evidence?'),
        content: Text(
          '"${entry.title}" will be hidden from this list. The action log '
          'keeps a record that it was added and removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: dssFilledButtonStyle(background: AdminDssTheme.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _repo.removeEvidence(flag: flag, entry: entry);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not remove evidence: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DssIntervention? get _undecidedIntervention {
    for (final i in _interventions) {
      if (!i.isDecided) return i;
    }
    return null;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  static String _errorText(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  Future<void> _checkOutcome(
    DssIntervention intervention, {
    bool silent = false,
  }) async {
    final flag = _flag;
    if (flag == null) return;
    if (!silent) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Check outcome'),
          content: const Text(
            'Outcome is judged from the next CHED GTS wave after this '
            'intervention started.\n\n'
            'If that wave is still open, you will see a preview only — the '
            'final judgment waits until the wave closes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Check now'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      setState(() => _saving = true);
    }
    try {
      final check = await _repo.evaluateIntervention(intervention.id);
      final interventions = await _repo.listInterventions(flag.findingKey);
      final notes = await _repo.listNotes(flag.id);
      if (!mounted || _flag?.id != flag.id) return;
      setState(() {
        _outcomeCheck = check;
        _interventions = interventions;
        _notes = notes;
      });
      if (!silent) {
        final preview = check.provisional && check.previewStatus != null
            ? ' (preview: ${check.previewStatus!.label})'
            : '';
        _showMessage('Outcome: ${check.outcomeStatus.label}$preview');
      }
    } catch (e) {
      if (!silent && mounted) {
        _showMessage('Could not check the outcome: ${_errorText(e)}');
      }
    } finally {
      if (!silent && mounted) setState(() => _saving = false);
    }
  }

  Future<void> _persistPlan(
    DssFlag flag, {
    required bool requireType,
    bool forResolve = false,
  }) async {
    final type = (_intervention ?? '').trim();
    if (type.isEmpty) {
      if (requireType) {
        throw Exception('Choose a plan type first.');
      }
      return;
    }
    final undecided = _undecidedIntervention;
    final defaults = dssOutcomeDefaults(flag);
    final metric = undecided?.successMetric ?? defaults.metric;
    final parsed = dssParseOutcomeTarget(metric, _planTargetCtrl.text);
    if (parsed == null) {
      throw Exception(
        metric == 'salary_peer_gap'
            ? 'Enter a target between -10 and 10 brackets.'
            : 'Enter a target between 0 and 100%.',
      );
    }
    final description = _planDescriptionCtrl.text.trim().isNotEmpty
        ? _planDescriptionCtrl.text.trim()
        : (type == 'Other'
              ? _interventionDetailCtrl.text.trim()
              : (forResolve ? _noteCtrl.text.trim() : ''));
    final expected = _planExpectedCtrl.text.trim();
    final targetUnchanged =
        _planTargetCtrl.text.trim() == _planTargetBaseline;

    if (undecided != null) {
      if (!_planDirty) return;
      await _repo.updateInterventionPlan(
        intervention: undecided,
        interventionType: type,
        description: description,
        expectedOutcome: expected,
        successTarget: parsed,
        startedOn: _planStartedOn,
      );
      return;
    }
    if (!forResolve && !_planDirty) return;
    await _repo.recordIntervention(
      flag: flag,
      interventionType: type,
      description: description,
      expectedOutcome: expected,
      successTarget: targetUnchanged ? null : parsed,
      startedOn: _planStartedOn,
    );
  }

  Future<void> _savePlan() async {
    final flag = _flag;
    if (flag == null) return;
    setState(() => _saving = true);
    try {
      await _persistPlan(flag, requireType: true);
      await _load();
      if (mounted) _showMessage('Plan saved.');
    } catch (e) {
      if (mounted) _showMessage('Could not save the plan: ${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _decide(
    DssIntervention intervention,
    DssOutcomeDecision decision,
  ) async {
    final flag = _flag;
    if (flag == null) return;
    final draft = await showDssDecisionDialog(
      context,
      flag: flag,
      intervention: intervention,
      decision: decision,
    );
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _repo.decideIntervention(
        flag: flag,
        intervention: intervention,
        decision: decision,
        note: draft.note,
        office: draft.office,
        interventionType: draft.type,
        description: draft.description,
        expectedOutcome: draft.expectedOutcome,
        successTarget: draft.target,
      );
      await _load();
      if (mounted) _showMessage('Decision recorded: ${decision.label}');
    } catch (e) {
      if (mounted) {
        _showMessage('Could not record the decision: ${_errorText(e)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Plan: intervention type + optional next-wave fields (inline).
  Widget _interventionCard(DssFlag flag) {
    final closed = flag.status.isClosed;
    final readOnly = closed && _undecidedIntervention?.canEditPlan != true;
    final undecided = _undecidedIntervention;
    final options = List<String>.from(
      DssCopy.interventionsForRule(flag.ruleId),
    );
    if (_intervention != null &&
        _intervention!.isNotEmpty &&
        !options.contains(_intervention)) {
      options.insert(0, _intervention!);
    }
    final value = options.contains(_intervention) ? _intervention : null;
    final defaults = dssOutcomeDefaults(flag);
    final metric = undecided?.successMetric ?? defaults.metric;
    final operator = undecided?.successOperator ?? defaults.operator;
    final salary = metric == 'salary_peer_gap';
    final targetError = dssParseOutcomeTarget(metric, _planTargetCtrl.text) ==
            null
        ? (salary ? 'Enter -10 to 10 brackets' : 'Enter 0 to 100')
        : null;
    final today = _dayOnly(DateTime.now());
    final canEdit =
        !readOnly &&
        (flag.status == DssFlagStatus.open ||
            flag.status == DssFlagStatus.inProgress ||
            (undecided?.canEditPlan ?? false));

    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            undecided == null
                ? 'Required to Resolve finding. Optional details track '
                      'next-wave outcome.'
                : 'Outcome: ${undecided.outcomeStatus.label}. Edit inline; '
                      'Save plan when fields change.',
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminDssTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('plan-${flag.ruleId}-$value'),
            initialValue: value,
            dropdownColor: Colors.white,
            decoration: _fieldDecoration('Plan type (required to resolve)'),
            items: options
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: canEdit
                ? (v) => setState(() => _intervention = v)
                : null,
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
              onChanged: canEdit ? (_) => setState(() {}) : null,
              enabled: canEdit,
            ),
          ],
          if (_hasOutcomes) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey(
                  'plan-details-${flag.id}-${undecided?.id ?? 'new'}',
                ),
                initiallyExpanded: _planDetailsExpanded,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 2),
                onExpansionChanged: (open) =>
                    setState(() => _planDetailsExpanded = open),
                title: const Text(
                  'Add plan details',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminDssTheme.textSecondary,
                  ),
                ),
                children: [
                  TextField(
                    controller: _planDescriptionCtrl,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 2000,
                    style: const TextStyle(fontSize: 13),
                    onChanged: canEdit ? (_) => setState(() {}) : null,
                    enabled: canEdit,
                    decoration: _fieldDecoration(
                      'What is being done',
                    ).copyWith(alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _planExpectedCtrl,
                    maxLength: 1000,
                    style: const TextStyle(fontSize: 13),
                    onChanged: canEdit ? (_) => setState(() {}) : null,
                    enabled: canEdit,
                    decoration: _fieldDecoration(
                      'Expected outcome',
                      helper:
                          'e.g. More of this batch employed by the next tracer',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _planTargetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: canEdit ? (_) => setState(() {}) : null,
                    enabled: canEdit,
                    decoration: _fieldDecoration(
                      'Target: ${DssCopy.outcomeMetricLabel(metric)} '
                      '${DssCopy.outcomeOperator(operator)}',
                      helper: salary
                          ? 'Salary brackets. Default is the rule threshold.'
                          : 'Percent of answers. Default is the rule threshold.',
                      error: targetError,
                    ).copyWith(suffixText: salary ? 'brackets' : '%'),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: !canEdit
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _planStartedOn.isAfter(today)
                                  ? today
                                  : _planStartedOn,
                              firstDate: DateTime(today.year - 5),
                              lastDate: today,
                            );
                            if (picked != null) {
                              setState(
                                () => _planStartedOn = _dayOnly(picked),
                              );
                            }
                          },
                    child: InputDecorator(
                      decoration: _fieldDecoration(
                        'Started',
                        helper:
                            'Outcome comes from the first tracer wave '
                            'published after this date.',
                      ).copyWith(
                        suffixIcon: const Icon(Icons.calendar_today, size: 16),
                      ),
                      child: Text(
                        DateFormat.yMMMd().format(_planStartedOn),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit && _planDirty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _savePlan,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save plan'),
                  style: dssFilledButtonStyle(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
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
            title: 'Finding',
            onBack: () => widget.onClose(),
            actions: const [],
          ),
          Expanded(child: Center(child: Text(_error ?? 'Not found'))),
        ],
      );
    }

    final flag = _flag!;
    final playbook = DssCopy.displayPlaybook(flag);
    final showSuggestions = DssSuggestionThemeService.appliesTo(flag);
    final wide =
        MediaQuery.sizeOf(context).width >= AdminDensity.desktopSplitMin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DssPageHeader(
          title: DssCopy.displayTitle(flag),
          subtitle:
              flag.cohortLabel +
              (flag.surveyTitle.isEmpty ? '' : ' · ${flag.surveyTitle}'),
          onBack: () => widget.onClose(),
          backTooltip: 'Back to findings',
          actions: [DssStatusChip(status: flag.status)],
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
                        controller: _mainScroll,
                        children: _fixedBody(
                          flag,
                          playbook,
                          includeStatus: false,
                          showSuggestions: showSuggestions,
                        ),
                      ),
                    ),
                    const SizedBox(width: AdminDssTheme.space2),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: _statusPanel(flag),
                      ),
                    ),
                  ],
                )
              : ListView(
                  controller: _mainScroll,
                  children: _fixedBody(
                    flag,
                    playbook,
                    includeStatus: true,
                    showSuggestions: showSuggestions,
                  ),
                ),
        ),
      ],
    );
  }

  /// Fixed card order — never reorders by stage (Phase 2).
  List<Widget> _fixedBody(
    DssFlag flag,
    List<DssPlaybookStep> playbook, {
    required bool includeStatus,
    required bool showSuggestions,
  }) {
    final hasUndecided = _undecidedIntervention != null;
    final outcomeReady = _outcomeCheck != null && !(_outcomeCheck!.provisional);
    final next = dssNextAction(
      flag,
      hasUndecidedIntervention: hasUndecided,
      outcomeReady: outcomeReady,
    );

    final children = <Widget>[
      DssStageStrip(
        flag: flag,
        hasUndecidedIntervention: hasUndecided,
        outcomeReady: outcomeReady,
      ),
    ];

    void ensureGap() {
      if (children.isNotEmpty && children.last is! SizedBox) {
        children.add(const SizedBox(height: AdminDssTheme.space2));
      }
    }

    void push(Widget w, {bool nextStep = false}) {
      ensureGap();
      children.add(nextStep ? _withNextBadge(w) : w);
    }

    final badgeTarget = _nextBadgeTarget(flag, next);
    if (includeStatus) {
      push(_statusPanel(flag), nextStep: badgeTarget == _NextBadgeTarget.panel);
    }
    push(_findingCard(flag, playbook));
    if (flag.isActive) push(_priorityCard(flag));
    if (_showInterventionSection(flag)) {
      push(
        KeyedSubtree(key: _planKey, child: _interventionCard(flag)),
        nextStep: badgeTarget == _NextBadgeTarget.plan,
      );
    }
    if (_hasAccountability && flag.status != DssFlagStatus.watch) {
      push(
        KeyedSubtree(
          key: _ownerKey,
          child: DssAccountabilityCard(
            key: ValueKey(
              'owner-${flag.id}-${flag.updatedAt.toIso8601String()}',
            ),
            flag: flag,
            repository: _repo,
            onSaved: _load,
            assignedTo: _assignedTo,
            admins: [
              for (final a in _admins) DssAdminChoice(id: a.id, label: a.label),
            ],
          ),
        ),
      );
      final otherProof = _intervention == 'Other'
          ? _interventionDetailCtrl.text.trim()
          : '';
      push(
        KeyedSubtree(
          key: _proofKey,
          child: DssProofCard(
            entries: _evidence,
            canEdit: _canAct(flag),
            busy: _saving,
            onAdd: _addEvidence,
            onRemove: _removeEvidence,
            linkedAnnouncementId: flag.linkedAnnouncementId,
            linkedAnnouncementAt: flag.updatedAt,
            offlineOtherDetail: otherProof.isEmpty ? null : otherProof,
          ),
        ),
        nextStep: badgeTarget == _NextBadgeTarget.proof,
      );
    }
    if (_canAct(flag)) {
      push(
        KeyedSubtree(key: _actKey, child: _actCard(flag)),
        nextStep: badgeTarget == _NextBadgeTarget.act,
      );
    }
    if (showSuggestions) push(_suggestionsCard());
    push(
      KeyedSubtree(
        key: _timelineKey,
        child: _whatHappenedCard(flag),
      ),
      nextStep: badgeTarget == _NextBadgeTarget.outcome,
    );

    return children;
  }

  Widget _withNextBadge(Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: DssMetaChip(
            label: 'Next step',
            color: AdminDssTheme.primary,
            icon: Icons.arrow_forward,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  _NextBadgeTarget _nextBadgeTarget(DssFlag flag, DssNextAction next) {
    switch (next.kind) {
      case DssNextActionKind.start:
      case DssNextActionKind.reopen:
      case DssNextActionKind.dismissOnly:
      case DssNextActionKind.none:
      case DssNextActionKind.wait:
        return _NextBadgeTarget.panel;
      case DssNextActionKind.resolve:
        final hasIntervention = (_intervention ?? '').trim().isNotEmpty;
        final hasLinked = (flag.linkedAnnouncementId ?? '').trim().isNotEmpty;
        final hasOfflineProof =
            _intervention == 'Other' &&
            _interventionDetailCtrl.text.trim().isNotEmpty;
        final hasProof = hasLinked || hasOfflineProof || _evidence.isNotEmpty;
        if (!hasIntervention) return _NextBadgeTarget.plan;
        if (!hasProof) {
          return _hasAccountability
              ? _NextBadgeTarget.proof
              : _NextBadgeTarget.act;
        }
        if (_noteCtrl.text.trim().isEmpty) return _NextBadgeTarget.panel;
        return _NextBadgeTarget.panel;
      case DssNextActionKind.checkOutcome:
      case DssNextActionKind.decide:
        return _NextBadgeTarget.outcome;
    }
  }

  /// "Explain with AI" and its result. AI text is always labeled and never
  /// changes the finding; a rejected or failed reply shows the rule-based
  /// explanation instead.
  Widget _aiExplanationSection(DssFlag flag) {
    const small = TextStyle(
      fontSize: 11.5,
      height: 1.35,
      color: AdminDssTheme.textMuted,
    );
    final result = _aiExplanation;
    if (result == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _explaining ? null : () => _explainWithAi(flag),
          icon: _explaining
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text(_explaining ? 'Writing explanation…' : 'Explain with AI'),
          style: dssOutlinedButtonStyle(),
        ),
      );
    }
    final String label;
    final String? note;
    if (result.byAi) {
      label = 'AI explanation';
      note =
          'Written by AI from the figures on this page. It does not change '
          'the finding, its priority or its status.';
    } else {
      label = 'Rule-based explanation';
      note = result.rejectedReason != null
          ? 'The AI reply was not used because ${result.rejectedReason}.'
          : 'AI is unavailable right now.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminDssTheme.surface,
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusMd),
        border: Border.all(color: AdminDssTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.byAi ? Icons.auto_awesome_outlined : Icons.rule,
                size: 15,
                color: AdminDssTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminDssTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.text,
            softWrap: true,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(note, style: small),
        ],
      ),
    );
  }

  Widget _findingCard(DssFlag flag, List<DssPlaybookStep> playbook) {
    final shownPlaybook = playbook.isNotEmpty
        ? playbook
        : DssCopy.displayPlaybook(flag);
    final cause = flag.playbook.any((s) => s.cause != null)
        ? DssCopy.playbookCause(flag)
        : null;
    final why = DssCopy.whyFlagged(flag);
    final next = DssCopy.displayRecommendedAction(flag);
    final headline = DssCopy.displayHeadline(flag);
    final showHeadline =
        flag.ruleId != 'DATA_QUALITY_LOW' && !_isNearDuplicate(headline, why);

    final detailLines = <Widget>[
      if (showHeadline)
        Text(
          headline,
          style: const TextStyle(
            color: AdminDssTheme.textSecondary,
            height: 1.4,
            fontSize: 12.5,
          ),
        ),
      if (DssCopy.rollupNote(flag) case final note?)
        Text(
          note,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AdminDssTheme.textSecondary,
          ),
        ),
      for (final note in [
        DssCopy.notEmployedReasonsNote(flag),
        DssCopy.coverageNote(flag),
        DssCopy.rosterBasisNote(flag),
      ].nonNulls)
        Text(
          note,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AdminDssTheme.textSecondary,
          ),
        ),
      if (flag.certainty != null && flag.isFinding)
        Text(
          DssCopy.certaintyHint(flag),
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AdminDssTheme.textSecondary,
          ),
        ),
      Text(
        DssCopy.sourceLabel(flag),
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AdminDssTheme.textMuted,
        ),
      ),
      if (_recheckNote(flag) case final note?)
        Text(
          note,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            fontWeight: flag.recheckRecovered
                ? FontWeight.w600
                : FontWeight.normal,
            color: flag.recheckRecovered
                ? AdminDssTheme.success
                : AdminDssTheme.textMuted,
          ),
        ),
      if (flag.confidence == DssConfidence.low && flag.isFinding)
        Text(
          DssCopy.confidenceLabel(flag),
          style: const TextStyle(fontSize: 12, color: AdminDssTheme.textMuted),
        ),
    ];

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
          const SizedBox(height: 8),
          if (_evidenceBanner(flag) case final banner?) ...[
            banner,
            const SizedBox(height: 8),
          ],
          Text(
            why,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
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
              DssEvidenceChip(flag: flag),
              if (flag.certainty != null && flag.isFinding)
                DssCertaintyChip(flag: flag),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DssCopy.thresholdLabel(flag),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 4),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                title: const Text(
                  'Supporting details',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminDssTheme.textSecondary,
                  ),
                ),
                children: [
                  for (final w in detailLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(alignment: Alignment.centerLeft, child: w),
                    ),
                ],
              ),
            ),
          ],
          if (DssAiService.isAvailable) ...[
            const SizedBox(height: 4),
            _aiExplanationSection(flag),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text(
            'Recommended action',
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
            const SizedBox(height: 4),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                title: Text(
                  cause == null ? 'Playbook steps' : 'Playbook: ${cause.label}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AdminDssTheme.textSecondary,
                  ),
                ),
                children: [
                  for (final e in shownPlaybook.asMap().entries)
                    Padding(
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact sample-size banner; full hint is in the tooltip.
  Widget? _evidenceBanner(DssFlag flag) {
    final label = DssCopy.evidenceLabel(flag);
    final hint = DssCopy.evidenceHint(flag);
    if (label == null || hint == null) return null;
    final finding = flag.isFinding;
    final color = finding ? AdminDssTheme.info : const Color(0xFFB45309);
    return Tooltip(
      message: hint,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
          border: Border.all(color: AdminDssTheme.border),
        ),
        child: Row(
          children: [
            Icon(
              finding ? Icons.info_outline : Icons.visibility_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionsCard() {
    final s = _suggestions;
    const muted = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: AdminDssTheme.textMuted,
    );
    const secondary = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: AdminDssTheme.textSecondary,
    );

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
            : const Text(
                'Could not load curriculum suggestions.',
                style: muted,
              ),
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
              ? 'Grouped by AI${aiLimited ? ' (first ${DssSuggestionThemeService.maxTexts} suggestions)' : ''}; '
                    'emails, phone numbers and links are removed before '
                    'sending. Quotes are the alumni\'s own words.'
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
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminDssTheme.textMuted,
                ),
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
    final closed = flag.status.isClosed;
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
                  onPressed: _saving || closed
                      ? null
                      : () => _runOneClick(flag),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _priorityCard(DssFlag flag) {
    final p = DssPriorityCalc.of(flag, now: DateTime.now());
    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Priority',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AdminDssTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              DssMetaChip(
                label: p.level == DssPriority.watch
                    ? p.level.label
                    : '${p.level.label} · score ${p.score}',
                icon: Icons.low_priority,
                color: dssPriorityColor(p.level),
              ),
            ],
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 2),
              title: const Text(
                'How this score was set',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdminDssTheme.textMuted,
                ),
              ),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Rule-based, not AI. Critical 7+, High 5–6, Medium 3–4, Low 0–2.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AdminDssTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final r in p.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            r.points == 0 ? '·' : '+${r.points}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: r.points == 0
                                  ? AdminDssTheme.textMuted
                                  : AdminDssTheme.textPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r.text,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AdminDssTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _canAct(DssFlag flag) =>
      flag.status != DssFlagStatus.watch &&
      flag.status != DssFlagStatus.superseded;

  static bool _showInterventionSection(DssFlag flag) =>
      flag.status == DssFlagStatus.open ||
      flag.status == DssFlagStatus.inProgress ||
      flag.status == DssFlagStatus.resolved;

  Widget _statusPanel(DssFlag flag) => switch (flag.status) {
    DssFlagStatus.superseded => _supersededCard(flag),
    DssFlagStatus.watch => _watchCard(flag),
    _ => _statusCard(flag),
  };

  void _openFlag(String id) {
    setState(() {
      _flagId = id;
      _flag = null;
      _aiExplanation = null;
      _explaining = false;
      _suggestions = null;
      _intervention = null;
      _assignedTo = null;
      _evidence = [];
    });
    _noteCtrl.clear();
    _interventionDetailCtrl.clear();
    _planDescriptionCtrl.clear();
    _planExpectedCtrl.clear();
    _planTargetCtrl.clear();
    _planDetailsExpanded = false;
    _load();
  }

  Widget _statusCardShell({
    required String title,
    required String body,
    required List<Widget> children,
  }) {
    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminDssTheme.textMuted,
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _supersededCard(DssFlag flag) {
    final at = flag.supersededAt;
    final newer = flag.supersededBy;
    return _statusCardShell(
      title: 'Superseded',
      body:
          'A newer CHED GTS wave checked the same finding'
          '${at == null ? '' : ' on ${DateFormat.yMMMd().format(at.toLocal())}'}'
          '${newer == null ? ' and has no active finding for it' : ''}. '
          'This finding is kept as history and can no longer change.',
      children: [
        if (newer != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : () => _openFlag(newer),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Open newer finding'),
            style: dssFilledButtonStyle(),
          ),
        ],
      ],
    );
  }

  Widget _watchCard(DssFlag flag) {
    return _statusCardShell(
      title: 'Watch item',
      body:
          'Too few valid answers for a finding. Re-run analysis makes it a '
          'finding once enough alumni answer; until then you can dismiss it '
          'or add notes.',
      children: [
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(fontSize: 13),
          onChanged: (_) => setState(() {}),
          decoration: _fieldDecoration(
            'Admin note',
          ).copyWith(alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => _setStatus(DssFlagStatus.dismissed),
              style: dssOutlinedButtonStyle(),
              child: const Text('Dismiss'),
            ),
            OutlinedButton(
              onPressed: _saving ? null : _addNoteOnly,
              style: dssOutlinedButtonStyle(),
              child: const Text('Add note'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusCard(DssFlag flag) {
    final closed = flag.status.isClosed;
    final started = flag.status == DssFlagStatus.inProgress || closed;
    final hasIntervention = (_intervention ?? '').trim().isNotEmpty;
    final hasNote = _noteCtrl.text.trim().isNotEmpty;
    final hasAssigned =
        (_assignedTo ?? '').trim().isNotEmpty ||
        (flag.ownerOffice ?? '').trim().isNotEmpty ||
        (flag.responsibleName ?? '').trim().isNotEmpty;
    final hasLinked = (flag.linkedAnnouncementId ?? '').trim().isNotEmpty;
    final hasOfflineProof =
        _intervention == 'Other' &&
        _interventionDetailCtrl.text.trim().isNotEmpty;
    final hasProof = hasLinked || hasOfflineProof || _evidence.isNotEmpty;
    final canResolve =
        flag.status == DssFlagStatus.inProgress &&
        hasIntervention &&
        hasNote &&
        hasProof &&
        (_intervention != 'Other' || hasOfflineProof);
    final hasUndecided = _undecidedIntervention != null;
    final outcomeReady = _outcomeCheck != null && !(_outcomeCheck!.provisional);
    final next = dssNextAction(
      flag,
      hasUndecidedIntervention: hasUndecided,
      outcomeReady: outcomeReady,
    );

    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Action',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            next.hint,
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminDssTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          _actionSteps(
            flag: flag,
            started: started,
            assigned: hasAssigned,
            intervention: hasIntervention,
            proof: hasProof,
            note: hasNote,
            resolved: closed && flag.status == DssFlagStatus.resolved,
            outcomeReady: outcomeReady,
            hasUndecided: hasUndecided,
          ),
          if (_undecidedIntervention != null) ...[
            const SizedBox(height: 10),
            _panelOutcomeSummary(_undecidedIntervention!),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(
              closed ? 'Admin note' : 'Admin note (required to resolve)',
            ).copyWith(alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          ..._actionPrimaryButtons(
            flag: flag,
            next: next,
            canResolve: canResolve,
            hasProof: hasProof,
          ),
        ],
      ),
    );
  }

  Widget _panelOutcomeSummary(DssIntervention i) {
    final preview = _outcomeCheck != null && _outcomeCheck!.provisional
        ? _outcomeCheck
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminDssTheme.surface,
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
        border: Border.all(color: AdminDssTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  i.interventionType,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AdminDssTheme.textPrimary,
                  ),
                ),
              ),
              DssMetaChip(
                label: i.outcomeStatus.label,
                color: dssOutcomeColor(i.outcomeStatus),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DssCopy.outcomeFollowup(i),
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminDssTheme.textMuted,
            ),
          ),
          if (preview?.previewStatus != null) ...[
            const SizedBox(height: 4),
            Text(
              'Preview (wave still open): ${preview!.previewStatus!.label}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminDssTheme.info,
              ),
            ),
          ],
          if (i.canEditPlan) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _saving ? null : () => _scrollTo(_planKey),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Edit plan'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _actionPrimaryButtons({
    required DssFlag flag,
    required DssNextAction next,
    required bool canResolve,
    required bool hasProof,
  }) {
    final closed = flag.status.isClosed;
    final primary = switch (next.kind) {
      DssNextActionKind.start => FilledButton(
        onPressed: _saving
            ? null
            : () => _setStatus(DssFlagStatus.inProgress),
        style: dssFilledButtonStyle(),
        child: const Text('Start'),
      ),
      DssNextActionKind.resolve => FilledButton(
        onPressed: _saving || !canResolve
            ? null
            : () => _setStatus(DssFlagStatus.resolved),
        style: dssFilledButtonStyle(background: AdminDssTheme.success),
        child: const Text('Resolve finding'),
      ),
      DssNextActionKind.checkOutcome => FilledButton(
        onPressed: _saving || _undecidedIntervention == null
            ? null
            : () => _checkOutcome(_undecidedIntervention!),
        style: dssFilledButtonStyle(),
        child: const Text('Check outcome'),
      ),
      DssNextActionKind.decide => FilledButton(
        onPressed: _saving || _undecidedIntervention == null
            ? null
            : () => _pickDecision(_undecidedIntervention!),
        style: dssFilledButtonStyle(background: AdminDssTheme.success),
        child: const Text('Decide'),
      ),
      DssNextActionKind.reopen || DssNextActionKind.wait => FilledButton(
        onPressed: _saving ? null : _reopen,
        style: dssFilledButtonStyle(),
        child: const Text('Reopen'),
      ),
      DssNextActionKind.dismissOnly || DssNextActionKind.none => null,
    };

    return [
      if (primary != null) ...[
        SizedBox(width: double.infinity, child: primary),
        const SizedBox(height: 8),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (flag.status != DssFlagStatus.dismissed && !closed)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => _setStatus(DssFlagStatus.dismissed),
              child: const Text('Dismiss'),
            ),
          TextButton(
            onPressed: _saving ? null : _addNoteOnly,
            child: const Text('Add note'),
          ),
        ],
      ),
      if (next.kind == DssNextActionKind.resolve && !canResolve) ...[
        const SizedBox(height: 8),
        Text(
          !hasProof
              ? 'Resolve finding unlocks after a reminder draft, a Proof '
                    'entry (or Other + details) and a note.'
              : 'Finish the steps above to unlock Resolve finding.',
          style: const TextStyle(
            fontSize: 11.5,
            color: AdminDssTheme.warning,
          ),
        ),
      ],
    ];
  }

  Future<void> _pickDecision(DssIntervention intervention) async {
    final decision = await showModalBottomSheet<DssOutcomeDecision>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Decide what happens next',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminDssTheme.textPrimary,
                ),
              ),
            ),
            for (final d in DssOutcomeDecision.values)
              ListTile(
                title: Text(d.label),
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
      ),
    );
    if (decision == null || !mounted) return;
    await _decide(intervention, decision);
  }

  Widget _actionSteps({
    required DssFlag flag,
    required bool started,
    required bool assigned,
    required bool intervention,
    required bool proof,
    required bool note,
    required bool resolved,
    required bool outcomeReady,
    required bool hasUndecided,
  }) {
    final showOutcomeSteps =
        flag.status == DssFlagStatus.resolved || hasUndecided;
    final steps = <({
      int n,
      String label,
      bool done,
      bool current,
      VoidCallback? onTap,
    })>[
      (
        n: 1,
        label: 'Start',
        done: started,
        current: flag.status == DssFlagStatus.open,
        onTap: null,
      ),
      (
        n: 2,
        label: 'Owner (admin, office or person)',
        done: assigned,
        current: false, // recommended — not required to Resolve
        onTap: _hasAccountability ? () => _scrollTo(_ownerKey) : null,
      ),
      (
        n: 3,
        label: 'Plan',
        done: intervention,
        current: started && !intervention && !resolved,
        onTap: () => _scrollTo(_planKey),
      ),
      (
        n: 4,
        label: 'Proof',
        done: proof,
        current: started && intervention && !proof && !resolved,
        onTap: () => _scrollTo(
          _hasAccountability ? _proofKey : _actKey,
        ),
      ),
      (
        n: 5,
        label: 'Resolve',
        done: resolved,
        current:
            flag.status == DssFlagStatus.inProgress &&
            intervention &&
            proof &&
            note,
        onTap: null,
      ),
      if (showOutcomeSteps) ...[
        (
          n: 6,
          label: 'Outcome',
          done: outcomeReady,
          current:
              flag.status == DssFlagStatus.resolved &&
              hasUndecided &&
              !outcomeReady,
          onTap: () => _scrollTo(_timelineKey),
        ),
        (
          n: 7,
          label: 'Decide',
          done: false,
          current:
              flag.status == DssFlagStatus.resolved &&
              hasUndecided &&
              outcomeReady,
          onTap: () => _scrollTo(_timelineKey),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in steps)
          InkWell(
            onTap: s.onTap,
            borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.done
                          ? AdminDssTheme.success.withValues(alpha: 0.15)
                          : s.current
                          ? AdminDssTheme.primary.withValues(alpha: 0.12)
                          : AdminDssTheme.surface,
                      border: Border.all(
                        color: s.done
                            ? AdminDssTheme.success
                            : s.current
                            ? AdminDssTheme.primary
                            : AdminDssTheme.border,
                      ),
                    ),
                    child: s.done
                        ? const Icon(
                            Icons.check,
                            size: 13,
                            color: AdminDssTheme.success,
                          )
                        : Text(
                            '${s.n}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: s.current
                                  ? AdminDssTheme.primary
                                  : AdminDssTheme.textMuted,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: s.current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: s.done || s.current
                            ? AdminDssTheme.textPrimary
                            : AdminDssTheme.textMuted,
                      ),
                    ),
                  ),
                  if (s.onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AdminDssTheme.textMuted,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Merged action log + coverage re-check + intervention outcome (Phase 5).
  Widget _whatHappenedCard(DssFlag flag) {
    final df = DateFormat.yMMMd().add_jm();
    final dayDf = DateFormat.yMMMd();
    final verdict = DssImpactVerdictX.fromDb(flag.impactVerdict);
    final baseline = flag.baselineValue ?? flag.metricValue;
    final followup = flag.followupValue;
    final due = flag.verifyDueAt;
    final dueOverdue =
        due != null &&
        due.isBefore(DateTime.now()) &&
        verdict != DssImpactVerdict.improved;
    final showRecheck =
        flag.status == DssFlagStatus.resolved ||
        followup != null ||
        flag.impactVerdict != null ||
        flag.status == DssFlagStatus.inProgress;
    final undecided = _undecidedIntervention;
    final showOutcomeBlock =
        _hasOutcomes &&
        (_interventions.isNotEmpty ||
            flag.status == DssFlagStatus.open ||
            flag.status == DssFlagStatus.inProgress ||
            flag.status == DssFlagStatus.resolved);

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
          const Text(
            'What happened',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AdminDssTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Same-wave coverage re-check is not intervention success. '
            'Next-wave outcome is judged when the following CHED GTS wave closes. '
            'Check outcome and Decide are on the Action panel.',
            style: TextStyle(fontSize: 11.5, color: AdminDssTheme.textMuted),
          ),
          if (showOutcomeBlock) ...[
            const SizedBox(height: 12),
            const Text(
              'Intervention outcome (next wave)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminDssTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            if (undecided != null)
              _timelineOutcomeBlock(undecided)
            else if (_interventions.isNotEmpty)
              _timelineOutcomeBlock(_interventions.first)
            else
              const Text(
                'No intervention recorded yet. Set the Plan above, then '
                'Resolve finding.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AdminDssTheme.textSecondary,
                ),
              ),
            if (_interventions.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                'Earlier interventions: ${_interventions.length - 1}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminDssTheme.textMuted,
                ),
              ),
              for (final i in _interventions.skip(1).take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '· ${i.interventionType} — ${i.outcomeStatus.label}'
                    '${i.decision == null ? '' : ' · ${i.decision!.label}'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminDssTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
          if (showRecheck) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Coverage re-check (same wave)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminDssTheme.textSecondary,
                    ),
                  ),
                ),
                if (verdict != null)
                  DssMetaChip(label: verdict.label, color: verdictColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              followup == null
                  ? 'No re-check yet. Re-check after more alumni answer this wave.'
                  : 'Coverage re-check — ${verdict?.label ?? 'recorded'}'
                        ' · Before ${DssImpact.formatMetric(flag.ruleId, baseline)}'
                        ' → Now ${DssImpact.formatMetric(flag.ruleId, followup)}'
                        '${flag.followupAt == null ? '' : ' · ${dayDf.format(flag.followupAt!.toLocal())}'}',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AdminDssTheme.textSecondary,
              ),
            ),
            if (verdict != null) ...[
              const SizedBox(height: 4),
              Text(
                verdict.hint,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminDssTheme.textMuted,
                ),
              ),
            ],
            if (due != null) ...[
              const SizedBox(height: 4),
              Text(
                dueOverdue
                    ? 'Verify due: ${dayDf.format(due.toLocal())} (overdue)'
                    : 'Next verify by ${dayDf.format(due.toLocal())}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: dueOverdue
                      ? AdminDssTheme.warning
                      : AdminDssTheme.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _rechecking || _saving ? null : _recheckImpact,
              icon: _rechecking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(_rechecking ? 'Checking…' : 'Re-check coverage'),
              style: dssOutlinedButtonStyle(),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Action log',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminDssTheme.textSecondary,
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
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: [for (final n in _notes) _actionLogTile(n, df)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineOutcomeBlock(DssIntervention i) {
    final preview = _outcomeCheck != null &&
            _outcomeCheck!.provisional &&
            !i.isDecided
        ? _outcomeCheck
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminDssTheme.surface,
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
        border: Border.all(color: AdminDssTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  i.interventionType,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AdminDssTheme.textPrimary,
                  ),
                ),
              ),
              DssMetaChip(
                label: i.outcomeStatus.label,
                color: dssOutcomeColor(i.outcomeStatus),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Started ${DateFormat.yMMMd().format(i.startedOn)}'
            '${i.createdByName.isEmpty ? '' : ' · ${i.createdByName}'}',
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminDssTheme.textMuted,
            ),
          ),
          if (i.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              i.description,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AdminDssTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            DssCopy.successTest(i),
            style: const TextStyle(
              fontSize: 12,
              color: AdminDssTheme.textSecondary,
            ),
          ),
          Text(
            DssCopy.outcomeBaseline(i),
            style: const TextStyle(
              fontSize: 12,
              color: AdminDssTheme.textSecondary,
            ),
          ),
          Text(
            DssCopy.outcomeFollowup(i),
            style: const TextStyle(
              fontSize: 12,
              color: AdminDssTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DssCopy.outcomeHint(i.outcomeStatus),
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminDssTheme.textMuted,
            ),
          ),
          if (preview?.previewStatus != null) ...[
            const SizedBox(height: 6),
            Text(
              'Preview, not final: would be "${preview!.previewStatus!.label}".',
              style: const TextStyle(
                fontSize: 12,
                color: AdminDssTheme.info,
              ),
            ),
          ],
          if (i.isDecided) ...[
            const SizedBox(height: 6),
            Text(
              'Decision: ${i.decision!.label}'
              '${i.escalatedTo == null ? '' : ' to ${i.escalatedTo}'}'
              '${(i.decisionNote ?? '').isEmpty ? '' : ' — ${i.decisionNote}'}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AdminDssTheme.textPrimary,
              ),
            ),
          ],
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
      DssNoteEventType.evidence => AdminDssTheme.success,
      DssNoteEventType.outcome => AdminDssTheme.info,
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
              'Coverage re-check: ${DssImpactVerdictX.fromDb(verdict)?.label ?? verdict}',
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

  InputDecoration _fieldDecoration(
    String label, {
    String? helper,
    String? error,
  }) {
    final radius = BorderRadius.circular(AdminDssTheme.radiusSm);
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: AdminDssTheme.textSecondary,
      ),
      helperText: helper,
      helperMaxLines: 3,
      errorText: error,
      filled: true,
      fillColor: Colors.white,
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

  /// Latest nightly server re-check; only for flags still awaiting action.
  String? _recheckNote(DssFlag flag) {
    if (!flag.isActive) return null;
    final at = flag.recheckedAt;
    if (flag.recheckState == null || at == null) return null;
    // Refreshing insights rewrites the flag; an older check is stale.
    if (flag.updatedAt.isAfter(at)) return null;
    final when = DateFormat('MMM d, h:mm a').format(at);
    final value = flag.recheckValue;
    final n = flag.recheckSampleN ?? 0;
    final answers = '$n answer${n == 1 ? '' : 's'}';
    switch (flag.recheckState) {
      case 'recovered':
        final since = flag.recoveredSince;
        final sinceText = since == null || since.isAtSameMomentAs(at)
            ? ''
            : ' since ${DateFormat('MMM d').format(since)}';
        return 'Nightly re-check ($when): now '
            '${value == null ? 'below target' : flag.metricLabelFor(value)} '
            'from $answers, no longer past the threshold$sinceText. '
            'Review and resolve if the improvement holds.';
      case 'still_triggered':
        return 'Nightly re-check ($when): still '
            '${value == null ? 'past the threshold' : flag.metricLabelFor(value)} '
            'from $answers.';
      default:
        return 'Nightly re-check ($when): no answers to measure for this group.';
    }
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
              style: const TextStyle(
                fontSize: 12,
                color: AdminDssTheme.textMuted,
              ),
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

enum _NextBadgeTarget { panel, plan, proof, act, outcome }

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
