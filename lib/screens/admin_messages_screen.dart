import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminMessagesScreen extends StatefulWidget {
  final bool hideAppBar;
  
  const AdminMessagesScreen({super.key, this.hideAppBar = false});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  User? _currentAdmin;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _conversationUsers = [];
  List<Map<String, dynamic>> _filteredConversations = [];

  bool _isLoadingMessages = false;
  bool _isLoadingUsers = true;
  bool _isUploadingImage = false;

  String? _selectedUserId;
  String? _selectedUserDocId;
  String? _selectedUserName;
  String? _adminDocId;
  final ScrollController _messagesScrollController = ScrollController();

  // Image handling
  File? _selectedImage;
  Uint8List? _selectedImageBytes;

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
              'lastMessage': data['messageText'] ?? '',
              'lastMessageTime': data['timestamp'] as Timestamp?,
              'isRead': data['isRead'] ?? false,
            };
          });
        }
      }

      // Get last message for each user
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

        // Get the most recent message for this conversation
        // Use simple queries without orderBy to avoid index requirement, then filter and sort in memory
        final adminIds = <String>{
          if (_currentAdmin?.uid != null) _currentAdmin!.uid,
          if (_adminDocId != null) _adminDocId!,
        };
        
        final allMessages = <Map<String, dynamic>>[];
        final userId = info['messagingId'] as String?;
        
        if (userId != null && adminIds.isNotEmpty) {
          // Get messages where user is sender (single where clause - no index needed)
          final senderMessages = await _firestore
              .collection('messages')
              .where('senderId', isEqualTo: userId)
              .get();
          
          // Get messages where user is recipient (single where clause - no index needed)
          final recipientMessages = await _firestore
              .collection('messages')
              .where('recipientId', isEqualTo: userId)
              .get();
          
          // Filter in memory to only keep messages between admin and this user
          for (var doc in senderMessages.docs) {
            final data = doc.data();
            final recipientId = data['recipientId'] as String?;
            final recipientDocId = data['recipientDocId'] as String?;
            if (adminIds.contains(recipientId) || adminIds.contains(recipientDocId)) {
              allMessages.add(data);
            }
          }
          
          for (var doc in recipientMessages.docs) {
            final data = doc.data();
            final senderId = data['senderId'] as String?;
            final senderDocId = data['senderDocId'] as String?;
            if (adminIds.contains(senderId) || adminIds.contains(senderDocId)) {
              allMessages.add(data);
            }
          }
          
          if (allMessages.isNotEmpty) {
            // Filter to only show user messages (not admin messages)
            final userMessages = allMessages.where((msg) {
              return (msg['senderRole'] ?? '') == 'user';
            }).toList();
            
            if (userMessages.isNotEmpty) {
              // Sort by timestamp in memory
              userMessages.sort((a, b) {
                final timeA = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
                final timeB = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
                return timeB.compareTo(timeA); // Descending order
              });
              
              final lastMsg = userMessages.first;
              info['lastMessage'] = lastMsg['messageText'] ?? '';
              info['lastMessageTime'] = lastMsg['timestamp'] as Timestamp?;
              info['isRead'] = lastMsg['isRead'] ?? false;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _conversationUsers = userMap.values.toList()
            ..sort((a, b) {
              final timeA = (a['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
              final timeB = (b['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
              return timeB.compareTo(timeA);
            });
          _filteredConversations = List.from(_conversationUsers);
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

  void _searchConversations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = List.from(_conversationUsers);
      } else {
        _filteredConversations = _conversationUsers.where((user) {
          final name = (user['name'] as String? ?? '').toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _loadMessagesForUser(String userMessagingId,
      {String? userDocId, bool showLoading = true}) async {
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
      if (showLoading) {
        setState(() => _isLoadingMessages = true);
      }

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
        return timeA.compareTo(timeB); // Oldest first for chat view
      });

      if (mounted) {
        final wasFirstLoad = _messages.isEmpty && _isLoadingMessages;
        
        setState(() {
          _messages = filteredMessages;
          _isLoadingMessages = false;
        });

        // Auto-scroll to bottom when messages are loaded
        _scrollToBottom(immediate: wasFirstLoad);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMessages = false);
      }
    }
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
      final fileName = 'messages/${_currentAdmin!.uid}_$timestamp.jpg';
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
        _currentAdmin == null ||
        (_selectedUserId == null && _selectedUserDocId == null)) {
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
        'imageUrl': imageUrl,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'reactions': <String, List<String>>{}, // Initialize empty reactions
      });

      // Clear image selection
      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
      });

      // Auto-scroll to bottom after sending
      _scrollToBottom();

      // Reload messages and conversations without showing loading state
      await _loadMessagesForUser(
        recipientId,
        userDocId: _selectedUserDocId,
        showLoading: false,
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

  void _scrollToBottom({bool immediate = false}) {
    // Use multiple postFrameCallbacks to ensure ListView is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messagesScrollController.hasClients) {
        // For initial load, use a longer delay to ensure ListView is fully rendered
        final delay = immediate ? 0 : 200;
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted && _messagesScrollController.hasClients) {
            try {
              final maxScroll = _messagesScrollController.position.maxScrollExtent;
              if (immediate) {
                _messagesScrollController.jumpTo(maxScroll);
              } else {
                _messagesScrollController.animateTo(
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

  Future<void> _addReaction(String messageDocId, String emoji) async {
    try {
      final doc = await _firestore.collection('messages').doc(messageDocId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      final adminId = _currentAdmin!.uid;

      // Get current list of users who reacted with this emoji
      final usersList = List<String>.from(reactions[emoji] ?? []);

      // Toggle reaction - if admin already reacted, remove it; otherwise add it
      if (usersList.contains(adminId)) {
        usersList.remove(adminId);
        if (usersList.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = usersList;
        }
      } else {
        usersList.add(adminId);
        reactions[emoji] = usersList;
      }

      await _firestore.collection('messages').doc(messageDocId).update({
        'reactions': reactions,
      });

      // Reload messages
      if (_selectedUserId != null || _selectedUserDocId != null) {
        await _loadMessagesForUser(
          _selectedUserId ?? _selectedUserDocId!,
          userDocId: _selectedUserDocId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding reaction: $e'),
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
            title: const Text('Edit Message'),
            content: TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Edit your message...',
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            title: const Text('Delete Message'),
            content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
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

      // Delete image from storage if exists
      final imageUrl = message['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          // Ignore storage deletion errors
        }
      }

      await _firestore.collection('messages').doc(docId).delete();

      if (_selectedUserId != null || _selectedUserDocId != null) {
        await _loadMessagesForUser(
          _selectedUserId ?? _selectedUserDocId!,
          userDocId: _selectedUserDocId,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMessageOptions(BuildContext context, Map<String, dynamic> message, String messageDocId) {
    final isAdmin = message['senderId'] == _currentAdmin?.uid ||
        (message['senderDocId'] != null &&
            _adminDocId != null &&
            message['senderDocId'] == _adminDocId);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_reaction, color: Colors.orange),
              title: const Text('Add Reaction'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(context, messageDocId);
              },
            ),
            if (isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Message'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context, String messageDocId) {
    final reactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Reaction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF090A4F),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: reactions.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _addReaction(messageDocId, emoji);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
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

  String _formatLastMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
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
    _messageController.dispose();
    _searchController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Row(
      children: [
        // Left Panel - Conversation List
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        _currentAdmin?.displayName?.substring(0, 1).toUpperCase() ?? 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Messenger',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search Bar
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade50,
                child: TextField(
                  controller: _searchController,
                  onChanged: _searchConversations,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ),
              ),
              // Conversations List
              Expanded(
                child: _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredConversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No conversations',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredConversations.length,
                            itemBuilder: (context, index) {
                              final user = _filteredConversations[index];
                              final isSelected = user['messagingId'] == _selectedUserId;
                              final lastMessage = user['lastMessage'] as String? ?? '';
                              final lastMessageTime = user['lastMessageTime'] as Timestamp?;
                              final isUnread = !(user['isRead'] ?? true);

                              return InkWell(
                                onTap: () {
                                  final selectedUser = _conversationUsers.firstWhere(
                                    (u) => u['messagingId'] == user['messagingId'],
                                    orElse: () => {
                                      'docId': null,
                                      'name': 'User',
                                    },
                                  );

                                  setState(() {
                                    _selectedUserId = user['messagingId'] as String;
                                    _selectedUserDocId = selectedUser['docId'] as String?;
                                    _selectedUserName = selectedUser['name'] as String;
                                  });

                                  _loadMessagesForUser(
                                    user['messagingId'] as String,
                                    userDocId: selectedUser['docId'] as String?,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.grey.shade100 : Colors.white,
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: const Color(0xFF090A4F).withOpacity(0.1),
                                        child: Text(
                                          (user['name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF090A4F),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    user['name'] as String? ?? 'User',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                                                      color: Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (lastMessageTime != null)
                                                  Text(
                                                    _formatLastMessageTime(lastMessageTime),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                                fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isUnread)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF090A4F),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        // Right Panel - Chat Area
        Expanded(
          child: _selectedUserId == null
              ? Container(
                  color: Colors.grey.shade50,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Select a conversation',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Chat Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF090A4F).withOpacity(0.1),
                            child: Text(
                              (_selectedUserName ?? 'U').substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF090A4F),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedUserName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Last active recently',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Messages Area
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade50,
                        child: _isLoadingMessages
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
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Start a conversation with ${_selectedUserName ?? 'this user'}',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _messagesScrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      final msg = _messages[index];
                                      final senderDocId = msg['senderDocId'] as String?;
                                      final isAdmin = msg['senderId'] == _currentAdmin!.uid ||
                                          (senderDocId != null &&
                                              _adminDocId != null &&
                                              senderDocId == _adminDocId);
                                      final timestamp = (msg['timestamp'] as Timestamp).toDate();
                                      final imageUrl = msg['imageUrl'] as String?;
                                      final messageText = msg['messageText'] as String? ?? '';
                                      final messageDocId = msg['docId'] as String? ?? '';
                                      final reactions = Map<String, dynamic>.from(msg['reactions'] ?? {});
                                      final adminId = _currentAdmin!.uid;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Column(
                                          crossAxisAlignment: isAdmin
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: isAdmin
                                                  ? MainAxisAlignment.end
                                                  : MainAxisAlignment.start,
                                              children: [
                                                if (!isAdmin) ...[
                                                  CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: const Color(0xFF090A4F).withOpacity(0.1),
                                                    child: Text(
                                                      (_selectedUserName ?? 'U').substring(0, 1).toUpperCase(),
                                                      style: const TextStyle(
                                                        color: Color(0xFF090A4F),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                Flexible(
                                                  child: GestureDetector(
                                                    onLongPress: () {
                                                      if (messageDocId.isNotEmpty) {
                                                        _showMessageOptions(context, msg, messageDocId);
                                                      }
                                                    },
                                                    onDoubleTap: () {
                                                      // Quick reaction on double tap
                                                      if (messageDocId.isNotEmpty) {
                                                        _addReaction(messageDocId, '👍');
                                                      }
                                                    },
                                                    child: Align(
                                                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                                      child: ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          maxWidth: MediaQuery.of(context).size.width * 0.65,
                                                        ),
                                                        child: IntrinsicWidth(
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: isAdmin
                                                                  ? const Color(0xFF090A4F)
                                                                  : Colors.white,
                                                              borderRadius: BorderRadius.circular(18),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.black.withOpacity(0.05),
                                                                  blurRadius: 4,
                                                                  offset: const Offset(0, 2),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Padding(
                                                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    mainAxisSize: MainAxisSize.min,
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
                                                                        const SizedBox(height: 6),
                                                                      if (messageText.isNotEmpty)
                                                                        Text(
                                                                          messageText,
                                                                          style: TextStyle(
                                                                            color: isAdmin ? Colors.white : Colors.black87,
                                                                            fontSize: 14,
                                                                            height: 1.3,
                                                                          ),
                                                                          softWrap: true,
                                                                        ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (reactions.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                                                              child: Wrap(
                                                                spacing: 4,
                                                                runSpacing: 4,
                                                                children: reactions.entries.map((entry) {
                                                                  final emoji = entry.key;
                                                                  final users = List<String>.from(entry.value ?? []);
                                                                  final hasReacted = users.contains(adminId);
                                                                  return GestureDetector(
                                                                    onTap: () {
                                                                      if (messageDocId.isNotEmpty) {
                                                                        _addReaction(messageDocId, emoji);
                                                                      }
                                                                    },
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal: 6,
                                                                        vertical: 2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: hasReacted
                                                                            ? (isAdmin
                                                                                ? Colors.white.withOpacity(0.3)
                                                                                : const Color(0xFF090A4F).withOpacity(0.1))
                                                                            : Colors.transparent,
                                                                        borderRadius: BorderRadius.circular(10),
                                                                        border: Border.all(
                                                                          color: hasReacted
                                                                              ? (isAdmin ? Colors.white : const Color(0xFF090A4F))
                                                                              : Colors.grey.shade300,
                                                                          width: 1,
                                                                        ),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          Text(
                                                                            emoji,
                                                                            style: const TextStyle(fontSize: 14),
                                                                          ),
                                                                          if (users.length > 1) ...[
                                                                            const SizedBox(width: 4),
                                                                            Text(
                                                                              '${users.length}',
                                                                              style: TextStyle(
                                                                                fontSize: 11,
                                                                                color: hasReacted
                                                                                    ? (isAdmin ? Colors.white : const Color(0xFF090A4F))
                                                                                    : Colors.grey.shade600,
                                                                                fontWeight: FontWeight.bold,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                              ),
                                                            ),
                                                          Padding(
                                                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                                                            child: Text(
                                                              _formatTime(timestamp),
                                                              style: TextStyle(
                                                                color: isAdmin
                                                                    ? Colors.white.withOpacity(0.7)
                                                                    : Colors.grey.shade600,
                                                                fontSize: 10,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    ),
                                                  ),
                                                ),
                                                if (isAdmin) ...[
                                                  const SizedBox(width: 8),
                                                  CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: const Color(0xFF090A4F).withOpacity(0.1),
                                                    child: Text(
                                                      _currentAdmin?.displayName?.substring(0, 1).toUpperCase() ?? 'A',
                                                      style: const TextStyle(
                                                        color: Color(0xFF090A4F),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ),
                    // Message Input
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
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
                                    ),
                                    child: TextField(
                                      controller: _messageController,
                                      decoration: InputDecoration(
                                        hintText: 'Type a message...',
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        hintStyle: TextStyle(color: Colors.grey.shade500),
                                      ),
                                      maxLines: null,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.attach_file, color: Colors.grey.shade600),
                                  onPressed: _pickImage,
                                ),
                                IconButton(
                                  icon: Icon(Icons.send, color: const Color(0xFF090A4F)),
                                  onPressed: _isUploadingImage ? null : _sendMessage,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
    
    if (widget.hideAppBar) {
      return bodyContent;
    }
    
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
      body: bodyContent,
    );
  }
}
