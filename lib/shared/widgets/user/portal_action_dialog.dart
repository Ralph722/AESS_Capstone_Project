import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Alumni-side choice dialog: title, message, optional body and
/// full-width stacked actions (primary first).
///
/// Stays usable above the soft keyboard on phones. [Dialog] already pads by
/// [MediaQuery.viewInsets] — we must not add that inset again, or the card
/// collapses. Height is capped to the remaining space and content scrolls.
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
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final screenH = media.size.height;
    // Do NOT add [keyboard] into insetPadding — Dialog already does
    // `viewInsets + insetPadding`. Adding it again crushed the card on phones.
    final topPad = keyboard > 0 ? 12.0 : 24.0;
    final bottomPad = keyboard > 0 ? 8.0 : 24.0;
    final maxHeight = math
        .min(screenH * 0.88, screenH - keyboard - topPad - bottomPad)
        .clamp(200.0, screenH);

    return Dialog(
      backgroundColor: PortalTheme.card,
      elevation: 8,
      shadowColor: PortalMenu.shadowColor,
      insetPadding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        side: const BorderSide(color: PortalTheme.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: maxHeight,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: PortalTheme.pageTitle.copyWith(fontSize: 19)),
              const SizedBox(height: 6),
              Text(message, style: PortalTheme.bodySecondary),
              if (body != null) ...[
                const SizedBox(height: 14),
                body!,
              ],
              const SizedBox(height: 18),
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
