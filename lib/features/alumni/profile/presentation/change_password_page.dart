import 'package:flutter/material.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/features/auth/presentation/widgets/change_password_form.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Profile → Change password. Only reachable from the signed-in shell.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  static const double _formMaxWidth = 560;

  void _onSuccess(BuildContext context, bool othersSignedOut) {
    showAuthFeedback(
      context,
      othersSignedOut
          ? 'Password changed successfully. Other devices have been signed out.'
          : 'Password changed successfully.',
      error: false,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: const PortalAppBar(title: 'Change password'),
      body: PortalContentFrame(
        maxWidth: _formMaxWidth,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Security',
                      style: PortalTheme.cardTitle.copyWith(
                        color: PortalTheme.navy,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Keep your account secure by using a strong password '
                    "that you don't use elsewhere.",
                    style: PortalTheme.meta.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(PortalTheme.space3),
              decoration: BoxDecoration(
                color: PortalTheme.card,
                borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
                border: Border.all(
                  color: PortalTheme.border.withValues(alpha: 0.75),
                ),
              ),
              child: ChangePasswordForm(
                role: UserRole.user,
                onSuccess: (othersSignedOut) =>
                    _onSuccess(context, othersSignedOut),
                onCancel: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
