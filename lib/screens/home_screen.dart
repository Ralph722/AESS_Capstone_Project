import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alumni_system/screens/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF090A4F),
      appBar: AppBar(
        title: const Text(
          'Alumni Portal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF090A4F),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Welcome Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school,
                  size: 70,
                  color: Color(0xFF090A4F),
                ),
              ),
              const SizedBox(height: 32),
              // Welcome Text
              const Text(
                'Welcome!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // User Email
              if (user != null)
                Text(
                  user.email ?? 'No email',
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
              const SizedBox(height: 48),
              // Placeholder content
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.dashboard, size: 48, color: Color(0xFF090A4F)),
                    SizedBox(height: 16),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF090A4F),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Welcome to the Alumni application for USTP Oroquieta City',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

