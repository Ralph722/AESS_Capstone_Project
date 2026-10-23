import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Compact SaaS-style page header for Admin Portal screens.
///
/// Minimizes vertical height (~44–48px) by aligning the screen title, optional
/// count badge, optional subtitle, and primary actions into a single horizontal
/// bar on desktop displays.
class AdminCompactHeader extends StatelessWidget {
  const AdminCompactHeader({
    super.key,
    required this.title,
    this.countBadge,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.narrowBreakpoint = 768,
  });

  /// Main page title (e.g. "Alumni Directory").
  final String title;

  /// Optional count or status badge shown next to the title (e.g. "9 alumni", "5 active").
  final String? countBadge;

  /// Optional concise subtitle describing the screen purpose.
  final String? subtitle;

  /// Optional leading widget (e.g. back button or breadcrumb prefix).
  final Widget? leading;

  /// Action buttons aligned to the right (e.g. Export, Add, Create).
  final List<Widget> actions;

  /// Breakpoint below which actions wrap below the title.
  final double narrowBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < narrowBreakpoint;

        final titleRow = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
                height: 1.2,
                letterSpacing: -0.4,
              ),
            ),
            if (countBadge != null && countBadge!.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Text(
                  countBadge!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: subtitle!,
                waitDuration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AdminColors.textMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        );

        final actionRow = actions.isEmpty
            ? null
            : Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
                children: actions,
              );

        if (actionRow == null) {
          return titleRow;
        }

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleRow,
              const SizedBox(height: 8),
              actionRow,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleRow),
            const SizedBox(width: 16),
            actionRow,
          ],
        );
      },
    );
  }
}
