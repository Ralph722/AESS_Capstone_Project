import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_tables.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_templates.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_validator.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_data_service.dart';
import 'package:alumni_system/features/admin/reports/data/gts_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/data/gts_saved_report_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_report_preview.dart';
import 'package:alumni_system/features/admin/reports/widgets/gts_saved_reports_bar.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

typedef GtsRespondentLoader =
    Future<List<GtsRespondent>> Function(List<String> surveyIds);

/// CHED GTS report builder: settings on one side, the live preview and
/// downloads on the other. Every number comes from [GtsReportEngine].
class GtsReportBuilderPanel extends StatefulWidget {
  const GtsReportBuilderPanel({
    super.key,
    required this.waves,
    this.loadRespondents,
    this.savedReports,
    this.respondentCache,
    this.initialConfig,
    this.onConfigChanged,
    this.initialOpen,
    this.onOpenChanged,
    this.onOpenList,
  });

  /// CHED GTS waves that can have responses, newest first.
  final List<Survey> waves;

  /// Settings to start from, e.g. kept by the page across tab switches.
  final GtsReportConfig? initialConfig;
  final ValueChanged<GtsReportConfig>? onConfigChanged;

  /// Defaults to [GtsReportDataService.loadRespondents].
  final GtsRespondentLoader? loadRespondents;

  /// Shared saved reports; the save and open controls are hidden when null.
  final GtsSavedReportStore? savedReports;

  /// Loaded responses per wave id, kept by the page so switching tabs does
  /// not download them again. "Reload responses" clears it.
  final Map<String, List<GtsRespondent>>? respondentCache;

  /// Saved report [initialConfig] was opened from or saved as.
  final GtsSavedReport? initialOpen;
  final ValueChanged<GtsSavedReport?>? onOpenChanged;

  /// Opens a saved alumni list in the list mode; lists are hidden when null.
  final ValueChanged<GtsSavedReport>? onOpenList;

  @override
  State<GtsReportBuilderPanel> createState() => _GtsReportBuilderPanelState();
}

class _GtsReportBuilderPanelState extends State<GtsReportBuilderPanel> {
  static const _topNChoices = [5, 10, 15];

  /// Calculations offered on screen. The others still run for older saved
  /// reports and are shown there with a note.
  static const _currentCalculations = {
    GtsCalculation.shareOfAnswered,
    GtsCalculation.count,
    GtsCalculation.medianBracket,
  };

  late GtsRespondentLoader _load;
  late GtsReportConfig _config;
  final _title = TextEditingController();
  late final Map<String, List<GtsRespondent>> _cache =
      widget.respondentCache ?? {};
  bool _loading = false;
  String? _loadError;
  GtsReportResult? _result;
  GtsReportValidation _validation = const GtsReportValidation([]);
  CustomReportFormat? _exporting;

  /// "Another question" was picked under Compare by, before a question.
  bool _pickingOtherGroup = false;

  /// Saved report the current settings were opened from or saved as.
  late GtsSavedReport? _open = widget.initialOpen;

  void _setOpen(GtsSavedReport? report) {
    setState(() => _open = report);
    widget.onOpenChanged?.call(report);
  }

  Map<String, String> get _waveLabels => {
    for (final w in widget.waves) w.id: w.title,
  };

  @override
  void initState() {
    super.initState();
    _load = widget.loadRespondents ?? GtsReportDataService().loadRespondents;
    final waveIds = {for (final w in widget.waves) w.id};
    final initial = widget.initialConfig;
    _config = initial != null
        ? initial.copyWith(
            surveyIds: [
              for (final id in initial.surveyIds)
                if (waveIds.contains(id)) id,
            ],
          )
        : GtsReportConfig(
            surveyIds: [if (widget.waves.isNotEmpty) widget.waves.first.id],
            measure: 'ched_16',
            population: GtsPopulation.rosterLinked,
            chart: GtsChartType.bar,
          );
    _title.text = _config.title;
    _refresh();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _update(GtsReportConfig next) {
    if (next.surveyIds.length > 1 &&
        !next.groupBy.contains(GtsFieldDictionary.wave) &&
        next.groupBy.length < GtsReportConfig.maxGroupBy) {
      next = next.copyWith(groupBy: [GtsFieldDictionary.wave, ...next.groupBy]);
    }
    if (GtsReportValidator.chartIssue(next, next.chart) != null) {
      final stacked =
          next.chart == GtsChartType.donut &&
          GtsReportValidator.chartIssue(next, GtsChartType.stackedBar) == null;
      next = next.copyWith(
        chart: stacked ? GtsChartType.stackedBar : GtsChartType.table,
      );
    }
    final result = _result;
    final titleOnly =
        result != null &&
        jsonEncode(next.copyWith(title: _config.title).toJson()) ==
            jsonEncode(_config.toJson());
    setState(() {
      _config = next;
      if (titleOnly) _result = result.retitled(next.title);
    });
    widget.onConfigChanged?.call(next);
    if (!titleOnly) _refresh();
  }

  void _applyTemplate(GtsReportTemplate template) {
    final next = template.forWaves(_config.surveyIds);
    _title.text = next.title;
    _pickingOtherGroup = false;
    _update(next);
  }

  void _setMeasure(String key) {
    final field = GtsFieldDictionary.byKey(key)!;
    final calc = field.allows(_config.calculation)
        ? _config.calculation
        : field.allows(GtsCalculation.shareOfAnswered)
        ? GtsCalculation.shareOfAnswered
        : _ordered(field.calculations).first;
    _update(
      _config.copyWith(
        measure: key,
        calculation: calc,
        groupBy: [
          for (final g in _config.groupBy)
            if (g != key) g,
        ],
        filters: [
          for (final f in _config.filters)
            if (f.field != key) f,
        ],
        clearGridColumn: true,
      ),
    );
  }

  /// Loads missing waves, then recalculates.
  Future<void> _refresh() async {
    final missing = [
      for (final id in _config.surveyIds)
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
          _loadError =
              'Could not load tracer responses. Check your '
              'connection and try again.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }
    _recalculate();
  }

  void _recalculate() {
    final validation = GtsReportValidator.validate(_config);
    GtsReportResult? result;
    if (validation.isValid && _config.surveyIds.every(_cache.containsKey)) {
      result = GtsReportEngine.run(_config, [
        for (final id in _config.surveyIds) ...?_cache[id],
      ], waveLabels: _waveLabels);
    }
    setState(() {
      _validation = validation;
      _result = result;
    });
  }

  void _reloadData() {
    _cache.clear();
    _refresh();
  }

  Future<void> _download(CustomReportFormat format) async {
    final result = _result;
    if (result == null || _exporting != null) return;
    setState(() => _exporting = format);
    try {
      final bytes = await GtsReportExportService.exportBytes(result, format);
      if (!mounted) return;
      tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName: GtsReportExportService.fileName(result, format),
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

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Settings differ from the opened saved report.
  bool get _hasUnsavedChanges {
    final open = _open;
    if (open == null) return false;
    try {
      return jsonEncode(_config.copyWith(title: open.name).toJson()) !=
          jsonEncode(open.settings.copyWith(title: open.name).toJson());
    } on FormatException {
      return true;
    }
  }

  void _openSaved(GtsSavedReport report) {
    final GtsReportConfig settings;
    try {
      settings = report.settings;
    } on FormatException catch (e) {
      _message(e.message);
      return;
    }
    final waveIds = {for (final w in widget.waves) w.id};
    final kept = [
      for (final id in settings.surveyIds)
        if (waveIds.contains(id)) id,
    ];
    final dropped = settings.surveyIds.length - kept.length;
    _setOpen(report);
    _title.text = report.name;
    _pickingOtherGroup = false;
    _update(settings.copyWith(surveyIds: kept, title: report.name));
    if (dropped > 0) {
      _message(
        dropped == 1
            ? '1 tracer wave in this report is no longer available and was '
                  'removed.'
            : '$dropped tracer waves in this report are no longer available '
                  'and were removed.',
      );
    }
  }

  static List<GtsCalculation> _ordered(Set<GtsCalculation> calcs) => [
    for (final c in GtsCalculation.values)
      if (calcs.contains(c)) c,
  ];

  /// Questions offered under "What do you want to know?".
  static List<GtsField> get _questions => [
    for (final f in GtsFieldDictionary.fields)
      if (!f.isPersonal &&
          f.othersOf == null &&
          f.source != GtsFieldSource.wave &&
          (f.allows(GtsCalculation.shareOfAnswered) ||
              f.allows(GtsCalculation.count)))
        f,
  ];

  bool get _comparingWaves => _config.surveyIds.length > 1;

  List<String> get _comparisons => [
    for (final g in _config.groupBy)
      if (g != GtsFieldDictionary.wave) g,
  ];

  String? get _compareBy => _comparisons.firstOrNull;

  String? get _thenBy => _comparisons.length > 1 ? _comparisons[1] : null;

  void _setWave(String id) {
    _update(
      _config.copyWith(
        surveyIds: [id],
        groupBy: _comparisons.take(GtsReportConfig.maxGroupBy).toList(),
      ),
    );
  }

  void _setCompareWaves(bool on) {
    final first = _config.surveyIds.firstOrNull ?? widget.waves.first.id;
    _update(
      on
          ? _config.copyWith(
              surveyIds: [for (final w in widget.waves) w.id],
              groupBy: [GtsFieldDictionary.wave, ?_compareBy],
            )
          : _config.copyWith(surveyIds: [first], groupBy: _comparisons),
    );
  }

  void _toggleComparedWave(String id, bool on) {
    _update(
      _config.copyWith(
        surveyIds: [
          for (final w in widget.waves)
            if (w.id == id ? on : _config.surveyIds.contains(w.id)) w.id,
        ],
      ),
    );
  }

  void _setCompareBy(String? key) {
    final then = _thenBy;
    _update(
      _config.copyWith(
        groupBy: [
          if (_comparingWaves) GtsFieldDictionary.wave,
          ?key,
          if (!_comparingWaves && key != null && then != null && then != key)
            then,
        ],
      ),
    );
  }

  void _setThenBy(String? key) {
    _update(
      _config.copyWith(groupBy: [?_compareBy, if (_compareBy != null) ?key]),
    );
  }

  /// Values offered for a filter on [field].
  List<(String, String)> _filterChoices(GtsField field) {
    if (field.source == GtsFieldSource.wave) {
      return [for (final id in _config.surveyIds) (id, _waveLabels[id] ?? id)];
    }
    if (field.options.isNotEmpty) {
      return [for (final o in field.options) (o, o)];
    }
    String cohort(GtsRespondent r) {
      final v = field.key == GtsFieldDictionary.course
          ? r.course.trim()
          : r.yearGraduated.trim();
      return v.isEmpty ? gtsUnknownLabel : v;
    }

    final seen = <String>{
      for (final id in _config.surveyIds)
        for (final r in _cache[id] ?? const <GtsRespondent>[]) cohort(r),
    };
    final list = seen.toList()
      ..sort((a, b) {
        if (a == gtsUnknownLabel) return 1;
        if (b == gtsUnknownLabel) return -1;
        return a.compareTo(b);
      });
    return [for (final v in list) (v, v)];
  }

  void _addFilter() {
    final used = {for (final f in _config.filters) f.field, _config.measure};
    for (final f in GtsFieldDictionary.filterable) {
      if (used.contains(f.key)) continue;
      _update(
        _config.copyWith(
          filters: [
            ..._config.filters,
            GtsReportFilter(field: f.key, values: const []),
          ],
        ),
      );
      return;
    }
  }

  Future<void> _pickQuestion() async {
    final key = await showDialog<String>(
      context: context,
      builder: (_) =>
          _QuestionPickerDialog(fields: _questions, selected: _config.measure),
    );
    if (key != null && key != _config.measure && mounted) _setMeasure(key);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.waves.isEmpty) {
      return _card(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No published CHED Graduate Tracer Study waves yet. Publish a '
            'tracer wave to build reports from its responses.',
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
            SizedBox(width: 400, child: settings),
            const SizedBox(width: 16),
            Expanded(child: preview),
          ],
        );
      },
    );
  }

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

  /// An older saved setting that is kept so the numbers do not change.
  Widget _olderSetting(String text, String action, VoidCallback? onPressed) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 12)),
            if (onPressed != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onPressed, child: Text(action)),
              ),
          ],
        ),
      );

  Widget _settings() {
    final measure = GtsFieldDictionary.byKey(_config.measure);
    final errors = _validation.of(GtsIssueSeverity.error).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Report settings',
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
            isList: false,
            open: _open,
            name: _title.text,
            settingsNamed: (name) => _config.copyWith(title: name).toJson(),
            canSave: _validation.isValid,
            unsavedChanges: _hasUnsavedChanges,
            onOpen: _openSaved,
            onOpenOther: widget.onOpenList,
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
        _section('Start from a ready-made report', [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in GtsReportTemplates.all) _templateCard(t),
            ],
          ),
          if (GtsReportTemplates.byKey(_config.templateKey) != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('You can change any setting below.', style: _muted),
            ),
        ]),
        TextField(
          controller: _title,
          decoration: _input('Report name (optional)'),
          onChanged: (v) => _update(_config.copyWith(title: v)),
        ),
        const SizedBox(height: 16),
        _section('Tracer wave', _waveSettings()),
        if (_config.population == GtsPopulation.allRespondents)
          _olderSetting(
            'This saved report counts every response, including people who '
                'are not on the active roster. This older setting is kept so '
                'its numbers do not change.',
            'Count roster graduates only',
            () => _update(
              _config.copyWith(population: GtsPopulation.rosterLinked),
            ),
          ),
        _section('1. What do you want to know?', [_questionTile(measure)]),
        _section('2. Compare by', _compareSettings()),
        _section('3. Only include', [
          if (_config.filters.isEmpty)
            const Text(
              'Every graduate in the tracer wave is included.',
              style: _muted,
            ),
          for (var i = 0; i < _config.filters.length; i++) _filterRow(i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addFilter,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add a condition'),
            ),
          ),
        ]),
        _section('4. Show as', _displaySettings(measure)),
        _moreOptions(measure),
        if (errors.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in errors)
                  Text(
                    e.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminReportsTheme.danger,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _templateCard(GtsReportTemplate t) {
    final selected = _config.templateKey == t.key;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('template-card-${t.key}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => _applyTemplate(t),
        child: Container(
          width: 176,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AdminReportsTheme.primary.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AdminReportsTheme.primary
                  : AdminReportsTheme.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AdminReportsTheme.primary.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AdminReportsTheme.primary
                            : AdminReportsTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AdminReportsTheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                t.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AdminReportsTheme.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _waveSettings() {
    final canCompare = widget.waves.length > 1;
    return [
      if (!_comparingWaves)
        DropdownButtonFormField<String>(
          key: ValueKey('wave-${_config.surveyIds.firstOrNull}'),
          initialValue: _config.surveyIds.firstOrNull,
          isExpanded: true,
          hint: const Text('Choose a tracer wave'),
          decoration: _input('Answers from'),
          items: [
            for (final w in widget.waves)
              DropdownMenuItem(
                value: w.id,
                child: Text(w.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            if (id != null) _setWave(id);
          },
        )
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final w in widget.waves)
              FilterChip(
                label: Text(w.title),
                selected: _config.surveyIds.contains(w.id),
                onSelected:
                    _config.surveyIds.contains(w.id) &&
                        _config.surveyIds.length <= 2
                    ? null
                    : (on) => _toggleComparedWave(w.id, on),
              ),
          ],
        ),
      Tooltip(
        message: canCompare ? '' : 'There is only one tracer wave so far.',
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Compare waves'),
          subtitle: _comparingWaves
              ? const Text('Each wave is shown side by side.')
              : null,
          value: _comparingWaves,
          onChanged: canCompare ? _setCompareWaves : null,
        ),
      ),
    ];
  }

  Widget _questionTile(GtsField? measure) {
    final prompt = measure?.prompt?.trim();
    return InkWell(
      key: const ValueKey('question-picker'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => unawaited(_pickQuestion()),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AdminReportsTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminReportsTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    measure?.numberedLabel ?? 'Choose a question',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (prompt != null && prompt.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(prompt, style: _muted),
                  ],
                  if (measure?.askedOf case final asked?) ...[
                    const SizedBox(height: 2),
                    Text('Asked only when $asked.', style: _muted),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Change',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminReportsTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _compareSettings() {
    final compareBy = _compareBy;
    const common = [
      GtsFieldDictionary.course,
      GtsFieldDictionary.yearGraduated,
    ];
    final other =
        _pickingOtherGroup ||
        (compareBy != null && !common.contains(compareBy));
    Widget chip(String label, String? key) => ChoiceChip(
      label: Text(label),
      selected: !other && compareBy == key,
      onSelected: key == _config.measure
          ? null
          : (_) {
              _pickingOtherGroup = false;
              _setCompareBy(key);
            },
    );
    final otherChoices = [
      for (final f in GtsFieldDictionary.groupable)
        if (f.source == GtsFieldSource.chedAnswer && f.key != _config.measure)
          f,
    ];
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          chip('None', null),
          chip('Course', GtsFieldDictionary.course),
          chip('Batch', GtsFieldDictionary.yearGraduated),
          ChoiceChip(
            label: const Text('Another question'),
            selected: other,
            onSelected: (_) => setState(() => _pickingOtherGroup = true),
          ),
        ],
      ),
      if (other) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('compare-other-$compareBy'),
          initialValue: otherChoices.any((f) => f.key == compareBy)
              ? compareBy
              : null,
          isExpanded: true,
          hint: const Text('Choose a question'),
          decoration: _input('Compare by the answer to'),
          items: [
            for (final f in otherChoices)
              DropdownMenuItem(
                value: f.key,
                child: Text(f.numberedLabel, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (k) {
            if (k != null) _setCompareBy(k);
          },
        ),
      ],
      if (_comparingWaves)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Waves are compared too (see "Compare waves").',
            style: _muted,
          ),
        ),
    ];
  }

  List<Widget> _displaySettings(GtsField? measure) {
    final calc = _config.calculation;
    final canPercent = measure?.allows(GtsCalculation.shareOfAnswered) ?? false;
    final canCount = measure?.allows(GtsCalculation.count) ?? false;
    final unavailable = [
      for (final t in GtsChartType.values)
        if (GtsReportValidator.chartIssue(_config, t) case final reason?)
          '${_chartLabel(t)}: $reason',
    ];
    return [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final t in GtsChartType.values) _chartTile(t)],
      ),
      if (unavailable.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Greyed out: ${unavailable.join(' ')}', style: _muted),
      ],
      if (canPercent || canCount) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Numbers', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<GtsCalculation>(
                showSelectedIcon: false,
                emptySelectionAllowed: true,
                segments: [
                  ButtonSegment(
                    value: GtsCalculation.shareOfAnswered,
                    label: const Text('Percent'),
                    enabled: canPercent,
                  ),
                  ButtonSegment(
                    value: GtsCalculation.count,
                    label: const Text('Number of graduates'),
                    enabled: canCount,
                  ),
                ],
                selected: {
                  if (calc == GtsCalculation.shareOfAnswered ||
                      calc == GtsCalculation.count)
                    calc,
                },
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) {
                    _update(_config.copyWith(calculation: s.single));
                  }
                },
              ),
            ),
          ],
        ),
        if (calc == GtsCalculation.shareOfAnswered && measure != null) ...[
          const SizedBox(height: 4),
          Text(
            GtsReportValidator.shareExplanation(measure, calc),
            style: _muted,
          ),
        ],
        if (calc == GtsCalculation.medianBracket)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Showing the middle bracket (see More options).',
              style: _muted,
            ),
          ),
      ],
      if (!_currentCalculations.contains(calc)) ...[
        const SizedBox(height: 8),
        _olderSetting(
          'This saved report shows "${GtsReportTables.calculationLabel(calc)}"'
          ', an older setting kept so its numbers do not change.',
          canPercent ? 'Use Percent' : 'Use Number of graduates',
          canPercent || canCount
              ? () => _update(
                  _config.copyWith(
                    calculation: canPercent
                        ? GtsCalculation.shareOfAnswered
                        : GtsCalculation.count,
                  ),
                )
              : null,
        ),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('Show the table under the chart'),
        value: _config.showTable,
        onChanged: (v) => _update(_config.copyWith(showTable: v)),
      ),
    ];
  }

  Widget _moreOptions(GtsField? measure) {
    final compareBy = _compareBy;
    final thenChoices = [
      for (final f in GtsFieldDictionary.groupable)
        if (f.source != GtsFieldSource.wave &&
            f.key != _config.measure &&
            f.key != compareBy)
          f,
    ];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const PageStorageKey('gts-more-options'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text('More options', style: _heading),
        children: [
          if (measure != null && measure.valueClass == GtsValueClass.grid) ...[
            DropdownButtonFormField<String?>(
              key: ValueKey('grid-${_config.measure}'),
              initialValue: _config.gridColumn,
              isExpanded: true,
              decoration: _input('Job'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any job')),
                for (final c in measure.gridColumns)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (c) => _update(
                c == null
                    ? _config.copyWith(clearGridColumn: true)
                    : _config.copyWith(gridColumn: c),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<GtsSortBy>(
                  initialValue: _config.sortBy,
                  isExpanded: true,
                  decoration: _input('Order answers by'),
                  items: [
                    const DropdownMenuItem(
                      value: GtsSortBy.natural,
                      child: Text('Questionnaire order'),
                    ),
                    const DropdownMenuItem(
                      value: GtsSortBy.count,
                      child: Text('Number of graduates'),
                    ),
                    const DropdownMenuItem(
                      value: GtsSortBy.label,
                      child: Text('Alphabetical'),
                    ),
                    if (_config.sortBy == GtsSortBy.share)
                      const DropdownMenuItem(
                        value: GtsSortBy.share,
                        child: Text('Share'),
                      ),
                  ],
                  onChanged: (s) => _update(
                    _config.copyWith(
                      sortBy: s,
                      sortDescending: s == GtsSortBy.count,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _config.topN,
                  isExpanded: true,
                  decoration: _input('Answers shown'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final n in {..._topNChoices, ?_config.topN})
                      DropdownMenuItem(value: n, child: Text('Top $n')),
                  ],
                  onChanged: (n) => _update(
                    n == null
                        ? _config.copyWith(clearTopN: true)
                        : _config.copyWith(topN: n),
                  ),
                ),
              ),
            ],
          ),
          if (measure?.allows(GtsCalculation.medianBracket) ?? false)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Show the middle bracket (median)'),
              subtitle: const Text(
                'The bracket half of the graduates are at or below. '
                'Shown as a table.',
              ),
              value: _config.calculation == GtsCalculation.medianBracket,
              onChanged: (on) => _update(
                _config.copyWith(
                  calculation: on
                      ? GtsCalculation.medianBracket
                      : GtsCalculation.shareOfAnswered,
                ),
              ),
            ),
          if (!_comparingWaves && compareBy != null) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: ValueKey('then-$compareBy-$_thenBy'),
              initialValue: thenChoices.any((f) => f.key == _thenBy)
                  ? _thenBy
                  : null,
              isExpanded: true,
              decoration: _input('Then split each group by'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Nothing')),
                for (final f in thenChoices)
                  DropdownMenuItem(
                    value: f.key,
                    child: Text(
                      f.numberedLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _setThenBy,
            ),
          ],
        ],
      ),
    );
  }

  static String _chartLabel(GtsChartType t) => switch (t) {
    GtsChartType.table => 'Table only',
    GtsChartType.bar => 'Bars',
    GtsChartType.horizontalBar => 'Horizontal bars',
    GtsChartType.donut => 'Donut',
    GtsChartType.line => 'Line',
    GtsChartType.groupedBar => 'Grouped bars',
    GtsChartType.stackedBar => 'Stacked bars',
  };

  static IconData _chartIcon(GtsChartType t) => switch (t) {
    GtsChartType.table => Icons.table_chart_outlined,
    GtsChartType.bar => Icons.bar_chart,
    GtsChartType.horizontalBar => Icons.align_horizontal_left,
    GtsChartType.donut => Icons.donut_large,
    GtsChartType.line => Icons.show_chart,
    GtsChartType.groupedBar => Icons.insert_chart_outlined,
    GtsChartType.stackedBar => Icons.stacked_bar_chart,
  };

  Widget _chartTile(GtsChartType type) {
    final reason = GtsReportValidator.chartIssue(_config, type);
    final enabled = reason == null;
    final selected = _config.chart == type;
    final color = !enabled
        ? AdminReportsTheme.textMuted.withValues(alpha: 0.45)
        : selected
        ? AdminReportsTheme.primary
        : AdminReportsTheme.textMuted;
    return Tooltip(
      message: reason ?? _chartLabel(type),
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        child: InkWell(
          key: ValueKey('chart-${type.name}'),
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? () => _update(_config.copyWith(chart: type)) : null,
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: selected
                  ? AdminReportsTheme.primary.withValues(alpha: 0.06)
                  : enabled
                  ? AdminReportsTheme.card
                  : AdminReportsTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? AdminReportsTheme.primary
                    : AdminReportsTheme.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(_chartIcon(type), size: 26, color: color),
                const SizedBox(height: 4),
                Text(
                  _chartLabel(type),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterRow(int index) {
    final filter = _config.filters[index];
    final field = GtsFieldDictionary.byKey(filter.field);
    final taken = {
      for (var i = 0; i < _config.filters.length; i++)
        if (i != index) _config.filters[i].field,
    };
    void replace(GtsReportFilter? next) {
      final list = [..._config.filters];
      if (next == null) {
        list.removeAt(index);
      } else {
        list[index] = next;
      }
      _update(_config.copyWith(filters: list));
    }

    final sentence = GtsReportTables.filterSentence(
      filter,
      (id) => _waveLabels[id] ?? id,
    );
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
          if (sentence != null) ...[
            Text(
              sentence,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('filter-$index-${filter.field}'),
                  initialValue: filter.field,
                  isExpanded: true,
                  decoration: _input('Only graduates whose'),
                  items: [
                    for (final f in GtsFieldDictionary.filterable)
                      if (f.key != _config.measure && !taken.contains(f.key))
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
                tooltip: 'Remove condition',
                onPressed: () => replace(null),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (field != null) ...[
            const SizedBox(height: 6),
            Text(
              field.valueClass == GtsValueClass.multiSelect
                  ? 'includes any of:'
                  : 'is any of:',
              style: _muted,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final (value, label) in _filterChoices(field))
                  FilterChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: filter.values.contains(value),
                    onSelected: (on) => replace(
                      GtsReportFilter(
                        field: filter.field,
                        values: [
                          for (final (v, _) in _filterChoices(field))
                            if (v == value ? on : filter.values.contains(v)) v,
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewArea() {
    final result = _result;
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
            for (final f in CustomReportFormat.values)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: OutlinedButton.icon(
                  onPressed: result == null || _exporting != null
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
        else if (result == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Fix the highlighted settings to see the report.',
              style: TextStyle(color: AdminReportsTheme.textMuted),
            ),
          )
        else
          GtsReportPreview(result: result),
      ],
    );
  }
}

/// Picks the CHED question to report on: numbered, grouped by section, with
/// search. Pops the field key, or null.
class _QuestionPickerDialog extends StatefulWidget {
  const _QuestionPickerDialog({required this.fields, required this.selected});

  final List<GtsField> fields;
  final String selected;

  @override
  State<_QuestionPickerDialog> createState() => _QuestionPickerDialogState();
}

class _QuestionPickerDialogState extends State<_QuestionPickerDialog> {
  static const _rosterSection = 'Graduate details (roster)';

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(GtsField f, String q) =>
      q.isEmpty ||
      f.numberedLabel.toLowerCase().contains(q) ||
      (f.prompt?.toLowerCase().contains(q) ?? false);

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final bySection = <String, List<GtsField>>{};
    for (final f in widget.fields) {
      if (!_matches(f, q)) continue;
      (bySection[f.section ?? _rosterSection] ??= []).add(f);
    }
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
          title: 'Select Question',
          subtitle: 'Choose a question or data field from the CHED GTS.',
          icon: Icons.help_outline_rounded,
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
                hintText: 'Search, e.g. employed or 16',
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
              child: bySection.isEmpty
                  ? const Center(child: Text('No question matches.'))
                  : ListView(
                      children: [
                        for (final MapEntry(key: section, value: fields)
                            in bySection.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                            child: Text(
                              section,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AdminReportsTheme.primary,
                              ),
                            ),
                          ),
                          for (final f in fields)
                            ListTile(
                              dense: true,
                              selected: f.key == widget.selected,
                              title: Text(f.numberedLabel),
                              subtitle: f.prompt == null
                                  ? null
                                  : Text(
                                      f.prompt!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => Navigator.of(context).pop(f.key),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: AdminButtonStyles.outlined(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
