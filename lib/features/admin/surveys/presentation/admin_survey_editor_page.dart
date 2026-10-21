import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_template_model.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/share/share_link_sheet.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_preview_sheet.dart';
import 'package:alumni_system/features/admin/surveys/widgets/survey_question_editor.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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

/// Whether the batch-year field [text] targets different years than [saved]
/// (stored years may be single years or `2020-2027` range tokens).
@visibleForTesting
bool surveyBatchInputChanged(String text, List<String> saved) {
  final trimmed = text.trim();
  if (trimmed == AudienceTargeting.formatBatchYearsForDisplay(saved).trim()) {
    return false;
  }
  try {
    final current = trimmed.isEmpty
        ? const <String>[]
        : AudienceTargeting.parseBatchYearInput(trimmed);
    final savedYears = AudienceTargeting.expandBatchYearTargets(saved);
    return !setEquals(current.toSet(), savedYears.toSet());
  } on FormatException {
    return true;
  }
}

enum _SnackTone { neutral, success, danger }

enum _UnsavedChoice { keepEditing, discard, saveAndClose }

class _AdminSurveyEditorScreenState extends State<AdminSurveyEditorScreen> {
  final _surveyService = SurveyService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _batchController = TextEditingController();
  final _batchFocus = FocusNode();

  Survey? _survey;
  SurveyTemplate? _templateMeta;
  List<SurveyQuestion> _questions = [];
  List<String> _targetPrograms = [];
  List<String> _targetBatches = [];
  String? _batchInputError;
  bool _isLoading = false;
  String? _loadError;
  DateTime? _openAt;
  DateTime? _closeAt;
  bool _autoAssignNewAlumni = true;
  bool _aiHelpEnabled = true;

  /// Inline field errors appear only after the admin touched the field (or
  /// tried to save).
  bool _titleTouched = false;
  bool _batchTouched = false;

  bool _savingDetails = false;
  bool _publishing = false;
  bool _closing = false;

  bool _showPreview = true;
  bool _narrowShowsPreview = false;

  int? _audienceCount;
  bool _audienceCountFailed = false;
  bool _audienceCounting = false;
  bool _audienceRecountPending = false;
  Timer? _audienceTimer;

  String? _expandedQuestionId;
  String? _scrollToQuestionId;
  final _scrollTargetKey = GlobalKey();

  /// Keeps the edit pane's scroll position and focus when the layout switches
  /// (preview hidden/shown, crossing the side-by-side width).
  final _editPaneKey = GlobalKey();
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
  static const _formMaxWidth = 880.0;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_scheduleLivePreviewUpdate);
    _descController.addListener(_scheduleLivePreviewUpdate);
    _batchFocus.addListener(_onBatchFocusChange);
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
    _audienceTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _batchController.dispose();
    _batchFocus.dispose();
    super.dispose();
  }

  void _showSnack(String message, {_SnackTone tone = _SnackTone.neutral}) {
    if (!mounted) return;
    final background = switch (tone) {
      _SnackTone.neutral => null,
      _SnackTone.success => AdminColors.success,
      _SnackTone.danger => AdminColors.danger,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  Future<void> _load({bool preserveExpanded = false}) async {
    final firstLoad = _survey == null;
    setState(() {
      _isLoading = true;
      if (firstLoad) _loadError = null;
    });
    try {
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
        _batchInputError = null;
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
      if (firstLoad && survey != null) _refreshAudienceCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (firstLoad) {
          _loadError = surveyFriendlyError(
            e,
            "Check your connection and try again.",
          );
        }
      });
      if (!firstLoad) {
        _showSnack(
          "Couldn't refresh the survey. Showing the last loaded version.",
          tone: _SnackTone.danger,
        );
      }
    }
  }

  // ── Unsaved details ────────────────────────────────────────────────────

  static bool _sameMoment(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.isAtSameMomentAs(b);
  }

  /// Title, description, schedule or audience differ from the saved survey.
  bool get _isDirty {
    final s = _survey;
    if (s == null) return false;
    if (_titleController.text.trim() != s.title.trim()) return true;
    if (_descController.text.trim() != s.description.trim()) return true;
    if (!_sameMoment(_openAt, s.openAt) || !_sameMoment(_closeAt, s.closeAt)) {
      return true;
    }
    if (_autoAssignNewAlumni != s.autoAssignNewAlumni) return true;
    if (_aiHelpEnabled != s.aiHelpEnabled) return true;
    final savedPrograms = AudienceTargeting.normalizeCourseTargets(
      s.targetPrograms,
    ).toSet();
    if (!setEquals(savedPrograms, _targetPrograms.toSet())) return true;
    return surveyBatchInputChanged(_batchController.text, s.targetBatchYears);
  }

  bool get _questionSavesPending =>
      _savingQuestionIds.isNotEmpty ||
      _savingVisibility ||
      _saveTimers.values.any((t) => t.isActive) ||
      (_visibilitySaveTimer?.isActive ?? false);

  /// Saves question/rule edits still waiting on their autosave timer.
  /// Returns false when any of them failed (the error is already shown).
  Future<bool> _flushPendingSaves() async {
    var ok = true;
    for (final entry in _saveTimers.entries.toList()) {
      if (!entry.value.isActive) continue;
      entry.value.cancel();
      ok = await _persistQuestion(entry.key) && ok;
    }
    _saveTimers.clear();
    if (_visibilitySaveTimer?.isActive == true) {
      _visibilitySaveTimer?.cancel();
      ok = await _persistVisibilityRules() && ok;
    }
    return ok;
  }

  void _closeEditor() {
    final close = widget.onClose;
    if (close != null) {
      close();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleBack() async {
    if (_closing || _publishing || _savingDetails) return;
    if (_isDirty) {
      final choice = await showAdminDialogSurface<_UnsavedChoice>(
        context: context,
        maxWidth: 460,
        child: const _UnsavedChangesDialog(),
      );
      if (!mounted) return;
      if (choice == null || choice == _UnsavedChoice.keepEditing) return;
      if (choice == _UnsavedChoice.saveAndClose) {
        final saved = await _saveMetadata(reload: false);
        if (!saved || !mounted) return;
      }
    }
    setState(() => _closing = true);
    final flushed = await _flushPendingSaves();
    if (!mounted) return;
    setState(() => _closing = false);
    if (!flushed) return;
    _closeEditor();
  }

  // ── Validation ─────────────────────────────────────────────────────────

  String? get _titleError =>
      _titleController.text.trim().isEmpty ? 'Title is required' : null;

  String? get _scheduleError =>
      _openAt != null && _closeAt != null && !_closeAt!.isAfter(_openAt!)
      ? 'Close time must be after open time'
      : null;

  void _onBatchFocusChange() {
    if (_batchFocus.hasFocus || _batchTouched) return;
    setState(() => _batchTouched = true);
  }

  /// Title, batch years and schedule. Shows the inline errors and a SnackBar
  /// naming [action] when something is wrong.
  bool _validateDetails(String action) {
    final batchOk = _syncBatchFromField();
    setState(() {
      _titleTouched = true;
      _batchTouched = true;
    });
    final ok = batchOk && _titleError == null && _scheduleError == null;
    if (!ok) {
      _showSnack(
        'Fix the highlighted fields before $action.',
        tone: _SnackTone.danger,
      );
    }
    return ok;
  }

  // ── Live audience count ────────────────────────────────────────────────

  bool get _hasAudienceFilters =>
      _targetPrograms.isNotEmpty || _targetBatches.isNotEmpty;

  void _scheduleAudienceCount() {
    _audienceTimer?.cancel();
    _audienceTimer = Timer(
      const Duration(milliseconds: 600),
      _refreshAudienceCount,
    );
  }

  Future<void> _refreshAudienceCount() async {
    if (!mounted) return;
    if (_audienceCounting) {
      _audienceRecountPending = true;
      return;
    }
    setState(() => _audienceCounting = true);
    try {
      final count = await _surveyService.countAudience(
        targetPrograms: List<String>.from(_targetPrograms),
        targetBatchYears: List<String>.from(_targetBatches),
      );
      if (!mounted) return;
      setState(() {
        _audienceCount = count;
        _audienceCountFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _audienceCountFailed = true);
    } finally {
      if (mounted) {
        setState(() => _audienceCounting = false);
        if (_audienceRecountPending) {
          _audienceRecountPending = false;
          _refreshAudienceCount();
        }
      }
    }
  }

  // ── Questions ──────────────────────────────────────────────────────────

  int _questionNumber(String questionId) =>
      _questions.indexWhere((q) => q.id == questionId) + 1;

  Future<void> _confirmDeleteQuestion(SurveyQuestion q) async {
    final bool ok;
    if (q.isStandardItem) {
      ok = await showAdminConfirmDialog(
        context,
        title: 'Remove standard CHED item?',
        message:
            'This question is part of the CHED preset pack. You may remove it '
            'for now if your registrar approves a shorter form, but reporting '
            'may no longer match the standard template.',
        confirmLabel: 'Remove anyway',
        cancelLabel: 'Keep',
        destructive: true,
        icon: Icons.delete_outline,
      );
    } else {
      ok = await showAdminConfirmDialog(
        context,
        title: 'Delete question?',
        message: q.prompt.trim().isEmpty
            ? 'Remove this untitled question from the survey?'
            : 'Remove “${q.prompt.trim()}” from the survey?',
        confirmLabel: 'Delete',
        destructive: true,
        icon: Icons.delete_outline,
      );
    }
    if (!ok || !mounted) return;

    final pending = _saveTimers.remove(q.id);
    final hadPendingSave = pending?.isActive ?? false;
    pending?.cancel();
    try {
      await _surveyService.deleteQuestion(widget.surveyId, q.id);
    } catch (e) {
      if (hadPendingSave) {
        final current = _questions.where((item) => item.id == q.id);
        if (current.isNotEmpty) _scheduleSave(current.first);
      }
      _showSnack(
        surveyFriendlyError(
          e,
          "Couldn't delete question ${_questionNumber(q.id)}. "
          'Please try again.',
        ),
        tone: _SnackTone.danger,
      );
      return;
    }
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
    try {
      await _surveyService.updateSurvey(updated);
    } catch (e) {
      _showSnack(
        surveyFriendlyError(
          e,
          "Couldn't update the visibility rules. Please try again.",
        ),
        tone: _SnackTone.danger,
      );
    }
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

  Future<bool> _persistVisibilityRules() async {
    final survey = _survey;
    if (survey == null) return true;
    if (!mounted) return true;
    setState(() => _savingVisibility = true);
    try {
      await _surveyService.updateSurvey(survey);
      return true;
    } catch (e) {
      _showSnack(
        surveyFriendlyError(
          e,
          "Couldn't save the visibility rules. Please try again.",
        ),
        tone: _SnackTone.danger,
      );
      return false;
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

  /// Saves title, description, schedule and audience. Returns false when
  /// validation or the save failed (the reason is already shown).
  Future<bool> _saveMetadata({
    bool reload = true,
    bool announce = true,
    String action = 'saving',
  }) async {
    if (_survey == null || _savingDetails) return false;
    if (!_validateDetails(action)) return false;
    final updated = _survey!.copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      targetPrograms: List<String>.from(_targetPrograms),
      targetBatchYears: List<String>.from(_targetBatches),
      openAt: _openAt,
      closeAt: _closeAt,
      clearOpenAt: _openAt == null,
      clearCloseAt: _closeAt == null,
      autoAssignNewAlumni: _autoAssignNewAlumni,
      aiHelpEnabled: _aiHelpEnabled,
    );
    setState(() => _savingDetails = true);
    try {
      await _surveyService.updateSurvey(updated);
      if (!mounted) return true;
      setState(() => _survey = updated);
      if (announce) {
        _showSnack('Survey details saved', tone: _SnackTone.success);
      }
      if (reload) await _load(preserveExpanded: true);
      return true;
    } catch (e) {
      _showSnack(
        surveyFriendlyError(
          e,
          "Couldn't save the survey details. Please try again.",
        ),
        tone: _SnackTone.danger,
      );
      return false;
    } finally {
      if (mounted) setState(() => _savingDetails = false);
    }
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
      _showSnack(
        surveyFriendlyError(e, "Couldn't add the question. Please try again."),
        tone: _SnackTone.danger,
      );
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

  Future<bool> _persistQuestion(String questionId) async {
    SurveyQuestion? question;
    for (final q in _questions) {
      if (q.id == questionId) {
        question = q;
        break;
      }
    }
    if (question == null) return true;
    if (!mounted) return true;
    setState(() => _savingQuestionIds.add(questionId));
    try {
      await _surveyService.saveQuestion(question);
      return true;
    } catch (e) {
      _showSnack(
        surveyFriendlyError(
          e,
          "Couldn't save question ${_questionNumber(questionId)}. "
          'Please try again.',
        ),
        tone: _SnackTone.danger,
      );
      return false;
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
      _showSnack(
        surveyFriendlyError(
          e,
          "Couldn't duplicate question ${index + 1}. Please try again.",
        ),
        tone: _SnackTone.danger,
      );
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
      _showSnack('Duplicated section "$section" (${clones.length} questions)');
    } catch (e) {
      _showSnack(
        surveyFriendlyError(
          e,
          "Couldn't duplicate section \"$section\". Please try again.",
        ),
        tone: _SnackTone.danger,
      );
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
      _showSnack(
        surveyFriendlyError(
          e,
          "Couldn't save the question order. Please try again.",
        ),
        tone: _SnackTone.danger,
      );
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

  void _goToQuestion(int index) {
    if (index < 0 || index >= _questions.length) return;
    final id = _questions[index].id;
    setState(() {
      _expandedQuestionId = id;
      _scrollToQuestionId = id;
      _narrowShowsPreview = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _scrollTargetKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: 0.1,
        );
      }
      if (mounted) setState(() => _scrollToQuestionId = null);
    });
  }

  // ── Publish / re-assign ────────────────────────────────────────────────

  Future<void> _publish({bool notify = true}) async {
    if (_publishing || _savingDetails || _closing) return;
    final action = notify ? 'publishing' : 're-assigning';
    if (!_validateDetails(action)) return;
    if (notify && _survey?.isChedGtsBuiltin != true) {
      final problems = surveyPublishProblems(_questions);
      if (problems.isNotEmpty) {
        final goTo = await showAdminDialogSurface<int>(
          context: context,
          maxWidth: 480,
          child: _PublishProblemsDialog(problems: problems),
        );
        if (goTo != null && mounted) _goToQuestion(goTo);
        return;
      }
    }

    setState(() => _publishing = true);
    try {
      final audienceCount = await _surveyService.countAudience(
        targetPrograms: _targetPrograms,
        targetBatchYears: _targetBatches,
      );
      final hasFilters =
          _targetPrograms.isNotEmpty || _batchController.text.trim().isNotEmpty;
      if (hasFilters && audienceCount == 0) {
        _showSnack(
          'No alumni match this program/batch range. '
          'Adjust filters before publishing.',
          tone: _SnackTone.danger,
        );
        return;
      }

      if (!mounted) return;
      setState(() => _publishing = false);
      final confirmed = await showAdminConfirmDialog(
        context,
        title: notify ? 'Publish survey?' : 'Re-assign alumni?',
        message: notify
            ? 'About $audienceCount alumni match the current audience'
                  '${hasFilters ? '' : ' (all alumni)'}. '
                  'They will be assigned and notified.'
            : 'Refresh assignments for about $audienceCount matching alumni. '
                  'Existing submissions are kept.',
        confirmLabel: notify ? 'Publish' : 'Re-assign',
        icon: notify ? Icons.publish_outlined : Icons.group_add_outlined,
      );
      if (!confirmed || !mounted) return;
      setState(() => _publishing = true);

      // Flush pending question autosaves before publish.
      final flushed = await _flushPendingSaves();
      if (!flushed) return;

      final saved = await _saveMetadata(
        reload: false,
        announce: false,
        action: action,
      );
      if (!saved) return;
      final count = await _surveyService.publishSurvey(widget.surveyId);
      if (!mounted) return;
      _showSnack(
        notify ? 'Published to $count alumni' : 'Assigned to $count alumni',
        tone: _SnackTone.success,
      );
      if (notify) {
        _closeEditor();
      } else {
        await _load(preserveExpanded: true);
      }
    } catch (e) {
      _showSnack(
        surveyFriendlyError(
          e,
          notify
              ? "Couldn't publish the survey. Please try again."
              : "Couldn't re-assign alumni. Please try again.",
        ),
        tone: _SnackTone.danger,
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  // ── Layout ─────────────────────────────────────────────────────────────

  static Widget _buttonSpinner(Color color) => SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );

  Widget _buildSaveState() {
    final Widget indicator;
    final String text;
    String? shortText;
    if (_questionSavesPending || _savingDetails) {
      indicator = _buttonSpinner(AdminColors.primary);
      text = 'Saving…';
    } else if (_isDirty) {
      indicator = Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AdminColors.warning,
          shape: BoxShape.circle,
        ),
      );
      text = 'Unsaved changes';
    } else {
      indicator = const Icon(
        Icons.check_circle_outline,
        size: 16,
        color: AdminColors.success,
      );
      if (_survey?.isChedGtsBuiltin == true) {
        text = 'All changes saved';
      } else {
        text = 'All changes saved · questions save automatically';
        shortText = 'All changes saved';
      }
    }
    final style = AdminText.caption.copyWith(
      fontWeight: _isDirty ? FontWeight.w600 : FontWeight.w400,
      color: _isDirty && !_questionSavesPending
          ? AdminColors.warning
          : AdminColors.textSecondary,
    );
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            var fullFits = true;
            if (shortText != null) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout();
              fullFits = painter.width <= constraints.maxWidth - 22;
              painter.dispose();
            }
            final label = Text(
              fullFits ? text : shortText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            );
            return Row(
              children: [
                SizedBox(width: 16, child: Center(child: indicator)),
                const SizedBox(width: 6),
                Flexible(
                  child: fullFits
                      ? label
                      : Tooltip(message: text, child: label),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionBar({bool? constrainWidth}) {
    final isDraft = _survey?.status == SurveyStatus.draft;
    final isPublished = _survey?.status == SurveyStatus.published;
    final busy = _publishing || _savingDetails || _closing;

    final saveButton = OutlinedButton(
      onPressed: _survey == null || busy ? null : () => _saveMetadata(),
      style: AdminButtonStyles.outlined(),
      child: _savingDetails
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buttonSpinner(AdminColors.primary),
                const SizedBox(width: 8),
                const Text('Saving…'),
              ],
            )
          : const Text('Save details'),
    );

    Widget? primary;
    if (isDraft || isPublished) {
      final label = isDraft
          ? (_publishing ? 'Publishing…' : 'Publish')
          : (_publishing ? 'Re-assigning…' : 'Re-assign alumni');
      primary = FilledButton.icon(
        onPressed: busy ? null : () => _publish(notify: isDraft),
        icon: _publishing
            ? _buttonSpinner(Colors.white)
            : Icon(
                isDraft ? Icons.publish_outlined : Icons.group_add_outlined,
                size: 18,
              ),
        label: Text(label),
        style: AdminButtonStyles.filled(),
      );
    }

    final shareable =
        _survey != null &&
        _survey!.status == SurveyStatus.published &&
        !_survey!.archived;
    return SurveyStickyActionBar(
      constrainWidth: constrainWidth ?? !_embedded,
      leading: _buildSaveState(),
      children: [
        saveButton,
        if (shareable) ...[
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => showShareLinkSheet(
                    context,
                    ShareableContent.fromSurvey(_survey!),
                  ),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share link'),
            style: AdminButtonStyles.outlined(),
          ),
        ],
        if (primary != null) primary,
      ],
    );
  }

  Widget _buildQuestionsBuilder() {
    if (_questions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No questions yet. Add one to start building this survey.',
            style: AdminText.caption,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addQuestionInline,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add question'),
            style: AdminButtonStyles.outlined(),
          ),
        ],
      );
    }

    // Flat reorderable list; section labels shown above each group start.
    final list = ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _questions.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final q = _questions[index];
        final showSection =
            q.section != null &&
            q.section!.isNotEmpty &&
            (index == 0 || _questions[index - 1].section != q.section);
        var sectionCount = 0;
        if (showSection) {
          for (var i = index; i < _questions.length; i++) {
            if (_questions[i].section != q.section) break;
            sectionCount++;
          }
        }

        Widget card = SurveyQuestionEditorCard(
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
              _expandedQuestionId = _expandedQuestionId == q.id ? null : q.id;
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
              padding: EdgeInsets.only(top: 3),
              child: Tooltip(
                message: 'Drag to reorder',
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: AdminColors.textMuted,
                ),
              ),
            ),
          ),
        );
        if (_scrollToQuestionId == q.id) {
          card = KeyedSubtree(key: _scrollTargetKey, child: card);
        }

        return Column(
          key: ValueKey(q.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showSection)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  '${q.sectionLabel.toUpperCase()} · $sectionCount '
                  '${sectionCount == 1 ? 'question' : 'questions'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AdminColors.primary,
                  ),
                ),
              ),
            card,
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        list,
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addQuestionInline,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add question'),
            style: AdminButtonStyles.outlined(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_embedded) return _buildStandalone();

    final survey = _survey;
    final titlePreview = _titleController.text.trim().isEmpty
        ? 'Edit survey'
        : _titleController.text.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _sideBySideMinWidth;

        final List<Widget> headerActions;
        if (survey == null) {
          headerActions = const [];
        } else if (wide) {
          headerActions = [
            TextButton.icon(
              onPressed: () => setState(() => _showPreview = !_showPreview),
              icon: Icon(
                _showPreview
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              label: Text(_showPreview ? 'Hide preview' : 'Show preview'),
              style: TextButton.styleFrom(
                foregroundColor: AdminColors.textSecondary,
              ),
            ),
          ];
        } else {
          headerActions = [
            _PaneSwitch(
              showPreview: _narrowShowsPreview,
              onChanged: (v) => setState(() => _narrowShowsPreview = v),
            ),
          ];
        }

        final header = SurveyInlinePanelHeader(
          title: titlePreview,
          subtitle: survey == null
              ? ''
              : (surveyWindowText(survey) ?? 'No window set'),
          chips: survey == null
              ? const []
              : [
                  SurveyStatusChip.fromSurvey(survey),
                  SurveyKindChip.fromSurvey(survey),
                ],
          backTooltip: widget.backTooltip,
          onClose: _handleBack,
          backBusy: _closing,
          actions: headerActions,
        );

        final Widget body;
        if (survey == null && _isLoading) {
          body = const SurveyEditorSkeleton(
            sideBySideMinWidth: _sideBySideMinWidth,
          );
        } else if (survey == null && _loadError != null) {
          body = AdminStateView.error(
            title: "Couldn't load this survey",
            message: _loadError,
            onRetry: _load,
          );
        } else if (survey == null) {
          body = AdminStateView.empty(
            icon: Icons.search_off_outlined,
            title: 'Survey not found',
            message: 'It may have been deleted.',
            primaryAction: AdminStateAction(
              label: widget.backTooltip,
              icon: Icons.arrow_back,
              onPressed: _closeEditor,
            ),
          );
        } else if (wide) {
          final editPane = _buildEditPane();
          body = Padding(
            padding: const EdgeInsets.all(12),
            child: _showPreview
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 11, child: editPane),
                      const SizedBox(width: 14),
                      Expanded(flex: 9, child: _buildPreviewPane()),
                    ],
                  )
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _formMaxWidth,
                      ),
                      child: editPane,
                    ),
                  ),
          );
        } else {
          body = Padding(
            padding: const EdgeInsets.all(12),
            child: _narrowShowsPreview ? _buildPreviewPane() : _buildEditPane(),
          );
        }

        return SurveyEditorScaffold(header: header, body: body);
      },
    );
  }

  /// Route-based layout (no caller uses it today).
  Widget _buildStandalone() {
    final titlePreview = _titleController.text.trim().isEmpty
        ? 'Edit survey'
        : _titleController.text.trim();

    if (_isLoading && _survey == null) {
      return SurveyEditorScaffold(
        appBar: AppBar(
          title: Text(titlePreview),
          backgroundColor: AdminSurveyTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const AdminFormEditorSkeleton(),
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

  Widget _buildEditPane() {
    final bar = _survey == null ? null : _buildActionBar(constrainWidth: false);
    return DecoratedBox(
      key: _editPaneKey,
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildEditorForm(),
              ),
            ),
            if (bar != null) bar,
          ],
        ),
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
    final decoration = BoxDecoration(
      color: AdminColors.card,
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
      border: Border.all(color: AdminColors.border),
    );
    if (survey == null) {
      return DecoratedBox(
        decoration: decoration,
        child: const Center(
          child: Text('Preview will appear here.', style: AdminText.caption),
        ),
      );
    }
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        child: AdminSurveyPreviewPanel(
          survey: survey,
          questions: _previewQuestions.isEmpty ? _questions : _previewQuestions,
          showCloseControls: false,
        ),
      ),
    );
  }

  Widget? _buildAudienceCountLabel() {
    if (_survey == null) return null;
    final Color color;
    final String text;
    final count = _audienceCount;
    if (_audienceCountFailed && !_audienceCounting) {
      color = AdminColors.textSecondary;
      text = 'Count unavailable';
    } else if (count == null) {
      color = AdminColors.textSecondary;
      text = 'Counting…';
    } else {
      final formatted = NumberFormat.decimalPattern().format(count);
      if (_hasAudienceFilters && count == 0) {
        color = AdminColors.warning;
        text = 'No alumni match';
      } else {
        color = AdminColors.textSecondary;
        text = _hasAudienceFilters
            ? '≈ $formatted alumni'
            : 'All alumni · ≈ $formatted';
      }
    }
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (_audienceCounting && count != null) ...[
            const SizedBox(width: 6),
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _fieldLabelStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 12.5,
    color: AdminColors.textSecondary,
  );

  static const _switchTitleStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
    color: AdminColors.textPrimary,
  );

  Widget _scheduleRow({
    required String label,
    required String emptyText,
    required DateTime? value,
    required VoidCallback onPick,
    required String clearTooltip,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: DirectoryDateFilterChip(
            label: label,
            expand: true,
            width: null,
            displayText: value == null
                ? emptyText
                : DateFormat.yMMMd().add_jm().format(value),
            active: value != null,
            onTap: onPick,
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: clearTooltip,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: AdminColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditorForm() {
    final scheduleError = _scheduleError;
    final isBuiltin = _survey?.isChedGtsBuiltin == true;
    final presetCallout = _buildLegacyPresetCallout();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_embedded && _survey != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SurveyStatusChip.fromSurvey(_survey!),
              SurveyKindChip.fromSurvey(_survey!),
            ],
          ),
          const SizedBox(height: AdminSurveyTheme.space2),
        ],
        SurveyEditorSection(
          first: true,
          title: 'Details',
          subtitle: 'Title shown to alumni.',
          child: TextField(
            controller: _titleController,
            onChanged: (_) => setState(() => _titleTouched = true),
            decoration: AdminSurveyTheme.fieldDecoration(
              label: 'Title *',
              error: _titleTouched ? _titleError : null,
            ),
          ),
        ),
        SurveyEditorSection(
          title: 'Schedule',
          subtitle:
              'Optional window. Leave empty for always open while published. '
              'Alumni cannot submit outside this window.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _scheduleRow(
                label: 'Opens at',
                emptyText: 'Immediately when published',
                value: _openAt,
                onPick: _pickOpenAt,
                clearTooltip: 'Clear open time',
                onClear: () => setState(() => _openAt = null),
              ),
              const SizedBox(height: 10),
              _scheduleRow(
                label: 'Closes at',
                emptyText: 'No automatic close',
                value: _closeAt,
                onPick: _pickCloseAt,
                clearTooltip: 'Clear close time',
                onClear: () => setState(() => _closeAt = null),
              ),
              if (scheduleError != null) ...[
                const SizedBox(height: 6),
                Text(
                  scheduleError,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
        SurveyEditorSection(
          title: 'Audience',
          subtitle: 'Leave courses and batches empty to include all alumni.',
          trailing: _buildAudienceCountLabel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Courses', style: _fieldLabelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CourseConstants.courses.map((p) {
                  final selected = _targetPrograms.contains(p);
                  return FilterChip(
                    label: Text(p),
                    selected: selected,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AdminColors.card,
                    selectedColor: AdminColors.infoBg,
                    checkmarkColor: AdminColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AdminColors.primary
                          : AdminColors.textPrimary,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AdminColors.primary.withValues(alpha: 0.35)
                          : AdminColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AdminSurfaces.radiusSm,
                      ),
                    ),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _targetPrograms.add(p);
                        } else {
                          _targetPrograms.remove(p);
                        }
                      });
                      _scheduleAudienceCount();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AdminSurveyTheme.space2),
              TextField(
                controller: _batchController,
                focusNode: _batchFocus,
                decoration: AdminSurveyTheme.fieldDecoration(
                  label: 'Target batch years',
                  hint: 'e.g. 2020-2027 or 2024, 2025',
                  helper:
                      'Use a year range (2020-2027) or comma-separated years',
                  error: _batchTouched ? _batchInputError : null,
                ),
                onChanged: (_) {
                  setState(() => _batchTouched = false);
                  if (_syncBatchFromField()) _scheduleAudienceCount();
                },
              ),
              const SizedBox(height: AdminSurveyTheme.space2),
              SwitchListTile.adaptive(
                value: _autoAssignNewAlumni,
                onChanged: (v) => setState(() => _autoAssignNewAlumni = v),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AdminColors.primary,
                title: const Text(
                  'Auto-assign new alumni',
                  style: _switchTitleStyle,
                ),
                subtitle: const Text(
                  'Alumni who register or update their program/batch later '
                  'are assigned automatically while this survey is open.',
                  style: AdminText.caption,
                ),
              ),
              if (isBuiltin)
                SwitchListTile.adaptive(
                  value: _aiHelpEnabled,
                  onChanged: (v) => setState(() => _aiHelpEnabled = v),
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AdminColors.primary,
                  title: const Text(
                    'AI answer helper',
                    style: _switchTitleStyle,
                  ),
                  subtitle: const Text(
                    'Shows "Help me answer" on question 19. Alumni describe '
                    'their job and get a suggested occupation and line of '
                    'business; question 20 then shows the line of business '
                    'as a recommendation (20 requests per alumnus per day).',
                    style: AdminText.caption,
                  ),
                ),
            ],
          ),
        ),
        if (isBuiltin)
          SurveyEditorSection(
            title: 'Questions',
            subtitle: 'Official CHED form — locked.',
            child: _buildBuiltinLockCallout(),
          )
        else
          SurveyEditorSection(
            title: 'Questions (${_questions.length})',
            subtitle:
                'Click a question to edit · drag ⋮⋮ to reorder · answer in '
                'the preview to test visibility rules.',
            trailing: TextButton.icon(
              onPressed: _addQuestionInline,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: AdminColors.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (presetCallout != null) ...[
                  presetCallout,
                  const SizedBox(height: AdminSurveyTheme.space2),
                ],
                _buildQuestionsBuilder(),
              ],
            ),
          ),
      ],
    );
  }
}

/// Edit · Preview switch for narrow layouts (one pane at a time).
class _PaneSwitch extends StatelessWidget {
  const _PaneSwitch({required this.showPreview, required this.onChanged});

  final bool showPreview;
  final ValueChanged<bool> onChanged;

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AdminColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AdminColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('Edit', !showPreview, () => onChanged(false)),
          _segment('Preview', showPreview, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _UnsavedChangesDialog extends StatelessWidget {
  const _UnsavedChangesDialog();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminColors.warningBg,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
                child: const Icon(
                  Icons.edit_note_outlined,
                  size: 20,
                  color: AdminColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Semantics(
                    header: true,
                    child: const Text(
                      'Unsaved changes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Changes to the details, schedule or audience haven\'t been saved. '
            'Question edits are saved automatically.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_UnsavedChoice.keepEditing),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminColors.textSecondary,
                  ),
                  child: const Text('Keep editing'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_UnsavedChoice.discard),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminColors.danger,
                    side: const BorderSide(color: AdminColors.border),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Discard'),
                ),
                FilledButton(
                  autofocus: true,
                  onPressed: () =>
                      Navigator.of(context).pop(_UnsavedChoice.saveAndClose),
                  style: AdminButtonStyles.filled(),
                  child: const Text('Save and close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishProblemsDialog extends StatelessWidget {
  const _PublishProblemsDialog({required this.problems});

  final List<SurveyPublishProblem> problems;

  static const _maxListed = 8;

  @override
  Widget build(BuildContext context) {
    final firstQuestion = problems
        .map((p) => p.questionIndex)
        .whereType<int>()
        .firstOrNull;
    final listed = problems.take(_maxListed).toList();
    final more = problems.length - listed.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminColors.warningBg,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
                child: const Icon(
                  Icons.rule_outlined,
                  size: 20,
                  color: AdminColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Semantics(
                    header: true,
                    child: const Text(
                      'Fix before publishing',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Alumni can\'t answer this survey yet:',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in listed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AdminColors.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.message, style: AdminText.body)),
                ],
              ),
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text('+ $more more', style: AdminText.caption),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  autofocus: firstQuestion == null,
                  onPressed: () => Navigator.of(context).pop(),
                  style: AdminButtonStyles.outlined(),
                  child: const Text('Close'),
                ),
                if (firstQuestion != null)
                  FilledButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(firstQuestion),
                    style: AdminButtonStyles.filled(),
                    child: Text('Go to question ${firstQuestion + 1}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
