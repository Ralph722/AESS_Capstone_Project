import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/core/utils/web_file_download.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';

/// Admin activity / audit log viewer.
class AdminActivityLogsScreen extends StatefulWidget {
  const AdminActivityLogsScreen({super.key});

  @override
  State<AdminActivityLogsScreen> createState() =>
      _AdminActivityLogsScreenState();
}

class _AdminActivityLogsScreenState extends State<AdminActivityLogsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AuditService _auditService = AuditService();
  final TextEditingController _searchController = TextEditingController();

  List<AuditLog> _logs = const [];
  AuditLogStats _stats = AuditLogStats.empty;
  bool _loading = true;
  String _actionFilter = 'All';
  String _resourceFilter = 'All';
  String _moduleFilter = 'All';
  String _categoryFilter = 'All';
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
    AuditModules.feedback,
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
      if (mounted) _loadLogs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AuditLogQuery get _query => AuditLogQuery(
        limit: _fetchLimit,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        action: _actionFilter,
        resource: _resourceFilter,
        module: _moduleFilter,
        category: _categoryFilter,
        status: _statusFilter,
        actorType: _actorTypeFilter,
        startDate: _startDate,
        endDate: _endDate,
      );

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _auditService.queryAuditLogs(_query),
        _auditService.getAuditLogStats(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ]);
      if (!mounted) return;
      final page = results[0] as ({List<AuditLog> logs, int? totalHint});
      setState(() {
        _logs = page.logs;
        _stats = results[1] as AuditLogStats;
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity logs: $e')),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _actionFilter = 'All';
      _resourceFilter = 'All';
      _moduleFilter = 'All';
      _categoryFilter = 'All';
      _statusFilter = 'All';
      _actorTypeFilter = 'All';
      _startDate = null;
      _endDate = null;
      _page = 0;
      _searchController.clear();
    });
    _loadLogs();
  }

  Future<void> _exportCsv() async {
    try {
      final csv = _auditService.buildExportCsv(_logs);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'aess_activity_logs_$stamp.csv';
      if (isWebFileDownloadSupported) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${_logs.length} log(s).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _showLogDetails(AuditLog log) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text(
                  log.action,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AdminDirectoryTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy · HH:mm:ss').format(log.timestamp),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _detailRow('Actor', log.userName.isEmpty ? 'Unknown' : log.userName),
                _detailRow('Email', log.userEmail.isEmpty ? '—' : log.userEmail),
                _detailRow('Role', log.userRole),
                _detailRow('Actor type', log.actorType),
                _detailRow('Module', log.module.isEmpty ? '—' : log.module),
                _detailRow('Category', log.category),
                _detailRow('Resource', log.resource),
                _detailRow('Target id', log.resourceId),
                if (log.targetLabel != null && log.targetLabel!.isNotEmpty)
                  _detailRow('Target', log.targetLabel!),
                _detailRow('Result', log.status),
                if (log.correlationId != null && log.correlationId!.isNotEmpty)
                  _detailRow('Correlation ID', log.correlationId!),
                const SizedBox(height: 12),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(log.description.isEmpty ? '—' : log.description),
                if (log.changes != null && log.changes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Changes / metadata',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminDirectoryTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminDirectoryTheme.border),
                    ),
                    child: Text(
                      _formatChanges(log.changes!),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatChanges(Map<String, dynamic> changes) {
    final buffer = StringBuffer();
    for (final entry in changes.entries) {
      final value = entry.value;
      if (value is Map && value.containsKey('from') && value.containsKey('to')) {
        buffer.writeln('${entry.key}: ${value['from']} → ${value['to']}');
      } else {
        buffer.writeln('${entry.key}: $value');
      }
    }
    return buffer.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.maxHeight.isFinite;
        final body = _buildContent(bounded: bounded);
        if (!bounded) {
          return SingleChildScrollView(child: body);
        }
        return body;
      },
    );
  }

  Widget _buildContent({required bool bounded}) {
    if (_loading && _logs.isEmpty) {
      return const AdminActivityLogSkeleton();
    }

    final actions = {
      'All',
      ..._logs.map((l) => l.action),
    }.toList()
      ..sort();
    final resources = {
      'All',
      ..._logs.map((l) => l.resource).where((r) => r.isNotEmpty),
    }.toList()
      ..sort();

    final safePage = adminClampPage(_page, _logs.length, _pageSize);
    final pageLogs = adminPaginate(_logs, safePage, _pageSize);

    final logsPanel = _buildLogsPanel(
      pageLogs: pageLogs,
      total: _logs.length,
      safePage: safePage,
      bounded: bounded,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          title: 'Activity Logs',
          subtitle: 'System activity and security audit trail.',
          actions: [
            IconButton(
              tooltip: 'Export CSV',
              onPressed: _logs.isEmpty ? null : _exportCsv,
              icon: const Icon(Icons.download_outlined),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadLogs,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: AdminDensity.sectionGap),
        DirectoryStatsGrid(
          children: [
            DirectoryStatCard(
              label: 'Total (range)',
              value: '${_stats.total}',
              description: 'Matching loaded logs',
              icon: Icons.history,
              accent: AdminDirectoryTheme.navy,
            ),
            DirectoryStatCard(
              label: 'Today',
              value: '${_stats.today}',
              description: 'Events since midnight',
              icon: Icons.today_outlined,
              accent: AdminDirectoryTheme.info,
            ),
            DirectoryStatCard(
              label: 'Admin actions',
              value: '${_stats.adminActions}',
              description: 'Administrator activity',
              icon: Icons.admin_panel_settings_outlined,
              accent: AdminDirectoryTheme.gold,
            ),
            DirectoryStatCard(
              label: 'Security',
              value: '${_stats.securityEvents}',
              description: 'Security-category events',
              icon: Icons.shield_outlined,
              accent: AdminDirectoryTheme.warning,
            ),
            DirectoryStatCard(
              label: 'Failed',
              value: '${_stats.failed}',
              description: 'Failed or rejected',
              icon: Icons.error_outline,
              accent: AdminDirectoryTheme.danger,
            ),
            DirectoryStatCard(
              label: 'System',
              value: '${_stats.systemEvents}',
              description: 'Automated actors',
              icon: Icons.settings_suggest_outlined,
              accent: AdminDirectoryTheme.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: AdminDensity.sectionGap),
        DirectoryToolbarCard(
          searchHint: 'Search actor, action, description…',
          searchController: _searchController,
          onSearchChanged: (_) {},
          onClearSearch: () {
            _searchController.clear();
            _loadLogs();
          },
          isLoading: _loading,
          onRefresh: _loadLogs,
          refreshTooltip: 'Refresh logs',
          hasActiveFilters: _hasActiveFilters,
          onResetFilters: _resetFilters,
          filters: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DirectoryFilterField<String>(
                label: 'Action',
                value: _actionFilter,
                width: 160,
                items: [
                  for (final a in actions)
                    DropdownMenuItem(value: a, child: Text(a)),
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
              DirectoryFilterField<String>(
                label: 'Module',
                value: _moduleFilter,
                width: 140,
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
                label: 'Category',
                value: _categoryFilter,
                width: 120,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(
                    value: AuditCategories.activity,
                    child: Text('activity'),
                  ),
                  DropdownMenuItem(
                    value: AuditCategories.security,
                    child: Text('security'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _categoryFilter = v;
                    _page = 0;
                  });
                  _loadLogs();
                },
              ),
              DirectoryFilterField<String>(
                label: 'Status',
                value: _statusFilter,
                width: 120,
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
                width: 120,
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
                label: 'Resource',
                value: _resourceFilter,
                width: 140,
                items: [
                  for (final r in resources)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _resourceFilter = v;
                    _page = 0;
                  });
                  _loadLogs();
                },
              ),
              DirectoryDateFilterChip(
                label: 'From',
                displayText: _startDate == null
                    ? 'Any date'
                    : DirectoryDateTimePickers.formatDate(_startDate!),
                active: _startDate != null,
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
            ],
          ),
        ),
        const SizedBox(height: AdminDensity.sectionGap),
        if (bounded) Expanded(child: logsPanel) else logsPanel,
      ],
    );
  }

  bool get _hasActiveFilters =>
      _actionFilter != 'All' ||
      _resourceFilter != 'All' ||
      _moduleFilter != 'All' ||
      _categoryFilter != 'All' ||
      _statusFilter != 'All' ||
      _actorTypeFilter != 'All' ||
      _startDate != null ||
      _endDate != null ||
      _searchController.text.trim().isNotEmpty;

  Widget _buildLogsPanel({
    required List<AuditLog> pageLogs,
    required int total,
    required int safePage,
    required bool bounded,
  }) {
    const columns = [
      AdminDataColumn(label: 'TIME', width: 120),
      AdminDataColumn(label: 'ACTOR', flex: 2),
      AdminDataColumn(label: 'ACTION', flex: 2),
      AdminDataColumn(label: 'MODULE', width: 100),
      AdminDataColumn(label: 'TARGET', flex: 2),
      AdminDataColumn(label: 'RESULT', width: 96),
      AdminDataColumn(label: '', width: 44),
    ];

    final table = AdminDataTable(
      shrinkWrap: !bounded,
      columns: columns,
      rowCount: pageLogs.length,
      rowBuilder: (context, index) {
        final log = pageLogs[index];
        final isSuccess = log.status == AuditStatus.success;
        return AdminDataRow(
          columns: columns,
          onTap: () => _showLogDetails(log),
          cells: [
            AdminTableTextCell(
              DateFormat('MMM d, HH:mm').format(log.timestamp),
              muted: true,
            ),
            AdminTableIdentityCell(
              title: log.userName.isEmpty
                  ? (log.actorType == AuditActorTypes.system
                      ? 'System'
                      : 'Unknown')
                  : log.userName,
              subtitle: log.actorType,
            ),
            AdminTableTextCell(log.action, bold: true, maxLines: 1),
            AdminTableTextCell(
              log.module.isEmpty ? '—' : log.module,
              muted: true,
            ),
            AdminTableTextCell(
              log.targetLabel?.isNotEmpty == true
                  ? log.targetLabel!
                  : (log.resource.isEmpty
                      ? '—'
                      : '${log.resource}${log.resourceId.isNotEmpty ? ' · ${log.resourceId}' : ''}'),
              muted: true,
              maxLines: 1,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AdminTableBadge(
                label: log.status,
                bg: isSuccess
                    ? AdminTableTheme.successBg
                    : AdminTableTheme.dangerBg,
                fg: isSuccess
                    ? AdminTableTheme.success
                    : AdminTableTheme.danger,
              ),
            ),
            IconButton(
              tooltip: 'Details',
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => _showLogDetails(log),
            ),
          ],
        );
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusMd),
        border: Border.all(color: AdminDirectoryTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              total == 0
                  ? 'No activity logs match these filters.'
                  : '$total record${total == 1 ? '' : 's'}'
                      '${total >= _fetchLimit ? ' (showing latest $_fetchLimit)' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: Text('No activity logs yet.')),
            )
          else ...[
            if (bounded)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: table,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: table,
              ),
            AdminPaginationBar(
              totalItems: total,
              page: safePage,
              pageSize: _pageSize,
              onPageChanged: (p) => setState(() => _page = p),
              onPageSizeChanged: (s) => setState(() {
                _pageSize = s;
                _page = 0;
              }),
            ),
          ],
        ],
      ),
    );
  }
}
