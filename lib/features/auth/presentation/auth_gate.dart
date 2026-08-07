import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/presentation/login_page.dart';
import 'package:alumni_system/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_onboarding_page.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';

/// Resolves cold-start / restored Supabase sessions into the correct root screen.
///
/// Preserves existing login routing:
/// admin → [AdminDashboardWeb]
/// alumni incomplete onboarding → [AlumniOnboardingScreen]
/// alumni ready → [MainNavigation]
/// signed out / unauthorized → [LoginScreen]
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _AuthDestination { loading, failed, login, admin, onboarding, home }

class _AuthGateState extends State<AuthGate> {
  static const _resolveTimeout = Duration(seconds: 20);

  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _authSub;

  _AuthDestination _destination = _AuthDestination.loading;
  String? _statusMessage;
  Object? _resolveToken;

  @override
  void initState() {
    super.initState();
    _resolve();
    _authSub = AppSession.onAuthStateChange.listen((state) {
      final event = state.event;
      if (event == AuthChangeEvent.signedOut) {
        AppImage.clearDecodedCache();
        if (!mounted) return;
        setState(() {
          _destination = _AuthDestination.login;
          _statusMessage = null;
        });
        return;
      }
      // Cold start: Supabase may emit initialSession after first frame.
      if (event == AuthChangeEvent.initialSession) {
        if (_destination == _AuthDestination.login ||
            _destination == _AuthDestination.loading ||
            _destination == _AuthDestination.failed) {
          _resolve();
        }
        return;
      }
      // Explicit sign-in is navigated by LoginScreen / Register flows.
      // Do not swap AuthGate children mid-login (avoids unmount races).
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    final token = Object();
    _resolveToken = token;

    if (mounted) {
      setState(() {
        _destination = _AuthDestination.loading;
        _statusMessage = 'Restoring your session…';
      });
    }

    final session = AppSession.currentSession;
    final user = AppSession.currentUser;
    if (session == null || user == null) {
      if (!mounted || _resolveToken != token) return;
      setState(() {
        _destination = _AuthDestination.login;
        _statusMessage = null;
      });
      return;
    }

    try {
      // Re-validate roster / profile the same way login does.
      await _authService
          .ensureAccountAuthorized(
            userId: user.id,
            email: user.email ?? '',
          )
          .timeout(_resolveTimeout);
      if (!mounted || _resolveToken != token) return;

      final routing = await _authService
          .getLoginRouting(user.id)
          .timeout(_resolveTimeout);
      if (!mounted || _resolveToken != token) return;

      final role = routing.role;
      if (role == null) {
        await _authService.logout();
        if (!mounted || _resolveToken != token) return;
        setState(() {
          _destination = _AuthDestination.login;
          _statusMessage = null;
        });
        return;
      }

      setState(() {
        if (role == UserRole.admin) {
          _destination = _AuthDestination.admin;
        } else if (!routing.onboardingComplete) {
          _destination = _AuthDestination.onboarding;
        } else {
          _destination = _AuthDestination.home;
        }
        _statusMessage = null;
      });
    } on TimeoutException {
      if (!mounted || _resolveToken != token) return;
      setState(() {
        _destination = _AuthDestination.failed;
        _statusMessage =
            'Taking longer than usual. Check your connection and try again.';
      });
    } catch (_) {
      try {
        await _authService.logout();
      } catch (_) {}
      if (!mounted || _resolveToken != token) return;
      setState(() {
        _destination = _AuthDestination.login;
        _statusMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_destination) {
      case _AuthDestination.loading:
        return _AuthSplash(message: _statusMessage);
      case _AuthDestination.failed:
        return _AuthSplash(
          message: _statusMessage,
          onRetry: _resolve,
          onSignInInstead: () {
            setState(() {
              _destination = _AuthDestination.login;
              _statusMessage = null;
            });
          },
        );
      case _AuthDestination.login:
        return const LoginScreen();
      case _AuthDestination.admin:
        return const AdminDashboardWeb();
      case _AuthDestination.onboarding:
        return const AlumniOnboardingScreen();
      case _AuthDestination.home:
        return const MainNavigation();
    }
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash({
    this.message,
    this.onRetry,
    this.onSignInInstead,
  });

  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onSignInInstead;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry != null;
    return Scaffold(
      backgroundColor: const Color(0xFF090A4F),
      body: Semantics(
        label: retry
            ? 'Session restore failed. ${message ?? ''}'
            : (message ?? 'Loading'),
        liveRegion: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!retry)
                  const ExcludeSemantics(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 40,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                const SizedBox(height: 20),
                Text(
                  message ?? 'Loading…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                if (retry) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF090A4F),
                      minimumSize: const Size(160, 44),
                    ),
                    child: const Text('Try again'),
                  ),
                  if (onSignInInstead != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onSignInInstead,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        minimumSize: const Size(160, 44),
                      ),
                      child: const Text('Sign in instead'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
