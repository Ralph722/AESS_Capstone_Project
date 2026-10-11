import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/home/data/survey_attention_reminder.dart';

enum UserRole { admin, user }

enum RegistrationStart { codeSent, signedIn }

enum PasswordChangeFailure {
  incorrectCurrentPassword,
  invalidCode,
  weakPassword,
  samePassword,
  accountUnavailable,
  sessionExpired,
  rateLimited,
  network,
  unknown,
}

/// Safe, user-facing failure from [AuthService.changePassword] and the
/// password reset methods.
class PasswordChangeException implements Exception {
  const PasswordChangeException(this.failure, this.message);

  final PasswordChangeFailure failure;
  final String message;

  @override
  String toString() => message;
}

/// Authentication — Supabase Auth only (Firebase removed).
class AuthService {
  AuthService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Runs before [logout] signs out, while the session is still valid
  /// (detaches this device from phone/browser alerts). Bounded so a slow
  /// network never blocks signing out.
  static Future<void> Function()? beforeSignOut;

  /// Runs after a password change or reset signs out the user's other sessions
  /// (removes those devices from phone/browser alerts). Bounded and
  /// fire-and-forget so it never delays or fails the password change.
  static Future<void> Function()? afterOtherSessionsRevoked;

  User? getCurrentUser() => AppSession.currentUser;

  Future<UserRole?> getUserRole(String userId) async {
    try {
      final row = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return UserRole.user;
      return row['role'] == 'admin' ? UserRole.admin : UserRole.user;
    } catch (_) {
      return null;
    }
  }

  /// Role + onboarding flag in one round-trip (used after login).
  Future<({UserRole? role, bool onboardingComplete})> getLoginRouting(
    String userId,
  ) async {
    try {
      final row = await _supabase
          .from('users')
          .select('role, onboarding_complete')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) {
        return (role: UserRole.user, onboardingComplete: false);
      }
      final role = row['role'] == 'admin' ? UserRole.admin : UserRole.user;
      return (
        role: role,
        onboardingComplete: row['onboarding_complete'] == true,
      );
    } catch (_) {
      return (role: null, onboardingComplete: false);
    }
  }

  Future<UserRole?> getCurrentUserRole() async {
    final id = AppSession.userId;
    if (id == null) return null;
    return getUserRole(id);
  }

  Future<void> setUserRole(
    String uid,
    UserRole role, {
    String? displayName,
    String? email,
  }) async {
    await _supabase.from('users').upsert({
      'id': uid,
      'role': role == UserRole.admin ? 'admin' : 'user',
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
      if (email != null && email.isNotEmpty) 'email': email.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<User?> loginWithEmailPassword(String email, String password) async {
    final normalizedEmail = email.trim();
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = response.user ?? AppSession.currentUser;
      if (user != null) {
        await _assertAccountStillAuthorized(
          userId: user.id,
          email: user.email ?? normalizedEmail,
        );
      }
      return user;
    } on AuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('failed to fetch') ||
          msg.contains('clientexception') ||
          msg.contains('socketexception') ||
          msg.contains('network')) {
        throw Exception(
          'Unable to reach the server. Check your internet connection and try again.',
        );
      }
      rethrow;
    }
  }

  /// Starts sign-up through Supabase Auth, which emails a verification code.
  ///
  /// Returns [RegistrationStart.signedIn] only when the email already belongs
  /// to a confirmed account and [password] is its password.
  ///
  /// Throws when the project auto-confirms sign-ups ("Confirm email" off):
  /// the address was never proven, so registration must not continue.
  Future<RegistrationStart> startRegistration({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final AuthResponse response;
    try {
      response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'display_name': fullName.trim()},
      );
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'user_already_exists' ||
          message.contains('already registered') ||
          message.contains('already been registered')) {
        return _signInExistingAccount(normalizedEmail, password);
      }
      throw Exception(_handleAuthException(e));
    }

    if (response.session != null) {
      debugPrint(
        'Registration blocked: sign-up returned a session, so "Confirm email" '
        'is off in Supabase (Authentication → Providers → Email).',
      );
      await _supabase.auth.signOut(scope: SignOutScope.local);
      throw Exception(
        'We couldn’t send a verification code to your Gmail right now. '
        'Please try again later or contact the alumni office.',
      );
    }

    // Supabase hides existing confirmed accounts behind a user with no
    // identities instead of returning an error.
    final identities = response.user?.identities;
    if (identities != null && identities.isEmpty) {
      return _signInExistingAccount(normalizedEmail, password);
    }
    return RegistrationStart.codeSent;
  }

  Future<RegistrationStart> _signInExistingAccount(
    String email,
    String password,
  ) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return RegistrationStart.signedIn;
    } on AuthException {
      throw Exception(
        'An account already exists for this email. '
        'Log in with your existing password instead.',
      );
    }
  }

  Future<void> resendRegistrationCode(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
      );
    } on AuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  /// Confirms the emailed code, which signs the user in.
  Future<User> verifyRegistrationCode({
    required String email,
    required String code,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await _supabase.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.signup,
      );
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'otp_expired' ||
          message.contains('expired') ||
          message.contains('invalid')) {
        throw Exception(
          'That code is invalid or has expired. '
          'Use the latest code we emailed, or request a new one.',
        );
      }
      throw Exception(_handleAuthException(e));
    }

    final user = response.user ?? AppSession.currentUser;
    if (user == null) {
      throw Exception('Verification failed. Request a new code and try again.');
    }
    // Repeating a sign-up for an unconfirmed email keeps the first password,
    // so set the one this person just chose.
    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
    } on AuthException catch (_) {}
    return user;
  }

  /// Changes the signed-in user's own password in Supabase Auth.
  ///
  /// Supabase verifies [currentPassword] by signing in again, which also
  /// satisfies "recent login" when secure password change is enabled. Other
  /// sessions are then revoked; this device stays signed in.
  ///
  /// Returns whether other sessions were signed out. Throws
  /// [PasswordChangeException] with a safe message on failure.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required UserRole role,
  }) async {
    final user = AppSession.currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty || AppSession.currentSession == null) {
      throw const PasswordChangeException(
        PasswordChangeFailure.sessionExpired,
        _sessionExpiredMessage,
      );
    }

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (response.user?.id != user.id) {
        await _supabase.auth.signOut();
        throw const PasswordChangeException(
          PasswordChangeFailure.sessionExpired,
          _sessionExpiredMessage,
        );
      }
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on PasswordChangeException {
      rethrow;
    } on AuthException catch (e) {
      throw _passwordChangeFailure(e);
    } catch (e) {
      throw _unexpectedPasswordFailure(e);
    }

    return _afterPasswordUpdated(
      user: user,
      role: role,
      action: 'PASSWORD_CHANGE',
      description: 'changed password',
    );
  }

  /// Emails a password reset code (the hosted "Reset password"
  /// template must include the token). Supabase answers the same way whether
  /// or not the email has an account, so callers must not reveal which.
  Future<void> sendPasswordResetCode(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (_isUnreachable(e)) {
        throw const PasswordChangeException(
          PasswordChangeFailure.network,
          _sendCodeNetworkMessage,
        );
      }
      if (e.code == 'over_email_send_rate_limit' ||
          e.code == 'over_request_rate_limit' ||
          e.statusCode == '429' ||
          message.contains('rate limit') ||
          message.contains('for security purposes')) {
        throw const PasswordChangeException(
          PasswordChangeFailure.rateLimited,
          'Too many code requests. Please wait a few minutes and try again.',
        );
      }
      throw const PasswordChangeException(
        PasswordChangeFailure.unknown,
        _sendCodeGenericMessage,
      );
    } catch (e) {
      throw _isNetworkError(e)
          ? const PasswordChangeException(
              PasswordChangeFailure.network,
              _sendCodeNetworkMessage,
            )
          : const PasswordChangeException(
              PasswordChangeFailure.unknown,
              _sendCodeGenericMessage,
            );
    }
  }

  /// Confirms an emailed reset code, which signs the user in, then applies
  /// the same roster / deactivation checks as login. On failure the user is
  /// signed out.
  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final AuthResponse response;
    try {
      response = await _supabase.auth.verifyOTP(
        email: normalizedEmail,
        token: code.trim(),
        type: OtpType.recovery,
      );
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'user_banned' || message.contains('banned')) {
        throw const PasswordChangeException(
          PasswordChangeFailure.accountUnavailable,
          'This alumni account has been deactivated. '
          'Please contact the alumni office.',
        );
      }
      if (e.code == 'otp_expired' ||
          message.contains('expired') ||
          message.contains('invalid')) {
        throw const PasswordChangeException(
          PasswordChangeFailure.invalidCode,
          'That code is invalid or has expired. '
          'Use the latest code we emailed, or request a new one.',
        );
      }
      throw _passwordChangeFailure(e);
    } catch (e) {
      throw _unexpectedPasswordFailure(e);
    }

    final user = response.user ?? AppSession.currentUser;
    if (user == null) {
      throw const PasswordChangeException(
        PasswordChangeFailure.invalidCode,
        'Verification failed. Request a new code and try again.',
      );
    }
    try {
      await ensureAccountAuthorized(
        userId: user.id,
        email: user.email ?? normalizedEmail,
      );
    } catch (e) {
      throw PasswordChangeException(
        PasswordChangeFailure.accountUnavailable,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Sets the new password after [verifyPasswordResetCode] succeeded for
  /// [email] in the same reset attempt. Returns whether other sessions were
  /// signed out.
  Future<bool> completePasswordReset({
    required String email,
    required String newPassword,
  }) async {
    final user = AppSession.currentUser;
    final signedInEmail = user?.email?.trim().toLowerCase() ?? '';
    if (user == null ||
        AppSession.currentSession == null ||
        signedInEmail != email.trim().toLowerCase()) {
      throw const PasswordChangeException(
        PasswordChangeFailure.sessionExpired,
        'Your reset code has expired. Request a new code and try again.',
      );
    }

    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw _passwordChangeFailure(e);
    } catch (e) {
      throw _unexpectedPasswordFailure(e);
    }

    final role = await getUserRole(user.id) ?? UserRole.user;
    return _afterPasswordUpdated(
      user: user,
      role: role,
      action: 'PASSWORD_RESET',
      description: 'reset password with an emailed code',
    );
  }

  /// Signs out other sessions, detaches their devices from alerts, and
  /// records the change. Returns whether other sessions were signed out.
  Future<bool> _afterPasswordUpdated({
    required User user,
    required UserRole role,
    required String action,
    required String description,
  }) async {
    var othersSignedOut = true;
    try {
      await _supabase.auth.signOut(scope: SignOutScope.others);
    } catch (_) {
      othersSignedOut = false;
    }
    final revokeHook = afterOtherSessionsRevoked;
    if (othersSignedOut && revokeHook != null) {
      unawaited(
        revokeHook()
            .timeout(const Duration(seconds: 4))
            .catchError((Object _) {}),
      );
    }

    final isAdmin = role == UserRole.admin;
    final label = isAdmin ? 'Admin' : 'User';
    unawaited(
      AuditService(supabase: _supabase).logAction(
        action: action,
        resource: label,
        resourceId: user.id,
        description: '$label $description: ${user.email ?? ''}',
        status: 'SUCCESS',
        userRole: isAdmin ? 'admin' : 'user',
      ),
    );

    return othersSignedOut;
  }

  static const _sessionExpiredMessage =
      'Your session has expired. Please sign in again.';
  static const _passwordNetworkMessage =
      'Unable to change your password right now. '
      'Please check your connection and try again.';
  static const _passwordGenericMessage =
      'Unable to change your password right now. Please try again later.';
  static const _sendCodeNetworkMessage =
      'Unable to send the code right now. '
      'Please check your connection and try again.';
  static const _sendCodeGenericMessage =
      'Unable to send the code right now. Please try again later.';

  PasswordChangeException _unexpectedPasswordFailure(Object e) {
    return _isNetworkError(e)
        ? const PasswordChangeException(
            PasswordChangeFailure.network,
            _passwordNetworkMessage,
          )
        : const PasswordChangeException(
            PasswordChangeFailure.unknown,
            _passwordGenericMessage,
          );
  }

  PasswordChangeException _passwordChangeFailure(AuthException e) {
    final code = e.code;
    final message = e.message.toLowerCase();
    if (_isUnreachable(e)) {
      return const PasswordChangeException(
        PasswordChangeFailure.network,
        _passwordNetworkMessage,
      );
    }
    if (code == 'invalid_credentials' ||
        message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return const PasswordChangeException(
        PasswordChangeFailure.incorrectCurrentPassword,
        'Your current password is incorrect.',
      );
    }
    if (e is AuthWeakPasswordException || code == 'weak_password') {
      final breached =
          e is AuthWeakPasswordException && e.reasons.contains('pwned');
      return PasswordChangeException(
        PasswordChangeFailure.weakPassword,
        breached
            ? 'This password has appeared in a known data breach. '
                  'Choose a different password.'
            : 'Your new password does not meet the password requirements.',
      );
    }
    if (code == 'same_password') {
      return const PasswordChangeException(
        PasswordChangeFailure.samePassword,
        'Your new password must be different from your current password.',
      );
    }
    if (code == 'over_request_rate_limit' ||
        e.statusCode == '429' ||
        message.contains('rate limit')) {
      return const PasswordChangeException(
        PasswordChangeFailure.rateLimited,
        'Too many attempts. Please wait a few minutes and try again.',
      );
    }
    if (e is AuthSessionMissingException ||
        e is AuthInvalidJwtException ||
        code == 'session_not_found' ||
        code == 'user_not_found' ||
        code == 'user_banned' ||
        code == 'reauthentication_needed' ||
        e.statusCode == '401' ||
        e.statusCode == '403') {
      return const PasswordChangeException(
        PasswordChangeFailure.sessionExpired,
        _sessionExpiredMessage,
      );
    }
    return const PasswordChangeException(
      PasswordChangeFailure.unknown,
      _passwordGenericMessage,
    );
  }

  /// Retryable errors without a status code never reached the server; 5xx
  /// retryable errors are server failures and get the generic message.
  bool _isUnreachable(AuthException e) =>
      (e is AuthRetryableFetchException && e.statusCode == null) ||
      (e.statusCode == null && _isNetworkError(e));

  bool _isNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('failed to fetch') ||
        msg.contains('clientexception') ||
        msg.contains('socketexception') ||
        msg.contains('network');
  }

  Future<void> logout() async {
    AppImage.clearDecodedCache();
    final hook = beforeSignOut;
    if (hook != null) {
      try {
        await hook().timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    await _supabase.auth.signOut();
    SurveyAttentionReminder.resetForSession();
  }

  /// Public entry used by [loginWithEmailPassword] and cold-start [AuthGate].
  Future<void> ensureAccountAuthorized({
    required String userId,
    required String email,
  }) => _assertAccountStillAuthorized(userId: userId, email: email);

  Future<void> _assertAccountStillAuthorized({
    required String userId,
    required String email,
  }) async {
    try {
      final existing = await _supabase
          .from('users')
          .select('id, role')
          .eq('id', userId)
          .maybeSingle();

      // Accounts not linked to an active roster row cannot read their own
      // users row, so this also covers unfinished registrations.
      if (existing == null) {
        await _supabase.auth.signOut();
        throw Exception(
          'This account is not linked to the AESS alumni roster. '
          'Finish registration from the Register page, or contact the alumni office.',
        );
      }

      final role = (existing['role'] as String? ?? 'user').toLowerCase();
      if (role == 'admin') return;

      final member = await _supabase
          .from('alumni_members')
          .select('id')
          .eq('auth_uid', userId)
          .eq('is_registered_user', true)
          .eq('is_deactivated', false)
          .maybeSingle();

      if (member == null) {
        await _supabase.auth.signOut();
        throw Exception(
          'This alumni account has been deleted or unlinked. '
          'Please register again before logging in.',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      await _supabase.auth.signOut();
      throw Exception(
        'Unable to verify account access for ${email.trim()}. Please try again.',
      );
    }
  }

  String _handleAuthException(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return 'Invalid email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (message.contains('banned')) {
      return 'This alumni account has been deactivated. '
          'Please contact the alumni office.';
    }
    if (e.code == 'over_email_send_rate_limit' ||
        message.contains('rate limit')) {
      return 'Too many emails were sent. Please wait a few minutes and try again.';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'An account already exists for this email.';
    }
    if (message.contains('password')) {
      return e.message;
    }
    return e.message.isNotEmpty ? e.message : 'Authentication failed.';
  }
}
