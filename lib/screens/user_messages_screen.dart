import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:alumni_system/services/message_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserMessagesScreen extends StatefulWidget {
  const UserMessagesScreen({super.key});

  @override
  State<UserMessagesScreen> createState() => _UserMessagesScreenState();
}

class _UserMessagesScreenState extends State<UserMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MessageService _messageService = MessageService();
  final ImagePicker _imagePicker = ImagePicker();

  User? _currentUser;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;
  String? _userDocId;
  String? _adminName = 'Admin';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSubscription;
  final ScrollController _scrollController = ScrollController();

  // Image handling
  File? _selectedImage;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCurrentUserDocId();
    await _loadAdminInfo();
    // Wait a bit to ensure _userDocId is set
    await Future.delayed(const Duration(milliseconds: 100));
    _startMessagesListener();
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

  Future<void> _loadAdminInfo() async {
    try {
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminSnapshot.docs.isNotEmpty) {
        final adminData = adminSnapshot.docs.first.data();
        setState(() {
          _adminName = adminData['displayName'] ?? 'Admin';
        });
      }
    } catch (e) {
      // ignore errors
    }
  }

  void _startMessagesListener() {
    if (_currentUser == null) return;

    // Cancel existing subscription if any
    _messagesSubscription?.cancel();

    setState(() => _isLoading = true);

    // Get admin ID first
    _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .limit(1)
        .get()
        .then((adminSnapshot) {
      if (adminSnapshot.docs.isEmpty || !mounted) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final adminDoc = adminSnapshot.docs.first;
      final adminData = adminDoc.data();
      final adminId = adminData['uid'] as String?;
      final adminDocId = adminDoc.id;

      final userIds = <String>{
        _currentUser!.uid,
        if (_userDocId != null && _userDocId!.isNotEmpty) _userDocId!,
      };

      final adminIds = <String>{
        if (adminId != null && adminId.isNotEmpty) adminId,
        adminDocId,
      };

      // Listen to messages where user is sender or recipient
      _messagesSubscription = _firestore
          .collection('messages')
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;

        final messagesMap = <String, Map<String, dynamic>>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final senderId = data['senderId'] as String?;
          final senderDocId = data['senderDocId'] as String?;
          final recipientId = data['recipientId'] as String?;
          final recipientDocId = data['recipientDocId'] as String?;

          // Check if message is between user and admin
          // User is sender if senderId or senderDocId matches user's uid or docId
          final isUserSender = (senderId != null && userIds.contains(senderId)) ||
              (senderDocId != null && userIds.contains(senderDocId));
          
          // User is recipient if recipientId or recipientDocId matches user's uid or docId
          final isUserRecipient = (recipientId != null && userIds.contains(recipientId)) ||
              (recipientDocId != null && userIds.contains(recipientDocId));
          
          // Admin is sender if senderId or senderDocId matches admin's uid or docId
          final isAdminSender = (senderId != null && adminIds.contains(senderId)) ||
              (senderDocId != null && adminIds.contains(senderDocId));
          
          // Admin is recipient if recipientId or recipientDocId matches admin's uid or docId
          final isAdminRecipient = (recipientId != null && adminIds.contains(recipientId)) ||
              (recipientDocId != null && adminIds.contains(recipientDocId));

          // Message is part of conversation if:
          // - User sent to admin, OR
          // - Admin sent to user
          if ((isUserSender && isAdminRecipient) ||
              (isAdminSender && isUserRecipient)) {
            messagesMap[doc.id] = {
              ...data,
              'docId': doc.id,
            };
          }
        }

        final filteredMessages = messagesMap.values.toList();
        filteredMessages.sort((a, b) {
          final timeA = (a['timestamp'] as Timestamp).toDate();
          final timeB = (b['timestamp'] as Timestamp).toDate();
          return timeA.compareTo(timeB); // Oldest first - newest at bottom
        });

        if (mounted) {
          final wasFirstLoad = _messages.isEmpty && _isLoading;
          
          setState(() {
            _messages = filteredMessages;
            _isLoading = false;
          });

          // Auto-scroll to bottom when new messages arrive or on first load
          _scrollToBottom(immediate: wasFirstLoad);

          // Mark all admin messages as read when user views the messages screen
          _messageService.markAdminMessagesAsRead();
        }
      }, onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          print('Error in messages stream: $error');
        }
      });
    });
  }

  Future<void> _loadMessages() async {
    // This method is kept for compatibility but _startMessagesListener is used instead
    _startMessagesListener();
  }

  void _scrollToBottom({bool immediate = false}) {
    // Use multiple postFrameCallbacks to ensure ListView is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        // For initial load, use a longer delay to ensure ListView is fully rendered
        final delay = immediate ? 0 : 200;
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted && _scrollController.hasClients) {
            try {
              final maxScroll = _scrollController.position.maxScrollExtent;
              if (immediate) {
                _scrollController.jumpTo(maxScroll);
              } else {
                _scrollController.animateTo(
                  maxScroll,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            } catch (e) {
              // Ignore scroll errors
            }
          }
        });
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageBytes = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null && _selectedImageBytes == null) return null;

    try {
      setState(() => _isUploadingImage = true);
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'messages/${_currentUser!.uid}_$timestamp.jpg';
      final ref = storage.ref().child(fileName);

      String downloadUrl;
      if (kIsWeb && _selectedImageBytes != null) {
        await ref.putData(
          _selectedImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else if (_selectedImage != null) {
        await ref.putFile(_selectedImage!);
      } else {
        return null;
      }

      downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _selectedImage = null;
          _selectedImageBytes = null;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if ((_messageController.text.isEmpty && _selectedImage == null && _selectedImageBytes == null) ||
        _currentUser == null) {
      return;
    }

    String? imageUrl;
    if (_selectedImage != null || _selectedImageBytes != null) {
      imageUrl = await _uploadImage();
      if (imageUrl == null && _messageController.text.isEmpty) {
        return; // Failed to upload and no text
      }
    }

    final messageText = _messageController.text.trim();
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
        'imageUrl': imageUrl,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'reactions': <String, List<String>>{}, // Initialize empty reactions
      });

      // Auto-scroll to bottom after sending
      _scrollToBottom();
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
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return intl.DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _scrollController.dispose();
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
                Text(
                  _adminName ?? 'Admin Support',
                  style: const TextStyle(
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
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        // Scroll to bottom when ListView is first built
                        addAutomaticKeepAlives: false,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderDocId = msg['senderDocId'] as String?;
                          final isCurrentUser =
                              msg['senderId'] == _currentUser!.uid ||
                                  (senderDocId != null &&
                                      _userDocId != null &&
                                      senderDocId == _userDocId);
                          final timestamp = (msg['timestamp'] as Timestamp).toDate();
                          final imageUrl = msg['imageUrl'] as String?;
                          final messageText = msg['messageText'] as String? ?? '';

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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (imageUrl != null)
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                imageUrl,
                                                width: 200,
                                                height: 200,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 200,
                                                    height: 200,
                                                    color: Colors.grey.shade300,
                                                    child: const Icon(Icons.broken_image),
                                                  );
                                                },
                                              ),
                                            ),
                                          if (imageUrl != null && messageText.isNotEmpty)
                                            const SizedBox(height: 8),
                                          if (messageText.isNotEmpty)
                                            Text(
                                              messageText,
                                              style: TextStyle(
                                                color: isCurrentUser
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 15,
                                                height: 1.4,
                                              ),
                                            ),
                                        ],
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
              child: Column(
                children: [
                  if (_selectedImage != null || _selectedImageBytes != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      height: 100,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb && _selectedImageBytes != null
                                ? Image.memory(
                                    _selectedImageBytes!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  )
                                : _selectedImage != null
                                    ? Image.file(
                                        _selectedImage!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      )
                                    : const SizedBox(),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black.withOpacity(0.6),
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _selectedImage = null;
                                    _selectedImageBytes = null;
                                  });
                                },
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
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
                              IconButton(
                                icon: Icon(Icons.attach_file, color: Colors.grey.shade600, size: 20),
                                onPressed: _pickImage,
                                tooltip: 'Attach image',
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
                          onPressed: _isUploadingImage ? null : _sendMessage,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                    ],
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
