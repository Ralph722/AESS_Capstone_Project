import 'package:flutter/material.dart';

import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/features/admin/dss/application/dss_ai_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluation_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_export_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_report_card.dart';
import 'package:alumni_system/features/admin/dss/application/dss_report_card_service.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/presentation/admin_dss_detail_page.dart';
import 'package:alumni_system/features/admin/dss/presentation/admin_dss_history_page.dart';
import 'package:alumni_system/features/admin/dss/presentation/admin_dss_settings_page.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';

enum _DssPanel { list, detail, history, settings }

enum _DssStatusFilter { all, open, inProgress, resolved, dismissed }

enum _DssSort { newest, oldest, severity, sampleDesc }

/// Admin DSS Recommendations — matches Surveys/Directory chrome.
class AdminDssScreen extends StatefulWidget {
  const AdminDssScreen({super.key, this.onOpenAdminMenu});

  final void Function(int menuIndex)? onOpenAdminMenu;

  @override
  State<AdminDssScreen> createState() => _AdminDssScreenState();
}

class _AdminDssScreenState extends State<AdminDssScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _repo = DssRepository();
  final _eval = DssEvaluationService();
  final _ai = DssAiService();
  final _export = DssExportService();
  final _reportCards = DssReportCardService();
  bool _buildingReport = false;
  final _searchController = TextEditingController();

  List<DssFlag> _flags = [];
  List<DssRule> _rules = [];
  bool _loading = true;
  bool _evaluating = false;
  String? _error;
  String? _evalMessage;
  String? _priorityHint;
  bool _prioritizing = false;

  _DssPanel _panel = _DssPanel.list;
  String? _activeFlagId;

  _DssStatusFilter _statusFilter = _DssStatusFilter.all;
  String _ruleFilter = '';
  _DssSort _sort = _DssSort.newest;
  String _query = '';
  bool _mineOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.listFlags(limit: 500),
        _repo.listRules(),
      ]);
      if (!mounted) return;
      setState(() {
        _flags = results[0] as List<DssFlag>;
        _rules = results[1] as List<DssRule>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshInsights() async {
    setState(() {
      _evaluating = true;
      _evalMessage = null;
    });
    try {
      final result = await _eval.evaluateAll(
        onProgress: (msg) {
          if (!mounted) return;
          setState(() => _evalMessage = msg);
        },
      );
      if (!mounted) return;
      setState(() => _evalMessage = result.message);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Evaluation failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  Future<void> _prioritizeWithAi() async {
    final open = _flags
        .where(
          (f) =>
              f.status == DssFlagStatus.open ||
              f.status == DssFlagStatus.inProgress,
        )
        .toList();
    if (open.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No open flags to prioritize.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _prioritizing = true);
    try {
      final hint = await _ai.prioritizeFlags(open);
      if (!mounted) return;
      setState(() => _priorityHint = hint);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI prioritization unavailable: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _prioritizing = false);
    }
  }

  Future<void> _exportReportCard() async {
    if (!requireWebExport(context)) return;
    final course = await showDialog<String>(
      context: context,
      builder: (_) => _ReportCardPicker(service: _reportCards),
    );
    if (course == null || !mounted) return;
    setState(() => _buildingReport = true);
    try {
      final data = await _reportCards.build(course);
      final bytes = await DssReportCardPdf.build(data);
      if (!mounted) return;
      final safe = course.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final date = DateTime.now().toIso8601String().split('T').first;
      tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName: 'program_report_card_${safe}_$date.pdf',
        mimeType: 'application/pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report card failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _buildingReport = false);
    }
  }

  Future<void> _exportFlags() async {
    final list = _filtered;
    if (list.isEmpty) return;
    try {
      await _export.exportFlagsCsv(list);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Program Insights flags exported.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDetail(String id) {
    setState(() {
      _activeFlagId = id;
      _panel = _DssPanel.detail;
    });
  }

  Future<void> _closePanel() async {
    setState(() {
      _panel = _DssPanel.list;
      _activeFlagId = null;
    });
    await _load();
  }

  bool get _hasActiveFilters =>
      _statusFilter != _DssStatusFilter.all ||
      _ruleFilter.isNotEmpty ||
      _query.isNotEmpty ||
      _sort != _DssSort.newest ||
      _mineOnly;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _statusFilter = _DssStatusFilter.all;
      _ruleFilter = '';
      _sort = _DssSort.newest;
      _query = '';
      _mineOnly = false;
    });
  }

  int get _openCount =>
      _flags.where((f) => f.status == DssFlagStatus.open).length;
  int get _inProgressCount =>
      _flags.where((f) => f.status == DssFlagStatus.inProgress).length;
  int get _resolvedCount =>
      _flags.where((f) => f.status == DssFlagStatus.resolved).length;
  int get _lowConfidenceCount =>
      _flags.where((f) => f.confidence == DssConfidence.low).length;

  List<DssFlag> get _filtered {
    var list = _flags.where((f) {
      switch (_statusFilter) {
        case _DssStatusFilter.all:
          break;
        case _DssStatusFilter.open:
          if (f.status != DssFlagStatus.open) return false;
        case _DssStatusFilter.inProgress:
          if (f.status != DssFlagStatus.inProgress) return false;
        case _DssStatusFilter.resolved:
          if (f.status != DssFlagStatus.resolved) return false;
        case _DssStatusFilter.dismissed:
          if (f.status != DssFlagStatus.dismissed) return false;
      }
      if (_ruleFilter.isNotEmpty && f.ruleId != _ruleFilter) {
        return false;
      }
      if (_mineOnly) {
        final uid = AppSession.currentUser?.id;
        if (uid == null || f.assignedTo != uid) return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hay =
            '${f.title} ${f.body} ${f.ruleId} ${f.ruleName ?? ''} '
            '${f.cohortLabel} ${f.surveyTitle}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    int sevRank(DssFlag f) => switch (f.severity) {
      DssSeverity.critical => 3,
      DssSeverity.warning => 2,
      DssSeverity.info => 1,
      null => 2,
    };

    switch (_sort) {
      case _DssSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _DssSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _DssSort.severity:
        list.sort((a, b) {
          final s = sevRank(b).compareTo(sevRank(a));
          if (s != 0) return s;
          return b.createdAt.compareTo(a.createdAt);
        });
      case _DssSort.sampleDesc:
        list.sort((a, b) {
          final n = b.sampleN.compareTo(a.sampleN);
          if (n != 0) return n;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
    return list;
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    if (_statusFilter != _DssStatusFilter.all) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Status: ${_statusFilterLabel(_statusFilter)}',
          onRemoved: () =>
              setState(() => _statusFilter = _DssStatusFilter.all),
        ),
      );
    }
    if (_ruleFilter.isNotEmpty) {
      final rule = _rules.cast<DssRule?>().firstWhere(
        (r) => r?.ruleId == _ruleFilter,
        orElse: () => null,
      );
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Rule: ${rule?.name ?? _ruleFilter}',
          onRemoved: () => setState(() => _ruleFilter = ''),
        ),
      );
    }
    if (_query.isNotEmpty) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Search: $_query',
          onRemoved: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
      );
    }
    if (_mineOnly) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'My flags',
          onRemoved: () => setState(() => _mineOnly = false),
        ),
      );
    }
    return chips;
  }

  String _statusFilterLabel(_DssStatusFilter f) => switch (f) {
    _DssStatusFilter.all => 'All',
    _DssStatusFilter.open => 'Open',
    _DssStatusFilter.inProgress => 'In Progress',
    _DssStatusFilter.resolved => 'Resolved',
    _DssStatusFilter.dismissed => 'Dismissed',
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);

    switch (_panel) {
      case _DssPanel.detail:
        if (_activeFlagId != null) {
          return AdminDssDetailPanel(
            key: ValueKey('dss-detail-$_activeFlagId'),
            flagId: _activeFlagId!,
            onClose: _closePanel,
            onOpenAdminMenu: widget.onOpenAdminMenu,
          );
        }
      case _DssPanel.history:
        return AdminDssHistoryPanel(onClose: _closePanel);
      case _DssPanel.settings:
        return AdminDssSettingsPanel(
          onClose: () async {
            await _closePanel();
          },
        );
      case _DssPanel.list:
        break;
    }
    return _buildList();
  }

  Widget _buildList() {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DssPageHeader(
          title: 'Program Insights',
          subtitle:
              'Clear alerts from tracer results — see what happened, why it matters, and what to do next.',
          actions: [
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => setState(() => _panel = _DssPanel.history),
              icon: const Icon(Icons.timeline, size: 17),
              label: const Text('History'),
              style: dssOutlinedButtonStyle(),
            ),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => setState(() => _panel = _DssPanel.settings),
              icon: const Icon(Icons.tune, size: 17),
              label: const Text('Rules'),
              style: dssOutlinedButtonStyle(),
            ),
            OutlinedButton.icon(
              onPressed: filtered.isEmpty ? null : _exportFlags,
              icon: const Icon(Icons.download_outlined, size: 17),
              label: const Text('Export'),
              style: dssOutlinedButtonStyle(),
            ),
            OutlinedButton.icon(
              onPressed: _buildingReport ? null : _exportReportCard,
              icon: _buildingReport
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 17),
              label: Text(_buildingReport ? 'Building…' : 'Report card'),
              style: dssOutlinedButtonStyle(),
            ),
            FilledButton.icon(
              onPressed: _evaluating ? null : _refreshInsights,
              icon: _evaluating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.analytics_outlined, size: 17),
              label: Text(_evaluating ? 'Evaluating…' : 'Refresh insights'),
              style: dssFilledButtonStyle(),
            ),
          ],
        ),
        const SizedBox(height: AdminDssTheme.space2),
        _buildMetrics(),
        const SizedBox(height: AdminDssTheme.space2),
        _buildToolbar(),
        if (_evalMessage != null) ...[
          const SizedBox(height: AdminDssTheme.space1),
          DssInsightBanner(
            text: _evalMessage!,
            icon: Icons.info_outline,
            onDismiss: () => setState(() => _evalMessage = null),
          ),
        ],
        if (_priorityHint != null) ...[
          const SizedBox(height: AdminDssTheme.space1),
          DssInsightBanner(
            text: _priorityHint!,
            onDismiss: () => setState(() => _priorityHint = null),
          ),
        ],
        const SizedBox(height: AdminDssTheme.space1),
        if (_error != null)
          Expanded(
            child: DirectoryEmptyState(
              title: 'Could not load flags',
              subtitle: _error!,
              icon: Icons.error_outline,
              primaryAction: _load,
              primaryLabel: 'Retry',
            ),
          )
        else
          Expanded(
            child: AdminInstantContent(
              loading: _loading,
              loadingSkeleton: const PortalCardListSkeleton(),
              isEmpty: filtered.isEmpty,
              empty: DirectoryEmptyState(
                title: _flags.isEmpty
                    ? 'No recommendation flags yet'
                    : 'No matches',
                subtitle: _flags.isEmpty
                    ? 'Run Refresh insights to evaluate CHED tracer responses against your insight thresholds.'
                    : 'Try a different search or clear filters.',
                icon: Icons.lightbulb_outline,
                primaryAction: _flags.isEmpty ? _refreshInsights : _resetFilters,
                primaryLabel:
                    _flags.isEmpty ? 'Refresh insights' : 'Reset filters',
              ),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AdminDensity.space3),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final flag = filtered[index];
                  return DssFlagListCard(
                    flag: flag,
                    selected: flag.id == _activeFlagId,
                    onOpen: () => _openDetail(flag.id),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetrics() {
    return DirectoryStatsGrid(
      children: [
        DirectoryStatCard(
          label: 'Open',
          value: '$_openCount',
          description: 'Needs attention',
          icon: Icons.flag_outlined,
          accent: AdminDssTheme.danger,
          onTap: () =>
              setState(() => _statusFilter = _DssStatusFilter.open),
        ),
        DirectoryStatCard(
          label: 'In progress',
          value: '$_inProgressCount',
          description: 'Being handled',
          icon: Icons.pending_actions_outlined,
          accent: AdminDssTheme.warning,
          onTap: () =>
              setState(() => _statusFilter = _DssStatusFilter.inProgress),
        ),
        DirectoryStatCard(
          label: 'Resolved',
          value: '$_resolvedCount',
          description: 'Closed with action',
          icon: Icons.check_circle_outline,
          accent: AdminDssTheme.success,
          onTap: () =>
              setState(() => _statusFilter = _DssStatusFilter.resolved),
        ),
        DirectoryStatCard(
          label: 'Low confidence',
          value: '$_lowConfidenceCount',
          description: 'Small sample / low response',
          icon: Icons.warning_amber_outlined,
          accent: AdminDssTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return DirectoryToolbarCard(
      searchController: _searchController,
      onSearchChanged: (v) => setState(() => _query = v.trim()),
      onClearSearch: () {
        _searchController.clear();
        setState(() => _query = '');
      },
      isLoading: _loading || _evaluating,
      onRefresh: _load,
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      searchHint: 'Search by rule, course, batch, or finding…',
      filters: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DirectoryFilterField<String>(
            label: 'Rule',
            value: _ruleFilter,
            width: 180,
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All rules'),
              ),
              ..._rules.map(
                (r) => DropdownMenuItem<String>(
                  value: r.ruleId,
                  child: Text(r.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _ruleFilter = v ?? ''),
          ),
          DirectoryFilterField<_DssSort>(
            label: 'Sort',
            value: _sort,
            width: 148,
            items: const [
              DropdownMenuItem(
                value: _DssSort.newest,
                child: Text('Newest first'),
              ),
              DropdownMenuItem(
                value: _DssSort.oldest,
                child: Text('Oldest first'),
              ),
              DropdownMenuItem(
                value: _DssSort.severity,
                child: Text('Severity'),
              ),
              DropdownMenuItem(
                value: _DssSort.sampleDesc,
                child: Text('Largest n'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _sort = v);
            },
          ),
          for (final f in _DssStatusFilter.values)
            DirectoryToolbarFilterChip(
              label: _statusFilterLabel(f),
              selected: _statusFilter == f,
              onSelected: (_) => setState(() => _statusFilter = f),
            ),
          DirectoryToolbarFilterChip(
            label: 'My flags',
            selected: _mineOnly,
            onSelected: (v) => setState(() => _mineOnly = v),
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            onPressed: _prioritizing ? null : _prioritizeWithAi,
            icon: _prioritizing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: const Text('AI prioritize'),
            style: dssOutlinedButtonStyle(),
          ),
        ],
      ),
    );
  }
}

/// Picks the program for a report card. Returns the course name.
class _ReportCardPicker extends StatefulWidget {
  const _ReportCardPicker({required this.service});

  final DssReportCardService service;

  @override
  State<_ReportCardPicker> createState() => _ReportCardPickerState();
}

class _ReportCardPickerState extends State<_ReportCardPicker> {
  late final Future<List<String>> _courses = widget.service.courses();
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusMd),
      ),
      title: const Text(
        'Program report card',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<String>>(
          future: _courses,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Text('Could not load programs: ${snap.error}');
            }
            final courses = snap.data ?? const [];
            if (courses.isEmpty) {
              return const Text('No programs on the roster yet.');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'One-page PDF with this program\'s tracer results against the '
                  'institution, results across waves, findings, actions taken '
                  'and impact checks.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AdminDssTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                DirectoryFilterField<String?>(
                  label: 'Program',
                  value: _selected,
                  width: 400,
                  items: [
                    for (final c in courses)
                      DropdownMenuItem<String?>(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selected = v),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Download PDF'),
          style: dssFilledButtonStyle(),
        ),
      ],
    );
  }
}
