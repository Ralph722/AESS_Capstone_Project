import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/notifications/application/notification_router.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/features/notifications/presentation/notification_preferences_page.dart';
import 'package:alumni_system/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Full notification history for alumni: filters, paging, swipe to delete.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _Filter { all, unread }

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = NotificationService.pageSize;

  final _service = NotificationService();
  StreamSubscription<void>? _changes;

  List<NotificationModel> _items = [];
  _Filter _filter = _Filter.all;
  NotificationType? _type;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _changes = _service.watchChanges().listen((_) => _reload(keepCount: true));
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool keepCount = false}) async {
    final limit = keepCount && _items.length > _pageSize
        ? _items.length
        : _pageSize;
    try {
      final rows = await _service.fetchPage(
        limit: limit,
        unreadOnly: _filter == _Filter.unread,
        type: _type,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _hasMore = rows.length >= limit;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final rows = await _service.fetchPage(
        limit: _pageSize,
        unreadOnly: _filter == _Filter.unread,
        type: _type,
        before: _items.last.createdAt,
      );
      if (!mounted) return;
      final known = _items.map((n) => n.id).toSet();
      setState(() {
        _items = [..._items, ...rows.where((n) => !known.contains(n.id))];
        _hasMore = rows.length >= _pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      _snack('Could not load more notifications');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setFilter({
    _Filter? filter,
    NotificationType? type,
    bool clearType = false,
  }) {
    setState(() {
      if (filter != null) _filter = filter;
      if (clearType) {
        _type = null;
      } else if (type != null) {
        _type = type;
      }
      _loading = true;
      _items = [];
      _hasMore = true;
    });
    _reload();
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _items = _filter == _Filter.unread
            ? []
            : [for (final n in _items) n.copyWith(isRead: true)];
      });
      _snack('All notifications marked as read');
    } catch (_) {
      _snack('Could not mark notifications as read');
    }
  }

  Future<void> _clearRead() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear read notifications?'),
        content: const Text(
          'Read notifications will be removed from this list. '
          'Unread ones stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: PortalMenu.dangerButton(dense: true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteAllRead();
      if (!mounted) return;
      setState(() => _items = _items.where((n) => !n.isRead).toList());
      _snack('Read notifications cleared');
    } catch (_) {
      _snack('Could not clear notifications');
    }
  }

  Future<void> _delete(NotificationModel n) async {
    final index = _items.indexWhere((x) => x.id == n.id);
    if (index < 0) return;
    setState(() => _items = [..._items]..removeAt(index));
    try {
      await _service.deleteNotification(n.id);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _items = [..._items]..insert(index.clamp(0, _items.length), n),
      );
      _snack('Could not delete notification');
    }
  }

  void _open(NotificationModel n) {
    if (!n.isRead) {
      setState(() {
        _items = [
          for (final x in _items) x.id == n.id ? x.copyWith(isRead: true) : x,
        ];
      });
    }
    unawaited(NotificationRouter.open(n));
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Notifications',
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationPreferencesScreen(),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'read') _markAllRead();
              if (value == 'clear') _clearRead();
            },
            itemBuilder: (_) => [
              portalMenuItem(
                value: 'read',
                label: 'Mark all as read',
                icon: Icons.done_all_rounded,
              ),
              portalMenuItem(
                value: 'clear',
                label: 'Clear read',
                icon: Icons.delete_sweep_outlined,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
      body: PortalContentFrame(
        child: Column(
          children: [
            _buildFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: PortalTheme.navy,
          labelStyle: PortalTheme.meta.copyWith(
            color: selected ? Colors.white : PortalTheme.navy,
            fontWeight: FontWeight.w700,
          ),
          showCheckmark: false,
          side: BorderSide(color: PortalTheme.border.withValues(alpha: 0.9)),
          backgroundColor: Colors.white,
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        children: [
          chip(
            'All',
            _filter == _Filter.all && _type == null,
            () => _setFilter(filter: _Filter.all, clearType: true),
          ),
          chip(
            'Unread',
            _filter == _Filter.unread,
            () => _setFilter(
              filter: _filter == _Filter.unread ? _Filter.all : _Filter.unread,
            ),
          ),
          for (final type in NotificationType.values)
            chip(
              notificationTypeLabel(type),
              _type == type,
              () => _type == type
                  ? _setFilter(clearType: true)
                  : _setFilter(type: type),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const NotificationListSkeleton();
    if (_error != null && _items.isEmpty) {
      return PortalErrorState(
        error: _error,
        onRetry: () {
          setState(() => _loading = true);
          _reload();
        },
      );
    }
    if (_items.isEmpty) {
      return PortalEmptyState(
        icon: Icons.notifications_none_rounded,
        title: _filter == _Filter.unread
            ? 'No unread notifications'
            : 'No notifications',
        subtitle: _type != null || _filter == _Filter.unread
            ? 'Try another filter.'
            : 'Updates about events, jobs, and community will show up here.',
      );
    }

    final groups = groupNotifications(_items);
    return RefreshIndicator(
      color: PortalTheme.navy,
      onRefresh: () => _reload(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (s) {
          if (s.metrics.pixels >= s.metrics.maxScrollExtent - 240) _loadMore();
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              NotificationGroupHeader(groups[i].key.label),
              for (final n in groups[i].value)
                Dismissible(
                  key: ValueKey('notification-${n.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: PortalTheme.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: PortalTheme.danger,
                    ),
                  ),
                  onDismissed: (_) => _delete(n),
                  child: NotificationTile(
                    notification: n,
                    onTap: () => _open(n),
                  ),
                ),
            ],
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PortalTheme.navy,
                    ),
                  ),
                ),
              )
            else if (_hasMore)
              Center(
                child: TextButton(
                  onPressed: _loadMore,
                  style: PortalTheme.ghostButton(),
                  child: const Text('Load more'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
