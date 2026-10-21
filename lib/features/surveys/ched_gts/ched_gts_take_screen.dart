import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/alumni/tracer/data/tracer_reminder_service.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/tracer_reminder_sheet.dart';
import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/contact_verification/presentation/contact_password_dialog.dart';
import 'package:alumni_system/shared/widgets/user/portal_action_dialog.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_contacts.dart';
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
    this.contactOriginals,
  });

  final String surveyId;
  final Map<String, dynamic> initialAnswers;

  /// See [ChedGtsForm.prefilledAnswers].
  final Map<String, dynamic> prefilledAnswers;
  final DateTime? closeAt;

  /// Shows "Help me answer" on Q19/Q20 (admin switch per survey).
  final bool aiHelpEnabled;

  /// Profile contacts; a changed Q3/Q5 must be verified before submit.
  final ChedGtsContactOriginals? contactOriginals;

  static Future<bool> open(
    BuildContext context, {
    required String surveyId,
    required Map<String, dynamic> initialAnswers,
    Map<String, dynamic> prefilledAnswers = const {},
    DateTime? closeAt,
    bool aiHelpEnabled = true,
    ChedGtsContactOriginals? contactOriginals,
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
              contactOriginals: contactOriginals,
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
  final _contactService = ContactVerificationService();
  late Map<String, dynamic> _answers;
  bool _saving = false;
  bool _dirty = false;

  /// Set by the wizard when the alumnus opts in after choosing Married.
  bool _marriageNameChangeOptedIn = false;

  /// Contacts verified this session, as the server stores them.
  final Map<ContactChannel, String> _verified = {};

  /// Verified contacts already saved to the profile (a verification can be
  /// saved once, so a retried submit skips these).
  final Map<ContactChannel, String> _applied = {};

  /// Login email set during this submit, if the alumnus changed Q3.
  String? _newLoginEmail;

  List<ContactChannel> get _unverifiedContacts {
    final originals = widget.contactOriginals;
    return originals == null
        ? const []
        : ChedGtsContacts.unverified(_answers, originals, _verified);
  }

  @override
  void initState() {
    super.initState();
    _answers = Map<String, dynamic>.from(widget.initialAnswers);
    // Name is locked to the verified prefill unless marriage opt-in unlocks it.
    final prefilledName = widget.prefilledAnswers['ched_1'];
    if (prefilledName != null && prefilledName.toString().trim().isNotEmpty) {
      _answers['ched_1'] = prefilledName;
    }
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
        marriageNameChangeOptedIn: _marriageNameChangeOptedIn,
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

  /// Saves verified Q3/Q5 changes to the profile. False when one failed.
  Future<bool> _saveVerifiedContacts() async {
    final originals = widget.contactOriginals;
    if (originals == null) return true;
    if (_unverifiedContacts.isNotEmpty) {
      _toast('Please verify your new contact details first.', error: true);
      return false;
    }
    setState(() => _saving = true);
    _newLoginEmail = null;
    try {
      for (final c in ChedGtsContacts.changed(_answers, originals)) {
        final target = _verified[c]!;
        if (_applied[c] == target) continue;
        String? password;
        if (c == ContactChannel.email &&
            _contactService.needsPasswordRecheck()) {
          if (!mounted) return false;
          password = await showContactPasswordDialog(context);
          if (!mounted) return false;
          if (password == null) {
            _toast(
              'Confirm your password to change your sign-in email.',
              error: true,
            );
            return false;
          }
        }
        final result = await _contactService.saveVerified(
          c,
          target,
          password: password,
        );
        _applied[c] = result.target;
        if (result.loginChanged) _newLoginEmail = result.target;
      }
      return true;
    } on ContactVerificationException catch (e) {
      if (mounted) {
        setState(() {
          for (final c in ContactChannel.values) {
            if (_applied[c] != _verified[c]) _verified.remove(c);
          }
        });
      }
      _toast(e.message, error: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!await _saveVerifiedContacts() || !mounted) return;
    if (await _save(submit: true) && mounted) {
      unawaited(
        _reminderService.cancelReminder(widget.surveyId).catchError((_) {}),
      );
      final login = _newLoginEmail;
      if (login != null && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => PortalActionDialog(
            title: 'Survey submitted',
            message:
                'From now on, sign in with $login. Your password is unchanged.',
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: PortalTheme.primaryButton(),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
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
    final originals = widget.contactOriginals;
    final unverified = _unverifiedContacts;
    if (!_dirty && unverified.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => PortalActionDialog(
        title: 'Save your progress?',
        message: [
          if (_dirty)
            'You have unsaved answers. Save a draft so you can continue '
                'where you left off.',
          if (unverified.isNotEmpty && originals != null)
            ChedGtsContacts.revertMessage(unverified, originals),
        ].join('\n\n'),
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
      if (unverified.isNotEmpty && originals != null) {
        setState(() {
          _answers = ChedGtsContacts.revertUnverified(
            _answers,
            originals,
            _verified,
          );
        });
      }
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
      onMarriageNameOptChanged: (v) => _marriageNameChangeOptedIn = v,
      onSubmit: _submit,
      onClose: _close,
      contactOriginals: widget.contactOriginals,
      verifiedContacts: _verified,
      onContactVerified: (channel, target) => setState(() {
        _verified[channel] = target;
        _answers = {..._answers, ChedGtsContacts.itemId(channel): target};
        _dirty = true;
      }),
      contactService: _contactService,
    );
  }
}
