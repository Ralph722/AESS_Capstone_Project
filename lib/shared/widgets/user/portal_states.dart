import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// User-facing empty / error / network helpers for the alumni portal.

String portalFriendlyError(Object? error) {
  // Prefer explicit, already-safe messages from our own ArgumentError/StateError.
  if (error is ArgumentError) {
    final msg = error.message?.toString().trim() ?? '';
    if (msg.isNotEmpty && msg.length <= 160 && !_looksTechnical(msg)) {
      return msg;
    }
  }
  if (error is StateError) {
    final msg = error.message.trim();
    if (msg.isNotEmpty && msg.length <= 160 && !_looksTechnical(msg)) {
      return msg;
    }
  }

  final raw = error?.toString() ?? '';
  final s = raw.toLowerCase();
  if (s.contains('socket') ||
      s.contains('failed host') ||
      s.contains('network') ||
      s.contains('failed to fetch') ||
      s.contains('clientexception') ||
      s.contains('timeout') ||
      s.contains('connection')) {
    return 'Connection problem. Check your internet and try again.';
  }
  if (s.contains('permission') || s.contains('row-level') || s.contains('42501')) {
    return 'You do not have permission to do that.';
  }
  if (s.contains('jwt') ||
      s.contains('not signed in') ||
      (s.contains('auth') && s.contains('session')) ||
      s.contains('session expired')) {
    return 'Your session expired. Please sign in again.';
  }
  if (s.contains('storageexception') ||
      s.contains('payload too large') ||
      s.contains('entity too large') ||
      s.contains('exceeds maximum upload')) {
    return 'Could not upload that image. Try a smaller photo.';
  }
  // Avoid dumping PostgREST / stack traces to alumni.
  if (raw.contains('Postgrest') ||
      raw.contains('Exception:') ||
      _looksTechnical(raw) ||
      RegExp(r'\b\d{5}\b').hasMatch(raw)) {
    return 'Something went wrong. Please try again.';
  }
  if (raw.trim().isEmpty) {
    return 'Something went wrong. Please try again.';
  }
  if (raw.length > 140) {
    return 'Something went wrong. Please try again.';
  }
  return raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
}

bool _looksTechnical(String raw) {
  final s = raw.toLowerCase();
  return s.contains('postgrest') ||
      s.contains('supabase') ||
      s.contains('stack trace') ||
      s.contains('dart:') ||
      s.contains('package:') ||
      RegExp(r'\bPGRST\d+\b', caseSensitive: false).hasMatch(raw);
}

/// Shows a floating danger SnackBar with a [portalFriendlyError] message.
void showPortalErrorSnack(BuildContext context, Object? error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(portalFriendlyError(error)),
        backgroundColor: PortalTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<bool> confirmDiscardChanges(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text(
        'You have unsaved changes. If you leave now, they will be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: PortalTheme.ghostButton(dense: true),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: PortalMenu.dangerButton(dense: true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return result == true;
}

class PortalEmptyState extends StatelessWidget {
  const PortalEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PortalTheme.navy.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: PortalTheme.navy),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: PortalTheme.cardTitle.copyWith(
                fontSize: 18,
                color: PortalTheme.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: PortalTheme.bodySecondary,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: PortalTheme.primaryButton(),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PortalErrorState extends StatelessWidget {
  const PortalErrorState({
    super.key,
    required this.onRetry,
    this.error,
    this.title = 'Something went wrong',
  });

  final Object? error;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    return PortalEmptyState(
      icon: Icons.wifi_off_rounded,
      title: title,
      subtitle: portalFriendlyError(error),
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
