import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_action_dialog.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Asks for the current password before the sign-in email is changed.
/// Returns the password, or null if the user cancels.
Future<String?> showContactPasswordDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ContactPasswordDialog(),
  );
}

class _ContactPasswordDialog extends StatefulWidget {
  const _ContactPasswordDialog();

  @override
  State<_ContactPasswordDialog> createState() => _ContactPasswordDialogState();
}

class _ContactPasswordDialogState extends State<_ContactPasswordDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  var _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return PortalActionDialog(
      title: 'Confirm it is you',
      message:
          'You signed in more than 24 hours ago. Enter your current password '
          'to change your sign-in email.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focus,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: 'Current password',
              errorText: _error,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: PortalTheme.ghostButton(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: PortalTheme.primaryButton(),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
