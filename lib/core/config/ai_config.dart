/// AI features in the app.
///
/// The Gemini key lives only in the secrets of the `ai-assist` Edge
/// Function; the app never holds it. Build with
/// `--dart-define=AI_ENABLED=false` to hide AI features entirely.
class AiConfig {
  AiConfig._();

  static const functionName = 'ai-assist';

  static const bool isEnabled = bool.fromEnvironment(
    'AI_ENABLED',
    defaultValue: true,
  );
}
