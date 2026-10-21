import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluation_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_export_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_history.dart';
import 'package:alumni_system/features/admin/dss/application/dss_priority.dart';
import 'package:alumni_system/features/admin/dss/application/dss_report_card.dart';
import 'package:alumni_system/features/admin/dss/application/dss_report_card_service.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/presentation/admin_dss_detail_page.dart';
import 'package:alumni_system/features/admin/dss/presentation/admin_dss_history_page.dart';
import 'package:alumni_system/features/admin/dss/presentation/admin_dss_settings_page.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_kpi_card.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';

enum _DssPanel { list, detail, history, settings }

enum _DssStatusFilter {
  all,
  open,
  inProgress,
  watch,
  resolved,
  dismissed,
  superseded,
}

enum _DssEvidenceFilter { all, findings, watch }

enum _DssSort { priority, newest, oldest, severity, sampleDesc }

/// Open and in-progress flags by due date.
enum _DssDueFilter { all, overdue, dueSoon }

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
  final _export = DssExportService();
  final _reportCards = DssReportCardService();
  bool _buildingReport = false;
  final _searchController = TextEditingController();

  List<DssFlag> _flags = [];
  List<DssRule> _rules = [];
  DateTime? _lastEvaluatedAt;
  bool _lastEvaluatedScheduled = false;
  bool _loading = true;
  bool _evaluating = false;
  String? _error;
  String? _evalMessage;
  bool _showRulesRefreshHint = false;

  _DssPanel _panel = _DssPanel.list;
  String? _activeFlagId;

  _DssStatusFilter _statusFilter = _DssStatusFilter.all;
  _DssEvidenceFilter _evidenceFilter = _DssEvidenceFilter.all;
  String _ruleFilter = '';
  DssPriority? _priorityFilter;
  String _officeFilter = '';
  _DssDueFilter _dueFilter = _DssDueFilter.all;
  _DssSort _sort = _DssSort.priority;
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
        _repo.listEvaluationRuns(limit: 1),
      ]);
      if (!mounted) return;
      final runs = results[2] as List<DssEvaluationRun>;
      final last = runs.isEmpty ? null : runs.first;
      setState(() {
        _flags = results[0] as List<DssFlag>;
        _rules = results[1] as List<DssRule>;
        _lastEvaluatedAt = last?.at;
        _lastEvaluatedScheduled = last?.scheduled ?? false;
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
      setState(() {
        _evalMessage = result.message;
        _showRulesRefreshHint = false;
      });
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
        fileName: data.institution
            ? 'institution_report_card_$date.pdf'
            : 'program_report_card_${safe}_$date.pdf',
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
          content: Text('Program Insights findings exported.'),
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

  int get _subnavIndex => switch (_panel) {
    _DssPanel.list || _DssPanel.detail => 0,
    _DssPanel.history => 1,
    _DssPanel.settings => 2,
  };

  void _onSubnavSelected(int index) {
    setState(() {
      _activeFlagId = null;
      switch (index) {
        case 1:
          _panel = _DssPanel.history;
        case 2:
          _panel = _DssPanel.settings;
          _showRulesRefreshHint = true;
        default:
          _panel = _DssPanel.list;
      }
    });
  }

  String get _lastEvaluatedLabel {
    final at = _lastEvaluatedAt;
    if (at == null) return 'Not evaluated yet — click Refresh insights.';
    final when = DateFormat.yMMMd().add_jm().format(at.toLocal());
    final how = _lastEvaluatedScheduled ? 'Nightly' : 'Manual';
    return 'Last evaluated: $when ($how)';
  }

  bool get _hasActiveFilters =>
      _statusFilter != _DssStatusFilter.all ||
      _evidenceFilter != _DssEvidenceFilter.all ||
      _ruleFilter.isNotEmpty ||
      _priorityFilter != null ||
      _officeFilter.isNotEmpty ||
      _dueFilter != _DssDueFilter.all ||
      _query.isNotEmpty ||
      _sort != _DssSort.priority ||
      _mineOnly;

  int get _moreFiltersCount {
    var count = 0;
    if (_dueFilter != _DssDueFilter.all) count++;
    if (_officeFilter.isNotEmpty) count++;
    if (_mineOnly) count++;
    return count;
  }

  Future<void> _openMoreFiltersDialog() async {
    final result = await showDialog<({
      _DssDueFilter due,
      String office,
      bool mineOnly,
    })>(
      context: context,
      builder: (_) => _MoreFiltersDialog(
        initialDue: _dueFilter,
        initialOffice: _officeFilter,
        initialMineOnly: _mineOnly,
        offices: _offices,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _dueFilter = result.due;
        _officeFilter = result.office;
        _mineOnly = result.mineOnly;
      });
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _statusFilter = _DssStatusFilter.all;
      _evidenceFilter = _DssEvidenceFilter.all;
      _ruleFilter = '';
      _priorityFilter = null;
      _officeFilter = '';
      _dueFilter = _DssDueFilter.all;
      _sort = _DssSort.priority;
      _query = '';
      _mineOnly = false;
    });
  }

  int get _openCount =>
      _flags.where((f) => f.status == DssFlagStatus.open && f.isFinding).length;
  int get _inProgressCount => _flags
      .where((f) => f.status == DssFlagStatus.inProgress && f.isFinding)
      .length;
  int get _resolvedCount =>
      _flags.where((f) => f.status == DssFlagStatus.resolved).length;
  int get _watchCount => _flags.where((f) => f.isActive && !f.isFinding).length;

  List<DssFlag> get _filtered {
    final now = DateTime.now();
    var list = _flags.where((f) {
      switch (_evidenceFilter) {
        case _DssEvidenceFilter.all:
          break;
        case _DssEvidenceFilter.findings:
          if (!f.isFinding) return false;
        case _DssEvidenceFilter.watch:
          if (f.isFinding) return false;
      }
      final wanted = switch (_statusFilter) {
        _DssStatusFilter.all => null,
        _DssStatusFilter.open => DssFlagStatus.open,
        _DssStatusFilter.inProgress => DssFlagStatus.inProgress,
        _DssStatusFilter.watch => DssFlagStatus.watch,
        _DssStatusFilter.resolved => DssFlagStatus.resolved,
        _DssStatusFilter.dismissed => DssFlagStatus.dismissed,
        _DssStatusFilter.superseded => DssFlagStatus.superseded,
      };
      // Superseded flags are history; they show only under their filter.
      if (wanted == null
          ? f.status == DssFlagStatus.superseded
          : f.status != wanted) {
        return false;
      }
      if (_ruleFilter.isNotEmpty && f.ruleId != _ruleFilter) {
        return false;
      }
      final wantedPriority = _priorityFilter;
      if (wantedPriority != null &&
          (!f.isActive ||
              DssPriorityCalc.of(f, now: now).level != wantedPriority)) {
        return false;
      }
      if (_officeFilter.isNotEmpty && f.ownerOffice != _officeFilter) {
        return false;
      }
      if (_dueFilter != _DssDueFilter.all) {
        final days = f.daysUntilDue(now);
        final keep = switch (_dueFilter) {
          _DssDueFilter.overdue => days != null && days < 0,
          _DssDueFilter.dueSoon => days != null && days >= 0 && days <= 7,
          _DssDueFilter.all => true,
        };
        if (!keep) return false;
      }
      if (_mineOnly) {
        final uid = AppSession.currentUser?.id;
        if (uid == null || f.assignedTo != uid) return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hay =
            '${f.title} ${f.body} ${f.ruleId} ${f.ruleName ?? ''} '
                    '${f.cohortLabel} ${f.surveyTitle} '
                    '${f.ownerOffice ?? ''} ${f.responsibleName ?? ''}'
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
      case _DssSort.priority:
        list.sort((a, b) {
          // Active work first; closed and superseded flags keep newest-first.
          final active = (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
          if (active != 0) return active;
          if (!a.isActive) return b.createdAt.compareTo(a.createdAt);
          return DssPriorityCalc.compare(a, b, now: now);
        });
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
          onRemoved: () => setState(() => _statusFilter = _DssStatusFilter.all),
        ),
      );
    }
    if (_evidenceFilter != _DssEvidenceFilter.all) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Sample: ${_evidenceFilterLabel(_evidenceFilter)}',
          onRemoved: () =>
              setState(() => _evidenceFilter = _DssEvidenceFilter.all),
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
    if (_priorityFilter != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Priority: ${_priorityFilter!.label}',
          onRemoved: () => setState(() => _priorityFilter = null),
        ),
      );
    }
    if (_officeFilter.isNotEmpty) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Office: $_officeFilter',
          onRemoved: () => setState(() => _officeFilter = ''),
        ),
      );
    }
    if (_dueFilter != _DssDueFilter.all) {
      chips.add(
        DirectoryActiveFilterChip(
          label: _dueFilterLabel(_dueFilter),
          onRemoved: () => setState(() => _dueFilter = _DssDueFilter.all),
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
          label: 'My findings',
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
    _DssStatusFilter.watch => 'Watch',
    _DssStatusFilter.resolved => 'Resolved',
    _DssStatusFilter.dismissed => 'Dismissed',
    _DssStatusFilter.superseded => 'Superseded',
  };

  String _dueFilterLabel(_DssDueFilter f) => switch (f) {
    _DssDueFilter.all => 'All due dates',
    _DssDueFilter.overdue => 'Overdue',
    _DssDueFilter.dueSoon => 'Due within 7 days',
  };

  /// Offices recorded on any flag, alphabetical.
  List<String> get _offices {
    final set = <String>{
      for (final f in _flags)
        if (f.ownerOffice != null) f.ownerOffice!,
    };
    return set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  String _evidenceFilterLabel(_DssEvidenceFilter f) => switch (f) {
    _DssEvidenceFilter.all => 'All sizes',
    _DssEvidenceFilter.findings => 'Findings (n≥10)',
    _DssEvidenceFilter.watch => 'Watch (n<10)',
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
        return AdminDssHistoryPanel(
          onClose: _closePanel,
          selectedSubnav: 1,
          onSubnavSelected: _onSubnavSelected,
        );
      case _DssPanel.settings:
        return AdminDssSettingsPanel(
          onClose: () async {
            await _closePanel();
          },
          selectedSubnav: 2,
          onSubnavSelected: _onSubnavSelected,
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
          subtitle: 'Work queue for tracer Findings and Watch items.',
          selectedSubnav: _subnavIndex,
          onSubnavSelected: _onSubnavSelected,
          trailingSubnav: Text(
            _lastEvaluatedLabel,
            style: const TextStyle(
              fontSize: 12,
              color: AdminDssTheme.textMuted,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Export and reports',
              enabled: !_loading && !_evaluating,
              position: PopupMenuPosition.under,
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              onSelected: (v) {
                if (v == 'export') {
                  _exportFlags();
                } else if (v == 'report') {
                  _exportReportCard();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'export',
                  enabled: filtered.isNotEmpty,
                  child: const Text('Export CSV'),
                ),
                PopupMenuItem(
                  value: 'report',
                  enabled: !_buildingReport,
                  child: Text(
                    _buildingReport ? 'Building report…' : 'Report card PDF',
                  ),
                ),
              ],
              child: Container(
                height: AdminDssTheme.buttonHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AdminDssTheme.card,
                  borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
                  border: Border.all(color: AdminDssTheme.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download_outlined,
                      size: 17,
                      color: AdminDssTheme.textPrimary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Reports',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminDssTheme.textPrimary,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: AdminDssTheme.textSecondary,
                    ),
                  ],
                ),
              ),
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
        if (_showRulesRefreshHint) ...[
          const SizedBox(height: AdminDssTheme.space1),
          DssInsightBanner(
            text:
                'If you changed Rules, click Refresh insights so Findings use the new thresholds.',
            icon: Icons.tune,
            onDismiss: () => setState(() => _showRulesRefreshHint = false),
          ),
        ],
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
        const SizedBox(height: AdminDssTheme.space1),
        if (_error != null)
          Expanded(
            child: DirectoryEmptyState(
              title: 'Could not load findings',
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
                    ? 'No findings yet'
                    : 'No matches',
                subtitle: _flags.isEmpty
                    ? 'Need a published CHED GTS with responses — then Refresh insights.'
                    : 'Try a different search or clear filters.',
                icon: Icons.lightbulb_outline,
                primaryAction: _flags.isEmpty
                    ? _refreshInsights
                    : _resetFilters,
                primaryLabel: _flags.isEmpty
                    ? 'Refresh insights'
                    : 'Reset filters',
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
    return DirectoryKpiRow(
      children: [
        AdminKpiCard(
          dense: true,
          label: 'Open',
          value: '$_openCount',
          caption: 'Not started',
          icon: Icons.flag_outlined,
          accent: AdminColors.primary,
          onTap: () => setState(() {
            _statusFilter = _DssStatusFilter.open;
            _evidenceFilter = _DssEvidenceFilter.findings;
          }),
        ),
        AdminKpiCard(
          dense: true,
          label: 'In progress',
          value: '$_inProgressCount',
          caption: 'Being handled',
          icon: Icons.pending_actions_outlined,
          accent: AdminColors.accent,
          onTap: () => setState(() {
            _statusFilter = _DssStatusFilter.inProgress;
            _evidenceFilter = _DssEvidenceFilter.findings;
          }),
        ),
        AdminKpiCard(
          dense: true,
          label: 'Resolved',
          value: '$_resolvedCount',
          caption: 'Closed with action',
          icon: Icons.check_circle_outline,
          accent: AdminColors.primary,
          onTap: () =>
              setState(() => _statusFilter = _DssStatusFilter.resolved),
        ),
        AdminKpiCard(
          dense: true,
          label: 'Watch',
          value: '$_watchCount',
          caption: 'Too few answers',
          icon: Icons.visibility_outlined,
          accent: AdminColors.accent,
          onTap: () => setState(() {
            _statusFilter = _DssStatusFilter.all;
            _evidenceFilter = _DssEvidenceFilter.watch;
          }),
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
      refreshTooltip: 'Reload list',
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      searchHint: 'Search by rule, course, batch, or finding…',
      singleRowMinWidth: 960,
      filters: LayoutBuilder(
        builder: (context, constraints) {
          final isSingleRow = constraints.maxWidth.isInfinite;
          final controls = <Widget>[
            DirectoryFilterField<String>(
              label: 'Rule',
              value: _ruleFilter,
              width: isSingleRow ? 135 : 160,
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('All rules', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                ..._rules.map(
                  (r) => DropdownMenuItem<String>(
                    value: r.ruleId,
                    child: Text(r.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _ruleFilter = v ?? ''),
            ),
            DirectoryFilterField<_DssStatusFilter>(
              label: 'Status',
              value: _statusFilter,
              width: isSingleRow ? 115 : 135,
              items: [
                for (final f in _DssStatusFilter.values)
                  DropdownMenuItem(
                    value: f,
                    child: Text(_statusFilterLabel(f), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _statusFilter = v);
              },
            ),
            DirectoryFilterField<DssPriority?>(
              label: 'Priority',
              value: _priorityFilter,
              width: isSingleRow ? 115 : 130,
              items: [
                const DropdownMenuItem<DssPriority?>(
                  value: null,
                  child: Text('All priorities', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                for (final p in DssPriority.values)
                  DropdownMenuItem<DssPriority?>(
                    value: p,
                    child: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _priorityFilter = v),
            ),
            DirectoryFilterField<_DssEvidenceFilter>(
              label: 'Sample size',
              value: _evidenceFilter,
              width: isSingleRow ? 135 : 150,
              items: [
                for (final f in _DssEvidenceFilter.values)
                  DropdownMenuItem(
                    value: f,
                    child: Text(
                      _evidenceFilterLabel(f),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _evidenceFilter = v);
              },
            ),
            DirectoryFilterField<_DssSort>(
              label: 'Sort',
              value: _sort,
              width: isSingleRow ? 110 : 125,
              items: const [
                DropdownMenuItem(
                  value: _DssSort.priority,
                  child: Text('Priority', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: _DssSort.newest,
                  child: Text('Newest first', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: _DssSort.oldest,
                  child: Text('Oldest first', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: _DssSort.severity,
                  child: Text('Severity', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: _DssSort.sampleDesc,
                  child: Text('Largest n', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _sort = v);
              },
            ),
            OutlinedButton.icon(
              onPressed: _openMoreFiltersDialog,
              icon: Icon(
                Icons.tune_rounded,
                size: 15,
                color: _moreFiltersCount > 0
                    ? AdminColors.primary
                    : AdminDirectoryTheme.textSecondary,
              ),
              label: Text(
                _moreFiltersCount > 0 ? 'More ($_moreFiltersCount)' : 'More',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight:
                      _moreFiltersCount > 0 ? FontWeight.w700 : FontWeight.w600,
                  color: _moreFiltersCount > 0
                      ? AdminColors.primary
                      : AdminDirectoryTheme.textPrimary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: _moreFiltersCount > 0
                    ? AdminColors.primary.withValues(alpha: 0.08)
                    : Colors.white,
                foregroundColor: _moreFiltersCount > 0
                    ? AdminColors.primary
                    : AdminDirectoryTheme.textPrimary,
                side: BorderSide(
                  color: _moreFiltersCount > 0
                      ? AdminColors.primary
                      : AdminDirectoryTheme.border,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                minimumSize: const Size(0, DirectoryFilterField.controlHeight),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AdminDirectoryTheme.radiusSm),
                ),
              ),
            ),
          ];

          if (isSingleRow) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < controls.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  controls[i],
                ],
              ],
            );
          }

          return Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: controls,
          );
        },
      ),
    );
  }
}

/// Modal dialog for secondary findings filters: due timeline, office, and ownership.
class _MoreFiltersDialog extends StatefulWidget {
  const _MoreFiltersDialog({
    required this.initialDue,
    required this.initialOffice,
    required this.initialMineOnly,
    required this.offices,
  });

  final _DssDueFilter initialDue;
  final String initialOffice;
  final bool initialMineOnly;
  final List<String> offices;

  @override
  State<_MoreFiltersDialog> createState() => _MoreFiltersDialogState();
}

class _MoreFiltersDialogState extends State<_MoreFiltersDialog> {
  late _DssDueFilter _due = widget.initialDue;
  late String _office = widget.initialOffice;
  late bool _mineOnly = widget.initialMineOnly;

  String _dueLabel(_DssDueFilter f) => switch (f) {
    _DssDueFilter.all => 'All due dates',
    _DssDueFilter.overdue => 'Overdue',
    _DssDueFilter.dueSoon => 'Due within 7 days',
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: AdminDialogStandards.elevation,
      shape: AdminDialogStandards.shape,
      insetPadding: AdminDialogStandards.defaultInsetPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: AdminDialogStandards.defaultContentPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminModalHeader(
                title: 'More Filters',
                subtitle:
                    'Filter findings by due date, assigned office, or ownership.',
                icon: Icons.tune_rounded,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              DirectoryFilterField<_DssDueFilter>(
                label: 'Due timeline',
                value: _due,
                width: double.infinity,
                items: [
                  for (final f in _DssDueFilter.values)
                    DropdownMenuItem(
                      value: f,
                      child: Text(_dueLabel(f)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _due = v);
                },
              ),
              const SizedBox(height: 14),
              DirectoryFilterField<String>(
                label: 'Assigned office',
                value: _office,
                width: double.infinity,
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All offices'),
                  ),
                  for (final o in widget.offices)
                    DropdownMenuItem<String>(
                      value: o,
                      child: Text(o, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _office = v ?? ''),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => setState(() => _mineOnly = !_mineOnly),
                borderRadius:
                    BorderRadius.circular(AdminDirectoryTheme.radiusSm),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _mineOnly
                        ? AdminColors.primary.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(AdminDirectoryTheme.radiusSm),
                    border: Border.all(
                      color:
                          _mineOnly ? AdminColors.primary : AdminColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _mineOnly,
                        activeColor: AdminColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (v) => setState(() => _mineOnly = v ?? false),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My findings only',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Show only findings assigned to my admin account.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AdminColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _due = _DssDueFilter.all;
                        _office = '';
                        _mineOnly = false;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AdminButtonStyles.outlined(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop((
                      due: _due,
                      office: _office,
                      mineOnly: _mineOnly,
                    )),
                    style: AdminButtonStyles.filled(),
                    child: const Text('Apply filters'),
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
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: AdminDialogStandards.elevation,
      shape: AdminDialogStandards.shape,
      insetPadding: AdminDialogStandards.defaultInsetPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: AdminDialogStandards.defaultContentPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminModalHeader(
                title: 'Report Card PDF',
                subtitle: 'Download manuscript-ready program and institution briefs.',
                icon: Icons.picture_as_pdf_outlined,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<String>>(
                future: _courses,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Text(
                      'Could not load programs: ${snap.error}',
                      style: const TextStyle(color: AdminColors.danger),
                    );
                  }
                  final courses = snap.data ?? const [];
                  if (courses.isEmpty) {
                    return const Text('No programs on the roster yet.');
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Text(
                          _selected == DssReportCardService.wholeInstitution
                              ? 'PDF with tracer results for all programs, results across waves, the most urgent findings across programs, intervention outcomes and actions taken.'
                              : 'PDF with this program\'s tracer results against the institution, results across waves, findings, intervention outcomes, actions taken and coverage re-checks.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DirectoryFilterField<String?>(
                        label: 'Select Scope or Program',
                        value: _selected,
                        width: double.infinity,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: DssReportCardService.wholeInstitution,
                            child: Text('Whole institution (all programs)'),
                          ),
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
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AdminButtonStyles.outlined(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Download PDF'),
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
