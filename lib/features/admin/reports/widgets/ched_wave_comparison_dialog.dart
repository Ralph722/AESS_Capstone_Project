import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/reports/application/ched_wave_comparison.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Result of the CHED wave comparison picker.
class ChedWaveComparisonSelection {
  const ChedWaveComparisonSelection({
    required this.surveys,
    this.batchYear,
    this.course,
  });

  final List<Survey> surveys;
  final String? batchYear;
  final String? course;
}

/// Multi-select Official CHED GTS waves (min 2, max 8) + optional cohort filters.
Future<ChedWaveComparisonSelection?> showChedWaveComparisonDialog({
  required BuildContext context,
  required List<Survey> chedWaves,
  required List<String> batchYears,
  String? initialBatchYear,
  String? initialCourse,
}) {
  return showDialog<ChedWaveComparisonSelection>(
    context: context,
    builder: (ctx) => _ChedWaveComparisonDialog(
      chedWaves: chedWaves,
      batchYears: batchYears,
      initialBatchYear: initialBatchYear,
      initialCourse: initialCourse,
    ),
  );
}

class _ChedWaveComparisonDialog extends StatefulWidget {
  const _ChedWaveComparisonDialog({
    required this.chedWaves,
    required this.batchYears,
    this.initialBatchYear,
    this.initialCourse,
  });

  final List<Survey> chedWaves;
  final List<String> batchYears;
  final String? initialBatchYear;
  final String? initialCourse;

  @override
  State<_ChedWaveComparisonDialog> createState() =>
      _ChedWaveComparisonDialogState();
}

class _ChedWaveComparisonDialogState extends State<_ChedWaveComparisonDialog> {
  late final Set<String> _selectedIds;
  String? _batchYear;
  String? _course;

  @override
  void initState() {
    super.initState();
    _batchYear = widget.initialBatchYear;
    _course = widget.initialCourse;

    final sorted = List<Survey>.from(widget.chedWaves)
      ..sort((a, b) {
        final aAt = a.publishedAt ?? a.openAt ?? a.createdAt;
        final bAt = b.publishedAt ?? b.openAt ?? b.createdAt;
        return bAt.compareTo(aAt); // newest first in UI
      });

    _selectedIds = {for (final s in sorted.take(2)) s.id};
  }

  bool get _canConfirm =>
      _selectedIds.length >= 2 &&
      _selectedIds.length <= ChedWaveComparisonReport.maxWaves;

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < ChedWaveComparisonReport.maxWaves) {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    final sorted = List<Survey>.from(widget.chedWaves)
      ..sort((a, b) {
        final aAt = a.publishedAt ?? a.openAt ?? a.createdAt;
        final bAt = b.publishedAt ?? b.openAt ?? b.createdAt;
        return bAt.compareTo(aAt);
      });

    return AlertDialog(
      title: const Text('CHED wave comparison'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select 2–8 published Official CHED GTS waves that already have '
              'submitted responses. The report compares employment, degree '
              'alignment, and other crucial fields across those waves.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AdminReportsTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
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
                const SizedBox(width: 10),
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
            const SizedBox(height: 12),
            Text(
              '${_selectedIds.length} selected · max ${ChedWaveComparisonReport.maxWaves}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminReportsTheme.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            if (sorted.length < 2)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Need at least two Official CHED GTS waves with submitted '
                  'responses to build a comparison.',
                  style: TextStyle(color: AdminReportsTheme.warning),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = sorted[index];
                    final when = s.publishedAt ?? s.openAt ?? s.createdAt;
                    final selected = _selectedIds.contains(s.id);
                    final atCap =
                        !selected &&
                        _selectedIds.length >=
                            ChedWaveComparisonReport.maxWaves;
                    return CheckboxListTile(
                      dense: true,
                      value: selected,
                      onChanged: atCap ? null : (_) => _toggle(s.id),
                      title: Text(
                        s.title.trim().isEmpty
                            ? 'Official CHED GTS'
                            : s.title.trim(),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${dateFmt.format(when)} · ${s.status.name} · '
                        '${s.responseCount} submitted',
                        style: const TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !_canConfirm
              ? null
              : () {
                  final picked = sorted
                      .where((s) => _selectedIds.contains(s.id))
                      .toList();
                  Navigator.pop(
                    context,
                    ChedWaveComparisonSelection(
                      surveys: picked,
                      batchYear: _batchYear,
                      course: _course,
                    ),
                  );
                },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
