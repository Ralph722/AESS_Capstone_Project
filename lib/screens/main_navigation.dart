import 'package:flutter/material.dart';
import 'package:alumni_system/screens/home_screen.dart';
import 'package:alumni_system/screens/events_screen.dart';
import 'package:alumni_system/screens/community_screen.dart';
import 'package:alumni_system/screens/job_posting_screen.dart';
import 'package:alumni_system/screens/id_tracer_screen.dart';
import 'package:alumni_system/screens/profile_screen.dart';
import 'package:alumni_system/screens/admin_dashboard.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isAdminMode = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const EventsScreen(),
    const CommunityScreen(),
    const JobPostingScreen(),
    const IdTracerScreen(),
    const ProfileScreen(),
  ];

  final List<NavItem> _navItems = [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', index: 0),
    NavItem(icon: Icons.event_outlined, activeIcon: Icons.event, label: 'Events', index: 1),
    NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Community', index: 2),
    NavItem(icon: Icons.work_outline, activeIcon: Icons.work, label: 'Jobs', index: 3),
    NavItem(icon: Icons.search, activeIcon: Icons.search, label: 'ID Tracer', index: 4),
    NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', index: 5),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isAdminMode) {
      return Scaffold(
        body: const AdminDashboard(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              _isAdminMode = false;
              _currentIndex = 0;
            });
          },
          backgroundColor: const Color(0xFF090A4F),
          foregroundColor: const Color(0xFFFFD700),
          tooltip: 'Back to User Mode',
          child: const Icon(Icons.arrow_back),
        ),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildMinimalNavBar(),
    );
  }

  Widget _buildMinimalNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.map((navItem) {
              return _buildMinimalNavItem(navItem);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalNavItem(NavItem navItem) {
    final isSelected = _currentIndex == navItem.index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = navItem.index;
        });
      },
      onLongPress: navItem.index == 5 ? () {
        setState(() {
          _isAdminMode = true;
        });
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(minWidth: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with subtle animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? navItem.activeIcon : navItem.icon,
                size: 22,
                color: isSelected ? const Color(0xFF090A4F) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              navItem.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF090A4F) : Colors.grey.shade600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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