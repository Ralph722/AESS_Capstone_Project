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
    this.count,
    this.icon,
    this.accent,
    this.expandBody = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  /// Optional count shown as a compact neutral pill before [trailing].
  final int? count;
  final IconData? icon;

  /// Shows [icon] in a tinted chip instead of plain grey.
  final AdminAccent? accent;

  /// Body fills the remaining height; the panel needs bounded height.
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    const bodyPad = EdgeInsets.fromLTRB(16, 0, 16, 14);
    final trailingRow = count == null && trailing == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null) _DashboardCountBadge(count!),
              if (count != null && trailing != null) const SizedBox(width: 6),
              if (trailing != null) trailing!,
            ],
          );
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
                  if (trailingRow != null) trailingRow,
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

class _DashboardCountBadge extends StatelessWidget {
  const _DashboardCountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AdminColors.textSecondary,
          height: 1.2,
        ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View all',
            semanticsLabel: semanticsLabel,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_forward_rounded, size: 14),
        ],
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
    final accent = this.accent;
    final background = accent?.tint ?? AdminColors.background;
    final borderColor = accent == null
        ? AdminColors.border
        : accent.color.withValues(alpha: 0.18);
    final iconBackground = accent == null
        ? AdminColors.primaryTint
        : Colors.white.withValues(alpha: 0.6);
    final iconColor = accent?.onTint ?? AdminColors.primary;

    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          hoverColor: AdminColors.primary.withValues(alpha: 0.05),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                if (showIcon) ...[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 14, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AdminColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                    ],
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
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AdminColors.border, width: 1),
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
