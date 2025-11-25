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
          tooltip: 'Back to User Mode',
          child: const Icon(Icons.arrow_back),
        ),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF090A4F),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, 'Home', 0),
                _buildNavItem(Icons.event, 'Events', 1),
                _buildNavItem(Icons.people, 'Community', 2),
                _buildNavItem(Icons.work, 'Job Posting', 3),
                _buildNavItem(Icons.search, 'ID Tracer', 4),
                GestureDetector(
                  onLongPress: () {
                    setState(() {
                      _isAdminMode = true;
                    });
                  },
                  child: _buildNavItem(Icons.person, 'Profile', 5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFFFD700) : Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFFFD700) : Colors.white,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

