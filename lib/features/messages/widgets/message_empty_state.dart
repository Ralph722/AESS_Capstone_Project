import 'package:flutter/material.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

class MessageEmptyState extends StatelessWidget {
  const MessageEmptyState({super.key, this.compact = false});

  /// Narrower padding for constrained panes.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Need help from the Alumni Office? Send us a message and we will respond as soon as possible.',
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: compact ? 64 : 72,
                  height: compact ? 64 : 72,
                  decoration: BoxDecoration(
                    color: MessageTheme.navy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent_outlined,
                    size: compact ? 32 : 36,
                    color: MessageTheme.navy,
                  ),
                ),
              ),
              const SizedBox(height: AdminDensity.space3),
              const Text(
                'Need help from the Alumni Office?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MessageTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AdminDensity.space1),
              const Text(
                "Send us a message and we'll respond as soon as possible.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MessageTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageDateSeparator extends StatelessWidget {
  const MessageDateSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AdminDensity.space2),
        child: Row(
          children: [
            const Expanded(
              child: Divider(color: MessageTheme.border, height: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: const TextStyle(
                  color: MessageTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: MessageTheme.border, height: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageNewMessagesButton extends StatelessWidget {
  const MessageNewMessagesButton({
    super.key,
    required this.onPressed,
    this.count,
  });

  final VoidCallback onPressed;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final label = (count != null && count! > 1)
        ? '↓  $count new messages'
        : '↓  New messages';
    final semantic = (count != null && count! > 1)
        ? 'Jump to $count new messages'
        : 'Jump to new messages';
    return Semantics(
      button: true,
      label: semantic,
      child: Material(
        elevation: 2,
        color: MessageTheme.navy,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          focusColor: Colors.white.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
