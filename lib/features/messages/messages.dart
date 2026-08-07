/// Alumni Engagement Support System — Messages module.
///
/// Stable entry points for shells:
/// - [UserMessagesScreen] / [AdminMessagesScreen]
/// - [MessageService] unread APIs (Home + Admin dashboard badges)
/// - [MessageOpenBus] (admin notification deep-link)
///
/// Prefer importing this barrel for new call sites; existing deep imports remain valid.
library;

export 'data/message_service.dart';
export 'data/message_open_bus.dart';
export 'presentation/user_messages_page.dart';
export 'presentation/admin_messages_page.dart';
