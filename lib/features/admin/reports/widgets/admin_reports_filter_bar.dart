import 'package:flutter/material.dart';

import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Cohort filter bar for Tracer / Survey tabs (wave · batch · course).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AdminReportsTheme.card,
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusLg),
            border: Border.all(color: AdminReportsTheme.border),
            boxShadow: AdminReportsTheme.cardShadow,
          ),
          child: Row(
            children: [
              _label(),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _DropdownField<String?>(
                        label: waveLabel,
                        value: filters.surveyId,
                        width: 220,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(allWavesLabel),
                          ),
                          for (final s in surveys)
                            DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                s.title,
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
                          onChanged(
                            filtersPrefillFromSurvey(filters, selected),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _DropdownField<String?>(
                        label: 'Batch',
                        value: filters.batchYear,
                        width: 130,
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
                      const SizedBox(width: 8),
                      _DropdownField<String?>(
                        label: 'Course',
                        value: filters.course,
                        width: 180,
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
                    ],
                  ),
                ),
              ),
              if (!filters.isEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => onChanged(ReportsDashboardFilters.empty),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminReportsTheme.textSecondary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              hint,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminReportsTheme.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _label() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.tune_outlined,
          size: 16,
          color: AdminReportsTheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          filters.isEmpty ? 'Filters' : 'Filters (${filters.activeCount})',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AdminReportsTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Small scope caption under KPIs / chart sections.
class ReportsScopeCaption extends StatelessWidget {
  const ReportsScopeCaption({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.filter_list_outlined,
            size: 14,
            color: AdminReportsTheme.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 160,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
            borderSide: const BorderSide(color: AdminReportsTheme.border),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            style: const TextStyle(
              fontSize: 13,
              color: AdminReportsTheme.textPrimary,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
