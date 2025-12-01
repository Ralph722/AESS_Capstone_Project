import 'package:flutter/material.dart';
import 'package:alumni_system/screens/user_messages_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  Widget build(BuildContext context) {
    return const UserMessagesScreen();
  }
}

