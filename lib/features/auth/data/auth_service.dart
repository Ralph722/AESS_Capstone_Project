import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/app_image.dart';

enum UserRole { admin, user }

/// Authentication — Supabase Auth only (Firebase removed).
class AuthService {
  AuthService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

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

  /// Creates or updates the alumni profile row after registration.
  Future<void> createAlumniUserProfile({
    required String uid,
    required String displayName,
    required String email,
    required String studentId,
    required String course,
  }) async {
    await _supabase.from('users').upsert({
      'id': uid,
      'role': 'user',
      'display_name': displayName,
      'email': email.trim(),
      'student_id': studentId,
      'program': course,
      'onboarding_complete': false,
      'tracer_profile_completion': 0,
      'tracer_profile_complete': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
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

  /// Creates the Auth user (or recovers an orphan Auth row with no profile),
  /// then signs in and upserts the alumni profile.
  Future<User?> registerWithEmailPassword(
    String email,
    String password,
    String fullName,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final invoke = await _supabase.functions.invoke(
        'register-account',
        body: {
          'email': normalizedEmail,
          'password': password,
          'displayName': fullName,
        },
      );

      final data = invoke.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      if (invoke.status >= 400) {
        final message = data is Map && data['error'] != null
            ? data['error'].toString()
            : 'Account creation failed.';
        throw Exception(message);
      }

      final response = await _supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = response.user ?? AppSession.currentUser;
      if (user == null) {
        throw Exception('Account creation failed.');
      }

      await createAlumniUserProfile(
        uid: user.id,
        displayName: fullName,
        email: normalizedEmail,
        studentId: '',
        course: '',
      );
      return user;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      throw Exception(
        e.reasonPhrase?.isNotEmpty == true
            ? e.reasonPhrase!
            : 'Account creation failed.',
      );
    } on AuthException catch (e) {
      throw Exception(_handleAuthException(e));
    }
  }

  Future<void> logout() async {
    AppImage.clearDecodedCache();
    await _supabase.auth.signOut();
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

      if (existing == null) {
        await _supabase.auth.signOut();
        throw Exception(
          'This account is no longer registered in AESS. '
          'Please register again from the alumni directory roster.',
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
