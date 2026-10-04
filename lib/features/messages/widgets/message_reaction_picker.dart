import 'package:flutter/material.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

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
                Expanded(
                  child: Text(
                    'Add reaction',
                    style: PortalTheme.cardTitle.copyWith(
                      fontSize: 15,
                      color: PortalTheme.navy,
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
                          color: PortalTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: PortalTheme.border),
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
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PortalTheme.borderStrong,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          body(ctx),
        ],
      ),
    ),
  );
}
