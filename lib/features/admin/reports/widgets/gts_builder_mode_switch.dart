import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';

/// The two kinds of custom report in the Builder tab.
enum GtsBuilderMode {
  list('Alumni list', 'Who answered and what they said', Icons.list_alt),
  summary(
    'Summary & charts',
    'How many and what share',
    Icons.insert_chart_outlined,
  );

  const GtsBuilderMode(this.label, this.purpose, this.icon);

  final String label;
  final String purpose;
  final IconData icon;
}

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
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: AdminReportsTheme.cardShadow,
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
    return Material(
      color: isSelected ? AdminReportsTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onChanged(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AdminReportsTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.12)
                      : AdminReportsTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  mode.icon,
                  size: 18,
                  color: isSelected
                      ? AdminReportsTheme.gold
                      : AdminReportsTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : AdminReportsTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    mode.purpose,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : AdminReportsTheme.textMuted,
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
