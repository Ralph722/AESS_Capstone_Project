import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alumni_system/screens/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Juan Dela Cruz';
    final email = user?.email ?? 'cruz@gmail.com';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Profile Picture
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF090A4F),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // User Information Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person, 'Full Name', displayName),
                    const Divider(),
                    _buildInfoRow(Icons.email, 'Email', email),
                    const Divider(),
                    _buildInfoRow(Icons.badge, 'ID Number', '2023202023'),
                    const Divider(),
                    _buildInfoRow(Icons.school, 'Course', 'BSIT'),
                    const Divider(),
                    _buildInfoRow(Icons.phone, 'Phone Number', '09123456789'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Settings Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildSettingItem(
                      Icons.settings,
                      'General Settings',
                      () {
                        // Not functional yet
                      },
                    ),
                    const Divider(),
                    _buildSettingItem(
                      Icons.lock,
                      'Security',
                      () {
                        // Not functional yet
                      },
                    ),
                    const Divider(),
                    _buildSettingItem(
                      Icons.notifications,
                      'Notifications',
                      () {
                        // Not functional yet
                      },
                    ),
                    const Divider(),
                    _buildSettingItem(
                      Icons.info,
                      'Privacy',
                      () {
                        // Not functional yet
                      },
                    ),
                    const Divider(),
                    _buildSettingItem(
                      Icons.link,
                      'Linked Accounts',
                      () {
                        // Not functional yet
                      },
                    ),
                    const Divider(),
                    _buildSettingItem(
                      Icons.help_outline,
                      'Help & Support',
                      () {
                        // Not functional yet
                      },
                    ),
                    const Divider(),
                    _buildSettingItem(
                      Icons.logout,
                      'Logout',
                      () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      isLogout: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF090A4F), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF090A4F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLogout ? const Color(0xFFFFD700) : const Color(0xFF090A4F),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: isLogout ? const Color(0xFFFFD700) : const Color(0xFF090A4F),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isLogout ? const Color(0xFFFFD700) : Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

