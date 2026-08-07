import 'dart:async';

/// Opens an admin support conversation by alumni user id.
class MessageOpenBus {
  MessageOpenBus._();

  static final StreamController<String> _controller =
      StreamController<String>.broadcast();

  static String? pendingConversationUserId;

  static Stream<String> get stream => _controller.stream;

  static void openConversation(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    pendingConversationUserId = id;
    if (!_controller.isClosed) _controller.add(id);
  }

  static String? takePending() {
    final id = pendingConversationUserId;
    pendingConversationUserId = null;
    return id;
  }
}
