/// Helpers for admin inbox conversation watch lifecycle.
///
/// Selection updates [_selectedUserId] before the watch starts, so "already
/// watching" must compare against the id bound to the active subscription —
/// not the newly selected id.
bool isAlreadyWatchingAdminConversation({
  required bool hasActiveSubscription,
  required String? watchingMessagingId,
  required String requestedMessagingId,
  String? watchingDocId,
  String? requestedDocId,
}) {
  if (!hasActiveSubscription) return false;
  if (watchingMessagingId != requestedMessagingId) return false;
  if (requestedDocId == null || requestedDocId.isEmpty) return true;
  return watchingDocId == requestedDocId;
}

/// Whether a realtime emit still belongs to the conversation the admin has open.
bool isAdminConversationEmitStillSelected({
  required String? selectedMessagingId,
  required String emitMessagingId,
  String? selectedDocId,
  String? emitDocId,
}) {
  if (selectedMessagingId == emitMessagingId) return true;
  if (emitDocId != null &&
      emitDocId.isNotEmpty &&
      selectedDocId != null &&
      selectedDocId.isNotEmpty &&
      selectedDocId == emitDocId) {
    return true;
  }
  return false;
}
