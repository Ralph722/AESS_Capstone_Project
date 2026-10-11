import 'package:flutter/material.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/data/password_policy.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Change-password form shared by the alumni Security page and the admin
/// dialog. Passwords only ever live in this widget's controllers.
class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({
    super.key,
    required this.role,
    required this.onSuccess,
    this.onCancel,
    this.autofocus = false,
  });

  final UserRole role;

  /// Receives whether other devices were signed out.
  final ValueChanged<bool> onSuccess;
  final VoidCallback? onCancel;
  final bool autofocus;

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final AuthService _authService = AuthService();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  bool _sessionExpired = false;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _bannerMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _bannerMessage = null;
      _sessionExpired = false;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final othersSignedOut = await _authService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
        role: widget.role,
      );
      if (!mounted) return;
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      setState(() => _submitting = false);
      widget.onSuccess(othersSignedOut);
    } on PasswordChangeException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        switch (e.failure) {
          case PasswordChangeFailure.incorrectCurrentPassword:
            _currentPasswordError = e.message;
          case PasswordChangeFailure.weakPassword ||
              PasswordChangeFailure.samePassword:
            _newPasswordError = e.message;
          case PasswordChangeFailure.sessionExpired:
            _sessionExpired = true;
            _bannerMessage = e.message;
          default:
            _bannerMessage = e.message;
        }
      });
      if (_currentPasswordError != null || _newPasswordError != null) {
        _formKey.currentState?.validate();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _bannerMessage =
            'Unable to change your password right now. Please try again later.';
      });
    }
  }

  Future<void> _signInAgain() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await _authService.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final newPassword = _newController.text;
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_bannerMessage != null)
              _FormBanner(
                message: _bannerMessage!,
                actionLabel: _sessionExpired ? 'Sign in again' : null,
                onAction: _sessionExpired ? _signInAgain : null,
              ),
            _passwordField(
              controller: _currentController,
              label: 'Current password',
              obscured: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              autofillHints: const [AutofillHints.password],
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _newFocus.requestFocus(),
              onChanged: (_) {
                if (_currentPasswordError != null) {
                  setState(() => _currentPasswordError = null);
                }
              },
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Enter your current password';
                }
                return _currentPasswordError;
              },
            ),
            const SizedBox(height: PortalTheme.space3),
            _passwordField(
              controller: _newController,
              focusNode: _newFocus,
              label: 'New password',
              obscured: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              autofillHints: const [AutofillHints.newPassword],
              helperText: PasswordPolicy.requirementText,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _confirmFocus.requestFocus(),
              onChanged: (_) => setState(() => _newPasswordError = null),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a new password';
                final policyError = PasswordPolicy.validate(v);
                if (policyError != null) return policyError;
                if (v == _currentController.text) {
                  return 'Your new password must be different from your '
                      'current password.';
                }
                return _newPasswordError;
              },
            ),
            if (newPassword.isNotEmpty) ...[
              const SizedBox(height: PortalTheme.space1),
              PasswordStrengthMeter(
                strength: PasswordPolicy.strength(newPassword),
              ),
            ],
            const SizedBox(height: PortalTheme.space3),
            _passwordField(
              controller: _confirmController,
              focusNode: _confirmFocus,
              label: 'Confirm new password',
              obscured: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Confirm your new password';
                }
                if (v != _newController.text) {
                  return 'New password and confirmation do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: PortalTheme.space5),
            Semantics(
              liveRegion: _submitting,
              label: _submitting ? 'Changing password, please wait' : null,
              child: AuthSubmitButton(
                label: 'Change Password',
                loading: _submitting,
                onPressed: _submit,
              ),
            ),
            if (widget.onCancel != null) ...[
              const SizedBox(height: PortalTheme.space1),
              TextButton(
                onPressed: _submitting ? null : widget.onCancel,
                style: PortalTheme.ghostButton(),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscured,
    required VoidCallback onToggle,
    required Iterable<String> autofillHints,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
    required FormFieldValidator<String> validator,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
    String? helperText,
    bool autofocus = false,
  }) {
    final name = label.toLowerCase();
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscured,
      enableSuggestions: false,
      autocorrect: false,
      readOnly: _submitting,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      validator: validator,
      decoration: authFieldDecoration(
        label: label,
        icon: Icons.lock_outline,
        helperText: helperText,
        suffixIcon: IconButton(
          tooltip: obscured ? 'Show $name' : 'Hide $name',
          icon: Icon(
            obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: PortalTheme.textSecondary,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _FormBanner extends StatelessWidget {
  const _FormBanner({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: PortalTheme.space3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PortalTheme.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          border: Border.all(color: PortalTheme.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: PortalTheme.danger,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: PortalTheme.bodySecondary.copyWith(
                      color: PortalTheme.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: onAction,
                        style: PortalTheme.ghostButton(dense: true).copyWith(
                          foregroundColor: const WidgetStatePropertyAll(
                            PortalTheme.navy,
                          ),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
