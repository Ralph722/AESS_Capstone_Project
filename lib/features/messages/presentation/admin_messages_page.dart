import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/messages/application/message_actions.dart';
import 'package:alumni_system/features/messages/application/message_attachment_uploader.dart';
import 'package:alumni_system/features/messages/application/message_image_picker.dart';
import 'package:alumni_system/features/messages/application/message_thread_history.dart';
import 'package:alumni_system/features/messages/data/message_image_pipeline.dart';
import 'package:alumni_system/features/messages/data/message_open_bus.dart';
import 'package:alumni_system/features/messages/data/message_realtime.dart';
import 'package:alumni_system/features/messages/application/admin_conversation_watch.dart';
import 'package:alumni_system/features/messages/data/message_service.dart';
import 'package:alumni_system/features/messages/models/message_filters.dart';
import 'package:alumni_system/features/messages/widgets/admin_compose_picker.dart';
import 'package:alumni_system/features/messages/widgets/admin_message_ui.dart';
import 'package:alumni_system/features/messages/widgets/message_bubble.dart';
import 'package:alumni_system/features/messages/widgets/message_composer.dart';
import 'package:alumni_system/features/messages/widgets/message_empty_state.dart';
import 'package:alumni_system/features/messages/widgets/message_reaction_picker.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/features/messages/widgets/message_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

class AdminMessagesScreen extends StatefulWidget {
  final bool hideAppBar;
  final MessageService? service;
  final MessageImagePipeline? imagePipeline;
  final MessageImagePicker? imagePicker;
  final String? currentUserIdOverride;
  final String? currentUserNameOverride;
  final String? currentUserEmailOverride;

  const AdminMessagesScreen({
    super.key,
    this.hideAppBar = false,
    this.service,
    this.imagePipeline,
    this.imagePicker,
    this.currentUserIdOverride,
    this.currentUserNameOverride,
    this.currentUserEmailOverride,
  });

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  late final MessageImagePipeline _imagePipeline =
      widget.imagePipeline ?? MessageImagePipeline();
  late final MessageImagePicker _imagePicker =
      widget.imagePicker ?? MessageImagePicker();
  late final MessageService _messageService =
      widget.service ?? MessageService();

  String? _currentAdminId;
  String? _currentAdminName;
  String? _currentAdminEmail;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _conversationUsers = [];
  List<Map<String, dynamic>> _filteredConversations = [];

  bool _isLoadingMessages = false;
  bool _isLoadingUsers = false;
  String? _inboxError;
  String? _threadError;
  bool _isUploadingImage = false;
  double? _uploadProgress;
  bool _uploadFailed = false;

  String? _selectedUserId;
  String? _selectedUserDocId;
  String? _selectedUserName;
  /// Conversation id currently bound to [_conversationSubscription].
  /// Kept separate from [_selectedUserId] so switching alumni after selection
  /// still tears down the previous watch (selection updates first).
  String? _watchingUserId;
  String? _watchingUserDocId;
  bool _isChatOpenOnMobile = false;
  String? _adminDocId;
  final ScrollController _messagesScrollController = ScrollController();
  Timer? _scrollTimer;
  double _lastMaxScrollExtent = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _inboxSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _conversationSubscription;
  StreamSubscription<String>? _openConversationSubscription;
  bool _markingReadInFlight = false;
  MessageInboxQuery _inboxQuery = const MessageInboxQuery();
  bool _showProfilePanel = true;
  AlumniMessageProfile? _selectedProfile;

  // Image handling
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  final Map<String, Map<String, dynamic>> _olderById = {};
  bool _hasMoreHistory = true;
  bool _loadingOlder = false;
  final Set<String> _reactionBusy = {};

  @override
  void initState() {
    super.initState();
    _currentAdminId = widget.currentUserIdOverride ?? AppSession.userId;
    _currentAdminName = widget.currentUserNameOverride ??
        AppSession.currentUser?.userMetadata?['display_name'] as String?;
    _currentAdminEmail = widget.currentUserEmailOverride ?? AppSession.email;
    _adminDocId = _currentAdminId;
    _startInboxWatch();
    _openConversationSubscription =
        MessageOpenBus.stream.listen(_openConversationFromDeepLink);
    final pending = MessageOpenBus.takePending();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openConversationFromDeepLink(pending);
      });
    }
    // Add listener to detect when scroll extent changes (images loading)
    _messagesScrollController.addListener(_onScrollChanged);
    // Add listener to text controller to update button state
    _messageController.addListener(() {
      setState(() {}); // Force rebuild when text changes
    });
  }

  void _onScrollChanged() {
    if (_messagesScrollController.hasClients) {
      final currentMax = _messagesScrollController.position.maxScrollExtent;
      // If max scroll extent increased, images likely loaded
      if (currentMax > _lastMaxScrollExtent + 10) {
        _lastMaxScrollExtent = currentMax;
        // Auto-scroll if user is near bottom
        final currentScroll = _messagesScrollController.position.pixels;
        if ((currentMax - currentScroll) < 200) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _messagesScrollController.hasClients) {
              try {
                _messagesScrollController.animateTo(
                  _messagesScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              } catch (e) {
                // Ignore errors
              }
            }
          });
        }
      }
      // Near top → load older history (oldest-first list)
      if (_messagesScrollController.position.pixels <= 80) {
        unawaited(_loadOlderMessages());
      }
    }
  }

  DateTime? _oldestLoadedTimestamp() =>
      MessageThreadHistory.oldestTimestamp(_messages);

  List<Map<String, dynamic>> _mergeAdminThreadWindow(
    List<Map<String, dynamic>> serverWindow,
  ) {
    return MessageThreadHistory.mergeWindow(
      serverWindow: serverWindow,
      olderById: _olderById,
      newestFirst: false,
    );
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreHistory || _isLoadingMessages) return;
    final userId = _selectedUserId;
    if (userId == null || userId.isEmpty) return;
    final before = _oldestLoadedTimestamp();
    if (before == null) return;

    setState(() => _loadingOlder = true);
    try {
      final page = await _messageService.loadOlderAdminConversation(
        userId,
        userDocId: _selectedUserDocId,
        before: before,
      );
      if (!mounted) return;
      setState(() {
        _messages = MessageThreadHistory.applyOlderPage(
          currentMessages: _messages,
          olderById: _olderById,
          olderPage: page.messages,
          newestFirst: false,
        );
        _hasMoreHistory = page.hasMore;
        _loadingOlder = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _startInboxWatch() {
    _inboxSubscription?.cancel();
    setState(() {
      _isLoadingUsers = true;
      _inboxError = null;
    });

    _inboxSubscription = _messageService.watchAdminInbox().listen(
      (conversations) {
        if (!mounted) return;
        setState(() {
          _conversationUsers = _mergeComposeStubs(conversations);
          _filteredConversations =
              applyInboxQuery(_conversationUsers, _inboxQuery);
          _isLoadingUsers = false;
          _inboxError = null;
          _syncSelectedProfile();
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLoadingUsers = false;
          _inboxError = '$error';
        });
      },
    );
  }

  /// Keep admin-started drafts in the inbox until the first message lands.
  List<Map<String, dynamic>> _mergeComposeStubs(
    List<Map<String, dynamic>> server,
  ) {
    final byId = <String, Map<String, dynamic>>{
      for (final row in server)
        if ((row['messagingId'] as String?)?.isNotEmpty == true)
          row['messagingId'] as String: row,
    };

    for (final row in _conversationUsers) {
      if (row['composeDraft'] != true) continue;
      final id = row['messagingId'] as String? ?? '';
      if (id.isEmpty || byId.containsKey(id)) continue;
      byId[id] = row;
    }

    if (_selectedUserId != null &&
        _selectedUserId!.isNotEmpty &&
        !byId.containsKey(_selectedUserId)) {
      final stub = _selectedProfile?.userId == _selectedUserId
          ? {
              'messagingId': _selectedUserId,
              'docId': _selectedUserDocId ?? _selectedUserId,
              'name': _selectedProfile?.name ?? _selectedUserName ?? 'Alumni',
              'email': _selectedProfile?.email ?? '',
              'program': _selectedProfile?.program ?? '',
              'batch': _selectedProfile?.batch ?? '',
              'avatarUrl': _selectedProfile?.avatarUrl,
              'lastMessage': '',
              'lastMessageTime': null,
              'isRead': true,
              'lastMessageFromRole': '',
              'tracerComplete': _selectedProfile?.tracerComplete ?? false,
              'lastActive': _selectedProfile?.lastActive,
              'registrationLabel':
                  _selectedProfile?.registrationLabel ?? 'Registered',
              'composeDraft': true,
            }
          : null;
      if (stub != null) byId[_selectedUserId!] = stub;
    }

    final merged = byId.values.toList()
      ..sort((a, b) {
        final timeA = (a['lastMessageTime'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = (b['lastMessageTime'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (a['composeDraft'] == true && b['composeDraft'] != true) {
          return -1;
        }
        if (b['composeDraft'] == true && a['composeDraft'] != true) {
          return 1;
        }
        return timeB.compareTo(timeA);
      });
    return merged;
  }

  Future<void> _openComposePicker() async {
    final contact = await showAdminComposeAlumniPicker(
      context: context,
      messageService: _messageService,
    );
    if (!mounted || contact == null) return;
    _startConversationWithContact(contact);
  }

  void _startConversationWithContact(RegisteredAlumniContact contact) {
    final existing = _conversationUsers.cast<Map<String, dynamic>?>().firstWhere(
          (u) =>
              u?['messagingId'] == contact.authUid ||
              u?['docId'] == contact.authUid,
          orElse: () => null,
        );
    if (existing != null) {
      _selectConversation(existing);
      return;
    }

    final stub = contact.toConversationStub();
    setState(() {
      _conversationUsers = _mergeComposeStubs([stub, ..._conversationUsers]);
      _filteredConversations =
          applyInboxQuery(_conversationUsers, _inboxQuery);
    });
    _selectConversation(stub);
  }

  void _applyInboxQuery(MessageInboxQuery query) {
    setState(() {
      _inboxQuery = query;
      _filteredConversations =
          applyInboxQuery(_conversationUsers, _inboxQuery);
    });
  }

  void _syncSelectedProfile() {
    if (_selectedUserId == null) {
      _selectedProfile = null;
      return;
    }
    final row = _conversationUsers.cast<Map<String, dynamic>?>().firstWhere(
          (u) => u?['messagingId'] == _selectedUserId,
          orElse: () => null,
        );
    if (row != null) {
      _selectedProfile = AlumniMessageProfile.fromConversationRow(row);
      _selectedUserName = _selectedProfile!.name;
    }
  }

  void _searchConversations(String query) {
    _applyInboxQuery(_inboxQuery.copyWith(search: query));
  }

  bool _isNearConversationBottom({double threshold = 160}) {
    if (!_messagesScrollController.hasClients) return true;
    final pos = _messagesScrollController.position;
    return (pos.maxScrollExtent - pos.pixels) <= threshold;
  }

  void _startConversationWatch(
    String userMessagingId, {
    String? userDocId,
  }) {
    if (userMessagingId.isEmpty && (userDocId == null || userDocId.isEmpty)) {
      return;
    }

    // Compare against the watched id — not [_selectedUserId], which is already
    // updated before this method runs on conversation switch.
    final alreadyWatching = isAlreadyWatchingAdminConversation(
      hasActiveSubscription:
          _conversationSubscription != null && _threadError == null,
      watchingMessagingId: _watchingUserId,
      requestedMessagingId: userMessagingId,
      watchingDocId: _watchingUserDocId,
      requestedDocId: userDocId,
    );
    if (alreadyWatching) {
      unawaited(_markSelectedConversationRead());
      return;
    }

    _stopConversationWatch(clearMessages: false);

    setState(() {
      _isLoadingMessages = true;
      _threadError = null;
      _messages = [];
      _olderById.clear();
      _hasMoreHistory = true;
      _loadingOlder = false;
    });

    _watchingUserId = userMessagingId;
    _watchingUserDocId = userDocId;

    _conversationSubscription = _messageService
        .watchAdminConversation(userMessagingId, userDocId: userDocId)
        .listen(
      (filteredMessages) {
        if (!mounted) return;
        // Drop late emits from a previous conversation after a switch.
        if (!isAdminConversationEmitStillSelected(
          selectedMessagingId: _selectedUserId,
          emitMessagingId: userMessagingId,
          selectedDocId: _selectedUserDocId,
          emitDocId: userDocId,
        )) {
          return;
        }

        final wasNearBottom = _isNearConversationBottom();
        final wasEmpty = _messages.isEmpty;
        final previousCount = _messages.length;
        final merged = _mergeAdminThreadWindow(filteredMessages);
        final fp = MessageRealtime.legacyListFingerprint(merged);
        final prevFp = MessageRealtime.legacyListFingerprint(_messages);
        if (fp == prevFp && !_isLoadingMessages && _threadError == null) {
          return;
        }

        setState(() {
          _messages = merged;
          _isLoadingMessages = false;
          _threadError = null;
          _hasMoreHistory = MessageThreadHistory.inferHasMoreHistory(
            windowLength: filteredMessages.length,
            olderEmpty: _olderById.isEmpty,
          );
        });

        unawaited(_markSelectedConversationRead());

        final grew = merged.length > previousCount;
        if (wasEmpty || (wasNearBottom && grew)) {
          _scrollToBottom(immediate: wasEmpty);
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _isLoadingMessages = false;
          _threadError = '$error';
        });
      },
    );
  }

  void _stopConversationWatch({bool clearMessages = true}) {
    _conversationSubscription?.cancel();
    _conversationSubscription = null;
    _watchingUserId = null;
    _watchingUserDocId = null;
    if (clearMessages) {
      _messages = [];
      _olderById.clear();
      _hasMoreHistory = true;
      _loadingOlder = false;
      _isLoadingMessages = false;
      _threadError = null;
    }
  }

  Future<void> _markSelectedConversationRead() async {
    final userMessagingId = _selectedUserId;
    if (userMessagingId == null || userMessagingId.isEmpty) return;
    if (_markingReadInFlight) return;

    final hasUnread = _messages.any((m) {
      final role = (m['senderRole'] as String?)?.toLowerCase();
      return role == 'user' && m['isRead'] != true;
    });
    if (!hasUnread) return;

    _markingReadInFlight = true;
    try {
      await _messageService.markUserMessagesAsReadForAdmin(
        userMessagingId,
        userDocId: _selectedUserDocId,
      );
    } catch (_) {
      // ignore â€” inbox watch will refresh later
    } finally {
      _markingReadInFlight = false;
    }
  }

  void _loadMessagesForUser(String userMessagingId, {String? userDocId}) {
    _startConversationWatch(userMessagingId, userDocId: userDocId);
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pick(
      context,
      galleryOnly: kIsWeb || adminIsWideSurface(context),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedImage = picked.file;
      _selectedImageBytes = picked.bytes;
      _uploadFailed = false;
      _uploadProgress = null;
    });
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AdminColors.danger),
      );
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
      onError: _showErrorSnack,
    );
  }

  Future<void> _sendMessage() async {
    final trimmedText = _messageController.text.trim();

    if ((trimmedText.isEmpty &&
            _selectedImage == null &&
            _selectedImageBytes == null) ||
        _currentAdminId == null ||
        (_selectedUserId == null && _selectedUserDocId == null)) {
      return;
    }

    if (_isUploadingImage) return;

    final tempImage = _selectedImage;
    final tempImageBytes = _selectedImageBytes;
    final hasImage = tempImage != null || tempImageBytes != null;
    final messageText = trimmedText;
    String? imageUrl;
    String? messageId;

    try {
      final recipientAuthUid = _selectedUserId ?? _selectedUserDocId ?? '';
      if (recipientAuthUid.isEmpty) return;

      messageId = LocalId.generate();

      if (hasImage) {
        imageUrl = await _uploadImage(messageId);
        if (imageUrl == null) return;
      }

      _messageController.clear();

      await _messageService.sendMessage(
        messageId: messageId,
        senderId: _currentAdminId!,
        senderDocId: _adminDocId,
        senderName: _currentAdminName ?? 'Admin',
        senderEmail: _currentAdminEmail ?? '',
        senderRole: 'admin',
        recipientId: recipientAuthUid,
        recipientDocId: _selectedUserDocId,
        messageText: messageText,
        imageUrl: imageUrl,
        reactions: <String, List<String>>{},
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _selectedImage = null;
          _selectedImageBytes = null;
          _uploadFailed = false;
          _uploadProgress = null;
        });
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('[AdminMessagesScreen] Send message failed: $e');
      if (imageUrl != null) {
        await _messageService.discardUploadedMessageImage(imageUrl);
      }
      if (mounted) {
        _showErrorSnack(
          messageFriendlyError(e, 'Could not send message. Please try again.'),
        );
        setState(() {
          _selectedImage = tempImage;
          _selectedImageBytes = tempImageBytes;
        });
      }
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    // Check if there are images in the last few messages (check last 5 messages)
    final hasRecentImages =
        _messages.isNotEmpty &&
        _messages
            .reversed
            .take(5)
            .any(
              (msg) =>
                  msg['imageUrl'] != null &&
                  msg['imageUrl'].toString().isNotEmpty,
            );

    // Cancel any existing scroll timer
    _scrollTimer?.cancel();

    // Use multiple postFrameCallbacks to ensure ListView is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messagesScrollController.hasClients) {
        // Update last max scroll extent
        _lastMaxScrollExtent = _messagesScrollController.position.maxScrollExtent;

        // For initial load or when images are present, use continuous scrolling
        if (hasRecentImages) {
          // Use timer-based approach for images - scroll continuously until stable
          int attempts = 0;
          double lastMaxScroll = _messagesScrollController.position.maxScrollExtent;
          
          _scrollTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
            if (!mounted || !_messagesScrollController.hasClients) {
              timer.cancel();
              return;
            }

            attempts++;
            final currentMaxScroll = _messagesScrollController.position.maxScrollExtent;

            // Scroll to bottom
            try {
              if (immediate) {
                _messagesScrollController.jumpTo(currentMaxScroll);
              } else {
                _messagesScrollController.animateTo(
                  currentMaxScroll,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            } catch (e) {
              // Ignore errors
            }

            // Stop if scroll extent hasn't changed (images finished loading) or max attempts reached
            if ((currentMaxScroll - lastMaxScroll).abs() < 5 || attempts >= 15) {
              timer.cancel();
              // Final scroll to ensure we're at the bottom
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && _messagesScrollController.hasClients) {
                  try {
                    final finalMaxScroll = _messagesScrollController.position.maxScrollExtent;
                    if (immediate) {
                      _messagesScrollController.jumpTo(finalMaxScroll);
                    } else {
                      _messagesScrollController.animateTo(
                        finalMaxScroll,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  } catch (e) {
                    // Ignore errors
                  }
                }
              });
            } else {
              lastMaxScroll = currentMaxScroll;
            }
          });
        } else {
          // Simple scroll for text-only messages
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
      }
    });
  }

  bool _isOwnAdminMessage(Map<String, dynamic> message) {
    return message['senderId'] == _currentAdminId ||
        (message['senderDocId'] != null &&
            _adminDocId != null &&
            message['senderDocId'] == _adminDocId);
  }

  Future<void> _addReaction(String messageDocId, String emoji) async {
    if (_currentAdminId == null) return;
    final busyKey = '$messageDocId|$emoji';
    if (_reactionBusy.contains(busyKey)) return;
    _reactionBusy.add(busyKey);

    Map<String, dynamic> current = const {};
    for (final m in _messages) {
      if ((m['docId'] ?? m['id']) == messageDocId) {
        current = Map<String, dynamic>.from(m['reactions'] ?? {});
        break;
      }
    }

    try {
      await MessageActions.toggleReaction(
        context: context,
        service: _messageService,
        messageId: messageDocId,
        actorUserId: _currentAdminId!,
        emoji: emoji,
        currentReactions: current,
        onOptimistic: (reactions) {
          setState(() {
            final index = _messages.indexWhere(
              (m) => (m['docId'] ?? m['id']) == messageDocId,
            );
            if (index >= 0) {
              _messages[index] = {
                ..._messages[index],
                'reactions': reactions,
              };
            }
          });
        },
      );
    } finally {
      _reactionBusy.remove(busyKey);
    }
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    await MessageActions.editOwnMessage(
      context: context,
      service: _messageService,
      message: message,
      isOwner: _isOwnAdminMessage(message),
      showSuccessSnack: true,
    );
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    await MessageActions.deleteOwnMessage(
      context: context,
      service: _messageService,
      message: message,
      isOwner: _isOwnAdminMessage(message),
      showSuccessSnack: true,
    );
  }

  void _showMessageOptions(BuildContext context, Map<String, dynamic> message, String messageDocId) {
    final isAdmin = _isOwnAdminMessage(message);
    final text = message['messageText'] as String? ?? '';
    final imageUrl = message['imageUrl'] as String?;

    final options = <AdminPickerOption<String>>[
      const AdminPickerOption(
        value: 'react',
        label: 'Add Reaction',
        icon: Icons.add_reaction,
      ),
      if (text.trim().isNotEmpty)
        const AdminPickerOption(
          value: 'copy',
          label: 'Copy message',
          icon: Icons.copy_outlined,
        ),
      if (imageUrl != null &&
          imageUrl.trim().isNotEmpty &&
          !imageUrl.startsWith('data:'))
        const AdminPickerOption(
          value: 'copy_image',
          label: 'Copy image link',
          icon: Icons.link,
        ),
      if (isAdmin) ...[
        const AdminPickerOption(
          value: 'edit',
          label: 'Edit Message',
          icon: Icons.edit,
        ),
        const AdminPickerOption(
          value: 'delete',
          label: 'Delete Message',
          icon: Icons.delete,
        ),
      ],
    ];

    Future<void> handle(String? choice) async {
      if (choice == null) return;
      switch (choice) {
        case 'react':
          _showReactionPicker(context, messageDocId);
        case 'copy':
          await copyAdminMessageText(context, text);
        case 'copy_image':
          await copyAdminImageLink(context, imageUrl);
        case 'edit':
          _editMessage(message);
        case 'delete':
          _deleteMessage(message);
      }
    }

    if (adminIsWideSurface(context)) {
      showAdminOptionPicker<String>(
        context: context,
        title: 'Message actions',
        options: options,
      ).then(handle);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              ListTile(
                leading: Icon(opt.icon ?? Icons.more_horiz),
                title: Text(opt.label),
                onTap: () {
                  Navigator.pop(context);
                  handle(opt.value);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context, String messageDocId) {
    showMessageReactionPicker(
      context: context,
      useAdminDialog: adminIsWideSurface(context),
      onSelected: (emoji) => _addReaction(messageDocId, emoji),
    );
  }

  void _showImageFullScreen(BuildContext context, String imageUrl) {
    showMessageImageViewer(context: context, imageUrl: imageUrl);
  }

  void _selectConversation(Map<String, dynamic> user) {
    final userMessagingId = user['messagingId'] as String;
    final userDocId = user['docId'] as String?;
    setState(() {
      _selectedUserId = userMessagingId;
      _selectedUserDocId = userDocId;
      _selectedUserName = user['name'] as String? ?? 'Alumni';
      _selectedProfile = AlumniMessageProfile.fromConversationRow(user);
      _isChatOpenOnMobile = true;
    });
    _loadMessagesForUser(userMessagingId, userDocId: userDocId);
  }

  void _openConversationFromDeepLink(String userId) {
    if (userId.isEmpty) return;
    unawaited(_openConversationFromDeepLinkAsync(userId));
  }

  Future<void> _openConversationFromDeepLinkAsync(String userId) async {
    if (!mounted || userId.isEmpty) return;

    Map<String, dynamic>? row;
    for (final u in _conversationUsers) {
      if (u['messagingId'] == userId || u['docId'] == userId) {
        row = u;
        break;
      }
    }
    if (row != null) {
      _selectConversation(row);
      return;
    }

    // Not in inbox yet — open a compose-style stub (same as New message picker).
    try {
      final contact = await _messageService.resolveAlumniContact(userId);
      if (!mounted) return;
      _startConversationWithContact(contact);
    } catch (_) {
      if (!mounted) return;
      _startConversationWithContact(
        RegisteredAlumniContact(authUid: userId, name: 'Alumni'),
      );
    }
  }

  @override
  void dispose() {
    _inboxSubscription?.cancel();
    _stopConversationWatch(clearMessages: false);
    _openConversationSubscription?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _scrollTimer?.cancel();
    _messagesScrollController.removeListener(_onScrollChanged);
    _messagesScrollController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return AdminCompactHeader(
      title: 'Messages',
      actions: [
        FilledButton.icon(
          onPressed: _openComposePicker,
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('New message'),
          style: AdminButtonStyles.filled(),
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: AdminColors.card,
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
      border: Border.all(color: AdminColors.border),
      boxShadow: AdminSurfaces.cardShadow,
    );
  }

  Widget _buildInboxRefreshWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: AdminColors.warningBg,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AdminColors.warning,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Inbox sync paused.',
              style: TextStyle(fontSize: 12.5, color: AdminColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _isLoadingUsers ? null : _startInboxWatch,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxBody() {
    if (_isLoadingUsers && _filteredConversations.isEmpty) {
      return const MessageListSkeleton(count: 8, shrinkWrap: true);
    }
    if (_inboxError != null && _conversationUsers.isEmpty) {
      return AdminStateView.error(
        compact: true,
        title: "Couldn't load conversations",
        message: messageFriendlyError(
          _inboxError!,
          'Check your connection and try again.',
        ),
        details: _inboxError,
        onRetry: _startInboxWatch,
      );
    }
    if (_filteredConversations.isEmpty) {
      final hasFilters = _inboxQuery.hasActiveFilters;
      return AdminStateView.empty(
        compact: true,
        icon: hasFilters
            ? Icons.filter_alt_off_outlined
            : Icons.inbox_outlined,
        title: hasFilters ? 'No conversations match' : 'No conversations yet',
        message: hasFilters
            ? 'Try clearing filters or searching a different keyword.'
            : 'Start a message to a registered alumnus, or wait for incoming replies.',
        primaryAction: hasFilters
            ? AdminStateAction(
                label: 'Reset filters',
                icon: Icons.filter_alt_off_outlined,
                onPressed: () {
                  _searchController.clear();
                  _applyInboxQuery(const MessageInboxQuery());
                },
              )
            : AdminStateAction(
                label: 'New message',
                icon: Icons.edit_outlined,
                onPressed: _openComposePicker,
              ),
      );
    }
    return ListView.builder(
      itemCount: _filteredConversations.length,
      itemBuilder: (context, index) {
        final user = _filteredConversations[index];
        final selected = user['messagingId'] == _selectedUserId;
        return AdminConversationListTile(
          row: user,
          selected: selected,
          onTap: () => _selectConversation(user),
        );
      },
    );
  }

  Widget _buildInboxPane({double? width = AdminMessageTheme.inboxWidth}) {
    return Container(
      width: width,
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AdminInboxToolbar(
            searchController: _searchController,
            query: _inboxQuery,
            onSearchChanged: _searchConversations,
            onFilterChanged: (f) =>
                _applyInboxQuery(_inboxQuery.copyWith(filter: f)),
            onReset: () {
              _searchController.clear();
              _applyInboxQuery(const MessageInboxQuery());
            },
          ),
          if (_inboxError != null && _conversationUsers.isNotEmpty)
            _buildInboxRefreshWarning(),
          Expanded(child: _buildInboxBody()),
        ],
      ),
    );
  }

  Widget _buildEmptySelectionPane() {
    return Container(
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: AdminStateView.empty(
        icon: Icons.forum_outlined,
        title: 'Select a conversation to reply',
        message:
            'Choose an alumnus from the inbox on the left or start a new message.',
        primaryAction: AdminStateAction(
          label: 'New message',
          icon: Icons.edit_outlined,
          onPressed: _openComposePicker,
        ),
      ),
    );
  }

  Future<void> _openProfileSheet(AlumniMessageProfile profile) {
    return showAdminSidePanel<void>(
      context: context,
      width: AdminMessageTheme.profileWidth + 24,
      backgroundColor: AdminColors.card,
      child: Builder(
        builder: (panelContext) => SafeArea(
          child: AdminAlumniProfilePanel(
            profile: profile,
            width: double.infinity,
            onClose: () => Navigator.of(panelContext).pop(),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadCard({
    required bool showBack,
    required bool canDockProfile,
  }) {
    return Container(
      decoration: _panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: _buildThreadPane(
        showBack: showBack,
        canDockProfile: canDockProfile,
      ),
    );
  }

  Widget _buildThreadPane({
    required bool showBack,
    required bool canDockProfile,
  }) {
    final profile = _selectedProfile ??
        AlumniMessageProfile(
          userId: _selectedUserId ?? '',
          name: _selectedUserName ?? 'Alumni',
          email: '',
        );
    final threadKey = ValueKey<String>(
      'admin-thread-${_selectedUserId ?? _selectedUserDocId ?? 'none'}',
    );

    final threadNeedsReply = _conversationUsers.any(
      (u) =>
          (u['messagingId'] == _selectedUserId ||
              (_selectedUserDocId != null &&
                  u['docId'] == _selectedUserDocId)) &&
          (u['lastMessageFromRole'] as String?)?.toLowerCase() == 'user',
    );

    return Column(
      key: threadKey,
      children: [
        AdminConversationHeader(
          profile: profile,
          showProfilePanel: canDockProfile && _showProfilePanel,
          needsReply: threadNeedsReply,
          onBack: showBack
              ? () => setState(() {
                    _isChatOpenOnMobile = false;
                    _selectedUserId = null;
                    _selectedUserDocId = null;
                    _selectedProfile = null;
                    _stopConversationWatch();
                  })
              : null,
          showProfileToggle: true,
          onToggleProfile: canDockProfile
              ? () => setState(() => _showProfilePanel = !_showProfilePanel)
              : () => unawaited(_openProfileSheet(profile)),
        ),
        Expanded(
          child: ColoredBox(
            color: AdminColors.background,
            child: _isLoadingMessages && _messages.isEmpty
                ? const MessageThreadSkeleton()
                : _threadError != null && _messages.isEmpty
                ? AdminStateView.error(
                    compact: true,
                    title: "Couldn't load conversation",
                    message: messageFriendlyError(
                      _threadError!,
                      'Check your connection and try again.',
                    ),
                    details: _threadError,
                    onRetry: () {
                      final uid = _selectedUserId;
                      if (uid != null && uid.isNotEmpty) {
                        _startConversationWatch(
                          uid,
                          userDocId: _selectedUserDocId,
                        );
                      }
                    },
                  )
                : _messages.isEmpty
                ? const AdminStateView.empty(
                    compact: true,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    message: 'Send a reply below to start the conversation.',
                  )
                : ListView.builder(
                    controller: _messagesScrollController,
                    padding: const EdgeInsets.all(MessageTheme.threadPadding),
                    itemCount: _messages.length +
                        (_hasMoreHistory || _loadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      final hasHeader = _hasMoreHistory || _loadingOlder;
                      if (hasHeader && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    child: const Text('Load earlier messages'),
                                  ),
                          ),
                        );
                      }
                      final msgIndex = hasHeader ? index - 1 : index;
                      final msg = _messages[msgIndex];
                      final isMine = msg['senderId'] == _currentAdminId ||
                          (msg['senderDocId'] != null &&
                              _adminDocId != null &&
                              msg['senderDocId'] == _adminDocId);
                      final timestamp =
                          (msg['timestamp'] as DateTime?) ?? DateTime.now();
                      final older = msgIndex > 0 ? _messages[msgIndex - 1] : null;
                      final olderTs = older?['timestamp'] as DateTime?;
                      final showDateSep = olderTs == null ||
                          !isSameMessageCalendarDay(timestamp, olderTs);
                      final text = msg['messageText'] as String? ?? '';
                      final imageUrl = msg['imageUrl'] as String?;
                      final docId = msg['docId'] as String? ?? '';
                      final reactions = Map<String, dynamic>.from(
                        msg['reactions'] ?? {},
                      );

                      return Column(
                        children: [
                          if (showDateSep)
                            MessageDateSeparator(
                              label: formatMessageDateLabel(timestamp),
                            ),
                          MessageBubble(
                            isMine: isMine,
                            body: text,
                            timestamp: timestamp,
                            imageUrl: imageUrl,
                            reactions: reactions,
                            currentUserId: _currentAdminId,
                            isEdited: msg['isEdited'] == true,
                            isRead: msg['isRead'] == true,
                            optimistic: msg['optimistic'] == true,
                            peerIsOffice: false,
                            peerAvatarUrl: _selectedProfile?.avatarUrl,
                            peerDisplayName:
                                _selectedProfile?.name ?? _selectedUserName,
                            onLongPress: () {
                              if (docId.isNotEmpty) {
                                _showMessageOptions(context, msg, docId);
                              }
                            },
                            onReact: (emoji) {
                              if (docId.isNotEmpty) {
                                _addReaction(docId, emoji);
                              }
                            },
                            onOpenImage: imageUrl == null
                                ? null
                                : () =>
                                    _showImageFullScreen(context, imageUrl),
                            onCopy: text.trim().isEmpty
                                ? null
                                : () => copyAdminMessageText(context, text),
                            onEdit: isMine ? () => _editMessage(msg) : null,
                            onDelete: isMine ? () => _deleteMessage(msg) : null,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        MessageComposer(
          controller: _messageController,
          hintText: 'Reply to alumni…',
          isUploading: _isUploadingImage,
          uploadProgress: _uploadProgress,
          uploadFailed: _uploadFailed,
          selectedImage: _selectedImage,
          selectedImageBytes: _selectedImageBytes,
          onPickImage: _pickImage,
          onRetryUpload: _sendMessage,
          onClearImage: () => setState(() {
            _selectedImage = null;
            _selectedImageBytes = null;
            _uploadFailed = false;
            _uploadProgress = null;
          }),
          onSend: _sendMessage,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final body = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isChatOpenOnMobile && _selectedUserId != null) {
            setState(() => _isChatOpenOnMobile = false);
          }
        },
      },
      child: Focus(
        autofocus: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            final isTablet =
                constraints.maxWidth >= 768 && constraints.maxWidth < 1100;
            final canDockProfile = !isMobile && !isTablet;
            final showProfile = canDockProfile &&
                _showProfilePanel &&
                _selectedUserId != null &&
                _selectedProfile != null;
            final showHeader =
                !(isMobile && _isChatOpenOnMobile && _selectedUserId != null);

            final Widget workspace;
            if (isMobile) {
              workspace = _isChatOpenOnMobile && _selectedUserId != null
                  ? _buildThreadCard(
                      showBack: true,
                      canDockProfile: false,
                    )
                  : _buildInboxPane(width: null);
            } else {
              workspace = Row(
                children: [
                  _buildInboxPane(
                    width: isTablet ? 300 : AdminMessageTheme.inboxWidth,
                  ),
                  const SizedBox(width: AdminDensity.space2),
                  Expanded(
                    child: _selectedUserId == null
                        ? _buildEmptySelectionPane()
                        : _buildThreadCard(
                            showBack: false,
                            canDockProfile: canDockProfile,
                          ),
                  ),
                  if (showProfile) ...[
                    const SizedBox(width: AdminDensity.space2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AdminSurfaces.radiusMd,
                      ),
                      child: Container(
                        decoration: _panelDecoration(),
                        clipBehavior: Clip.antiAlias,
                        child: AdminAlumniProfilePanel(
                          key: ValueKey<String>(
                            'admin-profile-${_selectedProfile!.userId}',
                          ),
                          profile: _selectedProfile!,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHeader) ...[
                  _buildHeader(),
                  const SizedBox(height: AdminDensity.space2),
                ],
                Expanded(child: workspace),
              ],
            );
          },
        ),
      ),
    );

    if (widget.hideAppBar) {
      return ColoredBox(color: AdminColors.background, child: body);
    }

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AdminDensity.space2),
        child: body,
      ),
    );
  }
}
