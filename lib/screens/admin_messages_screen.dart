import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentAdmin;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _conversationUsers = [];

  bool _isLoadingMessages = false;
  bool _isLoadingUsers = true;

  String? _selectedUserId;
  String? _selectedUserDocId;
  String? _selectedUserName;
  String? _adminDocId;

  @override
  void initState() {
    super.initState();
    _currentAdmin = _auth.currentUser;
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadAdminDocId();
    await _loadConversationUsers();
  }

  Future<void> _loadAdminDocId() async {
    if (_currentAdmin == null) return;
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: _currentAdmin!.uid)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        _adminDocId = snapshot.docs.first.id;
      }
    } catch (e) {
      // ignore lookup errors
    }
  }

  Future<void> _loadConversationUsers() async {
    if (_currentAdmin == null) return;

    final adminIds = <String>{
      if (_currentAdmin?.uid != null) _currentAdmin!.uid,
      if (_adminDocId != null) _adminDocId!,
    };

    if (adminIds.isEmpty) return;

    try {
      setState(() => _isLoadingUsers = true);

      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      if (_currentAdmin?.uid != null) {
        queries.add(_firestore
            .collection('messages')
            .where('recipientId', isEqualTo: _currentAdmin!.uid)
            .get());
      }
      if (_adminDocId != null) {
        queries.add(_firestore
            .collection('messages')
            .where('recipientDocId', isEqualTo: _adminDocId)
            .get());
      }

      final snapshots = await Future.wait(queries);
      final Map<String, Map<String, dynamic>> userMap = {};

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if ((data['senderRole'] ?? '') != 'user') continue;

          final senderId = data['senderId'] as String?;
          final senderDocId = data['senderDocId'] as String?;
          final key = senderId ?? senderDocId;
          if (key == null) continue;

          userMap.putIfAbsent(key, () {
            return {
              'messagingId': senderId ?? senderDocId,
              'docId': senderDocId,
              'name': data['senderName'] ?? 'User',
              'email': data['senderEmail'] ?? '',
            };
          });
        }
      }

      for (final entry in userMap.entries) {
        final info = entry.value;
        final docId = info['docId'] as String?;
        bool found = false;

        if (docId != null) {
          final userDoc =
              await _firestore.collection('users').doc(docId).get();
          if (userDoc.exists) {
            final data = userDoc.data();
            if (data != null) {
              info['name'] = data['displayName'] ?? info['name'];
              info['email'] = data['email'] ?? info['email'];
              info['messagingId'] = data['uid'] ?? info['messagingId'];
              found = true;
            }
          }
        }

        if (!found) {
          final messagingId = info['messagingId'] as String?;
          if (messagingId != null) {
            final query = await _firestore
                .collection('users')
                .where('uid', isEqualTo: messagingId)
                .limit(1)
                .get();
            if (query.docs.isNotEmpty) {
              final data = query.docs.first.data();
              info['docId'] = query.docs.first.id;
              info['name'] = data['displayName'] ?? info['name'];
              info['email'] = data['email'] ?? info['email'];
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _conversationUsers = userMap.values.toList()
            ..sort(
              (a, b) => (a['name'] as String)
                  .toLowerCase()
                  .compareTo((b['name'] as String).toLowerCase()),
            );
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading conversations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMessagesForUser(String userMessagingId,
      {String? userDocId}) async {
    final userIds = <String>{
      if (userMessagingId.isNotEmpty) userMessagingId,
      if (userDocId != null && userDocId.isNotEmpty) userDocId,
    };
    final adminIds = <String>{
      if (_currentAdmin?.uid != null) _currentAdmin!.uid,
      if (_adminDocId != null) _adminDocId!,
    };

    if (userIds.isEmpty || adminIds.isEmpty) return;

    try {
      setState(() => _isLoadingMessages = true);

      final messageMap = <String, Map<String, dynamic>>{};
      final processedIds = <String>{};

      for (final id in {...userIds, ...adminIds}) {
        if (processedIds.contains(id)) continue;
        processedIds.add(id);

        final snapshot = await _firestore
            .collection('messages')
            .where('senderId', isEqualTo: id)
            .get();
        for (final doc in snapshot.docs) {
          messageMap[doc.id] = {
            ...doc.data(),
            'docId': doc.id,
          };
        }
      }

      final filteredMessages = messageMap.values.where((msg) {
        final senderCandidates = <String?>{
          msg['senderId'] as String?,
          msg['senderDocId'] as String?,
        };
        final recipientCandidates = <String?>{
          msg['recipientId'] as String?,
          msg['recipientDocId'] as String?,
        };

        final isUserSender = senderCandidates.any(
          (id) => id != null && userIds.contains(id),
        );
        final isAdminSender = senderCandidates.any(
          (id) => id != null && adminIds.contains(id),
        );
        final isUserRecipient = recipientCandidates.any(
          (id) => id != null && userIds.contains(id),
        );
        final isAdminRecipient = recipientCandidates.any(
          (id) => id != null && adminIds.contains(id),
        );

        return (isUserSender && isAdminRecipient) ||
            (isAdminSender && isUserRecipient);
      }).toList();

      filteredMessages.sort((a, b) {
        final timeA = (a['timestamp'] as Timestamp).toDate();
        final timeB = (b['timestamp'] as Timestamp).toDate();
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _messages = filteredMessages;
          _isLoadingMessages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty ||
        _currentAdmin == null ||
        (_selectedUserId == null && _selectedUserDocId == null)) {
      return;
    }

    final messageText = _messageController.text;
    _messageController.clear();

    final recipientId = _selectedUserId ?? _selectedUserDocId!;

    try {
      final messageId = _firestore.collection('messages').doc().id;

      await _firestore.collection('messages').doc(messageId).set({
        'id': messageId,
        'senderId': _currentAdmin!.uid,
        'senderDocId': _adminDocId,
        'senderName': _currentAdmin!.displayName ?? 'Admin',
        'senderEmail': _currentAdmin!.email ?? '',
        'senderRole': 'admin',
        'recipientId': recipientId,
        'recipientDocId': _selectedUserDocId,
        'messageText': messageText,
        'imageUrl': null,
        'timestamp': Timestamp.now(),
        'isRead': false,
      });

      await _loadMessagesForUser(
        recipientId,
        userDocId: _selectedUserDocId,
      );
      await _loadConversationUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final isAdmin = message['senderId'] == _currentAdmin?.uid ||
        (message['senderDocId'] != null &&
            _adminDocId != null &&
            message['senderDocId'] == _adminDocId);
    if (!isAdmin) return;

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

      if (_selectedUserId != null || _selectedUserDocId != null) {
        await _loadMessagesForUser(
          _selectedUserId ?? _selectedUserDocId!,
          userDocId: _selectedUserDocId,
        );
      }
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
    final isAdmin = message['senderId'] == _currentAdmin?.uid ||
        (message['senderDocId'] != null &&
            _adminDocId != null &&
            message['senderDocId'] == _adminDocId);
    if (!isAdmin) return;

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

      if (_selectedUserId != null || _selectedUserDocId != null) {
        await _loadMessagesForUser(
          _selectedUserId ?? _selectedUserDocId!,
          userDocId: _selectedUserDocId,
        );
      }
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
        backgroundColor: const Color(0xFF090A4F),
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // User selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoadingUsers
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select user to chat with',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedUserId,
                    items: _conversationUsers
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u['messagingId'] as String,
                            child: Text(u['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        setState(() {
                          _selectedUserId = null;
                          _selectedUserDocId = null;
                          _selectedUserName = null;
                          _messages = [];
                        });
                        return;
                      }

                      final selectedUser = _conversationUsers.firstWhere(
                        (u) => u['messagingId'] == value,
                        orElse: () => {
                          'docId': null,
                          'name': 'User',
                        },
                      );

                      setState(() {
                        _selectedUserId = value;
                        _selectedUserDocId = selectedUser['docId'] as String?;
                        _selectedUserName = selectedUser['name'] as String;
                      });

                      _loadMessagesForUser(
                        value,
                        userDocId: _selectedUserDocId,
                      );
                    },
                  ),
          ),
          // Messages list
          Expanded(
            child: _selectedUserId == null
                ? Center(
                    child: Text(
                      'Select a user to start messaging',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : _isLoadingMessages
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet with ${_selectedUserName ?? 'this user'}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final senderDocId =
                                  msg['senderDocId'] as String?;
                              final isAdmin =
                                  msg['senderId'] == _currentAdmin!.uid ||
                                      (senderDocId != null &&
                                          _adminDocId != null &&
                                          senderDocId == _adminDocId);
                              final timestamp =
                                  (msg['timestamp'] as Timestamp).toDate();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Align(
                                  alignment: isAdmin
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment: isAdmin
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onLongPress: isAdmin
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
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  'edit'),
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(
                                                              Icons.delete),
                                                          title: const Text(
                                                              'Delete'),
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                  context,
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
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.75,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isAdmin
                                                ? const Color(0xFF090A4F)
                                                : Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            msg['messageText'] ?? '',
                                            style: TextStyle(
                                              color: isAdmin
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
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
          // Message input
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
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
                              enabled:
                                  _selectedUserId != null ||
                                      _selectedUserDocId != null,
                              decoration: InputDecoration(
                                hintText: _selectedUserId == null
                                    ? 'Select a user to start chatting'
                                    : 'Type a message...',
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                ),
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
                      color: (_selectedUserId == null &&
                              _selectedUserDocId == null)
                          ? Colors.grey.shade400
                          : const Color(0xFF090A4F),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: (_selectedUserId == null &&
                              _selectedUserDocId == null)
                          ? null
                          : _sendMessage,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
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


