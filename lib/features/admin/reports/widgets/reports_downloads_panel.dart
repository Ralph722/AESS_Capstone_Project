import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_bento.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';

typedef ReportsPresetDownload =
    Future<void> Function(
      ReportsDownloadPreset preset, {
      required CustomReportFormat format,
      required bool printPreview,
    });

/// Ready-to-download preset reports laid out as bento cards.
class ReportsDownloadsPanel extends StatelessWidget {
  const ReportsDownloadsPanel({
    super.key,
    required this.onDownload,
    required this.rowCounts,
    required this.filterLabel,
    required this.chedWaveCount,
    this.onClearFilters,
    this.busy = false,
    this.busyPresetId,
    this.fitHeight,
  });

  final ReportsPresetDownload onDownload;

  /// Rows each section will contain; `null` means it is counted on download.
  final Map<CustomReportSectionId, int?> rowCounts;

  /// Batch / course scope the exports use (e.g. "All batches · All courses").
  final String filterLabel;

  /// Official CHED GTS waves with submitted responses.
  final int chedWaveCount;

  /// Shown when a batch or course filter is set.
  final VoidCallback? onClearFilters;

  final bool busy;
  final String? busyPresetId;
  final double? fitHeight;

  static const double _barHeight = 36;

  /// Sections that honour the batch / course filters.
  static const filteredSections = {
    CustomReportSectionId.alumniRoster,
    CustomReportSectionId.employmentRecords,
  };

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

  static ReportsDownloadPreset _preset(String id) =>
      presets.firstWhere((p) => p.id == id);

  @override
  Widget build(BuildContext context) {
    final fit = fitHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _barHeight, child: _scopeBar()),
        const SizedBox(height: AdminReportsTheme.gutter),
        ReportsBentoGrid(
          kpis: const [],
          fitHeight: fit == null
              ? null
              : fit - _barHeight - AdminReportsTheme.gutter,
          rows: [
            ReportsBentoRow(
              flex: const [5, 4, 3],
              naturalHeight: 260,
              children: [
                _card(_preset('executive')),
                _card(_preset('ched')),
                _waveCompareCard(_preset('ched_wave_compare')),
              ],
            ),
            ReportsBentoRow(
              flex: const [4, 4, 4],
              naturalHeight: 230,
              children: [
                _card(_preset('tracer')),
                _card(_preset('survey')),
                _card(_preset('roster')),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _scopeBar() {
    final clear = onClearFilters;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message:
                  'Roster and employment rows use these filters. '
                  'Change them on the Tracer or Survey tab.',
              waitDuration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AdminReportsTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AdminReportsTheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 13,
                      color: AdminReportsTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Exports use: $filterLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AdminReportsTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (clear != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: TextButton.icon(
              onPressed: clear,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AdminReportsTheme.primary,
              ),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
              label: const Text(
                'Clear filters',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _details(ReportsDownloadPreset preset) {
    final filtered = preset.sections.any(filteredSections.contains);
    return ReportsDetailsButton.compose(
      definition: preset.description,
      calculation:
          'Includes: '
          '${preset.sections.map((s) => s.label).join(', ')}. Row counts '
          'come from the same builder that creates the file.',
      scope: filtered
          ? 'Roster and employment rows use: $filterLabel. Other sections '
                'cover the whole system.'
          : 'Whole system (batch and course filters do not apply).',
    );
  }

  Widget _card(ReportsDownloadPreset preset) {
    final counts = [for (final s in preset.sections) rowCounts[s]];
    final allKnown = counts.every((c) => c != null);
    final empty = allKnown && counts.fold<int>(0, (s, c) => s + c!) == 0;
    return ReportsBentoCard(
      title: preset.title,
      caption: preset.description,
      details: _details(preset),
      trailing: _PresetIcon(icon: preset.icon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: preset.sections.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 12, color: AdminReportsTheme.border),
              itemBuilder: (context, i) => _SectionLine(
                label: preset.sections[i].label,
                count: counts[i],
              ),
            ),
          ),
          if (empty) ...[
            const SizedBox(height: 6),
            const _Note(
              text: 'Nothing to export with these filters',
              color: AdminReportsTheme.warning,
            ),
          ],
          const SizedBox(height: 8),
          _actions(preset),
        ],
      ),
    );
  }

  Widget _waveCompareCard(ReportsDownloadPreset preset) {
    final ready = chedWaveCount >= 2;
    return ReportsBentoCard(
      title: preset.title,
      caption: preset.description,
      details: ReportsDetailsButton.compose(
        definition: preset.description,
        calculation:
            'Pick a format, then choose the waves (and optional '
            'batch or course) in the wave picker.',
        scope:
            'Published or closed Official CHED GTS waves with submitted '
            'responses.',
      ),
      trailing: _PresetIcon(icon: preset.icon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$chedWaveCount',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AdminReportsTheme.textPrimary,
                      ),
                    ),
                    Text(
                      chedWaveCount == 1
                          ? 'CHED wave available'
                          : 'CHED waves available',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminReportsTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Note(
            text: ready
                ? 'You choose the waves after picking a format'
                : 'Needs at least 2 CHED waves with responses',
            color: ready
                ? AdminReportsTheme.textMuted
                : AdminReportsTheme.warning,
          ),
          const SizedBox(height: 8),
          _actions(preset, enabled: ready),
        ],
      ),
    );
  }

  Widget _actions(ReportsDownloadPreset preset, {bool enabled = true}) {
    if (busy && busyPresetId == preset.id) {
      return const SizedBox(
        height: 30,
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Preparing…',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminReportsTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    final canTap = enabled && !busy;
    return SizedBox(
      height: 30,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final format in CustomReportFormat.values) ...[
              OutlinedButton(
                onPressed: canTap
                    ? () => onDownload(
                        preset,
                        format: format,
                        printPreview: false,
                      )
                    : null,
                style: AdminButtonStyles.outlined(),
                child: Text(
                  format.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            TextButton.icon(
              onPressed: canTap
                  ? () => onDownload(
                      preset,
                      format: CustomReportFormat.pdf,
                      printPreview: true,
                    )
                  : null,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AdminReportsTheme.primary,
              ),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text(
                'Print',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
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

class _PresetIcon extends StatelessWidget {
  const _PresetIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AdminReportsTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 15, color: AdminReportsTheme.primary),
    );
  }
}

class _SectionLine extends StatelessWidget {
  const _SectionLine({required this.label, required this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final n = count;
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: n == 0
              ? AdminReportsTheme.textMuted
              : AdminReportsTheme.success,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AdminReportsTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          n == null ? 'counted on download' : '$n ${n == 1 ? 'row' : 'rows'}',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: n == null ? FontWeight.w500 : FontWeight.w700,
            color: n == null
                ? AdminReportsTheme.textMuted
                : AdminReportsTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: color),
          ),
        ),
      ],
    );
  }
}
