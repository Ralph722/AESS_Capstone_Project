import 'package:alumni_system/core/config/ai_defaults.dart';

/// Gemini API configuration for the in-app AI assistant.
///
/// 1. Get a free key: https://aistudio.google.com/apikey
/// 2. Paste it in [AiDefaults.apiKey] below, or run with:
///    `--dart-define=GEMINI_API_KEY=your_key_here`
class AiConfig {
  AiConfig._();

  static const String _defineKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static String get apiKey {
    final fromDefine = _defineKey.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    return AiDefaults.apiKey.trim();
  }

  static bool get isConfigured => apiKey.isNotEmpty;

  /// Tried in order — first model with quota on your API key wins.
  /// (gemini-2.0-flash often has limit 0 on new free keys.)
  static const models = [
    'gemini-2.5-flash',
    'gemini-1.5-flash',
    'gemini-2.0-flash-lite',
  ];

  static String generateContentUrl(String model) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
}
