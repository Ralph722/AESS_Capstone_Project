import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/ai/models/ai_chat_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiNotConfiguredException implements Exception {
  AiNotConfiguredException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Daily limit reached, or the AI provider is busy.
class AiQuotaException implements Exception {
  AiQuotaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What the AI is asked to do. The `ai-assist` Edge Function holds the
/// instructions and settings for each task; the app sends only the content.
enum AiTask {
  assistant('assistant'),
  forumModeration('forum_moderation'),
  dssExplain('dss_explain'),
  dssThemes('dss_themes'),
  reportsInsights('reports_insights'),
  surveyReport('survey_report');

  const AiTask(this.wireName);
  final String wireName;
}

/// Sends AI requests through the `ai-assist` Edge Function, which checks the
/// caller, applies the daily limit and calls Gemini with the server-side key.
class AiAssistantService {
  AiAssistantService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<String> sendMessage({
    required AiTask task,
    required String userMessage,
    List<AiChatMessage> history = const [],
  }) async {
    if (!AiConfig.isEnabled) {
      throw AiNotConfiguredException('AI features are turned off in this build.');
    }
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    final FunctionResponse res;
    try {
      res = await _client.functions.invoke(
        AiConfig.functionName,
        body: {
          'task': task.wireName,
          'message': trimmed,
          if (history.isNotEmpty)
            'history': [
              for (final m in history)
                if (!m.isError)
                  {'role': m.isUser ? 'user' : 'model', 'text': m.text},
            ],
        },
      );
    } on FunctionException catch (e) {
      throw errorFor(e.status, e.details);
    } catch (_) {
      throw Exception("Couldn't reach the AI service. Check your connection.");
    }

    final data = res.data;
    if (res.status >= 400 || data is! Map) {
      throw errorFor(res.status, data);
    }
    final text = data['text']?.toString().trim() ?? '';
    if (text.isEmpty) throw Exception('Empty AI response');
    return text;
  }

  /// The exception for an `ai-assist` error response.
  static Exception errorFor(int status, dynamic details) {
    final map = details is Map ? details : const {};
    final code = map['error']?.toString() ?? '';
    return switch (code) {
      'limit_reached' => AiQuotaException(
        "You've used today's AI requests. Please try again tomorrow.",
      ),
      'ai_busy' => AiQuotaException(
        'AI is temporarily busy. Please wait a minute and try again.',
      ),
      'ai_unavailable' || 'server_not_configured' => AiNotConfiguredException(
        'AI is not available right now. Please try again later.',
      ),
      'not_signed_in' => Exception('Please sign in again to use AI.'),
      'not_allowed' => Exception('AI is not available for this account.'),
      'too_long' => Exception('That text is too long for AI.'),
      'invalid_input' => Exception('AI could not read this request.'),
      _ when status == 404 => AiNotConfiguredException(
        'AI is not available right now. Please try again later.',
      ),
      _ => Exception('AI request failed ($status).'),
    };
  }
}
