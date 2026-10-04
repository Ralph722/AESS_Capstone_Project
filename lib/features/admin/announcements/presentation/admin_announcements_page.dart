import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/admin/announcements/presentation/admin_announcement_editor_page.dart';
import 'package:alumni_system/features/admin/announcements/widgets/admin_announcement_ui.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';

enum _AnnouncementStatusFilter { all, draft, published, archived }

enum _AnnouncementSort { newest, oldest, titleAsc, reachDesc }

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _service = AnnouncementService();
  final _searchController = TextEditingController();

  List<Announcement> _items = [];
  bool _isLoading = false;
  String _query = '';
  _AnnouncementStatusFilter _statusFilter = _AnnouncementStatusFilter.all;
  _AnnouncementSort _sort = _AnnouncementSort.newest;

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
    setState(() => _isLoading = true);
    try {
      final list = await _service.getAllAnnouncements();
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  List<Announcement> get _filtered {
    var list = _items.where((a) {
      switch (_statusFilter) {
        case _AnnouncementStatusFilter.all:
          if (a.status == AnnouncementStatus.archived) return false;
        case _AnnouncementStatusFilter.draft:
          if (a.status != AnnouncementStatus.draft) return false;
        case _AnnouncementStatusFilter.published:
          if (a.status != AnnouncementStatus.published) return false;
        case _AnnouncementStatusFilter.archived:
          if (a.status != AnnouncementStatus.archived) return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hay = '${a.title} ${a.body}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _AnnouncementSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _AnnouncementSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _AnnouncementSort.titleAsc:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _AnnouncementSort.reachDesc:
        list.sort((a, b) => b.recipientCount.compareTo(a.recipientCount));
    }
    return list;
  }

  int get _draftCount =>
      _items.where((a) => a.status == AnnouncementStatus.draft).length;
  int get _publishedCount =>
      _items.where((a) => a.status == AnnouncementStatus.published).length;
  int get _archivedCount =>
      _items.where((a) => a.status == AnnouncementStatus.archived).length;
  int get _reachTotal => _items
      .where((a) => a.status == AnnouncementStatus.published)
      .fold<int>(0, (sum, a) => sum + a.recipientCount);

  bool get _hasActiveFilters =>
      _query.isNotEmpty || _statusFilter != _AnnouncementStatusFilter.all;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _statusFilter = _AnnouncementStatusFilter.all;
    });
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
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
    if (_statusFilter != _AnnouncementStatusFilter.all) {
      final label = switch (_statusFilter) {
        _AnnouncementStatusFilter.draft => 'Draft',
        _AnnouncementStatusFilter.published => 'Published',
        _AnnouncementStatusFilter.archived => 'Archived',
        _AnnouncementStatusFilter.all => 'Active',
      };
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Status: $label',
          onRemoved: () =>
              setState(() => _statusFilter = _AnnouncementStatusFilter.all),
        ),
      );
    }
    return chips;
  }

  String _audienceLine(Announcement a) {
    final programs = a.targetPrograms;
    final batches = a.targetBatchYears;
    if (programs.isEmpty && batches.isEmpty) return 'All alumni';
    final parts = <String>[];
    if (programs.isNotEmpty) {
      parts.add(
        programs.length == 1
            ? programs.first
            : '${programs.length} courses',
      );
    }
    if (batches.isNotEmpty) {
      parts.add(
        batches.length == 1
            ? 'Batch ${batches.first}'
            : '${batches.length} batches',
      );
    }
    return parts.join(' · ');
  }

  String _metaLine(Announcement a) {
    final fmt = DateFormat.yMMMd();
    final parts = <String>[
      _audienceLine(a),
      if (a.status == AnnouncementStatus.published)
        '${a.recipientCount} reached',
      a.publishedAt != null
          ? 'Published ${fmt.format(a.publishedAt!)}'
          : 'Created ${fmt.format(a.createdAt)}',
    ];
    return parts.join(' · ');
  }

  Future<void> _create() async {
    final titleController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New announcement'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: AdminAnnouncementTheme.fieldDecoration(label: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: announcementFilledButtonStyle(),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final id = await _service.createAnnouncement(
        title: titleController.text.trim(),
        body: '',
      );
      if (!mounted) return;
      await showAdminAnnouncementEditor(
        context: context,
        announcementId: id,
        onChanged: _load,
      );
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _openEditor(Announcement a) async {
    await showAdminAnnouncementEditor(
      context: context,
      announcementId: a.id,
      onChanged: _load,
    );
    if (mounted) _load();
  }

  Future<void> _onMenu(Announcement a, String value) async {
    if (value == 'edit') {
      await _openEditor(a);
      return;
    }
    if (value == 'archive' && a.status == AnnouncementStatus.published) {
      await _service.archiveAnnouncement(a.id);
      _load();
      return;
    }
    if (value == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete announcement?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style: announcementFilledButtonStyle(
                background: AdminAnnouncementTheme.danger,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _service.deleteAnnouncement(a.id);
        _load();
      }
    }
  }

  List<PopupMenuEntry<String>> _menuItemsFor(Announcement a) {
    return [
      const PopupMenuItem(value: 'edit', child: Text('Edit / publish')),
      if (a.status == AnnouncementStatus.published)
        const PopupMenuItem(value: 'archive', child: Text('Archive')),
      const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ];
  }

  Widget _buildMetrics() {
    return DirectoryStatsGrid(
      children: [
        DirectoryStatCard(
          label: 'Draft',
          value: '$_draftCount',
          description: 'Not yet published',
          icon: Icons.edit_note_outlined,
          accent: AdminAnnouncementTheme.warning,
          onTap: () => setState(
            () => _statusFilter = _AnnouncementStatusFilter.draft,
          ),
        ),
        DirectoryStatCard(
          label: 'Published',
          value: '$_publishedCount',
          description: 'Live notices',
          icon: Icons.campaign_outlined,
          accent: AdminAnnouncementTheme.success,
          onTap: () => setState(
            () => _statusFilter = _AnnouncementStatusFilter.published,
          ),
        ),
        DirectoryStatCard(
          label: 'Archived',
          value: '$_archivedCount',
          description: 'Retired notices',
          icon: Icons.archive_outlined,
          accent: AdminAnnouncementTheme.textSecondary,
          onTap: () => setState(
            () => _statusFilter = _AnnouncementStatusFilter.archived,
          ),
        ),
        DirectoryStatCard(
          label: 'Reach',
          value: '$_reachTotal',
          description: 'Alumni notified',
          icon: Icons.groups_outlined,
          accent: AdminAnnouncementTheme.primary,
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
      isLoading: _isLoading,
      onRefresh: _load,
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      searchHint: 'Search by title or body…',
      filters: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DirectoryFilterField<_AnnouncementSort>(
            label: 'Sort',
            value: _sort,
            width: 148,
            items: const [
              DropdownMenuItem(
                value: _AnnouncementSort.newest,
                child: Text('Newest first'),
              ),
              DropdownMenuItem(
                value: _AnnouncementSort.oldest,
                child: Text('Oldest first'),
              ),
              DropdownMenuItem(
                value: _AnnouncementSort.titleAsc,
                child: Text('Title A–Z'),
              ),
              DropdownMenuItem(
                value: _AnnouncementSort.reachDesc,
                child: Text('Most reach'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _sort = v);
            },
          ),
          for (final f in _AnnouncementStatusFilter.values)
            DirectoryToolbarFilterChip(
              label: switch (f) {
                _AnnouncementStatusFilter.all => 'Active',
                _AnnouncementStatusFilter.draft => 'Draft',
                _AnnouncementStatusFilter.published => 'Published',
                _AnnouncementStatusFilter.archived =>
                  'Archived ($_archivedCount)',
              },
              selected: _statusFilter == f,
              onSelected: (_) => setState(() => _statusFilter = f),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            AdminPageHeader(
              title: 'Announcements',
              subtitle: 'Publish notices to alumni by course and batch.',
              titleFontSize: AdminDensity.titleFontSize,
              titleColor: AdminAnnouncementTheme.textPrimary,
              subtitleColor: AdminAnnouncementTheme.textSecondary,
              actions: [
                FilledButton.icon(
                  onPressed: _isLoading ? null : _create,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('New announcement'),
                  style: announcementFilledButtonStyle(),
                ),
              ],
            ),
            const SizedBox(height: AdminAnnouncementTheme.space2),
            _buildMetrics(),
            const SizedBox(height: AdminAnnouncementTheme.space2),
            _buildToolbar(),
            const SizedBox(height: AdminAnnouncementTheme.space1),
            Expanded(
              child: AdminInstantContent(
                loading: _isLoading,
                loadingSkeleton: const PortalCardListSkeleton(),
                isEmpty: filtered.isEmpty,
                empty: DirectoryEmptyState(
                  title: _items.isEmpty
                      ? 'No announcements yet'
                      : 'No matches',
                  subtitle: _items.isEmpty
                      ? 'Create a notice and publish it to alumni.'
                      : 'Try a different search or filter.',
                  icon: Icons.campaign_outlined,
                  primaryAction: _items.isEmpty ? _create : null,
                  primaryLabel: 'New announcement',
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: AdminDensity.space3),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final a = filtered[index];
                    return AnnouncementListCard(
                      announcement: a,
                      metaLine: _metaLine(a),
                      menuItems: _menuItemsFor(a),
                      onMenuSelected: (value) => _onMenu(a, value),
                      onOpen: () => _openEditor(a),
                    );
                  },
                ),
              ),
            ),
          ],
    );
  }
}
