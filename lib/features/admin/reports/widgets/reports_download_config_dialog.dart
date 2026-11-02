import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:alumni_system/features/admin/reports/models/report_filter_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_downloads_panel.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Result of the Downloads configure dialog.
class ReportsDownloadConfigResult {
  const ReportsDownloadConfigResult({
    required this.filters,
    required this.format,
    required this.printPreview,
  });

  final ReportFilterSelection filters;
  final CustomReportFormat format;
  final bool printPreview;
}

/// Per-card filter + format confirmation before an institutional download.
Future<ReportsDownloadConfigResult?> showReportsDownloadConfigDialog({
  required BuildContext context,
  required ReportsDownloadPreset preset,
  required CustomReportFormat initialFormat,
  required bool printPreview,
  required List<String> batchYears,
  required List<Survey> chedWaves,
  ReportFilterSelection initialFilters = ReportFilterSelection.empty,
}) {
  final schema = ReportFilterSchemas.forDownloadsPreset(preset.id) ??
      ReportFilterSchema(
        catalogId: preset.catalogId ?? preset.id,
        supported: const {
          ReportFilterKey.batchYear,
          ReportFilterKey.course,
        },
      );

  return showDialog<ReportsDownloadConfigResult>(
    context: context,
    builder: (ctx) => _ReportsDownloadConfigDialog(
      preset: preset,
      schema: schema,
      initialFormat: initialFormat,
      printPreview: printPreview,
      batchYears: batchYears,
      chedWaves: chedWaves,
      initialFilters: initialFilters.constrainedTo(schema),
    ),
  );
}

class _ReportsDownloadConfigDialog extends StatefulWidget {
  const _ReportsDownloadConfigDialog({
    required this.preset,
    required this.schema,
    required this.initialFormat,
    required this.printPreview,
    required this.batchYears,
    required this.chedWaves,
    required this.initialFilters,
  });

  final ReportsDownloadPreset preset;
  final ReportFilterSchema schema;
  final CustomReportFormat initialFormat;
  final bool printPreview;
  final List<String> batchYears;
  final List<Survey> chedWaves;
  final ReportFilterSelection initialFilters;

  @override
  State<_ReportsDownloadConfigDialog> createState() =>
      _ReportsDownloadConfigDialogState();
}

class _ReportsDownloadConfigDialogState
    extends State<_ReportsDownloadConfigDialog> {
  late String? _batchYear;
  late String? _course;
  late Set<String> _waveIds;
  late String? _surveyType;
  late CustomReportRegistrationFilter _registration;
  late CustomReportTracerFilter _tracer;
  late CustomReportEmploymentFilter _employment;
  late CustomReportFormat _format;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;
    _batchYear = f.batchYear;
    _course = f.course;
    _waveIds = {...f.surveyIds};
    if (_waveIds.isEmpty && f.surveyId != null) {
      _waveIds = {f.surveyId!};
    }
    _surveyType = f.surveyType ??
        (widget.preset.id == 'program_cohort_comparison' ? 'course' : null);
    _registration = CustomReportRegistrationFilter.all;
    _tracer = CustomReportTracerFilter.all;
    _employment = CustomReportEmploymentFilter.all;
    _format = widget.initialFormat;
  }

  ReportFilterSelection get _selection => ReportFilterSelection(
        batchYear: _batchYear,
        course: _course,
        surveyIds: _waveIds.toList(growable: false),
        surveyId: _waveIds.length == 1 ? _waveIds.first : null,
        surveyType: _surveyType,
      ).constrainedTo(widget.schema);

  String get _privacyLabel {
    final entry = widget.preset.catalogId == null
        ? null
        : AessReportCatalog.byId(widget.preset.catalogId!);
    return switch (entry?.privacy) {
      ReportPrivacyClass.aggregated => 'Aggregated — no personal names',
      ReportPrivacyClass.restrictedFollowUp => 'Restricted follow-up list',
      _ => 'May include personal alumni data',
    };
  }

  void _toggleWave(String id) {
    setState(() {
      if (_waveIds.contains(id)) {
        _waveIds.remove(id);
      } else {
        _waveIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final schema = widget.schema;
    final dateFmt = DateFormat.yMMMd();
    final sortedWaves = List<Survey>.from(widget.chedWaves)
      ..sort((a, b) {
        final aAt = a.publishedAt ?? a.openAt ?? a.createdAt;
        final bAt = b.publishedAt ?? b.openAt ?? b.createdAt;
        return bAt.compareTo(aAt);
      });

    return AlertDialog(
      shape: AdminDialogStandards.shape,
      backgroundColor: AdminDialogStandards.backgroundColor,
      surfaceTintColor: Colors.transparent,
      insetPadding: AdminDialogStandards.defaultInsetPadding,
      contentPadding: AdminDialogStandards.defaultContentPadding,
      titlePadding: EdgeInsets.zero,
      actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      title: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
        child: AdminModalHeader(
          title: widget.preset.title,
          subtitle: 'Confirm scope, then download ${widget.printPreview ? 'for print' : _format.label}.',
          icon: widget.preset.icon,
          onClose: () => Navigator.pop(context),
        ),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1, color: AdminColors.border),
              const SizedBox(height: 12),
              Text(
                widget.preset.scopeNote ??
                    AessReportCatalog.institutionalScopeBadge,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _privacyLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _privacyLabel.startsWith('Aggregated')
                      ? AdminReportsTheme.textMuted
                      : AdminColors.warning,
                ),
              ),
              if (schema.notes != null && schema.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  schema.notes!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AdminReportsTheme.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (widget.preset.id == 'program_cohort_comparison') ...[
                DirectoryFilterField<String>(
                  label: 'Compare by',
                  value: _surveyType == 'batch' ? 'batch' : 'course',
                  items: const [
                    DropdownMenuItem(value: 'course', child: Text('Course / program')),
                    DropdownMenuItem(
                      value: 'batch',
                      child: Text('Graduation batch'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _surveyType = v);
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (schema.supports(ReportFilterKey.batchYear) ||
                  schema.supports(ReportFilterKey.course))
                Row(
                  children: [
                    if (schema.supports(ReportFilterKey.batchYear))
                      Expanded(
                        child: DirectoryFilterField<String?>(
                          label: 'Batch',
                          value: _batchYear,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All batches'),
                            ),
                            for (final b in widget.batchYears)
                              DropdownMenuItem(value: b, child: Text(b)),
                          ],
                          onChanged: (v) => setState(() => _batchYear = v),
                        ),
                      ),
                    if (schema.supports(ReportFilterKey.batchYear) &&
                        schema.supports(ReportFilterKey.course))
                      const SizedBox(width: 10),
                    if (schema.supports(ReportFilterKey.course))
                      Expanded(
                        child: DirectoryFilterField<String?>(
                          label: 'Course',
                          value: _course,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All courses'),
                            ),
                            for (final c in CourseConstants.courses)
                              DropdownMenuItem(value: c, child: Text(c)),
                          ],
                          onChanged: (v) => setState(() => _course = v),
                        ),
                      ),
                  ],
                ),
              if (schema.supports(ReportFilterKey.registrationStatus)) ...[
                const SizedBox(height: 10),
                DirectoryFilterField<CustomReportRegistrationFilter>(
                  label: 'Registration',
                  value: _registration,
                  items: [
                    for (final v in CustomReportRegistrationFilter.values)
                      DropdownMenuItem(
                        value: v,
                        child: Text(switch (v) {
                          CustomReportRegistrationFilter.all => 'All',
                          CustomReportRegistrationFilter.registeredOnly =>
                            'Registered only',
                          CustomReportRegistrationFilter.unregisteredOnly =>
                            'Unregistered only',
                        }),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _registration = v);
                  },
                ),
              ],
              if (schema.supports(ReportFilterKey.tracerStatus)) ...[
                const SizedBox(height: 10),
                DirectoryFilterField<CustomReportTracerFilter>(
                  label: 'Tracer',
                  value: _tracer,
                  items: [
                    for (final v in CustomReportTracerFilter.values)
                      DropdownMenuItem(
                        value: v,
                        child: Text(switch (v) {
                          CustomReportTracerFilter.all => 'All',
                          CustomReportTracerFilter.completeOnly =>
                            'Tracer complete',
                          CustomReportTracerFilter.incompleteOnly =>
                            'Tracer incomplete',
                        }),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _tracer = v);
                  },
                ),
              ],
              if (schema.supports(ReportFilterKey.employmentStatus)) ...[
                const SizedBox(height: 10),
                DirectoryFilterField<CustomReportEmploymentFilter>(
                  label: 'Employment',
                  value: _employment,
                  items: [
                    for (final v in CustomReportEmploymentFilter.values)
                      DropdownMenuItem(
                        value: v,
                        child: Text(switch (v) {
                          CustomReportEmploymentFilter.all => 'All',
                          CustomReportEmploymentFilter.employedOnly =>
                            'Employed only',
                          CustomReportEmploymentFilter.unemployedOnly =>
                            'Not employed',
                        }),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _employment = v);
                  },
                ),
              ],
              if (schema.supports(ReportFilterKey.surveyWaves) ||
                  schema.supports(ReportFilterKey.surveyWave)) ...[
                const SizedBox(height: 14),
                Text(
                  schema.supports(ReportFilterKey.surveyWaves)
                      ? 'Official CHED waves (optional — empty = all)'
                      : 'Official CHED wave',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AdminReportsTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (sortedWaves.isEmpty)
                  const Text(
                    'No Official CHED waves with submissions yet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminReportsTheme.warning,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sortedWaves.length,
                      itemBuilder: (context, i) {
                        final s = sortedWaves[i];
                        final selected = _waveIds.contains(s.id);
                        final stamp = dateFmt.format(
                          s.publishedAt ?? s.openAt ?? s.createdAt,
                        );
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected,
                          onChanged: (_) => _toggleWave(s.id),
                          title: Text(
                            s.title.trim().isEmpty ? 'Untitled' : s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            stamp,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
              ],
              if (!widget.printPreview) ...[
                const SizedBox(height: 14),
                const Text(
                  'Format',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AdminReportsTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in CustomReportFormat.values)
                      ChoiceChip(
                        label: Text(f.label),
                        selected: _format == f,
                        onSelected: (_) => setState(() => _format = f),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: AdminButtonStyles.filled(),
          onPressed: () {
            var selection = _selection;
            // Attach registration/tracer/employment via CustomReportFilters later;
            // stash encoded names on unused string fields when supported.
            if (schema.supports(ReportFilterKey.registrationStatus) ||
                schema.supports(ReportFilterKey.tracerStatus) ||
                schema.supports(ReportFilterKey.employmentStatus)) {
              selection = selection.copyWith(
                registrationStatus: schema.supports(
                  ReportFilterKey.registrationStatus,
                )
                    ? _registration.name
                    : null,
                tracerStatus: schema.supports(ReportFilterKey.tracerStatus)
                    ? _tracer.name
                    : null,
                employmentStatus:
                    schema.supports(ReportFilterKey.employmentStatus)
                        ? _employment.name
                        : null,
              );
            }
            Navigator.pop(
              context,
              ReportsDownloadConfigResult(
                filters: selection,
                format: _format,
                printPreview: widget.printPreview,
              ),
            );
          },
          icon: Icon(
            widget.printPreview ? Icons.print_outlined : Icons.download_outlined,
            size: 18,
          ),
          label: Text(widget.printPreview ? 'Print' : 'Download'),
        ),
      ],
    );
  }
}
