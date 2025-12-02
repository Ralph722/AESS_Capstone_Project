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
  String? _userDocId;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCurrentUserDocId();
    await _loadMessages();
  }

  Future<void> _loadCurrentUserDocId() async {
    if (_currentUser == null) return;
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: _currentUser!.uid)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        _userDocId = snapshot.docs.first.id;
      }
    } catch (e) {
      // ignore doc lookup errors
    }
  }

  Future<void> _loadMessages() async {
    if (_currentUser == null) return;
    try {
      setState(() => _isLoading = true);

      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _firestore
            .collection('messages')
            .where('senderId', isEqualTo: _currentUser!.uid)
            .get(),
        _firestore
            .collection('messages')
            .where('recipientId', isEqualTo: _currentUser!.uid)
            .get(),
      ];

      if (_userDocId != null) {
        queries.add(
          _firestore
              .collection('messages')
              .where('senderId', isEqualTo: _userDocId!)
              .get(),
        );
        queries.add(
          _firestore
              .collection('messages')
              .where('recipientId', isEqualTo: _userDocId!)
              .get(),
        );
      }

      final snapshots = await Future.wait(queries);

      final messagesMap = <String, Map<String, dynamic>>{};
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          messagesMap[doc.id] = {
            ...doc.data(),
            'docId': doc.id,
          };
        }
      }

      final participantIds = <String>{
        _currentUser!.uid,
        if (_userDocId != null) _userDocId!,
      };

      final filteredMessages = messagesMap.values.where((msg) {
        final senderCandidates = <String?>{
          msg['senderId'] as String?,
          msg['senderDocId'] as String?,
        };
        final recipientCandidates = <String?>{
          msg['recipientId'] as String?,
          msg['recipientDocId'] as String?,
        };

        final isParticipant = senderCandidates.any(
                  (id) => id != null && participantIds.contains(id),
                ) ||
            recipientCandidates.any(
              (id) => id != null && participantIds.contains(id),
            );
        return isParticipant;
      }).toList();

      filteredMessages.sort((a, b) {
        final timeA = (a['timestamp'] as Timestamp).toDate();
        final timeB = (b['timestamp'] as Timestamp).toDate();
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _messages = filteredMessages;
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
      // Get one admin user record
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

      final adminDoc = adminSnapshot.docs.first;
      final adminData = adminDoc.data();
      final adminId = adminData['uid'] ?? adminDoc.id;
      final messageId = _firestore.collection('messages').doc().id;

      print('DEBUG: Sending message to admin: $adminId');

      await _firestore.collection('messages').doc(messageId).set({
        'id': messageId,
        'senderId': _currentUser!.uid,
        'senderDocId': _userDocId,
        'senderName': _currentUser!.displayName ?? 'User',
        'senderEmail': _currentUser!.email ?? '',
        'senderRole': 'user',
        'recipientId': adminId,
        'recipientDocId': adminDoc.id,
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

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final isCurrentUser = message['senderId'] == _currentUser?.uid;
    if (!isCurrentUser) return;

    final controller =
        TextEditingController(text: message['messageText'] as String? ?? '');

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Edit message'),
            content: TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    final newText = controller.text.trim();
    if (newText.isEmpty || newText == message['messageText']) return;

    try {
      final docId = message['docId'] as String?;
      if (docId == null) return;

      await _firestore
          .collection('messages')
          .doc(docId)
          .update({'messageText': newText});
      await _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final isCurrentUser = message['senderId'] == _currentUser?.uid;
    if (!isCurrentUser) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete message'),
            content: const Text('Do you want to delete this message?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final docId = message['docId'] as String?;
      if (docId == null) return;

      await _firestore.collection('messages').doc(docId).delete();
      await _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting message: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                          final senderDocId = msg['senderDocId'] as String?;
                          final isCurrentUser =
                              msg['senderId'] == _currentUser!.uid ||
                                  (senderDocId != null &&
                                      _userDocId != null &&
                                      senderDocId == _userDocId);
                          final timestamp = (msg['timestamp'] as Timestamp).toDate();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Align(
                              alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onLongPress: isCurrentUser
                                        ? () async {
                                            final action =
                                                await showModalBottomSheet<
                                                    String>(
                                              context: context,
                                              builder: (context) =>
                                                  SafeArea(
                                                child: Wrap(
                                                  children: [
                                                    ListTile(
                                                      leading: const Icon(
                                                          Icons.edit),
                                                      title: const Text(
                                                          'Edit'),
                                                      onTap: () => Navigator
                                                          .pop(context,
                                                              'edit'),
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                          Icons.delete),
                                                      title: const Text(
                                                          'Delete'),
                                                      onTap: () => Navigator
                                                          .pop(context,
                                                              'delete'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );

                                            if (action == 'edit') {
                                              await _editMessage(msg);
                                            } else if (action ==
                                                'delete') {
                                              await _deleteMessage(msg);
                                            }
                                          }
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.75,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCurrentUser
                                            ? const Color(0xFF090A4F)
                                            : Colors.grey.shade200,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        msg['messageText'] ?? '',
                                        style: TextStyle(
                                          color: isCurrentUser
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
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
