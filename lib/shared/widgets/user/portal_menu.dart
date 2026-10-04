import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Shared look for alumni-portal menus, dropdowns, dialogs and option sheets.
abstract final class PortalMenu {
  static const double itemHeight = 48;
  static const double iconSize = 20;

  static const TextStyle itemText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: PortalTheme.textPrimary,
  );

  static ShapeBorder get menuShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
    side: const BorderSide(color: PortalTheme.border),
  );

  static BorderRadius get dropdownRadius =>
      BorderRadius.circular(PortalTheme.radiusLg);

  static ShapeBorder get dialogShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
  );

  static Color get shadowColor => PortalTheme.navy.withValues(alpha: 0.22);

  /// Confirm button for destructive dialogs (delete, remove, leave…).
  static ButtonStyle dangerButton({bool dense = true}) =>
      PortalTheme.primaryButton(dense: dense).copyWith(
        backgroundColor: const WidgetStatePropertyAll(PortalTheme.danger),
      );
}

/// Row used inside [PopupMenuItem]s and option sheets: optional leading
/// [icon], label, red styling for [destructive] actions and a trailing
/// check for the [selected] choice in single-select lists.
class PortalMenuRow extends StatelessWidget {
  const PortalMenuRow({
    super.key,
    required this.label,
    this.icon,
    this.destructive = false,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? PortalTheme.danger
        : selected
        ? PortalTheme.navy
        : PortalTheme.textPrimary;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: PortalMenu.iconSize,
            color: destructive ? PortalTheme.danger : PortalTheme.navy,
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PortalMenu.itemText.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 12),
          const Icon(Icons.check_rounded, size: 18, color: PortalTheme.navy),
        ],
      ],
    );
  }
}

/// [PopupMenuItem] preset using [PortalMenuRow].
PopupMenuItem<T> portalMenuItem<T>({
  required T value,
  required String label,
  IconData? icon,
  bool destructive = false,
  bool selected = false,
  bool enabled = true,
}) {
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    height: PortalMenu.itemHeight,
    child: PortalMenuRow(
      label: label,
      icon: icon,
      destructive: destructive,
      selected: selected,
    ),
  );
}

/// Tappable option row for bottom sheets, matching popup menu items.
class PortalSheetOption extends StatelessWidget {
  const PortalSheetOption({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: PortalMenuRow(
            label: label,
            icon: icon,
            destructive: destructive,
            selected: selected,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet frame for a short list of options (drag handle, optional
/// title, rounded white card).
class PortalOptionsSheet extends StatelessWidget {
  const PortalOptionsSheet({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PortalTheme.borderStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(title!, style: PortalTheme.pageTitle),
            )
          else
            const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
