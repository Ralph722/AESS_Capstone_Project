import 'package:flutter/material.dart';

import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_details_button.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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
        OutlinedButton.icon(
          onPressed: () => onChanged(ReportsDashboardFilters.empty),
          icon: const Icon(Icons.filter_alt_off_outlined, size: 13),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminColors.textSecondary,
            side: BorderSide(color: AdminColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            ),
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: _leading(activeCount),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: fields[0]),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: fields[1]),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: fields[2]),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ...actions,
                    ],
                  ],
                ),
                if (active) ...[
                  const SizedBox(height: 8),
                  _buildActiveChips(),
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
                const SizedBox(height: 8),
                _buildActiveChips(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Active:',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AdminColors.textMuted,
          ),
        ),
        if (filters.surveyId != null)
          DirectoryActiveFilterChip(
            icon: Icons.waves_outlined,
            label: _selectedSurvey != null
                ? reportsSurveyFilterLabel(_selectedSurvey!)
                : 'Wave',
            onRemoved: () => onChanged(ReportsDashboardFilters.empty),
          ),
        if (filters.batchYear != null)
          DirectoryActiveFilterChip(
            icon: Icons.calendar_today_outlined,
            label: 'Batch ${filters.batchYear}',
            onRemoved: () => onChanged(filters.copyWith(clearBatch: true)),
          ),
        if (filters.course != null)
          DirectoryActiveFilterChip(
            icon: Icons.school_outlined,
            label: filters.course!,
            onRemoved: () => onChanged(filters.copyWith(clearCourse: true)),
          ),
      ],
    );
  }

  Widget _leading(int activeCount) {
    final active = activeCount > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.tune_rounded,
          size: 16,
          color: active ? AdminColors.primary : AdminColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          'Filters',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminColors.textPrimary,
          ),
        ),
        if (active) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AdminColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$activeCount',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AdminColors.primary,
              ),
            ),
          ),
        ],
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
