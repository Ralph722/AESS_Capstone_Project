import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/auth/presentation/login_page.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_home_gate.dart';
import 'package:alumni_system/features/auth/data/alumni_eligibility_service.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/email_service.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/core/services/audit_service.dart';

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
  String? _generatedOtp;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late final EmailService _emailService;
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
  void initState() {
    super.initState();
    _emailService = EmailService();
  }

  @override
  void dispose() {
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF090A4F), Color(0xFF151875)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A4ECA).withOpacity(0.4),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00D4FF).withOpacity(0.2),
                ),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_add,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Alumni Registration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Official roster verification required',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 420),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_eligibilityErrorMessage != null &&
                                      !_eligibilityVerified)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.redAccent.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.redAccent.shade200,
                                            size: 26,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Cannot register',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.redAccent.shade100,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _eligibilityErrorMessage!,
                                                  style: TextStyle(
                                                    color: Colors.red.shade100,
                                                    fontSize: 14,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_eligibilityVerified)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.greenAccent.withOpacity(0.4),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.verified_outlined,
                                            color: Colors.greenAccent.shade200,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Verified on official alumni roster',
                                              style: TextStyle(
                                                color: Colors.greenAccent.shade100,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  _buildGlassTextField(
                                    controller: _fullNameController,
                                    label: 'Full name',
                                    icon: Icons.person_outline,
                                    enabled: !_identityLocked,
                                    onChanged: (_) => _clearEligibilityError(),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Enter your full name'
                                            : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildCourseDropdown(),
                                  const SizedBox(height: 16),
                                  _buildGlassTextField(
                                    controller: _studentIdController,
                                    label: 'ID number',
                                    icon: Icons.badge_outlined,
                                    enabled: !_identityLocked,
                                    onChanged: (_) => _clearEligibilityError(),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Enter your school ID number'
                                            : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildGlassTextField(
                                    controller: _emailController,
                                    label: 'Gmail',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    enabled: !_identityLocked,
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
                                  const SizedBox(height: 20),
                                  _buildGlassTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscurePassword,
                                    isPassword: true,
                                    enabled: _eligibilityVerified && !_otpSent,
                                    validator: (v) {
                                      if (!_eligibilityVerified) return null;
                                      if (v == null || v.length < 6) {
                                        return 'At least 6 characters';
                                      }
                                      return null;
                                    },
                                    onToggleObscure: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildGlassTextField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm password',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscureConfirmPassword,
                                    isPassword: true,
                                    enabled: _eligibilityVerified && !_otpSent,
                                    validator: (v) {
                                      if (!_eligibilityVerified) return null;
                                      if (v == null || v.isEmpty) {
                                        return 'Confirm your password';
                                      }
                                      return null;
                                    },
                                    onToggleObscure: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                  if (_otpSent) ...[
                                    const SizedBox(height: 20),
                                    _buildGlassTextField(
                                      controller: _otpController,
                                      label: '6-digit OTP',
                                      icon: Icons.verified_user_outlined,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      isOtp: true,
                                      validator: (v) {
                                        if (v == null || v.length != 6) {
                                          return 'Enter the 6-digit OTP';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 28),
                                  _buildSubmitButton(),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already registered? ',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const LoginScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'Login',
                                          style: TextStyle(
                                            color: Color(0xFF00D4FF),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCourse,
      dropdownColor: const Color(0xFF151875),
      decoration: InputDecoration(
        labelText: 'Course',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: Icon(
          Icons.school_outlined,
          color: Colors.white.withOpacity(0.7),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(_identityLocked ? 0.02 : 0.05),
        enabled: !_identityLocked,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      style: const TextStyle(color: Colors.white),
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

  Widget _buildSubmitButton() {
    String label;
    if (_otpSent) {
      label = 'Verify OTP & create account';
    } else if (_eligibilityVerified) {
      label = 'Send OTP to Gmail';
    } else {
      label = 'Verify alumni status';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF4A4ECA)],
        ),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handlePrimaryAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
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
      await _sendOtp();
      return;
    }

    if (_otpController.text.trim() != _generatedOtp) {
      _showError('Invalid OTP. Please try again.');
      return;
    }

    await _createAccount();
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
        final message = result.message ??
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Alumni status verified. Set your password and continue.',
          ),
          backgroundColor: Colors.green,
        ),
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

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF6B6B),
        duration: const Duration(seconds: 6),
      ),
    );

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.person_off_outlined, color: Colors.red.shade700, size: 40),
        title: const Text('Not an official alumni member'),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (!EmailDeliveryConfig.isConfigured) {
      _showError(
        'Email verification is not configured. Check Gmail SMTP / Supabase secrets.',
      );
      return;
    }

    setState(() => _isLoading = true);
    final otp = _generateOtp();

    try {
      await _emailService.sendOtpEmail(
        toEmail: _emailController.text.trim(),
        otp: otp,
        username: _fullNameController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _generatedOtp = otp;
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent to your Gmail.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Failed to send OTP: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAccount() async {
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

      final user = await _authService.registerWithEmailPassword(
        email,
        _passwordController.text,
        fullName,
      );

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

  String _generateOtp() {
    final random = Random.secure();
    return (random.nextInt(900000) + 100000).toString();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    TextInputType? keyboardType,
    int? maxLength,
    bool isOtp = false,
    bool enabled = true,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
    VoidCallback? onToggleObscure,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      enabled: enabled,
      onChanged: onChanged,
      textAlign: isOtp ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: enabled ? Colors.white : Colors.white54,
        fontSize: isOtp ? 20 : 16,
        letterSpacing: isOtp ? 6 : null,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white.withOpacity(0.7),
                ),
                onPressed: onToggleObscure,
              )
            : null,
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(enabled ? 0.05 : 0.02),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isOtp ? Colors.greenAccent : const Color(0xFF00D4FF),
            width: 2,
          ),
        ),
      ),
      validator: validator,
    );
  }
}
