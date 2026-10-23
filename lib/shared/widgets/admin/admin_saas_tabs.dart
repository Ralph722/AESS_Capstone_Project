import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Specification for a tab in [AdminSaaSTabs].
class AdminSaaSTabSpec {
  const AdminSaaSTabSpec({
    required this.label,
    this.icon,
    this.count,
    this.isSelected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final int? count;
  final bool isSelected;
  final VoidCallback? onTap;
}

/// Standalone SaaS View Tabs component.
///
/// Sits independently above tables and filter toolbars to clearly separate
/// high-level dataset routing (e.g. All, Updates, Deactivated) from granular query filters.
class AdminSaaSTabs extends StatelessWidget {
  const AdminSaaSTabs({
    super.key,
    required this.tabs,
  });

  final List<AdminSaaSTabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in tabs) _buildTabPill(tab),
        ],
      ),
    );
  }

  Widget _buildTabPill(AdminSaaSTabSpec tab) {
    final selected = tab.isSelected;
    return InkWell(
      onTap: tab.onTap,
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm - 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm - 2),
          border: selected
              ? Border.all(color: AdminColors.border.withValues(alpha: 0.7))
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tab.icon != null) ...[
              Icon(
                tab.icon,
                size: 14,
                color: selected ? AdminColors.primary : AdminColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AdminColors.primary : AdminColors.textSecondary,
                height: 1.1,
              ),
            ),
            if (tab.count != null && tab.count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AdminColors.primary.withValues(alpha: 0.1)
                      : AdminColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tab.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? AdminColors.primary : AdminColors.textSecondary,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
