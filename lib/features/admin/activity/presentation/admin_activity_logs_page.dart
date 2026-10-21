import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_search_field.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Admin activity / audit log viewer (extracted from [AdminDashboardWeb]).
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
  final TextEditingController _activitySearchController =
      TextEditingController();
  List<AuditLog>? _cachedAuditLogs;
  bool _logsLoading = true;
  String _selectedActionFilter = 'All';
  String _selectedResourceFilter = 'All';
  String _selectedStatusFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  int _page = 0;
  int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadLogs();
    });
  }

  @override
  void dispose() {
    _activitySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _logsLoading = true);
    try {
      final logs = await _auditService.getAllAuditLogs(limit: 200);
      if (!mounted) return;
      setState(() {
        _cachedAuditLogs = logs;
        _logsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _logsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity logs: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.maxHeight.isFinite;
        final body = _buildActivityLogsContent(bounded: bounded);
        if (!bounded) {
          return SingleChildScrollView(child: body);
        }
        return body;
      },
    );
  }

  Widget _buildActivityLogsContent({required bool bounded}) {
    if (_logsLoading && _cachedAuditLogs == null) {
      return const AdminActivityLogSkeleton();
    }

    final logs = _cachedAuditLogs ?? [];

    if (!_logsLoading && logs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Activity Logs',
            subtitle: 'Audit trail of admin and system actions.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No activity logs yet.')),
          ),
        ],
      );
    }

    // Get unique values for filters
    final actions = ['All', ...logs.map((l) => l.action).toSet().toList()];
    final resources = ['All', ...logs.map((l) => l.resource).toSet().toList()];
    final statuses = ['All', ...logs.map((l) => l.status).toSet().toList()];

    // Apply filters including date range and search
    String searchQuery = '';
    try {
      if (_activitySearchController.text.isNotEmpty) {
        searchQuery = _activitySearchController.text.toLowerCase();
      }
    } catch (e) {
      // Controller might not be ready yet
      searchQuery = '';
    }
    var filteredLogs = logs.where((log) {
      final actionMatch =
          _selectedActionFilter == 'All' || log.action == _selectedActionFilter;
      final resourceMatch =
          _selectedResourceFilter == 'All' ||
          log.resource == _selectedResourceFilter;
      final statusMatch =
          _selectedStatusFilter == 'All' || log.status == _selectedStatusFilter;

      // Search filter
      final searchMatch =
          searchQuery.isEmpty ||
          (log.userName.toLowerCase().contains(searchQuery)) ||
          (log.userEmail.toLowerCase().contains(searchQuery)) ||
          (log.action.toLowerCase().contains(searchQuery)) ||
          (log.resource.toLowerCase().contains(searchQuery)) ||
          (log.description.toLowerCase().contains(searchQuery));

      // Date range filter
      bool dateMatch = true;
      if (_startDate != null) {
        final logDate = DateTime(
          log.timestamp.year,
          log.timestamp.month,
          log.timestamp.day,
        );
        final startDate = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );
        dateMatch =
            logDate.isAfter(startDate) || logDate.isAtSameMomentAs(startDate);
      }
      if (_endDate != null && dateMatch) {
        final logDate = DateTime(
          log.timestamp.year,
          log.timestamp.month,
          log.timestamp.day,
        );
        final endDate = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
        );
        dateMatch =
            logDate.isBefore(endDate.add(const Duration(days: 1))) ||
            logDate.isAtSameMomentAs(endDate);
      }

      return actionMatch &&
          resourceMatch &&
          statusMatch &&
          dateMatch &&
          searchMatch;
    }).toList();

    // Calculate statistics
    final totalLogs = filteredLogs.length;
    final successLogs = filteredLogs.where((l) => l.status == 'SUCCESS').length;
    final failedLogs = filteredLogs.where((l) => l.status == 'FAILED').length;

    // Calculate today's logs - check all logs, not just filtered ones
    final now = DateTime.now();
    final todayYear = now.year;
    final todayMonth = now.month;
    final todayDay = now.day;

    // Count logs from today
    int todayLogs = 0;
    for (final log in logs) {
      try {
        // Get timestamp and ensure it's in local time
        DateTime logDate = log.timestamp;
        if (logDate.isUtc) {
          logDate = logDate.toLocal();
        }

        // Compare year, month, and day
        if (logDate.year == todayYear &&
            logDate.month == todayMonth &&
            logDate.day == todayDay) {
          todayLogs++;
        }
      } catch (e) {
        // Skip logs with invalid timestamps
        continue;
      }
    }

    final logsPanel = _buildActivityLogsPanel(
      filteredLogs: filteredLogs,
      bounded: bounded,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPageHeader(
          title: 'Activity Logs',
          subtitle: 'Audit trail of admin and system actions.',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadLogs,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: AdminDensity.sectionGap),

        // Statistics Cards
        Row(
          children: [
            Expanded(
              child: _buildActivityStatCard(
                'Total Logs',
                totalLogs.toString(),
                Icons.history,
                AdminColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActivityStatCard(
                'Successful',
                successLogs.toString(),
                Icons.check_circle,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActivityStatCard(
                'Failed',
                failedLogs.toString(),
                Icons.error,
                const Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActivityStatCard(
                'Today',
                todayLogs.toString(),
                Icons.today,
                AdminColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AdminDensity.sectionGap),

        // Search and Filters Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: AdminColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Search & Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AdminColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Search Bar
              AdminSearchField(
                controller: _activitySearchController,
                onDebouncedChanged: (_) => setState(() => _page = 0),
                hintText: 'Search by user, action, resource, or description...',
                decoration: InputDecoration(
                  hintText:
                      'Search by user, action, resource, or description...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AdminColors.primary,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Filter Dropdowns
              Row(
                children: [
                  Expanded(
                    child: DirectoryFilterField<String>(
                      label: 'Action',
                      value: _selectedActionFilter,
                      items: [
                        for (final item in actions)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedActionFilter = value ?? 'All';
                          _page = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DirectoryFilterField<String>(
                      label: 'Resource',
                      value: _selectedResourceFilter,
                      items: [
                        for (final item in resources)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedResourceFilter = value ?? 'All';
                          _page = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DirectoryFilterField<String>(
                      label: 'Status',
                      value: _selectedStatusFilter,
                      items: [
                        for (final item in statuses)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatusFilter = value ?? 'All';
                          _page = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DirectoryDateFilterChip(
                      label: 'Start',
                      expand: true,
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
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DirectoryDateFilterChip(
                      label: 'End',
                      expand: true,
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
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedActionFilter = 'All';
                        _selectedResourceFilter = 'All';
                        _selectedStatusFilter = 'All';
                        _startDate = null;
                        _endDate = null;
                        _page = 0;
                        try {
                          if (_activitySearchController.text.isNotEmpty) {
                            _activitySearchController.clear();
                          }
                        } catch (e) {
                          // Controller might not be ready, ignore
                        }
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset Filters'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (bounded) Expanded(child: logsPanel) else logsPanel,
      ],
    );
  }

  Widget _buildActivityLogsPanel({
    required List<AuditLog> filteredLogs,
    required bool bounded,
  }) {
    final safePage = adminClampPage(_page, filteredLogs.length, _pageSize);
    final pageLogs = adminPaginate(filteredLogs, safePage, _pageSize);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AdminColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Log records',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${filteredLogs.length} ${filteredLogs.length == 1 ? 'record' : 'records'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filteredLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(60),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No activity logs found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your filters or search query',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            if (bounded)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: AdminDataTable(
                    columns: const [
                      AdminDataColumn(label: 'TIME', width: 140),
                      AdminDataColumn(label: 'ACTION', flex: 2),
                      AdminDataColumn(label: 'USER', flex: 2),
                      AdminDataColumn(label: 'RESOURCE', width: 120),
                      AdminDataColumn(label: 'STATUS', width: 100),
                      AdminDataColumn(label: 'DESCRIPTION', flex: 3),
                    ],
                    rowCount: pageLogs.length,
                    rowBuilder: (context, index) {
                      return _buildActivityLogRow(pageLogs[index]);
                    },
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: AdminDataTable(
                  shrinkWrap: true,
                  columns: const [
                    AdminDataColumn(label: 'TIME', width: 140),
                    AdminDataColumn(label: 'ACTION', flex: 2),
                    AdminDataColumn(label: 'USER', flex: 2),
                    AdminDataColumn(label: 'RESOURCE', width: 120),
                    AdminDataColumn(label: 'STATUS', width: 100),
                    AdminDataColumn(label: 'DESCRIPTION', flex: 3),
                  ],
                  rowCount: pageLogs.length,
                  rowBuilder: (context, index) {
                    return _buildActivityLogRow(pageLogs[index]);
                  },
                ),
              ),
            AdminPaginationBar(
              totalItems: filteredLogs.length,
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

  Widget _buildActivityStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AdminDensity.kpiCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: AdminDensity.kpiIconBox,
            height: AdminDensity.kpiIconBox,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: AdminDensity.kpiIconSize),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AdminDensity.kpiLabelFontSize,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: AdminDensity.kpiValueFontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLogRow(AuditLog log) {
    final isSuccess = log.status == 'SUCCESS';
    const columns = [
      AdminDataColumn(label: 'TIME', width: 140),
      AdminDataColumn(label: 'ACTION', flex: 2),
      AdminDataColumn(label: 'USER', flex: 2),
      AdminDataColumn(label: 'RESOURCE', width: 120),
      AdminDataColumn(label: 'STATUS', width: 100),
      AdminDataColumn(label: 'DESCRIPTION', flex: 3),
    ];

    return AdminDataRow(
      columns: columns,
      cells: [
        AdminTableTextCell(
          DateFormat('MMM d, HH:mm').format(log.timestamp),
          muted: true,
        ),
        AdminTableTextCell(log.action, bold: true),
        AdminTableIdentityCell(
          title: log.userName.isEmpty ? 'Unknown' : log.userName,
          subtitle: log.userEmail,
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: log.userRole == 'admin'
                  ? AdminColors.accent.withValues(alpha: 0.2)
                  : const Color(0xFF2196F3).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                log.userName.isNotEmpty ? log.userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: log.userRole == 'admin'
                      ? const Color(0xFFB45309)
                      : const Color(0xFF2196F3),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminTableBadge(
            label: log.resource,
            bg: AdminTableTheme.headerBg,
            fg: AdminTableTheme.primary,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminTableBadge(
            label: log.status,
            bg: isSuccess
                ? AdminTableTheme.successBg
                : AdminTableTheme.dangerBg,
            fg: isSuccess ? AdminTableTheme.success : AdminTableTheme.danger,
            icon: isSuccess ? Icons.check_circle : Icons.error,
          ),
        ),
        AdminTableTextCell(log.description, muted: true, maxLines: 2),
      ],
    );
  }
}
