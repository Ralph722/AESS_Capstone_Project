import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/forum/presentation/forum_page.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/features/notifications/presentation/notification_panel_sheet.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Community tab: alumni Forum hub.
///
/// Announcements open from Home (or other entry points) via
/// [UserAnnouncementsScreen], not as a second tab here.
class UserCommunityScreen extends StatefulWidget {
  const UserCommunityScreen({super.key});

  @override
  State<UserCommunityScreen> createState() => _UserCommunityScreenState();
}

class _UserCommunityScreenState extends State<UserCommunityScreen>
    with AutomaticKeepAliveClientMixin {
  final _notifications = NotificationService();
  StreamSubscription<int>? _forumUnreadSub;
  int _forumUnread = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _forumUnreadSub = _notifications
        .getUnreadCountStream(type: NotificationType.forum)
        .listen((count) {
          if (!mounted) return;
          setState(() => _forumUnread = count);
        });
  }

  @override
  void dispose() {
    _forumUnreadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Community',
        automaticallyImplyLeading: false,
        actions: [
          PortalHeaderAction(
            icon: Icons.notifications_outlined,
            tooltip: 'Community activity',
            badgeCount: _forumUnread,
            onPressed: () => showNotificationPanel(
              context,
              type: NotificationType.forum,
              title: 'Community activity',
              emptySubtitle:
                  'Replies, mentions, and job-offer updates will show up here.',
            ),
          ),
        ],
      ),
      body: const ForumScreen(embeddedInHub: true),
    );
  }
}
