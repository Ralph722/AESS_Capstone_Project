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

  static Future<void> toggleReaction({
    required BuildContext context,
    required MessageService service,
    required String messageId,
    required String actorUserId,
    required String emoji,
  }) async {
    try {
      await service.toggleReaction(
        messageId: messageId,
        actorUserId: actorUserId,
        emoji: emoji,
      );
    } catch (e) {
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
