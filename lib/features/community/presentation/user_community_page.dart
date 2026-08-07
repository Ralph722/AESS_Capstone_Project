import 'package:flutter/material.dart';
import 'package:alumni_system/features/announcements/presentation/user_announcements_page.dart';
import 'package:alumni_system/features/forum/presentation/forum_page.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Primary Community tab: Forum + Announcements (Tracer/Surveys stay separate).
class UserCommunityScreen extends StatefulWidget {
  const UserCommunityScreen({super.key, this.initialTab = 0});

  /// 0 = Forum, 1 = Announcements
  final int initialTab;

  @override
  State<UserCommunityScreen> createState() => _UserCommunityScreenState();
}

class _UserCommunityScreenState extends State<UserCommunityScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab.clamp(0, 1);
    _tabController = TabController(length: 2, vsync: this, initialIndex: initial);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Community',
        subtitle: 'Connect with fellow alumni',
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: PortalTheme.navy,
          unselectedLabelColor: PortalTheme.textMuted,
          indicatorColor: PortalTheme.navy,
          indicatorWeight: 2.5,
          dividerColor: Colors.transparent,
          labelStyle: PortalTheme.button.copyWith(fontSize: 13),
          unselectedLabelStyle: PortalTheme.meta.copyWith(
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Forum'),
            Tab(text: 'Announcements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ForumScreen(embeddedInHub: true),
          UserAnnouncementsScreen(embeddedInHub: true),
        ],
      ),
    );
  }
}
