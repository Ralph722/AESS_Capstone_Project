import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_token.dart';

/// Outcome of [AlumniCardTokenService.issue] (token or why it failed).
class AlumniCardIssueResult {
  const AlumniCardIssueResult._({this.token, this.error});

  const AlumniCardIssueResult.ok(AlumniCardToken token)
    : this._(token: token);

  const AlumniCardIssueResult.fail(String error) : this._(error: error);

  final AlumniCardToken? token;
  final String? error;

  bool get ok => token != null;
}

/// Issues and verifies short-lived digital alumni card codes via Supabase RPCs.
///
/// Does **not** require Firebase Hosting — only a live Supabase session.
/// Hosting only matters so staff can open the QR URL on their phones.
///
/// Concurrent [issueDetailed] calls share one in-flight RPC and reuse a still-
/// valid cached token so two [AlumniDigitalCard] widgets cannot wipe each
/// other's code (each issue deletes all tokens for that member server-side).
class AlumniCardTokenService {
  AlumniCardTokenService({SupabaseClient? client}) : _clientOrNull = client;

  SupabaseClient? _clientOrNull;

  SupabaseClient get _client => _clientOrNull ??= Supabase.instance.client;

  static AlumniCardToken? _sharedToken;
  static Future<AlumniCardIssueResult>? _sharedInFlight;

  /// Clears the process-local cache (tests / sign-out).
  static void clearSharedCache() {
    _sharedToken = null;
    _sharedInFlight = null;
  }

  /// Issues a 60-second token for the signed-in, roster-matched alumnus.
  Future<AlumniCardToken?> issue() async {
    final result = await issueDetailed();
    return result.token;
  }

  /// Same as [issue], but keeps the RPC error/message for UI diagnostics.
  ///
  /// When [forceRefresh] is true, ignores the process-local cache so a new
  /// server code is minted (e.g. verify face just opened or code nearly expired).
  Future<AlumniCardIssueResult> issueDetailed({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _sharedToken = null;
    } else {
      final cached = _sharedToken;
      if (cached != null &&
          cached.remaining > const Duration(seconds: 2)) {
        return AlumniCardIssueResult.ok(cached);
      }
    }

    final existing = _sharedInFlight;
    if (existing != null) return existing;

    final future = _issueRaw();
    _sharedInFlight = future;
    try {
      final result = await future;
      if (result.token != null) {
        _sharedToken = result.token;
      }
      return result;
    } finally {
      if (identical(_sharedInFlight, future)) {
        _sharedInFlight = null;
      }
    }
  }

  Future<AlumniCardIssueResult> _issueRaw() async {
    try {
      final raw = await _client.rpc('issue_alumni_card_token');
      final data = _asStringKeyedMap(raw);
      if (data == null) {
        return const AlumniCardIssueResult.fail('Unexpected server response.');
      }
      if (data['ok'] != true) {
        final message =
            (data['message'] ?? data['error'] ?? 'Could not issue code.')
                .toString();
        return AlumniCardIssueResult.fail(message);
      }
      final token = AlumniCardToken.fromJson(data);
      if (token.token.isEmpty || token.shortCode.isEmpty) {
        return const AlumniCardIssueResult.fail('Incomplete code from server.');
      }
      return AlumniCardIssueResult.ok(token);
    } catch (e, st) {
      debugPrint('issue_alumni_card_token failed: $e\n$st');
      return const AlumniCardIssueResult.fail(
        'Could not reach the verification service. Check your connection.',
      );
    }
  }

  /// Public verify (no login). Accepts the long QR token, backup code, or a
  /// full `?verify=` URL.
  Future<AlumniCardVerifyResult> verify(String code) async {
    final trimmed = _normalizeVerifyInput(code);
    if (trimmed.isEmpty) return const AlumniCardVerifyResult.notValid();
    try {
      final raw = await _client.rpc(
        'verify_alumni_card',
        params: {'p_code': trimmed},
      );
      final data = _asStringKeyedMap(raw);
      if (data == null) return const AlumniCardVerifyResult.notValid();
      return AlumniCardVerifyResult.fromJson(data);
    } catch (e, st) {
      debugPrint('verify_alumni_card failed: $e\n$st');
      return AlumniCardVerifyResult.notValid(
        message: 'Could not reach the verification service. Try again.',
      );
    }
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// Pulls `verify=` out of a pasted URL; otherwise returns the trimmed code.
  static String _normalizeVerifyInput(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.queryParameters['verify'] != null) {
      return uri.queryParameters['verify']!.trim();
    }
    // Tolerate "…?verify=TOKEN" without a full scheme.
    final match = RegExp(
      r'[?&]verify=([0-9A-Fa-f]+)',
    ).firstMatch(trimmed);
    if (match != null) return match.group(1)!.trim();
    return trimmed;
  }
}
