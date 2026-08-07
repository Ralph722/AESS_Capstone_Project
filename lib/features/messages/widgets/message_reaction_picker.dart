import 'package:flutter/material.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';

/// Shared reaction picker for alumni + admin message screens.
Future<void> showMessageReactionPicker({
  required BuildContext context,
  required ValueChanged<String> onSelected,
  bool useAdminDialog = false,
}) {
  Widget body(BuildContext ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Reaction',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: MessageTheme.navy,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: MessageTheme.reactionEmojis.map((emoji) {
                return Semantics(
                  button: true,
                  label: 'React with $emoji',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelected(emoji);
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

  if (useAdminDialog) {
    return showAdminDialogSurface<void>(
      context: context,
      maxWidth: 360,
      child: Builder(builder: body),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(child: body(ctx)),
  );
}
