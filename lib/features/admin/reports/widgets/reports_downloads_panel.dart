import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:alumni_system/core/constants/ustp_colors.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:alumni_system/features/admin/reports/models/report_filter_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

typedef ReportsPresetDownload =
    Future<void> Function(
      ReportsDownloadPreset preset, {
      required CustomReportFormat format,
      required bool printPreview,
    });

/// Title Case for Downloads card titles (first/last/principal words).
String reportsDownloadTitleCase(String input) {
  const small = {
    'a',
    'an',
    'the',
    'and',
    'but',
    'or',
    'nor',
    'for',
    'on',
    'at',
    'to',
    'from',
    'by',
    'of',
    'in',
    'with',
    'as',
    'vs',
    'via',
  };
  final words = input.trim().split(RegExp(r'\s+'));
  if (words.isEmpty) return input;
  final last = words.length - 1;
  return [
    for (var i = 0; i < words.length; i++)
      _titleCaseToken(words[i], forceCap: i == 0 || i == last, small: small),
  ].join(' ');
}

String _titleCaseToken(
  String raw, {
  required bool forceCap,
  required Set<String> small,
}) {
  if (raw.isEmpty) return raw;
  if (raw.contains('-')) {
    final parts = raw.split('-');
    return [
      for (var i = 0; i < parts.length; i++)
        _titleCaseToken(
          parts[i],
          forceCap: forceCap || i == 0 || i == parts.length - 1,
          small: small,
        ),
    ].join('-');
  }
  // Keep short all-caps tokens (CHED, GTS, KPI, PDF, …).
  if (raw.length >= 2 &&
      raw.length <= 5 &&
      RegExp(r'^[A-Z0-9&]+$').hasMatch(raw)) {
    return raw;
  }
  final lower = raw.toLowerCase();
  if (!forceCap && small.contains(lower)) return lower;
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

/// Ready-to-download preset reports laid out as responsive download cards.
class ReportsDownloadsPanel extends StatelessWidget {
  const ReportsDownloadsPanel({
    super.key,
    required this.onDownload,
    required this.rowCounts,
    required this.filterLabel,
    required this.chedWaveCount,
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

  final bool busy;
  final String? busyPresetId;
  final double? fitHeight;

  static const double _cardHeight = 275;

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
    'professional_exams': <CustomReportSectionId>[],
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
      'professional_exams',
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
    'professional_exams',
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
      includeItems: entry.includeItems,
    );
  }

  static ReportsDownloadPreset _preset(String id) => _presetFromCatalog(id);

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder adapts column count while sizing cleanly to content.
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1200.0;
        final int columns;
        if (width >= 1060) {
          columns = 3;
        } else if (width >= 640) {
          columns = 2;
        } else {
          columns = 1;
        }

        const gutter = AdminReportsTheme.gutter;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final category in categoryPresetIds.keys) ...[
              _categoryHeader(category),
              const SizedBox(height: 10),
              ..._buildCategoryGrid(
                presetIds: categoryPresetIds[category]!,
                columns: columns,
                cardHeight: _cardHeight,
                gutter: gutter,
              ),
              const SizedBox(height: AdminReportsTheme.sectionGap),
            ],
          ],
        );
      },
    );

    final maxH = fitHeight;
    // When the page passes a viewport budget, bound the panel first — then
    // SingleChildScrollView inside Expanded is safe.
    if (maxH != null && maxH.isFinite && maxH > 0) {
      return SizedBox(
        height: maxH,
        child: SingleChildScrollView(child: body),
      );
    }

    return body;
  }

  Widget _categoryHeader(ReportCatalogCategory category) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 13,
          decoration: BoxDecoration(
            color: UstpColors.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          category.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AdminColors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCategoryGrid({
    required List<String> presetIds,
    required int columns,
    required double cardHeight,
    required double gutter,
  }) {
    final chunks = _chunks(presetIds, columns);
    return [
      for (var r = 0; r < chunks.length; r++) ...[
        if (r > 0) SizedBox(height: gutter),
        SizedBox(
          height: cardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < chunks[r].length; i++) ...[
                if (i > 0) SizedBox(width: gutter),
                Expanded(
                  child: chunks[r][i] == 'ched_wave_compare'
                      ? _waveCompareCard(_preset(chunks[r][i]))
                      : _card(_preset(chunks[r][i])),
                ),
              ],
              // Pad any remaining column slots so all cards maintain identical widths
              for (var i = chunks[r].length; i < columns; i++) ...[
                SizedBox(width: gutter),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  static List<List<String>> _chunks(List<String> ids, int size) {
    final out = <List<String>>[];
    for (var i = 0; i < ids.length; i += size) {
      out.add(ids.sublist(i, i + size > ids.length ? ids.length : i + size));
    }
    return out;
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

  Widget? _privacyBadge(ReportPrivacyClass? privacy) {
    if (privacy == null) return null;
    final isAggregated = privacy == ReportPrivacyClass.aggregated;
    final label = switch (privacy) {
      ReportPrivacyClass.aggregated => 'Aggregated',
      ReportPrivacyClass.confidentialIdentifiable => 'Confidential',
      ReportPrivacyClass.restrictedFollowUp => 'Restricted',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAggregated
            ? UstpColors.blue.withValues(alpha: 0.06)
            : AdminColors.warningBg,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(
          color: isAggregated
              ? UstpColors.blue.withValues(alpha: 0.2)
              : AdminColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isAggregated ? UstpColors.blue : AdminColors.warning,
        ),
      ),
    );
  }

  Widget _card(ReportsDownloadPreset preset) {
    final counts = [for (final s in preset.sections) rowCounts[s]];
    final allKnown =
        preset.sections.isNotEmpty && counts.every((c) => c != null);
    final empty = allKnown && counts.fold<int>(0, (s, c) => s + c!) == 0;
    final privacy = preset.privacy;

    Widget middleContent;
    if (empty) {
      middleContent = const Center(
        child: _Note(
          text: 'Nothing to export with current filters',
          color: AdminColors.warning,
        ),
      );
    } else if (preset.sections.isNotEmpty) {
      middleContent = ListView.separated(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: preset.sections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 5),
        itemBuilder: (context, i) => _SectionLine(
          label: preset.sections[i].label,
          count: counts[i],
        ),
      );
    } else if (preset.includeItems.isNotEmpty) {
      middleContent = ListView.separated(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: math.min(preset.includeItems.length, 3),
        separatorBuilder: (context, index) => const SizedBox(height: 5),
        itemBuilder: (context, i) => _HighlightLine(
          text: preset.includeItems[i],
        ),
      );
    } else {
      middleContent = Align(
        alignment: Alignment.centerLeft,
        child: Text(
          preset.scopeNote ?? AessReportCatalog.institutionalScopeBadge,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: AdminColors.textMuted,
          ),
        ),
      );
    }

    return ReportsDownloadCard(
      preset: preset,
      details: _details(preset),
      badge: _privacyBadge(privacy),
      content: middleContent,
      actions: _actions(preset),
    );
  }

  Widget _waveCompareCard(ReportsDownloadPreset preset) {
    final ready = chedWaveCount >= 2;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ready
                ? UstpColors.blue.withValues(alpha: 0.05)
                : AdminColors.surface,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            border: Border.all(
              color: ready
                  ? UstpColors.blue.withValues(alpha: 0.2)
                  : AdminColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                ready ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 16,
                color: ready ? UstpColors.blue : AdminColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chedWaveCount == 1
                          ? '1 CHED wave available'
                          : '$chedWaveCount CHED waves available',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready
                          ? 'Select waves after choosing format'
                          : 'Needs at least 2 waves with responses',
                      style: TextStyle(
                        fontSize: 11,
                        color: ready
                            ? AdminColors.textSecondary
                            : AdminColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return ReportsDownloadCard(
      preset: preset,
      details: ReportsDetailsButton.compose(
        definition: preset.definition ?? preset.description,
        calculation:
            'Pick a format, then choose the waves (and optional '
            'batch or course) in the wave picker.',
        scope: preset.scopeNote ??
            'Published or closed Official CHED GTS waves with submitted '
                'responses.',
      ),
      badge: _privacyBadge(preset.privacy),
      content: content,
      actions: _actions(preset, enabled: ready),
    );
  }

  Widget _actions(ReportsDownloadPreset preset, {bool enabled = true}) {
    if (busy && busyPresetId == preset.id) {
      return Container(
        height: 30,
        alignment: Alignment.centerLeft,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: UstpColors.blue,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Preparing…',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary,
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: UstpColors.blue,
                  side: const BorderSide(color: AdminColors.border),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  ),
                ),
                child: Text(
                  format.label,
                  style: const TextStyle(
                    fontSize: 11.5,
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
                foregroundColor: UstpColors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                minimumSize: const Size(0, 28),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
              ),
              icon: const Icon(Icons.print_outlined, size: 14),
              label: const Text(
                'Print',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Redesigned download card with multi-line typography, accessory badges,
/// and value-driven highlight items instead of empty placeholder space.
class ReportsDownloadCard extends StatelessWidget {
  const ReportsDownloadCard({
    super.key,
    required this.preset,
    required this.details,
    required this.content,
    required this.actions,
    this.badge,
  });

  final ReportsDownloadPreset preset;
  final String details;
  final Widget content;
  final Widget actions;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Accessory Row: Leading Icon Badge + Privacy Tag + Details Button
          Row(
            children: [
              _PresetIcon(icon: preset.icon),
              if (badge != null) ...[
                const SizedBox(width: 8),
                badge!,
              ],
              const Spacer(),
              ReportsDetailsButton(
                title: reportsDownloadTitleCase(preset.title),
                body: details,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Title (maxLines: 2, softWrap: true)
          Text(
            reportsDownloadTitleCase(preset.title),
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.25,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          // Description / Subtitle (maxLines: 2, softWrap: true)
          Text(
            preset.description,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AdminColors.border),
          const SizedBox(height: 8),
          // Middle content (replaces the dead thumbnail space)
          Expanded(child: ClipRect(child: content)),
          const SizedBox(height: 8),
          // Action buttons row (pinned to bottom)
          actions,
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
    this.needsConfigDialog = true,
    this.catalogId,
    this.scopeNote,
    this.definition,
    this.privacy,
    this.category,
    this.includeItems = const [],
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
  final List<String> includeItems;
}

class _PresetIcon extends StatelessWidget {
  const _PresetIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: UstpColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: UstpColors.blue),
    );
  }
}

class _HighlightLine extends StatelessWidget {
  const _HighlightLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: UstpColors.blue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AdminColors.textSecondary,
            ),
          ),
        ),
      ],
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
          size: 13,
          color: n == 0 ? AdminColors.textMuted : UstpColors.blue,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          n == null ? 'counted on download' : '$n ${n == 1 ? 'row' : 'rows'}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: n == null ? FontWeight.w500 : FontWeight.w700,
            color: n == null
                ? AdminColors.textMuted
                : AdminColors.textSecondary,
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
