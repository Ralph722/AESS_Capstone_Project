import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Reusable admin share sheet: canonical URL, copy, and native share.
/// On web, `share_plus` uses the Web Share API where available and
/// throws otherwise — the copy action is always offered as fallback.
Future<void> showShareLinkSheet(
  BuildContext context,
  ShareableContent content,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AdminColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AdminSurfaces.radiusLg),
      ),
    ),
    builder: (_) => _ShareLinkSheet(content: content),
  );
}

class _ShareLinkSheet extends StatelessWidget {
  const _ShareLinkSheet({required this.content});

  final ShareableContent content;

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: content.canonicalUrl));
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied. You can now share it with alumni.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not copy automatically. Long-press the link to copy it.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareNative(BuildContext context) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: content.shareText,
          subject: content.title,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      // Unsupported (e.g. browser without Web Share): fall back to copy.
      if (context.mounted) await _copy(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: AdminColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Share link',
                    style: AdminText.sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              content.title,
              style: AdminText.body.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${content.statusLabel} · ${content.audienceLabel}',
              style: AdminText.caption,
            ),
            const SizedBox(height: 16),
            if (!content.isShareable)
              Text(
                content.unavailableReason ??
                    'This content cannot be shared yet.',
                style: AdminText.body.copyWith(color: AdminColors.warning),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.background,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  border: Border.all(color: AdminColors.border),
                ),
                child: SelectableText(
                  content.canonicalUrl,
                  style: AdminText.body.copyWith(color: AdminColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(context),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Copy link'),
                      style: AdminButtonStyles.outlined(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _shareNative(context),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share…'),
                      style: AdminButtonStyles.filled(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
