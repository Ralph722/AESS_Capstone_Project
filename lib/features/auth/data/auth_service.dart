import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/home/data/survey_attention_reminder.dart';

enum UserRole { admin, user }

enum RegistrationStart { codeSent, signedIn }

/// Authentication — Supabase Auth only (Firebase removed).
class AuthService {
  AuthService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Runs before [logout] signs out, while the session is still valid
  /// (detaches this device from phone/browser alerts). Bounded so a slow
  /// network never blocks signing out.
  static Future<void> Function()? beforeSignOut;

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

  Future<User?> loginWithEmailPassword(
    String email,
    String password,
  ) async {
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

  /// Starts sign-up through Supabase Auth, which emails a 6-digit code.
  ///
  /// Returns [RegistrationStart.signedIn] when no code is needed: the email
  /// already belongs to a confirmed account and [password] is its password,
  /// or email confirmation is turned off for the project.
  Future<RegistrationStart> startRegistration({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'display_name': fullName.trim()},
      );
      if (response.session != null) return RegistrationStart.signedIn;
      // Supabase hides existing confirmed accounts behind a user with no
      // identities instead of returning an error.
      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        return _signInExistingAccount(normalizedEmail, password);
      }
      return RegistrationStart.codeSent;
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == 'user_already_exists' ||
          message.contains('already registered') ||
          message.contains('already been registered')) {
        return _signInExistingAccount(normalizedEmail, password);
      }
      throw Exception(_handleAuthException(e));
    }
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
  }) =>
      _assertAccountStillAuthorized(userId: userId, email: email);

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
