enum AiMessageRole { user, assistant }

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
  });

  final AiMessageRole role;
  final String text;
  final bool isError;

  bool get isUser => role == AiMessageRole.user;
}
