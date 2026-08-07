import 'package:flutter/material.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';

/// Accessibility helpers for the Messages module (Part 9).
abstract final class MessageA11y {
  /// Screen-reader label for a chat bubble.
  static String bubbleLabel({
    required bool isMine,
    required String body,
    required DateTime timestamp,
    required bool peerIsOffice,
    String? imageUrl,
    bool isEdited = false,
    String? receiptLabel,
  }) {
    final who = isMine
        ? 'You'
        : (peerIsOffice ? 'Alumni Office' : 'Alumni');
    final time = formatMessageClockTime(timestamp);
    final parts = <String>[
      '$who, $time',
      if (imageUrl != null && imageUrl.isNotEmpty) 'Image attached',
      if (body.trim().isNotEmpty) body.trim(),
      if (isEdited) 'Edited',
      if (receiptLabel != null && receiptLabel.isNotEmpty) receiptLabel,
    ];
    return parts.join('. ');
  }

  static String conversationTileLabel({
    required String name,
    required String lastMessage,
    required bool unread,
    String? program,
    String? batch,
    String? relativeTime,
  }) {
    final meta = [
      if (program != null && program.isNotEmpty) program,
      if (batch != null && batch.isNotEmpty) batch,
    ].join(', ');
    return [
      name,
      if (meta.isNotEmpty) meta,
      if (relativeTime != null && relativeTime.isNotEmpty) relativeTime,
      if (lastMessage.isNotEmpty) lastMessage else 'No messages yet',
      if (unread) 'Unread',
    ].join('. ');
  }

  /// Stronger borders when system high-contrast is on.
  static Color border(BuildContext context) {
    if (MediaQuery.highContrastOf(context)) {
      return const Color(0xFF000000);
    }
    return MessageTheme.border;
  }

  static Color textPrimary(BuildContext context) {
    if (MediaQuery.highContrastOf(context)) {
      return const Color(0xFF000000);
    }
    return MessageTheme.textPrimary;
  }
}
