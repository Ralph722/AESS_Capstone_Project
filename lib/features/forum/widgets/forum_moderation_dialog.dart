import 'package:flutter/material.dart';

import 'package:alumni_system/features/forum/data/forum_content_moderation_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Shows the result of a blocked or warned moderation check. Returns true only
/// when the user chooses to publish a warned post anyway.
Future<bool> showForumModerationResult(
  BuildContext context,
  ForumModerationResult result, {
  required String subject,
}) async {
  if (result.isClean) return true;
  if (result.isBlocked) {
    await showForumModerationDialog(
      context,
      title: 'Content cannot be published',
      message:
          'This $subject appears to contain inappropriate or sensitive '
          'content. Please revise it before posting.',
      reasons: result.reasons,
      allowPublishAnyway: false,
    );
    return false;
  }
  final proceed = await showForumModerationDialog(
    context,
    title: 'Please review before posting',
    message:
        'This $subject may include sensitive content. You can edit it, '
        'or publish anyway if it is appropriate for the alumni community.',
    reasons: result.reasons,
    allowPublishAnyway: true,
  );
  return proceed == true;
}

Future<bool?> showForumModerationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required List<String> reasons,
  required bool allowPublishAnyway,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: allowPublishAnyway
                            ? PortalTheme.gold.withValues(alpha: 0.18)
                            : PortalTheme.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        allowPublishAnyway
                            ? Icons.info_outline_rounded
                            : Icons.shield_outlined,
                        color: allowPublishAnyway
                            ? PortalTheme.navy
                            : PortalTheme.danger,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: PortalTheme.sectionTitle.copyWith(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: PortalTheme.bodySecondary.copyWith(height: 1.4),
                ),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PortalTheme.pageBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PortalTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why this was flagged',
                          style: PortalTheme.caption.copyWith(
                            color: PortalTheme.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final reason in reasons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '•  ',
                                  style: PortalTheme.meta.copyWith(
                                    color: PortalTheme.navy,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: PortalTheme.meta.copyWith(
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: PortalTheme.secondaryButton(dense: true),
                        child: Text(allowPublishAnyway ? 'Edit' : 'OK'),
                      ),
                    ),
                    if (allowPublishAnyway) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: PortalTheme.primaryButton(dense: true),
                          child: const Text('Publish anyway'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
