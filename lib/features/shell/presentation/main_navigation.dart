import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/home/presentation/home_page.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/events/presentation/events_page.dart';
import 'package:alumni_system/features/jobs/presentation/job_posting_page.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/tracer_page.dart';
import 'package:alumni_system/features/alumni/profile/presentation/profile_page.dart';
import 'package:alumni_system/features/community/presentation/user_community_page.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Primary tab indices for the alumni portal shell.
abstract final class PortalTabs {
  static const int home = 0;
  static const int events = 1;
  static const int tracer = 2;
  static const int jobs = 3;
  static const int community = 4;
  static const int profile = 5;
  static const int count = 6;
}

class MainNavigation extends StatefulWidget {
  final int? initialIndex;

  const MainNavigation({super.key, this.initialIndex});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();
  final Set<int> _visitedTabs = {PortalTabs.home};

  @override
  void initState() {
    super.initState();
    _currentIndex = (widget.initialIndex ?? PortalTabs.home)
        .clamp(0, PortalTabs.count - 1);
    _visitedTabs.add(_currentIndex);
    _recordAlumniActivity();
  }

  /// Switch bottom-nav tab without rebuilding the whole app shell.
  Future<void> switchToTab(int index) async {
    if (index < 0 || index >= PortalTabs.count) return;
    if (_currentIndex == index) return;
    if (_currentIndex == PortalTabs.profile) {
      final profile = _profileKey.currentState;
      if (profile != null && profile.hasUnsavedChanges) {
        final ok = await profile.confirmLeave();
        if (!ok || !mounted) return;
      }
    }
    setState(() {
      _visitedTabs.add(index);
      _currentIndex = index;
    });
    if (index == PortalTabs.home) {
      _homeKey.currentState?.refreshMessagesCount();
      _homeKey.currentState?.refreshUserProfile();
      unawaited(_homeKey.currentState?.refreshDashboard());
    }
  }

  Future<void> _recordAlumniActivity() async {
    final userId = AppSession.userId;
    if (userId == null) return;
    try {
      final role = await AuthService().getUserRole(userId);
      if (role == UserRole.user) {
        await AlumniMemberService().recordLastActiveForAuthUid(userId);
      }
    } catch (_) {}
  }

  Widget _screenForIndex(int index) {
    switch (index) {
      case PortalTabs.home:
        return HomeScreen(key: _homeKey, onSelectTab: switchToTab);
      case PortalTabs.events:
        return const EventsScreen();
      case PortalTabs.tracer:
        return const TracerScreen(embeddedInNav: true);
      case PortalTabs.jobs:
        return const JobPostingScreen();
      case PortalTabs.community:
        return const UserCommunityScreen();
      case PortalTabs.profile:
        return ProfileScreen(key: _profileKey);
      default:
        return const SizedBox.shrink();
    }
  }

  final List<NavItem> _navItems = [
    NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      index: PortalTabs.home,
    ),
    NavItem(
      icon: Icons.event_outlined,
      activeIcon: Icons.event,
      label: 'Events',
      index: PortalTabs.events,
    ),
    NavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      label: 'Tracer',
      index: PortalTabs.tracer,
    ),
    NavItem(
      icon: Icons.work_outline,
      activeIcon: Icons.work,
      label: 'Jobs',
      index: PortalTabs.jobs,
    ),
    NavItem(
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
      label: 'Community',
      index: PortalTabs.community,
    ),
    NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
      index: PortalTabs.profile,
    ),
  ];

  Widget _buildBodyStack() {
    return IndexedStack(
      index: _currentIndex,
      sizing: StackFit.expand,
      children: List.generate(PortalTabs.count, (index) {
        if (!_visitedTabs.contains(index)) {
          return const SizedBox.shrink();
        }
        return _screenForIndex(index);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = PortalBreakpoints.widthOf(context);
    final useRail = PortalBreakpoints.useNavigationRail(width);

    if (useRail) {
      return Scaffold(
        backgroundColor: PortalTheme.pageBg,
        body: Row(
          children: [
            Semantics(
              container: true,
              label: 'Main navigation',
              child: NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: switchToTab,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                indicatorColor: PortalTheme.navy.withValues(alpha: 0.08),
                selectedIconTheme: const IconThemeData(
                  color: PortalTheme.navy,
                  size: 22,
                ),
                unselectedIconTheme: IconThemeData(
                  color: Colors.grey.shade600,
                  size: 22,
                ),
                selectedLabelTextStyle: const TextStyle(
                  color: PortalTheme.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                destinations: _navItems
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.activeIcon),
                        label: Text(item.label),
                      ),
                    )
                    .toList(),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _buildBodyStack()),
          ],
        ),
      );
    }

    return Scaffold(
      body: _buildBodyStack(),
      bottomNavigationBar: _buildMinimalNavBar(),
    );
  }

  Widget _buildMinimalNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: PortalTheme.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: PortalTheme.navy.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.map(_buildMinimalNavItem).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalNavItem(NavItem navItem) {
    final isSelected = _currentIndex == navItem.index;
    // Soft indigo/slate tint for active tab (keeps navy icons).
    const activeTint = Color(0xFFEEF2FF);

    return Semantics(
      button: true,
      selected: isSelected,
      label: navItem.label,
      child: InkWell(
        onTap: () => switchToTab(navItem.index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: PortalTheme.fast,
          curve: PortalTheme.ease,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          constraints: const BoxConstraints(minWidth: 52, minHeight: 48),
          decoration: BoxDecoration(
            color: isSelected ? activeTint : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? navItem.activeIcon : navItem.icon,
                size: 22,
                color: isSelected ? PortalTheme.navy : PortalTheme.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                navItem.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isSelected ? PortalTheme.navy : PortalTheme.textSecondary,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}
