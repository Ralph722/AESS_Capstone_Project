import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:alumni_system/features/admin/reports/models/report_filter_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_bento.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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

  static const _presetSections = <String, List<CustomReportSectionId>>{
    'employment_employability': <CustomReportSectionId>[],
    'curriculum_competency': <CustomReportSectionId>[],
    'industry_placement': <CustomReportSectionId>[],
    'career_mobility': <CustomReportSectionId>[],
    'ched_compliance_master': <CustomReportSectionId>[],
    'gts_participation_quality': <CustomReportSectionId>[],
    'executive': [
      CustomReportSectionId.executiveKpis,
      CustomReportSectionId.surveySummary,
      CustomReportSectionId.employmentRecords,
    ],
    'tracer': [CustomReportSectionId.employmentRecords],
    'ched': [
      CustomReportSectionId.executiveKpis,
      CustomReportSectionId.surveySummary,
      CustomReportSectionId.surveyQuestions,
      CustomReportSectionId.employmentRecords,
    ],
    'ched_wave_compare': [CustomReportSectionId.chedWaveComparison],
    'survey': [
      CustomReportSectionId.surveySummary,
      CustomReportSectionId.surveyParticipation,
    ],
    'roster': [CustomReportSectionId.alumniRoster],
  };

  /// Category → preset ids for the Downloads library layout.
  static const categoryPresetIds = <ReportCatalogCategory, List<String>>{
    ReportCatalogCategory.institutionalGts: [
      'employment_employability',
      'curriculum_competency',
      'industry_placement',
      'career_mobility',
      'ched_compliance_master',
    ],
    ReportCatalogCategory.comparisonsAndQuality: [
      'ched_wave_compare',
      'gts_participation_quality',
      'survey',
    ],
    ReportCatalogCategory.operations: [
      'executive',
      'ched',
      'tracer',
      'roster',
    ],
  };

  static const _presetOrder = <String>[
    'employment_employability',
    'curriculum_competency',
    'industry_placement',
    'career_mobility',
    'ched_compliance_master',
    'ched_wave_compare',
    'gts_participation_quality',
    'survey',
    'executive',
    'ched',
    'tracer',
    'roster',
  ];

  static List<ReportsDownloadPreset> get presets {
    return [
      for (final id in _presetOrder) _presetFromCatalog(id),
    ];
  }

  static ReportsDownloadPreset _presetFromCatalog(String id) {
    final entry = AessReportCatalog.byDownloadsPresetId(id);
    final sections = _presetSections[id];
    if (entry == null || sections == null) {
      throw StateError('Downloads preset "$id" missing from report catalog');
    }
    return ReportsDownloadPreset(
      id: id,
      title: entry.title,
      description: entry.subtitle,
      icon: entry.icon ?? Icons.description_outlined,
      sections: sections,
      needsWavePicker: id == 'ched_wave_compare',
      needsConfigDialog: id != 'ched_wave_compare',
      catalogId: entry.id,
      scopeNote: entry.scopeNote,
      definition: entry.definition,
      privacy: entry.privacy,
      category: entry.category,
    );
  }

  static ReportsDownloadPreset _preset(String id) => _presetFromCatalog(id);

  @override
  Widget build(BuildContext context) {
    // Always size to content. This panel lives under a page-level
    // CustomScrollView / SliverToBoxAdapter (unbounded height), so Expanded
    // cannot be used here — that left the Column with size MISSING and a blank
    // Downloads tab.
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in categoryPresetIds.keys) ...[
          _categoryHeader(category),
          const SizedBox(height: 8),
          ReportsBentoGrid(
            kpis: const [],
            fitHeight: null,
            rows: [
              for (final chunk in _chunks(categoryPresetIds[category]!, 3))
                ReportsBentoRow(
                  flex: [for (final _ in chunk) 4],
                  naturalHeight: 250,
                  children: [
                    for (final id in chunk)
                      id == 'ched_wave_compare'
                          ? _waveCompareCard(_preset(id))
                          : _card(_preset(id)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AdminReportsTheme.gutter),
        ],
      ],
    );

    final chrome = <Widget>[
      SizedBox(height: _barHeight, child: _scopeBar()),
      const SizedBox(height: AdminReportsTheme.gutter),
    ];

    final maxH = fitHeight;
    // When the page passes a viewport budget, bound the panel first — then
    // Expanded/scroll is safe. Never put Expanded directly under a
    // SliverToBoxAdapter (unbounded height → blank Downloads tab).
    if (maxH != null && maxH.isFinite && maxH > _barHeight) {
      return SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...chrome,
            Expanded(child: SingleChildScrollView(child: body)),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...chrome, body],
    );
  }

  Widget _categoryHeader(ReportCatalogCategory category) {
    return Text(
      category.label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.45,
        color: AdminReportsTheme.textMuted,
      ),
    );
  }

  static List<List<String>> _chunks(List<String> ids, int size) {
    final out = <List<String>>[];
    for (var i = 0; i < ids.length; i += size) {
      out.add(ids.sublist(i, i + size > ids.length ? ids.length : i + size));
    }
    return out;
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
                  '${AessReportCatalog.downloadsIntro} '
                  'Alumni list and employment extracts use these filters. '
                  'Change them on the Tracer or Survey tab.',
              waitDuration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      size: 13,
                      color: AdminColors.primary,
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
                          color: AdminColors.primary,
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
                foregroundColor: AdminColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    final scope = preset.scopeNote?.trim();
    final schema = ReportFilterSchemas.forDownloadsPreset(preset.id);
    final filterNote = schema?.notes?.trim();
    final supported = schema == null || schema.supported.isEmpty
        ? null
        : 'Configurable filters (later): '
            '${schema.supported.map((k) => k.label).join(', ')}.';
    final scopeText = (scope != null && scope.isNotEmpty)
        ? scope
        : filtered
        ? 'Alumni list and employment rows use: $filterLabel. Other sections '
              'cover the whole system.'
        : 'Whole system (batch and course filters do not apply). '
              '(${AessReportCatalog.institutionalScopeBadge})';
    return ReportsDetailsButton.compose(
      definition: preset.definition ?? preset.description,
      calculation:
          'Includes: '
          '${preset.sections.map((s) => s.label).join(', ')}. Row counts '
          'come from the same builder that creates the file.'
          '${supported == null ? '' : ' $supported'}'
          '${filterNote == null || filterNote.isEmpty ? '' : ' $filterNote'}',
      scope: scopeText,
    );
  }

  Widget _card(ReportsDownloadPreset preset) {
    final counts = [for (final s in preset.sections) rowCounts[s]];
    final allKnown =
        preset.sections.isNotEmpty && counts.every((c) => c != null);
    final empty = allKnown && counts.fold<int>(0, (s, c) => s + c!) == 0;
    final privacy = preset.privacy;
    return ReportsBentoCard(
      title: preset.title,
      caption: preset.description,
      details: _details(preset),
      trailing: _PresetIcon(icon: preset.icon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (privacy != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                switch (privacy) {
                  ReportPrivacyClass.aggregated => 'Aggregated',
                  ReportPrivacyClass.confidentialIdentifiable =>
                    'Confidential',
                  ReportPrivacyClass.restrictedFollowUp =>
                    'Restricted follow-up',
                },
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: privacy == ReportPrivacyClass.aggregated
                      ? AdminReportsTheme.textMuted
                      : AdminReportsTheme.warning,
                ),
              ),
            ),
          Expanded(
            child: preset.sections.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      preset.scopeNote ??
                          AessReportCatalog.institutionalScopeBadge,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AdminReportsTheme.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: preset.sections.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 12,
                      color: AdminReportsTheme.border,
                    ),
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
        definition: preset.definition ?? preset.description,
        calculation:
            'Pick a format, then choose the waves (and optional '
            'batch or course) in the wave picker.',
        scope: preset.scopeNote ??
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
    this.needsConfigDialog = true,
    this.catalogId,
    this.scopeNote,
    this.definition,
    this.privacy,
    this.category,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<CustomReportSectionId> sections;

  /// When true, Downloads opens a wave picker before exporting.
  final bool needsWavePicker;

  /// When true, Downloads opens the shared filter config dialog.
  final bool needsConfigDialog;

  /// Stable [AessReportCatalog] id when this preset is catalog-backed.
  final String? catalogId;

  /// Scope contract copied from the catalog for details / tooltips.
  final String? scopeNote;

  /// Longer definition from the catalog (Details panel).
  final String? definition;

  final ReportPrivacyClass? privacy;
  final ReportCatalogCategory? category;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
