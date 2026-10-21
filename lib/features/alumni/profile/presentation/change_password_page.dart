import 'package:flutter/material.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/features/auth/presentation/widgets/change_password_form.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Opens Change password as a modal dialog from Profile.
/// Shows a success snack after a completed change.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final othersSignedOut = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Change password',
    builder: (_) => const _ChangePasswordDialog(),
  );
  if (!context.mounted || othersSignedOut == null) return;
  showAuthFeedback(
    context,
    othersSignedOut
        ? 'Password changed successfully. Other devices have been signed out.'
        : 'Password changed successfully.',
    error: false,
  );
}

/// Pops with whether other devices were signed out, or null when cancelled.
class _ChangePasswordDialog extends StatelessWidget {
  const _ChangePasswordDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PortalTheme.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Change password',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PortalTheme.navy,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep your account secure by using a strong password '
                "that you don't use elsewhere.",
                style: PortalTheme.meta.copyWith(height: 1.4),
              ),
              const SizedBox(height: PortalTheme.space4),
              ChangePasswordForm(
                role: UserRole.user,
                autofocus: true,
                onSuccess: (othersSignedOut) =>
                    Navigator.of(context).pop(othersSignedOut),
                onCancel: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
