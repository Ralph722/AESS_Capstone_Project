import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_home_gate.dart';
import 'package:alumni_system/features/auth/data/alumni_eligibility_service.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedCourse = CourseConstants.courses.first;

  bool _isLoading = false;
  bool _otpSent = false;
  bool _eligibilityVerified = false;
  String? _eligibilityErrorMessage;
  String? _rosterMemberId;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  final AuthService _authService = AuthService();
  final AlumniEligibilityService _eligibilityService =
      AlumniEligibilityService();
  final AuditService _auditService = AuditService();

  bool get _identityLocked => _eligibilityVerified || _otpSent;

  void _clearEligibilityError() {
    if (_eligibilityErrorMessage != null) {
      setState(() => _eligibilityErrorMessage = null);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _fullNameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      eyebrow: 'Register',
      backLabel: 'Back to login',
      title: 'Create your account',
      subtitle: 'Registration is verified against the official alumni roster.',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_eligibilityErrorMessage != null && !_eligibilityVerified)
                _StatusBanner(
                  tone: _StatusTone.error,
                  title: 'Cannot register',
                  message: _eligibilityErrorMessage!,
                ),
              if (_eligibilityVerified)
                const _StatusBanner(
                  tone: _StatusTone.success,
                  title: null,
                  message: 'Verified on official alumni roster',
                ),
              Text(
                'Alumni record',
                style: PortalTheme.caption.copyWith(
                  color: PortalTheme.navy,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: PortalTheme.space2),
              TextFormField(
                controller: _fullNameController,
                enabled: !_identityLocked,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearEligibilityError(),
                decoration: authFieldDecoration(
                  label: 'Full name',
                  icon: Icons.person_outline,
                  enabled: !_identityLocked,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: PortalTheme.space3),
              _buildCourseDropdown(),
              const SizedBox(height: PortalTheme.space3),
              TextFormField(
                controller: _studentIdController,
                enabled: !_identityLocked,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearEligibilityError(),
                decoration: authFieldDecoration(
                  label: 'ID number',
                  icon: Icons.badge_outlined,
                  enabled: !_identityLocked,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter your school ID number'
                    : null,
              ),
              const SizedBox(height: PortalTheme.space5),
              Text(
                'Account details',
                style: PortalTheme.caption.copyWith(
                  color: PortalTheme.navy,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: PortalTheme.space2),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !_otpSent,
                decoration: authFieldDecoration(
                  label: 'Gmail address',
                  icon: Icons.email_outlined,
                  enabled: !_otpSent,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter your Gmail address';
                  }
                  if (!v.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: PortalTheme.space3),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                enabled: _eligibilityVerified && !_otpSent,
                decoration: authFieldDecoration(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  enabled: _eligibilityVerified && !_otpSent,
                  helperText: 'At least 8 characters, with letters and numbers',
                  suffixIcon: _visibilityToggle(
                    obscured: _obscurePassword,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (!_eligibilityVerified) return null;
                  if (v == null || v.length < 8) {
                    return 'At least 8 characters';
                  }
                  if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                      !RegExp(r'[0-9]').hasMatch(v)) {
                    return 'Use both letters and numbers';
                  }
                  return null;
                },
              ),
              const SizedBox(height: PortalTheme.space3),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                enabled: _eligibilityVerified && !_otpSent,
                onFieldSubmitted: (_) {
                  if (!_isLoading) _handlePrimaryAction();
                },
                decoration: authFieldDecoration(
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  enabled: _eligibilityVerified && !_otpSent,
                  suffixIcon: _visibilityToggle(
                    obscured: _obscureConfirmPassword,
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                validator: (v) {
                  if (!_eligibilityVerified) return null;
                  if (v == null || v.isEmpty) {
                    return 'Confirm your password';
                  }
                  if (v != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              if (_otpSent) ...[
                const SizedBox(height: PortalTheme.space5),
                Text(
                  'Email verification',
                  style: PortalTheme.caption.copyWith(
                    color: PortalTheme.navy,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: PortalTheme.space2),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 20,
                    letterSpacing: 6,
                    color: PortalTheme.textPrimary,
                  ),
                  decoration: authFieldDecoration(
                    label: '6-digit code sent to your Gmail',
                    icon: Icons.verified_user_outlined,
                  ),
                  validator: (v) {
                    if (v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                      return 'Enter the 6-digit code';
                    }
                    return null;
                  },
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isLoading || _resendSeconds > 0
                          ? null
                          : _resendCode,
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
              ],
              const SizedBox(height: PortalTheme.space4),
              Text(_stepCaption, style: PortalTheme.meta),
              const SizedBox(height: PortalTheme.space1),
              AuthSubmitButton(
                label: _submitLabel,
                loading: _isLoading,
                onPressed: _handlePrimaryAction,
              ),
              const SizedBox(height: PortalTheme.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already registered?', style: PortalTheme.bodySecondary),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.maybePop(context),
                    style: PortalTheme.ghostButton(dense: true).copyWith(
                      foregroundColor: const WidgetStatePropertyAll(
                        PortalTheme.navy,
                      ),
                    ),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _visibilityToggle({
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: PortalTheme.textSecondary,
      ),
      onPressed: onPressed,
    );
  }

  String get _submitLabel {
    if (_otpSent) {
      return 'Verify code & create account';
    } else if (_eligibilityVerified) {
      return 'Send code to Gmail';
    } else {
      return 'Verify alumni status';
    }
  }

  String get _stepCaption {
    if (_otpSent) {
      return 'Step 3 of 3 · Email verification';
    } else if (_eligibilityVerified) {
      return 'Step 2 of 3 · Account details';
    }
    return 'Step 1 of 3 · Verify alumni status';
  }

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCourse,
      borderRadius: PortalMenu.dropdownRadius,
      dropdownColor: PortalTheme.card,
      style: const TextStyle(fontSize: 14, color: PortalTheme.textPrimary),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _identityLocked ? PortalTheme.textMuted : PortalTheme.navy,
      ),
      decoration: authFieldDecoration(
        label: 'Course',
        icon: Icons.school_outlined,
        enabled: !_identityLocked,
      ),
      items: CourseConstants.courses
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: _identityLocked
          ? null
          : (v) {
              if (v != null) {
                setState(() => _selectedCourse = v);
                _clearEligibilityError();
              }
            },
      validator: (v) => v == null ? 'Select your course' : null,
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_eligibilityVerified) {
      await _verifyEligibility();
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    if (!_otpSent) {
      await _startRegistration();
      return;
    }

    await _verifyCode();
  }

  Future<void> _verifyEligibility() async {
    setState(() {
      _isLoading = true;
      _eligibilityErrorMessage = null;
    });

    try {
      final result = await _eligibilityService.validate(
        fullName: _fullNameController.text,
        course: _selectedCourse,
        studentId: _studentIdController.text,
      );

      if (!result.eligible || result.memberId == null) {
        final message =
            result.message ??
            'You are not listed as an official alumni member. '
                'Please contact the alumni office.';
        if (!mounted) return;
        setState(() {
          _eligibilityVerified = false;
          _rosterMemberId = null;
          _eligibilityErrorMessage = message;
          _isLoading = false;
        });
        _showEligibilityError(message);
        return;
      }

      if (!mounted) return;
      setState(() {
        _eligibilityVerified = true;
        _eligibilityErrorMessage = null;
        _rosterMemberId = result.memberId;
        _isLoading = false;
        if (result.rosterFullName != null &&
            result.rosterFullName!.trim().isNotEmpty) {
          _fullNameController.text = result.rosterFullName!;
        }
      });

      showAuthFeedback(
        context,
        'Alumni status verified. Set your password and continue.',
        error: false,
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _eligibilityVerified = false;
        _eligibilityErrorMessage = message;
        _isLoading = false;
      });
      _showEligibilityError(message);
    }
  }

  void _showEligibilityError(String message) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.person_off_outlined,
          color: PortalTheme.danger,
          size: 36,
        ),
        title: const Text('Not an official alumni member'),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(height: 1.4)),
        ),
        actions: [
          FilledButton(
            style: PortalTheme.primaryButton(dense: true),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRegistration() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.startRegistration(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _fullNameController.text,
      );
      if (result == RegistrationStart.signedIn) {
        await _completeRegistration();
        return;
      }
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startResendCooldown();
      showAuthFeedback(
        context,
        'We emailed a 6-digit code to your Gmail.',
        error: false,
      );
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _isLoading = true);
    try {
      await _authService.verifyRegistrationCode(
        email: _emailController.text,
        code: _otpController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    await _completeRegistration();
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    try {
      await _authService.resendRegistrationCode(_emailController.text);
      _startResendCooldown();
      if (!mounted) return;
      showAuthFeedback(context, 'A new code is on its way.', error: false);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _useDifferentEmail() {
    _resendTimer?.cancel();
    setState(() {
      _otpSent = false;
      _resendSeconds = 0;
      _otpController.clear();
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

  /// Links the now signed-in, email-verified account to its roster record.
  Future<void> _completeRegistration() async {
    if (_rosterMemberId == null) {
      _showError('Please verify alumni status again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final fullName = _fullNameController.text.trim();
      final studentId = AlumniMemberService.normalizeStudentId(
        _studentIdController.text,
      );

      final user = AppSession.currentUser;
      if (user == null) {
        throw Exception('Account creation failed.');
      }

      await _eligibilityService.linkRegistration(
        memberId: _rosterMemberId!,
        fullName: fullName,
        course: _selectedCourse,
        studentId: studentId,
        email: email,
      );

      await _auditService.logAction(
        action: 'REGISTER',
        resource: 'User',
        resourceId: user.id,
        description: 'Alumni registered: $email ($studentId)',
        status: 'SUCCESS',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AlumniHomeGate()),
      );
    } catch (e) {
      await _authService.logout();
      await _auditService.logAction(
        action: 'REGISTER',
        resource: 'User',
        resourceId: 'unknown',
        description: 'Failed registration: ${_emailController.text}',
        status: 'FAILED',
      );
      final raw = e.toString();
      if (raw.contains('permission-denied') ||
          raw.toLowerCase().contains('row-level security') ||
          raw.toLowerCase().contains('rls')) {
        _showError(
          'Account could not be saved (database permission denied). '
          'Please try again, or contact the alumni office if it keeps failing.',
        );
      } else {
        _showError(raw.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showAuthFeedback(context, message);
  }
}

enum _StatusTone { error, success }

/// Inline roster-status feedback shown at the top of the form.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.tone,
    required this.message,
    required this.title,
  });

  final _StatusTone tone;
  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isError = tone == _StatusTone.error;
    final color = isError ? PortalTheme.danger : PortalTheme.success;
    return Container(
      margin: const EdgeInsets.only(bottom: PortalTheme.space3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isError ? 0.08 : 0.1),
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.verified_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: PortalTheme.body.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: PortalTheme.bodySecondary.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
