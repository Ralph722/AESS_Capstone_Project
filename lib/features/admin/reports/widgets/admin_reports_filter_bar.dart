import 'package:flutter/material.dart';

import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Cohort filter bar for Tracer / Survey tabs (wave · batch · course).
///
/// Matches Alumni Directory toolbar density: white surface card, filled
/// [DirectoryFilterField] controls, and removable active chips.
class ReportsCohortFilterBar extends StatelessWidget {
  const ReportsCohortFilterBar({
    super.key,
    required this.filters,
    required this.surveys,
    required this.batchYears,
    required this.onChanged,
    this.waveLabel = 'Survey wave',
    this.allWavesLabel = 'All published waves',
  });

  final ReportsDashboardFilters filters;
  final List<Survey> surveys;
  final List<String> batchYears;
  final ValueChanged<ReportsDashboardFilters> onChanged;
  final String waveLabel;
  final String allWavesLabel;

  Survey? get _selectedSurvey {
    final id = filters.surveyId;
    if (id == null) return null;
    for (final s in surveys) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hint = reportsAudienceHint(_selectedSurvey);
    final activeCount = [
      filters.surveyId,
      filters.batchYear,
      filters.course,
    ].where((v) => v != null).length;
    final active = activeCount > 0;
    final fields = _fields();
    final actions = <Widget>[
      if (hint != null)
        ReportsDetailsButton(
          title: 'Audience',
          body: hint,
          tooltip: 'Audience details',
        ),
      if (active)
        TextButton.icon(
          onPressed: () => onChanged(ReportsDashboardFilters.empty),
          style: TextButton.styleFrom(
            foregroundColor: AdminReportsTheme.primary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 32),
          ),
          icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
          label: const Text(
            'Clear all',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminReportsTheme.border),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: _leading(activeCount),
                ),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: fields[0]),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: fields[1]),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: fields[2]),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  ...actions,
                ],
              ],
            );
          }

          final half = (constraints.maxWidth - 10) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _leading(activeCount)),
                  ...actions,
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final f in fields)
                    SizedBox(
                      width: half < 160 ? constraints.maxWidth : half,
                      child: f,
                    ),
                ],
              ),
              if (active) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (filters.surveyId != null)
                      DirectoryActiveFilterChip(
                        icon: Icons.waves_outlined,
                        label: _selectedSurvey != null
                            ? reportsSurveyFilterLabel(_selectedSurvey!)
                            : 'Wave',
                        onRemoved: () =>
                            onChanged(ReportsDashboardFilters.empty),
                      ),
                    if (filters.batchYear != null)
                      DirectoryActiveFilterChip(
                        icon: Icons.calendar_today_outlined,
                        label: 'Batch ${filters.batchYear}',
                        onRemoved: () =>
                            onChanged(filters.copyWith(clearBatch: true)),
                      ),
                    if (filters.course != null)
                      DirectoryActiveFilterChip(
                        icon: Icons.school_outlined,
                        label: filters.course!,
                        onRemoved: () =>
                            onChanged(filters.copyWith(clearCourse: true)),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _leading(int activeCount) {
    final active = activeCount > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active
                ? AdminReportsTheme.primary
                : AdminReportsTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 17,
            color: active ? AdminReportsTheme.gold : AdminReportsTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cohort filters',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AdminReportsTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                active ? '$activeCount active' : 'Showing all data',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active
                      ? AdminReportsTheme.primary
                      : AdminReportsTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _fields() {
    return [
      DirectoryFilterField<String?>(
        label: waveLabel,
        value: filters.surveyId,
        minWidth: 160,
        items: [
          DropdownMenuItem(value: null, child: Text(allWavesLabel)),
          for (final s in surveys)
            DropdownMenuItem(
              value: s.id,
              child: Text(
                reportsSurveyFilterLabel(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) {
          if (id == null) {
            onChanged(ReportsDashboardFilters.empty);
            return;
          }
          Survey? selected;
          for (final s in surveys) {
            if (s.id == id) {
              selected = s;
              break;
            }
          }
          onChanged(filtersPrefillFromSurvey(filters, selected));
        },
      ),
      DirectoryFilterField<String?>(
        label: 'Batch',
        value: filters.batchYear,
        minWidth: 120,
        items: [
          const DropdownMenuItem(value: null, child: Text('All batches')),
          for (final y in {
            ...batchYears,
            if (filters.batchYear != null) filters.batchYear!,
          })
            DropdownMenuItem(value: y, child: Text(y)),
        ],
        onChanged: (v) =>
            onChanged(filters.copyWith(batchYear: v, clearBatch: v == null)),
      ),
      DirectoryFilterField<String?>(
        label: 'Course',
        value: filters.course,
        minWidth: 150,
        items: [
          const DropdownMenuItem(value: null, child: Text('All courses')),
          for (final c in {
            ...CourseConstants.courses,
            if (filters.course != null) filters.course!,
          })
            DropdownMenuItem(
              value: c,
              child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) =>
            onChanged(filters.copyWith(course: v, clearCourse: v == null)),
      ),
    ];
  }
}

/// Soft scope pill under KPIs / chart sections.
class ReportsScopeCaption extends StatelessWidget {
  const ReportsScopeCaption({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  text,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AdminReportsTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
