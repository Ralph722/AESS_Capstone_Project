import 'package:flutter/material.dart';
import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/contact_verification/presentation/contact_password_dialog.dart';
import 'package:alumni_system/features/contact_verification/presentation/contact_verify_card.dart';
import 'package:alumni_system/shared/widgets/user/portal_action_dialog.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// A contact to verify: the saved value and the one to check.
class ContactChange {
  const ContactChange({
    required this.channel,
    required this.original,
    required this.value,
  });

  final ContactChannel channel;
  final String original;
  final String value;
}

/// Verifies [changes] one by one; each contact is saved as soon as its code
/// is checked. Closing early leaves the rest unsaved (the caller reloads the
/// profile, which puts them back).
///
/// Returns the saved contacts, as the server stores them.
Future<Map<ContactChannel, String>> showContactVerifySheet(
  BuildContext context, {
  required List<ContactChange> changes,
  String? message,
  ContactVerificationService? service,
}) async {
  final saved = await showModalBottomSheet<Map<ContactChannel, String>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PortalTheme.radius2xl),
      ),
    ),
    builder: (_) => ContactVerifySheet(
      changes: changes,
      message: message,
      service: service,
    ),
  );
  return saved ?? const {};
}

class ContactVerifySheet extends StatefulWidget {
  const ContactVerifySheet({
    super.key,
    required this.changes,
    this.message,
    this.service,
  });

  final List<ContactChange> changes;

  /// Intro line while codes are pending.
  final String? message;
  final ContactVerificationService? service;

  @override
  State<ContactVerifySheet> createState() => _ContactVerifySheetState();
}

class _ContactVerifySheetState extends State<ContactVerifySheet> {
  late final ContactVerificationService _service =
      widget.service ?? ContactVerificationService();
  late final Map<ContactChannel, String> _values = {
    for (final c in widget.changes) c.channel: c.value,
  };
  final Map<ContactChannel, String> _saved = {};
  final Map<ContactChannel, String> _errors = {};
  ContactChannel? _saving;
  String? _loginEmail;

  bool _isSaved(ContactChannel c) =>
      ContactNormalizer.same(c, _saved[c], _values[c]);

  List<ContactChannel> get _pending => [
    for (final c in widget.changes)
      if (!_isSaved(c.channel)) c.channel,
  ];

  Future<void> _onVerified(ContactChannel channel, String target) async {
    setState(() {
      _saving = channel;
      _errors.remove(channel);
    });
    try {
      String? password;
      if (channel == ContactChannel.email && _service.needsPasswordRecheck()) {
        password = await showContactPasswordDialog(context);
        if (!mounted) return;
        if (password == null) {
          setState(() {
            _errors[channel] =
                'Confirm your password to change your sign-in email.';
          });
          return;
        }
      }
      final result = await _service.saveVerified(
        channel,
        target,
        password: password,
      );
      if (!mounted) return;
      setState(() {
        _saved[channel] = result.target;
        _values[channel] = result.target;
        if (result.loginChanged) _loginEmail = result.target;
      });
    } on ContactVerificationException catch (e) {
      if (!mounted) return;
      if (e.needsPassword) {
        final password = await showContactPasswordDialog(context);
        if (!mounted) return;
        if (password == null) {
          setState(() => _errors[channel] = e.message);
          return;
        }
        try {
          final result = await _service.saveVerified(
            channel,
            target,
            password: password,
          );
          if (!mounted) return;
          setState(() {
            _saved[channel] = result.target;
            _values[channel] = result.target;
            if (result.loginChanged) _loginEmail = result.target;
            _errors.remove(channel);
          });
        } on ContactVerificationException catch (retry) {
          if (mounted) setState(() => _errors[channel] = retry.message);
        }
      } else {
        setState(() => _errors[channel] = e.message);
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _close() async {
    final pending = _pending;
    if (pending.isNotEmpty) {
      final what = pending.length > 1
          ? 'your new contact details'
          : pending.single == ContactChannel.email
          ? 'your new email address'
          : 'your new mobile number';
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => PortalActionDialog(
          title: 'Leave without verifying?',
          message:
              "If you leave now, $what won't be saved and your profile "
              'keeps what it had before.',
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: PortalTheme.primaryButton(),
              child: const Text('Keep verifying'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: PortalActionDialog.dangerOutlinedButton(),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    Navigator.of(context).pop(Map<ContactChannel, String>.from(_saved));
  }

  @override
  Widget build(BuildContext context) {
    final done = _pending.isEmpty;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final loginEmail = _loginEmail;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Verify your contact details',
                        style: PortalTheme.pageTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving == null ? _close : null,
                      icon: const Icon(Icons.close_rounded),
                      color: PortalTheme.navy,
                    ),
                  ],
                ),
                Text(
                  done
                      ? (loginEmail != null
                            ? 'All set! From now on, sign in with $loginEmail.'
                            : 'All set! Your contact details are saved.')
                      : widget.message ??
                            'Confirm these are yours with a one-time code so '
                                'the alumni office can reach you.',
                  style: PortalTheme.bodySecondary.copyWith(fontSize: 13.5),
                ),
                for (final change in widget.changes) ...[
                  const SizedBox(height: 14),
                  ContactVerifyCard(
                    key: ValueKey('profile-verify-${change.channel.wire}'),
                    channel: change.channel,
                    original: change.original,
                    value: _values[change.channel] ?? change.value,
                    verified: _isSaved(change.channel),
                    verifiedText: change.channel == ContactChannel.email
                        ? (_saved[change.channel] != null &&
                                  loginEmail != null &&
                                  ContactNormalizer.same(
                                    ContactChannel.email,
                                    _saved[change.channel],
                                    loginEmail,
                                  )
                              ? 'Email verified. From now on, sign in with '
                                    'this address.'
                              : 'Email verified and saved.')
                        : 'Number confirmed and saved.',
                    enabled: _saving == null,
                    service: _service,
                    onValueChanged: (v) =>
                        setState(() => _values[change.channel] = v),
                    onVerified: (t) => _onVerified(change.channel, t),
                  ),
                  if (_errors[change.channel] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        _errors[change.channel]!,
                        style: PortalTheme.meta.copyWith(
                          color: PortalTheme.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: done && _saving == null ? _close : null,
                  style: PortalTheme.primaryButton(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
