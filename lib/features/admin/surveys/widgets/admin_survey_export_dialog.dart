import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// What the admin wants to export from a survey responses workspace.
enum SurveyExportReportKind {
  responses,
  management,
  ched,
  chedOutcomes,
  pending,
  chedFillable,
}

/// Output channel for a chosen report.
enum SurveyExportFormat { pdf, excel, csv, print }

class SurveyExportChoice {
  const SurveyExportChoice({
    required this.report,
    required this.format,
    this.batchYear,
    this.course,
  });

  final SurveyExportReportKind report;
  final SurveyExportFormat format;

  /// Cohort slice for open-to-all tracers only (null = all assigned).
  final String? batchYear;
  final String? course;
}

class _ReportSpec {
  const _ReportSpec({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.formats,
    required this.details,
    required this.category,
    required this.privacy,
    this.formatHint,
  });

  final SurveyExportReportKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final Set<SurveyExportFormat> formats;
  final _ExportDetailContent details;
  final ReportCatalogCategory category;
  final ReportPrivacyClass privacy;
  final String? formatHint;
}

class _ExportDetailSection {
  const _ExportDetailSection({
    required this.label,
    required this.body,
    this.bullets,
    this.icon = Icons.info_outline,
  });

  final String label;
  final String body;
  final List<String>? bullets;
  final IconData icon;
}

class _ExportDetailContent {
  const _ExportDetailContent(this.sections);

  final List<_ExportDetailSection> sections;
}

String _privacyLabel(ReportPrivacyClass privacy) => switch (privacy) {
      ReportPrivacyClass.aggregated => 'Aggregated',
      ReportPrivacyClass.confidentialIdentifiable => 'Confidential',
      ReportPrivacyClass.restrictedFollowUp => 'Restricted follow-up',
    };

String _privacyBlurb(ReportPrivacyClass privacy) => switch (privacy) {
      ReportPrivacyClass.aggregated =>
        'Counts and distributions only — no alumni names or contact details.',
      ReportPrivacyClass.confidentialIdentifiable =>
        'Includes personal alumni information. Handle under RA 10173.',
      ReportPrivacyClass.restrictedFollowUp =>
        'Identifiable follow-up list for limited staff use.',
    };

_ExportDetailContent _exportDetails({
  required String definition,
  required ReportPrivacyClass privacy,
  String? includes,
  List<String>? includeItems,
  String? bestFor,
  String? limitation,
}) {
  return _ExportDetailContent([
    _ExportDetailSection(
      label: 'What it is',
      body: definition,
      icon: Icons.description_outlined,
    ),
    _ExportDetailSection(
      label: 'Privacy',
      body: '${_privacyLabel(privacy)}. ${_privacyBlurb(privacy)}',
      icon: Icons.shield_outlined,
    ),
    if ((includes != null && includes.trim().isNotEmpty) ||
        (includeItems != null && includeItems.isNotEmpty))
      _ExportDetailSection(
        label: 'What you get',
        body: includes?.trim() ?? '',
        bullets: includeItems,
        icon: Icons.checklist_outlined,
      ),
    if (bestFor != null && bestFor.trim().isNotEmpty)
      _ExportDetailSection(
        label: 'Best for',
        body: bestFor.trim(),
        icon: Icons.thumb_up_outlined,
      ),
    if (limitation != null && limitation.trim().isNotEmpty)
      _ExportDetailSection(
        label: 'Please note',
        body: limitation.trim(),
        icon: Icons.info_outline,
      ),
  ]);
}

_ReportSpec _specFromCatalog(AessReportCatalogEntry entry) {
  final kindName = entry.surveyExportKindName;
  if (kindName == null) {
    throw StateError('Catalog entry ${entry.id} missing surveyExportKindName');
  }
  final kind = SurveyExportReportKind.values.byName(kindName);
  return _ReportSpec(
    kind: kind,
    title: entry.title,
    subtitle: entry.subtitle,
    icon: entry.icon ?? Icons.description_outlined,
    formats: _formatsForKind(kind),
    formatHint: _formatHintForKind(kind),
    category: entry.category,
    privacy: entry.privacy,
    details: _exportDetails(
      definition: entry.definition,
      privacy: entry.privacy,
      includeItems: entry.includeItems,
      bestFor: entry.bestFor,
      limitation: [
        if (entry.scopeNote != null && entry.scopeNote!.trim().isNotEmpty)
          entry.scopeNote!.trim(),
        if (entry.limitation != null && entry.limitation!.trim().isNotEmpty)
          entry.limitation!.trim(),
      ].join(' '),
    ),
  );
}

Set<SurveyExportFormat> _formatsForKind(SurveyExportReportKind kind) {
  return switch (kind) {
    SurveyExportReportKind.responses => const {
      SurveyExportFormat.excel,
      SurveyExportFormat.csv,
    },
    SurveyExportReportKind.ched => const {SurveyExportFormat.excel},
    SurveyExportReportKind.chedFillable => const {SurveyExportFormat.pdf},
    SurveyExportReportKind.management ||
    SurveyExportReportKind.chedOutcomes ||
    SurveyExportReportKind.pending => const {
      SurveyExportFormat.pdf,
      SurveyExportFormat.excel,
      SurveyExportFormat.csv,
      SurveyExportFormat.print,
    },
  };
}

String? _formatHintForKind(SurveyExportReportKind kind) {
  return switch (kind) {
    SurveyExportReportKind.responses =>
      'Choose Excel or CSV for spreadsheets.',
    SurveyExportReportKind.ched => 'Available as Excel only.',
    SurveyExportReportKind.chedFillable =>
      'Downloads a ZIP folder of filled PDF forms.',
    SurveyExportReportKind.chedOutcomes =>
      'PDF or Print works well for meetings; Excel or CSV for deeper review.',
    SurveyExportReportKind.pending =>
      'Useful when sending reminders or following up.',
    SurveyExportReportKind.management => null,
  };
}

/// Two-step export: pick report type, then PDF / Excel / CSV / Print.
///
/// [showCohortFilters] is for open-to-all CHED tracers only (no publish targets).
Future<SurveyExportChoice?> showAdminSurveyExportDialog({
  required BuildContext context,
  required bool hasSubmitted,
  required bool isChedGts,
  bool showCohortFilters = false,
  List<String> batchOptions = const [],
  List<String> courseOptions = const [],
  String? initialBatchYear,
  String? initialCourse,
}) {
  final reports = [
    for (final entry in AessReportCatalog.surveyModalEntries(
      isChedGts: isChedGts,
    ))
      _specFromCatalog(entry),
  ];

  return showAdminDialogSurface<SurveyExportChoice>(
    context: context,
    maxWidth: 520,
    maxHeight: showCohortFilters ? 820 : 740,
    child: _SurveyExportDialogBody(
      reports: reports,
      hasSubmitted: hasSubmitted,
      showCohortFilters: showCohortFilters,
      batchOptions: batchOptions,
      courseOptions: courseOptions,
      initialBatchYear: initialBatchYear,
      initialCourse: initialCourse,
    ),
  );
}

class _SurveyExportDialogBody extends StatefulWidget {
  const _SurveyExportDialogBody({
    required this.reports,
    required this.hasSubmitted,
    this.showCohortFilters = false,
    this.batchOptions = const [],
    this.courseOptions = const [],
    this.initialBatchYear,
    this.initialCourse,
  });

  final List<_ReportSpec> reports;
  final bool hasSubmitted;
  final bool showCohortFilters;
  final List<String> batchOptions;
  final List<String> courseOptions;
  final String? initialBatchYear;
  final String? initialCourse;

  @override
  State<_SurveyExportDialogBody> createState() =>
      _SurveyExportDialogBodyState();
}

class _SurveyExportDialogBodyState extends State<_SurveyExportDialogBody> {
  late SurveyExportReportKind _report;
  SurveyExportFormat? _format;
  String? _batchYear;
  String? _course;

  @override
  void initState() {
    super.initState();
    _report = widget.reports.first.kind;
    _format = _preferredFormat(_currentSpec);
    _batchYear = widget.initialBatchYear;
    _course = widget.initialCourse;
  }

  _ReportSpec get _currentSpec =>
      widget.reports.firstWhere((r) => r.kind == _report);

  static const _categoryOrder = <ReportCatalogCategory>[
    ReportCatalogCategory.responseAndParticipation,
    ReportCatalogCategory.surveyFindings,
    ReportCatalogCategory.officialChed,
    ReportCatalogCategory.detailedData,
  ];

  List<Widget> _groupedReportWidgets() {
    final widgets = <Widget>[];
    for (final category in _categoryOrder) {
      final group =
          widget.reports.where((r) => r.category == category).toList();
      if (group.isEmpty) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.add(
        Text(
          category.label.toUpperCase(),
          style: AdminText.caption.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AdminColors.textSecondary,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 6));
      for (var i = 0; i < group.length; i++) {
        if (i > 0) widgets.add(const SizedBox(height: 8));
        final r = group[i];
        widgets.add(
          _ReportRow(
            report: r,
            selected: r.kind == _report,
            blockedReason: _reportNeedsSubmissions(r.kind) && !widget.hasSubmitted
                ? 'Needs submitted responses'
                : null,
            onSelect: () {
              setState(() {
                _report = r.kind;
                if (_format == null || !r.formats.contains(_format)) {
                  _format = _preferredFormat(r);
                }
              });
            },
            onDetails: () => _showReportDetails(r),
          ),
        );
      }
    }
    return widgets;
  }

  SurveyExportFormat? _preferredFormat(_ReportSpec spec) {
    const order = [
      SurveyExportFormat.pdf,
      SurveyExportFormat.excel,
      SurveyExportFormat.csv,
      SurveyExportFormat.print,
    ];
    for (final f in order) {
      if (spec.formats.contains(f)) return f;
    }
    return null;
  }

  bool _reportNeedsSubmissions(SurveyExportReportKind kind) {
    return kind == SurveyExportReportKind.responses ||
        kind == SurveyExportReportKind.ched ||
        kind == SurveyExportReportKind.chedOutcomes ||
        kind == SurveyExportReportKind.chedFillable;
  }

  bool get _canContinue {
    final format = _format;
    if (format == null) return false;
    if (!_currentSpec.formats.contains(format)) return false;
    if (_reportNeedsSubmissions(_report) && !widget.hasSubmitted) {
      return false;
    }
    return true;
  }

  String _formatLabel(SurveyExportFormat f) {
    switch (f) {
      case SurveyExportFormat.pdf:
        return 'PDF';
      case SurveyExportFormat.excel:
        return 'Excel';
      case SurveyExportFormat.csv:
        return 'CSV';
      case SurveyExportFormat.print:
        return 'Print';
    }
  }

  IconData _formatIcon(SurveyExportFormat f) {
    switch (f) {
      case SurveyExportFormat.pdf:
        return Icons.picture_as_pdf_outlined;
      case SurveyExportFormat.excel:
        return Icons.grid_on_outlined;
      case SurveyExportFormat.csv:
        return Icons.description_outlined;
      case SurveyExportFormat.print:
        return Icons.print_outlined;
    }
  }

  Future<void> _showReportDetails(_ReportSpec report) async {
    final body = _ExportDetailsPanel(report: report);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AdminSurveyTheme.card,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusLg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(child: SingleChildScrollView(child: body)),
                const Divider(height: 1, color: AdminSurveyTheme.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AdminSurveyTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: SingleChildScrollView(child: body),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = _currentSpec;
    final needsSubs = _reportNeedsSubmissions(_report);
    final blocked = needsSubs && !widget.hasSubmitted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Download / export',
                  style: AdminText.sectionTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  AessReportCatalog.surveyModalIntro,
                  style: AdminText.caption.copyWith(height: 1.4),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AdminSurveyTheme.surface,
                      borderRadius: BorderRadius.circular(
                        AdminSurveyTheme.radiusSm,
                      ),
                      border: Border.all(color: AdminSurveyTheme.border),
                    ),
                    child: Text(
                      AessReportCatalog.surveyScopeBadge,
                      style: AdminText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AdminSurveyTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('1. What do you need?', style: _stepStyle),
                const SizedBox(height: 8),
                ..._groupedReportWidgets(),
                if (widget.showCohortFilters) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '2. Limit by batch or course (optional)',
                    style: _stepStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Optional — leave as All to include everyone assigned to '
                    'this survey.',
                    style: AdminText.caption.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminSurveyTheme.surface,
                      borderRadius: BorderRadius.circular(
                        AdminSurveyTheme.radiusMd,
                      ),
                      border: Border.all(color: AdminSurveyTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: DirectoryFilterField<String?>(
                            label: 'Batch',
                            value: _batchYear,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All batches'),
                              ),
                              for (final item in widget.batchOptions)
                                DropdownMenuItem<String?>(
                                  value: item,
                                  child: Text(
                                    item,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _batchYear = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DirectoryFilterField<String?>(
                            label: 'Course',
                            value: _course,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All courses'),
                              ),
                              for (final item in widget.courseOptions)
                                DropdownMenuItem<String?>(
                                  value: item,
                                  child: Text(
                                    item,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _course = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  widget.showCohortFilters
                      ? '3. How do you want it?'
                      : '2. How do you want it?',
                  style: _stepStyle,
                ),
                if (spec.formatHint != null) ...[
                  const SizedBox(height: 4),
                  Text(spec.formatHint!, style: AdminText.caption),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in SurveyExportFormat.values)
                      _FormatChip(
                        label:
                            _report == SurveyExportReportKind.chedFillable &&
                                f == SurveyExportFormat.pdf
                            ? 'ZIP'
                            : _formatLabel(f),
                        icon:
                            _report == SurveyExportReportKind.chedFillable &&
                                f == SurveyExportFormat.pdf
                            ? Icons.folder_zip_outlined
                            : _formatIcon(f),
                        selected: _format == f,
                        enabled: spec.formats.contains(f) && !blocked,
                        onTap: () => setState(() => _format = f),
                      ),
                  ],
                ),
                if (blocked) ...[
                  const SizedBox(height: 10),
                  Text(
                    'This report needs at least one submitted response.',
                    style: AdminText.caption.copyWith(
                      color: AdminColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AdminColors.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: !_canContinue
                    ? null
                    : () {
                        final format = _format;
                        if (format == null) return;
                        Navigator.pop(
                          context,
                          SurveyExportChoice(
                            report: _report,
                            format: format,
                            batchYear: widget.showCohortFilters
                                ? _batchYear
                                : null,
                            course: widget.showCohortFilters ? _course : null,
                          ),
                        );
                      },
                icon: Icon(
                  _format == SurveyExportFormat.print
                      ? Icons.print_outlined
                      : Icons.download_outlined,
                  size: 18,
                ),
                label: Text(
                  _format == SurveyExportFormat.print ? 'Print' : 'Download',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminSurveyTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _stepStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.2,
  color: AdminColors.textSecondary,
);

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.selected,
    required this.blockedReason,
    required this.onSelect,
    required this.onDetails,
  });

  final _ReportSpec report;
  final bool selected;

  /// Shown inside the row when the report can't be downloaded yet.
  final String? blockedReason;
  final VoidCallback onSelect;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AdminSurfaces.radiusMd);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AdminColors.primary.withValues(alpha: 0.06)
            : AdminColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AdminColors.primary : AdminColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminColors.primary.withValues(alpha: 0.1)
                        : AdminColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    report.icon,
                    size: 18,
                    color: selected
                        ? AdminColors.primary
                        : AdminColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: AdminText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AdminColors.primary
                              : AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.subtitle,
                        style: AdminText.caption.copyWith(height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _privacyLabel(report.privacy),
                        style: AdminText.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: report.privacy ==
                                  ReportPrivacyClass.aggregated
                              ? AdminColors.textSecondary
                              : AdminColors.warning,
                        ),
                      ),
                      if (blockedReason != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 13,
                              color: AdminColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                blockedReason!,
                                style: AdminText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AdminColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AdminColors.primary,
                    ),
                  ),
                IconButton(
                  tooltip: 'Details',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AdminColors.textSecondary,
                  ),
                  onPressed: onDetails,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? AdminSurveyTheme.textMuted.withValues(alpha: 0.45)
        : selected
        ? AdminSurveyTheme.primary
        : AdminSurveyTheme.textSecondary;
    final bg = !enabled
        ? AdminSurveyTheme.surface
        : selected
        ? AdminSurveyTheme.primary.withValues(alpha: 0.08)
        : AdminSurveyTheme.card;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected && enabled
                  ? AdminSurveyTheme.primary
                  : AdminSurveyTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportDetailsPanel extends StatelessWidget {
  const _ExportDetailsPanel({required this.report});

  final _ReportSpec report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AdminSurveyTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  report.icon,
                  size: 20,
                  color: AdminSurveyTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: AdminText.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.subtitle,
                      style: AdminText.body.copyWith(
                        height: 1.35,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < report.details.sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ExportDetailCard(section: report.details.sections[i]),
          ],
        ],
      ),
    );
  }
}

class _ExportDetailCard extends StatelessWidget {
  const _ExportDetailCard({required this.section});

  final _ExportDetailSection section;

  @override
  Widget build(BuildContext context) {
    final bullets = section.bullets;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AdminSurveyTheme.surface,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
        border: Border.all(color: AdminSurveyTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AdminSurveyTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              section.icon,
              size: 15,
              color: AdminSurveyTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: AdminText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AdminColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                if (bullets != null && bullets.isNotEmpty) ...[
                  for (final item in bullets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: AdminSurveyTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: AdminText.body.copyWith(
                                height: 1.4,
                                color: AdminColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else if (section.body.isNotEmpty)
                  Text(
                    section.body,
                    style: AdminText.body.copyWith(
                      height: 1.45,
                      color: AdminColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
