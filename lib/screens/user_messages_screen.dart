import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;

class UserMessagesScreen extends StatefulWidget {
  const UserMessagesScreen({super.key});

  @override
  State<UserMessagesScreen> createState() => _UserMessagesScreenState();
}

class _UserMessagesScreenState extends State<UserMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (_currentUser == null) return;
    try {
      // Get all messages where current user is sender
      final sentSnapshot = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: _currentUser!.uid)
          .get();

      // Get all messages where current user is recipient
      final receivedSnapshot = await _firestore
          .collection('messages')
          .where('recipientId', isEqualTo: _currentUser!.uid)
          .get();

      final allMessages = <Map<String, dynamic>>[];
      
      // Add sent messages
      for (var doc in sentSnapshot.docs) {
        allMessages.add(doc.data());
      }
      
      // Add received messages
      for (var doc in receivedSnapshot.docs) {
        allMessages.add(doc.data());
      }

      // Sort by timestamp (newest first)
      allMessages.sort((a, b) {
        final timeA = (a['timestamp'] as Timestamp).toDate();
        final timeB = (b['timestamp'] as Timestamp).toDate();
        return timeB.compareTo(timeA);
      });

      print('DEBUG: Loaded ${allMessages.length} messages');

      if (mounted) {
        setState(() {
          _messages = allMessages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _currentUser == null) {
      return;
    }

    final messageText = _messageController.text;
    _messageController.clear();

    try {
      // Get all admins
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No admin available to message'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final adminId = adminSnapshot.docs.first.id;
      final messageId = _firestore.collection('messages').doc().id;

      print('DEBUG: Sending message to admin: $adminId');

      await _firestore.collection('messages').doc(messageId).set({
        'id': messageId,
        'senderId': _currentUser!.uid,
        'senderName': _currentUser!.displayName ?? 'User',
        'senderEmail': _currentUser!.email ?? '',
        'senderRole': 'user',
        'recipientId': adminId,
        'messageText': messageText,
        'imageUrl': null,
        'timestamp': Timestamp.now(),
        'isRead': false,
      });

      print('DEBUG: Message saved to Firestore');

      // Reload messages immediately
      await _loadMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent to admin'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error sending message: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return intl.DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings, color: Color(0xFF090A4F), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Support',
                  style: TextStyle(
                    color: Color(0xFF090A4F),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mail_outline, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation with admin',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isCurrentUser = msg['senderId'] == _currentUser!.uid;
                          final timestamp = (msg['timestamp'] as Timestamp).toDate();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Align(
                              alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? const Color(0xFF090A4F)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      msg['messageText'] ?? '',
                                      style: TextStyle(
                                        color: isCurrentUser ? Colors.white : Colors.black87,
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      _formatTime(timestamp),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Message Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Ask admin...',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                hintStyle: TextStyle(color: Colors.grey.shade500),
                              ),
                              maxLines: null,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF090A4F),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
