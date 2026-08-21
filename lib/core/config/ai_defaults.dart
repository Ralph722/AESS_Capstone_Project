import 'package:alumni_system/core/config/ai_secrets.dart';

/// Google Gemini API key for the AI assistant.
///
/// Preferred (local, gitignored): edit [ai_secrets.dart]
/// Or run with: `--dart-define-from-file=config/dart_defines.json`
/// Or: `--dart-define=GEMINI_API_KEY=your_key_here`
///
/// Get a free key at https://aistudio.google.com/apikey
/// Do not commit a real API key to git.
class AiDefaults {
  AiDefaults._();

  static const apiKey = kLocalGeminiApiKey;
}
