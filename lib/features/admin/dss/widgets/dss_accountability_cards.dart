import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';

InputDecoration _decoration(String label, {String? helper, String? error}) {
  final radius = BorderRadius.circular(AdminDssTheme.radiusSm);
  return InputDecoration(
    isDense: true,
    labelText: label,
    helperText: helper,
    errorText: error,
    labelStyle: const TextStyle(
      fontSize: 12,
      color: AdminDssTheme.textSecondary,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AdminDssTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AdminDssTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AdminDssTheme.primary, width: 1.5),
    ),
  );
}

const _titleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 13.5,
  color: AdminDssTheme.textPrimary,
);
const _hintStyle = TextStyle(fontSize: 11.5, color: AdminDssTheme.textMuted);
final _dateFormat = DateFormat.yMMMd();

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Admin account choice for the Owner & schedule dropdown.
class DssAdminChoice {
  const DssAdminChoice({required this.id, required this.label});
  final String id;
  final String label;
}

/// Admin owner, office, responsible person and start / due / review dates.
/// Editable while the flag is open or in progress.
class DssAccountabilityCard extends StatefulWidget {
  const DssAccountabilityCard({
    super.key,
    required this.flag,
    required this.repository,
    required this.onSaved,
    this.admins = const [],
    this.assignedTo,
  });

  final DssFlag flag;
  final DssRepository repository;
  final Future<void> Function() onSaved;
  final List<DssAdminChoice> admins;
  final String? assignedTo;

  @override
  State<DssAccountabilityCard> createState() => _DssAccountabilityCardState();
}

class _DssAccountabilityCardState extends State<DssAccountabilityCard> {
  late final _officeCtrl = TextEditingController(
    text: widget.flag.ownerOffice ?? '',
  );
  late final _personCtrl = TextEditingController(
    text: widget.flag.responsibleName ?? '',
  );
  late DateTime? _start = widget.flag.startDate;
  late DateTime? _due = widget.flag.dueDate;
  late DateTime? _review = widget.flag.reviewDate;
  late String? _assignedTo = widget.assignedTo;
  bool _saving = false;
  bool _assigning = false;

  bool get _editable =>
      widget.flag.status == DssFlagStatus.open ||
      widget.flag.status == DssFlagStatus.inProgress;

  String? get _assignedLabel {
    final id = _assignedTo;
    if (id == null || id.isEmpty) return null;
    for (final a in widget.admins) {
      if (a.id == id) return a.label;
    }
    return 'Assigned admin';
  }

  @override
  void dispose() {
    _officeCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  String? get _dateError {
    final start = _start;
    if (start == null) return null;
    if (_due != null && _due!.isBefore(start)) {
      return 'The due date cannot be before the start date.';
    }
    if (_review != null && _review!.isBefore(start)) {
      return 'The next review cannot be before the start date.';
    }
    return null;
  }

  bool get _dirty {
    final f = widget.flag;
    return _officeCtrl.text.trim() != (f.ownerOffice ?? '') ||
        _personCtrl.text.trim() != (f.responsibleName ?? '') ||
        _start != f.startDate ||
        _due != f.dueDate ||
        _review != f.reviewDate;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.updateAccountability(
        flag: widget.flag,
        ownerOffice: _officeCtrl.text,
        responsibleName: _personCtrl.text,
        startDate: _start,
        dueDate: _due,
        reviewDate: _review,
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<DateTime?> _pick(DateTime? current, {DateTime? notBefore}) {
    final today = _today();
    final first = DateTime(today.year - 5);
    var initial = current ?? notBefore ?? today;
    if (initial.isBefore(first)) initial = first;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(today.year + 5, 12, 31),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    DateTime? notBefore,
  }) {
    final busy = _saving || _assigning;
    return InkWell(
      onTap: busy
          ? null
          : () async {
              final picked = await _pick(value, notBefore: notBefore);
              if (picked != null) setState(() => onChanged(picked));
            },
      borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
      child: InputDecorator(
        decoration: _decoration(label).copyWith(
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today, size: 16)
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: busy
                      ? null
                      : () => setState(() => onChanged(null)),
                ),
        ),
        child: Text(
          value == null ? 'Not set' : _dateFormat.format(value),
          style: TextStyle(
            fontSize: 13,
            color: value == null
                ? AdminDssTheme.textMuted
                : AdminDssTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _assignOwner(String? id) async {
    final label = id == null
        ? null
        : widget.admins
              .where((a) => a.id == id)
              .map((a) => a.label)
              .firstOrNull;
    setState(() {
      _assignedTo = id;
      _assigning = true;
    });
    try {
      await widget.repository.assignOwner(
        flagId: widget.flag.id,
        userId: id,
        ownerLabel: label,
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _assignedTo = widget.assignedTo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assign failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Widget _readOnly(DssFlag f) {
    final rows = <(String, String)>[
      if (_assignedLabel != null) ('Admin owner', _assignedLabel!),
      if (f.ownerOffice != null) ('Office', f.ownerOffice!),
      if (f.responsibleName != null) ('Responsible', f.responsibleName!),
      if (f.startDate != null) ('Start', _dateFormat.format(f.startDate!)),
      if (f.dueDate != null) ('Due', _dateFormat.format(f.dueDate!)),
      if (f.reviewDate != null)
        ('Next review', _dateFormat.format(f.reviewDate!)),
    ];
    if (rows.isEmpty) {
      return const Text(
        'No owner, office, person or dates were recorded.',
        style: TextStyle(fontSize: 12.5, color: AdminDssTheme.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$k: ',
                    style: const TextStyle(color: AdminDssTheme.textMuted),
                  ),
                  TextSpan(
                    text: v,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AdminDssTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant DssAccountabilityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignedTo != widget.assignedTo) {
      _assignedTo = widget.assignedTo;
    }
    if (oldWidget.flag.id != widget.flag.id ||
        oldWidget.flag.updatedAt != widget.flag.updatedAt) {
      _officeCtrl.text = widget.flag.ownerOffice ?? '';
      _personCtrl.text = widget.flag.responsibleName ?? '';
      _start = widget.flag.startDate;
      _due = widget.flag.dueDate;
      _review = widget.flag.reviewDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final flag = widget.flag;
    final error = _dateError;
    final busy = _saving || _assigning;
    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Owner & schedule', style: _titleStyle),
              const SizedBox(width: 8),
              DssDueChip(flag: flag),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _editable
                ? 'Admin owner, office, responsible person and dates for '
                      'this finding.'
                : 'Recorded while the work was under way.',
            style: _hintStyle,
          ),
          const SizedBox(height: 10),
          if (!_editable)
            _readOnly(flag)
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(_assignedTo ?? ''),
              initialValue: _assignedTo ?? '',
              dropdownColor: Colors.white,
              decoration: _decoration('Admin owner'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Unassigned')),
                ...widget.admins.map(
                  (a) => DropdownMenuItem(value: a.id, child: Text(a.label)),
                ),
              ],
              onChanged: busy
                  ? null
                  : (v) => _assignOwner(
                      (v == null || v.isEmpty) ? null : v,
                    ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _officeCtrl,
              enabled: !busy,
              maxLength: 120,
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => setState(() {}),
              decoration: _decoration('Owner office').copyWith(
                counterText: '',
                suffixIcon: PopupMenuButton<String>(
                  tooltip: 'Suggested offices',
                  icon: const Icon(Icons.arrow_drop_down),
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  enabled: !busy,
                  onSelected: (v) => setState(() => _officeCtrl.text = v),
                  itemBuilder: (_) => [
                    for (final o in DssCopy.officeSuggestions)
                      PopupMenuItem(value: o, child: Text(o)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _personCtrl,
              enabled: !busy,
              maxLength: 120,
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => setState(() {}),
              decoration: _decoration(
                'Responsible person',
                helper:
                    'Name and role, e.g. a program chair without an account',
              ).copyWith(counterText: ''),
            ),
            const SizedBox(height: 10),
            _dateField(
              label: 'Start date',
              value: _start,
              onChanged: (d) => _start = d,
            ),
            const SizedBox(height: 10),
            _dateField(
              label: 'Due date',
              value: _due,
              notBefore: _start,
              onChanged: (d) => _due = d,
            ),
            const SizedBox(height: 10),
            _dateField(
              label: 'Next review',
              value: _review,
              notBefore: _start,
              onChanged: (d) => _review = d,
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminDssTheme.danger,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy || !_dirty || error != null ? null : _save,
              style: dssFilledButtonStyle(),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Proof for a flag: evidence entries plus linked draft / offline Other.
/// Any kind unlocks Resolve finding.
class DssProofCard extends StatelessWidget {
  const DssProofCard({
    super.key,
    required this.entries,
    required this.canEdit,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    this.linkedAnnouncementId,
    this.linkedAnnouncementAt,
    this.offlineOtherDetail,
  });

  final List<DssFlagEvidence> entries;
  final bool canEdit;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<DssFlagEvidence> onRemove;

  /// Reminder/announcement draft linked on the flag (counts as proof).
  final String? linkedAnnouncementId;
  final DateTime? linkedAnnouncementAt;

  /// Plan type "Other" offline action text (counts as proof).
  final String? offlineOtherDetail;

  static IconData _icon(DssEvidenceType t) => switch (t) {
    DssEvidenceType.meeting => Icons.groups_outlined,
    DssEvidenceType.event => Icons.event_available_outlined,
    DssEvidenceType.communication => Icons.mail_outline,
    DssEvidenceType.document => Icons.description_outlined,
    DssEvidenceType.report => Icons.bar_chart,
    DssEvidenceType.other => Icons.attach_file,
  };

  int get _syntheticCount {
    var n = 0;
    if ((linkedAnnouncementId ?? '').trim().isNotEmpty) n++;
    if ((offlineOtherDetail ?? '').trim().isNotEmpty) n++;
    return n;
  }

  Widget _syntheticRow({
    required IconData icon,
    required String title,
    required String meta,
    String? body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AdminDssTheme.surface,
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
        border: Border.all(color: AdminDssTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AdminDssTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AdminDssTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminDssTheme.textMuted,
                  ),
                ),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AdminDssTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDraft = (linkedAnnouncementId ?? '').trim().isNotEmpty;
    final other = (offlineOtherDetail ?? '').trim();
    final total = entries.length + _syntheticCount;
    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Proof', style: _titleStyle),
              const SizedBox(width: 8),
              DssMetaChip(label: '$total'),
              const Spacer(),
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: busy ? null : onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: dssOutlinedButtonStyle(),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Reminder draft, offline “Other” action, or evidence entries. '
            'Any one unlocks Resolve finding.',
            style: _hintStyle,
          ),
          const SizedBox(height: 8),
          if (total == 0)
            const Text(
              'No proof entries yet.',
              style: TextStyle(color: AdminDssTheme.textMuted, fontSize: 12.5),
            ),
          if (hasDraft)
            _syntheticRow(
              icon: Icons.campaign_outlined,
              title: 'Reminder announcement drafted — counts as proof',
              meta: linkedAnnouncementAt == null
                  ? 'Linked draft'
                  : 'Linked draft · ${_dateFormat.format(linkedAnnouncementAt!.toLocal())}',
            ),
          if (other.isNotEmpty)
            _syntheticRow(
              icon: Icons.edit_note_outlined,
              title: 'Offline action (Other)',
              meta: 'Counts as proof',
              body: other,
            ),
          for (final e in entries)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              decoration: BoxDecoration(
                color: AdminDssTheme.surface,
                borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
                border: Border.all(color: AdminDssTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon(e.type), size: 18, color: AdminDssTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AdminDssTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.type.label} · ${_dateFormat.format(e.date)}'
                          '${e.createdByName.isEmpty ? '' : ' · added by ${e.createdByName}'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AdminDssTheme.textMuted,
                          ),
                        ),
                        if (e.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.description,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AdminDssTheme.textSecondary,
                            ),
                          ),
                        ],
                        if (e.link != null) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              final uri = Uri.tryParse(e.link!);
                              if (uri != null) {
                                launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: Text(
                              e.link!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AdminDssTheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canEdit)
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AdminDssTheme.textMuted,
                      ),
                      onPressed: busy ? null : () => onRemove(e),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Backward-compatible name for [DssProofCard].
typedef DssEvidenceCard = DssProofCard;

/// What the admin entered in the Add evidence dialog.
typedef DssEvidenceDraft = ({
  DssEvidenceType type,
  String title,
  DateTime date,
  String description,
  String? link,
});

/// Null when the link is empty or a web address.
String? dssEvidenceLinkError(String link) {
  final t = link.trim();
  if (t.isEmpty) return null;
  final uri = Uri.tryParse(t);
  final ok =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      !t.contains(RegExp(r'\s'));
  return ok ? null : 'Use a web link starting with http:// or https://';
}

Future<DssEvidenceDraft?> showDssAddEvidenceDialog(BuildContext context) {
  return showDialog<DssEvidenceDraft>(
    context: context,
    builder: (_) => const _AddEvidenceDialog(),
  );
}

class _AddEvidenceDialog extends StatefulWidget {
  const _AddEvidenceDialog();

  @override
  State<_AddEvidenceDialog> createState() => _AddEvidenceDialogState();
}

class _AddEvidenceDialogState extends State<_AddEvidenceDialog> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  DssEvidenceType _type = DssEvidenceType.meeting;
  DateTime _date = _today();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkError = dssEvidenceLinkError(_linkCtrl.text);
    final canSave = _titleCtrl.text.trim().isNotEmpty && linkError == null;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: AdminDialogStandards.shape,
      elevation: AdminDialogStandards.elevation,
      title: const Text('Add evidence'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<DssEvidenceType>(
                initialValue: _type,
                dropdownColor: Colors.white,
                decoration: _decoration('Type'),
                items: [
                  for (final t in DssEvidenceType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                maxLength: 200,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  'Title (required)',
                  helper: 'e.g. Curriculum review meeting with the dean',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final today = _today();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(today.year - 5),
                    lastDate: today,
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: _decoration('Date').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today, size: 16),
                  ),
                  child: Text(
                    _dateFormat.format(_date),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionCtrl,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                style: const TextStyle(fontSize: 13),
                decoration: _decoration(
                  'Description (optional)',
                ).copyWith(alignLabelWithHint: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _linkCtrl,
                keyboardType: TextInputType.url,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  'Link (optional)',
                  helper: 'Shared drive, minutes or report; no file uploads',
                  error: linkError,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave
              ? () => Navigator.of(context).pop((
                  type: _type,
                  title: _titleCtrl.text.trim(),
                  date: _date,
                  description: _descriptionCtrl.text.trim(),
                  link: _linkCtrl.text.trim().isEmpty
                      ? null
                      : _linkCtrl.text.trim(),
                ))
              : null,
          style: dssFilledButtonStyle(),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
