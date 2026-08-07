import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/models/forum_filters.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/presentation/forum_topic_page.dart';
import 'package:alumni_system/features/forum/presentation/forum_composer_page.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/features/admin/forum/widgets/admin_forum_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';

/// Admin forum moderation — matches Surveys / Events / Announcements chrome.
class AdminForumScreen extends StatefulWidget {
  const AdminForumScreen({super.key});

  @override
  State<AdminForumScreen> createState() => _AdminForumScreenState();
}

enum _AdminForumMode { discussions, reports }

class _AdminForumScreenState extends State<AdminForumScreen> {
  final ForumService _forumService = ForumService();
  final _searchController = TextEditingController();

  StreamSubscription<void>? _refreshSub;
  List<ForumTopic> _topics = [];
  List<ForumReport> _reports = [];
  bool _loading = true;
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
      final programs = catalog
          .map((t) => t.authorProgram.trim())
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final page = _forumService.applyTopicQuery(
        catalog,
        ForumTopicQuery(
          search: _search,
          filters: Set.of(_filters),
          sort: _sort,
          page: 0,
          pageSize: 200,
          programEquals: _programFilter,
        ),
      );

      final openReports = await _forumService.getOpenReportCount();
      final reports = _mode == _AdminForumMode.reports
          ? await _forumService.getReports(
              status: _reportStatus == 'all' ? null : _reportStatus,
            )
          : _reports;

      if (!mounted) return;
      setState(() {
        _topics = page.topics;
        _reports = reports;
        _allPrograms = programs;
        _statTotal = catalog.length;
        _statUnanswered = catalog.where((t) => t.needsResponse).length;
        _statLocked = catalog.where((t) => t.isLocked).length;
        _statOpenReports = openReports;
        _loading = false;
        _error = null;
        if (_selectedTopicId != null &&
            !catalog.any((t) => t.id == _selectedTopicId)) {
          _selectedTopicId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
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

  bool get _hasActiveFilters {
    final notAll = !(_filters.length == 1 &&
        _filters.contains(ForumListFilter.all));
    return _search.isNotEmpty ||
        notAll ||
        _lockedOnly ||
        (_programFilter != null && _programFilter!.isNotEmpty);
  }

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
    _refresh();
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
    _refresh();
  }

  void _openTopic(String topicId) {
    setState(() => _selectedTopicId = topicId);
  }

  void _closeTopic() {
    setState(() => _selectedTopicId = null);
  }

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln(
      'Title,Author,Program,Batch,Replies,Pinned,Locked,Solved,Announcement,Tags,Created',
    );
    for (final t in _topics) {
      String esc(String v) => '"${v.replaceAll('"', '""')}"';
      buf.writeln([
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
      ].join(','));
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export CSV'),
        content: SizedBox(
          width: 520,
          child: SelectableText(
            buf.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
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
            _refresh();
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
            _refresh();
          },
        ),
      );
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pageInsets = AdminDensity.pageInsetsForWidth(width);

    // Directory / Surveys pattern: replace the list workspace entirely with
    // the discussion (full available area), not a side-by-side panel.
    if (_selectedTopicId != null) {
      return ColoredBox(
        color: AdminForumTheme.background,
        child: Padding(
          padding: pageInsets.copyWith(bottom: 0),
          child: ForumTopicScreen(
            key: ValueKey(_selectedTopicId),
            topicId: _selectedTopicId!,
            embedded: true,
            onClose: _closeTopic,
            onChanged: () => _refresh(silent: true),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AdminForumTheme.background,
      child: Padding(
        padding: pageInsets.copyWith(bottom: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ForumPageHeader(
              title: 'Forum Moderation',
              subtitle: _mode == _AdminForumMode.reports
                  ? 'Review alumni reports on discussions and replies.'
                  : 'Moderate alumni discussions and announcements.',
              actions: [
                _buildModeToggle(),
                if (_mode == _AdminForumMode.discussions) ...[
                  OutlinedButton.icon(
                    onPressed: _topics.isEmpty || _loading ? null : _exportCsv,
                    icon: const Icon(Icons.download_outlined, size: 17),
                    label: const Text('Export'),
                    style: forumOutlinedButtonStyle(),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _newAnnouncement,
                    icon: const Icon(Icons.campaign_outlined, size: 17),
                    label: const Text('New announcement'),
                    style: forumFilledButtonStyle(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AdminForumTheme.space2),
            _buildMetrics(),
            const SizedBox(height: AdminForumTheme.space2),
            if (_mode == _AdminForumMode.discussions) ...[
              _buildToolbar(),
              const SizedBox(height: AdminForumTheme.space1),
              Expanded(child: _buildListPane()),
            ] else ...[
              _buildReportsToolbar(),
              const SizedBox(height: AdminForumTheme.space1),
              Expanded(child: _buildReportsPane()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return SizedBox(
      height: AdminForumTheme.buttonHeight,
      child: SegmentedButton<_AdminForumMode>(
        segments: [
          const ButtonSegment(
            value: _AdminForumMode.discussions,
            label: Text('Discussions'),
            icon: Icon(Icons.forum_outlined, size: 16),
          ),
          ButtonSegment(
            value: _AdminForumMode.reports,
            label: Text(
              _statOpenReports > 0
                  ? 'Reports ($_statOpenReports)'
                  : 'Reports',
            ),
            icon: const Icon(Icons.flag_outlined, size: 16),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (s) {
          setState(() {
            _mode = s.first;
            _search = '';
            _searchController.clear();
          });
          _refresh();
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          fixedSize: WidgetStateProperty.all(
            const Size.fromHeight(AdminForumTheme.buttonHeight),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AdminForumTheme.infoBg;
            }
            return Colors.white;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AdminForumTheme.border),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminForumTheme.radiusSm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics() {
    if (_mode == _AdminForumMode.reports) {
      final open = _reports.where((r) => r.isOpen).length;
      final resolved = _reports.where((r) => !r.isOpen).length;
      return DirectoryStatsGrid(
        children: [
          DirectoryStatCard(
            label: 'Open reports',
            value: '$_statOpenReports',
            description: 'Needs review',
            icon: Icons.flag_outlined,
            accent: AdminForumTheme.warning,
            onTap: () {
              setState(() => _reportStatus = 'open');
              _refresh();
            },
          ),
          DirectoryStatCard(
            label: 'Showing',
            value: '${_reports.length}',
            description: _reportStatus == 'all'
                ? 'All statuses'
                : (_reportStatus == 'open' ? 'Open only' : 'Resolved only'),
            icon: Icons.inbox_outlined,
            accent: AdminForumTheme.navy,
          ),
          DirectoryStatCard(
            label: 'Open in list',
            value: '$open',
            description: 'Current filter',
            icon: Icons.mark_email_unread_outlined,
            accent: AdminForumTheme.warning,
          ),
          DirectoryStatCard(
            label: 'Resolved in list',
            value: '$resolved',
            description: 'Current filter',
            icon: Icons.check_circle_outline,
            accent: ForumTheme.solved,
          ),
        ],
      );
    }

    return DirectoryStatsGrid(
      children: [
        DirectoryStatCard(
          label: 'Topics',
          value: '$_statTotal',
          description: 'All discussions',
          icon: Icons.forum_outlined,
          accent: AdminForumTheme.navy,
          onTap: _resetFilters,
        ),
        DirectoryStatCard(
          label: 'Needs response',
          value: '$_statUnanswered',
          description: 'Zero replies',
          icon: Icons.mark_chat_unread_outlined,
          accent: AdminForumTheme.warning,
          onTap: () {
            setState(() {
              _filters
                ..clear()
                ..add(ForumListFilter.unanswered);
              _lockedOnly = false;
            });
            _refresh();
          },
        ),
        DirectoryStatCard(
          label: 'Locked',
          value: '$_statLocked',
          description: 'Closed for replies',
          icon: Icons.lock_outline,
          accent: AdminForumTheme.textSecondary,
          onTap: () {
            setState(() {
              _filters
                ..clear()
                ..add(ForumListFilter.all);
              _lockedOnly = true;
            });
            _refresh();
          },
        ),
        DirectoryStatCard(
          label: 'Open reports',
          value: '$_statOpenReports',
          description: 'Alumni flags',
          icon: Icons.flag_outlined,
          accent: AdminForumTheme.warning,
          onTap: () {
            setState(() {
              _mode = _AdminForumMode.reports;
              _reportStatus = 'open';
            });
            _refresh();
          },
        ),
      ],
    );
  }

  Widget _buildReportsToolbar() {
    return DirectoryToolbarCard(
      searchController: _searchController,
      onSearchChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 280), () {
          setState(() => _search = v.trim());
        });
      },
      onClearSearch: () {
        _searchController.clear();
        setState(() => _search = '');
      },
      isLoading: _loading,
      onRefresh: () => _refresh(),
      hasActiveFilters: _reportStatus != 'open' || _search.isNotEmpty,
      onResetFilters: () {
        _searchController.clear();
        setState(() {
          _reportStatus = 'open';
          _search = '';
        });
        _refresh();
      },
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
              _refresh();
            },
          ),
      ],
      searchHint: 'Search report reason or topic title…',
      filters: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ForumToolbarFilterChip(
            label: 'Open',
            selected: _reportStatus == 'open',
            onSelected: (_) {
              setState(() => _reportStatus = 'open');
              _refresh();
            },
          ),
          ForumToolbarFilterChip(
            label: 'Resolved',
            selected: _reportStatus == 'resolved',
            onSelected: (_) {
              setState(() => _reportStatus = 'resolved');
              _refresh();
            },
          ),
          ForumToolbarFilterChip(
            label: 'All',
            selected: _reportStatus == 'all',
            onSelected: (_) {
              setState(() => _reportStatus = 'all');
              _refresh();
            },
          ),
        ],
      ),
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
    return AdminInstantContent(
      loading: _loading && _reports.isEmpty,
      loadingSkeleton: const PortalCardListSkeleton(),
      isEmpty: visible.isEmpty && !_loading,
      empty: _error != null
          ? ForumErrorState(
              message: _error!,
              onRetry: () => _refresh(),
            )
          : DirectoryEmptyState(
              title: _reports.isEmpty && _reportStatus == 'open'
                  ? 'No open reports'
                  : 'No reports in this filter',
              subtitle: _reports.isEmpty && _reportStatus == 'open'
                  ? 'Alumni reports will appear here for review.'
                  : 'Try a different search or status.',
              icon: Icons.flag_outlined,
            ),
      child: RefreshIndicator(
        onRefresh: () => _refresh(),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: AdminDensity.space3),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final r = visible[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
              child: _AdminReportRow(
                report: r,
                onOpenTopic: r.topicId == null
                    ? null
                    : () => _openTopic(r.topicId!),
                onResolve: r.isOpen
                    ? () async {
                        await _forumService.updateReportStatus(
                          r.id,
                          'resolved',
                        );
                        await _refresh(silent: true);
                      }
                    : null,
                onReopen: !r.isOpen
                    ? () async {
                        await _forumService.updateReportStatus(r.id, 'open');
                        await _refresh(silent: true);
                      }
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return DirectoryToolbarCard(
      searchController: _searchController,
      onSearchChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 280), () {
          setState(() => _search = v.trim());
          _refresh();
        });
      },
      onClearSearch: () {
        _searchController.clear();
        setState(() => _search = '');
        _refresh();
      },
      isLoading: _loading,
      onRefresh: () => _refresh(),
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      searchHint: 'Search title, author, program, or tags…',
      filters: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DirectoryFilterField<ForumSort>(
            label: 'Sort',
            width: 148,
            value: _sort,
            items: ForumSort.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _sort = v);
              _refresh();
            },
          ),
          DirectoryFilterField<String?>(
            label: 'Program',
            width: 148,
            value: _programFilter,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All programs'),
              ),
              ..._allPrograms.map(
                (p) => DropdownMenuItem(value: p, child: Text(p)),
              ),
            ],
            onChanged: (v) {
              setState(() => _programFilter = v);
              _refresh();
            },
          ),
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
              _refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListPane() {
    final visible = _visibleTopics;
    final emptyCatalog = _statTotal == 0 && !_loading && _error == null;

    return AdminInstantContent(
      loading: _loading && visible.isEmpty,
      loadingSkeleton: const PortalCardListSkeleton(),
      isEmpty: visible.isEmpty && !_loading,
      empty: _error != null
          ? ForumErrorState(
              message: _error!,
              onRetry: () => _refresh(),
            )
          : DirectoryEmptyState(
              title: emptyCatalog ? 'No forum topics yet' : 'No matches',
              subtitle: emptyCatalog
                  ? 'Create an announcement or wait for alumni discussions.'
                  : 'Try a different search or filter.',
              icon: Icons.forum_outlined,
              primaryAction: emptyCatalog ? _newAnnouncement : null,
              primaryLabel: 'New announcement',
            ),
      child: RefreshIndicator(
        onRefresh: () => _refresh(),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: AdminDensity.space3),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final t = visible[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
              child: _AdminTopicRow(
                topic: t,
                selected: t.id == _selectedTopicId,
                onOpen: () => _openTopic(t.id),
                onChanged: () => _refresh(silent: true),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminTopicRow extends StatelessWidget {
  const _AdminTopicRow({
    required this.topic,
    required this.selected,
    required this.onOpen,
    required this.onChanged,
  });

  final ForumTopic topic;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final forum = ForumService();
    final meta =
        '${topic.authorName} · ${topic.replyCount} replies · ${DateFormat.yMMMd().format(topic.createdAt)}'
        '${topic.authorProgram.isNotEmpty ? ' · ${topic.authorProgram}' : ''}'
        '${topic.authorBatch.isNotEmpty ? ' · Batch ${topic.authorBatch}' : ''}';

    return Material(
      color: selected ? AdminForumTheme.infoBg : AdminForumTheme.card,
      borderRadius: BorderRadius.circular(AdminForumTheme.radiusMd),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AdminForumTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminForumTheme.radiusMd),
            border: Border.all(
              color: selected
                  ? AdminForumTheme.navy.withValues(alpha: 0.35)
                  : AdminForumTheme.border,
            ),
            boxShadow: selected ? null : AdminDirectoryTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminDensity.cardPadding,
              10,
              4,
              10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: topic.isAnnouncement
                      ? ForumTheme.announcementBg
                      : AdminForumTheme.infoBg,
                  backgroundImage: () {
                    final url = topic.authorAvatarUrl?.trim() ?? '';
                    if (url.isEmpty) return null;
                    return AppImage.provider(url);
                  }(),
                  child: (topic.authorAvatarUrl?.trim().isNotEmpty ?? false)
                      ? null
                      : Text(
                          topic.authorName.isNotEmpty
                              ? topic.authorName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: topic.isAnnouncement
                                ? ForumTheme.announcement
                                : AdminForumTheme.navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AdminForumTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminForumTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ForumStatusChipRow(topic: topic),
                      if (topic.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: topic.tags
                              .take(3)
                              .map((tag) => ForumTagChip(label: tag.label))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (value) async {
                    switch (value) {
                      case 'view':
                        onOpen();
                      case 'copy':
                        await copyForumTopicLink(context, topic.id);
                      case 'lock':
                        final reason = topic.isLocked
                            ? ''
                            : await showForumModerationReasonDialog(
                                context,
                                title: topic.isLocked
                                    ? 'Unlock topic'
                                    : 'Lock topic',
                                confirmLabel:
                                    topic.isLocked ? 'Unlock' : 'Lock',
                              );
                        if (!topic.isLocked && reason == null) return;
                        await forum.setTopicLocked(
                          topic.id,
                          !topic.isLocked,
                          reason: topic.isLocked ? null : reason,
                        );
                        onChanged();
                      case 'pin':
                        await forum.setTopicPinned(
                          topic.id,
                          !topic.isPinned,
                        );
                        onChanged();
                      case 'solved':
                        if (topic.isAnnouncement) return;
                        await forum.setTopicSolved(
                          topic.id,
                          !topic.isSolved,
                        );
                        onChanged();
                      case 'delete':
                        final reason = await showForumModerationReasonDialog(
                          context,
                          title: 'Delete topic?',
                          confirmLabel: 'Continue',
                        );
                        if (reason == null) return;
                        if (!context.mounted) return;
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete topic?'),
                            content: const Text(
                              'This removes the topic and all replies.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await forum.deleteTopic(topic.id, reason: reason);
                          onChanged();
                        }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('Open discussion'),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Text('Copy link'),
                    ),
                    PopupMenuItem(
                      value: 'lock',
                      child: Text(topic.isLocked ? 'Unlock' : 'Lock'),
                    ),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(topic.isPinned ? 'Unpin' : 'Pin'),
                    ),
                    if (!topic.isAnnouncement)
                      PopupMenuItem(
                        value: 'solved',
                        child: Text(
                          topic.isSolved ? 'Mark unsolved' : 'Mark solved',
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminReportRow extends StatelessWidget {
  const _AdminReportRow({
    required this.report,
    this.onOpenTopic,
    this.onResolve,
    this.onReopen,
  });

  final ForumReport report;
  final VoidCallback? onOpenTopic;
  final VoidCallback? onResolve;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final title = (report.topicTitle?.trim().isNotEmpty == true)
        ? report.topicTitle!
        : (report.topicId ?? 'Unknown topic');
    final when = DateFormat.yMMMd().add_jm().format(report.createdAt);

    return Material(
      color: AdminForumTheme.card,
      borderRadius: BorderRadius.circular(AdminForumTheme.radiusMd),
      child: InkWell(
        onTap: onOpenTopic,
        borderRadius: BorderRadius.circular(AdminForumTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminForumTheme.radiusMd),
            border: Border.all(color: AdminForumTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: report.isOpen
                        ? AdminForumTheme.warning.withValues(alpha: 0.12)
                        : ForumTheme.solvedBg,
                    borderRadius:
                        BorderRadius.circular(AdminForumTheme.radiusSm),
                  ),
                  child: Icon(
                    report.isOpen
                        ? Icons.flag_outlined
                        : Icons.check_circle_outline,
                    size: 18,
                    color: report.isOpen
                        ? AdminForumTheme.warning
                        : ForumTheme.solved,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AdminForumTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AdminForumTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.isOpen ? 'Open' : 'Resolved'}'
                        '${report.postId != null ? ' · Reply report' : ' · Topic report'}'
                        ' · $when',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminForumTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onOpenTopic != null)
                  IconButton(
                    tooltip: 'Open discussion',
                    onPressed: onOpenTopic,
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                if (onResolve != null)
                  TextButton(
                    onPressed: onResolve,
                    child: const Text('Resolve'),
                  ),
                if (onReopen != null)
                  TextButton(
                    onPressed: onReopen,
                    child: const Text('Reopen'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
