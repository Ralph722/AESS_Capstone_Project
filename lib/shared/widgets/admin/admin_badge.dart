import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

enum AdminBadgeTone { neutral, info, success, warning, danger }

/// Standard status and indicator badge for tables, cards, and list views.
class AdminBadge extends StatelessWidget {
  const AdminBadge({
    super.key,
    required this.label,
    this.tone = AdminBadgeTone.neutral,
    this.icon,
    this.dot = false,
    this.dense = false,
  });

  const AdminBadge.neutral({
    super.key,
    required this.label,
    this.icon,
    this.dot = false,
    this.dense = false,
  }) : tone = AdminBadgeTone.neutral;

  const AdminBadge.info({
    super.key,
    required this.label,
    this.icon,
    this.dot = false,
    this.dense = false,
  }) : tone = AdminBadgeTone.info;

  const AdminBadge.success({
    super.key,
    required this.label,
    this.icon,
    this.dot = false,
    this.dense = false,
  }) : tone = AdminBadgeTone.success;

  const AdminBadge.warning({
    super.key,
    required this.label,
    this.icon,
    this.dot = false,
    this.dense = false,
  }) : tone = AdminBadgeTone.warning;

  const AdminBadge.danger({
    super.key,
    required this.label,
    this.icon,
    this.dot = false,
    this.dense = false,
  }) : tone = AdminBadgeTone.danger;

  final String label;
  final AdminBadgeTone tone;
  final IconData? icon;
  final bool dot;
  final bool dense;

  Color get _foreground => switch (tone) {
    AdminBadgeTone.neutral => AdminColors.textSecondary,
    AdminBadgeTone.info => AdminColors.info,
    AdminBadgeTone.success => AdminColors.success,
    AdminBadgeTone.warning => AdminColors.warning,
    AdminBadgeTone.danger => AdminColors.danger,
  };

  Color get _background => switch (tone) {
    AdminBadgeTone.neutral => AdminColors.surface,
    AdminBadgeTone.info => AdminColors.infoBg,
    AdminBadgeTone.success => AdminColors.successBg,
    AdminBadgeTone.warning => AdminColors.warningBg,
    AdminBadgeTone.danger => AdminColors.dangerBg,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 3.5,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _foreground.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dot) ...[
            Container(
              width: dense ? 6 : 7,
              height: dense ? 6 : 7,
              decoration: BoxDecoration(
                color: _foreground,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: dense ? 4 : 5),
          ],
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 12, color: _foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: _foreground,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
