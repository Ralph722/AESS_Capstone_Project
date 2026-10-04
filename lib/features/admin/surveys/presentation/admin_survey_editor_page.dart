import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_template_model.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_preview_sheet.dart';
import 'package:alumni_system/features/admin/surveys/widgets/survey_question_editor.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';

/// Embedded survey edit / publish workspace (left edit · right live preview).
class AdminSurveyEditorScreen extends StatefulWidget {
  const AdminSurveyEditorScreen({
    super.key,
    required this.surveyId,
    this.onClose,
    this.backTooltip = 'Back to surveys',
  });

  final String surveyId;

  /// When set, editor is shown inline in the surveys panel (closes via this).
  final VoidCallback? onClose;

  /// Tooltip for the workspace back control.
  final String backTooltip;

  @override
  State<AdminSurveyEditorScreen> createState() =>
      _AdminSurveyEditorScreenState();
}

class _AdminSurveyEditorScreenState extends State<AdminSurveyEditorScreen> {
  final _surveyService = SurveyService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _batchController = TextEditingController();

  Survey? _survey;
  SurveyTemplate? _templateMeta;
  List<SurveyQuestion> _questions = [];
  List<String> _targetPrograms = [];
  List<String> _targetBatches = [];
  String? _batchInputError;
  bool _isLoading = false;
  DateTime? _openAt;
  DateTime? _closeAt;
  bool _autoAssignNewAlumni = true;
  bool _aiHelpEnabled = true;

  String? _expandedQuestionId;
  final Set<String> _savingQuestionIds = {};
  final Map<String, Timer> _saveTimers = {};
  Timer? _visibilitySaveTimer;
  bool _savingVisibility = false;
  bool _previewSyncScheduled = false;

  /// Live preview snapshot (embedded workspace only).
  Survey? _previewSurvey;
  List<SurveyQuestion> _previewQuestions = const [];

  bool get _embedded => widget.onClose != null;

  static const _sideBySideMinWidth = 900.0;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_scheduleLivePreviewUpdate);
    _descController.addListener(_scheduleLivePreviewUpdate);
    _load();
  }

  /// Mirrors every local state change into the side-by-side preview so it
  /// stays live while the admin edits (no need to close/reopen).
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleLivePreviewUpdate();
  }

  void _scheduleLivePreviewUpdate() {
    if (!_embedded) return;
    if (_previewSyncScheduled) return;
    _previewSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewSyncScheduled = false;
      if (!mounted) return;
      final survey = _survey;
      if (survey == null) return;
      final next = survey.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
      );
      final nextQs = List<SurveyQuestion>.from(_questions);
      super.setState(() {
        _previewSurvey = next;
        _previewQuestions = nextQs;
      });
    });
  }

  @override
  void dispose() {
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    _visibilitySaveTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveExpanded = false}) async {
    setState(() => _isLoading = true);
    final survey = await _surveyService.getSurvey(widget.surveyId);
    final questions = await _surveyService.getQuestions(widget.surveyId);
    final templateMeta = survey?.templateId != null
        ? await _surveyService.getSurveyTemplateMeta(widget.surveyId)
        : null;
    if (!mounted) return;
    if (survey != null) {
      _titleController.text = survey.title;
      _descController.text = survey.description;
      _targetPrograms = AudienceTargeting.normalizeCourseTargets(
        survey.targetPrograms,
      );
      _targetBatches = List.from(survey.targetBatchYears);
      _batchController.text = AudienceTargeting.formatBatchYearsForDisplay(
        _targetBatches,
      );
      _openAt = survey.openAt;
      _closeAt = survey.closeAt;
      _autoAssignNewAlumni = survey.autoAssignNewAlumni;
      _aiHelpEnabled = survey.aiHelpEnabled;
    }
    setState(() {
      _survey = survey;
      _templateMeta = templateMeta;
      _questions = questions;
      _isLoading = false;
      if (!preserveExpanded) {
        // keep expanded if still present
        if (_expandedQuestionId != null &&
            !questions.any((q) => q.id == _expandedQuestionId)) {
          _expandedQuestionId = null;
        }
      }
    });
  }

  Future<void> _confirmDeleteQuestion(SurveyQuestion q) async {
    if (q.isStandardItem) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove standard CHED item?'),
          content: const Text(
            'This question is part of the CHED preset pack. You may remove it '
            'for now if your registrar approves a shorter form, but reporting '
            'may no longer match the standard template.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove anyway'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete question?'),
          content: Text(
            q.prompt.trim().isEmpty
                ? 'Remove this untitled question from the survey?'
                : 'Remove “${q.prompt.trim()}” from the survey?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: surveyFilledButtonStyle(
                background: AdminSurveyTheme.danger,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    _saveTimers.remove(q.id)?.cancel();
    await _surveyService.deleteQuestion(widget.surveyId, q.id);
    if (!mounted) return;
    setState(() {
      _questions.removeWhere((item) => item.id == q.id);
      if (_expandedQuestionId == q.id) _expandedQuestionId = null;
    });
    await _persistOrders(_questions);
    await _pruneVisibilityRulesForDeletedQuestion(q.id);
  }

  Future<void> _pruneVisibilityRulesForDeletedQuestion(
    String questionId,
  ) async {
    final survey = _survey;
    if (survey == null || survey.isChedGtsBuiltin) return;
    final rules = Map<String, SurveyVisibilityRule>.from(
      survey.visibilityRules,
    );
    final before = rules.length;
    rules.remove(questionId);
    rules.removeWhere((_, rule) => rule.sourceQuestionId == questionId);
    if (rules.length == before &&
        !survey.visibilityRules.containsKey(questionId)) {
      return;
    }
    final updated = survey.copyWith(visibilityRules: rules);
    setState(() => _survey = updated);
    await _surveyService.updateSurvey(updated);
  }

  void _setVisibilityRule(String questionId, SurveyVisibilityRule? rule) {
    final survey = _survey;
    if (survey == null || survey.isChedGtsBuiltin) return;
    final rules = Map<String, SurveyVisibilityRule>.from(
      survey.visibilityRules,
    );
    if (rule == null) {
      rules.remove(questionId);
    } else {
      rules[questionId] = rule;
    }
    setState(() => _survey = survey.copyWith(visibilityRules: rules));
    _visibilitySaveTimer?.cancel();
    _visibilitySaveTimer = Timer(const Duration(milliseconds: 400), () {
      _persistVisibilityRules();
    });
  }

  Future<void> _persistVisibilityRules() async {
    final survey = _survey;
    if (survey == null) return;
    if (!mounted) return;
    setState(() => _savingVisibility = true);
    try {
      await _surveyService.updateSurvey(survey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingVisibility = false);
    }
  }

  Future<void> _openPreviewOverlay() async {
    if (_survey == null) return;
    for (final entry in _saveTimers.entries.toList()) {
      entry.value.cancel();
      await _persistQuestion(entry.key);
    }
    _saveTimers.clear();
    if (_visibilitySaveTimer?.isActive == true) {
      _visibilitySaveTimer?.cancel();
      await _persistVisibilityRules();
    }
    if (!mounted || _survey == null) return;
    await showAdminSurveyPreview(
      context: context,
      survey: _survey!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
      ),
      questions: List<SurveyQuestion>.from(_questions),
    );
  }

  Widget? _buildLegacyPresetCallout() {
    if (_survey == null || _survey!.isChedGtsBuiltin) return null;
    if (!_survey!.isFromTemplate) return null;
    final meta = _templateMeta;
    return SurveyCallout(
      tone: SurveyCalloutTone.warning,
      icon: Icons.fact_check_outlined,
      title:
          'CHED preset: ${meta?.title ?? _survey!.templateId} '
          '(v${_survey!.templateVersion ?? "?"})',
      body:
          meta?.disclaimer ??
          'Review question wording with your registrar before publishing.',
    );
  }

  Widget _buildBuiltinLockCallout() {
    final version = _survey?.schemaVersion ?? '?';
    return SurveyCallout(
      tone: SurveyCalloutTone.info,
      icon: Icons.lock_outline,
      title: 'Official CHED GTS (built-in v$version)',
      body:
          'Question wording is locked to the official template with skip logic. '
          'Set audience below, then Publish — alumni answer it inline on Tracer. '
          'Official items cannot be edited here.',
    );
  }

  bool _syncBatchFromField() {
    final text = _batchController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _targetBatches = [];
        _batchInputError = null;
      });
      return true;
    }
    final formatError = AudienceTargeting.validateBatchYearInput(text);
    if (formatError != null) {
      setState(() => _batchInputError = formatError);
      return false;
    }
    try {
      final parsed = AudienceTargeting.parseBatchYearInput(text);
      setState(() {
        _targetBatches = parsed;
        _batchInputError = null;
      });
      return true;
    } on FormatException catch (e) {
      setState(() => _batchInputError = e.message);
      return false;
    }
  }

  Future<void> _saveMetadata() async {
    if (_survey == null) return;
    if (!_syncBatchFromField()) return;
    if (_openAt != null && _closeAt != null && !_closeAt!.isAfter(_openAt!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Close date must be after open date'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    await _surveyService.updateSurvey(
      _survey!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        targetPrograms: _targetPrograms,
        targetBatchYears: _targetBatches,
        openAt: _openAt,
        closeAt: _closeAt,
        clearOpenAt: _openAt == null,
        clearCloseAt: _closeAt == null,
        autoAssignNewAlumni: _autoAssignNewAlumni,
        aiHelpEnabled: _aiHelpEnabled,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Survey details saved')));
    }
    await _load(preserveExpanded: true);
  }

  Future<void> _pickOpenAt() async {
    final now = DateTime.now();
    final picked = await DirectoryDateTimePickers.pickDateTime(
      context,
      initial: _openAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() => _openAt = picked);
  }

  Future<void> _pickCloseAt() async {
    final now = DateTime.now();
    final picked = await DirectoryDateTimePickers.pickDateTime(
      context,
      initial: _closeAt ?? _openAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() => _closeAt = picked);
  }

  Future<void> _addQuestionInline() async {
    final q = SurveyQuestion(
      id: LocalId.generate(),
      surveyId: widget.surveyId,
      order: _questions.length,
      type: SurveyQuestionType.text,
      prompt: '',
      required: true,
    );
    setState(() {
      _questions = [..._questions, q];
      _expandedQuestionId = q.id;
    });
    setState(() => _savingQuestionIds.add(q.id));
    try {
      await _surveyService.saveQuestion(q);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingQuestionIds.remove(q.id));
      }
    }
  }

  void _updateQuestionLocal(SurveyQuestion updated) {
    final index = _questions.indexWhere((q) => q.id == updated.id);
    if (index < 0) return;
    setState(() {
      _questions = List<SurveyQuestion>.from(_questions)..[index] = updated;
    });
    _scheduleSave(updated);
  }

  void _scheduleSave(SurveyQuestion question) {
    _saveTimers[question.id]?.cancel();
    _saveTimers[question.id] = Timer(const Duration(milliseconds: 400), () {
      _persistQuestion(question.id);
    });
  }

  Future<void> _persistQuestion(String questionId) async {
    SurveyQuestion? question;
    for (final q in _questions) {
      if (q.id == questionId) {
        question = q;
        break;
      }
    }
    if (question == null) return;
    if (!mounted) return;
    setState(() => _savingQuestionIds.add(questionId));
    try {
      await _surveyService.saveQuestion(question);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingQuestionIds.remove(questionId));
      }
    }
  }

  Future<void> _duplicateQuestion(SurveyQuestion source) async {
    final index = _questions.indexWhere((q) => q.id == source.id);
    if (index < 0) return;
    final dup = SurveyQuestion(
      id: LocalId.generate(),
      surveyId: source.surveyId,
      order: index + 1,
      type: source.type,
      prompt: source.prompt,
      required: source.required,
      options: List<String>.from(source.options),
      scaleMin: source.scaleMin,
      scaleMax: source.scaleMax,
      section: source.section,
      isStandardItem: false,
    );
    final next = List<SurveyQuestion>.from(_questions)..insert(index + 1, dup);
    for (var i = 0; i < next.length; i++) {
      next[i] = next[i].copyWith(order: i);
    }
    setState(() {
      _questions = next;
      _expandedQuestionId = dup.id;
    });
    setState(() => _savingQuestionIds.add(dup.id));
    try {
      await _surveyService.saveQuestions(next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingQuestionIds.remove(dup.id));
      }
    }
  }

  Future<void> _duplicateSection(SurveyQuestion source) async {
    final section = source.section?.trim();
    if (section == null || section.isEmpty) return;
    final inSection = _questions
        .where((q) => (q.section ?? '').trim() == section)
        .toList();
    if (inSection.isEmpty) return;

    final clones = inSection
        .map(
          (q) => SurveyQuestion(
            id: LocalId.generate(),
            surveyId: q.surveyId,
            order: 0,
            type: q.type,
            prompt: q.prompt,
            required: q.required,
            options: List<String>.from(q.options),
            scaleMin: q.scaleMin,
            scaleMax: q.scaleMax,
            section: q.section,
            isStandardItem: false,
          ),
        )
        .toList();

    final next = [..._questions, ...clones];
    for (var i = 0; i < next.length; i++) {
      next[i] = next[i].copyWith(order: i);
    }
    setState(() {
      _questions = next;
      _expandedQuestionId = clones.first.id;
    });
    for (final c in clones) {
      _savingQuestionIds.add(c.id);
    }
    setState(() {});
    try {
      await _surveyService.saveQuestions(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Duplicated section "$section" (${clones.length} questions)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          for (final c in clones) {
            _savingQuestionIds.remove(c.id);
          }
        });
      }
    }
  }

  Future<void> _persistOrders(List<SurveyQuestion> list) async {
    final ordered = <SurveyQuestion>[];
    for (var i = 0; i < list.length; i++) {
      ordered.add(list[i].copyWith(order: i));
    }
    setState(() => _questions = ordered);
    try {
      await _surveyService.saveQuestions(ordered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _moveQuestion(int from, int to) async {
    if (to < 0 || to >= _questions.length) return;
    final next = List<SurveyQuestion>.from(_questions);
    final item = next.removeAt(from);
    next.insert(to, item);
    await _persistOrders(next);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    var to = newIndex;
    if (to > oldIndex) to -= 1;
    if (to == oldIndex) return;
    final next = List<SurveyQuestion>.from(_questions);
    final item = next.removeAt(oldIndex);
    next.insert(to, item);
    await _persistOrders(next);
  }

  Future<void> _publish({bool notify = true}) async {
    try {
      if (!_syncBatchFromField()) return;

      final audienceCount = await _surveyService.countAudience(
        targetPrograms: _targetPrograms,
        targetBatchYears: _targetBatches,
      );
      final hasFilters =
          _targetPrograms.isNotEmpty || _batchController.text.trim().isNotEmpty;
      if (hasFilters && audienceCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No alumni match this program/batch range. '
                'Adjust filters before publishing.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(notify ? 'Publish survey?' : 'Re-assign alumni?'),
          content: Text(
            notify
                ? 'About $audienceCount alumni match the current audience'
                      '${hasFilters ? '' : ' (all alumni)'}. '
                      'They will be assigned${notify ? ' and notified' : ''}.'
                : 'Refresh assignments for about $audienceCount matching alumni. '
                      'Existing submissions are kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: surveyFilledButtonStyle(
                background: notify
                    ? AdminSurveyTheme.success
                    : AdminSurveyTheme.primary,
              ),
              child: Text(notify ? 'Publish' : 'Re-assign'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      // Flush pending question autosaves before publish.
      for (final entry in _saveTimers.entries.toList()) {
        entry.value.cancel();
        await _persistQuestion(entry.key);
      }
      _saveTimers.clear();
      if (_visibilitySaveTimer?.isActive == true) {
        _visibilitySaveTimer?.cancel();
        await _persistVisibilityRules();
      }

      await _saveMetadata();
      final count = await _surveyService.publishSurvey(widget.surveyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notify ? 'Published to $count alumni' : 'Assigned to $count alumni',
          ),
          backgroundColor: Colors.green,
        ),
      );
      if (notify) {
        final close = widget.onClose;
        if (close != null) {
          close();
        } else {
          Navigator.pop(context);
        }
      } else {
        await _load(preserveExpanded: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildActionBar({bool? constrainWidth}) {
    final isDraft = _survey?.status == SurveyStatus.draft;
    final isPublished = _survey?.status == SurveyStatus.published;

    final saveButton = OutlinedButton(
      onPressed: _survey == null ? null : _saveMetadata,
      style: surveyOutlinedButtonStyle(),
      child: const Text('Save details'),
    );

    Widget? primary;
    if (isDraft) {
      primary = FilledButton.icon(
        onPressed: _publish,
        icon: const Icon(Icons.publish_outlined, size: 18),
        label: const Text('Publish'),
        style: surveyFilledButtonStyle(background: AdminSurveyTheme.success),
      );
    } else if (isPublished) {
      primary = FilledButton.icon(
        onPressed: () => _publish(notify: false),
        icon: const Icon(Icons.group_add_outlined, size: 18),
        label: const Text('Re-assign alumni'),
        style: surveyFilledButtonStyle(),
      );
    }

    return SurveyStickyActionBar(
      constrainWidth: constrainWidth ?? !_embedded,
      children: [saveButton, if (primary != null) primary],
    );
  }

  Widget _buildQuestionsBuilder() {
    if (_questions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'No questions yet. Add one to start building this survey.',
            style: TextStyle(color: AdminSurveyTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addQuestionInline,
            icon: const Icon(Icons.add),
            label: const Text('Add question'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminSurveyTheme.primary,
              side: const BorderSide(color: AdminSurveyTheme.border),
              minimumSize: const Size(0, AdminSurveyTheme.buttonHeight),
            ),
          ),
        ],
      );
    }

    // Flat reorderable list; section labels shown above each group start.
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _questions.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final q = _questions[index];
        final showSection =
            q.section != null &&
            q.section!.isNotEmpty &&
            (index == 0 || _questions[index - 1].section != q.section);

        return Column(
          key: ValueKey(q.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showSection)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  q.sectionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminSurveyTheme.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            SurveyQuestionEditorCard(
              question: q,
              index: index,
              expanded: _expandedQuestionId == q.id,
              isSaving:
                  _savingQuestionIds.contains(q.id) ||
                  (_savingVisibility &&
                      _survey?.visibilityRules.containsKey(q.id) == true),
              canMoveUp: index > 0,
              canMoveDown: index < _questions.length - 1,
              onToggleExpand: () {
                setState(() {
                  _expandedQuestionId = _expandedQuestionId == q.id
                      ? null
                      : q.id;
                });
              },
              onChanged: _updateQuestionLocal,
              onDuplicate: () => _duplicateQuestion(q),
              onDuplicateSection:
                  (q.section != null && q.section!.trim().isNotEmpty)
                  ? () => _duplicateSection(q)
                  : null,
              onDelete: () => _confirmDeleteQuestion(q),
              onMoveUp: () => _moveQuestion(index, index - 1),
              onMoveDown: () => _moveQuestion(index, index + 1),
              allQuestions: _questions,
              visibilityRule: _survey?.visibilityRules[q.id],
              onVisibilityRuleChanged: (rule) => _setVisibilityRule(q.id, rule),
              dragHandle: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Tooltip(
                    message: 'Drag to reorder',
                    child: Icon(
                      Icons.drag_indicator,
                      color: AdminSurveyTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titlePreview = _titleController.text.trim().isEmpty
        ? 'Edit survey'
        : _titleController.text.trim();

    if (_isLoading && _survey == null) {
      return SurveyEditorScaffold(
        header: _embedded
            ? SurveyInlinePanelHeader(
                title: titlePreview,
                subtitle: 'Edit / publish',
                backTooltip: widget.backTooltip,
                onClose: widget.onClose!,
              )
            : null,
        appBar: _embedded
            ? null
            : AppBar(
                title: Text(titlePreview),
                backgroundColor: AdminSurveyTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
        body: const AdminFormEditorSkeleton(),
      );
    }

    if (_embedded) {
      return SurveyEditorScaffold(
        header: SurveyInlinePanelHeader(
          title: titlePreview,
          subtitle: 'Edit / publish',
          backTooltip: widget.backTooltip,
          onClose: widget.onClose!,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _sideBySideMinWidth;
            final editPane = _buildEditPane(scrollable: true);
            final preview = _buildPreviewPane();
            if (wide) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: editPane),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: preview),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: editPane),
                  const SizedBox(height: 12),
                  Expanded(flex: 5, child: preview),
                ],
              ),
            );
          },
        ),
      );
    }

    return SurveyEditorScaffold(
      appBar: AppBar(
        title: Text(titlePreview),
        backgroundColor: AdminSurveyTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_survey != null)
            IconButton(
              tooltip: 'Preview',
              onPressed: _openPreviewOverlay,
              icon: const Icon(Icons.visibility_outlined),
            ),
        ],
      ),
      bottomBar: _survey == null ? null : _buildActionBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: SurveyEditorContentWidth(child: _buildEditorForm()),
      ),
    );
  }

  Widget _buildEditPane({required bool scrollable}) {
    final form = _buildEditorForm();
    final bar = _survey == null ? null : _buildActionBar(constrainWidth: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AdminSurveyTheme.card,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusLg),
        border: Border.all(color: AdminSurveyTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    child: form,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    child: form,
                  ),
          ),
          if (bar != null) bar,
        ],
      ),
    );
  }

  Widget _buildPreviewPane() {
    final survey =
        _previewSurvey ??
        _survey?.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
        );
    if (survey == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AdminSurveyTheme.card,
          borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusLg),
          border: Border.all(color: AdminSurveyTheme.border),
        ),
        child: const Center(
          child: Text(
            'Preview will appear here.',
            style: TextStyle(color: AdminSurveyTheme.textMuted),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AdminSurveyTheme.card,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusLg),
        border: Border.all(color: AdminSurveyTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusLg),
        child: AdminSurveyPreviewPanel(
          survey: survey,
          questions: _previewQuestions.isEmpty ? _questions : _previewQuestions,
          showCloseControls: false,
        ),
      ),
    );
  }

  Widget _buildEditorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_survey != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SurveyStatusChip(
                status: _survey!.status,
                archived: _survey!.archived,
                scheduled: _survey!.isScheduledWindow,
              ),
              SurveyKindChip.fromSurvey(_survey!),
            ],
          ),
          const SizedBox(height: AdminSurveyTheme.space2),
        ],
        SurveySectionCard(
          title: 'Details',
          subtitle: 'Title and description shown to alumni.',
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                onChanged: (_) => setState(() {}),
                decoration: AdminSurveyTheme.fieldDecoration(label: 'Title'),
              ),
              const SizedBox(height: AdminSurveyTheme.space2),
              TextField(
                controller: _descController,
                decoration: AdminSurveyTheme.fieldDecoration(
                  label: 'Description',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: AdminSurveyTheme.space2),
        SurveySectionCard(
          title: 'Schedule',
          subtitle:
              'Optional window. Leave empty for always open while published. '
              'Alumni cannot submit outside this window.',
          child: Column(
            children: [
              DirectoryDateFilterChip(
                label: 'Opens at',
                expand: true,
                width: null,
                displayText: _openAt == null
                    ? 'Immediately when published'
                    : DateFormat.yMMMd().add_jm().format(_openAt!),
                active: _openAt != null,
                onTap: _pickOpenAt,
              ),
              if (_openAt != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _openAt = null),
                    child: const Text('Clear open time'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              DirectoryDateFilterChip(
                label: 'Closes at',
                expand: true,
                width: null,
                displayText: _closeAt == null
                    ? 'No automatic close'
                    : DateFormat.yMMMd().add_jm().format(_closeAt!),
                active: _closeAt != null,
                onTap: _pickCloseAt,
              ),
              if (_closeAt != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _closeAt = null),
                    child: const Text('Clear close time'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AdminSurveyTheme.space2),
        SurveySectionCard(
          title: 'Audience',
          subtitle: 'Leave courses and batches empty to include all alumni.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Courses',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AdminSurveyTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CourseConstants.courses.map((p) {
                  final selected = _targetPrograms.contains(p);
                  return FilterChip(
                    label: Text(p),
                    selected: selected,
                    selectedColor: AdminSurveyTheme.infoBg,
                    checkmarkColor: AdminSurveyTheme.primary,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _targetPrograms.add(p);
                        } else {
                          _targetPrograms.remove(p);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AdminSurveyTheme.space2),
              TextField(
                controller: _batchController,
                decoration: AdminSurveyTheme.fieldDecoration(
                  label: 'Target batch years',
                  hint: 'e.g. 2020-2027 or 2024, 2025',
                  helper:
                      'Use a year range (2020-2027) or comma-separated years',
                  error: _batchInputError,
                ),
                onChanged: (_) {
                  setState(_syncBatchFromField);
                },
              ),
              const SizedBox(height: AdminSurveyTheme.space2),
              SwitchListTile.adaptive(
                value: _autoAssignNewAlumni,
                onChanged: (v) => setState(() => _autoAssignNewAlumni = v),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AdminSurveyTheme.primary,
                title: const Text(
                  'Auto-assign new alumni',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Alumni who register or update their program/batch later '
                  'are assigned automatically while this survey is open.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminSurveyTheme.textSecondary,
                  ),
                ),
              ),
              if (_survey?.isChedGtsBuiltin == true)
                SwitchListTile.adaptive(
                  value: _aiHelpEnabled,
                  onChanged: (v) => setState(() => _aiHelpEnabled = v),
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AdminSurveyTheme.primary,
                  title: const Text(
                    'AI answer helper',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Shows "Help me answer" on question 19. Alumni describe '
                    'their job and get a suggested occupation and line of '
                    'business; question 20 then shows the line of business '
                    'as a recommendation (20 requests per alumnus per day).',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminSurveyTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AdminSurveyTheme.space2),
        if (_survey?.isChedGtsBuiltin == true)
          SurveySectionCard(
            title: 'Questions',
            subtitle: 'Official CHED form — locked.',
            child: _buildBuiltinLockCallout(),
          )
        else ...[
          if (_buildLegacyPresetCallout() != null) ...[
            _buildLegacyPresetCallout()!,
            const SizedBox(height: AdminSurveyTheme.space2),
          ],
          SurveySectionCard(
            title: 'Questions',
            subtitle:
                'Edit inline, drag to reorder, duplicate, or delete. '
                'Use Preview to test visibility rules.',
            trailing: TextButton.icon(
              onPressed: _addQuestionInline,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AdminSurveyTheme.primary,
              ),
            ),
            child: _buildQuestionsBuilder(),
          ),
        ],
      ],
    );
  }
}
