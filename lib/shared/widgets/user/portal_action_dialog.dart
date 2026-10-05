import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Alumni-side choice dialog: title, message, optional body and
/// full-width stacked actions (primary first).
class PortalActionDialog extends StatelessWidget {
  const PortalActionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.actions,
    this.body,
  });

  final String title;
  final String message;
  final Widget? body;
  final List<Widget> actions;

  /// Red outlined style for a destructive secondary action.
  static ButtonStyle dangerOutlinedButton() =>
      PortalTheme.secondaryButton().copyWith(
        foregroundColor: const WidgetStatePropertyAll(PortalTheme.danger),
        side: WidgetStatePropertyAll(
          BorderSide(color: PortalTheme.danger.withValues(alpha: 0.35)),
        ),
      );

  /// Muted text style for the "stay" action.
  static ButtonStyle quietButton() => PortalTheme.ghostButton().copyWith(
    foregroundColor: const WidgetStatePropertyAll(PortalTheme.textSecondary),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: PortalTheme.pageTitle.copyWith(fontSize: 19)),
              const SizedBox(height: 6),
              Text(message, style: PortalTheme.bodySecondary),
              if (body != null) ...[
                const SizedBox(height: 16),
                Flexible(child: body!),
              ],
              const SizedBox(height: 22),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                actions[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
