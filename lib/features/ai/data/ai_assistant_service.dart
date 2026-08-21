import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/features/ai/models/ai_chat_message.dart';

class AiNotConfiguredException implements Exception {
  AiNotConfiguredException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Rate limit or billing issue from the Gemini API.
class AiQuotaException implements Exception {
  AiQuotaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiAssistantService {
  Future<String> sendMessage({
    required bool isAdmin,
    required List<AiChatMessage> history,
    required String userMessage,
    String? userDisplayName,
    int maxOutputTokens = 1024,
    double temperature = 0.7,
    String? systemInstructionOverride,
    String? responseMimeType,
  }) async {
    if (!AiConfig.isConfigured) {
      throw AiNotConfiguredException(
        'AI is not configured. Add your Gemini API key in '
        'lib/core/config/ai_secrets.dart '
        '(get one free at aistudio.google.com/apikey).',
      );
    }

    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message cannot be empty');
    }

    final contents = <Map<String, dynamic>>[
      for (final m in history)
        if (!m.isError)
          {
            'role': m.isUser ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          },
      {
        'role': 'user',
        'parts': [
          {'text': trimmed},
        ],
      },
    ];

    final generationConfig = <String, dynamic>{
      'temperature': temperature,
      'maxOutputTokens': maxOutputTokens,
    };
    if (responseMimeType != null && responseMimeType.trim().isNotEmpty) {
      generationConfig['responseMimeType'] = responseMimeType.trim();
    }

    final body = <String, dynamic>{
      'contents': contents,
      'systemInstruction': {
        'parts': [
          {
            'text': systemInstructionOverride ??
                _systemPrompt(
                  isAdmin: isAdmin,
                  userDisplayName: userDisplayName,
                ),
          },
        ],
      },
      'generationConfig': generationConfig,
    };

    Object? lastError;
    for (final model in AiConfig.models) {
      try {
        return await _requestModel(model: model, body: body);
      } catch (e) {
        lastError = e;
        if (e is! AiQuotaException) rethrow;
      }
    }

    throw lastError ??
        AiQuotaException(
          'All AI models are unavailable on your API key. '
          'Check usage at https://aistudio.google.com/apikey or try again later.',
        );
  }

  Future<String> _requestModel({
    required String model,
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      Uri.parse(AiConfig.generateContentUrl(model)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 429 ||
        _isQuotaError(response.statusCode, response.body)) {
      throw AiQuotaException(_friendlyQuotaMessage(response.body));
    }

    if (response.statusCode != 200) {
      final err = _parseError(response.body);
      throw Exception(err ?? 'AI request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from AI');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty AI response');
    }

    // Gemini may split long answers across multiple parts — join them all
    // so section-based responses are never truncated to the first part.
    final text = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
    if (text.trim().isEmpty) {
      throw Exception('Empty AI response');
    }
    return text.trim();
  }

  bool _isQuotaError(int statusCode, String body) {
    if (statusCode == 429) return true;
    final lower = body.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('resource_exhausted') ||
        lower.contains('limit: 0');
  }

  String _friendlyQuotaMessage(String body) {
    final raw = _parseError(body) ?? '';
    if (raw.toLowerCase().contains('quota') ||
        raw.toLowerCase().contains('limit: 0')) {
      return 'Daily free AI quota is used up or this model is not enabled on your key. '
          'Wait a few minutes and try again, or check https://aistudio.google.com/apikey '
          '(create a new key if needed). The app will try alternate models automatically.';
    }
    return 'AI is temporarily busy. Please wait a minute and try again.';
  }

  String? _parseError(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      final error = map['error'] as Map<String, dynamic>?;
      return error?['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _systemPrompt({required bool isAdmin, String? userDisplayName}) {
    final nameLine = userDisplayName != null && userDisplayName.trim().isNotEmpty
        ? 'The user\'s name is ${userDisplayName.trim()}. '
        : '';

    if (isAdmin) {
      return '''
You are the AI assistant for the USTP Alumni Portal **admin dashboard**.
$nameLine
Help administrators with:
- Official alumni roster (import/export, registration filters, employment filters)
- Graduate tracer data (demographics, employment records)
- Tracer surveys (create, publish, assignments, reminders)
- Announcements and forum moderation
- Events, job postings, messages, activity logs, and reports & analytics

Be concise, practical, and step-by-step when explaining how to use the portal.
Do not invent features that do not exist. If unsure, say so.
Never share or ask for passwords. Do not claim you can change Firestore data directly—guide the admin to use the UI.
''';
    }

    return '''
You are the AI assistant for the USTP Alumni Portal **alumni app**.
$nameLine
Help alumni with:
- Updating their tracer profile (Demographics and Employment tabs)
- Completing assigned surveys from Home
- Events, job listings, messages to admin, announcements, and forum
- Profile settings and onboarding

Be friendly, concise, and step-by-step. Use the portal's actual tab names (Home, Events, Messages, Jobs, Tracer, Profile).
Do not invent admin-only features. If something needs admin action, tell them to message admin via Messages.
Never share or ask for passwords.
''';
  }
}
