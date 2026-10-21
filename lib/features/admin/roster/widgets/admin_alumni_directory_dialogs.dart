import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_form_layout.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

const _dialogTitleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: AdminColors.textPrimary,
);

const _dialogMessageStyle = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: AdminColors.textSecondary,
);

Widget _dialogIconBox(IconData icon, {bool destructive = false}) {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: destructive ? AdminColors.dangerBg : AdminColors.infoBg,
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
    ),
    child: Icon(
      icon,
      size: 20,
      color: destructive ? AdminColors.danger : AdminColors.primary,
    ),
  );
}

/// Title text for the CHED progress and import-issues alert dialogs.
Text directoryDialogTitle(String text) => Text(text, style: _dialogTitleStyle);

/// Shape for plain [AlertDialog]s opened from the directory.
final directoryAlertDialogShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AdminSurfaces.radiusLg),
);

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
        backgroundColor: AdminColors.card,
        surfaceTintColor: Colors.transparent,
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
                          Text('Add alumni', style: _dialogTitleStyle),
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
    final years =
        widget.members
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

  List<AlumniMember> get _eligible => _filtered
      .where((m) => m.isRegisteredUser && (m.authUid?.isNotEmpty ?? false))
      .toList();

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
      backgroundColor: AdminColors.card,
      surfaceTintColor: Colors.transparent,
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
                          style: _dialogTitleStyle,
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
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: AdminButtonStyles.outlined(),
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
                    style: AdminButtonStyles.filled(),
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

/// Values typed into the roster entry dialog (normalized by the service).
class RosterEntryInput {
  const RosterEntryInput({
    required this.fullName,
    required this.course,
    required this.studentId,
    required this.yearGraduated,
  });

  final String fullName;
  final String course;
  final String studentId;
  final String yearGraduated;
}

/// Add or edit one roster entry. [onSubmit] saves and returns null on success
/// or a message to show inside the dialog, which then stays open with the
/// typed values. Resolves to true once saved.
Future<bool> showRosterEntryDialog(
  BuildContext context, {
  AlumniMember? existing,
  required Future<String?> Function(RosterEntryInput input) onSubmit,
}) async {
  final saved = await showAdminDialogSurface<bool>(
    context: context,
    maxWidth: kAdminDialogSm,
    child: RosterEntryDialog(existing: existing, onSubmit: onSubmit),
  );
  return saved ?? false;
}

class RosterEntryDialog extends StatefulWidget {
  const RosterEntryDialog({super.key, this.existing, required this.onSubmit});

  final AlumniMember? existing;
  final Future<String?> Function(RosterEntryInput input) onSubmit;

  @override
  State<RosterEntryDialog> createState() => _RosterEntryDialogState();
}

class _RosterEntryDialogState extends State<RosterEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _studentId;
  late final TextEditingController _year;
  String? _course;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.fullName ?? '');
    _studentId = TextEditingController(text: existing?.studentId ?? '');
    _year = TextEditingController(text: existing?.effectiveBatchYear ?? '');
    final course = existing == null
        ? CourseConstants.courses.first
        : CourseConstants.normalize(existing.course);
    _course = CourseConstants.courses.contains(course) ? course : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _year.dispose();
    super.dispose();
  }

  String? _validateName(String? value) =>
      AlumniMemberService.normalizeFullName(value ?? '').isEmpty
      ? 'Enter the full name.'
      : null;

  String? _validateStudentId(String? value) =>
      AlumniMemberService.normalizeStudentId(value ?? '').isEmpty
      ? 'Enter the ID number.'
      : null;

  String? _validateCourse(String? value) =>
      value == null || !CourseConstants.isValid(value)
      ? 'Select a course.'
      : null;

  String? _validateYear(String? value) {
    try {
      AlumniMemberService.normalizeGraduationYear(value ?? '');
      return null;
    } catch (_) {
      return 'Enter a 4-digit year (e.g. 2024) or leave it blank.';
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(
      RosterEntryInput(
        fullName: _name.text,
        course: _course!,
        studentId: _studentId.text,
        yearGraduated: _year.text,
      ),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  InputDecoration _decoration(String label, IconData icon) {
    final radius = BorderRadius.circular(AdminSurfaces.radiusSm);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AdminColors.primary, size: 20),
      filled: true,
      fillColor: AdminColors.background,
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AdminColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AdminColors.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _dialogIconBox(
                  _isEdit ? Icons.edit_outlined : Icons.person_add_alt_1,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      _isEdit ? 'Edit roster entry' : 'Add to official roster',
                      style: _dialogTitleStyle,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Used to validate registration (name, course, and ID must match).',
              style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.dangerBg,
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: AdminColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AdminColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              decoration: _decoration('Full name', Icons.person_outline),
              textCapitalization: TextCapitalization.words,
              validator: _validateName,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _course,
              decoration: _decoration('Course', Icons.school_outlined),
              items: CourseConstants.courses
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _course = v),
              validator: _validateCourse,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _studentId,
              enabled: !_saving,
              decoration: _decoration('ID number', Icons.badge_outlined),
              validator: _validateStudentId,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _year,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: _decoration(
                'Year graduated (optional)',
                Icons.calendar_today_outlined,
              ),
              validator: _validateYear,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: AdminButtonStyles.outlined(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: AdminButtonStyles.filled(),
                  child: _saving
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Saving…'),
                          ],
                        )
                      : Text(_isEdit ? 'Save changes' : 'Add member'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Outcome of the remove dialog. [deactivate] is only offered for members
/// with a registered account.
enum RosterRemoveAction { deactivate, delete }

/// Confirms removing [member]: Cancel, Deactivate (registered only), or
/// Remove account / Delete. Focus starts on Cancel.
Future<RosterRemoveAction?> showRosterRemoveDialog(
  BuildContext context, {
  required AlumniMember member,
}) {
  return showAdminDialogSurface<RosterRemoveAction>(
    context: context,
    maxWidth: 460,
    child: RosterRemoveDialog(member: member),
  );
}

class RosterRemoveDialog extends StatelessWidget {
  const RosterRemoveDialog({super.key, required this.member});

  final AlumniMember member;

  @override
  Widget build(BuildContext context) {
    final registered = member.isRegisteredUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _dialogIconBox(
                registered ? Icons.person_off_outlined : Icons.delete_outline,
                destructive: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    registered
                        ? 'Remove registered alumni?'
                        : 'Delete roster entry?',
                    style: _dialogTitleStyle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            registered
                ? 'Deactivate blocks sign-in and can be undone later. '
                      'Remove account also erases their personal details '
                      '(name, email, contact info, photo) from the portal. '
                      'Their tracer answers stay in the statistics without '
                      'identifying details, and the roster entry stays deactivated. '
                      'This cannot be undone.'
                : 'Remove ${member.fullName} from the official roster? '
                      'They will not be able to register.',
            style: _dialogMessageStyle,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  autofocus: true,
                  onPressed: () => Navigator.of(context).pop(),
                  style: AdminButtonStyles.outlined(),
                  child: const Text('Cancel'),
                ),
                if (registered)
                  OutlinedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(RosterRemoveAction.deactivate),
                    style: AdminButtonStyles.outlined(),
                    child: const Text('Deactivate'),
                  ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(RosterRemoveAction.delete),
                  style: AdminButtonStyles.danger(),
                  child: Text(registered ? 'Remove account' : 'Delete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
