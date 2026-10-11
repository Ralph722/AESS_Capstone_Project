import 'package:flutter/material.dart';
import 'package:alumni_system/features/auth/data/password_policy.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Four-segment strength bar with a text label, so strength is never shown
/// by colour alone.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.strength});

  final PasswordStrength strength;

  Color get _color => switch (strength) {
    PasswordStrength.weak => PortalTheme.danger,
    PasswordStrength.fair => PortalTheme.warning,
    PasswordStrength.good => PortalTheme.navyMid,
    PasswordStrength.strong => PortalTheme.success,
  };

  @override
  Widget build(BuildContext context) {
    final filled = strength.index + 1;
    return Semantics(
      label: 'Password strength: ${strength.label}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < PasswordStrength.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < filled ? _color : PortalTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          const SizedBox(width: PortalTheme.space2),
          Text(
            'Strength: ${strength.label}',
            style: PortalTheme.caption.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
