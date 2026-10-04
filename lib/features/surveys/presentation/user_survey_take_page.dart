import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/data/classic_survey_visibility.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';
import 'package:alumni_system/features/surveys/presentation/widgets/survey_take_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

class UserSurveyTakeScreen extends StatefulWidget {
  const UserSurveyTakeScreen({super.key, required this.surveyId});

  final String surveyId;

  @override
  State<UserSurveyTakeScreen> createState() => _UserSurveyTakeScreenState();
}

class _UserSurveyTakeScreenState extends State<UserSurveyTakeScreen> {
  final _surveyService = SurveyService();
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};

  Survey? _survey;
  List<SurveyQuestion> _questions = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isSubmitted = false;
  bool _dirty = false;

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    final uid = AppSession.userId;
    final results = await Future.wait<dynamic>([
      _surveyService.getSurvey(widget.surveyId),
      _surveyService.getQuestions(widget.surveyId),
      if (uid != null)
        _surveyService.getResponse(widget.surveyId, uid)
      else
        Future<SurveyResponse?>.value(null),
    ]);
    final survey = results[0] as Survey?;
    final questions = results[1] as List<SurveyQuestion>;
    final response = results.length > 2 ? results[2] as SurveyResponse? : null;

    for (final q in questions) {
      if (q.type == SurveyQuestionType.text ||
          q.type == SurveyQuestionType.longText) {
        _textControllers[q.id] = TextEditingController();
      }
    }

    if (response != null) {
      _answers.addAll(response.answers);
      _isSubmitted = response.status == SurveyResponseStatus.submitted;
    }

    if (uid != null && !_isSubmitted) {
      final prefill = await _surveyService.buildPrefillAnswersByQuestionId(
        questions: questions,
        userId: uid,
        existingAnswers: _answers,
      );
      for (final entry in prefill.entries) {
        if (entry.value == null) {
          _answers.remove(entry.key);
        } else {
          _answers[entry.key] = entry.value;
        }
      }
    }

    for (final q in questions) {
      if (q.type == SurveyQuestionType.text ||
          q.type == SurveyQuestionType.longText) {
        _textControllers[q.id]?.text = _answers[q.id]?.toString() ?? '';
      }
    }

    if (mounted) {
      setState(() {
        _survey = survey;
        _questions = questions;
        _isLoading = false;
      });
    }

    if (uid != null &&
        !_isSubmitted &&
        survey != null &&
        survey.acceptsResponses) {
      unawaited(_surveyService.recordSurveyOpened(widget.surveyId));
    }
  }

  Future<void> _save({required bool submit}) async {
    if (_survey != null && !_survey!.acceptsResponses && !_isSubmitted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _survey!.isNotYetOpen
                ? 'This survey is not open yet.'
                : 'This survey is closed.',
          ),
          backgroundColor: SurveyTakeTheme.danger,
        ),
      );
      return;
    }
    for (final q in _questions) {
      if (q.type == SurveyQuestionType.text ||
          q.type == SurveyQuestionType.longText) {
        _answers[q.id] = _textControllers[q.id]?.text ?? '';
      }
    }

    setState(() => _isSaving = true);
    try {
      await _surveyService.saveResponse(
        surveyId: widget.surveyId,
        answers: Map<String, dynamic>.from(_answers),
        submit: submit,
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submit ? 'Survey submitted. Thank you!' : 'Draft saved',
          ),
          backgroundColor: SurveyTakeTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (submit) {
        Navigator.pop(context);
      } else {
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(portalFriendlyError(e)),
            backgroundColor: SurveyTakeTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<SurveyQuestion> get _visibleQuestions {
    final rules = _survey?.visibilityRules ?? const {};
    if (_survey?.isChedGtsBuiltin == true || rules.isEmpty) {
      return _questions;
    }
    return ClassicSurveyVisibility.visibleQuestions(
      questions: _questions,
      answers: _answers,
      rules: rules,
    );
  }

  Future<void> _confirmAndSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final missing = _visibleQuestions
        .where((q) => q.required && !surveyTakeAnswerFilled(_answers[q.id]))
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please answer: ${missing.first.prompt}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit survey?'),
        content: const Text(
          'You will not be able to edit answers after submitting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: PortalTheme.primaryButton(dense: true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _save(submit: true);
    }
  }

  Widget _buildSubmittedAnswer(SurveyQuestion q, int number) {
    final formatted = formatSurveyAnswerValue(_answers[q.id]);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: SurveyTakeTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SurveyTakeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ${q.prompt}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: SurveyTakeTheme.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatted.isEmpty ? '—' : formatted,
            style: const TextStyle(
              fontSize: 13.5,
              color: SurveyTakeTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleQuestions;
    final answered = visible
        .where((q) => surveyTakeAnswerFilled(_answers[q.id]))
        .length;

    return PopScope(
      canPop: !_dirty || _isSubmitted,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty || _isSubmitted) return;
        final discard = await confirmDiscardChanges(context);
        if (!discard || !mounted) return;
        setState(() => _dirty = false);
        Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        title: _survey?.title ?? 'Survey',
      ),
      body: _isLoading && _questions.isEmpty
          ? const SurveyFormSkeleton()
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: SurveyTakeHeaderCard(
                            title: _survey?.title ?? 'Survey',
                            description: _survey?.description ?? '',
                            totalQuestions: visible.length,
                            answeredCount: answered,
                            showProgress: !_isSubmitted,
                          ),
                        ),
                        if (_survey?.isFromTemplate == true && !_isSubmitted)
                          Container(
                            margin:
                                const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PortalTheme.sky.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                              border: Border.all(
                                color: PortalTheme.sky.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: PortalTheme.sky,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Some answers may be prefilled from your '
                                    'Alumni Tracer employment profile. Update '
                                    'Tracer if anything changed.',
                                    style: PortalTheme.meta.copyWith(
                                      color: PortalTheme.navy,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_survey != null &&
                            !_isSubmitted &&
                            !_survey!.acceptsResponses)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: PortalTheme.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                PortalTheme.radiusMd,
                              ),
                              border: Border.all(
                                color: PortalTheme.gold.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _survey!.isNotYetOpen
                                      ? Icons.lock_clock_outlined
                                      : Icons.lock_outline,
                                  size: 20,
                                  color: PortalTheme.navy,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _survey!.isNotYetOpen &&
                                            _survey!.openAt != null
                                        ? 'This survey opens on '
                                            '${DateFormat.yMMMd().add_jm().format(_survey!.openAt!)}. '
                                            'You can answer once the schedule begins.'
                                        : 'This survey is closed and no longer '
                                            'accepts responses.',
                                    style: PortalTheme.meta.copyWith(
                                      color: PortalTheme.navy,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_isSubmitted)
                          Container(
                            margin:
                                const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: SurveyTakeTheme.successSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: SurveyTakeTheme.success
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 20,
                                  color: SurveyTakeTheme.success,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'You have already submitted this survey. '
                                    'Thank you for your response!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: SurveyTakeTheme.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < visible.length; i++) ...[
                          if (surveyTakeShowsSectionHeader(visible, i))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                              child: SurveySectionBanner(
                                label: visible[i].sectionLabel,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: _isSubmitted
                                ? _buildSubmittedAnswer(visible[i], i + 1)
                                : SurveyQuestionCard(
                                    question: visible[i],
                                    number: i + 1,
                                    answer: _answers[visible[i].id],
                                    textController:
                                        _textControllers[visible[i].id],
                                    textValidator: visible[i].required
                                        ? (v) =>
                                            v == null || v.trim().isEmpty
                                                ? 'Required'
                                                : null
                                        : null,
                                    onAnswerChanged: (v) => setState(
                                      () {
                                        _answers[visible[i].id] = v;
                                        if (!_isSubmitted) _dirty = true;
                                      },
                                    ),
                                  ),
                          ),
                        ],
                        if (visible.isEmpty && !_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'This survey has no questions yet.',
                                style: TextStyle(
                                  color: SurveyTakeTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_isSubmitted && (_survey?.acceptsResponses ?? false))
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      decoration: BoxDecoration(
                        color: PortalTheme.card,
                        border: const Border(
                          top: BorderSide(color: PortalTheme.border),
                        ),
                        boxShadow: PortalTheme.softShadow,
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : () => _save(submit: false),
                                icon: const Icon(Icons.save_outlined, size: 18),
                                label: const Text('Save draft'),
                                style: PortalTheme.secondaryButton(dense: true).copyWith(
                                  minimumSize: WidgetStateProperty.all(
                                    const Size(0, 48),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    _isSaving ? null : _confirmAndSubmit,
                                icon: _isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 18),
                                label:
                                    Text(_isSaving ? 'Saving…' : 'Submit'),
                                style: PortalTheme.primaryButton(dense: true).copyWith(
                                  minimumSize: WidgetStateProperty.all(
                                    const Size(0, 48),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}
