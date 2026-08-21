import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';

/// Ready-to-download preset reports (replaces the custom builder for now).
class ReportsDownloadsPanel extends StatelessWidget {
  const ReportsDownloadsPanel({
    super.key,
    required this.onDownload,
    this.busy = false,
  });

  final Future<void> Function(
    ReportsDownloadPreset preset, {
    required CustomReportFormat format,
    required bool printPreview,
  }) onDownload;

  final bool busy;

  static const presets = <ReportsDownloadPreset>[
    ReportsDownloadPreset(
      id: 'executive',
      title: 'Executive snapshot',
      description: 'KPIs, survey summary, and employment outcomes.',
      icon: Icons.insights_outlined,
      sections: [
        CustomReportSectionId.executiveKpis,
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.employmentRecords,
      ],
    ),
    ReportsDownloadPreset(
      id: 'tracer',
      title: 'Tracer outcomes',
      description: 'Employment records for registered alumni.',
      icon: Icons.work_outline,
      sections: [CustomReportSectionId.employmentRecords],
    ),
    ReportsDownloadPreset(
      id: 'ched',
      title: 'CHED GTS pack',
      description: 'KPIs, waves, questions, and employment for GTS reporting.',
      icon: Icons.verified_outlined,
      sections: [
        CustomReportSectionId.executiveKpis,
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.surveyQuestions,
        CustomReportSectionId.employmentRecords,
      ],
    ),
    ReportsDownloadPreset(
      id: 'ched_wave_compare',
      title: 'CHED wave comparison',
      description: 'Compare 2+ Official CHED GTS waves on key fields.',
      icon: Icons.compare_arrows_outlined,
      sections: [CustomReportSectionId.chedWaveComparison],
      needsWavePicker: true,
    ),
    ReportsDownloadPreset(
      id: 'survey',
      title: 'Survey participation',
      description: 'Assignment and response health by wave.',
      icon: Icons.poll_outlined,
      sections: [
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.surveyParticipation,
      ],
    ),
    ReportsDownloadPreset(
      id: 'roster',
      title: 'Roster extract',
      description: 'Active roster with registration and tracer status.',
      icon: Icons.groups_outlined,
      sections: [CustomReportSectionId.alumniRoster],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ReportsSectionShell(
      icon: Icons.download_outlined,
      title: 'Downloads',
      subtitle: 'Pick a preset, then download or print.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < presets.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PresetCard(
              preset: presets[i],
              busy: busy,
              onDownload: onDownload,
            ),
          ],
        ],
      ),
    );
  }
}

class ReportsDownloadPreset {
  const ReportsDownloadPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.sections,
    this.needsWavePicker = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<CustomReportSectionId> sections;

  /// When true, Downloads opens a wave picker before exporting.
  final bool needsWavePicker;
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.busy,
    required this.onDownload,
  });

  final ReportsDownloadPreset preset;
  final bool busy;
  final Future<void> Function(
    ReportsDownloadPreset preset, {
    required CustomReportFormat format,
    required bool printPreview,
  }) onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AdminReportsTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminReportsTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  preset.icon,
                  size: 16,
                  color: AdminReportsTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AdminReportsTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AdminReportsTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final format in CustomReportFormat.values)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => onDownload(
                            preset,
                            format: format,
                            printPreview: false,
                          ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(format.label),
                ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => onDownload(
                          preset,
                          format: CustomReportFormat.pdf,
                          printPreview: true,
                        ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: const Text('Print'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
