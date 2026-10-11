import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/alumni/tracer/data/tracer_reminder_service.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/tracer_reminder_sheet.dart';
import 'package:alumni_system/shared/widgets/user/portal_action_dialog.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_wizard.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

enum _LeaveChoice { save, discard }

/// Full-screen CHED GTS answering flow (no tabs / bottom nav).
///
/// Pops `true` after a successful submit, otherwise `false`.
class ChedGtsTakeScreen extends StatefulWidget {
  const ChedGtsTakeScreen({
    super.key,
    required this.surveyId,
    required this.initialAnswers,
    this.prefilledAnswers = const {},
    this.closeAt,
    this.aiHelpEnabled = true,
  });

  final String surveyId;
  final Map<String, dynamic> initialAnswers;

  /// See [ChedGtsForm.prefilledAnswers].
  final Map<String, dynamic> prefilledAnswers;
  final DateTime? closeAt;

  /// Shows "Help me answer" on Q19/Q20 (admin switch per survey).
  final bool aiHelpEnabled;

  static Future<bool> open(
    BuildContext context, {
    required String surveyId,
    required Map<String, dynamic> initialAnswers,
    Map<String, dynamic> prefilledAnswers = const {},
    DateTime? closeAt,
    bool aiHelpEnabled = true,
  }) async {
    final submitted = await Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute(
            builder: (_) => ChedGtsTakeScreen(
              surveyId: surveyId,
              initialAnswers: initialAnswers,
              prefilledAnswers: prefilledAnswers,
              closeAt: closeAt,
              aiHelpEnabled: aiHelpEnabled,
            ),
          ),
        );
    return submitted == true;
  }

  @override
  State<ChedGtsTakeScreen> createState() => _ChedGtsTakeScreenState();
}

class _ChedGtsTakeScreenState extends State<ChedGtsTakeScreen> {
  final _surveyService = SurveyService();
  final _reminderService = TracerReminderService();
  late Map<String, dynamic> _answers;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _answers = Map<String, dynamic>.from(widget.initialAnswers);
    unawaited(_surveyService.recordSurveyOpened(widget.surveyId));
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
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

  Future<bool> _save({required bool submit}) async {
    setState(() => _saving = true);
    try {
      await _surveyService.saveResponse(
        surveyId: widget.surveyId,
        answers: _answers,
        submit: submit,
      );
      _dirty = false;
      return true;
    } catch (e) {
      _toast(portalFriendlyError(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (await _save(submit: true) && mounted) {
      unawaited(
        _reminderService.cancelReminder(widget.surveyId).catchError((_) {}),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _offerReminder() async {
    final choice = await showTracerReminderSheet(
      context,
      closeAt: widget.closeAt,
    );
    if (!mounted) return;
    if (choice == null) {
      _toast('Draft saved. You can continue anytime.');
      return;
    }
    try {
      await _reminderService.setReminder(
        surveyId: widget.surveyId,
        remindAt: choice.remindAt,
        repeatHourly: choice.repeatHourly,
      );
      _toast(
        "Draft saved. We'll remind you ${formatReminderTime(choice.remindAt)}.",
      );
    } catch (_) {
      _toast(
        "Draft saved, but the reminder couldn't be set. Please try again "
        'from the Tracer tab.',
        error: true,
      );
    }
  }

  Future<void> _close() async {
    if (!_dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => PortalActionDialog(
        title: 'Save your progress?',
        message:
            'You have unsaved answers. Save a draft so you can continue '
            'where you left off.',
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.save),
            style: PortalTheme.primaryButton(),
            child: const Text('Save draft'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.discard),
            style: PortalActionDialog.dangerOutlinedButton(),
            child: const Text('Leave without saving'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: PortalActionDialog.quietButton(),
            child: const Text('Keep answering'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == _LeaveChoice.save) {
      if (!await _save(submit: false) || !mounted) return;
      await _offerReminder();
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return ChedGtsWizard(
      answers: _answers,
      prefilledAnswers: widget.prefilledAnswers,
      saving: _saving,
      helpSurveyId: widget.aiHelpEnabled ? widget.surveyId : null,
      onChanged: (a) => setState(() {
        _answers = a;
        _dirty = true;
      }),
      onSubmit: _submit,
      onClose: _close,
    );
  }
}
