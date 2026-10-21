import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/data/email_code_policy.dart';
import 'package:alumni_system/features/auth/data/password_policy.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Login → Forgot password. Emails a recovery code, then sets a new
/// password and signs the user in through [AuthGate].
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  final _codeController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final AuthService _authService = AuthService();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  /// Set once this screen verified the emailed code; the recovery session
  /// then belongs to [_verifiedEmail] until the reset completes or is
  /// abandoned.
  String? _verifiedEmail;
  bool _completed = false;

  String? _codeError;
  String? _newPasswordError;

  String get _email => _emailController.text.trim().toLowerCase();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// A verified but unfinished reset leaves the user signed in; sign out so
  /// leaving this screen never leaves a session behind.
  void _abandonVerifiedReset() {
    if (_verifiedEmail == null || _completed) return;
    _verifiedEmail = null;
    unawaited(_authService.logout());
  }

  Future<void> _sendCode() async {
    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordResetCode(_email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startResendCooldown();
      showAuthFeedback(
        context,
        'If an account exists for that email, we sent a verification code.',
        error: false,
      );
    } on PasswordChangeException catch (e) {
      if (mounted) showAuthFeedback(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _isLoading = true);
    try {
      if (_verifiedEmail != _email) {
        await _authService.verifyPasswordResetCode(
          email: _email,
          code: EmailCodePolicy.normalize(_codeController.text),
        );
        _verifiedEmail = _email;
      }
      final othersSignedOut = await _authService.completePasswordReset(
        email: _email,
        newPassword: _newController.text,
      );
      _completed = true;
      if (!mounted) return;
      showAuthFeedback(
        context,
        othersSignedOut
            ? 'Password reset successfully. Other devices have been signed out.'
            : 'Password reset successfully.',
        error: false,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } on PasswordChangeException catch (e) {
      if (!mounted) return;
      switch (e.failure) {
        case PasswordChangeFailure.invalidCode:
          _codeError = e.message;
          _formKey.currentState?.validate();
        case PasswordChangeFailure.weakPassword ||
            PasswordChangeFailure.samePassword:
          _newPasswordError = e.message;
          _formKey.currentState?.validate();
        case PasswordChangeFailure.accountUnavailable ||
            PasswordChangeFailure.sessionExpired:
          _verifiedEmail = null;
          showAuthFeedback(context, e.message);
        default:
          showAuthFeedback(context, e.message);
      }
    } finally {
      if (mounted && !_completed) setState(() => _isLoading = false);
    }
  }

  void _submit() {
    if (_isLoading) return;
    setState(() {
      _codeError = null;
      _newPasswordError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    if (_codeSent) {
      _resetPassword();
    } else {
      _sendCode();
    }
  }

  void _useDifferentEmail() {
    _abandonVerifiedReset();
    _resendTimer?.cancel();
    setState(() {
      _codeSent = false;
      _resendSeconds = 0;
      _codeError = null;
      _newPasswordError = null;
      _codeController.clear();
      _newController.clear();
      _confirmController.clear();
    });
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final codeVerified = _verifiedEmail != null && _verifiedEmail == _email;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _abandonVerifiedReset();
      },
      child: AuthShell(
        backLabel: 'Back to login',
        title: 'Reset your password',
        subtitle: _codeSent
            ? 'Enter the code we emailed to $_email. It expires in 1 hour.'
            : "Enter your account's email address and we'll send you "
                  'a verification code.',
        form: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  autofocus: widget.initialEmail.trim().isEmpty,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: authFieldDecoration(
                    label: 'Email address',
                    icon: Icons.email_outlined,
                    enabled: !_codeSent,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                if (_codeSent) ..._resetFields(codeVerified),
                const SizedBox(height: PortalTheme.space4),
                Semantics(
                  liveRegion: _isLoading,
                  label: _isLoading ? 'Please wait' : null,
                  child: AuthSubmitButton(
                    label: _codeSent ? 'Reset password' : 'Send code',
                    loading: _isLoading,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _resetFields(bool codeVerified) {
    final newPassword = _newController.text;
    return [
      const SizedBox(height: PortalTheme.space3),
      TextFormField(
        controller: _codeController,
        enabled: !codeVerified,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: EmailCodePolicy.inputFormatters,
        autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          letterSpacing: 6,
          color: PortalTheme.textPrimary,
        ),
        onChanged: (_) {
          if (_codeError != null) setState(() => _codeError = null);
        },
        onFieldSubmitted: (_) => _newFocus.requestFocus(),
        decoration: authFieldDecoration(
          label: 'Verification code',
          icon: Icons.verified_user_outlined,
          enabled: !codeVerified,
          helperText: codeVerified ? 'Code verified' : null,
        ),
        validator: (v) {
          if (codeVerified) return null;
          return EmailCodePolicy.validate(v) ?? _codeError;
        },
      ),
      if (!codeVerified)
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: _isLoading || _resendSeconds > 0 ? null : _sendCode,
              style: PortalTheme.ghostButton(dense: true),
              child: Text(
                _resendSeconds > 0
                    ? 'Resend code in ${_resendSeconds}s'
                    : 'Resend code',
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _useDifferentEmail,
              style: PortalTheme.ghostButton(dense: true),
              child: const Text('Use a different email'),
            ),
          ],
        ),
      const SizedBox(height: PortalTheme.space3),
      TextFormField(
        controller: _newController,
        focusNode: _newFocus,
        obscureText: _obscureNew,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        onChanged: (_) => setState(() => _newPasswordError = null),
        onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
        decoration: authFieldDecoration(
          label: 'New password',
          icon: Icons.lock_outline,
          helperText: PasswordPolicy.requirementText,
          suffixIcon: _visibilityToggle(
            name: 'new password',
            obscured: _obscureNew,
            onPressed: () => setState(() => _obscureNew = !_obscureNew),
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Enter a new password';
          return PasswordPolicy.validate(v) ?? _newPasswordError;
        },
      ),
      if (newPassword.isNotEmpty) ...[
        const SizedBox(height: PortalTheme.space1),
        PasswordStrengthMeter(strength: PasswordPolicy.strength(newPassword)),
      ],
      const SizedBox(height: PortalTheme.space3),
      TextFormField(
        controller: _confirmController,
        focusNode: _confirmFocus,
        obscureText: _obscureConfirm,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.newPassword],
        onFieldSubmitted: (_) => _submit(),
        decoration: authFieldDecoration(
          label: 'Confirm new password',
          icon: Icons.lock_outline,
          suffixIcon: _visibilityToggle(
            name: 'confirm new password',
            obscured: _obscureConfirm,
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Confirm your new password';
          if (v != _newController.text) {
            return 'New password and confirmation do not match.';
          }
          return null;
        },
      ),
    ];
  }

  Widget _visibilityToggle({
    required String name,
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscured ? 'Show $name' : 'Hide $name',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: PortalTheme.textSecondary,
      ),
      onPressed: onPressed,
    );
  }
}
