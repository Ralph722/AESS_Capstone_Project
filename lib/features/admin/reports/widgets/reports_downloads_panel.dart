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
      description:
          'System KPIs, survey summary, and employment outcomes for a quick brief.',
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
      description:
          'Employment records for registered alumni (use Tracer filters first if needed).',
      icon: Icons.work_outline,
      sections: [CustomReportSectionId.employmentRecords],
    ),
    ReportsDownloadPreset(
      id: 'ched',
      title: 'CHED GTS pack',
      description:
          'KPIs, survey waves, question summaries, and employment for GTS reporting.',
      icon: Icons.verified_outlined,
      sections: [
        CustomReportSectionId.executiveKpis,
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.surveyQuestions,
        CustomReportSectionId.employmentRecords,
      ],
    ),
    ReportsDownloadPreset(
      id: 'survey',
      title: 'Survey participation',
      description: 'Survey waves with assignment and response health.',
      icon: Icons.poll_outlined,
      sections: [
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.surveyParticipation,
      ],
    ),
    ReportsDownloadPreset(
      id: 'roster',
      title: 'Roster extract',
      description: 'Active alumni roster with registration and tracer status.',
      icon: Icons.groups_outlined,
      sections: [CustomReportSectionId.alumniRoster],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ReportsSectionShell(
      icon: Icons.download_outlined,
      title: 'Downloads',
      subtitle:
          'Pick a ready report, then download or print. No custom builder for now.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < presets.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
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
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<CustomReportSectionId> sections;
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminReportsTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  preset.icon,
                  size: 18,
                  color: AdminReportsTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AdminReportsTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AdminReportsTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
