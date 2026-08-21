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
    final active = !filters.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AdminReportsTheme.card,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
        border: Border.all(
          color: active
              ? AdminReportsTheme.primary.withValues(alpha: 0.22)
              : AdminReportsTheme.border,
        ),
        boxShadow: AdminReportsTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminReportsTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: AdminReportsTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cohort filters',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AdminReportsTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Narrow charts by wave, batch, and course',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: AdminReportsTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (hint != null)
                ReportsDetailsButton(
                  title: 'Audience',
                  body: hint,
                  tooltip: 'Audience details',
                ),
              if (active)
                TextButton(
                  onPressed: () => onChanged(ReportsDashboardFilters.empty),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminReportsTheme.primary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'Clear all',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final fields = <Widget>[
                DirectoryFilterField<String?>(
                  label: waveLabel,
                  value: filters.surveyId,
                  minWidth: 160,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(allWavesLabel),
                    ),
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
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All batches'),
                    ),
                    for (final y in {
                      ...batchYears,
                      if (filters.batchYear != null) filters.batchYear!,
                    })
                      DropdownMenuItem(value: y, child: Text(y)),
                  ],
                  onChanged: (v) => onChanged(
                    filters.copyWith(
                      batchYear: v,
                      clearBatch: v == null,
                    ),
                  ),
                ),
                DirectoryFilterField<String?>(
                  label: 'Course',
                  value: filters.course,
                  minWidth: 150,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All courses'),
                    ),
                    for (final c in {
                      ...CourseConstants.courses,
                      if (filters.course != null) filters.course!,
                    })
                      DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => onChanged(
                    filters.copyWith(course: v, clearCourse: v == null),
                  ),
                ),
              ];

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: fields[0]),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: fields[1]),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: fields[2]),
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final f in fields)
                    SizedBox(
                      width: (constraints.maxWidth - 10) / 2 < 160
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2,
                      child: f,
                    ),
                ],
              );
            },
          ),
          if (active) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AdminReportsTheme.border),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AdminReportsTheme.textMuted,
                  ),
                ),
                if (filters.surveyId != null)
                  _ActiveFilterChip(
                    icon: Icons.waves_outlined,
                    label: _selectedSurvey != null
                        ? reportsSurveyFilterLabel(_selectedSurvey!)
                        : 'Wave',
                    onDeleted: () =>
                        onChanged(ReportsDashboardFilters.empty),
                  ),
                if (filters.batchYear != null)
                  _ActiveFilterChip(
                    icon: Icons.calendar_today_outlined,
                    label: 'Batch ${filters.batchYear}',
                    onDeleted: () => onChanged(
                      filters.copyWith(clearBatch: true),
                    ),
                  ),
                if (filters.course != null)
                  _ActiveFilterChip(
                    icon: Icons.school_outlined,
                    label: filters.course!,
                    onDeleted: () => onChanged(
                      filters.copyWith(clearCourse: true),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.icon,
    required this.label,
    required this.onDeleted,
  });

  final IconData icon;
  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminReportsTheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onDeleted,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AdminReportsTheme.primary),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminReportsTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.close_rounded,
                size: 14,
                color: AdminReportsTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
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
