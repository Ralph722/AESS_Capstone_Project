import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/core/utils/web_file_download.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/models/forum_filters.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/presentation/forum_topic_page.dart';
import 'package:alumni_system/features/forum/presentation/forum_composer_page.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/features/admin/forum/widgets/admin_forum_ui.dart';
import 'package:alumni_system/features/share/share_link_sheet.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_tabs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Admin forum moderation — matches Directory / Surveys / Events / Announcements SaaS chrome.
class AdminForumScreen extends StatefulWidget {
  const AdminForumScreen({super.key, this.service});

  final ForumService? service;

  @override
  State<AdminForumScreen> createState() => _AdminForumScreenState();
}

enum _AdminForumMode { discussions, reports }

class _AdminForumScreenState extends State<AdminForumScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final ForumService _forumService = widget.service ?? ForumService();
  final _searchController = TextEditingController();
  final Set<String> _busyTopicIds = {};
  final Set<String> _busyReportIds = {};

  StreamSubscription<void>? _refreshSub;
  List<ForumTopic> _catalog = [];
  List<ForumTopic> _topics = [];
  List<ForumReport> _reports = [];
  bool _loading = true;
  bool _hasLoaded = false;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  String? _error;
  bool _lockedOnly = false;
  _AdminForumMode _mode = _AdminForumMode.discussions;
  String _reportStatus = 'open';

  String _search = '';
  ForumSort _sort = ForumSort.latestActivity;
  final Set<ForumListFilter> _filters = {ForumListFilter.all};
  String? _programFilter;
  Timer? _debounce;

  int _statTotal = 0;
  int _statUnanswered = 0;
  int _statLocked = 0;
  int _statOpenReports = 0;
  List<String> _allPrograms = [];

  String? _selectedTopicId;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshSub = ForumService.topicsChangedStream.listen((_) {
      if (mounted) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refreshSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    _refreshInFlight = true;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final catalog = await _forumService.getAllTopics();
      final openReports = await _forumService.getOpenReportCount();
      final reports = _mode == _AdminForumMode.reports
          ? await _forumService.getReports(
              status: _reportStatus == 'all' ? null : _reportStatus,
            )
          : _reports;

      if (!mounted) return;
      _catalog = catalog;
      _reports = reports;
      _statOpenReports = openReports;
      _error = null;
      _loading = false;
      _hasLoaded = true;
      if (_selectedTopicId != null &&
          !catalog.any((t) => t.id == _selectedTopicId)) {
        _selectedTopicId = null;
      }
      _applyTopicFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasLoaded = true;
        _error = '$e';
      });
    } finally {
      _refreshInFlight = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        if (mounted) unawaited(_refresh(silent: true));
      }
    }
  }

  Future<void> _loadReportsOnly({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _forumService.getReports(
          status: _reportStatus == 'all' ? null : _reportStatus,
        ),
        _forumService.getOpenReportCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<ForumReport>;
        _statOpenReports = results[1] as int;
        _loading = false;
        _hasLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasLoaded = true;
        _error = '$e';
      });
    }
  }

  void _applyTopicFilters() {
    final programs =
        _catalog
            .map((t) => t.authorProgram.trim())
            .where((p) => p.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final safeProgram =
        _programFilter != null && programs.contains(_programFilter)
            ? _programFilter
            : null;

    final page = _forumService.applyTopicQuery(
      _catalog,
      ForumTopicQuery(
        search: _search,
        filters: Set.of(_filters),
        sort: _sort,
        page: 0,
        pageSize: 200,
        programEquals: safeProgram,
      ),
    );

    if (!mounted) return;
    setState(() {
      _allPrograms = programs;
      _programFilter = safeProgram;
      _topics = page.topics;
      _statTotal = _catalog.length;
      _statUnanswered = _catalog.where((t) => t.needsResponse).length;
      _statLocked = _catalog.where((t) => t.isLocked).length;
    });
  }

  bool get _hasActiveFilters {
    final notAll =
        !(_filters.length == 1 && _filters.contains(ForumListFilter.all));
    return _search.isNotEmpty ||
        notAll ||
        _lockedOnly ||
        (_programFilter != null && _programFilter!.isNotEmpty) ||
        _sort != ForumSort.latestActivity;
  }

  bool get _hasActiveReportFilters =>
      _reportStatus != 'open' || _search.isNotEmpty;

  void _resetFilters() {
    setState(() {
      _search = '';
      _searchController.clear();
      _filters
        ..clear()
        ..add(ForumListFilter.all);
      _programFilter = null;
      _lockedOnly = false;
      _sort = ForumSort.latestActivity;
    });
    _applyTopicFilters();
  }

  void _resetReportFilters() {
    _searchController.clear();
    setState(() {
      _reportStatus = 'open';
      _search = '';
    });
    _loadReportsOnly();
  }

  void _toggleFilter(ForumListFilter filter) {
    setState(() {
      if (filter == ForumListFilter.all) {
        _filters
          ..clear()
          ..add(ForumListFilter.all);
      } else {
        _filters.remove(ForumListFilter.all);
        if (_filters.contains(filter)) {
          _filters.remove(filter);
        } else {
          _filters.add(filter);
        }
        if (_filters.isEmpty) _filters.add(ForumListFilter.all);
      }
    });
    _applyTopicFilters();
  }

  void _openTopic(String topicId) {
    setState(() => _selectedTopicId = topicId);
  }

  void _closeTopic() {
    setState(() => _selectedTopicId = null);
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

  List<PopupMenuEntry<String>> _topicMenuItems(ForumTopic topic) {
    return [
      adminForumMenuItem(
        value: 'view',
        label: 'Open discussion',
        icon: Icons.open_in_new_rounded,
      ),
      adminForumMenuItem(
        value: 'share',
        label: 'Share link…',
        icon: Icons.share_outlined,
      ),
      adminForumMenuItem(
        value: 'copy',
        label: 'Copy link',
        icon: Icons.link_rounded,
      ),
      const PopupMenuDivider(height: 8),
      adminForumMenuItem(
        value: 'lock',
        label: topic.isLocked ? 'Unlock topic' : 'Lock topic',
        icon: topic.isLocked ? Icons.lock_open_outlined : Icons.lock_outlined,
      ),
      adminForumMenuItem(
        value: 'pin',
        label: topic.isPinned ? 'Unpin' : 'Pin to top',
        icon: Icons.push_pin_outlined,
      ),
      if (!topic.isAnnouncement)
        adminForumMenuItem(
          value: 'solved',
          label: topic.isSolved ? 'Mark unsolved' : 'Mark solved',
          icon: Icons.check_circle_outline,
        ),
      const PopupMenuDivider(height: 8),
      adminForumMenuItem(
        value: 'delete',
        label: 'Delete topic',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    ];
  }

  Future<void> _handleTopicAction(ForumTopic topic, String value) async {
    if (value == 'view') {
      _openTopic(topic.id);
      return;
    }
    if (value == 'share') {
      await showShareLinkSheet(
        context,
        ShareableContent.fromTopic(topic),
      );
      return;
    }
    if (value == 'copy') {
      await copyForumTopicLink(context, topic.id);
      return;
    }

    if (_busyTopicIds.contains(topic.id)) return;

    if (value == 'lock') {
      final reason = topic.isLocked
          ? ''
          : await showForumModerationReasonDialog(
              context,
              title: 'Lock topic',
              confirmLabel: 'Lock',
            );
      if (!mounted) return;
      if (!topic.isLocked && reason == null) return;

      setState(() => _busyTopicIds.add(topic.id));
      try {
        await _forumService.setTopicLocked(
          topic.id,
          !topic.isLocked,
          reason: topic.isLocked ? null : reason,
        );
        _showSnack(topic.isLocked ? 'Topic unlocked' : 'Topic locked');
        await _refresh(silent: true);
      } catch (e) {
        _showSnack(
          forumFriendlyError(e, 'Could not update topic lock state.'),
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _busyTopicIds.remove(topic.id));
      }
      return;
    }

    if (value == 'pin') {
      setState(() => _busyTopicIds.add(topic.id));
      try {
        await _forumService.setTopicPinned(topic.id, !topic.isPinned);
        _showSnack(topic.isPinned ? 'Topic unpinned' : 'Topic pinned');
        await _refresh(silent: true);
      } catch (e) {
        _showSnack(
          forumFriendlyError(e, 'Could not update pin status.'),
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _busyTopicIds.remove(topic.id));
      }
      return;
    }

    if (value == 'solved') {
      if (topic.isAnnouncement) return;
      setState(() => _busyTopicIds.add(topic.id));
      try {
        await _forumService.setTopicSolved(topic.id, !topic.isSolved);
        _showSnack(
          topic.isSolved ? 'Marked as unsolved' : 'Marked as solved',
        );
        await _refresh(silent: true);
      } catch (e) {
        _showSnack(
          forumFriendlyError(e, 'Could not update solved status.'),
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _busyTopicIds.remove(topic.id));
      }
      return;
    }

    if (value == 'delete') {
      final reason = await showForumModerationReasonDialog(
        context,
        title: 'Delete topic?',
        confirmLabel: 'Continue',
      );
      if (reason == null || !mounted) return;
      final label = topic.title.trim().isEmpty
          ? 'this topic'
          : '“${topic.title.trim()}”';
      final ok = await showAdminConfirmDialog(
        context,
        title: 'Delete topic?',
        message: 'Permanently delete $label and all its replies? '
            'This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
        icon: Icons.delete_outline_rounded,
      );
      if (!ok || !mounted) return;

      setState(() => _busyTopicIds.add(topic.id));
      try {
        await _forumService.deleteTopic(topic.id, reason: reason);
        _showSnack('Topic deleted');
        await _refresh(silent: true);
      } catch (e) {
        _showSnack(
          forumFriendlyError(e, 'Could not delete this topic.'),
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _busyTopicIds.remove(topic.id));
      }
    }
  }

  Future<void> _handleReportStatus(ForumReport report, String status) async {
    if (_busyReportIds.contains(report.id)) return;
    setState(() => _busyReportIds.add(report.id));
    try {
      await _forumService.updateReportStatus(report.id, status);
      _showSnack(
        status == 'resolved' ? 'Report resolved' : 'Report reopened',
      );
      await _loadReportsOnly(silent: true);
    } catch (e) {
      _showSnack(
        forumFriendlyError(e, 'Could not update report status.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyReportIds.remove(report.id));
    }
  }

  String _buildCsvContent(List<ForumTopic> items) {
    final buf = StringBuffer();
    buf.writeln(
      'Title,Author,Program,Batch,Replies,Pinned,Locked,Solved,Announcement,Tags,Created',
    );
    for (final t in items) {
      const esc = CsvSafe.cell;
      buf.writeln(
        [
          esc(t.title),
          esc(t.authorName),
          esc(t.authorProgram),
          esc(t.authorBatch),
          t.replyCount,
          t.isPinned ? 'Yes' : 'No',
          t.isLocked ? 'Yes' : 'No',
          t.isSolved ? 'Yes' : 'No',
          t.isAnnouncement ? 'Yes' : 'No',
          esc(t.tags.map((e) => e.label).join('; ')),
          DateFormat('yyyy-MM-dd').format(t.createdAt),
        ].join(','),
      );
    }
    return buf.toString();
  }

  Future<void> _exportCsv() async {
    final items = _visibleTopics;
    final csv = _buildCsvContent(items);
    if (!mounted) return;
    await showAdminDialogSurface<void>(
      context: context,
      maxWidth: 580,
      child: _ForumCsvExportDialog(
        csvContent: csv,
        topicCount: items.length,
      ),
    );
  }

  Future<void> _newAnnouncement() async {
    final id = await showAdminForumComposer(
      context: context,
      initialAsAnnouncement: true,
    );
    if (id != null) {
      await _refresh();
      if (mounted) _openTopic(id);
    }
  }

  List<ForumTopic> get _visibleTopics {
    if (!_lockedOnly) return _topics;
    return _topics.where((t) => t.isLocked).toList();
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    if (_search.isNotEmpty) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Search: $_search',
          onRemoved: () {
            _searchController.clear();
            setState(() => _search = '');
            _applyTopicFilters();
          },
        ),
      );
    }
    for (final f in _filters) {
      if (f == ForumListFilter.all) continue;
      chips.add(
        DirectoryActiveFilterChip(
          label: f.label,
          onRemoved: () => _toggleFilter(f),
        ),
      );
    }
    if (_programFilter != null && _programFilter!.isNotEmpty) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Program: $_programFilter',
          onRemoved: () {
            setState(() => _programFilter = null);
            _applyTopicFilters();
          },
        ),
      );
    }
    if (_lockedOnly) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Locked',
          onRemoved: () {
            setState(() => _lockedOnly = false);
            _applyTopicFilters();
          },
        ),
      );
    }
    if (_sort != ForumSort.latestActivity) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Sort: ${_sort.label}',
          onRemoved: () {
            setState(() => _sort = ForumSort.latestActivity);
            _applyTopicFilters();
          },
        ),
      );
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Directory / Surveys pattern: replace the list workspace entirely with
    // the discussion (full available area), not a side-by-side panel.
    if (_selectedTopicId != null) {
      return ForumTopicScreen(
        key: ValueKey(_selectedTopicId),
        topicId: _selectedTopicId!,
        embedded: true,
        service: _forumService,
        onClose: _closeTopic,
        onChanged: () => _refresh(silent: true),
      );
    }

    final hasDataInActiveTab = _mode == _AdminForumMode.discussions
        ? _catalog.isNotEmpty
        : _reports.isNotEmpty;

    final refreshButton = OutlinedButton.icon(
      onPressed: _loading
          ? null
          : () => _mode == _AdminForumMode.discussions
              ? _refresh()
              : _loadReportsOnly(),
      icon: _loading && _hasLoaded
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 15),
      label: Text(_loading && _hasLoaded ? 'Refreshing…' : 'Refresh'),
      style: AdminButtonStyles.outlined(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCompactHeader(
          title: 'Forum Moderation',
          actions: _mode == _AdminForumMode.discussions
              ? [
                  refreshButton,
                  OutlinedButton.icon(
                    onPressed:
                        _visibleTopics.isEmpty || _loading ? null : _exportCsv,
                    icon: const Icon(Icons.download_outlined, size: 17),
                    label: const Text('Export'),
                    style: AdminButtonStyles.outlined(),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _newAnnouncement,
                    icon: const Icon(Icons.campaign_outlined, size: 17),
                    label: const Text('New announcement'),
                    style: AdminButtonStyles.filled(),
                  ),
                ]
              : [refreshButton],
        ),
        const SizedBox(height: AdminDensity.space2),
        Align(
          alignment: Alignment.centerLeft,
          child: AdminSaaSTabs(
            tabs: [
              AdminSaaSTabSpec(
                label: 'Discussions',
                icon: Icons.forum_outlined,
                isSelected: _mode == _AdminForumMode.discussions,
                onTap: () {
                  if (_mode == _AdminForumMode.discussions) return;
                  setState(() {
                    _mode = _AdminForumMode.discussions;
                    _search = '';
                    _searchController.clear();
                    _error = null;
                  });
                  if (_catalog.isEmpty) {
                    _refresh();
                  } else {
                    _applyTopicFilters();
                  }
                },
              ),
              AdminSaaSTabSpec(
                label: 'Reports',
                icon: Icons.flag_outlined,
                count: _statOpenReports > 0 ? _statOpenReports : null,
                isSelected: _mode == _AdminForumMode.reports,
                onTap: () {
                  if (_mode == _AdminForumMode.reports) return;
                  setState(() {
                    _mode = _AdminForumMode.reports;
                    _search = '';
                    _searchController.clear();
                    _error = null;
                  });
                  _loadReportsOnly();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AdminDensity.space2),
        _buildMetrics(),
        const SizedBox(height: AdminDensity.space2),
        if (_mode == _AdminForumMode.discussions) ...[
          _buildToolbar(),
          if (_error != null && hasDataInActiveTab) ...[
            const SizedBox(height: AdminDensity.space1),
            _buildRefreshErrorNotice(() => _refresh()),
          ],
          const SizedBox(height: AdminDensity.space1),
          Expanded(child: _buildListPane()),
        ] else ...[
          _buildReportsToolbar(),
          if (_error != null && hasDataInActiveTab) ...[
            const SizedBox(height: AdminDensity.space1),
            _buildRefreshErrorNotice(() => _loadReportsOnly()),
          ],
          const SizedBox(height: AdminDensity.space1),
          Expanded(child: _buildReportsPane()),
        ],
      ],
    );
  }

  Widget _buildRefreshErrorNotice(VoidCallback onRetry) {
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
              "Couldn't refresh forum data. Showing the last loaded list.",
              style: TextStyle(fontSize: 13, color: AdminColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    if (_mode == _AdminForumMode.reports) {
      final open = _reports.where((r) => r.isOpen).length;
      final resolved = _reports.where((r) => !r.isOpen).length;
      return AdminMetricRibbon(
        items: [
          AdminMetricRibbonItem(
            label: 'Open reports',
            value: '$_statOpenReports',
            icon: Icons.flag_outlined,
            color: AdminColors.warning,
            isSelected: _reportStatus == 'open',
            tooltip: 'Open alumni flags — click to view open reports',
            onTap: () {
              setState(() => _reportStatus = 'open');
              _loadReportsOnly();
            },
          ),
          AdminMetricRibbonItem(
            label: 'Showing',
            value: '${_reports.length}',
            icon: Icons.inbox_outlined,
            color: AdminColors.primary,
            isSelected: _reportStatus == 'all',
            tooltip: 'All loaded reports — click to view all statuses',
            onTap: () {
              setState(() => _reportStatus = 'all');
              _loadReportsOnly();
            },
          ),
          AdminMetricRibbonItem(
            label: 'Open in list',
            value: '$open',
            icon: Icons.mark_email_unread_outlined,
            color: AdminColors.warning,
            tooltip: 'Open reports in the active filter',
          ),
          AdminMetricRibbonItem(
            label: 'Resolved in list',
            value: '$resolved',
            icon: Icons.check_circle_outline,
            color: AdminColors.success,
            isSelected: _reportStatus == 'resolved',
            tooltip: 'Resolved reports — click to view resolved items',
            onTap: () {
              setState(() => _reportStatus = 'resolved');
              _loadReportsOnly();
            },
          ),
        ],
      );
    }

    return AdminMetricRibbon(
      items: [
        AdminMetricRibbonItem(
          label: 'Topics',
          value: '$_statTotal',
          icon: Icons.forum_outlined,
          color: AdminColors.primary,
          isSelected: !_hasActiveFilters,
          tooltip: 'All discussions — click to clear filters',
          onTap: _resetFilters,
        ),
        AdminMetricRibbonItem(
          label: 'Needs response',
          value: '$_statUnanswered',
          icon: Icons.mark_chat_unread_outlined,
          color: AdminColors.warning,
          isSelected: _filters.contains(ForumListFilter.unanswered),
          tooltip: 'Unanswered topics with zero replies — click to filter',
          onTap: () {
            final alreadyOnly =
                _filters.contains(ForumListFilter.unanswered) && !_lockedOnly;
            setState(() {
              _filters.clear();
              if (alreadyOnly) {
                _filters.add(ForumListFilter.all);
              } else {
                _filters.add(ForumListFilter.unanswered);
              }
              _lockedOnly = false;
            });
            _applyTopicFilters();
          },
        ),
        AdminMetricRibbonItem(
          label: 'Locked',
          value: '$_statLocked',
          icon: Icons.lock_outline,
          color: AdminColors.textSecondary,
          isSelected: _lockedOnly,
          tooltip: 'Topics closed for replies — click to filter',
          onTap: () {
            setState(() {
              _filters
                ..clear()
                ..add(ForumListFilter.all);
              _lockedOnly = !_lockedOnly;
            });
            _applyTopicFilters();
          },
        ),
        AdminMetricRibbonItem(
          label: 'Open reports',
          value: '$_statOpenReports',
          icon: Icons.flag_outlined,
          color: _statOpenReports > 0
              ? AdminColors.danger
              : AdminColors.textSecondary,
          tooltip: 'Flagged topics and replies — click to open Reports tab',
          onTap: () {
            setState(() {
              _mode = _AdminForumMode.reports;
              _reportStatus = 'open';
              _search = '';
              _searchController.clear();
              _error = null;
            });
            _loadReportsOnly();
          },
        ),
      ],
    );
  }

  Widget _buildReportsToolbar() {
    return AdminSaaSToolbar(
      searchController: _searchController,
      onSearchChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 220), () {
          if (mounted) setState(() => _search = v.trim());
        });
      },
      onClearSearch: () {
        _searchController.clear();
        setState(() => _search = '');
      },
      hasActiveFilters: _hasActiveReportFilters,
      onResetFilters: _resetReportFilters,
      activeFilterChips: [
        if (_search.isNotEmpty)
          DirectoryActiveFilterChip(
            label: 'Search: $_search',
            onRemoved: () {
              _searchController.clear();
              setState(() => _search = '');
            },
          ),
        if (_reportStatus != 'open')
          DirectoryActiveFilterChip(
            label: _reportStatus == 'all' ? 'All statuses' : 'Resolved',
            onRemoved: () {
              setState(() => _reportStatus = 'open');
              _loadReportsOnly();
            },
          ),
      ],
      searchHint: 'Search report reason or topic title…',
      searchWidth: 260,
      filters: [
        ForumToolbarFilterChip(
          label: 'Open',
          selected: _reportStatus == 'open',
          onSelected: (_) {
            setState(() => _reportStatus = 'open');
            _loadReportsOnly();
          },
        ),
        ForumToolbarFilterChip(
          label: 'Resolved',
          selected: _reportStatus == 'resolved',
          onSelected: (_) {
            setState(() => _reportStatus = 'resolved');
            _loadReportsOnly();
          },
        ),
        ForumToolbarFilterChip(
          label: 'All',
          selected: _reportStatus == 'all',
          onSelected: (_) {
            setState(() => _reportStatus = 'all');
            _loadReportsOnly();
          },
        ),
      ],
    );
  }

  List<ForumReport> get _visibleReports {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _reports;
    return _reports.where((r) {
      final title = (r.topicTitle ?? '').toLowerCase();
      final reason = r.reason.toLowerCase();
      return title.contains(q) || reason.contains(q);
    }).toList();
  }

  Widget _buildReportsPane() {
    final visible = _visibleReports;
    if (_loading && _reports.isEmpty) {
      return const AdminForumListSkeleton();
    }
    if (_error != null && _reports.isEmpty) {
      return AdminStateView.error(
        title: "Couldn't load forum reports",
        message: forumFriendlyError(
          _error!,
          'Check your connection and try again.',
        ),
        details: _error,
        onRetry: () => _loadReportsOnly(),
      );
    }
    if (visible.isEmpty) {
      return AdminStateView.empty(
        icon: Icons.flag_outlined,
        title: _reports.isEmpty && _reportStatus == 'open'
            ? 'No open reports'
            : 'No matching reports',
        message: _reports.isEmpty && _reportStatus == 'open'
            ? 'Alumni reports will appear here for moderation review.'
            : 'Try clearing filters or switching report status.',
        primaryAction: _hasActiveReportFilters
            ? AdminStateAction(
                label: 'Reset filters',
                icon: Icons.filter_alt_off_outlined,
                onPressed: _resetReportFilters,
              )
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReportsOnly(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AdminDensity.space3),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final r = visible[index];
          return AdminForumReportCard(
            report: r,
            busy: _busyReportIds.contains(r.id),
            onOpenTopic: r.topicId == null
                ? null
                : () => _openTopic(r.topicId!),
            onResolve: r.isOpen
                ? () => _handleReportStatus(r, 'resolved')
                : null,
            onReopen: !r.isOpen
                ? () => _handleReportStatus(r, 'open')
                : null,
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    return AdminSaaSToolbar(
      searchController: _searchController,
      onSearchChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 220), () {
          if (!mounted) return;
          setState(() => _search = v.trim());
          _applyTopicFilters();
        });
      },
      onClearSearch: () {
        _searchController.clear();
        setState(() => _search = '');
        _applyTopicFilters();
      },
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      searchHint: 'Search title, author, program, or tags…',
      searchWidth: 250,
      filters: [
        ForumToolbarFilterChip(
          label: 'Pinned',
          selected: _filters.contains(ForumListFilter.pinned),
          onSelected: (_) => _toggleFilter(ForumListFilter.pinned),
        ),
        ForumToolbarFilterChip(
          label: 'Solved',
          selected: _filters.contains(ForumListFilter.solved),
          onSelected: (_) => _toggleFilter(ForumListFilter.solved),
        ),
        ForumToolbarFilterChip(
          label: 'Unanswered',
          selected: _filters.contains(ForumListFilter.unanswered),
          onSelected: (_) => _toggleFilter(ForumListFilter.unanswered),
        ),
        ForumToolbarFilterChip(
          label: 'Announcements',
          selected: _filters.contains(ForumListFilter.announcements),
          onSelected: (_) => _toggleFilter(ForumListFilter.announcements),
        ),
        ForumToolbarFilterChip(
          label: 'Locked',
          selected: _lockedOnly,
          onSelected: (v) {
            setState(() => _lockedOnly = v);
            _applyTopicFilters();
          },
        ),
        DirectoryFilterField<String?>(
          label: 'Program',
          width: 136,
          dense: true,
          value: _programFilter,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All programs'),
            ),
            ..._allPrograms.map(
              (p) => DropdownMenuItem(
                value: p,
                child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _programFilter = v);
            _applyTopicFilters();
          },
        ),
      ],
      sortControl: DirectoryFilterField<ForumSort>(
        label: 'Sort',
        width: 146,
        dense: true,
        value: _sort,
        items: ForumSort.values
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() => _sort = v);
          _applyTopicFilters();
        },
      ),
    );
  }

  Widget _buildListPane() {
    final visible = _visibleTopics;
    final emptyCatalog = _statTotal == 0 && !_loading && _error == null;

    if (_loading && visible.isEmpty) {
      return const AdminForumListSkeleton();
    }
    if (_error != null && visible.isEmpty) {
      return AdminStateView.error(
        title: "Couldn't load forum discussions",
        message: forumFriendlyError(
          _error!,
          'Check your connection and try again.',
        ),
        details: _error,
        onRetry: () => _refresh(),
      );
    }
    if (visible.isEmpty) {
      return AdminStateView.empty(
        icon: emptyCatalog ? Icons.forum_outlined : Icons.search_off_rounded,
        title: emptyCatalog ? 'No forum topics yet' : 'No matching discussions',
        message: emptyCatalog
            ? 'Create an announcement or wait for alumni discussions.'
            : 'Try clearing filters or searching with another keyword.',
        primaryAction: AdminStateAction(
          label: emptyCatalog ? 'New announcement' : 'Clear filters',
          icon: emptyCatalog
              ? Icons.campaign_outlined
              : Icons.filter_alt_off_outlined,
          onPressed: emptyCatalog ? _newAnnouncement : _resetFilters,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AdminDensity.space3),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final t = visible[index];
          return AdminForumTopicCard(
            topic: t,
            selected: t.id == _selectedTopicId,
            busy: _busyTopicIds.contains(t.id),
            menuItems: _topicMenuItems(t),
            onMenuSelected: (v) => _handleTopicAction(t, v),
            onOpen: () => _openTopic(t.id),
          );
        },
      ),
    );
  }
}

class _ForumCsvExportDialog extends StatelessWidget {
  const _ForumCsvExportDialog({
    required this.csvContent,
    required this.topicCount,
  });

  final String csvContent;
  final int topicCount;

  @override
  Widget build(BuildContext context) {
    final canDownload = isWebFileDownloadSupported;
    return Padding(
      padding: AdminDialogStandards.defaultContentPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminModalHeader(
            title: 'Export discussions CSV',
            subtitle:
                '$topicCount ${topicCount == 1 ? 'discussion' : 'discussions'} in the current view.',
            icon: Icons.download_outlined,
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                border: Border.all(color: AdminColors.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  csvContent,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: AdminButtonStyles.outlined(),
                child: const Text('Close'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: csvContent));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV copied to clipboard')),
                  );
                },
                style: canDownload
                    ? AdminButtonStyles.outlined()
                    : AdminButtonStyles.filled(),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copy CSV'),
              ),
              if (canDownload)
                FilledButton.icon(
                  onPressed: () {
                    final stamp = DateFormat('yyyyMMdd_HHmm').format(
                      DateTime.now(),
                    );
                    downloadTextOnWeb(
                      content: csvContent,
                      fileName: 'forum_discussions_$stamp.csv',
                      mimeType: 'text/csv;charset=utf-8',
                    );
                  },
                  style: AdminButtonStyles.filled(),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Download .csv'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
