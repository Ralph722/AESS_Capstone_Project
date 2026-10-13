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
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<GtsBuilderMode>(
        segments: [
          for (final m in GtsBuilderMode.values)
            ButtonSegment(
              value: m,
              icon: Icon(m.icon, size: 18),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      m.purpose,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminReportsTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        selected: {mode},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
