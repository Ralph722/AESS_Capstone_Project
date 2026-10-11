import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_home_gate.dart';
import 'package:alumni_system/features/auth/data/alumni_eligibility_service.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/data/email_code_policy.dart';
import 'package:alumni_system/features/auth/data/password_policy.dart';
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
  String? _eligibilityErrorCode;
  String? _rosterMemberId;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  final AuthService _authService = AuthService();
  final AlumniEligibilityService _eligibilityService =
      AlumniEligibilityService();
  final AuditService _auditService = AuditService();

  /// 0 = verify alumni record, 1 = account details, 2 = email code.
  int get _step => _otpSent
      ? 2
      : _eligibilityVerified
      ? 1
      : 0;

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
      showBackButton: false,
      title: 'Create your account',
      subtitle: 'Registration is verified against the official alumni roster.',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RegisterStepper(current: _step),
              const SizedBox(height: PortalTheme.space4),
              // Only the current step's fields are built, so validation
              // never trips over a field the graduate cannot see yet.
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : PortalTheme.normal,
                switchInCurve: PortalTheme.ease,
                switchOutCurve: PortalTheme.ease,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current],
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _buildRecordStep(),
                    1 => _buildAccountStep(),
                    _ => _buildCodeStep(),
                  },
                ),
              ),
              const SizedBox(height: PortalTheme.space4),
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

  /// Step 1: only what the roster check uses.
  Widget _buildRecordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_eligibilityErrorMessage != null)
          _ErrorBanner(
            title: _eligibilityErrorStyle.$1,
            message: _eligibilityErrorMessage!,
          ),
        const _SectionLabel('Alumni record'),
        Text(
          'Enter your details exactly as they appear in your school records.',
          style: PortalTheme.meta,
        ),
        const SizedBox(height: PortalTheme.space3),
        TextFormField(
          controller: _fullNameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          onChanged: (_) => _clearEligibilityError(),
          decoration: authFieldDecoration(
            label: 'Full name',
            icon: Icons.person_outline,
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter your full name' : null,
        ),
        const SizedBox(height: PortalTheme.space3),
        _buildCourseDropdown(),
        const SizedBox(height: PortalTheme.space3),
        TextFormField(
          controller: _studentIdController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _clearEligibilityError(),
          onFieldSubmitted: (_) {
            if (!_isLoading) _handlePrimaryAction();
          },
          decoration: authFieldDecoration(
            label: 'ID number',
            icon: Icons.badge_outlined,
          ),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Enter your school ID number'
              : null,
        ),
      ],
    );
  }

  /// Step 2: sign-in details for the verified graduate.
  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VerifiedRecordCard(
          name: _fullNameController.text.trim(),
          course: _selectedCourse,
          studentId: _studentIdController.text.trim(),
          onChange: _isLoading ? null : _changeRecord,
        ),
        const SizedBox(height: PortalTheme.space4),
        const _SectionLabel('Account details'),
        Text(
          'You’ll use these to sign in. We’ll email a code to confirm your '
          'Gmail.',
          style: PortalTheme.meta,
        ),
        const SizedBox(height: PortalTheme.space3),
        TextFormField(
          controller: _emailController,
          autofocus: _emailController.text.isEmpty,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: authFieldDecoration(
            label: 'Gmail address',
            icon: Icons.email_outlined,
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
          decoration: authFieldDecoration(
            label: 'Password',
            icon: Icons.lock_outline,
            helperText: PasswordPolicy.requirementText,
            suffixIcon: _visibilityToggle(
              obscured: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: PasswordPolicy.validate,
        ),
        const SizedBox(height: PortalTheme.space3),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: (_) {
            if (!_isLoading) _handlePrimaryAction();
          },
          decoration: authFieldDecoration(
            label: 'Confirm password',
            icon: Icons.lock_outline,
            suffixIcon: _visibilityToggle(
              obscured: _obscureConfirmPassword,
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) {
              return 'Confirm your password';
            }
            if (v != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Step 3: confirm the Gmail with the emailed code.
  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VerifiedRecordCard(
          name: _fullNameController.text.trim(),
          course: _selectedCourse,
          studentId: _studentIdController.text.trim(),
          onChange: null,
        ),
        const SizedBox(height: PortalTheme.space4),
        const _SectionLabel('Email verification'),
        Text.rich(
          TextSpan(
            text: 'We sent a verification code to ',
            children: [
              TextSpan(
                text: _emailController.text.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PortalTheme.textPrimary,
                ),
              ),
              const TextSpan(text: '. It can take a minute to arrive.'),
            ],
          ),
          style: PortalTheme.meta,
        ),
        const SizedBox(height: PortalTheme.space3),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: EmailCodePolicy.inputFormatters,
          textAlign: TextAlign.center,
          autofocus: true,
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            if (!_isLoading) _handlePrimaryAction();
          },
          style: const TextStyle(
            fontSize: 20,
            letterSpacing: 6,
            color: PortalTheme.textPrimary,
          ),
          decoration: authFieldDecoration(
            label: 'Verification code',
            icon: Icons.verified_user_outlined,
          ),
          validator: EmailCodePolicy.validate,
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: _isLoading || _resendSeconds > 0 ? null : _resendCode,
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
    );
  }

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCourse,
      borderRadius: PortalMenu.dropdownRadius,
      dropdownColor: PortalTheme.card,
      style: const TextStyle(fontSize: 14, color: PortalTheme.textPrimary),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: PortalTheme.navy,
      ),
      decoration: authFieldDecoration(
        label: 'Course',
        icon: Icons.school_outlined,
      ),
      items: CourseConstants.courses
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => _selectedCourse = v);
          _clearEligibilityError();
        }
      },
      validator: (v) => v == null ? 'Select your course' : null,
    );
  }

  /// Returns to step 1 so a wrong course or ID can be corrected.
  void _changeRecord() {
    setState(() {
      _eligibilityVerified = false;
      _rosterMemberId = null;
      _eligibilityErrorMessage = null;
    });
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
            'We couldn’t find a matching alumni record. Please contact the '
                'alumni office.';
        if (!mounted) return;
        setState(() {
          _eligibilityVerified = false;
          _rosterMemberId = null;
          _eligibilityErrorMessage = message;
          _eligibilityErrorCode = result.code;
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
        'Alumni status verified. Now set up your account.',
        error: false,
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _eligibilityVerified = false;
        _eligibilityErrorMessage = message;
        _eligibilityErrorCode = 'unavailable';
        _isLoading = false;
      });
      _showEligibilityError(message);
    }
  }

  /// Title and icon for a failed roster check, from the server's code.
  (String, IconData) get _eligibilityErrorStyle =>
      switch (_eligibilityErrorCode) {
        'already_exists' => (
          'Account already exists',
          Icons.manage_accounts_outlined,
        ),
        'failed_precondition' => (
          'Alumni record deactivated',
          Icons.person_off_outlined,
        ),
        'not_found' => ('No matching alumni record', Icons.search_off_rounded),
        'unavailable' => (
          'Couldn’t check the roster',
          Icons.cloud_off_outlined,
        ),
        _ => ('Check your details', Icons.error_outline),
      };

  void _showEligibilityError(String message) {
    if (!mounted) return;
    final (title, icon) = _eligibilityErrorStyle;
    final alreadyRegistered = _eligibilityErrorCode == 'already_exists';

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, color: PortalTheme.danger, size: 36),
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(height: 1.4)),
        ),
        actions: [
          if (alreadyRegistered) ...[
            TextButton(
              style: PortalTheme.ghostButton(dense: true),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              style: PortalTheme.primaryButton(dense: true),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.maybePop(context);
              },
              child: const Text('Go to login'),
            ),
          ] else
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
        'We emailed a verification code to your Gmail.',
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
        code: EmailCodePolicy.normalize(_otpController.text),
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

/// Three-segment progress for Verify → Account → Email code.
class _RegisterStepper extends StatelessWidget {
  const _RegisterStepper({required this.current});

  final int current;

  static const _labels = ['Verify', 'Account', 'Email code'];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of ${_labels.length}: ${_labels[current]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0) const SizedBox(width: PortalTheme.space1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: PortalTheme.normal,
                    curve: PortalTheme.ease,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < current
                          ? PortalTheme.success
                          : i == current
                          ? PortalTheme.navy
                          : PortalTheme.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i < current ? '✓ ${_labels[i]}' : _labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PortalTheme.caption.copyWith(
                      fontWeight: i == current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: i == current
                          ? PortalTheme.navy
                          : i < current
                          ? PortalTheme.success
                          : PortalTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space1),
      child: Text(
        text,
        style: PortalTheme.caption.copyWith(
          color: PortalTheme.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Collapsed alumni record shown once the roster check passes.
class _VerifiedRecordCard extends StatelessWidget {
  const _VerifiedRecordCard({
    required this.name,
    required this.course,
    required this.studentId,
    required this.onChange,
  });

  final String name;
  final String course;
  final String studentId;

  /// Null hides the Change link (after the code has been sent).
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: PortalTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        border: Border.all(color: PortalTheme.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_outlined,
            color: PortalTheme.success,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified on official alumni roster',
                  style: PortalTheme.caption.copyWith(
                    color: PortalTheme.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PortalTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$course · ID $studentId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PortalTheme.meta,
                ),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              style: PortalTheme.ghostButton(dense: true),
              child: const Text(
                'Change',
                semanticsLabel: 'Change alumni record',
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline roster-check failure shown above the record fields.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.title});

  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    const color = PortalTheme.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: PortalTheme.space3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: color, size: 20),
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
