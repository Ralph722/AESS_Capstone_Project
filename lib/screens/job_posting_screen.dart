import 'package:flutter/material.dart';

class JobPostingScreen extends StatelessWidget {
  const JobPostingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: const Center(
        child: Text(
          'Job Posting Screen',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF090A4F),
          ),
        ),
      ),
    );
  }
}

