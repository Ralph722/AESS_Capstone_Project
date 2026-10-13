import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/reports/data/gts_saved_report_service.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';

/// Open, save, save as new and delete for saved reports. Both builder modes
/// use it; reports of the other mode are listed too and handed to
/// [onOpenOther].
class GtsSavedReportsBar extends StatefulWidget {
  const GtsSavedReportsBar({
    super.key,
    required this.store,
    required this.isList,
    required this.open,
    required this.name,
    required this.settingsNamed,
    required this.canSave,
    required this.unsavedChanges,
    required this.onOpen,
    required this.onSaved,
    required this.onDeleted,
    this.onOpenOther,
  });

  final GtsSavedReportStore store;

  /// This builder makes alumni lists (otherwise summary reports).
  final bool isList;

  /// The saved report the settings came from, if any.
  final GtsSavedReport? open;

  /// Report name typed in the builder.
  final String name;

  /// The current settings JSON, titled with the given name.
  final Map<String, dynamic> Function(String name) settingsNamed;
  final bool canSave;
  final bool unsavedChanges;

  final ValueChanged<GtsSavedReport> onOpen;
  final ValueChanged<GtsSavedReport> onSaved;
  final VoidCallback onDeleted;

  /// Opens a report of the other mode; those are hidden when null.
  final ValueChanged<GtsSavedReport>? onOpenOther;

  @override
  State<GtsSavedReportsBar> createState() => _GtsSavedReportsBarState();
}

class _GtsSavedReportsBarState extends State<GtsSavedReportsBar> {
  List<GtsSavedReport> _saved = const [];
  bool _loading = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.store.list();
      if (!mounted) return;
      setState(() {
        _saved = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Saved reports could not be loaded.';
      });
    }
  }

  List<GtsSavedReport> get _visible => [
    for (final r in _saved)
      if (r.isList == widget.isList) r,
    if (widget.onOpenOther != null)
      for (final r in _saved)
        if (r.isList != widget.isList) r,
  ];

  Future<void> _save({required bool asNew}) async {
    if (_saving) return;
    final open = widget.open;
    var name = widget.name.trim();
    if (asNew || open == null || name.isEmpty) {
      final suggested = asNew && open != null
          ? '${name.isEmpty ? open.name : name} (copy)'
          : name;
      final asked = await showDialog<String>(
        context: context,
        builder: (_) => _ReportNameDialog(initial: suggested),
      );
      if (asked == null || !mounted) return;
      name = asked;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.store.save(
        id: asNew ? null : open?.id,
        name: name,
        settings: widget.settingsNamed(name.trim()),
      );
      if (!mounted) return;
      widget.onSaved(saved);
      _message('Saved "${saved.name}".');
      await _load();
    } on GtsSavedReportNameTaken catch (e) {
      _message(
        'A saved report named "${e.name}" already exists. Choose another '
        'name.',
      );
    } catch (_) {
      _message(
        'Could not save the report. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final open = widget.open;
    if (open == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved report?'),
        content: Text(
          '"${open.name}" will be removed for every admin. Files already '
          'downloaded are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.store.delete(open.id);
      if (!mounted) return;
      widget.onDeleted();
      _message('Deleted "${open.name}".');
      await _load();
    } catch (_) {
      _message(
        'Could not delete the report. Check your connection and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.open;
    final visible = _visible;
    const muted = TextStyle(fontSize: 12, color: AdminReportsTheme.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('saved-${open?.id}-${visible.length}'),
          initialValue: visible.any((r) => r.id == open?.id) ? open!.id : null,
          isExpanded: true,
          hint: Text(
            _loading
                ? 'Loading saved reports…'
                : visible.isEmpty
                ? 'No saved reports yet'
                : 'Open a saved report',
          ),
          decoration: const InputDecoration(
            labelText: 'Saved reports',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final r in visible)
              DropdownMenuItem(
                value: r.id,
                child: Row(
                  children: [
                    Tooltip(
                      message: r.isList ? 'Alumni list' : 'Summary & charts',
                      child: Icon(
                        r.isList ? Icons.list_alt : Icons.insert_chart_outlined,
                        size: 16,
                        color: AdminReportsTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (id) {
            for (final r in visible) {
              if (r.id != id) continue;
              if (r.isList == widget.isList) {
                widget.onOpen(r);
              } else {
                widget.onOpenOther?.call(r);
              }
              return;
            }
          },
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: muted.copyWith(color: AdminReportsTheme.danger),
            ),
          )
        else if (open != null && widget.unsavedChanges)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Unsaved changes', style: muted),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilledButton.tonalIcon(
              onPressed: _saving || !widget.canSave
                  ? null
                  : () => unawaited(_save(asNew: false)),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(open == null ? 'Save report' : 'Save changes'),
            ),
            if (open != null) ...[
              OutlinedButton(
                onPressed: _saving || !widget.canSave
                    ? null
                    : () => unawaited(_save(asNew: true)),
                child: const Text('Save as new'),
              ),
              TextButton.icon(
                onPressed: _saving ? null : () => unawaited(_delete()),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Asks for a saved report name; pops the trimmed name, or null.
class _ReportNameDialog extends StatefulWidget {
  const _ReportNameDialog({required this.initial});

  final String initial;

  @override
  State<_ReportNameDialog> createState() => _ReportNameDialogState();
}

class _ReportNameDialogState extends State<_ReportNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save report'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _name,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Report name',
            helperText: 'Every admin can open saved reports.',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
