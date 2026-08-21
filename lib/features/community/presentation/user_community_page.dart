import 'package:flutter/material.dart';
import 'package:alumni_system/features/forum/presentation/forum_page.dart';
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
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: const PortalAppBar(
        title: 'Community',
        automaticallyImplyLeading: false,
      ),
      body: const ForumScreen(embeddedInHub: true),
    );
  }
}
