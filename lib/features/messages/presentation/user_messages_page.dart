import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/messages/application/message_actions.dart';
import 'package:alumni_system/features/messages/application/message_attachment_uploader.dart';
import 'package:alumni_system/features/messages/application/message_image_picker.dart';
import 'package:alumni_system/features/messages/application/message_thread_history.dart';
import 'package:alumni_system/features/messages/data/message_image_pipeline.dart';
import 'package:alumni_system/features/messages/data/message_realtime.dart';
import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/features/messages/widgets/message_bubble.dart';
import 'package:alumni_system/features/messages/widgets/message_composer.dart';
import 'package:alumni_system/features/messages/widgets/message_empty_state.dart';
import 'package:alumni_system/features/messages/widgets/message_reaction_picker.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/features/messages/widgets/message_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

class UserMessagesScreen extends StatefulWidget {
  const UserMessagesScreen({super.key, this.isTabActive = false});

  /// True when the bottom-nav Messages tab is selected ([MainNavigation]).
  final bool isTabActive;

  @override
  State<UserMessagesScreen> createState() => _UserMessagesScreenState();
}

class _UserMessagesScreenState extends State<UserMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final MessageService _messageService = MessageService();
  final MessageImagePipeline _imagePipeline = MessageImagePipeline();
  final MessageImagePicker _imagePicker = MessageImagePicker();

  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserEmail;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;
  double? _uploadProgress;
  bool _uploadFailed = false;
  String? _userDocId;
  Set<String> _userIdentityIds = {};
  StreamSubscription<List<ConversationMessage>>? _messagesSubscription;
  bool _markedReadThisVisit = false;
  final ScrollController _scrollController = ScrollController();
  bool _showNewMessagesButton = false;
  int _pendingNewMessageCount = 0;

  // Image handling
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  final Map<String, Uint8List> _decodedImagesCache = {};
  static const int _maxDecodedImages = 24;
  final Map<String, Map<String, dynamic>> _failedMessageDrafts = {};

  /// History beyond the live newest window (Part 8 pagination).
  final Map<String, Map<String, dynamic>> _olderById = {};
  bool _hasMoreHistory = true;
  bool _loadingOlder = false;

  Uint8List _getCachedImageBytes(String messageDocId, String imageUrl) {
    final existing = _decodedImagesCache.remove(messageDocId);
    if (existing != null) {
      _decodedImagesCache[messageDocId] = existing;
      return existing;
    }
    final bytes = base64Decode(imageUrl.split(',').last);
    _decodedImagesCache[messageDocId] = bytes;
    while (_decodedImagesCache.length > _maxDecodedImages) {
      _decodedImagesCache.remove(_decodedImagesCache.keys.first);
    }
    return bytes;
  }

  void _scrollToLatestMessage({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    // ListView is `reverse: true`, so offset 0 is the latest (bottom).
    if (animated) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  bool _isNearLatestMessages({double threshold = 80}) {
    if (!_scrollController.hasClients) return true;
    // reverse:true â€” near latest when pixels are close to 0
    return _scrollController.position.pixels <= threshold;
  }

  void _upsertLocalMessage(Map<String, dynamic> message) {
    final docId = (message['docId'] as String?) ?? (message['id'] as String?);
    if (docId == null || docId.isEmpty) return;

    setState(() {
      final index = _messages.indexWhere(
        (m) => (m['docId'] ?? m['id']) == docId,
      );
      if (index >= 0) {
        _messages[index] = {..._messages[index], ...message, 'docId': docId};
      } else {
        _messages.insert(0, {...message, 'docId': docId});
      }

      _messages.sort((a, b) {
        final timeA =
            (a['timestamp'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final timeB =
            (b['timestamp'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToLatestMessage();
    });
  }

  /// Merge live newest window with paginated older history + optimistic rows.
  List<Map<String, dynamic>> _mergeServerMessages(
    List<Map<String, dynamic>> server,
  ) {
    return MessageThreadHistory.mergeWindow(
      serverWindow: server,
      olderById: _olderById,
      currentMessages: _messages,
      preserveOptimistic: true,
      newestFirst: true,
    );
  }

  DateTime? _oldestLoadedTimestamp() =>
      MessageThreadHistory.oldestTimestamp(_messages);

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreHistory || _isLoading) return;
    final before = _oldestLoadedTimestamp();
    if (before == null) return;

    setState(() => _loadingOlder = true);
    try {
      final page = await _messageService.loadOlderUserAdminConversation(
        before: before,
      );
      if (!mounted) return;
      setState(() {
        _messages = MessageThreadHistory.applyOlderPage(
          currentMessages: _messages,
          olderById: _olderById,
          olderPage: page.messages.map(
            (item) => {...item.data, 'docId': item.docId},
          ),
          newestFirst: true,
        );
        _hasMoreHistory = page.hasMore;
        _loadingOlder = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = AppSession.userId;
    _currentUserName =
        AppSession.currentUser?.userMetadata?['display_name'] as String?;
    _currentUserEmail = AppSession.email;
    _scrollController.addListener(_onScrollForNewMessages);
    _initialize();
    _messageController.addListener(() {
      setState(() {});
    });
  }

  void _onScrollForNewMessages() {
    if (_isNearLatestMessages()) {
      if (_showNewMessagesButton || _pendingNewMessageCount > 0) {
        setState(() {
          _showNewMessagesButton = false;
          _pendingNewMessageCount = 0;
        });
      }
    }
    _maybeLoadOlderOnScroll();
  }

  void _maybeLoadOlderOnScroll() {
    if (!_scrollController.hasClients) return;
    if (_loadingOlder || !_hasMoreHistory) return;
    final pos = _scrollController.position;
    // reverse:true — top of history is near maxScrollExtent
    if (pos.maxScrollExtent - pos.pixels <= 120) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _initialize() async {
    await _loadIdentityIds();
    _startMessagesListener();
  }

  Future<void> _loadIdentityIds() async {
    if (_currentUserId == null) return;
    try {
      final ids = await _messageService.resolveCurrentUserIds();
      _userIdentityIds = ids;
      for (final id in ids) {
        if (id != _currentUserId) {
          _userDocId = id;
          break;
        }
      }
    } catch (_) {
      // ignore lookup errors
    }
  }

  Future<void> _markAdminMessagesAsRead() async {
    if (!widget.isTabActive) return;
    try {
      await _messageService.markAdminMessagesAsRead();
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }

  void _tryMarkAdminMessagesAsReadIfNeeded() {
    if (!widget.isTabActive || _markedReadThisVisit) return;
    final hasUnreadFromAdmin = _messages.any((m) {
      if ((m['senderRole'] as String?)?.toLowerCase() != 'admin') return false;
      return m['isRead'] != true;
    });
    if (!hasUnreadFromAdmin) return;
    _markedReadThisVisit = true;
    _markAdminMessagesAsRead();
  }

  @override
  void didUpdateWidget(UserMessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isTabActive) {
      _markedReadThisVisit = false;
      return;
    }
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _tryMarkAdminMessagesAsReadIfNeeded();
    }
  }

  void _startMessagesListener() {
    if (_currentUserId == null) return;

    _messagesSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _olderById.clear();
      _hasMoreHistory = true;
    });

    _messagesSubscription = _messageService.watchUserAdminConversation().listen(
      (items) {
        if (!mounted) return;

        final wasNearLatest = _isNearLatestMessages();
        final previousCount = _messages.length;
        final filteredMessages = items
            .map((m) => {...m.data, 'docId': m.docId})
            .toList();
        final merged = _mergeServerMessages(filteredMessages);
        final fingerprint = MessageRealtime.legacyListFingerprint(merged);
        final previousFingerprint = MessageRealtime.legacyListFingerprint(
          _messages,
        );
        if (fingerprint == previousFingerprint && !_isLoading) {
          return;
        }

        final grew = merged.length > previousCount;
        final incomingWhileReading =
            grew && !wasNearLatest && previousCount > 0;

        setState(() {
          _messages = merged;
          _isLoading = false;
          _hasMoreHistory = MessageThreadHistory.inferHasMoreHistory(
            windowLength: filteredMessages.length,
            olderEmpty: _olderById.isEmpty,
          );
          if (incomingWhileReading) {
            _showNewMessagesButton = true;
            _pendingNewMessageCount += merged.length - previousCount;
          } else if (wasNearLatest) {
            _showNewMessagesButton = false;
            _pendingNewMessageCount = 0;
          }
        });

        _tryMarkAdminMessagesAsReadIfNeeded();

        if (wasNearLatest || previousCount == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollToLatestMessage(animated: previousCount > 0 && grew);
            }
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  void _jumpToNewMessages() {
    setState(() {
      _showNewMessagesButton = false;
      _pendingNewMessageCount = 0;
    });
    _scrollToLatestMessage();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pick(context);
    if (picked == null || !mounted) return;
    setState(() {
      _selectedImage = picked.file;
      _selectedImageBytes = picked.bytes;
      _uploadFailed = false;
      _uploadProgress = null;
    });
  }

  Future<String?> _uploadImage(String messageId) async {
    if (_selectedImage == null && _selectedImageBytes == null) return null;

    return MessageAttachmentUploader.upload(
      pipeline: _imagePipeline,
      messageId: messageId,
      file: _selectedImage,
      bytes: _selectedImageBytes,
      onState: (state) {
        if (!mounted) return;
        setState(() {
          _isUploadingImage = state.isUploading;
          _uploadProgress = state.progress;
          _uploadFailed = state.failed;
        });
      },
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final trimmedText = _messageController.text.trim();

    if ((trimmedText.isEmpty &&
            _selectedImage == null &&
            _selectedImageBytes == null) ||
        _currentUserId == null) {
      return;
    }

    if (_isUploadingImage) return;

    final tempImage = _selectedImage;
    final tempImageBytes = _selectedImageBytes;
    final hasImage = tempImage != null || tempImageBytes != null;

    final messageText = trimmedText;
    String? messageId;
    String? imageUrl;

    try {
      final admin = await _messageService.resolvePrimaryAdminContact();
      if (admin == null) {
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

      final userIds = await _messageService.resolveCurrentUserIds();
      String? senderDocId = _userDocId;
      for (final id in userIds) {
        if (id != _currentUserId) {
          senderDocId = id;
          break;
        }
      }

      messageId = LocalId.generate();

      if (hasImage) {
        imageUrl = await _uploadImage(messageId);
        if (imageUrl == null) return;
      }

      _messageController.clear();
      final now = DateTime.now();

      _upsertLocalMessage({
        'id': messageId,
        'docId': messageId,
        'senderId': _currentUserId,
        'senderDocId': senderDocId,
        'senderName': _currentUserName ?? 'User',
        'senderEmail': _currentUserEmail ?? '',
        'senderRole': 'user',
        'recipientId': admin.authUid,
        'recipientDocId': admin.docId,
        'messageText': messageText,
        'imageUrl': imageUrl,
        'timestamp': now,
        'isRead': false,
        'reactions': <String, List<String>>{},
        'optimistic': true,
        'sendStatus': 'sending',
      });

      await _messageService.sendMessage(
        messageId: messageId,
        senderId: _currentUserId!,
        senderDocId: senderDocId,
        senderName: _currentUserName ?? 'User',
        senderEmail: _currentUserEmail ?? '',
        senderRole: 'user',
        recipientId: admin.authUid,
        recipientDocId: admin.docId,
        messageText: messageText,
        imageUrl: imageUrl,
        reactions: <String, List<String>>{},
        timestamp: now,
      );

      _failedMessageDrafts.remove(messageId);
      _upsertLocalMessage({
        'docId': messageId,
        'optimistic': false,
        'sendStatus': 'sent',
        'isRead': false,
      });

      if (mounted) {
        setState(() {
          _selectedImage = null;
          _selectedImageBytes = null;
          _uploadFailed = false;
          _uploadProgress = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final failedId = messageId;
        if (failedId != null) {
          final existing = _messages.cast<Map<String, dynamic>?>().firstWhere(
            (m) => (m?['docId'] ?? m?['id']) == failedId,
            orElse: () => null,
          );
          if (existing != null) {
            _failedMessageDrafts[failedId] = Map<String, dynamic>.from(
              existing,
            );
          }
          _upsertLocalMessage({
            'docId': failedId,
            'optimistic': true,
            'sendStatus': 'failed',
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _selectedImage = tempImage;
          _selectedImageBytes = tempImageBytes;
        });
      }
    }
  }

  Future<void> _retryFailedMessage(Map<String, dynamic> message) async {
    final docId = message['docId'] as String? ?? message['id'] as String?;
    if (docId == null) return;
    final draft = _failedMessageDrafts[docId] ?? message;
    _messageController.text = draft['messageText'] as String? ?? '';
    // Re-send via normal path after marking status sending.
    _upsertLocalMessage({'docId': docId, 'sendStatus': 'sending'});
    try {
      final admin = await _messageService.resolvePrimaryAdminContact();
      if (admin == null) return;
      await _messageService.sendMessage(
        messageId: docId,
        senderId: _currentUserId!,
        senderDocId: draft['senderDocId'] as String?,
        senderName:
            draft['senderName'] as String? ?? _currentUserName ?? 'User',
        senderEmail: draft['senderEmail'] as String? ?? _currentUserEmail ?? '',
        senderRole: 'user',
        recipientId: admin.authUid,
        recipientDocId: admin.docId,
        messageText: draft['messageText'] as String? ?? '',
        imageUrl: draft['imageUrl'] as String?,
        reactions: <String, List<String>>{},
        timestamp: draft['timestamp'] as DateTime? ?? DateTime.now(),
      );
      _failedMessageDrafts.remove(docId);
      _upsertLocalMessage({
        'docId': docId,
        'sendStatus': 'sent',
        'optimistic': false,
        'isRead': false,
      });
      _messageController.clear();
    } catch (e) {
      _upsertLocalMessage({'docId': docId, 'sendStatus': 'failed'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retry failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    await MessageActions.editOwnMessage(
      context: context,
      service: _messageService,
      message: message,
      isOwner: message['senderId'] == _currentUserId,
    );
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    await MessageActions.deleteOwnMessage(
      context: context,
      service: _messageService,
      message: message,
      isOwner: message['senderId'] == _currentUserId,
    );
  }

  Future<void> _addReaction(String messageDocId, String emoji) async {
    if (_currentUserId == null) return;
    await MessageActions.toggleReaction(
      context: context,
      service: _messageService,
      messageId: messageDocId,
      actorUserId: _currentUserId!,
      emoji: emoji,
    );
  }

  void _showMessageOptions(
    BuildContext context,
    Map<String, dynamic> message,
    String messageDocId,
  ) {
    final isCurrentUser = message['senderId'] == _currentUserId;
    final text = message['messageText'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      builder: (context) => PortalOptionsSheet(
        children: [
          PortalSheetOption(
            label: 'Add reaction',
            icon: Icons.add_reaction_outlined,
            onTap: () {
              Navigator.pop(context);
              _showReactionPicker(context, messageDocId);
            },
          ),
          if (text.trim().isNotEmpty)
            PortalSheetOption(
              label: 'Copy message',
              icon: Icons.copy_outlined,
              onTap: () {
                Navigator.pop(context);
                copyMessageText(context, text);
              },
            ),
          if (isCurrentUser) ...[
            PortalSheetOption(
              label: 'Edit message',
              icon: Icons.edit_outlined,
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
            PortalSheetOption(
              label: 'Delete message',
              icon: Icons.delete_outline_rounded,
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context, String messageDocId) {
    showMessageReactionPicker(
      context: context,
      onSelected: (emoji) => _addReaction(messageDocId, emoji),
    );
  }

  void _showImageFullScreen(
    BuildContext context,
    String imageUrl, [
    String? messageDocId,
  ]) {
    showMessageImageViewer(
      context: context,
      imageUrl: imageUrl,
      decodedBytes:
          imageUrl.startsWith('data:') &&
              messageDocId != null &&
              messageDocId.isNotEmpty
          ? _getCachedImageBytes(messageDocId, imageUrl)
          : null,
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _scrollController.removeListener(_onScrollForNewMessages);
    _scrollController.dispose();
    _messageController.dispose();
    _markedReadThisVisit = false;
    super.dispose();
  }

  MessageSendStatus _statusFor(Map<String, dynamic> msg) {
    switch (msg['sendStatus']) {
      case 'sending':
        return MessageSendStatus.sending;
      case 'failed':
        return MessageSendStatus.failed;
      default:
        return MessageSendStatus.sent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MessageTheme.pageBg,
      appBar: PortalAppBar(
        title: MessageTheme.officeDisplayName,
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      body: Column(
        children: [
          Expanded(
            child: PortalContentFrame(
              maxWidth: PortalBreakpoints.chatMax,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    ColoredBox(
                      color: MessageTheme.pageBg,
                      child: _isLoading
                          ? const MessageThreadSkeleton()
                          : _messages.isEmpty
                          ? const MessageEmptyState()
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.all(
                                MessageTheme.threadPadding,
                              ),
                              itemCount:
                                  _messages.length +
                                  (_hasMoreHistory || _loadingOlder ? 1 : 0),
                              addAutomaticKeepAlives: false,
                              itemBuilder: (context, index) {
                                if (index >= _messages.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Center(
                                      child: _loadingOlder
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : TextButton(
                                              onPressed: _loadOlderMessages,
                                              child: const Text(
                                                'Load earlier messages',
                                              ),
                                            ),
                                    ),
                                  );
                                }
                                final msg = _messages[index];
                                final isCurrentUser = _messageService
                                    .isUserSender(msg, _userIdentityIds);
                                final timestamp =
                                    (msg['timestamp'] as DateTime?) ??
                                    DateTime.now();
                                final older = index + 1 < _messages.length
                                    ? _messages[index + 1]
                                    : null;
                                final olderTs =
                                    older?['timestamp'] as DateTime?;
                                final showDateSep =
                                    olderTs == null ||
                                    !isSameMessageCalendarDay(
                                      timestamp,
                                      olderTs,
                                    );
                                final imageUrl = msg['imageUrl'] as String?;
                                final messageText =
                                    msg['messageText'] as String? ?? '';
                                final messageDocId =
                                    msg['docId'] as String? ?? '';
                                final reactions = Map<String, dynamic>.from(
                                  msg['reactions'] ?? {},
                                );
                                final isEdited = msg['isEdited'] == true;

                                return Column(
                                  children: [
                                    if (showDateSep)
                                      MessageDateSeparator(
                                        label: formatMessageDateLabel(
                                          timestamp,
                                        ),
                                      ),
                                    MessageBubble(
                                      isMine: isCurrentUser,
                                      body: messageText,
                                      timestamp: timestamp,
                                      imageUrl: imageUrl,
                                      imageBytes:
                                          imageUrl != null &&
                                              imageUrl.startsWith('data:') &&
                                              messageDocId.isNotEmpty
                                          ? _getCachedImageBytes(
                                              messageDocId,
                                              imageUrl,
                                            )
                                          : null,
                                      reactions: reactions,
                                      currentUserId: _currentUserId,
                                      isEdited: isEdited,
                                      status: _statusFor(msg),
                                      isRead: msg['isRead'] == true,
                                      optimistic: msg['optimistic'] == true,
                                      onLongPress: () {
                                        if (messageDocId.isNotEmpty) {
                                          _showMessageOptions(
                                            context,
                                            msg,
                                            messageDocId,
                                          );
                                        }
                                      },
                                      onReact: (emoji) {
                                        if (messageDocId.isNotEmpty) {
                                          _addReaction(messageDocId, emoji);
                                        }
                                      },
                                      onOpenImage: imageUrl == null
                                          ? null
                                          : () => _showImageFullScreen(
                                              context,
                                              imageUrl,
                                              messageDocId,
                                            ),
                                      onRetry: () => _retryFailedMessage(msg),
                                      onCopy: messageText.trim().isEmpty
                                          ? null
                                          : () => copyMessageText(
                                              context,
                                              messageText,
                                            ),
                                      onEdit: isCurrentUser
                                          ? () => _editMessage(msg)
                                          : null,
                                      onDelete: isCurrentUser
                                          ? () => _deleteMessage(msg)
                                          : null,
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    if (_showNewMessagesButton)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(
                          child: MessageNewMessagesButton(
                            count: _pendingNewMessageCount > 1
                                ? _pendingNewMessageCount
                                : null,
                            onPressed: _jumpToNewMessages,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          MessageComposer(
            maxContentWidth: PortalBreakpoints.chatMax,
            controller: _messageController,
            isUploading: _isUploadingImage,
            uploadProgress: _uploadProgress,
            uploadFailed: _uploadFailed,
            selectedImage: _selectedImage,
            selectedImageBytes: _selectedImageBytes,
            onPickImage: _pickImage,
            onRetryUpload: _sendMessage,
            onClearImage: () {
              setState(() {
                _selectedImage = null;
                _selectedImageBytes = null;
                _uploadFailed = false;
                _uploadProgress = null;
              });
            },
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
