import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/admin/activity/widgets/admin_activity_ui.dart';
import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/core/utils/web_file_download.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';

/// Optional CSV download callback (defaults to [downloadTextOnWeb]).
typedef ActivityCsvDownloader = void Function({
  required String content,
  required String fileName,
  String mimeType,
});

/// Admin activity / audit log viewer.
class AdminActivityLogsScreen extends StatefulWidget {
  const AdminActivityLogsScreen({
    super.key,
    this.service,
    this.csvDownloader,
  });

  final AuditService? service;
  final ActivityCsvDownloader? csvDownloader;

  @override
  State<AdminActivityLogsScreen> createState() =>
      _AdminActivityLogsScreenState();
}

class _AdminActivityLogsScreenState extends State<AdminActivityLogsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final AuditService _auditService = widget.service ?? AuditService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _lastSearchedTerm = '';

  List<AuditLog> _logs = const [];
  AuditLogStats _stats = AuditLogStats.empty;
  bool _loading = true;
  bool _hasLoaded = false;
  bool _exporting = false;
  String? _error;
  String? _loadedStatsRangeKey;
  int _loadSeq = 0;
  String _actionFilter = 'All';
  String _moduleFilter = 'All';
  String _statusFilter = 'All';
  String _actorTypeFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  int _page = 0;
  int _pageSize = 25;
  static const _fetchLimit = 500;

  static const _moduleOptions = [
    'All',
    AuditModules.auth,
    AuditModules.alumni,
    AuditModules.profile,
    AuditModules.surveys,
    AuditModules.events,
    AuditModules.jobs,
    AuditModules.forum,
    AuditModules.announcements,
    AuditModules.reports,
    AuditModules.administration,
    AuditModules.dss,
    AuditModules.archives,
    AuditModules.system,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadLogs(refreshStats: true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  AuditLogQuery get _query => AuditLogQuery(
        limit: _fetchLimit,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        action: _actionFilter,
        module: _moduleFilter,
        status: _statusFilter,
        actorType: _actorTypeFilter,
        startDate: _startDate,
        endDate: _endDate,
      );

  String get _statsRangeKey =>
      '${_startDate?.toIso8601String() ?? ''}|${_endDate?.toIso8601String() ?? ''}';

  Future<void> _loadLogs({bool refreshStats = false}) async {
    final seq = ++_loadSeq;
    final rangeKey = _statsRangeKey;
    final needStats =
        refreshStats || !_hasLoaded || _loadedStatsRangeKey != rangeKey;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final logsFuture = _auditService.queryAuditLogs(_query);
      final statsFuture = needStats
          ? _auditService.getAuditLogStats(
              startDate: _startDate,
              endDate: _endDate,
            )
          : null;

      final page = await logsFuture;
      final stats = statsFuture != null ? await statsFuture : null;

      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _logs = page.logs;
        if (stats != null) {
          _stats = stats;
          _loadedStatsRangeKey = rangeKey;
        }
        _loading = false;
        _hasLoaded = true;
        _error = null;
        _page = 0;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _hasLoaded = true;
        _error = '$e';
      });
      if (_logs.isEmpty) {
        _showSnack(
          auditFriendlyError(e, 'Could not load activity logs.'),
          isError: true,
        );
      }
    }
  }

  void _onSearchChanged(String raw) {
    _searchDebounce?.cancel();
    final normalized = raw.trim();
    if (normalized == _lastSearchedTerm) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _lastSearchedTerm = _searchController.text.trim();
      setState(() => _page = 0);
      _loadLogs();
    });
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    _lastSearchedTerm = '';
    setState(() {
      _actionFilter = 'All';
      _moduleFilter = 'All';
      _statusFilter = 'All';
      _actorTypeFilter = 'All';
      _startDate = null;
      _endDate = null;
      _page = 0;
      _searchController.clear();
    });
    _loadLogs(refreshStats: true);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AdminColors.danger : null,
        ),
      );
  }

  Future<void> _exportCsv() async {
    if (_exporting || _logs.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final csv = _auditService.buildExportCsv(_logs);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'aess_activity_logs_$stamp.csv';
      if (widget.csvDownloader != null) {
        widget.csvDownloader!(
          content: csv,
          fileName: fileName,
          mimeType: 'text/csv',
        );
      } else if (isWebFileDownloadSupported) {
        downloadTextOnWeb(
          content: csv,
          fileName: fileName,
          mimeType: 'text/csv',
        );
      }
      await _auditService.logAction(
        action: AuditActions.exportAuditLogs,
        resource: 'AuditLog',
        resourceId: 'export',
        description: 'Exported ${_logs.length} activity log row(s) to CSV',
        userRole: 'admin',
        module: AuditModules.administration,
        category: AuditCategories.security,
        changes: {'rowCount': _logs.length, 'fileName': fileName},
      );
      if (!mounted) return;
      _showSnack('Exported ${_logs.length} log(s).');
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        auditFriendlyError(e, 'Could not export activity logs.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.maxHeight.isFinite;
        final width = constraints.maxWidth;
        final useInnerScroll = boundedHeight &&
            width >= AdminDensity.desktopSplitMin &&
            constraints.maxHeight >= 640;
        final body = _buildContent(bounded: useInnerScroll);
        if (!useInnerScroll) {
          return SingleChildScrollView(child: body);
        }
        return body;
      },
    );
  }

  Widget _buildHeader() {
    return AdminCompactHeader(
      title: 'Activity Logs',
      actions: [
        OutlinedButton.icon(
          onPressed: _loading ? null : () => _loadLogs(refreshStats: true),
          style: AdminButtonStyles.outlined(),
          icon: _loading && _hasLoaded
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 16),
          label: Text(_loading && _hasLoaded ? 'Refreshing…' : 'Refresh'),
        ),
        FilledButton.icon(
          onPressed:
              _loading || _exporting || _logs.isEmpty ? null : _exportCsv,
          style: AdminButtonStyles.filled(),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
        ),
      ],
    );
  }

  Widget _buildMetrics() {
    return AdminMetricRibbon(
      items: [
        AdminMetricRibbonItem(
          label: 'Total (range)',
          value: '${_stats.total}',
          icon: Icons.history,
          color: AdminColors.primary,
          tooltip: 'All events in the current date range',
        ),
        AdminMetricRibbonItem(
          label: 'Admin actions',
          value: '${_stats.adminActions}',
          icon: Icons.admin_panel_settings_outlined,
          color: AdminColors.accent,
          tooltip: 'Administrator activity',
        ),
        AdminMetricRibbonItem(
          label: 'Security',
          value: '${_stats.securityEvents}',
          icon: Icons.shield_outlined,
          color: AdminColors.warning,
          tooltip: 'Security-category events',
        ),
        AdminMetricRibbonItem(
          label: 'Failed',
          value: '${_stats.failed}',
          icon: Icons.error_outline,
          color: AdminColors.danger,
          tooltip: 'Failed or rejected actions',
        ),
      ],
    );
  }

  Widget _buildRefreshErrorNotice() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AdminColors.warningBg,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AdminColors.warning,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Couldn't refresh activity logs. Showing the last loaded list.",
              style: TextStyle(fontSize: 13, color: AdminColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : () => _loadLogs(refreshStats: true),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent({required bool bounded}) {
    if (_loading && !_hasLoaded) {
      return const AdminActivityLogSkeleton();
    }

    final actions = {
      'All',
      if (_actionFilter != 'All') _actionFilter,
      ..._logs.map((l) => l.action).where((a) => a.isNotEmpty),
    }.toList()
      ..sort();

    final safePage = adminClampPage(_page, _logs.length, _pageSize);
    final pageLogs = adminPaginate(_logs, safePage, _pageSize);

    final logsPanel = _buildLogsArea(
      pageLogs: pageLogs,
      total: _logs.length,
      safePage: safePage,
      bounded: bounded,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: AdminDensity.space2),
        _buildMetrics(),
        const SizedBox(height: AdminDensity.space2),
        _buildToolbar(actions: actions),
        if (_error != null && _logs.isNotEmpty) ...[
          const SizedBox(height: AdminDensity.space1),
          _buildRefreshErrorNotice(),
        ],
        const SizedBox(height: AdminDensity.space1),
        if (bounded) Expanded(child: logsPanel) else logsPanel,
      ],
    );
  }

  List<Widget> _activeFilterChips() {
    final search = _searchController.text.trim();
    return [
      if (search.isNotEmpty)
        DirectoryActiveFilterChip(
          label: 'Search: $search',
          onRemoved: () {
            _searchDebounce?.cancel();
            _searchController.clear();
            _lastSearchedTerm = '';
            setState(() => _page = 0);
            _loadLogs();
          },
        ),
      if (_moduleFilter != 'All')
        DirectoryActiveFilterChip(
          label: 'Module: $_moduleFilter',
          onRemoved: () {
            setState(() {
              _moduleFilter = 'All';
              _page = 0;
            });
            _loadLogs();
          },
        ),
      if (_statusFilter != 'All')
        DirectoryActiveFilterChip(
          label: 'Status: $_statusFilter',
          onRemoved: () {
            setState(() {
              _statusFilter = 'All';
              _page = 0;
            });
            _loadLogs();
          },
        ),
      if (_actorTypeFilter != 'All')
        DirectoryActiveFilterChip(
          label: 'Actor: $_actorTypeFilter',
          onRemoved: () {
            setState(() {
              _actorTypeFilter = 'All';
              _page = 0;
            });
            _loadLogs();
          },
        ),
      if (_actionFilter != 'All')
        DirectoryActiveFilterChip(
          label: 'Action: $_actionFilter',
          onRemoved: () {
            setState(() {
              _actionFilter = 'All';
              _page = 0;
            });
            _loadLogs();
          },
        ),
      if (_startDate != null)
        DirectoryActiveFilterChip(
          label: 'From: ${DirectoryDateTimePickers.formatDate(_startDate!)}',
          onRemoved: () {
            setState(() {
              _startDate = null;
              _page = 0;
            });
            _loadLogs();
          },
        ),
      if (_endDate != null)
        DirectoryActiveFilterChip(
          label: 'To: ${DirectoryDateTimePickers.formatDate(_endDate!)}',
          onRemoved: () {
            setState(() {
              _endDate = null;
              _page = 0;
            });
            _loadLogs();
          },
        ),
    ];
  }

  Widget _buildToolbar({required List<String> actions}) {
    return AdminSaaSToolbar(
      searchHint: 'Search actor, action, description…',
      searchWidth: 240,
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      onClearSearch: () {
        _searchDebounce?.cancel();
        _searchController.clear();
        _lastSearchedTerm = '';
        setState(() => _page = 0);
        _loadLogs();
      },
      isLoading: _loading,
      onRefresh: () => _loadLogs(refreshStats: true),
      refreshTooltip: 'Refresh logs',
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      filters: [
        DirectoryDateFilterChip(
          label: 'From',
          displayText: _startDate == null
              ? 'Any date'
              : DirectoryDateTimePickers.formatDate(_startDate!),
          active: _startDate != null,
          width: 126,
          onTap: () async {
            final picked = await DirectoryDateTimePickers.pickDate(
              context,
              initialDate: _startDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              helpText: 'Start date',
            );
            if (picked == null || !mounted) return;
            setState(() {
              _startDate = picked;
              if (_endDate != null && _endDate!.isBefore(picked)) {
                _endDate = picked;
              }
              _page = 0;
            });
            _loadLogs();
          },
        ),
        DirectoryDateFilterChip(
          label: 'To',
          displayText: _endDate == null
              ? 'Any date'
              : DirectoryDateTimePickers.formatDate(_endDate!),
          active: _endDate != null,
          width: 126,
          onTap: () async {
            final picked = await DirectoryDateTimePickers.pickDate(
              context,
              initialDate: _endDate ?? _startDate ?? DateTime.now(),
              firstDate: _startDate ?? DateTime(2020),
              lastDate: DateTime.now(),
              helpText: 'End date',
            );
            if (picked == null || !mounted) return;
            setState(() {
              _endDate = picked;
              _page = 0;
            });
            _loadLogs();
          },
        ),
        DirectoryFilterField<String>(
          label: 'Module',
          value: _moduleFilter,
          dense: true,
          width: 132,
          items: [
            for (final m in _moduleOptions)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _moduleFilter = v;
              _page = 0;
            });
            _loadLogs();
          },
        ),
        DirectoryFilterField<String>(
          label: 'Status',
          value: _statusFilter,
          dense: true,
          width: 118,
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All')),
            DropdownMenuItem(
              value: AuditStatus.success,
              child: Text('SUCCESS'),
            ),
            DropdownMenuItem(
              value: AuditStatus.failed,
              child: Text('FAILED'),
            ),
            DropdownMenuItem(
              value: AuditStatus.rejected,
              child: Text('REJECTED'),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _statusFilter = v;
              _page = 0;
            });
            _loadLogs();
          },
        ),
        DirectoryFilterField<String>(
          label: 'Actor',
          value: _actorTypeFilter,
          dense: true,
          width: 112,
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All')),
            DropdownMenuItem(
              value: AuditActorTypes.admin,
              child: Text('admin'),
            ),
            DropdownMenuItem(
              value: AuditActorTypes.alumni,
              child: Text('alumni'),
            ),
            DropdownMenuItem(
              value: AuditActorTypes.system,
              child: Text('system'),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _actorTypeFilter = v;
              _page = 0;
            });
            _loadLogs();
          },
        ),
        DirectoryFilterField<String>(
          label: 'Action',
          value: _actionFilter,
          dense: true,
          width: 152,
          items: [
            for (final a in actions) DropdownMenuItem(value: a, child: Text(a)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _actionFilter = v;
              _page = 0;
            });
            _loadLogs();
          },
        ),
      ],
    );
  }

  bool get _hasActiveFilters =>
      _actionFilter != 'All' ||
      _moduleFilter != 'All' ||
      _statusFilter != 'All' ||
      _actorTypeFilter != 'All' ||
      _startDate != null ||
      _endDate != null ||
      _searchController.text.trim().isNotEmpty;

  Widget _buildLogsArea({
    required List<AuditLog> pageLogs,
    required int total,
    required int safePage,
    required bool bounded,
  }) {
    if (_error != null && _logs.isEmpty) {
      return AdminStateView.error(
        title: "Couldn't load activity logs",
        message: auditFriendlyError(
          _error!,
          'Check your connection and try again.',
        ),
        details: _error,
        onRetry: () => _loadLogs(refreshStats: true),
      );
    }

    if (total == 0) {
      return AdminStateView.empty(
        icon: Icons.history_toggle_off_outlined,
        title: _hasActiveFilters
            ? 'No matching activity logs'
            : 'No activity logs yet',
        message: _hasActiveFilters
            ? 'Try clearing filters or broadening your date range.'
            : 'System activity and security audit events will appear here.',
        primaryAction: _hasActiveFilters
            ? AdminStateAction(
                label: 'Clear filters',
                icon: Icons.filter_alt_off_outlined,
                onPressed: _resetFilters,
              )
            : null,
      );
    }

    return _buildLogsPanel(
      pageLogs: pageLogs,
      total: total,
      safePage: safePage,
      bounded: bounded,
    );
  }

  Widget _buildDesktopTable({
    required List<AuditLog> pageLogs,
    required bool bounded,
  }) {
    const columns = [
      AdminDataColumn(label: 'TIME', width: 120),
      AdminDataColumn(label: 'ACTOR', flex: 2),
      AdminDataColumn(label: 'ACTION', flex: 2),
      AdminDataColumn(label: 'MODULE', width: 108),
      AdminDataColumn(label: 'TARGET', flex: 2),
      AdminDataColumn(label: 'RESULT', width: 98),
      AdminDataColumn(label: '', width: 44),
    ];

    return AdminDataTable(
      shrinkWrap: !bounded,
      showBorder: false,
      enableHorizontalScroll: true,
      minTableWidth: 860,
      columns: columns,
      rowCount: pageLogs.length,
      rowBuilder: (context, index) {
        final log = pageLogs[index];
        final badgeColors = auditStatusTableColors(log.status);
        final isSecurity = log.category == AuditCategories.security;
        return AdminDataRow(
          columns: columns,
          onTap: () => showAdminActivityLogDetailPanel(context, log),
          cells: [
            AdminTableTextCell(
              DateFormat('MMM d, HH:mm').format(log.timestamp),
              muted: true,
            ),
            AdminTableIdentityCell(
              title: auditActorDisplayName(log),
              subtitle: log.actorType,
            ),
            Row(
              children: [
                if (isSecurity) ...[
                  const Tooltip(
                    message: 'Security event',
                    child: Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: AdminColors.warning,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: AdminTableTextCell(log.action, bold: true, maxLines: 1),
                ),
              ],
            ),
            AdminTableTextCell(
              log.module.isEmpty ? '—' : log.module,
              muted: true,
            ),
            AdminTableTextCell(
              auditTargetSummary(log),
              muted: true,
              maxLines: 1,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AdminTableBadge(
                label: log.status,
                bg: badgeColors.bg,
                fg: badgeColors.fg,
              ),
            ),
            IconButton(
              tooltip: 'Details',
              icon: const Icon(
                Icons.chevron_right,
                size: 20,
                color: AdminColors.textSecondary,
              ),
              onPressed: () => showAdminActivityLogDetailPanel(context, log),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileCards({
    required List<AuditLog> pageLogs,
    required bool bounded,
  }) {
    return ListView.separated(
      shrinkWrap: !bounded,
      physics: bounded
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AdminDensity.space1),
      itemCount: pageLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AdminDensity.space1),
      itemBuilder: (context, index) {
        final log = pageLogs[index];
        return AdminActivityLogCard(
          log: log,
          onTap: () => showAdminActivityLogDetailPanel(context, log),
        );
      },
    );
  }

  Widget _buildLogsPanel({
    required List<AuditLog> pageLogs,
    required int total,
    required int safePage,
    required bool bounded,
  }) {
    final listContent = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AdminDensity.desktopSplitMin) {
          return _buildDesktopTable(pageLogs: pageLogs, bounded: bounded);
        }
        return _buildMobileCards(pageLogs: pageLogs, bounded: bounded);
      },
    );

    return Container(
      decoration: AdminSurfaces.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bounded) Expanded(child: listContent) else listContent,
          LayoutBuilder(
            builder: (context, constraints) {
              final allowPageSize = constraints.maxWidth >= 460;
              return AdminPaginationBar(
                totalItems: total,
                page: safePage,
                pageSize: _pageSize,
                dense: true,
                onPageChanged: (p) => setState(() => _page = p),
                onPageSizeChanged: allowPageSize
                    ? (s) => setState(() {
                          _pageSize = s;
                          _page = 0;
                        })
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
