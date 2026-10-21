import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_columns.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_tables.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/data/gts_list_data_service.dart';
import 'package:alumni_system/features/admin/reports/data/gts_list_export_service.dart';
import 'package:alumni_system/features/admin/reports/data/gts_saved_report_service.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_saved_reports_bar.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_templates.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_preview.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/personal_data_export_dialog.dart';

typedef GtsListResponseLoader =
    Future<List<GtsListResponse>> Function(List<String> surveyIds);

/// Alumni list builder: one row per alumnus on the active roster with the
/// columns the admin picks, and the tracer-status tally underneath.
class GtsAlumniListPanel extends StatefulWidget {
  const GtsAlumniListPanel({
    super.key,
    required this.waves,
    required this.roster,
    this.loadResponses,
    this.responseCache,
    this.initialConfig,
    this.onConfigChanged,
    this.savedReports,
    this.initialOpen,
    this.onOpenChanged,
    this.onOpenSummary,
  });

  /// Shared saved reports; the save and open controls are hidden when null.
  final GtsSavedReportStore? savedReports;

  /// Saved list [initialConfig] was opened from or saved as.
  final GtsSavedReport? initialOpen;
  final ValueChanged<GtsSavedReport?>? onOpenChanged;

  /// Opens a saved summary report in that mode; hidden when null.
  final ValueChanged<GtsSavedReport>? onOpenSummary;

  /// CHED GTS waves that can have responses, newest first.
  final List<Survey> waves;

  /// Every roster record; deactivated records are left out of the list.
  final List<AlumniMember> roster;

  /// Defaults to [GtsListDataService.loadResponses].
  final GtsListResponseLoader? loadResponses;

  /// Loaded responses per wave id, kept by the page across tab switches.
  final Map<String, List<GtsListResponse>>? responseCache;

  final GtsListConfig? initialConfig;
  final ValueChanged<GtsListConfig>? onConfigChanged;

  @override
  State<GtsAlumniListPanel> createState() => _GtsAlumniListPanelState();
}

class _GtsAlumniListPanelState extends State<GtsAlumniListPanel> {
  late GtsListResponseLoader _load;
  late GtsListConfig _config;
  final _title = TextEditingController();
  late final Map<String, List<GtsListResponse>> _cache =
      widget.responseCache ?? {};
  bool _loading = false;
  bool _reloadAfterLoad = false;
  CustomReportFormat? _exporting;

  /// Excel first: it suits wide lists best.
  static const _downloadOrder = [
    CustomReportFormat.excel,
    CustomReportFormat.csv,
    CustomReportFormat.pdf,
  ];
  String? _loadError;
  GtsAlumniListResult? _result;

  /// Saved list the current settings were opened from or saved as.
  late GtsSavedReport? _open = widget.initialOpen;

  void _setOpen(GtsSavedReport? report) {
    setState(() => _open = report);
    widget.onOpenChanged?.call(report);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Settings differ from the opened saved list.
  bool get _hasUnsavedChanges {
    final open = _open;
    if (open == null) return false;
    try {
      return jsonEncode(_config.copyWith(title: open.name).toJson()) !=
          jsonEncode(open.listSettings.copyWith(title: open.name).toJson());
    } on FormatException {
      return true;
    }
  }

  /// [config] with a wave that still exists: the newest when its own wave
  /// is gone. Returns whether the wave was replaced.
  (GtsListConfig, bool) _withKnownWave(GtsListConfig config) {
    final id = config.surveyId;
    if (id == null || widget.waves.any((w) => w.id == id)) {
      return (config, false);
    }
    final newest = widget.waves.firstOrNull?.id;
    return (
      newest == null
          ? config.copyWith(latestFromAnyWave: true)
          : config.copyWith(surveyId: newest),
      true,
    );
  }

  void _openSaved(GtsSavedReport report) {
    final GtsListConfig settings;
    try {
      settings = report.listSettings;
    } on FormatException catch (e) {
      _message(e.message);
      return;
    }
    final (next, replaced) = _withKnownWave(
      settings.copyWith(title: report.name),
    );
    _setOpen(report);
    _title.text = report.name;
    _update(next);
    if (replaced) {
      _message(
        'The tracer wave in this list is no longer available; the newest '
        'wave is used instead.',
      );
    }
    final unknown = GtsListColumns.unknownKeys(next);
    if (unknown.isNotEmpty) {
      _message(
        '${unknown.length} column(s) in this list no longer exist and are '
        'not shown.',
      );
    }
  }

  void _applyTemplate(GtsListTemplate template) {
    final next = template.forWave(_config.surveyId);
    _title.text = next.title;
    _update(next);
  }

  Map<String, String> get _waveLabels => {
    for (final w in widget.waves) w.id: w.title,
  };

  List<String> get _neededWaves => switch (_config.surveyId) {
    final id? => [id],
    null => [for (final w in widget.waves) w.id],
  };

  @override
  void initState() {
    super.initState();
    _load = widget.loadResponses ?? GtsListDataService().loadResponses;
    final initial = widget.initialConfig;
    _config = initial == null
        ? GtsListConfig(surveyId: widget.waves.firstOrNull?.id)
        : _withKnownWave(initial).$1;
    _title.text = _config.title;
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(GtsAlumniListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.roster, widget.roster)) _recalculate();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _update(GtsListConfig next) {
    setState(() => _config = next);
    widget.onConfigChanged?.call(next);
    unawaited(_refresh());
  }

  /// Loads missing waves, then rebuilds the list.
  Future<void> _refresh() async {
    if (_loading) {
      _reloadAfterLoad = true;
      return;
    }
    final missing = [
      for (final id in _neededWaves)
        if (!_cache.containsKey(id)) id,
    ];
    if (missing.isNotEmpty) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
      try {
        final rows = await _load(missing);
        for (final id in missing) {
          _cache[id] = [];
        }
        for (final r in rows) {
          (_cache[r.surveyId] ??= []).add(r);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _reloadAfterLoad = false;
          _loadError =
              'Could not load tracer responses. Check your connection and '
              'try again.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
      if (_reloadAfterLoad) {
        _reloadAfterLoad = false;
        return _refresh();
      }
    }
    _recalculate();
  }

  void _recalculate() {
    final needed = _neededWaves;
    if (!needed.every(_cache.containsKey)) return;
    final result = GtsAlumniList.build(
      _config,
      roster: widget.roster,
      responses: [for (final id in needed) ..._cache[id]!],
      waveIds: [for (final w in widget.waves) w.id],
      waveLabels: _waveLabels,
    );
    setState(() => _result = result);
  }

  void _reloadData() {
    _cache.clear();
    unawaited(_refresh());
  }

  // ---- Settings -----------------------------------------------------------

  static const _heading = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AdminReportsTheme.primary,
    letterSpacing: 0.3,
  );

  static const _muted = TextStyle(
    fontSize: 12,
    color: AdminReportsTheme.textMuted,
  );

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 13, color: AdminReportsTheme.textSecondary),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminReportsTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminReportsTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminReportsTheme.primary, width: 1.5),
    ),
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title.toUpperCase(), style: _heading),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  List<AlumniMember> get _activeRoster => [
    for (final m in widget.roster)
      if (!m.isDeactivated) m,
  ];

  List<String> get _courseChoices {
    final seen = <String, String>{};
    for (final m in _activeRoster) {
      final c = m.course.trim();
      if (c.isNotEmpty) seen.putIfAbsent(c.toLowerCase(), () => c);
    }
    return seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> get _batchChoices {
    final seen = {
      for (final m in _activeRoster)
        GtsListRow(status: _anyStatus, member: m).batch,
    };
    final list = seen.toList()
      ..sort((a, b) {
        if (a == DssPolicy.batchNotRecorded) return 1;
        if (b == DssPolicy.batchNotRecorded) return -1;
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return nb.compareTo(na);
        return b.compareTo(a);
      });
    return list;
  }

  static const _anyStatus = GtsTracerStatus.untrackedNotRegistered;

  static List<GtsField> get _answerFilterFields => [
    for (final f in GtsFieldDictionary.filterable)
      if (f.source == GtsFieldSource.chedAnswer && f.options.isNotEmpty) f,
  ];

  List<String> _toggled(List<String> list, String value, bool on) => on
      ? [...list, value]
      : [
          for (final v in list)
            if (v != value) v,
        ];

  Widget _settings() {
    final columns = GtsListColumns.resolve(_config);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'List settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Reload responses',
              onPressed: _loading ? null : _reloadData,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.savedReports case final store?) ...[
          GtsSavedReportsBar(
            store: store,
            isList: true,
            open: _open,
            name: _title.text,
            settingsNamed: (name) => _config.copyWith(title: name).toJson(),
            canSave: true,
            unsavedChanges: _hasUnsavedChanges,
            onOpen: _openSaved,
            onOpenOther: widget.onOpenSummary,
            onSaved: (saved) {
              _title.text = saved.name;
              final next = _config.copyWith(title: saved.name);
              setState(() => _config = next);
              _setOpen(saved);
              widget.onConfigChanged?.call(next);
            },
            onDeleted: () => _setOpen(null),
          ),
          const SizedBox(height: 16),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey('list-template-${_config.templateKey}'),
          initialValue: GtsListTemplates.byKey(_config.templateKey)?.key,
          isExpanded: true,
          dropdownColor: Colors.white,
          hint: const Text('Custom list'),
          decoration: _input('Start from a ready-made list'),
          items: [
            for (final t in GtsListTemplates.all)
              DropdownMenuItem(
                value: t.key,
                child: Text(t.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (k) {
            if (GtsListTemplates.byKey(k) case final t?) _applyTemplate(t);
          },
        ),
        if (GtsListTemplates.byKey(_config.templateKey) case final t?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${t.summary} You can change any setting below.',
              style: _muted,
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: _input('Report name (optional)'),
          onChanged: (v) => _update(_config.copyWith(title: v)),
        ),
        const SizedBox(height: 16),
        _section('Tracer wave', [
          DropdownButtonFormField<String?>(
            key: ValueKey('wave-${_config.surveyId}'),
            initialValue: _config.surveyId,
            isExpanded: true,
            dropdownColor: Colors.white,
            decoration: _input('Answers from'),
            items: [
              for (final w in widget.waves)
                DropdownMenuItem(
                  value: w.id,
                  child: Text(w.title, overflow: TextOverflow.ellipsis),
                ),
              const DropdownMenuItem(
                value: null,
                child: Text(GtsListTables.latestWave),
              ),
            ],
            onChanged: (id) => _update(
              id == null
                  ? _config.copyWith(latestFromAnyWave: true)
                  : _config.copyWith(surveyId: id),
            ),
          ),
          if (_config.latestFromAnyWave)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Each graduate\'s newest answer from any tracer wave. The '
                '"Wave answered" column shows which one.',
                style: _muted,
              ),
            ),
        ]),
        _section('Columns', [
          _columnList(columns),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => unawaited(_pickColumns(columns)),
              icon: const Icon(Icons.view_column_outlined, size: 18),
              label: const Text('Add or remove columns'),
            ),
          ),
        ]),
        _section('Only include', [
          _label('Tracer status'),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final s in GtsTracerStatus.values)
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(s.label, style: const TextStyle(fontSize: 12)),
                  selected: _config.statuses.contains(s),
                  onSelected: (on) => _update(
                    _config.copyWith(
                      statuses: [
                        for (final x in GtsTracerStatus.values)
                          if (x == s ? on : _config.statuses.contains(x)) x,
                      ],
                    ),
                  ),
                ),
            ],
          ),
          _label('Course'),
          _chips(
            _courseChoices,
            _config.courses,
            (v, on) => _update(
              _config.copyWith(courses: _toggled(_config.courses, v, on)),
            ),
          ),
          _label('Batch'),
          _chips(
            _batchChoices,
            _config.batches,
            (v, on) => _update(
              _config.copyWith(batches: _toggled(_config.batches, v, on)),
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _config.answerFilters.length; i++)
            _answerFilterRow(i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addAnswerFilter,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Only graduates who answered…'),
            ),
          ),
          const Text(
            'Answer filters leave out untracked alumni, who have no answers.',
            style: _muted,
          ),
        ]),
        _section('Order', [_sortControls(columns)]),
        _section('Subtotals', [
          Wrap(
            spacing: 6,
            children: [
              for (final s in GtsListSubtotal.values)
                ChoiceChip(
                  label: Text(switch (s) {
                    GtsListSubtotal.none => 'Overall only',
                    GtsListSubtotal.batch => 'By batch',
                    GtsListSubtotal.course => 'By course',
                  }),
                  selected: _config.subtotalBy == s,
                  onSelected: (_) => _update(_config.copyWith(subtotalBy: s)),
                ),
            ],
          ),
        ]),
        _section('Chart', [
          Wrap(
            spacing: 6,
            children: [
              for (final c in GtsListChart.values)
                ChoiceChip(
                  label: Text(switch (c) {
                    GtsListChart.none => 'No chart',
                    GtsListChart.bars => 'Bars',
                    GtsListChart.donut => 'Donut',
                  }),
                  selected: _config.chart == c,
                  onSelected: (_) => _update(_config.copyWith(chart: c)),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Tracer status of the alumni listed.', style: _muted),
          ),
        ]),
      ],
    );
  }

  Widget _chips(
    List<String> choices,
    List<String> selected,
    void Function(String value, bool on) onChanged,
  ) {
    if (choices.isEmpty) {
      return const Text('None recorded on the roster.', style: _muted);
    }
    final picked = {for (final s in selected) s.trim().toLowerCase()};
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final c in choices)
          FilterChip(
            visualDensity: VisualDensity.compact,
            label: Text(c, style: const TextStyle(fontSize: 12)),
            selected: picked.contains(c.toLowerCase()),
            onSelected: (on) => onChanged(c, on),
          ),
      ],
    );
  }

  bool _isLockedColumn(GtsListColumn c) =>
      c.key == GtsListColumns.waveColumn && _config.latestFromAnyWave;

  Widget _columnList(List<GtsListColumn> columns) {
    if (columns.isEmpty) {
      return const Text(
        'No columns yet. Add the details you want to see.',
        style: _muted,
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: columns.length,
      onReorder: (from, to) {
        final keys = [for (final c in columns) c.key];
        if (to > from) to--;
        keys.insert(to, keys.removeAt(from));
        _update(_config.copyWith(columns: keys));
      },
      itemBuilder: (context, i) {
        final c = columns[i];
        return Material(
          key: ValueKey(c.key),
          color: Colors.transparent,
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: i,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: AdminReportsTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Tooltip(
                  message: c.description,
                  child: Text(
                    c.header,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (c.personal)
                const Tooltip(
                  message: 'Personal data',
                  child: Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: AdminReportsTheme.textMuted,
                  ),
                ),
              if (_isLockedColumn(c))
                const Tooltip(
                  message: 'Always shown when answers come from any wave.',
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: AdminReportsTheme.textMuted,
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Remove column',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeColumn(columns, c.key),
                  icon: const Icon(Icons.close, size: 16),
                ),
            ],
          ),
        );
      },
    );
  }

  void _removeColumn(List<GtsListColumn> columns, String key) {
    _update(
      _config.copyWith(
        columns: [
          for (final c in columns)
            if (c.key != key) c.key,
        ],
        clearSortBy: _config.sortBy == key,
      ),
    );
  }

  Future<void> _pickColumns(List<GtsListColumn> current) async {
    final picked = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          GtsListColumnPicker(selected: [for (final c in current) c.key]),
    );
    if (picked == null || !mounted) return;
    _update(
      _config.copyWith(
        columns: picked,
        clearSortBy: _config.sortBy != null && !picked.contains(_config.sortBy),
      ),
    );
  }

  Widget _sortControls(List<GtsListColumn> columns) {
    final current = columns.any((c) => c.key == _config.sortBy)
        ? _config.sortBy
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          key: ValueKey('sort-$current-${columns.length}'),
          initialValue: current,
          isExpanded: true,
          dropdownColor: Colors.white,
          decoration: _input('Sort by'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Batch, then name'),
            ),
            for (final c in columns)
              if (c.key != GtsListConfig.batchColumn)
                DropdownMenuItem(
                  value: c.key,
                  child: Text(c.header, overflow: TextOverflow.ellipsis),
                ),
          ],
          onChanged: (k) => _update(
            k == null
                ? _config.copyWith(clearSortBy: true)
                : _config.copyWith(sortBy: k),
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.arrow_upward, size: 16),
              label: Text('A to Z'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.arrow_downward, size: 16),
              label: Text('Z to A'),
            ),
          ],
          selected: {_config.sortDescending},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              _update(_config.copyWith(sortDescending: s.first)),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Blank and "Not asked" answers stay at the bottom.',
            style: _muted,
          ),
        ),
      ],
    );
  }

  void _addAnswerFilter() {
    final used = {for (final f in _config.answerFilters) f.field};
    for (final f in _answerFilterFields) {
      if (used.contains(f.key)) continue;
      _update(
        _config.copyWith(
          answerFilters: [
            ..._config.answerFilters,
            GtsReportFilter(field: f.key, values: const []),
          ],
        ),
      );
      return;
    }
  }

  Widget _answerFilterRow(int index) {
    final filter = _config.answerFilters[index];
    final field = GtsFieldDictionary.byKey(filter.field);
    final taken = {
      for (var i = 0; i < _config.answerFilters.length; i++)
        if (i != index) _config.answerFilters[i].field,
    };
    void replace(GtsReportFilter? next) {
      final list = [..._config.answerFilters];
      if (next == null) {
        list.removeAt(index);
      } else {
        list[index] = next;
      }
      _update(_config.copyWith(answerFilters: list));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AdminReportsTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('answer-filter-$index-${filter.field}'),
                  initialValue: filter.field,
                  isExpanded: true,
                  decoration: _input('Only graduates whose'),
                  items: [
                    for (final f in _answerFilterFields)
                      if (!taken.contains(f.key))
                        DropdownMenuItem(
                          value: f.key,
                          child: Text(
                            f.numberedLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  ],
                  onChanged: (k) {
                    if (k != null) {
                      replace(GtsReportFilter(field: k, values: const []));
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove filter',
                onPressed: () => replace(null),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (field != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final o in field.options)
                  FilterChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(o, style: const TextStyle(fontSize: 12)),
                    selected: filter.values.contains(o),
                    onSelected: (on) => replace(
                      GtsReportFilter(
                        field: filter.field,
                        values: [
                          for (final v in field.options)
                            if (v == o ? on : filter.values.contains(v)) v,
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (filter.values.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Pick at least one answer; until then nobody matches.',
                  style: _muted,
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ---- Layout -------------------------------------------------------------

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AdminReportsTheme.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AdminReportsTheme.border),
      boxShadow: AdminReportsTheme.cardShadow,
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.waves.isEmpty) {
      return _card(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No published CHED Graduate Tracer Study waves yet. Publish a '
            'tracer wave to list who answered.',
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = _card(_settings());
        final preview = _card(_previewArea());
        if (constraints.maxWidth < 1000) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [settings, const SizedBox(height: 16), preview],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 380, child: settings),
            const SizedBox(width: 16),
            Expanded(child: preview),
          ],
        );
      },
    );
  }

  Future<void> _download(CustomReportFormat format) async {
    final result = _result;
    if (result == null || _exporting != null) return;
    if (!await confirmPersonalDataExport(context, what: 'This alumni list')) {
      return;
    }
    if (!mounted) return;
    setState(() => _exporting = format);
    try {
      final bytes = await GtsListExportService.exportBytes(result, format);
      if (!mounted) return;
      tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName: GtsListExportService.fileName(result, format),
        mimeType: switch (format) {
          CustomReportFormat.pdf => 'application/pdf',
          CustomReportFormat.excel =>
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          CustomReportFormat.csv => 'text/csv;charset=utf-8',
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create the ${format.label} file.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  Widget _previewArea() {
    final result = _result;
    final columnCount = GtsListColumns.resolve(_config).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final f in _downloadOrder)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: OutlinedButton.icon(
                  onPressed: result == null || _loading || _exporting != null
                      ? null
                      : () => unawaited(_download(f)),
                  style: AdminButtonStyles.outlined(),
                  icon: _exporting == f
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 16),
                  label: Text(f.label),
                ),
              ),
          ],
        ),
        if (columnCount > GtsListExportService.pdfWideColumns)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$columnCount columns: Excel is easiest to read for wide lists; '
              'the PDF prints small.',
              textAlign: TextAlign.right,
              style: _muted,
            ),
          ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          Column(
            children: [
              Text(_loadError!),
              TextButton(
                onPressed: _reloadData,
                child: const Text('Try again'),
              ),
            ],
          )
        else if (result != null)
          GtsAlumniListPreview(result: result),
      ],
    );
  }
}

/// On-screen alumni list: heading, status chart, the rows (200 at a time)
/// and the tally, which is always shown in full.
class GtsAlumniListPreview extends StatelessWidget {
  const GtsAlumniListPreview({super.key, required this.result});

  static const rowStep = GtsReportPreview.rowStep;

  final GtsAlumniListResult result;

  @override
  Widget build(BuildContext context) {
    final columns = GtsListColumns.resolve(result.config);
    final chart = GtsListTables.chart(result);
    final tally = result.tally;
    final filtered =
        result.config.courses.isNotEmpty ||
        result.config.batches.isNotEmpty ||
        result.config.statuses.isNotEmpty ||
        result.config.answerFilters.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          GtsListTables.title(result),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AdminReportsTheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${GtsListTables.scope(result)} · ${tally.total} alumni on the '
          'active roster${filtered ? ' (filtered)' : ''}',
          style: const TextStyle(
            fontSize: 12,
            color: AdminReportsTheme.textMuted,
          ),
        ),
        if (result.config.description.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              result.config.description,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        const SizedBox(height: 16),
        if (chart != null) ...[
          GtsReportChartView(data: chart),
          const SizedBox(height: 16),
        ],
        if (result.rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No alumni match these settings.'),
          )
        else if (columns.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Add at least one column to see the list.'),
          )
        else
          _ListTable(
            result: result,
            columns: columns,
            key: ValueKey(result.config),
          ),
        const SizedBox(height: 20),
        const Text(
          'TALLY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminReportsTheme.primary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        _TallyTable(result),
        if (tally.count(GtsTracerStatus.offRoster) > 0)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              GtsListTables.offRosterNote,
              style: TextStyle(
                fontSize: 11,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

const _headingStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: AdminReportsTheme.primary,
);

const _cellStyle = TextStyle(fontSize: 12, color: Colors.black87);

class _ListTable extends StatefulWidget {
  const _ListTable({super.key, required this.result, required this.columns});

  final GtsAlumniListResult result;
  final List<GtsListColumn> columns;

  @override
  State<_ListTable> createState() => _ListTableState();
}

class _ListTableState extends State<_ListTable> {
  var _limit = GtsAlumniListPreview.rowStep;

  static const _untrackedTint = Color(0xFFFFFBEB);

  Widget _cell(String text) {
    if (text == gtsNotAskedLabel) {
      return const Text(
        gtsNotAskedLabel,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: AdminReportsTheme.textMuted,
        ),
      );
    }
    final box = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
    return text.length > 60 ? Tooltip(message: text, child: box) : box;
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.result.rows;
    final shown = rows.take(_limit).toList();
    final labels = widget.result.waveLabels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminReportsTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(AdminReportsTheme.surface),
              headingRowHeight: 38,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 48,
              columnSpacing: 20,
              headingTextStyle: _headingStyle,
              dataTextStyle: _cellStyle,
              columns: [
                for (final c in widget.columns)
                  DataColumn(
                    label: Tooltip(message: c.description, child: Text(c.header)),
                  ),
              ],
              rows: [
                for (final r in shown)
                  DataRow(
                    color: r.status.untracked
                        ? const WidgetStatePropertyAll(_untrackedTint)
                        : r.member == null
                        ? const WidgetStatePropertyAll(AdminReportsTheme.surface)
                        : null,
                    cells: [
                      for (final c in widget.columns)
                        DataCell(
                          _cell(GtsListColumns.cell(c, r, waveLabels: labels)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (rows.length > _limit) ...[
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                'Showing the first $_limit of ${rows.length} alumni.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _limit += GtsAlumniListPreview.rowStep),
                child: Text(
                  'Show ${math.min(GtsAlumniListPreview.rowStep, rows.length - _limit)} more',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Overall tally, or one column per batch/course plus the overall column.
class _TallyTable extends StatelessWidget {
  const _TallyTable(this.result);

  final GtsAlumniListResult result;

  @override
  Widget build(BuildContext context) {
    final overall = GtsListTables.tally(result.tally);
    final groups = result.groups;
    DataRow row(int i, List<String> cells) {
      final line = overall[i];
      return DataRow(
        color: line.isTotal
            ? const WidgetStatePropertyAll(AdminReportsTheme.surface)
            : null,
        cells: [
          for (final c in cells)
            DataCell(
              Text(
                c,
                style: line.isTotal
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null,
              ),
            ),
        ],
      );
    }

    String both(GtsTallyLine l) =>
        l.share.isEmpty ? l.count : '${l.count} (${l.share})';

    final DataTable table;
    if (groups.isEmpty) {
      table = DataTable(
        headingRowHeight: 34,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        columnSpacing: 24,
        headingTextStyle: _headingStyle,
        dataTextStyle: _cellStyle,
        columns: const [
          DataColumn(label: Text('Tracer status')),
          DataColumn(label: Text('Alumni'), numeric: true),
          DataColumn(label: Text('Share'), numeric: true),
        ],
        rows: [
          for (var i = 0; i < overall.length; i++)
            row(i, [overall[i].label, overall[i].count, overall[i].share]),
        ],
      );
    } else {
      final perGroup = [
        for (final g in groups) _byLabel(GtsListTables.tally(g.tally)),
      ];
      table = DataTable(
        headingRowHeight: 34,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        columnSpacing: 24,
        headingTextStyle: _headingStyle,
        dataTextStyle: _cellStyle,
        columns: [
          DataColumn(
            label: Text(
              'Tracer status by '
              '${GtsListTables.groupHeading(result.config.subtotalBy).toLowerCase()}',
            ),
          ),
          for (final g in groups) DataColumn(label: Text(g.label)),
          const DataColumn(label: Text('Overall')),
        ],
        rows: [
          for (var i = 0; i < overall.length; i++)
            row(i, [
              overall[i].label,
              for (final lines in perGroup)
                switch (lines[overall[i].label]) {
                  final l? => both(l),
                  null => '0',
                },
              both(overall[i]),
            ]),
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: table,
      ),
    );
  }

  static Map<String, GtsTallyLine> _byLabel(List<GtsTallyLine> lines) => {
    for (final l in lines) l.label: l,
  };
}

/// Column picker: every column grouped by section, with search and
/// select-all per section. Pops the new column keys, or null.
class GtsListColumnPicker extends StatefulWidget {
  const GtsListColumnPicker({super.key, required this.selected});

  /// Current column keys in display order.
  final List<String> selected;

  @override
  State<GtsListColumnPicker> createState() => _GtsListColumnPickerState();
}

class _GtsListColumnPickerState extends State<GtsListColumnPicker> {
  late final Set<String> _picked = {...widget.selected};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(GtsListColumn c) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.header.toLowerCase().contains(q) ||
        c.description.toLowerCase().contains(q) ||
        c.group.toLowerCase().contains(q);
  }

  /// Kept columns stay in place; new ones follow in questionnaire order.
  List<String> _result() => [
    for (final k in widget.selected)
      if (_picked.contains(k)) k,
    for (final c in GtsListColumns.all)
      if (_picked.contains(c.key) && !widget.selected.contains(c.key)) c.key,
  ];

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final g in GtsListColumns.groups)
        (g, GtsListColumns.inGroup(g).where(_matches).toList()),
    ].where((e) => e.$2.isNotEmpty).toList();
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
          title: 'Configure Columns',
          subtitle: 'Choose and reorder data columns to display.',
          icon: Icons.view_column_outlined,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
      content: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1, color: AdminColors.border),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Search, e.g. occupation or 16',
                filled: true,
                fillColor: AdminColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: groups.isEmpty
                  ? const Center(child: Text('No columns match.'))
                  : ListView(
                      children: [
                        for (final (group, columns) in groups) ...[
                          _groupHeader(group, columns),
                          for (final c in columns) _option(c),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            '${_picked.length} selected',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminReportsTheme.textMuted,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: AdminButtonStyles.outlined(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: AdminButtonStyles.filled(),
          onPressed: () => Navigator.of(context).pop(_result()),
          child: const Text('Use these columns'),
        ),
      ],
    );
  }

  Widget _groupHeader(String group, List<GtsListColumn> columns) {
    final all = columns.every((c) => _picked.contains(c.key));
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminReportsTheme.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              for (final c in columns) {
                all ? _picked.remove(c.key) : _picked.add(c.key);
              }
            }),
            child: Text(all ? 'Clear section' : 'Select all'),
          ),
        ],
      ),
    );
  }

  Widget _option(GtsListColumn c) {
    final subtitle = c.isAnswer ? c.description : null;
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _picked.contains(c.key),
      onChanged: (on) => setState(
        () => on == true ? _picked.add(c.key) : _picked.remove(c.key),
      ),
      title: Row(
        children: [
          Flexible(child: Text(c.header)),
          if (c.personal) ...[
            const SizedBox(width: 6),
            const Tooltip(
              message: 'Personal data',
              child: Icon(
                Icons.badge_outlined,
                size: 15,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
