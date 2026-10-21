import 'package:flutter/material.dart';
import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Shared edit / delete / react actions for message screens (Part 11).
abstract final class MessageActions {
  static Future<void> editOwnMessage({
    required BuildContext context,
    required MessageService service,
    required Map<String, dynamic> message,
    required bool isOwner,
    bool showSuccessSnack = false,
  }) async {
    if (!isOwner) return;

    final controller = TextEditingController(
      text: message['messageText'] as String? ?? '',
    );

    try {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Edit message'),
              content: TextField(
                controller: controller,
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Edit your message…',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: PortalTheme.ghostButton(dense: true),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: PortalTheme.primaryButton(dense: true),
                  child: const Text('Save'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;
      final newText = controller.text.trim();
      if (newText.isEmpty || newText == message['messageText']) return;

      final docId = message['docId'] as String?;
      if (docId == null) return;

      try {
        await service.updateMessage(docId, newText);
        if (showSuccessSnack && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  static Future<void> deleteOwnMessage({
    required BuildContext context,
    required MessageService service,
    required Map<String, dynamic> message,
    required bool isOwner,
    bool showSuccessSnack = false,
  }) async {
    if (!isOwner) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete message?'),
            content: const Text(
              'Are you sure you want to delete this message? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: PortalTheme.ghostButton(dense: true),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: PortalMenu.dangerButton(dense: true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final docId = message['docId'] as String?;
    if (docId == null) return;

    try {
      await service.deleteMessage(docId);
      if (showSuccessSnack && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Computes the reactions map after toggling [emoji] for [actorUserId].
  static Map<String, dynamic> reactionsAfterToggle({
    required Map<String, dynamic> current,
    required String actorUserId,
    required String emoji,
  }) {
    final reactions = <String, dynamic>{};
    for (final entry in current.entries) {
      final list = entry.value;
      reactions[entry.key] = List<String>.from(
        list is List ? list.map((e) => e.toString()) : const <String>[],
      );
    }
    final usersList = List<String>.from(
      (reactions[emoji] as List?)?.map((e) => e.toString()) ?? const <String>[],
    );
    if (usersList.contains(actorUserId)) {
      usersList.remove(actorUserId);
      if (usersList.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = usersList;
      }
    } else {
      usersList.add(actorUserId);
      reactions[emoji] = usersList;
    }
    return reactions;
  }

  static Future<void> toggleReaction({
    required BuildContext context,
    required MessageService service,
    required String messageId,
    required String actorUserId,
    required String emoji,
    Map<String, dynamic>? currentReactions,
    void Function(Map<String, dynamic> reactions)? onOptimistic,
  }) async {
    Map<String, dynamic>? previousCopy;
    if (currentReactions != null) {
      previousCopy = <String, dynamic>{};
      for (final entry in currentReactions.entries) {
        final list = entry.value;
        previousCopy[entry.key] = List<String>.from(
          list is List ? list.map((e) => e.toString()) : const <String>[],
        );
      }
    }
    final next = previousCopy == null
        ? null
        : reactionsAfterToggle(
            current: previousCopy,
            actorUserId: actorUserId,
            emoji: emoji,
          );
    if (next != null) onOptimistic?.call(next);
    try {
      if (next != null) {
        await service.applyReactions(messageId: messageId, reactions: next);
      } else {
        await service.toggleReaction(
          messageId: messageId,
          actorUserId: actorUserId,
          emoji: emoji,
        );
      }
    } catch (e) {
      if (previousCopy != null) onOptimistic?.call(previousCopy);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding reaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
