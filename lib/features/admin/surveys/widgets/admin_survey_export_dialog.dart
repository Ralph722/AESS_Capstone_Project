import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';

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
enum SurveyExportFormat {
  pdf,
  excel,
  csv,
  print,
}

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
    this.formatHint,
  });

  final SurveyExportReportKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final Set<SurveyExportFormat> formats;
  final _ExportDetailContent details;
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

_ExportDetailContent _exportDetails({
  required String definition,
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
  final reports = <_ReportSpec>[
    _ReportSpec(
      kind: SurveyExportReportKind.responses,
      title: 'Submitted responses',
      subtitle: 'A full list of everyone who already answered, with their answers',
      icon: Icons.table_rows_outlined,
      formats: const {
        SurveyExportFormat.excel,
        SurveyExportFormat.csv,
      },
      formatHint: 'Choose Excel or CSV for spreadsheets.',
      details: _exportDetails(
        definition:
            'Downloads a spreadsheet of alumni who already submitted this survey, '
            'with their answers side by side.',
        includeItems: const [
          'Name, email, course, and batch year',
          'When they submitted',
          'Each survey answer',
        ],
        bestFor: 'Reviewing answers in Excel or sharing raw results with staff.',
        limitation:
            'This is a data file, not a presentation. For meetings, use a summary report.',
      ),
    ),
    _ReportSpec(
      kind: SurveyExportReportKind.management,
      title: 'Management report',
      subtitle: 'Overview of how many answered and what the results look like',
      icon: Icons.summarize_outlined,
      formats: const {
        SurveyExportFormat.pdf,
        SurveyExportFormat.excel,
        SurveyExportFormat.csv,
        SurveyExportFormat.print,
      },
      details: _exportDetails(
        definition:
            'A ready-made summary of this survey for office review: how many were '
            'invited, how many finished, and highlights from the answers.',
        includeItems: const [
          'Completion overview',
          'Results by course and batch',
          'Question summaries and short takeaways',
        ],
        bestFor: 'Meetings, printouts, and quick status updates for the office.',
        limitation:
            'For tracer employment and related CHED questions, the “CHED outcomes '
            'summary” is clearer.',
      ),
    ),
    if (isChedGts) ...[
      _ReportSpec(
        kind: SurveyExportReportKind.chedOutcomes,
        title: 'CHED outcomes summary',
        subtitle: 'Are they employed? Did the job match their course? And more',
        icon: Icons.insights_outlined,
        formats: const {
          SurveyExportFormat.pdf,
          SurveyExportFormat.excel,
          SurveyExportFormat.csv,
          SurveyExportFormat.print,
        },
        formatHint: 'PDF or Print works well for meetings; Excel or CSV for deeper review.',
        details: _exportDetails(
          definition:
              'A short tracer report for this survey that answers the main CHED '
              'questions offices care about. Percentages always show how many people '
              'answered, so small groups are easy to spot.',
          includeItems: const [
            'How many finished the tracer',
            'Whether graduates are employed',
            'Why some are not employed',
            'Type of work, and local or abroad',
            'Whether the job matches their course',
            'Time to first job, starting pay, and curriculum help',
            'Reasons for further studies',
          ],
          bestFor: 'School meetings, CHED reporting talks, and “what did this tracer find?”',
          limitation:
              'This covers the current survey only. To compare older and newer tracers, '
              'use Reports & Analytics → Downloads.',
        ),
      ),
      _ReportSpec(
        kind: SurveyExportReportKind.ched,
        title: 'CHED GTS Excel pack',
        subtitle: 'Detailed tracer workbook with personal, school, and job sheets',
        icon: Icons.verified_outlined,
        formats: const {SurveyExportFormat.excel},
        formatHint: 'Available as Excel only.',
        details: _exportDetails(
          definition:
              'A detailed Excel file for this tracer, organized into sheets that follow '
              'the CHED Graduate Tracer Study sections.',
          includeItems: const [
            'Personal background',
            'Education history',
            'Employment information',
            'Survey answers arranged for office filing',
          ],
          bestFor: 'Registrar handoff, archiving, and detailed CHED data review.',
          limitation:
              'This is a workbook, not the official fillable PDF form. Use “Official '
              'fillable PDFs” if you need individual forms.',
        ),
      ),
      _ReportSpec(
        kind: SurveyExportReportKind.chedFillable,
        title: 'Official fillable PDFs',
        subtitle: 'One official CHED form per graduate who submitted, in a ZIP folder',
        icon: Icons.picture_as_pdf_outlined,
        formats: const {SurveyExportFormat.pdf},
        formatHint: 'Downloads a ZIP folder of filled PDF forms.',
        details: _exportDetails(
          definition:
              'Creates the official CHED tracer PDF form for each graduate who already '
              'submitted, then downloads them together in one ZIP folder.',
          includeItems: const [
            'One filled form per submitted graduate',
            'Answers taken from this survey',
            'Missing blanks may be completed from their profile when available',
          ],
          bestFor: 'Printing, filing, or submitting individual official tracer forms.',
          limitation:
              'Large groups are limited to 100 forms at a time. Export again for the '
              'next group if needed. Forms that cannot be filled are skipped.',
        ),
      ),
    ],
    _ReportSpec(
      kind: SurveyExportReportKind.pending,
      title: 'Pending list',
      subtitle: 'Alumni invited to this survey who have not finished yet',
      icon: Icons.person_off_outlined,
      formats: const {
        SurveyExportFormat.pdf,
        SurveyExportFormat.excel,
        SurveyExportFormat.csv,
        SurveyExportFormat.print,
      },
      formatHint: 'Useful when sending reminders or following up.',
      details: _exportDetails(
        definition:
            'A contact list of alumni who were invited but still have not submitted '
            'this survey.',
        includeItems: const [
          'Name and email',
          'Course and batch year',
          'Invitation status',
          'When they were assigned',
          'How many reminders were sent',
        ],
        bestFor: 'Follow-ups, reminder messages, and improving response rates.',
        limitation:
            'People who already submitted are not included. The list is empty if '
            'everyone has finished.',
      ),
    ),
  ];

  return showAdminDialogSurface<SurveyExportChoice>(
    context: context,
    maxWidth: 460,
    maxHeight: showCohortFilters ? 640 : 560,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Download / export',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AdminSurveyTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick what you need first, then choose how to save or print it.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AdminSurveyTheme.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '1. What do you need?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminSurveyTheme.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.showCohortFilters ? 180 : 220,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = widget.reports[i];
                final selected = r.kind == _report;
                return Material(
                  color: selected
                      ? AdminSurveyTheme.primary.withValues(alpha: 0.06)
                      : AdminSurveyTheme.surface,
                  borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(AdminSurveyTheme.radiusMd),
                    onTap: () {
                      setState(() {
                        _report = r.kind;
                        if (_format == null ||
                            !r.formats.contains(_format)) {
                          _format = _preferredFormat(r);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AdminSurveyTheme.radiusMd),
                        border: Border.all(
                          color: selected
                              ? AdminSurveyTheme.primary
                              : AdminSurveyTheme.border,
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
                                  ? AdminSurveyTheme.primary
                                      .withValues(alpha: 0.1)
                                  : AdminSurveyTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              r.icon,
                              size: 18,
                              color: selected
                                  ? AdminSurveyTheme.primary
                                  : AdminSurveyTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? AdminSurveyTheme.primary
                                        : AdminSurveyTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  r.subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: AdminSurveyTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!selected)
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
                                color: AdminSurveyTheme.textMuted,
                              ),
                              onPressed: () => _showReportDetails(r),
                            )
                          else
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: AdminSurveyTheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.showCohortFilters) ...[
            const SizedBox(height: 16),
            const Text(
              '2. Limit by batch or course (optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminSurveyTheme.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Optional — leave as All to include everyone.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminSurveyTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminSurveyTheme.surface,
                borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
                border: Border.all(color: AdminSurveyTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ExportCohortDropdown(
                      id: 'batch',
                      value: _batchYear,
                      hint: 'All batches',
                      items: widget.batchOptions,
                      onChanged: (v) => setState(() => _batchYear = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExportCohortDropdown(
                      id: 'course',
                      value: _course,
                      hint: 'All courses',
                      items: widget.courseOptions,
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminSurveyTheme.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          if (spec.formatHint != null) ...[
            const SizedBox(height: 4),
            Text(
              spec.formatHint!,
              style: const TextStyle(
                fontSize: 12,
                color: AdminSurveyTheme.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in SurveyExportFormat.values)
                _FormatChip(
                  label: _report == SurveyExportReportKind.chedFillable &&
                          f == SurveyExportFormat.pdf
                      ? 'ZIP'
                      : _formatLabel(f),
                  icon: _report == SurveyExportReportKind.chedFillable &&
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
            const Text(
              'No submitted responses yet for this report.',
              style: TextStyle(
                fontSize: 12.5,
                color: AdminSurveyTheme.warning,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
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
                  _format == SurveyExportFormat.print
                      ? 'Print'
                      : 'Download',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminSurveyTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportCohortDropdown extends StatelessWidget {
  const _ExportCohortDropdown({
    required this.id,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String id;
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AdminSurveyTheme.radiusSm);
    return DropdownButtonFormField<String?>(
      key: ValueKey('export-$id-$value'),
      initialValue: value,
      isExpanded: true,
      isDense: true,
      iconSize: 18,
      borderRadius: radius,
      style: const TextStyle(
        fontSize: 13,
        color: AdminSurveyTheme.textPrimary,
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 18,
        color: AdminSurveyTheme.textMuted,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AdminSurveyTheme.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AdminSurveyTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AdminSurveyTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(
            color: AdminSurveyTheme.primary,
            width: 1.4,
          ),
        ),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            hint,
            style: const TextStyle(color: AdminSurveyTheme.textMuted),
          ),
        ),
        for (final item in items)
          DropdownMenuItem<String?>(
            value: item,
            child: Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AdminSurveyTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AdminSurveyTheme.textMuted,
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AdminSurveyTheme.primary,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                if (bullets != null && bullets.isNotEmpty)
                  ...[
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
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: AdminSurveyTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]
                else if (section.body.isNotEmpty)
                  Text(
                    section.body,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AdminSurveyTheme.textSecondary,
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
