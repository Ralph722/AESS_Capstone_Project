import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of the `tracer-help` Edge Function for CHED GTS Q19/Q20.
class ChedGtsHelpSuggestion {
  const ChedGtsHelpSuggestion({
    required this.unclear,
    required this.occupation,
    required this.lineOfBusiness,
    required this.specifyText,
    required this.reason,
    required this.remaining,
  });

  /// The description didn't read as a job; nothing to suggest.
  final bool unclear;
  final String occupation;

  /// One of the official Q20 options, or null.
  final String? lineOfBusiness;

  /// Text for Q20 "Others, please specify" (only when that option is chosen).
  final String specifyText;
  final String reason;

  /// Help requests left today.
  final int? remaining;

  factory ChedGtsHelpSuggestion.fromJson(Map<String, dynamic> json) {
    String str(String key) => (json[key] ?? '').toString().trim();
    final line = str('lineOfBusiness');
    return ChedGtsHelpSuggestion(
      unclear: json['unclear'] == true,
      occupation: str('occupation'),
      lineOfBusiness: line.isEmpty ? null : line,
      specifyText: str('specifyText'),
      reason: str('reason'),
      remaining: (json['remaining'] as num?)?.toInt(),
    );
  }
}

/// User-facing failure from the helper (message is ready to show).
class ChedGtsHelpException implements Exception {
  const ChedGtsHelpException(this.message, {this.remaining});
  final String message;
  final int? remaining;

  @override
  String toString() => message;
}

class ChedGtsHelpService {
  ChedGtsHelpService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const maxInput = 300;
  static const dailyLimit = 20;

  Future<ChedGtsHelpSuggestion> suggest({
    required String surveyId,
    required String description,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'tracer-help',
        body: {'surveyId': surveyId, 'description': description.trim()},
      );
      final data = res.data;
      if (res.status >= 400 || data is! Map) {
        throw _fromError(res.status, data);
      }
      return ChedGtsHelpSuggestion.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (e) {
      throw _fromError(e.status, e.details);
    } on ChedGtsHelpException {
      rethrow;
    } catch (_) {
      throw const ChedGtsHelpException(
        "Couldn't reach the helper. Check your connection and try again.",
      );
    }
  }

  ChedGtsHelpException _fromError(int status, dynamic details) {
    final map = details is Map ? details : const {};
    final code = map['error']?.toString() ?? '';
    final remaining = (map['remaining'] as num?)?.toInt();
    final message = switch (code) {
      'limit_reached' =>
        "You've used all $dailyLimit helps for today. The notes under each "
            'question can still guide you, or try again tomorrow.',
      'disabled' => 'The answer helper is turned off for this survey.',
      'not_available' => 'The answer helper is not available for this survey.',
      'not_signed_in' => 'Please sign in again to use the answer helper.',
      'too_long' => 'Please keep your description under $maxInput characters.',
      'invalid_input' => 'Please describe your job in a few words first.',
      'ai_unavailable' =>
        'The helper is busy right now. Please try again in a moment, or use '
            'the notes under each question.',
      _ =>
        status == 429
            ? "You've used all $dailyLimit helps for today."
            : 'Something went wrong. Please try again in a moment.',
    };
    return ChedGtsHelpException(message, remaining: remaining);
  }
}
