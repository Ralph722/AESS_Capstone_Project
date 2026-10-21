import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Reusable reference standard for all modal dialogs in the Admin Portal.
///
/// Follows the established Alumni Directory reference design:
/// - Pure white surface (`Colors.white`) with `surfaceTintColor: Colors.transparent`
/// - 16px corner radius with crisp border (`AdminColors.border`)
/// - Soft depth elevation with dark navy shadow
/// - Squircle icon container (38x38) with subtle primary tint
/// - Clean typography hierarchy (Title 17px w700, Subtitle 13px)
/// - Top-right close 'X' button
/// - Standard action button alignment (Cancel/Reset on left, Action on right)
abstract final class AdminDialogStandards {
  static const double radius = 16.0;

  static ShapeBorder get shape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AdminColors.border),
      );

  static const Color backgroundColor = Colors.white;
  static const double elevation = 12.0;

  static const EdgeInsets defaultInsetPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 24,
  );

  static const EdgeInsets defaultContentPadding = EdgeInsets.fromLTRB(
    22,
    20,
    22,
    18,
  );
}

/// Standardized modal header with 38x38 squircle icon, title, subtitle and close button.
class AdminModalHeader extends StatelessWidget {
  const AdminModalHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.iconBackground,
    this.onClose,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackground;
  final VoidCallback? onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AdminColors.primary;
    final effectiveIconBg = iconBackground ?? AdminColors.primaryTint;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: effectiveIconBg,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          ),
          child: Icon(icon, size: 20, color: effectiveIconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdminColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
        if (onClose != null || trailing == null)
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AdminColors.textMuted),
            tooltip: 'Close',
            onPressed: onClose ?? () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}

/// Standardized action footer for modals with Cancel and Action buttons.
class AdminModalFooter extends StatelessWidget {
  const AdminModalFooter({
    super.key,
    this.cancelLabel = 'Cancel',
    this.onCancel,
    required this.confirmLabel,
    required this.onConfirm,
    this.isConfirmDisabled = false,
    this.isConfirmDestructive = false,
    this.isConfirmLoading = false,
    this.leadingAction,
  });

  final String cancelLabel;
  final VoidCallback? onCancel;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool isConfirmDisabled;
  final bool isConfirmDestructive;
  final bool isConfirmLoading;
  final Widget? leadingAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (leadingAction != null) ...[
          leadingAction!,
          const Spacer(),
        ],
        if (onCancel != null)
          TextButton(
            onPressed: onCancel ?? () => Navigator.of(context).pop(),
            child: Text(cancelLabel),
          ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: isConfirmDisabled || isConfirmLoading ? null : onConfirm,
          style: isConfirmDestructive
              ? AdminButtonStyles.danger()
              : AdminButtonStyles.filled(),
          child: isConfirmLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Wraps content in a standardized desktop admin modal dialog container.
class AdminDialogContainer extends StatelessWidget {
  const AdminDialogContainer({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.maxHeight,
    this.padding = AdminDialogStandards.defaultContentPadding,
  });

  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final resolvedMaxHeight = maxHeight ?? size.height * 0.9;

    return Dialog(
      backgroundColor: AdminDialogStandards.backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: AdminDialogStandards.elevation,
      insetPadding: AdminDialogStandards.defaultInsetPadding,
      shape: AdminDialogStandards.shape,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: resolvedMaxHeight,
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
