import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Dashboard card with a section title, optional icon and trailing action.
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
    this.accent,
    this.expandBody = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  /// Shows [icon] in a tinted chip instead of plain grey.
  final AdminAccent? accent;

  /// Body fills the remaining height; the panel needs bounded height.
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    const bodyPad = EdgeInsets.fromLTRB(16, 0, 16, 14);
    return Container(
      decoration: AdminSurfaces.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  if (icon != null && accent != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent!.tint,
                        borderRadius: BorderRadius.circular(
                          AdminSurfaces.radiusSm,
                        ),
                        border: Border.all(
                          color: accent!.color.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, size: 15, color: accent!.onTint),
                    ),
                    const SizedBox(width: 10),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 18, color: AdminColors.textSecondary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: AdminText.sectionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
          if (expandBody)
            Expanded(
              child: Padding(padding: bodyPad, child: child),
            )
          else
            Padding(padding: bodyPad, child: child),
        ],
      ),
    );
  }
}

/// "View all" link in a panel header; [semanticsLabel] names the destination.
class DashboardViewAllButton extends StatelessWidget {
  const DashboardViewAllButton({
    super.key,
    required this.onPressed,
    required this.semanticsLabel,
  });

  final VoidCallback onPressed;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        ),
      ),
      child: Text(
        'View all',
        semanticsLabel: semanticsLabel,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Tappable label/value tile used in the dashboard summary cards.
class DashboardStatTile extends StatelessWidget {
  const DashboardStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.showIcon = true,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  /// Tints the tile and colours its icon.
  final AdminAccent? accent;

  /// Hidden in narrow cells so the label is not truncated.
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: accent?.tint ?? AdminColors.background,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          hoverColor: AdminColors.primary.withValues(alpha: 0.05),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              border: Border.all(
                color: accent != null
                    ? accent!.color.withValues(alpha: 0.16)
                    : AdminColors.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (showIcon) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: accent?.onTint ?? AdminColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.body,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Live" badge for the dashboard header; the figures refresh on their own.
class DashboardLiveIndicator extends StatelessWidget {
  const DashboardLiveIndicator({super.key, this.updatedAt});

  /// When the figures last finished loading; shown in the tooltip.
  final DateTime? updatedAt;

  @visibleForTesting
  static String message(DateTime? updatedAt) {
    const base = 'Figures update automatically.';
    if (updatedAt == null) return base;
    return '$base Last updated ${DateFormat('h:mm a').format(updatedAt)}.';
  }

  @override
  Widget build(BuildContext context) {
    final text = message(updatedAt);
    return Tooltip(
      message: text,
      child: Semantics(
        label: 'Live. $text',
        child: ExcludeSemantics(
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AdminColors.successBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AdminColors.success.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AdminColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 7, height: 7),
                ),
                SizedBox(width: 6),
                Text(
                  'Live',
                  style: TextStyle(
                    color: AdminColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
