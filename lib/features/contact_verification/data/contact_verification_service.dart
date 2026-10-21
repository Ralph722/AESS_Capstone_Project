import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A contact detail that needs a one-time code before it is saved.
enum ContactChannel {
  email('email'),
  mobile('mobile');

  const ContactChannel(this.wire);

  /// Value sent to the `contact-verify` Edge Function and the database.
  final String wire;
}

/// Same rules as `public.contact_normalize_target` in the database.
abstract final class ContactNormalizer {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phMobile = RegExp(r'^09\d{9}$');
  static final _intlMobile = RegExp(r'^\+[1-9]\d{7,14}$');

  /// The stored form of [value], or null when it is not valid.
  static String? normalize(ContactChannel channel, String? value) {
    var v = (value ?? '').trim();
    switch (channel) {
      case ContactChannel.email:
        v = v.toLowerCase();
        if (v.length > 254 || !_email.hasMatch(v)) return null;
        return v;
      case ContactChannel.mobile:
        v = v.replaceAll(RegExp(r'[\s().-]'), '');
        if (RegExp(r'^\+63\d{10}$').hasMatch(v)) {
          v = '0${v.substring(3)}';
        } else if (RegExp(r'^63\d{10}$').hasMatch(v)) {
          v = '0${v.substring(2)}';
        } else if (RegExp(r'^9\d{9}$').hasMatch(v)) {
          v = '0$v';
        }
        if (_phMobile.hasMatch(v) || _intlMobile.hasMatch(v)) return v;
        return null;
    }
  }

  /// Whether [a] and [b] are the same contact, ignoring formatting.
  static bool same(ContactChannel channel, String? a, String? b) {
    final na = normalize(channel, a);
    final nb = normalize(channel, b);
    if (na != null && nb != null) return na == nb;
    String loose(String? v) {
      final t = (v ?? '').trim();
      return channel == ContactChannel.email ? t.toLowerCase() : t;
    }

    return loose(a) == loose(b);
  }

  static String invalidMessage(ContactChannel channel) => switch (channel) {
    ContactChannel.email => 'Enter a valid email address.',
    ContactChannel.mobile =>
      'Enter a valid mobile number, like 09171234567 or +14155550123.',
  };
}

/// A code was sent (or, for mock SMS, created and returned as [demoCode]).
class ContactCodeSent {
  const ContactCodeSent({
    required this.target,
    required this.resendAfterSeconds,
    this.demoCode,
  });

  /// The contact as the server stores it.
  final String target;
  final int resendAfterSeconds;

  /// Only while SMS is not integrated: the code to show in the app.
  final String? demoCode;

  bool get isDemo => demoCode != null;

  factory ContactCodeSent.fromJson(
    Map<String, dynamic> json,
    String fallback, {
    /// Release builds ignore [demoCode] even if a misconfigured server sends it.
    bool allowDemoCode = !kReleaseMode,
  }) {
    final demo = json['demoCode']?.toString();
    final raw = (demo == null || demo.isEmpty) ? null : demo;
    return ContactCodeSent(
      target: (json['target'] ?? fallback).toString(),
      resendAfterSeconds: (json['resendAfter'] as num?)?.toInt() ?? 60,
      demoCode: allowDemoCode ? raw : null,
    );
  }
}

/// Result of saving a verified contact.
class ContactSaveResult {
  const ContactSaveResult({
    required this.target,
    this.loginChanged = false,
    this.previousEmail,
  });

  final String target;

  /// True when [target] also became the Auth sign-in email.
  final bool loginChanged;

  final String? previousEmail;
}

/// User-facing failure (message is ready to show).
class ContactVerificationException implements Exception {
  const ContactVerificationException(
    this.message, {
    this.retryAfterSeconds,
    this.needsPassword = false,
  });

  final String message;

  /// Set when the server asked the user to wait before another code.
  final int? retryAfterSeconds;

  /// True when the user must re-enter their password before saving an email.
  final bool needsPassword;

  @override
  String toString() => message;
}

/// Sends and checks contact codes (`contact-verify`). Mobile is saved with
/// `apply_verified_contact`; email is saved with `apply_email` (becomes the
/// login email).
class ContactVerificationService {
  ContactVerificationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const codeLength = 6;

  /// Password must be re-entered when the last sign-in was over this long ago.
  static const reauthAfter = Duration(hours: 24);

  Future<ContactCodeSent> sendCode(
    ContactChannel channel,
    String target,
  ) async {
    final data = await _invoke(channel, {
      'action': 'send',
      'channel': channel.wire,
      'target': target.trim(),
    });
    return ContactCodeSent.fromJson(data, target.trim());
  }

  /// Returns the verified contact as the server stores it.
  Future<String> verifyCode(
    ContactChannel channel,
    String target,
    String code,
  ) async {
    final data = await _invoke(channel, {
      'action': 'verify',
      'channel': channel.wire,
      'target': target.trim(),
      'code': code.trim(),
    });
    return (data['target'] ?? target.trim()).toString();
  }

  /// Whether [applyEmail] needs the current password first.
  bool needsPasswordRecheck() {
    final at = _client.auth.currentUser?.lastSignInAt;
    if (at == null || at.isEmpty) return true;
    final parsed = DateTime.tryParse(at)?.toUtc();
    if (parsed == null) return true;
    return DateTime.now().toUtc().difference(parsed) > reauthAfter;
  }

  /// Re-checks the current password so [applyEmail] sees a recent sign-in.
  Future<void> confirmPassword(String password) async {
    final email = _client.auth.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) {
      throw const ContactVerificationException('Please sign in again.');
    }
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw const ContactVerificationException(
          'That password is not correct.',
        );
      }
    } on ContactVerificationException {
      rethrow;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid') || m.contains('credentials')) {
        throw const ContactVerificationException(
          'That password is not correct.',
        );
      }
      throw ContactVerificationException(
        e.message.trim().isEmpty
            ? 'Could not confirm your password. Please try again.'
            : e.message,
      );
    } catch (_) {
      throw const ContactVerificationException(
        "Couldn't reach the server. Check your connection and try again.",
      );
    }
  }

  /// Saves a verified contact. Email goes through `apply_email` (login email
  /// changes too). Pass [password] when [needsPasswordRecheck] is true.
  Future<ContactSaveResult> saveVerified(
    ContactChannel channel,
    String target, {
    String? password,
  }) async {
    if (channel == ContactChannel.email) {
      if (needsPasswordRecheck()) {
        final p = password?.trim() ?? '';
        if (p.isEmpty) {
          throw const ContactVerificationException(
            'Confirm your password to change your sign-in email.',
            needsPassword: true,
          );
        }
        await confirmPassword(p);
      }
      return applyEmail(target);
    }

    try {
      await _client.rpc(
        'apply_verified_contact',
        params: {'p_channel': channel.wire, 'p_target': target},
      );
      return ContactSaveResult(target: target);
    } on PostgrestException catch (e) {
      throw ContactVerificationException(
        e.message.contains('not been verified')
            ? 'Your verification has expired. Please verify '
                  '${_label(channel)} again.'
            : "Couldn't save ${_label(channel)}. Please try again.",
      );
    } catch (_) {
      throw const ContactVerificationException(
        "Couldn't reach the server. Check your connection and try again.",
      );
    }
  }

  /// Applies a verified email as the contact and login email, then refreshes
  /// the session so [AppSession.email] matches.
  Future<ContactSaveResult> applyEmail(String target) async {
    final data = await _invoke(ContactChannel.email, {
      'action': 'apply_email',
      'target': target.trim(),
    });
    final saved = (data['target'] ?? target.trim()).toString();
    final loginChanged = data['loginChanged'] == true;
    final previous = data['previousEmail']?.toString();
    try {
      await _client.auth.refreshSession();
    } catch (_) {
      // The save already succeeded; the next navigation will pick up email.
    }
    return ContactSaveResult(
      target: saved,
      loginChanged: loginChanged,
      previousEmail: previous == null || previous.isEmpty ? null : previous,
    );
  }

  Future<Map<String, dynamic>> _invoke(
    ContactChannel channel,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.functions.invoke('contact-verify', body: body);
      final data = res.data;
      if (res.status >= 400 || data is! Map) {
        throw errorFor(channel, res.status, data);
      }
      return Map<String, dynamic>.from(data);
    } on FunctionException catch (e) {
      throw errorFor(channel, e.status, e.details);
    } on ContactVerificationException {
      rethrow;
    } catch (_) {
      throw const ContactVerificationException(
        "Couldn't reach the server. Check your connection and try again.",
      );
    }
  }

  static String _label(ContactChannel channel) => switch (channel) {
    ContactChannel.email => 'your email address',
    ContactChannel.mobile => 'your mobile number',
  };

  /// Maps a `contact-verify` error response to a message.
  static ContactVerificationException errorFor(
    ContactChannel channel,
    int status,
    dynamic details,
  ) {
    final map = details is Map ? details : const {};
    final code = map['error']?.toString() ?? '';
    final retryAfter = (map['retryAfter'] as num?)?.toInt();
    final attemptsLeft = (map['attemptsLeft'] as num?)?.toInt();
    final message = switch (code) {
      'invalid_target' => ContactNormalizer.invalidMessage(channel),
      'cooldown' =>
        'Please wait ${retryAfter ?? 60} seconds before asking for another '
            'code.',
      'too_many_requests' =>
        "You've asked for too many codes. Try again in about "
            '${((retryAfter ?? 3600) / 60).ceil()} minutes.',
      'email_failed' =>
        "We couldn't send the email. Check the address and try again.",
      'email_in_use' =>
        'That email is already used by another account. '
            'Try a different address.',
      'sms_unavailable' => 'Text message codes are not available yet.',
      'wrong_code' =>
        attemptsLeft == null
            ? "That code isn't right."
            : "That code isn't right. $attemptsLeft "
                  '${attemptsLeft == 1 ? 'try' : 'tries'} left.',
      'expired' => 'This code has expired. Ask for a new one.',
      'too_many_attempts' => 'Too many wrong tries. Ask for a new code.',
      'not_found' => 'Ask for a code first.',
      'not_verified' =>
        'Your verification has expired. Please verify '
            '${_label(channel)} again.',
      'reauth_required' =>
        'Confirm your password to change your sign-in email.',
      'login_email_failed' ||
      'apply_failed' => "Couldn't update your sign-in email. Please try again.",
      'invalid_code' => 'Enter the $codeLength-digit code.',
      'not_signed_in' || 'inactive_account' => 'Please sign in again.',
      _ => 'Something went wrong. Please try again in a moment.',
    };
    return ContactVerificationException(
      message,
      retryAfterSeconds: code == 'cooldown' ? retryAfter : null,
      needsPassword: code == 'reauth_required',
    );
  }
}
