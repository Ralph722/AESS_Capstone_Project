import 'package:flutter/material.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/admin/announcements/presentation/admin_announcement_editor_page.dart';
import 'package:alumni_system/features/admin/announcements/widgets/admin_announcement_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

enum _AnnouncementStatusFilter { all, draft, published, archived }

enum _AnnouncementSort { newest, oldest, titleAsc, reachDesc }

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key, this.service});

  final AnnouncementService? service;

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final AnnouncementService _service =
      widget.service ?? AnnouncementService();
  final _searchController = TextEditingController();
  final Set<String> _busyIds = {};

  List<Announcement> _items = [];
  bool _isLoading = false;
  String? _loadError;
  String _query = '';
  _AnnouncementStatusFilter _statusFilter = _AnnouncementStatusFilter.all;
  AnnouncementPriority? _priorityFilter;
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
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await _service.getAllAnnouncements();
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '$e';
      });
    }
  }

  List<Announcement> get _filtered {
    final list = _items.where((a) {
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
      if (_priorityFilter != null && a.priority != _priorityFilter) {
        return false;
      }
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hay =
            '${a.title} ${a.body} ${a.targetPrograms.join(' ')} ${a.targetBatchYears.join(' ')}'
                .toLowerCase();
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
      _query.isNotEmpty ||
      _statusFilter != _AnnouncementStatusFilter.all ||
      _priorityFilter != null ||
      _sort != _AnnouncementSort.newest;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _statusFilter = _AnnouncementStatusFilter.all;
      _priorityFilter = null;
      _sort = _AnnouncementSort.newest;
    });
  }

  String _sortLabel(_AnnouncementSort sort) => switch (sort) {
    _AnnouncementSort.newest => 'Newest first',
    _AnnouncementSort.oldest => 'Oldest first',
    _AnnouncementSort.titleAsc => 'Title A–Z',
    _AnnouncementSort.reachDesc => 'Most reach',
  };

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
    if (_priorityFilter != null) {
      chips.add(
        DirectoryActiveFilterChip(
          label:
              'Priority: ${_priorityFilter == AnnouncementPriority.important ? 'Important' : 'Normal'}',
          onRemoved: () => setState(() => _priorityFilter = null),
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
    if (_sort != _AnnouncementSort.newest) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Sort: ${_sortLabel(_sort)}',
          onRemoved: () => setState(() => _sort = _AnnouncementSort.newest),
        ),
      );
    }
    return chips;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AdminColors.danger : null,
      ),
    );
  }

  Future<void> _create() async {
    final title = await showAdminDialogSurface<String>(
      context: context,
      maxWidth: 460,
      child: const _NewAnnouncementDialog(),
    );
    if (title == null || !mounted) return;

    try {
      final id = await _service.createAnnouncement(
        title: title,
        body: '',
      );
      if (!mounted) return;
      await showAdminAnnouncementEditor(
        context: context,
        announcementId: id,
        onChanged: _load,
        service: _service,
      );
      if (mounted) _load();
    } catch (e) {
      _showSnack(
        announcementFriendlyError(
          e,
          'Could not create the announcement draft. Please try again.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _openEditor(Announcement a) async {
    await showAdminAnnouncementEditor(
      context: context,
      announcementId: a.id,
      onChanged: _load,
      service: _service,
    );
    if (mounted) _load();
  }

  Future<void> _onMenu(Announcement a, String value) async {
    if (value == 'edit') {
      await _openEditor(a);
      return;
    }
    if (_busyIds.contains(a.id)) return;

    if (value == 'archive' && a.status == AnnouncementStatus.published) {
      setState(() => _busyIds.add(a.id));
      try {
        await _service.archiveAnnouncement(a.id);
        if (!mounted) return;
        _showSnack('Announcement archived');
        await _load();
      } catch (e) {
        _showSnack(
          announcementFriendlyError(
            e,
            'Could not archive this announcement. Please try again.',
          ),
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _busyIds.remove(a.id));
      }
      return;
    }

    if (value == 'restore' && a.status == AnnouncementStatus.archived) {
      setState(() => _busyIds.add(a.id));
      try {
        await _service.restoreAnnouncement(a.id);
        if (!mounted) return;
        _showSnack('Announcement restored');
        await _load();
      } catch (e) {
        _showSnack(
          announcementFriendlyError(
            e,
            'Could not restore this announcement. Please try again.',
          ),
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _busyIds.remove(a.id));
      }
      return;
    }

    if (value == 'delete') {
      final label = a.title.trim().isEmpty
          ? 'this announcement'
          : '“${a.title.trim()}”';
      final confirm = await showAdminConfirmDialog(
        context,
        title: 'Delete announcement?',
        message: 'Permanently delete $label? This action cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
        icon: Icons.delete_outline_rounded,
      );
      if (!confirm || !mounted) return;

      setState(() => _busyIds.add(a.id));
      try {
        await _service.deleteAnnouncement(a.id);
        if (!mounted) return;
        _showSnack('Announcement deleted');
        await _load();
      } catch (e) {
        _showSnack(
          announcementFriendlyError(
            e,
            'Could not delete this announcement. Please try again.',
          ),
          isError: true,
        );
      } finally {
        if (mounted) setState(() => _busyIds.remove(a.id));
      }
    }
  }

  List<PopupMenuEntry<String>> _menuItemsFor(Announcement a) {
    return [
      adminAnnouncementMenuItem(
        value: 'edit',
        label: a.status == AnnouncementStatus.draft
            ? 'Edit & publish'
            : 'Open details',
        icon: Icons.edit_outlined,
      ),
      if (a.status == AnnouncementStatus.published)
        adminAnnouncementMenuItem(
          value: 'archive',
          label: 'Archive',
          icon: Icons.archive_outlined,
        ),
      if (a.status == AnnouncementStatus.archived)
        adminAnnouncementMenuItem(
          value: 'restore',
          label: 'Restore',
          icon: Icons.unarchive_outlined,
        ),
      const PopupMenuDivider(height: 8),
      adminAnnouncementMenuItem(
        value: 'delete',
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
    ];
  }

  Widget _buildMetrics() {
    return AdminMetricRibbon(
      items: [
        AdminMetricRibbonItem(
          label: 'Drafts',
          value: '$_draftCount',
          icon: Icons.edit_note_outlined,
          color: AdminColors.warning,
          tooltip: 'Unpublished announcement drafts',
        ),
        AdminMetricRibbonItem(
          label: 'Published',
          value: '$_publishedCount',
          icon: Icons.campaign_outlined,
          color: AdminColors.success,
          tooltip: 'Live alumni notices',
        ),
        AdminMetricRibbonItem(
          label: 'Archived',
          value: '$_archivedCount',
          icon: Icons.archive_outlined,
          color: AdminColors.textSecondary,
          tooltip: 'Retired notices available to restore',
        ),
        AdminMetricRibbonItem(
          label: 'Total reach',
          value: '$_reachTotal',
          icon: Icons.groups_outlined,
          color: AdminColors.primary,
          tooltip: 'Alumni reached by published notices',
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return AdminSaaSToolbar(
      searchController: _searchController,
      onSearchChanged: (v) => setState(() => _query = v.trim()),
      onClearSearch: () {
        _searchController.clear();
        setState(() => _query = '');
      },
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      searchHint: 'Search title, message, or target…',
      searchWidth: 250,
      filters: [
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
        DirectoryFilterField<AnnouncementPriority?>(
          label: 'Priority',
          value: _priorityFilter,
          dense: true,
          width: 132,
          items: const [
            DropdownMenuItem(value: null, child: Text('All priorities')),
            DropdownMenuItem(
              value: AnnouncementPriority.important,
              child: Text('Important'),
            ),
            DropdownMenuItem(
              value: AnnouncementPriority.normal,
              child: Text('Normal'),
            ),
          ],
          onChanged: (v) => setState(() => _priorityFilter = v),
        ),
      ],
      sortControl: DirectoryFilterField<_AnnouncementSort>(
        label: 'Sort',
        value: _sort,
        dense: true,
        width: 142,
        items: [
          for (final s in _AnnouncementSort.values)
            DropdownMenuItem(
              value: s,
              child: Text(
                _sortLabel(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _sort = v);
        },
      ),
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
              "Couldn't refresh announcements. Showing the last loaded list.",
              style: TextStyle(fontSize: 13, color: AdminColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _load,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Announcement> filtered) {
    if (_isLoading && _items.isEmpty) {
      return const AdminAnnouncementsListSkeleton();
    }
    if (_loadError != null && _items.isEmpty) {
      return AdminStateView.error(
        title: "Couldn't load announcements",
        message: 'Check your connection and try again.',
        details: _loadError,
        onRetry: _load,
      );
    }
    if (filtered.isEmpty) {
      final hasEmptyRepo = _items.isEmpty || !_hasActiveFilters;
      return AdminStateView.empty(
        icon: hasEmptyRepo
            ? Icons.campaign_outlined
            : Icons.search_off_rounded,
        title: _items.isEmpty
            ? 'No announcements yet'
            : (_hasActiveFilters
                ? 'No matching announcements'
                : 'No announcements in this view'),
        message: _items.isEmpty
            ? 'Create a notice and publish it to alumni.'
            : (_hasActiveFilters
                ? 'Try clearing filters or searching with a different keyword.'
                : 'Switch tabs or create a new announcement.'),
        primaryAction: AdminStateAction(
          label: _hasActiveFilters ? 'Clear filters' : 'New announcement',
          icon: _hasActiveFilters
              ? Icons.filter_alt_off_outlined
              : Icons.add_rounded,
          onPressed: _hasActiveFilters ? _resetFilters : _create,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AdminDensity.space3),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final a = filtered[index];
        return AnnouncementListCard(
          announcement: a,
          busy: _busyIds.contains(a.id),
          menuItems: _menuItemsFor(a),
          onMenuSelected: (value) => _onMenu(a, value),
          onOpen: () => _openEditor(a),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCompactHeader(
          title: 'Announcements',
          actions: [
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _load,
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 15),
              label: Text(_isLoading ? 'Refreshing…' : 'Refresh'),
              style: AdminButtonStyles.outlined(),
            ),
            FilledButton.icon(
              onPressed: _isLoading ? null : _create,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('New announcement'),
              style: AdminButtonStyles.filled(),
            ),
          ],
        ),
        const SizedBox(height: AdminDensity.space2),
        _buildMetrics(),
        const SizedBox(height: AdminDensity.space2),
        _buildToolbar(),
        if (_loadError != null && _items.isNotEmpty) ...[
          const SizedBox(height: AdminDensity.space1),
          _buildRefreshErrorNotice(),
        ],
        const SizedBox(height: AdminDensity.space1),
        Expanded(child: _buildBody(filtered)),
      ],
    );
  }
}

class _NewAnnouncementDialog extends StatefulWidget {
  const _NewAnnouncementDialog();

  @override
  State<_NewAnnouncementDialog> createState() => _NewAnnouncementDialogState();
}

class _NewAnnouncementDialogState extends State<_NewAnnouncementDialog> {
  final _titleController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = 'Enter a title before creating a draft.');
      return;
    }
    Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AdminDialogStandards.defaultContentPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminModalHeader(
            title: 'New announcement',
            subtitle:
                'Start a draft headline, then set audience and delivery options.',
            icon: Icons.campaign_outlined,
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            decoration: AdminAnnouncementTheme.fieldDecoration(
              label: 'Title *',
              hint: 'e.g. Graduate Tracer Survey Reminder',
            ).copyWith(errorText: _errorText),
          ),
          const SizedBox(height: 20),
          AdminModalFooter(
            cancelLabel: 'Cancel',
            onCancel: () => Navigator.pop(context),
            confirmLabel: 'Create draft',
            onConfirm: _submit,
          ),
        ],
      ),
    );
  }
}
