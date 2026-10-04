import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/notifications/application/notification_router.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/features/notifications/presentation/notifications_page.dart';
import 'package:alumni_system/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Alumni notification sheet (Home bell). Stays live while open.
Future<void> showNotificationPanel(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const NotificationPanelSheet(),
  );
}

class NotificationPanelSheet extends StatefulWidget {
  const NotificationPanelSheet({super.key});

  @override
  State<NotificationPanelSheet> createState() => _NotificationPanelSheetState();
}

class _NotificationPanelSheetState extends State<NotificationPanelSheet> {
  static const _limit = 20;

  final _service = NotificationService();
  StreamSubscription<void>? _changes;
  List<NotificationModel> _items = const [];
  int _unread = 0;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _changes = _service.watchChanges().listen((_) => _load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.fetchPage(limit: _limit),
        _service.getUnreadCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<NotificationModel>;
        _unread = results[1] as int;
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

  Future<void> _markAllRead() async {
    final previous = _items;
    final previousUnread = _unread;
    setState(() {
      _items = [for (final n in _items) n.copyWith(isRead: true)];
      _unread = 0;
    });
    try {
      await _service.markAllAsRead();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = previous;
        _unread = previousUnread;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark notifications as read')),
      );
    }
  }

  void _open(NotificationModel n) {
    Navigator.of(context).pop();
    unawaited(NotificationRouter.open(n));
  }

  void _openPage(Widget page) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PortalTheme.pageBg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(PortalTheme.radius2xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            if (_items.isNotEmpty) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: PortalTheme.border.withValues(alpha: 0.75)),
        ),
        boxShadow: PortalTheme.softShadow,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PortalTheme.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PortalTheme.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: PortalTheme.navy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: PortalTheme.pageTitle.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _unread > 0
                              ? '$_unread unread'
                              : 'You\'re all caught up',
                          style: PortalTheme.meta.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_unread > 0)
                    TextButton(
                      onPressed: _markAllRead,
                      style: TextButton.styleFrom(
                        foregroundColor: PortalTheme.sky,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Mark all read',
                        style: PortalTheme.meta.copyWith(
                          color: PortalTheme.sky,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const NotificationListSkeleton();
    if (_error != null && _items.isEmpty) {
      return PortalErrorState(error: _error, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const PortalEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications',
        subtitle:
            'Updates about events, jobs, and community will show up here.',
      );
    }
    final groups = groupNotifications(_items);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            NotificationGroupHeader(groups[i].key.label),
            for (final n in groups[i].value)
              NotificationTile(notification: n, onTap: () => _open(n)),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: PortalTheme.border.withValues(alpha: 0.75)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: TextButton(
          onPressed: () => _openPage(const NotificationsScreen()),
          style: TextButton.styleFrom(
            foregroundColor: PortalTheme.navy,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(
            'See all notifications',
            style: PortalTheme.meta.copyWith(
              color: PortalTheme.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
