import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/ustp_colors.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_columns.dart';
import 'package:alumni_system/features/admin/reports/application/gts_list_narrative.dart';
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
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/personal_data_export_dialog.dart';

typedef GtsListResponseLoader =
    Future<List<GtsListResponse>> Function(List<String> surveyIds);

typedef GtsListProfileLoader =
    Future<Map<String, TracerProfile>> Function(List<String> userIds);

/// Alumni list builder: one row per alumnus on the alumni list with the
/// columns the admin picks, and the tracer-status tally underneath.
class GtsAlumniListPanel extends StatefulWidget {
  const GtsAlumniListPanel({
    super.key,
    required this.waves,
    required this.roster,
    this.loadResponses,
    this.loadProfiles,
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

  /// Legacy hook for opening a saved summary report. Unused now that Builder
  /// is list-only; kept optional so older call sites compile.
  final ValueChanged<GtsSavedReport>? onOpenSummary;

  /// CHED GTS waves that can have responses, newest first.
  final List<Survey> waves;

  /// Every alumni list record; deactivated records are left out of the list.
  final List<AlumniMember> roster;

  /// Defaults to [GtsListDataService.loadResponses].
  final GtsListResponseLoader? loadResponses;

  /// Section A profiles for registered alumni. Defaults to
  /// [GtsListDataService.loadProfiles].
  final GtsListProfileLoader? loadProfiles;

  /// Loaded responses per wave id, kept by the page across tab switches.
  final Map<String, List<GtsListResponse>>? responseCache;

  final GtsListConfig? initialConfig;
  final ValueChanged<GtsListConfig>? onConfigChanged;

  @override
  State<GtsAlumniListPanel> createState() => _GtsAlumniListPanelState();
}

class _GtsAlumniListPanelState extends State<GtsAlumniListPanel> {
  late GtsListResponseLoader _load;
  late GtsListProfileLoader _loadProfiles;
  late GtsListConfig _config;
  late final Map<String, List<GtsListResponse>> _cache =
      widget.responseCache ?? {};
  bool _loading = false;
  bool _reloadAfterLoad = false;
  CustomReportFormat? _exporting;
  bool _savingTemplate = false;
  List<GtsSavedReport> _savedTemplates = const [];

  /// Excel first: it suits wide lists best.
  static const _downloadOrder = [
    CustomReportFormat.excel,
    CustomReportFormat.csv,
    CustomReportFormat.pdf,
  ];
  String? _loadError;
  String? _profileWarning;
  GtsAlumniListResult? _result;
  String _explanation = '';
  final Map<String, TracerProfile> _profiles = {};
  final Set<String> _profileMiss = {};

  /// Saved list template the current settings were opened from or saved as.
  late GtsSavedReport? _open = widget.initialOpen;

  void _setOpen(GtsSavedReport? report) {
    setState(() => _open = report);
    widget.onOpenChanged?.call(report);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

  Future<void> _loadSavedTemplates() async {
    final store = widget.savedReports;
    if (store == null) return;
    try {
      final list = await store.list();
      if (!mounted) return;
      setState(() {
        _savedTemplates = [for (final r in list) if (r.isList) r];
      });
    } catch (_) {
      if (!mounted) return;
      _message('Saved templates could not be loaded.');
    }
  }

  /// Keeps the ready-made dropdown in sync before a network refresh finishes.
  List<GtsSavedReport> _withSavedTemplate(
    List<GtsSavedReport> current,
    GtsSavedReport saved,
  ) {
    final next = [
      for (final r in current)
        if (r.id != saved.id) r,
      saved,
    ];
    next.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return next;
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
      settings.copyWith(
        title: report.name,
        templateKey: GtsListTemplates.savedKey(report.id),
      ),
    );
    _setOpen(report);
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
    _setOpen(null);
    _update(template.forWave(_config.surveyId));
  }

  void _clearTemplate() {
    _setOpen(null);
    _update(_config.copyWith(clearTemplateKey: true, title: ''));
  }

  /// Only returns keys that exist in the ready-made dropdown items. Returning
  /// a [saved:] key before it is in [_savedTemplates] crashes DropdownButton.
  String? get _selectedTemplateKey {
    final key = _config.templateKey;
    if (key == null) return null;
    if (GtsListTemplates.byKey(key) != null) return key;
    final savedId = GtsListTemplates.savedReportId(key);
    if (savedId != null &&
        _savedTemplates.any((r) => r.id == savedId)) {
      return key;
    }
    return null;
  }

  String? get _selectedTemplateSummary {
    final key = _selectedTemplateKey;
    if (key == null) return null;
    if (GtsListTemplates.byKey(key) case final t?) return t.summary;
    final id = GtsListTemplates.savedReportId(key);
    if (id == null) return null;
    for (final r in _savedTemplates) {
      if (r.id == id) return 'Your saved list template.';
    }
    return null;
  }

  Future<void> _saveTemplate() async {
    final store = widget.savedReports;
    if (store == null || _savingTemplate) return;
    final open = _open;
    String name;
    if (open == null) {
      final suggested = _config.title.trim();
      final asked = await showDialog<String>(
        context: context,
        builder: (_) => GtsSavedNameDialog(
          initial: suggested,
          title: 'Save Template',
          subtitle:
              'Name this list setup. It will appear under Ready-made list.',
          fieldLabel: 'Template name *',
          helperText: 'Saved templates are available to all administrators.',
        ),
      );
      if (asked == null || !mounted) return;
      name = asked;
    } else {
      name = open.name;
    }
    setState(() => _savingTemplate = true);
    try {
      var keyed = _config.copyWith(
        title: name,
        templateKey: open == null
            ? null
            : GtsListTemplates.savedKey(open.id),
      );
      var saved = await store.save(
        id: open?.id,
        name: name,
        settings: keyed.toJson(),
      );
      if (open == null) {
        keyed = keyed.copyWith(
          templateKey: GtsListTemplates.savedKey(saved.id),
        );
        saved = await store.save(
          id: saved.id,
          name: name,
          settings: keyed.toJson(),
        );
      }
      if (!mounted) return;
      setState(() {
        _open = saved;
        _config = keyed;
        _savedTemplates = _withSavedTemplate(_savedTemplates, saved);
      });
      widget.onOpenChanged?.call(saved);
      widget.onConfigChanged?.call(keyed);
      _message('Saved template "${saved.name}".');
      await _loadSavedTemplates();
    } on GtsSavedReportNameTaken catch (e) {
      _message(
        'A template named "${e.name}" already exists. Choose another name.',
      );
    } catch (_) {
      _message(
        'Could not save the template. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _savingTemplate = false);
    }
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
    _load = widget.loadResponses ?? (ids) => GtsListDataService().loadResponses(ids);
    _loadProfiles =
        widget.loadProfiles ?? (ids) => GtsListDataService().loadProfiles(ids);
    final initial = widget.initialConfig;
    _config = initial == null
        ? GtsListConfig(surveyId: widget.waves.firstOrNull?.id)
        : _withKnownWave(initial).$1;
    unawaited(_loadSavedTemplates());
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(GtsAlumniListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.roster, widget.roster)) unawaited(_refresh());
    if (!identical(oldWidget.savedReports, widget.savedReports)) {
      unawaited(_loadSavedTemplates());
    }
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
    final missingProfiles = _profileWarning == null ? _missingProfileIds() : const <String>[];
    if (missing.isNotEmpty || missingProfiles.isNotEmpty) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
      try {
        if (missing.isNotEmpty) {
          final rows = await _load(missing);
          for (final id in missing) {
            _cache[id] = [];
          }
          for (final r in rows) {
            (_cache[r.surveyId] ??= []).add(r);
          }
        }
        if (missingProfiles.isNotEmpty) await _loadMissingProfiles(missingProfiles);
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

  List<String> _missingProfileIds() => [
    for (final member in widget.roster)
      if (member.isRegisteredUser && (member.authUid ?? '').trim().isNotEmpty)
        if (!_profiles.containsKey(member.authUid!.trim()) &&
            !_profileMiss.contains(member.authUid!.trim()))
          member.authUid!.trim(),
  ];

  Future<void> _loadMissingProfiles(List<String> ids) async {
    try {
      final found = await _loadProfiles(ids);
      for (final id in ids) {
        final profile = found[id];
        if (profile == null) {
          _profileMiss.add(id);
        } else {
          _profiles[id] = profile;
        }
      }
      _profileWarning = null;
    } catch (_) {
      _profileWarning =
          'Registered profile details could not be loaded. Section A for '
          'alumni who have not answered the tracer may be incomplete.';
    }
  }

  Map<String, Map<String, dynamic>> _sectionAByUser() {
    final out = <String, Map<String, dynamic>>{};
    for (final member in widget.roster) {
      if (!member.isRegisteredUser) continue;
      final uid = (member.authUid ?? '').trim();
      if (uid.isEmpty) continue;
      final profile = _profiles[uid];
      out[uid] = profile == null
          ? GtsListColumns.sectionANameOnly(member.fullName)
          : GtsListColumns.sectionAFromProfile(
              profile,
              rosterName: member.fullName,
            );
    }
    return out;
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
      sectionAByUser: _sectionAByUser(),
    );
    setState(() {
      _result = result;
      _explanation = GtsListNarrative.compose(result);
    });
  }

  void _reloadData() {
    _cache.clear();
    _profiles.clear();
    _profileMiss.clear();
    _profileWarning = null;
    unawaited(_refresh());
  }

  static const _muted = TextStyle(
    fontSize: 12,
    color: AdminColors.textMuted,
  );

  Widget _stepCard({
    required String step,
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AdminColors.surface,
              border: Border(bottom: BorderSide(color: AdminColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: UstpColors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
      borderSide: const BorderSide(color: AdminColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
      borderSide: const BorderSide(color: AdminColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
      borderSide: const BorderSide(color: UstpColors.blue, width: 1.5),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AdminColors.textPrimary,
      ),
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AdminColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.format_list_bulleted_rounded, size: 18, color: AdminColors.primary),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'List Builder',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
              ),
            ),
            IconButton(
              tooltip: 'Reload responses',
              onPressed: _loading ? null : _reloadData,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AdminColors.textSecondary),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _stepCard(
          step: '1',
          title: 'Scope & Template',
          subtitle: 'Choose tracer wave and baseline list',
          children: [
            DropdownButtonFormField<String?>(
              key: ValueKey('wave-${_config.surveyId}'),
              initialValue: _config.surveyId,
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.textPrimary,
              ),
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
                padding: EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  'Each graduate\'s newest answer from any tracer wave.',
                  style: _muted,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(
                      'list-template-$_selectedTemplateKey-'
                      '${_savedTemplates.length}',
                    ),
                    initialValue: _selectedTemplateKey,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AdminColors.textPrimary,
                    ),
                    decoration: _input('Start from a ready-made list'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Custom list'),
                      ),
                      for (final t in GtsListTemplates.all)
                        DropdownMenuItem(
                          value: t.key,
                          child: Text(t.name, overflow: TextOverflow.ellipsis),
                        ),
                      for (final r in _savedTemplates)
                        DropdownMenuItem(
                          value: GtsListTemplates.savedKey(r.id),
                          child: Text(r.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (k) {
                      if (k == null) {
                        _clearTemplate();
                        return;
                      }
                      if (GtsListTemplates.byKey(k) case final t?) {
                        _applyTemplate(t);
                        return;
                      }
                      final id = GtsListTemplates.savedReportId(k);
                      for (final r in _savedTemplates) {
                        if (r.id == id) {
                          _openSaved(r);
                          return;
                        }
                      }
                    },
                  ),
                ),
                if (_selectedTemplateKey != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      tooltip: 'Back to custom list',
                      onPressed: _clearTemplate,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (_selectedTemplateSummary case final summary?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(summary, style: _muted),
              ),
          ],
        ),
        _stepCard(
          step: '2',
          title: 'Columns',
          subtitle: 'Select and reorder columns for alumni data',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AdminColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${columns.length} columns',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AdminColors.primary,
              ),
            ),
          ),
          children: [
            _columnList(columns),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_pickColumns(columns)),
                style: AdminButtonStyles.outlined(),
                icon: const Icon(Icons.view_column_outlined, size: 16),
                label: const Text('Add or remove columns'),
              ),
            ),
          ],
        ),
        _stepCard(
          step: '3',
          title: 'Filters (Only Include)',
          subtitle: 'Filter by tracer status, course, batch, or answers',
          children: [
            _label('Tracer status'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in GtsTracerStatus.values)
                  FilterChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(s.label),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _config.statuses.contains(s) ? FontWeight.w700 : FontWeight.w500,
                      color: _config.statuses.contains(s) ? AdminColors.primary : AdminColors.textPrimary,
                    ),
                    selected: _config.statuses.contains(s),
                    selectedColor: AdminColors.primary.withValues(alpha: 0.1),
                    backgroundColor: AdminColors.surface,
                    checkmarkColor: AdminColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                      side: BorderSide(
                        color: _config.statuses.contains(s) ? AdminColors.primary : AdminColors.border,
                        width: _config.statuses.contains(s) ? 1.4 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
            const SizedBox(height: 10),
            _label('Course'),
            _chips(
              _courseChoices,
              _config.courses,
              (v, on) => _update(
                _config.copyWith(courses: _toggled(_config.courses, v, on)),
              ),
            ),
            const SizedBox(height: 10),
            _label('Batch'),
            _chips(
              _batchChoices,
              _config.batches,
              (v, on) => _update(
                _config.copyWith(batches: _toggled(_config.batches, v, on)),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AdminColors.border),
            const SizedBox(height: 8),
            for (var i = 0; i < _config.answerFilters.length; i++)
              _answerFilterRow(i),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addAnswerFilter,
                style: AdminButtonStyles.outlined(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Only graduates who answered…'),
              ),
            ),
          ],
        ),
        _stepCard(
          step: '4',
          title: 'Grouping & Sorting',
          subtitle: 'Order rows, add subtotals, and choose what the export includes',
          children: [
            _label('Order'),
            _sortControls(),
            const SizedBox(height: 10),
            _label('Subtotals'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in GtsListSubtotal.values)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(switch (s) {
                      GtsListSubtotal.none => 'Overall only',
                      GtsListSubtotal.batch => 'By batch',
                      GtsListSubtotal.course => 'By course',
                    }),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _config.subtotalBy == s ? FontWeight.w700 : FontWeight.w500,
                      color: _config.subtotalBy == s ? AdminColors.primary : AdminColors.textPrimary,
                    ),
                    selected: _config.subtotalBy == s,
                    selectedColor: AdminColors.primary.withValues(alpha: 0.1),
                    backgroundColor: AdminColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                      side: BorderSide(
                        color: _config.subtotalBy == s ? AdminColors.primary : AdminColors.border,
                        width: _config.subtotalBy == s ? 1.4 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    onSelected: (_) => _update(_config.copyWith(subtotalBy: s)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _label('Include in the preview and the export'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: const Text('Alumni table'),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _config.includeTable ? FontWeight.w700 : FontWeight.w500,
                    color: _config.includeTable ? AdminColors.primary : AdminColors.textPrimary,
                  ),
                  selected: _config.includeTable,
                  selectedColor: AdminColors.primary.withValues(alpha: 0.1),
                  backgroundColor: AdminColors.surface,
                  checkmarkColor: AdminColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                    side: BorderSide(
                      color: _config.includeTable ? AdminColors.primary : AdminColors.border,
                      width: _config.includeTable ? 1.4 : 1.0,
                    ),
                  ),
                  onSelected: (on) => _update(_config.copyWith(includeTable: on)),
                ),
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: const Text('Tally'),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _config.includeTally ? FontWeight.w700 : FontWeight.w500,
                    color: _config.includeTally ? AdminColors.primary : AdminColors.textPrimary,
                  ),
                  selected: _config.includeTally,
                  selectedColor: AdminColors.primary.withValues(alpha: 0.1),
                  backgroundColor: AdminColors.surface,
                  checkmarkColor: AdminColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                    side: BorderSide(
                      color: _config.includeTally ? AdminColors.primary : AdminColors.border,
                      width: _config.includeTally ? 1.4 : 1.0,
                    ),
                  ),
                  onSelected: (on) => _update(_config.copyWith(includeTally: on)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _label('Chart'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in GtsListChart.values)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(switch (c) {
                      GtsListChart.none => 'No chart',
                      GtsListChart.bars => 'Horizontal bars',
                      GtsListChart.verticalBars => 'Vertical bars',
                      GtsListChart.donut => 'Donut',
                      GtsListChart.pie => 'Pie chart',
                    }),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _config.chart == c ? FontWeight.w700 : FontWeight.w500,
                      color: _config.chart == c ? AdminColors.primary : AdminColors.textPrimary,
                    ),
                    selected: _config.chart == c,
                    selectedColor: AdminColors.primary.withValues(alpha: 0.1),
                    backgroundColor: AdminColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                      side: BorderSide(
                        color: _config.chart == c ? AdminColors.primary : AdminColors.border,
                        width: _config.chart == c ? 1.4 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    onSelected: (_) => _update(_config.copyWith(chart: c)),
                  ),
              ],
            ),
          ],
        ),
        if (widget.savedReports != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _savingTemplate
                  ? null
                  : () => unawaited(_saveTemplate()),
              style: AdminButtonStyles.filled(),
              icon: _savingTemplate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(
                _open == null ? 'Save template' : 'Save template changes',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _chips(
    List<String> choices,
    List<String> selected,
    void Function(String value, bool on) onChanged,
  ) {
    if (choices.isEmpty) {
      return const Text('None recorded on the alumni list.', style: _muted);
    }
    final picked = {for (final s in selected) s.trim().toLowerCase()};
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in choices)
          FilterChip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(c),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: picked.contains(c.toLowerCase()) ? FontWeight.w700 : FontWeight.w500,
              color: picked.contains(c.toLowerCase()) ? AdminColors.primary : AdminColors.textPrimary,
            ),
            selected: picked.contains(c.toLowerCase()),
            selectedColor: AdminColors.primary.withValues(alpha: 0.1),
            backgroundColor: AdminColors.surface,
            checkmarkColor: AdminColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              side: BorderSide(
                color: picked.contains(c.toLowerCase()) ? AdminColors.primary : AdminColors.border,
                width: picked.contains(c.toLowerCase()) ? 1.4 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            onSelected: (on) => onChanged(c, on),
          ),
      ],
    );
  }

  Widget _columnList(List<GtsListColumn> columns) {
    if (columns.isEmpty) {
      return const Text(
        'No columns yet. Add the details you want to see.',
        style: _muted,
      );
    }
    final radius = BorderRadius.circular(AdminSurfaces.radiusSm);
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
      // Default drag proxy is a sharp Material rect; clip + round so the
      // floating chip matches the resting card corners.
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(animation.value);
            return Material(
              elevation: 1 + 5 * t,
              color: Colors.transparent,
              shadowColor: const Color(0x330F172A),
              surfaceTintColor: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, i) {
        final c = columns[i];
        return Padding(
          key: ValueKey(c.key),
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: AdminColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: const BorderSide(color: AdminColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Tooltip(
                      message: c.description,
                      child: Text(
                        c.header,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (c.personal)
                    const Tooltip(
                      message: 'Personal data',
                      child: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.badge_outlined,
                          size: 16,
                          color: AdminColors.warning,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Remove column',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeColumn(columns, c.key),
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
    final picked = await showDialog<GtsListColumnPickResult>(
      context: context,
      builder: (_) => GtsListColumnPicker(
        selected: [for (final c in current) c.key],
        includeUntracked: _config.includeUntracked,
      ),
    );
    if (picked == null || !mounted) return;
    final columns = GtsListConfig.migrateColumns(picked.columns);
    final sortBy = _config.sortBy == null
        ? null
        : GtsListConfig.migrateSort(_config.sortBy);
    _update(
      _config.copyWith(
        columns: columns,
        includeUntracked: picked.includeUntracked,
        clearSortBy: sortBy != null && !columns.contains(sortBy),
        sortBy: sortBy,
      ),
    );
  }

  Widget _sortControls() {
    final columns = GtsListColumns.displayColumns(_config);
    final sortBy = _config.sortBy == null
        ? null
        : GtsListConfig.migrateSort(_config.sortBy);
    final current = columns.any((c) => c.key == sortBy) ? sortBy : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          key: ValueKey('sort-$current-${columns.length}'),
          initialValue: current,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          style: const TextStyle(
            fontSize: 13,
            color: AdminColors.textPrimary,
          ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
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
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdminColors.textPrimary,
                  ),
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
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in field.options)
                  FilterChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(o),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: filter.values.contains(o) ? FontWeight.w700 : FontWeight.w500,
                      color: filter.values.contains(o) ? AdminColors.primary : AdminColors.textPrimary,
                    ),
                    selected: filter.values.contains(o),
                    selectedColor: AdminColors.primary.withValues(alpha: 0.1),
                    backgroundColor: AdminColors.surface,
                    checkmarkColor: AdminColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                      side: BorderSide(
                        color: filter.values.contains(o) ? AdminColors.primary : AdminColors.border,
                        width: filter.values.contains(o) ? 1.4 : 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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

  Widget _card(Widget child, {bool scroll = false}) {
    final body = scroll
        ? SizedBox.expand(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          )
        : Padding(padding: const EdgeInsets.all(16), child: child);
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }

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
        final isWide = constraints.maxWidth >= 1050;
        final bounded = constraints.hasBoundedHeight;
        final settings = _card(_settings(), scroll: bounded);
        final preview = _card(_previewArea(), scroll: bounded);

        if (!isWide) {
          if (!bounded) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [settings, const SizedBox(height: 16), preview],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: settings),
              const SizedBox(height: 16),
              Expanded(flex: 6, child: preview),
            ],
          );
        }
        // Stretch only when height is bounded (Reports tab viewport). In
        // unbounded scroll hosts (tests / nested scroll), start-align.
        return Row(
          crossAxisAlignment: bounded
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            SizedBox(width: 320, child: settings),
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
      final bytes = await GtsListExportService.exportBytes(
        result,
        format,
        explanation: _explanation,
      );
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
    final columnCount = GtsListColumns.displayColumns(_config).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: UstpColors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              ),
              child: const Icon(Icons.visibility_outlined, size: 16, color: UstpColors.blue),
            ),
            const SizedBox(width: 8),
            const Text(
              'Preview',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
            ),
            const Spacer(),
            for (final f in _downloadOrder)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: OutlinedButton.icon(
                  onPressed: result == null || _loading || _exporting != null
                      ? null
                      : () => unawaited(_download(f)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UstpColors.blue,
                    side: const BorderSide(color: AdminColors.border),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 30),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                    ),
                  ),
                  icon: _exporting == f
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2, color: UstpColors.blue),
                        )
                      : const Icon(Icons.download_outlined, size: 14),
                  label: Text(
                    f.label,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (result != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: OutlinedButton.icon(
                  onPressed: () => _showFullPreviewModal(context, result),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UstpColors.blue,
                    side: const BorderSide(color: AdminColors.border),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 30),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_full_rounded, size: 14),
                  label: const Text(
                    'Expand view',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
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
          GtsAlumniListPreview(
            result: result,
            explanation: _explanation,
            profileWarning: _profileWarning,
          ),
      ],
    );
  }

  void _showFullPreviewModal(BuildContext context, GtsAlumniListResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AdminDialogStandards.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: AdminDialogStandards.elevation,
        insetPadding: AdminDialogStandards.defaultInsetPadding,
        shape: AdminDialogStandards.shape,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 850),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminModalHeader(
                  title: GtsListTables.title(result),
                  subtitle:
                      'Full-screen preview · ${result.rows.length} records · '
                      '${GtsListColumns.displayColumns(result.config).length} columns',
                  icon: Icons.fullscreen_rounded,
                  onClose: () => Navigator.of(ctx).pop(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final f in _downloadOrder)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              unawaited(_download(f));
                            },
                            style: AdminButtonStyles.outlined(),
                            icon: const Icon(Icons.download_outlined, size: 15),
                            label: Text(f.label),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AdminColors.border),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: GtsAlumniListPreview(
                      result: result,
                      explanation: _explanation,
                      profileWarning: _profileWarning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// On-screen alumni list: heading, status chart, the rows (paged) and the
/// tally, which is always shown in full.
class GtsAlumniListPreview extends StatelessWidget {
  const GtsAlumniListPreview({
    super.key,
    required this.result,
    this.explanation = '',
    this.profileWarning,
  });

  /// Default rows per page for the list preview (Directory stays at its own default).
  static const previewPageSize = 10;

  /// Page-size choices for this preview only.
  static const previewPageSizeOptions = [10, 25, 50, 100];

  final GtsAlumniListResult result;
  final String explanation;
  final String? profileWarning;

  @override
  Widget build(BuildContext context) {
    final columns = GtsListColumns.displayColumns(result.config);
    final charts = GtsListTables.charts(result);
    final tally = result.tally;
    final config = result.config;
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
            letterSpacing: -0.3,
            color: AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${GtsListTables.scope(result)} · ${tally.total} alumni on the '
          'alumni list${filtered ? ' (filtered)' : ''}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AdminColors.textSecondary,
          ),
        ),
        if (result.config.description.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              result.config.description,
              style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary),
            ),
          ),
        if (explanation.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: UstpColors.blue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              border: Border.all(
                color: AdminColors.border.withValues(alpha: 0.8),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3.5,
                    decoration: const BoxDecoration(
                      color: UstpColors.blue,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(AdminSurfaces.radiusSm),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        explanation,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (profileWarning != null) ...[
          const SizedBox(height: 8),
          Text(
            profileWarning!,
            style: const TextStyle(fontSize: 12, color: AdminColors.warning),
          ),
        ],
        const SizedBox(height: 16),
        if (config.includeCharts)
          for (final chart in charts) ...[
            Text(chart.title, style: _headingStyle),
            const SizedBox(height: 6),
            GtsReportChartView(data: chart),
            if (chart.omittedNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  chart.omittedNote!,
                  style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                ),
              ),
            const SizedBox(height: 16),
          ],
        if (!config.includeTable && !config.includeTally && !config.includeCharts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Turn on the alumni table, the tally, or a chart to include it in the preview and the export.',
            ),
          ),
        if (config.includeTable) ...[
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
        ],
        if (config.includeTally) ...[
        const SizedBox(height: 20),
        const Text(
          'TALLY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminColors.primary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        _TallyTable(result),
        ],
        if (tally.count(GtsTracerStatus.offRoster) > 0 &&
            (config.includeTable || config.includeTally))
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              GtsListTables.offRosterNote,
              style: TextStyle(
                fontSize: 11,
                color: AdminColors.textMuted,
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
  color: AdminColors.primary,
);

const _cellStyle = TextStyle(fontSize: 12, color: AdminColors.textPrimary);

class _ListTable extends StatefulWidget {
  const _ListTable({super.key, required this.result, required this.columns});

  final GtsAlumniListResult result;
  final List<GtsListColumn> columns;

  @override
  State<_ListTable> createState() => _ListTableState();
}

class _ListTableState extends State<_ListTable> {
  var _page = 0;
  var _pageSize = GtsAlumniListPreview.previewPageSize;
  final ScrollController _hScrollController = ScrollController();

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  static const _untrackedTint = Color(0xFFFFFBEB);

  Widget _cell(String text) {
    if (text == gtsNotAskedLabel) {
      return const Text(
        gtsNotAskedLabel,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: AdminColors.textMuted,
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
    final safePage = adminClampPage(_page, rows.length, _pageSize);
    final shown = adminPaginate(rows, safePage, _pageSize);
    final labels = widget.result.waveLabels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AdminColors.card,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
            border: Border.all(color: AdminColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = math.max(
                constraints.maxWidth,
                math.max(600.0, widget.columns.length * 130.0),
              );
              return Scrollbar(
                controller: _hScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _hScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minWidth),
                    child: DataTable(
                      headingRowColor:
                          const WidgetStatePropertyAll(AdminColors.surface),
                      headingRowHeight: 38,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 48,
                      columnSpacing: 20,
                      headingTextStyle: _headingStyle,
                      dataTextStyle: _cellStyle,
                      columns: [
                        for (final c in widget.columns)
                          DataColumn(
                            label: Tooltip(
                              message: c.description,
                              child: Text(c.header),
                            ),
                          ),
                      ],
                      rows: [
                        for (final r in shown)
                          DataRow(
                            color: r.status.untracked
                                ? const WidgetStatePropertyAll(_untrackedTint)
                                : r.member == null
                                ? const WidgetStatePropertyAll(
                                    AdminColors.surface,
                                  )
                                : null,
                            cells: [
                              for (final c in widget.columns)
                                DataCell(
                                  _cell(
                                    GtsListColumns.cell(
                                      c,
                                      r,
                                      waveLabels: labels,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          AdminPaginationBar(
            totalItems: rows.length,
            page: safePage,
            pageSize: _pageSize,
            pageSizeOptions: GtsAlumniListPreview.previewPageSizeOptions,
            onPageChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (s) => setState(() {
              _pageSize = s;
              _page = 0;
            }),
            dense: true,
          ),
        ],
      ],
    );
  }
}

/// Overall tally, or one column per batch/course plus the overall column.
class _TallyTable extends StatefulWidget {
  const _TallyTable(this.result);

  final GtsAlumniListResult result;

  @override
  State<_TallyTable> createState() => _TallyTableState();
}

class _TallyTableState extends State<_TallyTable> {
  final ScrollController _hScrollController = ScrollController();

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  static String _both(GtsTallyLine line) =>
      line.share.isEmpty ? line.count : '${line.count} (${line.share})';

  DataTable _table(GtsTallySection section, GtsAlumniListResult result) {
    final groups = result.groups;
    DataRow row(GtsTallyLine line, List<String> cells) => DataRow(
      color: line.isTotal ? const WidgetStatePropertyAll(AdminColors.surface) : null,
      cells: [
        for (final cell in cells)
          DataCell(
            Text(
              cell,
              style: line.isTotal ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
          ),
      ],
    );
    if (groups.isEmpty) {
      return DataTable(
        headingRowColor: const WidgetStatePropertyAll(AdminColors.surface),
        headingRowHeight: 34,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        columnSpacing: 24,
        headingTextStyle: _headingStyle,
        dataTextStyle: _cellStyle,
        columns: [
          DataColumn(label: Text(section.title)),
          const DataColumn(label: Text('Alumni'), numeric: true),
          const DataColumn(label: Text('Share'), numeric: true),
        ],
        rows: [
          for (final line in section.lines)
            row(line, [line.label, line.count, line.share]),
        ],
      );
    }
    final by = GtsListTables.groupHeading(result.config.subtotalBy).toLowerCase();
    return DataTable(
      headingRowColor: const WidgetStatePropertyAll(AdminColors.surface),
      headingRowHeight: 34,
      dataRowMinHeight: 28,
      dataRowMaxHeight: 36,
      columnSpacing: 24,
      headingTextStyle: _headingStyle,
      dataTextStyle: _cellStyle,
      columns: [
        DataColumn(label: Text('${section.title} by $by')),
        for (final group in groups) DataColumn(label: Text(group.label)),
        const DataColumn(label: Text('Overall')),
      ],
      rows: [
        for (var i = 0; i < section.lines.length; i++)
          row(section.lines[i], [
            section.lines[i].label,
            for (final lines in section.groupLines) _both(lines[i]),
            _both(section.lines[i]),
          ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final sections = GtsListTables.sections(result);
    final groups = result.groups;
    return Scrollbar(
      controller: _hScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _hScrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: groups.isEmpty
                ? 500
                : math.max(600, (groups.length + 2) * 110.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final section in sections) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AdminColors.card,
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: _table(section, result),
                ),
                if (section.note != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      section.note!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Result of the configure-columns dialog.
class GtsListColumnPickResult {
  const GtsListColumnPickResult({
    required this.columns,
    required this.includeUntracked,
  });

  final List<String> columns;
  final bool includeUntracked;
}

/// Column picker: every column grouped by section, with search and
/// select-all per section. Pops [GtsListColumnPickResult], or null.
class GtsListColumnPicker extends StatefulWidget {
  const GtsListColumnPicker({
    super.key,
    required this.selected,
    this.includeUntracked = true,
  });

  /// Current column keys in display order.
  final List<String> selected;
  final bool includeUntracked;

  @override
  State<GtsListColumnPicker> createState() => _GtsListColumnPickerState();
}

class _GtsListColumnPickerState extends State<GtsListColumnPicker> {
  late final Set<String> _picked = {
    for (final k in GtsListConfig.migrateColumns(widget.selected)) k,
  };
  late bool _includeUntracked = widget.includeUntracked;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(GtsListColumn c) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final blob = '${c.searchText} ${c.header} ${c.description} ${c.group}'
        .toLowerCase();
    return blob.contains(q);
  }

  /// Kept columns stay in place; new ones follow in questionnaire order.
  List<String> _resultColumns() {
    final selected = GtsListConfig.migrateColumns(widget.selected);
    return [
      for (final k in selected)
        if (_picked.contains(k)) k,
      for (final c in GtsListColumns.pickable)
        if (_picked.contains(c.key) && !selected.contains(c.key)) c.key,
    ];
  }

  GtsListColumnPickResult _result() => GtsListColumnPickResult(
    columns: _resultColumns(),
    includeUntracked: _includeUntracked,
  );

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
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  borderSide: const BorderSide(color: AdminColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  borderSide: const BorderSide(
                    color: AdminColors.primary,
                    width: 1.5,
                  ),
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
                          if (group == GtsListColumns.alumniGroup)
                            _includeUntrackedToggle(),
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

  Widget _includeUntrackedToggle() {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: _includeUntracked,
      onChanged: (on) => setState(() => _includeUntracked = on),
      title: const Text(
        'Include people who have not answered',
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'When off, only alumni who submitted the tracer stay in the list.',
        style: TextStyle(fontSize: 12),
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
