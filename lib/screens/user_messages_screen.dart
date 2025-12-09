import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'package:alumni_system/services/message_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _messagesSubscription;
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
    _firestore.collection('users').where('role', isEqualTo: 'admin').limit(1).get().then((
      adminSnapshot,
    ) {
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
          .listen(
            (snapshot) {
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
                final isUserSender =
                    (senderId != null && userIds.contains(senderId)) ||
                    (senderDocId != null && userIds.contains(senderDocId));

                // User is recipient if recipientId or recipientDocId matches user's uid or docId
                final isUserRecipient =
                    (recipientId != null && userIds.contains(recipientId)) ||
                    (recipientDocId != null &&
                        userIds.contains(recipientDocId));

                // Admin is sender if senderId or senderDocId matches admin's uid or docId
                final isAdminSender =
                    (senderId != null && adminIds.contains(senderId)) ||
                    (senderDocId != null && adminIds.contains(senderDocId));

                // Admin is recipient if recipientId or recipientDocId matches admin's uid or docId
                final isAdminRecipient =
                    (recipientId != null && adminIds.contains(recipientId)) ||
                    (recipientDocId != null &&
                        adminIds.contains(recipientDocId));

                // Message is part of conversation if:
                // - User sent to admin, OR
                // - Admin sent to user
                if ((isUserSender && isAdminRecipient) ||
                    (isAdminSender && isUserRecipient)) {
                  messagesMap[doc.id] = {...data, 'docId': doc.id};
                }
              }

              final filteredMessages = messagesMap.values.toList();
              filteredMessages.sort((a, b) {
                final timeA = (a['timestamp'] as Timestamp).toDate();
                final timeB = (b['timestamp'] as Timestamp).toDate();
                return timeA.compareTo(
                  timeB,
                ); // Oldest first - newest at bottom
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
            },
            onError: (error) {
              if (mounted) {
                setState(() => _isLoading = false);
                print('Error in messages stream: $error');
              }
            },
          );
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
      // Show dialog to choose between camera and gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF090A4F),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF090A4F),
                  ),
                  title: const Text('Take a Photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
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

      String? imageBase64;
      Uint8List compressedBytes;

      // Compress and convert image to base64 (no Firebase Storage needed)
      try {
        if (kIsWeb && _selectedImageBytes != null) {
          // For web, compress directly from bytes
          compressedBytes = await FlutterImageCompress.compressWithList(
            _selectedImageBytes!,
            minHeight: 1920,
            minWidth: 1920,
            quality: 85,
            format: CompressFormat.jpeg,
          );
        } else if (_selectedImage != null) {
          // For mobile, compress from file
          final filePath = _selectedImage!.absolute.path;
          final compressedFile = await FlutterImageCompress.compressWithFile(
            filePath,
            minHeight: 1920,
            minWidth: 1920,
            quality: 85,
            format: CompressFormat.jpeg,
          );
          // Fallback: read original if compression fails
          compressedBytes =
              compressedFile ?? await _selectedImage!.readAsBytes();
        } else {
          setState(() => _isUploadingImage = false);
          return null;
        }

        // Keep compressing until under 700KB (to leave room for base64 encoding and Firestore limits)
        int quality = 85;
        int maxSizeBytes = 700 * 1024; // 700KB target

        while (compressedBytes.length > maxSizeBytes && quality > 30) {
          quality -= 10;
          Uint8List? newCompressedBytes;

          if (kIsWeb && _selectedImageBytes != null) {
            newCompressedBytes = await FlutterImageCompress.compressWithList(
              _selectedImageBytes!,
              minHeight: 1920,
              minWidth: 1920,
              quality: quality,
              format: CompressFormat.jpeg,
            );
          } else if (_selectedImage != null) {
            final filePath = _selectedImage!.absolute.path;
            final compressedFile = await FlutterImageCompress.compressWithFile(
              filePath,
              minHeight: 1920,
              minWidth: 1920,
              quality: quality,
              format: CompressFormat.jpeg,
            );
            newCompressedBytes = compressedFile;
          }

          if (newCompressedBytes != null) {
            compressedBytes = newCompressedBytes;
          } else {
            break; // If compression fails, use what we have
          }
        }

        // Final check - if still too large, resize more aggressively
        if (compressedBytes.length > maxSizeBytes) {
          // Resize to smaller dimensions
          Uint8List? finalCompressedBytes;

          if (kIsWeb && _selectedImageBytes != null) {
            finalCompressedBytes = await FlutterImageCompress.compressWithList(
              _selectedImageBytes!,
              minHeight: 1280,
              minWidth: 1280,
              quality: 70,
              format: CompressFormat.jpeg,
            );
          } else if (_selectedImage != null) {
            final filePath = _selectedImage!.absolute.path;
            final compressedFile = await FlutterImageCompress.compressWithFile(
              filePath,
              minHeight: 1280,
              minWidth: 1280,
              quality: 70,
              format: CompressFormat.jpeg,
            );
            finalCompressedBytes = compressedFile;
          }

          if (finalCompressedBytes != null) {
            compressedBytes = finalCompressedBytes;
          }
        }

        // Convert compressed image to base64
        imageBase64 = base64Encode(compressedBytes);

        // Check final base64 size (should be under 1MB for Firestore)
        final base64SizeMB = imageBase64.length / (1024 * 1024);
        if (base64SizeMB > 0.95) {
          // If still too large, show warning but try to send anyway
          print(
            'Warning: Base64 image size is ${base64SizeMB.toStringAsFixed(2)}MB, close to Firestore limit',
          );
        }
      } catch (conversionError) {
        String errorMessage = 'Error processing image';
        final errorString = conversionError.toString().toLowerCase();

        if (errorString.contains('too large') ||
            errorString.contains('failed')) {
          errorMessage =
              'Failed to compress image. Please try a different image.';
        } else {
          errorMessage =
              'Failed to process image: ${conversionError.toString()}';
        }

        if (mounted) {
          setState(() => _isUploadingImage = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      // imageBase64 is guaranteed to have a value here since we return early on error
      // Save base64 image as data URL (format: data:image/jpeg;base64,...)
      final base64ImageUrl = 'data:image/jpeg;base64,$imageBase64';

      // Only clear images after successful conversion
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _selectedImage = null;
          _selectedImageBytes = null;
        });
      }

      return base64ImageUrl;
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _sendMessage() async {
    if ((_messageController.text.isEmpty &&
            _selectedImage == null &&
            _selectedImageBytes == null) ||
        _currentUser == null) {
      return;
    }

    // Don't allow sending while uploading
    if (_isUploadingImage) return;

    String? imageUrl;
    File? tempImage;
    Uint8List? tempImageBytes;

    // Store image references before upload (since _uploadImage clears them)
    if (_selectedImage != null) {
      tempImage = _selectedImage;
    }
    if (_selectedImageBytes != null) {
      tempImageBytes = _selectedImageBytes;
    }

    if (tempImage != null || tempImageBytes != null) {
      imageUrl = await _uploadImage();
      if (imageUrl == null && _messageController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Restore image selection if upload failed
        if (mounted) {
          setState(() {
            _selectedImage = tempImage;
            _selectedImageBytes = tempImageBytes;
          });
        }
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

      // Clear image selection after successful send
      if (mounted) {
        setState(() {
          _selectedImage = null;
          _selectedImageBytes = null;
        });
      }

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
        // Restore image selection if send failed
        setState(() {
          _selectedImage = tempImage;
          _selectedImageBytes = tempImageBytes;
        });
      }
      print('Error sending message: $e');
    }
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final isCurrentUser = message['senderId'] == _currentUser?.uid;
    if (!isCurrentUser) return;

    final controller = TextEditingController(
      text: message['messageText'] as String? ?? '',
    );

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Edit message'),
            content: TextField(
              controller: controller,
              maxLines: null,
              decoration: const InputDecoration(border: OutlineInputBorder()),
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

      await _firestore.collection('messages').doc(docId).update({
        'messageText': newText,
      });
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

    final confirmed =
        await showDialog<bool>(
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  Future<void> _addReaction(String messageDocId, String emoji) async {
    try {
      final doc = await _firestore
          .collection('messages')
          .doc(messageDocId)
          .get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      final userId = _currentUser!.uid;

      // Get current list of users who reacted with this emoji
      final usersList = List<String>.from(reactions[emoji] ?? []);

      // Toggle reaction - if user already reacted, remove it; otherwise add it
      if (usersList.contains(userId)) {
        usersList.remove(userId);
        if (usersList.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = usersList;
        }
      } else {
        usersList.add(userId);
        reactions[emoji] = usersList;
      }

      await _firestore.collection('messages').doc(messageDocId).update({
        'reactions': reactions,
      });

      // Reload messages
      await _loadMessages();
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

  void _showMessageOptions(
    BuildContext context,
    Map<String, dynamic> message,
    String messageDocId,
  ) {
    final isCurrentUser = message['senderId'] == _currentUser?.uid;

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
            if (isCurrentUser) ...[
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

  void _showImageFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.grey.shade800,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
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
              child: const Icon(
                Icons.admin_panel_settings,
                color: Color(0xFF090A4F),
                size: 22,
              ),
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
            child: Container(
              color: Colors.grey.shade50,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mail_outline,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation with admin',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
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
                        final timestamp = (msg['timestamp'] as Timestamp)
                            .toDate();
                        final imageUrl = msg['imageUrl'] as String?;
                        final messageText = msg['messageText'] as String? ?? '';
                        final messageDocId = msg['docId'] as String? ?? '';
                        final reactions = Map<String, dynamic>.from(
                          msg['reactions'] ?? {},
                        );
                        final userId = _currentUser!.uid;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: isCurrentUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: isCurrentUser
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  if (!isCurrentUser) ...[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(
                                        0xFF090A4F,
                                      ).withOpacity(0.1),
                                      child: const Icon(
                                        Icons.admin_panel_settings,
                                        color: Color(0xFF090A4F),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: GestureDetector(
                                      onLongPress: () {
                                        if (messageDocId.isNotEmpty) {
                                          _showMessageOptions(
                                            context,
                                            msg,
                                            messageDocId,
                                          );
                                        }
                                      },
                                      onDoubleTap: () {
                                        // Quick reaction on double tap
                                        if (messageDocId.isNotEmpty) {
                                          _addReaction(messageDocId, '👍');
                                        }
                                      },
                                      child: Align(
                                        alignment: isCurrentUser
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.75,
                                          ),
                                          child: IntrinsicWidth(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isCurrentUser
                                                    ? const Color(0xFF090A4F)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          8,
                                                          12,
                                                          4,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (imageUrl != null)
                                                          GestureDetector(
                                                            onTap: () {
                                                              _showImageFullScreen(
                                                                context,
                                                                imageUrl,
                                                              );
                                                            },
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                              child: Image.network(
                                                                imageUrl,
                                                                width: 200,
                                                                height: 200,
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorBuilder:
                                                                    (
                                                                      context,
                                                                      error,
                                                                      stackTrace,
                                                                    ) {
                                                                      return Container(
                                                                        width:
                                                                            200,
                                                                        height:
                                                                            200,
                                                                        color: Colors
                                                                            .grey
                                                                            .shade300,
                                                                        child: const Icon(
                                                                          Icons
                                                                              .broken_image,
                                                                        ),
                                                                      );
                                                                    },
                                                              ),
                                                            ),
                                                          ),
                                                        if (imageUrl != null &&
                                                            messageText
                                                                .isNotEmpty)
                                                          const SizedBox(
                                                            height: 6,
                                                          ),
                                                        if (messageText
                                                            .isNotEmpty)
                                                          Text(
                                                            messageText,
                                                            style: TextStyle(
                                                              color:
                                                                  isCurrentUser
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black87,
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
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            12,
                                                            0,
                                                            12,
                                                            4,
                                                          ),
                                                      child: Wrap(
                                                        spacing: 4,
                                                        runSpacing: 4,
                                                        children: reactions.entries.map((
                                                          entry,
                                                        ) {
                                                          final emoji =
                                                              entry.key;
                                                          final users =
                                                              List<String>.from(
                                                                entry.value ??
                                                                    [],
                                                              );
                                                          final hasReacted =
                                                              users.contains(
                                                                userId,
                                                              );
                                                          return GestureDetector(
                                                            onTap: () {
                                                              if (messageDocId
                                                                  .isNotEmpty) {
                                                                _addReaction(
                                                                  messageDocId,
                                                                  emoji,
                                                                );
                                                              }
                                                            },
                                                            child: ConstrainedBox(
                                                              constraints:
                                                                  const BoxConstraints(
                                                                    maxWidth:
                                                                        100,
                                                                  ),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      hasReacted
                                                                      ? (isCurrentUser
                                                                            ? Colors.white.withOpacity(
                                                                                0.3,
                                                                              )
                                                                            : const Color(
                                                                                0xFF090A4F,
                                                                              ).withOpacity(
                                                                                0.1,
                                                                              ))
                                                                      : Colors
                                                                            .transparent,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        10,
                                                                      ),
                                                                  border: Border.all(
                                                                    color:
                                                                        hasReacted
                                                                        ? (isCurrentUser
                                                                              ? Colors.white
                                                                              : const Color(
                                                                                  0xFF090A4F,
                                                                                ))
                                                                        : Colors
                                                                              .grey
                                                                              .shade300,
                                                                    width: 1,
                                                                  ),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Text(
                                                                      emoji,
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                      ),
                                                                    ),
                                                                    if (users
                                                                            .length >
                                                                        1) ...[
                                                                      const SizedBox(
                                                                        width:
                                                                            4,
                                                                      ),
                                                                      Text(
                                                                        '${users.length}',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              11,
                                                                          color:
                                                                              hasReacted
                                                                              ? (isCurrentUser
                                                                                    ? Colors.white
                                                                                    : const Color(
                                                                                        0xFF090A4F,
                                                                                      ))
                                                                              : Colors.grey.shade600,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          0,
                                                          12,
                                                          6,
                                                        ),
                                                    child: Text(
                                                      _formatTime(timestamp),
                                                      style: TextStyle(
                                                        color: isCurrentUser
                                                            ? Colors.white
                                                                  .withOpacity(
                                                                    0.7,
                                                                  )
                                                            : Colors
                                                                  .grey
                                                                  .shade600,
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
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(
                                        0xFF090A4F,
                                      ).withOpacity(0.1),
                                      child: Text(
                                        _currentUser?.displayName
                                                ?.substring(0, 1)
                                                .toUpperCase() ??
                                            'U',
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
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
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
                              hintText: 'Ask admin...',
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
                        icon: Icon(
                          Icons.attach_file,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: _pickImage,
                      ),
                      IconButton(
                        icon: _isUploadingImage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF090A4F),
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.send,
                                color:
                                    (_messageController.text.isNotEmpty ||
                                        _selectedImage != null ||
                                        _selectedImageBytes != null)
                                    ? const Color(0xFF090A4F)
                                    : Colors.grey.shade400,
                              ),
                        onPressed:
                            (_isUploadingImage ||
                                (_messageController.text.isEmpty &&
                                    _selectedImage == null &&
                                    _selectedImageBytes == null))
                            ? null
                            : _sendMessage,
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
