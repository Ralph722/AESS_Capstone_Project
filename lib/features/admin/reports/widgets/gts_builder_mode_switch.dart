import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// The two kinds of custom report in the Builder tab.
enum GtsBuilderMode {
  list('Alumni list', 'Who answered and what they said', Icons.list_alt_rounded),
  summary(
    'Summary & charts',
    'How many and what share',
    Icons.insert_chart_outlined_rounded,
  );

  const GtsBuilderMode(this.label, this.purpose, this.icon);

  final String label;
  final String purpose;
  final IconData icon;
}

/// SaaS segmented mode switch for Report Builder (Alumni List vs. Summary & Charts).
class GtsBuilderModeSwitch extends StatelessWidget {
  const GtsBuilderModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final GtsBuilderMode mode;
  final ValueChanged<GtsBuilderMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in GtsBuilderMode.values)
            _buildSegment(context, mode: m, isSelected: m == mode),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required GtsBuilderMode mode,
    required bool isSelected,
  }) {
    final borderRadius = BorderRadius.circular(AdminSurfaces.radiusSm - 2);
    return Material(
      color: isSelected ? AdminColors.primary : Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: () => onChanged(mode),
        borderRadius: borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AdminColors.primary.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode.icon,
                size: 17,
                color: isSelected ? Colors.white : AdminColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AdminColors.textPrimary,
                    ),
                  ),
                  Text(
                    mode.purpose,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AdminColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
