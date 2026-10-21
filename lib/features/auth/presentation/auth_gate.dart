import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/shared/widgets/aess_logo.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/presentation/login_page.dart';
import 'package:alumni_system/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_onboarding_page.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_token_service.dart';
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
        ImageStorageService.clearSignedUrlCache();
        AlumniCardTokenService.clearSharedCache();
        // Defer so concurrent Navigator replacements (e.g. Profile logout
        // after a notification cold-start) can dispose this gate first.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _destination = _AuthDestination.login;
            _statusMessage = null;
          });
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
          .ensureAccountAuthorized(userId: user.id, email: user.email ?? '')
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
    } catch (e) {
      if (!mounted || _resolveToken != token) return;
      // Network / transient errors: keep session and offer retry.
      // Authorization / account failures: sign out and return to login.
      if (_looksLikeNetworkError(e)) {
        setState(() {
          _destination = _AuthDestination.failed;
          _statusMessage =
              'Connection problem. Check your internet and try again.';
        });
        return;
      }
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

  bool _looksLikeNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socket') ||
        msg.contains('failed to fetch') ||
        msg.contains('clientexception') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timed out') ||
        msg.contains('timeout');
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
  const _AuthSplash({this.message, this.onRetry, this.onSignInInstead});

  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onSignInInstead;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry != null;
    return Scaffold(
      backgroundColor: Colors.white,
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
                const ExcludeSemantics(child: AessLogo(height: 72)),
                const SizedBox(height: 36),
                if (!retry)
                  const ExcludeSemantics(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: PortalTheme.navy,
                        backgroundColor: Color(0x1F1A1851),
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: PortalTheme.textSecondary,
                  ),
                const SizedBox(height: 16),
                Text(
                  message ?? 'Loading…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PortalTheme.textSecondary,
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
                      backgroundColor: PortalTheme.navy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(160, 44),
                    ),
                    child: const Text('Try again'),
                  ),
                  if (onSignInInstead != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onSignInInstead,
                      style: TextButton.styleFrom(
                        foregroundColor: PortalTheme.navy,
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
