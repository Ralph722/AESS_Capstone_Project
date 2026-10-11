import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/features/auth/presentation/forgot_password_page.dart';
import 'package:alumni_system/features/auth/presentation/register_page.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/auth/data/login_preferences_service.dart';
import 'package:alumni_system/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_onboarding_page.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();
  final AuditService _auditService = AuditService();
  final LoginPreferencesService _loginPreferences = LoginPreferencesService();

  @override
  void initState() {
    super.initState();
    _loadSavedLoginPreferences();
  }

  Future<void> _loadSavedLoginPreferences() async {
    final saved = await _loginPreferences.load();
    if (!mounted) return;
    setState(() {
      _rememberMe = saved.rememberMe;
      if (saved.email != null) {
        _emailController.text = saved.email!;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to continue to your alumni portal.',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: authFieldDecoration(
                  label: 'Email address',
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: PortalTheme.space3),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (!_isLoading) _handleLogin();
                },
                decoration: authFieldDecoration(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: PortalTheme.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: PortalTheme.space2),
              Row(
                children: [
                  SizedBox(
                    height: 40,
                    width: 40,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: PortalTheme.navy,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (value) async {
                        final remember = value ?? false;
                        setState(() {
                          _rememberMe = remember;
                        });
                        if (!remember) {
                          await _loginPreferences.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      final remember = !_rememberMe;
                      setState(() => _rememberMe = remember);
                      if (!remember) {
                        await _loginPreferences.clear();
                      }
                    },
                    child: Text(
                      'Remember me',
                      style: PortalTheme.body.copyWith(fontSize: 14),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  initialEmail: _emailController.text,
                                ),
                              ),
                            );
                          },
                    style: PortalTheme.ghostButton(dense: true).copyWith(
                      foregroundColor: const WidgetStatePropertyAll(
                        PortalTheme.navy,
                      ),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              const SizedBox(height: PortalTheme.space4),
              AuthSubmitButton(
                label: 'Log in',
                loading: _isLoading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: PortalTheme.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: PortalTheme.bodySecondary,
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                    style: PortalTheme.ghostButton(dense: true).copyWith(
                      foregroundColor: const WidgetStatePropertyAll(
                        PortalTheme.navy,
                      ),
                    ),
                    child: const Text('Register now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.loginWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null && mounted) {
        final routing = await _authService.getLoginRouting(user.id);
        final userRole = routing.role;
        if (userRole == null) {
          await _authService.logout();
          throw Exception(
            'No account profile found in the database. '
            'If you are an admin, recreate your user profile in Supabase '
            '(see docs/restore-admin-account.md).',
          );
        }

        unawaited(
          _loginPreferences.save(
            rememberMe: _rememberMe,
            email: _emailController.text,
          ),
        );

        final roleString = userRole == UserRole.admin ? 'admin' : 'user';
        unawaited(
          _auditService.logAction(
            action: 'LOGIN',
            resource: roleString == 'admin' ? 'Admin' : 'User',
            resourceId: user.id,
            description:
                '${roleString == 'admin' ? 'Admin' : 'User'} logged in: ${user.email}',
            status: 'SUCCESS',
            userRole: roleString,
          ),
        );

        if (mounted) {
          if (userRole == UserRole.admin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminDashboardWeb(),
              ),
            );
          } else if (!routing.onboardingComplete) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AlumniOnboardingScreen(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          }
        }
      }
    } catch (e) {
      await _auditService.logAction(
        action: 'LOGIN',
        resource: 'User',
        resourceId: 'unknown',
        description: 'Failed login attempt: ${_emailController.text}',
        status: 'FAILED',
        userRole: 'user',
      );

      if (mounted) {
        showAuthFeedback(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
