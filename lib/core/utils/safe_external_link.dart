import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Detects http(s) URLs in plain text.
final RegExp kHttpUrlPattern = RegExp(
  r'(https?:\/\/[^\s<>"{}|\\^`\[\]]+)',
  caseSensitive: false,
);

/// Returns true when [raw] is an allowed external web URL.
bool isSafeExternalHttpUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.trim().isEmpty) return false;
  return true;
}

/// Trims common trailing punctuation accidentally captured with a URL.
String sanitizeCapturedUrl(String raw) {
  var url = raw.trim();
  while (url.isNotEmpty && '.,;:!?)】」』>'.contains(url[url.length - 1])) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// Shows a confirmation dialog, then opens the URL externally if confirmed.
Future<void> openExternalLinkSafely(
  BuildContext context, {
  required String url,
}) async {
  final cleaned = sanitizeCapturedUrl(url);
  if (!isSafeExternalHttpUrl(cleaned)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This link cannot be opened.')),
    );
    return;
  }

  final uri = Uri.parse(cleaned);
  final host = uri.host;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
      ),
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
                      color: PortalTheme.sky.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      size: 20,
                      color: PortalTheme.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Open external link?',
                      style: PortalTheme.pageTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'This opens a website outside the Alumni Portal. '
                'Continue only if you trust the destination.',
                style: PortalTheme.bodySecondary.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PortalTheme.pageBg,
                  borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                  border: Border.all(color: PortalTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host,
                      style: PortalTheme.cardTitle.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      cleaned,
                      style: PortalTheme.caption.copyWith(
                        color: PortalTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: PortalTheme.ghostButton(dense: true),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: PortalTheme.primaryButton(dense: true),
                    child: const Text('Open link'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this link.')),
    );
  }
}
