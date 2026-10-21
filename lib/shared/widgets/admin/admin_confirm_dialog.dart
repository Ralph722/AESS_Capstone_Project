import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Asks the admin to confirm an action. Resolves to `true` only when the
/// confirm button is pressed; Esc, Cancel and clicking outside give `false`.
///
/// For [destructive] actions the confirm button is red and keyboard focus
/// starts on Cancel.
Future<bool> showAdminConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showAdminDialogSurface<bool>(
    context: context,
    maxWidth: 440,
    child: AdminConfirmDialogBody(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return result ?? false;
}

class AdminConfirmDialogBody extends StatelessWidget {
  const AdminConfirmDialogBody({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AdminColors.danger : AdminColors.primary;
    final accentBg = destructive ? AdminColors.dangerBg : AdminColors.infoBg;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: icon != null ? 7 : 0),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  autofocus: destructive,
                  onPressed: () => Navigator.of(context).pop(false),
                  style: AdminButtonStyles.outlined(),
                  child: Text(cancelLabel),
                ),
                FilledButton(
                  autofocus: !destructive,
                  onPressed: () => Navigator.of(context).pop(true),
                  style: destructive
                      ? AdminButtonStyles.danger()
                      : AdminButtonStyles.filled(),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
