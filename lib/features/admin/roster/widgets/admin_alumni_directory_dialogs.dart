import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';

/// Result from the CHED bulk export confirmation dialog.
class ChedBulkExportChoice {
  const ChedBulkExportChoice({
    required this.members,
    required this.flattenFields,
  });

  final List<AlumniMember> members;
  final bool flattenFields;
}

/// Polished chooser: add one alumni manually, or import from Excel.
Future<void> showAlumniAddChooserDialog(
  BuildContext context, {
  required VoidCallback onAddManually,
  required VoidCallback onImportFile,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusLg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AdminDirectoryTheme.infoBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_outlined,
                        color: AdminDirectoryTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add alumni',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AdminDirectoryTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Choose how you want to add to the roster.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AdminDirectoryTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ChooserOptionCard(
                  icon: Icons.edit_outlined,
                  title: 'Add manually',
                  subtitle: 'Enter one alumni record in a form.',
                  onTap: () {
                    Navigator.pop(ctx);
                    onAddManually();
                  },
                ),
                const SizedBox(height: 10),
                _ChooserOptionCard(
                  icon: Icons.upload_file_outlined,
                  title: 'Import from file',
                  subtitle:
                      'Upload an Excel file (Full Name, Course, ID Number, optional Year Graduated).',
                  onTap: () {
                    Navigator.pop(ctx);
                    onImportFile();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ChooserOptionCard extends StatefulWidget {
  const _ChooserOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_ChooserOptionCard> createState() => _ChooserOptionCardState();
}

class _ChooserOptionCardState extends State<_ChooserOptionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hovered
                  ? AdminDirectoryTheme.infoBg
                  : AdminDirectoryTheme.background,
              borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusMd),
              border: Border.all(
                color: _hovered
                    ? AdminDirectoryTheme.primary.withValues(alpha: 0.35)
                    : AdminDirectoryTheme.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminDirectoryTheme.border),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: AdminDirectoryTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminDirectoryTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AdminDirectoryTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AdminDirectoryTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the filtered CHED GTS ZIP export dialog. Returns null if cancelled.
Future<ChedBulkExportChoice?> showChedBulkExportDialog(
  BuildContext context, {
  required List<AlumniMember> members,
}) {
  return showDialog<ChedBulkExportChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ChedBulkExportDialog(members: members),
  );
}

class _ChedBulkExportDialog extends StatefulWidget {
  const _ChedBulkExportDialog({required this.members});

  final List<AlumniMember> members;

  @override
  State<_ChedBulkExportDialog> createState() => _ChedBulkExportDialogState();
}

class _ChedBulkExportDialogState extends State<_ChedBulkExportDialog> {
  String? _course;
  String? _batch;
  bool _flattenFields = true;

  List<String> get _batchOptions {
    final years = widget.members
        .map((m) => m.effectiveBatchYear)
        .where((y) => y.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  List<String> get _courseOptions {
    final fromRoster = widget.members
        .map((m) => m.course.trim())
        .where((c) => c.isNotEmpty)
        .toSet();
    final ordered = <String>[
      ...CourseConstants.courses.where(fromRoster.contains),
      ...fromRoster.where((c) => !CourseConstants.courses.contains(c)).toList()
        ..sort(),
    ];
    return ordered;
  }

  /// Candidates after course/batch filters (deactivated excluded).
  List<AlumniMember> get _filtered {
    return widget.members.where((m) {
      if (m.isDeactivated) return false;
      if (_course != null && m.course.trim() != _course) return false;
      if (_batch != null && m.effectiveBatchYear != _batch) return false;
      return true;
    }).toList();
  }

  List<AlumniMember> get _eligible =>
      _filtered.where((m) => m.isRegisteredUser && (m.authUid?.isNotEmpty ?? false)).toList();

  int get _skippedUnregistered => _filtered.length - _eligible.length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final eligible = _eligible;
    final overCap = eligible.length > ChedGtsPdfExportLimits.maxBatchSize;
    final warnLarge =
        eligible.length >= ChedGtsPdfExportLimits.batchWarnSize && !overCap;
    final canExport = eligible.isNotEmpty && !overCap;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AdminDirectoryTheme.infoBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AdminDirectoryTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export official CHED GTS PDFs',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AdminDirectoryTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Build a ZIP of filled official forms. Members without '
                          'a registered account or CHED records are skipped.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AdminDirectoryTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DirectoryFilterField<String?>(
                      label: 'Course',
                      value: _course,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All courses'),
                        ),
                        ..._courseOptions.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _course = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DirectoryFilterField<String?>(
                      label: 'Batch',
                      value: _batch,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All batches'),
                        ),
                        ..._batchOptions.map(
                          (b) => DropdownMenuItem(value: b, child: Text(b)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _batch = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ExportCountPanel(
                matched: filtered.length,
                eligible: eligible.length,
                skipped: _skippedUnregistered,
                overCap: overCap,
                warnLarge: warnLarge,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _flattenFields,
                onChanged: (v) => setState(() => _flattenFields = v == true),
                title: const Text(
                  'Print-Ready PDF (flatten fields)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AdminDirectoryTheme.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Recommended for printing and archival. Uncheck for editable Fillable PDFs.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AdminDirectoryTheme.textSecondary,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AdminDirectoryTheme.primary,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: !canExport
                        ? null
                        : () => Navigator.pop(
                              context,
                              ChedBulkExportChoice(
                                members: eligible,
                                flattenFields: _flattenFields,
                              ),
                            ),
                    icon: const Icon(Icons.folder_zip_outlined, size: 18),
                    label: Text(
                      eligible.isEmpty
                          ? 'Nothing to export'
                          : 'Export ZIP (${eligible.length})',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminDirectoryTheme.primary,
                      disabledBackgroundColor:
                          AdminDirectoryTheme.border.withValues(alpha: 0.7),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportCountPanel extends StatelessWidget {
  const _ExportCountPanel({
    required this.matched,
    required this.eligible,
    required this.skipped,
    required this.overCap,
    required this.warnLarge,
  });

  final int matched;
  final int eligible;
  final int skipped;
  final bool overCap;
  final bool warnLarge;

  @override
  Widget build(BuildContext context) {
    final bg = overCap
        ? AdminDirectoryTheme.dangerBg
        : warnLarge
        ? AdminDirectoryTheme.warningBg
        : AdminDirectoryTheme.infoBg;
    final accent = overCap
        ? AdminDirectoryTheme.danger
        : warnLarge
        ? AdminDirectoryTheme.warning
        : AdminDirectoryTheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  overCap
                      ? ChedGtsPdfExportLimits.batchCapMessage(eligible)
                      : warnLarge
                      ? 'Large batch — keep this tab open; export may take several minutes.'
                      : 'Live preview of who will be included in this ZIP.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(label: 'Matched filters', value: '$matched'),
              _StatPill(
                label: 'Will export',
                value: '$eligible',
                emphasis: true,
              ),
              _StatPill(label: 'Will skip', value: '$skipped'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasis
              ? AdminDirectoryTheme.primary.withValues(alpha: 0.3)
              : AdminDirectoryTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AdminDirectoryTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: emphasis
                  ? AdminDirectoryTheme.primary
                  : AdminDirectoryTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
