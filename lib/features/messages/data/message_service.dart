import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/supabase_user_bridge.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/messages/data/message_realtime.dart';
import 'package:alumni_system/features/messages/data/message_repository.dart';
import 'package:alumni_system/features/messages/models/message_model.dart';

export 'package:alumni_system/features/messages/models/message_model.dart'
    show
        ConversationMessage,
        MessageModel,
        ConversationSummary,
        RegisteredAlumniContact;
export 'package:alumni_system/features/messages/data/message_realtime.dart'
    show MessageChangeSubscription;

/// Messaging facade — orchestrates repository, realtime, notifications, and
/// Storage cleanup.
///
/// **Stable public surface (Home / Admin dashboard / screens):**
/// - Unread badges: [getUnreadMessagesCount], [getUnreadMessagesCountStream],
///   [getAdminUnreadUserMessagesCount], [watchAdminUnreadUserMessagesCount]
/// - Identity: [resolveIdentityIds], [resolveCurrentUserIds],
///   [resolvePrimaryAdminContact], [resolveAdminIdentityIds]
/// - Alumni thread: [watchUserAdminConversation], [loadOlderUserAdminConversation]
/// - Admin inbox/thread: [watchAdminInbox], [watchAdminConversation],
///   [getConversationUsersForAdmin], [loadOlderAdminConversation]
/// - CRUD: [sendMessage], [updateMessage], [deleteMessage], [toggleReaction],
///   mark-read helpers
///
/// Screens may use additional methods; do not break the badge / entry APIs.
/// Delete also cleans Storage attachments when present.
class MessageService {
  MessageService({
    SupabaseClient? supabase,
    SupabaseUserBridge? bridge,
    MessageRepository? repository,
    MessageRealtime? realtime,
    ImageStorageService? imageStorage,
  })  : _repo = repository ??
            MessageRepository(supabase: supabase, bridge: bridge),
        _realtime = realtime ?? MessageRealtime(supabase: supabase),
        _imageStorage = imageStorage ?? ImageStorageService(supabase: supabase);

  final MessageRepository _repo;
  final MessageRealtime _realtime;
  final ImageStorageService _imageStorage;

  MessageRepository get repository => _repo;
  MessageRealtime get realtime => _realtime;

  Future<Set<String>> resolveIdentityIds(String authUid) =>
      _repo.resolveIdentityIds(authUid);

  Future<Set<String>> resolveCurrentUserIds() async {
    final userId = AppSession.userId;
    if (userId == null) return {};
    return resolveIdentityIds(userId);
  }

  Future<void> sendMessage({
    required String messageId,
    required String senderId,
    String? senderDocId,
    required String senderName,
    required String senderEmail,
    required String senderRole,
    required String recipientId,
    String? recipientDocId,
    required String messageText,
    String? imageUrl,
    Map<String, dynamic>? reactions,
    DateTime? timestamp,
  }) async {
    final authUid = AppSession.userId ?? _repo.client.auth.currentUser?.id;
    if (authUid == null || authUid.isEmpty) {
      throw Exception('Not signed in.');
    }

    final createdAt = timestamp ?? DateTime.now();
    final trimmedBody = messageText.trim();
    if (trimmedBody.length > 4000) {
      throw Exception('Message is too long.');
    }
    if (!ImageStorageService.isAllowedMessageImageUrl(imageUrl)) {
      throw Exception('Invalid image attachment.');
    }

    final senderSupabaseId = await _repo.bridge.resolveSupabaseUserId(senderId);
    final recipientSupabaseId =
        await _repo.bridge.resolveSupabaseUserId(recipientId);
    if (senderSupabaseId == null || recipientSupabaseId == null) {
      throw Exception('Unable to resolve sender or recipient.');
    }
    if (senderSupabaseId != authUid) {
      throw Exception('Cannot send messages as another user.');
    }

    final safeRole = senderRole.toLowerCase() == 'admin' ? 'admin' : 'user';

    try {
      final message = MessageModel(
        id: messageId,
        senderId: senderSupabaseId,
        senderDocId: senderDocId,
        senderName: senderName,
        senderEmail: senderEmail,
        senderRole: safeRole,
        recipientId: recipientSupabaseId,
        recipientDocId: recipientDocId,
        body: trimmedBody,
        imageUrl: imageUrl,
        isRead: false,
        reactions: reactions ?? <String, dynamic>{},
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      await _repo.upsertMessage(
        message: message,
        senderSupabaseId: senderSupabaseId,
        recipientSupabaseId: recipientSupabaseId,
      );
      // The recipient's notification is created by the messages insert
      // trigger (notify_message_recipient).
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  Future<void> updateMessage(String messageId, String newText) async {
    final trimmed = newText.trim();
    if (trimmed.length > 4000) {
      throw Exception('Message is too long.');
    }
    try {
      await _repo.updateMessageBody(messageId, trimmed);
    } catch (e) {
      throw Exception('Error updating message: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      final existing = await _repo.getMessageById(messageId);
      await _repo.deleteMessage(messageId);
      if (existing?.imageUrl != null) {
        await _imageStorage.deleteMessageImageByUrl(existing!.imageUrl);
      }
    } catch (e) {
      throw Exception('Error deleting message: $e');
    }
  }

  /// Removes an uploaded chat image that never became a message (send aborted).
  Future<void> discardUploadedMessageImage(String? imageUrl) async {
    await _imageStorage.deleteMessageImageByUrl(imageUrl);
  }

  Future<void> toggleReaction({
    required String messageId,
    required String actorUserId,
    required String emoji,
  }) async {
    final message = await _repo.getMessageById(messageId);
    if (message == null) return;
    final next = _reactionsAfterToggle(
      current: message.reactions,
      actorUserId: actorUserId,
      emoji: emoji,
    );
    await applyReactions(messageId: messageId, reactions: next);
  }

  /// Writes an already-computed reactions map (used by optimistic UI).
  Future<void> applyReactions({
    required String messageId,
    required Map<String, dynamic> reactions,
  }) async {
    try {
      await _repo.updateReactions(messageId, reactions);
    } catch (e) {
      throw Exception('Error updating reactions: $e');
    }
  }

  static Map<String, dynamic> _reactionsAfterToggle({
    required Map<String, dynamic> current,
    required String actorUserId,
    required String emoji,
  }) {
    final reactions = <String, dynamic>{};
    for (final entry in current.entries) {
      final list = entry.value;
      reactions[entry.key] = List<String>.from(
        list is List ? list.map((e) => e.toString()) : const <String>[],
      );
    }
    final usersList = List<String>.from(
      (reactions[emoji] as List?)?.map((e) => e.toString()) ?? const <String>[],
    );
    if (usersList.contains(actorUserId)) {
      usersList.remove(actorUserId);
      if (usersList.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = usersList;
      }
    } else {
      usersList.add(actorUserId);
      reactions[emoji] = usersList;
    }
    return reactions;
  }

  Future<Set<String>> resolveAdminIdentityIds() =>
      _repo.resolveAdminIdentityIds();

  Future<({String authUid, String docId, String displayName})?>
      resolvePrimaryAdminContact() async {
    final contact = await _repo.resolvePrimaryAdminContact();
    if (contact == null) return null;
    return (
      authUid: contact.authUid,
      docId: contact.docId,
      displayName: contact.displayName,
    );
  }

  /// Admin inbox: one row per user conversation, newest first.
  Future<List<Map<String, dynamic>>> getConversationUsersForAdmin() async {
    try {
      final rpcRows = await _repo.fetchAdminInboxSummariesRpc();
      if (rpcRows != null) {
        return _enrichInboxFromRpc(rpcRows);
      }
      return _getConversationUsersForAdminClientSide();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _enrichInboxFromRpc(
    List<Map<String, dynamic>> rpcRows,
  ) async {
    final byUser = <String, ConversationSummary>{};
    for (final row in rpcRows) {
      final id = row['messaging_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byUser[id] = ConversationSummary(
        messagingId: id,
        docId: id,
        name: row['sender_name']?.toString() ?? 'User',
        email: row['sender_email']?.toString() ?? '',
        lastMessage: row['last_message']?.toString() ?? '',
        lastMessageTime: row['last_message_time'] != null
            ? parseMessageDateTime(row['last_message_time'])
            : null,
        isRead: row['has_unread'] != true,
        lastMessageFromRole: row['last_message_from_role']?.toString() ?? '',
        waitingSince: row['waiting_since'] != null
            ? parseMessageDateTime(row['waiting_since'])
            : null,
      );
    }

    if (byUser.isNotEmpty) {
      final profiles = await _repo.fetchUserProfiles(byUser.keys);
      for (final entry in profiles.entries) {
        final summary = byUser[entry.key];
        if (summary == null) continue;
        final p = entry.value;
        byUser[entry.key] = summary.copyWith(
          name: (p.displayName?.isNotEmpty == true)
              ? p.displayName
              : summary.name,
          email: (p.email?.isNotEmpty == true) ? p.email : summary.email,
          program: p.program ?? summary.program,
          batch: p.batch ?? summary.batch,
          tracerComplete: p.tracerComplete,
          lastActive: p.lastActive,
          avatarUrl: p.avatarUrl,
          registrationLabel: 'Registered',
        );
      }
    }

    return byUser.values.map((s) => s.toLegacyMap()).toList()
      ..sort((a, b) {
        final timeA = (a['lastMessageTime'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = (b['lastMessageTime'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
  }

  /// Fallback when inbox RPC is not deployed yet.
  Future<List<Map<String, dynamic>>> _getConversationUsersForAdminClientSide() async {
    final adminIds = await resolveAdminIdentityIds();
    final messages = await _repo.fetchAdminInvolvedMessages();

    final byUser = <String, ConversationSummary>{};
    final usersWithUnread = <String>{};
    final waitingSinceByUser = <String, DateTime>{};

    for (final message in messages) {
      final senderId = message.senderId;
      final recipientId = message.recipientId;
      final senderRole = message.senderRole.toLowerCase();

      String? userId;
      if (senderRole == 'user' && senderId.isNotEmpty) {
        userId = senderId;
      } else if (senderRole == 'admin' &&
          recipientId.isNotEmpty &&
          !adminIds.contains(recipientId)) {
        userId = recipientId;
      }
      if (userId == null || userId.isEmpty) continue;

      if (senderRole == 'user' && !message.isRead) {
        usersWithUnread.add(userId);
        final prev = waitingSinceByUser[userId];
        if (prev == null || message.createdAt.isBefore(prev)) {
          waitingSinceByUser[userId] = message.createdAt;
        }
      }

      final existing = byUser[userId];
      final ts = message.createdAt;
      final isNewer = existing == null ||
          existing.lastMessageTime == null ||
          ts.isAfter(existing.lastMessageTime!);

      if (isNewer) {
        byUser[userId] = ConversationSummary(
          messagingId: userId,
          docId: userId,
          name: senderRole == 'user'
              ? (message.senderName.isNotEmpty
                  ? message.senderName
                  : (existing?.name ?? 'User'))
              : (existing?.name ?? 'User'),
          email: senderRole == 'user'
              ? (message.senderEmail.isNotEmpty
                  ? message.senderEmail
                  : (existing?.email ?? ''))
              : (existing?.email ?? ''),
          lastMessage: message.body.isNotEmpty
              ? message.body
              : (message.hasImage ? 'Sent an image' : ''),
          lastMessageTime: ts,
          isRead: true,
          lastMessageFromRole: senderRole,
          program: existing?.program ?? '',
          batch: existing?.batch ?? '',
        );
      }
    }

    if (byUser.isNotEmpty) {
      final profiles = await _repo.fetchUserProfiles(byUser.keys);
      for (final entry in profiles.entries) {
        final summary = byUser[entry.key];
        if (summary == null) continue;
        final p = entry.value;
        byUser[entry.key] = summary.copyWith(
          name: (p.displayName?.isNotEmpty == true)
              ? p.displayName
              : summary.name,
          email: (p.email?.isNotEmpty == true) ? p.email : summary.email,
          program: p.program ?? summary.program,
          batch: p.batch ?? summary.batch,
          tracerComplete: p.tracerComplete,
          lastActive: p.lastActive,
          avatarUrl: p.avatarUrl,
          registrationLabel: 'Registered',
        );
      }
    }

    final list = byUser.entries.map((e) {
      final unread = usersWithUnread.contains(e.key);
      return e.value
          .copyWith(
            isRead: !unread,
            waitingSince: waitingSinceByUser[e.key],
          )
          .toLegacyMap();
    }).toList()
      ..sort((a, b) {
        final timeA = (a['lastMessageTime'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = (b['lastMessageTime'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
    return list;
  }

  /// Admin conversation view: newest page (or older page if [before] set), oldest first.
  Future<List<Map<String, dynamic>>> getMessagesForAdminConversation(
    String userMessagingId, {
    String? userDocId,
    DateTime? before,
    int limit = MessageRepository.threadPageSize,
  }) async {
    final userIds = <String>{
      if (userMessagingId.isNotEmpty) userMessagingId,
      if (userDocId != null && userDocId.isNotEmpty) userDocId,
    };
    if (userIds.isEmpty) return [];

    try {
      final adminIds = await resolveAdminIdentityIds();
      final rows = await _repo.fetchConversationPage(
        participantIds: userIds,
        before: before,
        limit: limit,
      );

      final messages = rows.where((message) {
        final senderId = message.senderId;
        final recipientId = message.recipientId;
        final isUserSide =
            userIds.contains(senderId) || userIds.contains(recipientId);
        final isAdminSide =
            adminIds.contains(senderId) || adminIds.contains(recipientId);
        return isUserSide && isAdminSide;
      }).map((m) => m.toLegacyMap()).toList();

      messages.sort((a, b) {
        final timeA = (a['timestamp'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = (b['timestamp'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return timeA.compareTo(timeB);
      });
      return messages;
    } catch (_) {
      return [];
    }
  }

  /// Older admin-thread page (exclusive of [before]). Oldest first.
  Future<({List<Map<String, dynamic>> messages, bool hasMore})>
      loadOlderAdminConversation(
    String userMessagingId, {
    String? userDocId,
    required DateTime before,
    int limit = MessageRepository.threadPageSize,
  }) async {
    final messages = await getMessagesForAdminConversation(
      userMessagingId,
      userDocId: userDocId,
      before: before,
      limit: limit,
    );
    return (messages: messages, hasMore: messages.length >= limit);
  }

  bool isUserSender(Map<String, dynamic> data, Set<String> userIds) {
    final senderId = data['senderId'] as String?;
    final senderDocId = data['senderDocId'] as String?;
    if (senderId != null && userIds.contains(senderId)) return true;
    if (senderDocId != null && userIds.contains(senderDocId)) return true;
    return (data['senderRole'] as String?)?.toLowerCase() == 'user';
  }

  Set<String> augmentAdminIds(
    Set<String> baseAdminIds,
    Iterable<Map<String, dynamic>> messages,
  ) {
    final ids = Set<String>.from(baseAdminIds);
    for (final data in messages) {
      if ((data['senderRole'] as String?)?.toLowerCase() == 'admin') {
        final senderId = data['senderId'] as String?;
        final senderDocId = data['senderDocId'] as String?;
        final recipientId = data['recipientId'] as String?;
        final recipientDocId = data['recipientDocId'] as String?;
        if (senderId != null && senderId.isNotEmpty) ids.add(senderId);
        if (senderDocId != null && senderDocId.isNotEmpty) ids.add(senderDocId);
        if (recipientId != null && recipientId.isNotEmpty) ids.add(recipientId);
        if (recipientDocId != null && recipientDocId.isNotEmpty) {
          ids.add(recipientDocId);
        }
      }
    }
    return ids;
  }

  bool _isUserConversationMessage(
    Map<String, dynamic> data, {
    required String userUid,
    required Set<String> adminIds,
  }) {
    final senderId = data['senderId'] as String?;
    final recipientId = data['recipientId'] as String?;
    final senderRole = (data['senderRole'] as String?)?.toLowerCase();

    final userSent = senderId == userUid;
    final userReceived = recipientId == userUid;
    final adminSent = senderRole == 'admin' ||
        (senderId != null && adminIds.contains(senderId));
    final adminReceived =
        recipientId != null && adminIds.contains(recipientId);

    return (userSent && adminReceived) || (adminSent && userReceived);
  }

  Future<List<ConversationMessage>> _fetchUserAdminConversation(
    String userUid, {
    DateTime? before,
    int limit = MessageRepository.threadPageSize,
  }) async {
    var adminIds = await resolveAdminIdentityIds();
    final rows = await _repo.fetchConversationPage(
      participantIds: {userUid},
      before: before,
      limit: limit,
    );
    final byDocId = <String, ConversationMessage>{};

    for (final message in rows) {
      final data = message.toLegacyMap();
      adminIds = augmentAdminIds(adminIds, [data]);
      if (!_isUserConversationMessage(
        data,
        userUid: userUid,
        adminIds: adminIds,
      )) {
        continue;
      }
      byDocId[message.id] = ConversationMessage(docId: message.id, data: data);
    }

    final items = byDocId.values.toList()
      ..sort((a, b) {
        final timeA = (a.data['timestamp'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = (b.data['timestamp'] as DateTime?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
    return items;
  }

  /// Older alumni-thread page (exclusive of [before]). Newest first.
  Future<({List<ConversationMessage> messages, bool hasMore})>
      loadOlderUserAdminConversation({
    required DateTime before,
    int limit = MessageRepository.threadPageSize,
  }) async {
    final userUid = AppSession.userId;
    if (userUid == null) {
      return (messages: <ConversationMessage>[], hasMore: false);
    }
    final messages = await _fetchUserAdminConversation(
      userUid,
      before: before,
      limit: limit,
    );
    return (messages: messages, hasMore: messages.length >= limit);
  }

  /// Live alumni ↔ admin thread (insert/update/delete/reactions/read).
  Stream<List<ConversationMessage>> watchUserAdminConversation() {
    final controller = StreamController<List<ConversationMessage>>();

    Future<void> setup() async {
      MessageChangeSubscription? changeSub;
      var lastFingerprint = '';
      var hasEmitted = false;

      Future<void> emitFresh() async {
        if (controller.isClosed) return;
        try {
          final userUid = AppSession.userId;
          if (userUid == null) {
            if (!controller.isClosed) controller.add([]);
            hasEmitted = true;
            return;
          }
          final items = await _fetchUserAdminConversation(userUid);
          final fp = MessageRealtime.conversationFingerprint(items);
          // Empty list fingerprints as '' — must still emit the first time.
          if (hasEmitted && fp == lastFingerprint) return;
          lastFingerprint = fp;
          hasEmitted = true;
          if (!controller.isClosed) controller.add(items);
        } catch (_) {
          if (!controller.isClosed && !hasEmitted) {
            hasEmitted = true;
            controller.add([]);
          }
        }
      }

      try {
        final userUid = AppSession.userId;
        if (userUid == null) {
          controller.add([]);
          await controller.close();
          return;
        }

        await emitFresh();

        changeSub = _realtime.subscribeMessageChanges(
          channelName: 'alumni-thread-$userUid',
          invokeImmediately: false,
          onChange: () {
            unawaited(emitFresh());
          },
        );

        controller.onCancel = () async {
          await changeSub?.cancel();
        };
      } catch (_) {
        await changeSub?.cancel();
        if (!controller.isClosed) controller.add([]);
      }
    }

    setup();
    return controller.stream;
  }

  /// Live admin inbox (conversation summaries).
  Stream<List<Map<String, dynamic>>> watchAdminInbox() {
    final controller = StreamController<List<Map<String, dynamic>>>();

    Future<void> setup() async {
      MessageChangeSubscription? changeSub;
      var lastFingerprint = '';
      var hasEmitted = false;

      Future<void> emitFresh() async {
        if (controller.isClosed) return;
        try {
          final items = await getConversationUsersForAdmin();
          final fp = MessageRealtime.legacyListFingerprint(items);
          // Empty inbox fingerprints as '' — must still emit the first time
          // or the admin Support inbox skeleton never clears.
          if (hasEmitted && fp == lastFingerprint) return;
          lastFingerprint = fp;
          hasEmitted = true;
          if (!controller.isClosed) controller.add(items);
        } catch (_) {
          if (!controller.isClosed && !hasEmitted) {
            hasEmitted = true;
            controller.add([]);
          }
        }
      }

      try {
        await emitFresh();
        changeSub = _realtime.subscribeMessageChanges(
          channelName: 'admin-inbox',
          invokeImmediately: false,
          onChange: () {
            unawaited(emitFresh());
          },
        );
        controller.onCancel = () async {
          await changeSub?.cancel();
        };
      } catch (_) {
        await changeSub?.cancel();
        if (!controller.isClosed) controller.add([]);
      }
    }

    setup();
    return controller.stream;
  }

  /// Live admin open-thread with a given alumni.
  Stream<List<Map<String, dynamic>>> watchAdminConversation(
    String userMessagingId, {
    String? userDocId,
  }) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    Future<void> setup() async {
      MessageChangeSubscription? changeSub;
      var lastFingerprint = '';
      var hasEmitted = false;

      Future<void> emitFresh() async {
        if (controller.isClosed) return;
        try {
          final items = await getMessagesForAdminConversation(
            userMessagingId,
            userDocId: userDocId,
          );
          final fp = MessageRealtime.legacyListFingerprint(items);
          if (hasEmitted && fp == lastFingerprint) return;
          lastFingerprint = fp;
          hasEmitted = true;
          if (!controller.isClosed) controller.add(items);
        } catch (_) {
          if (!controller.isClosed && !hasEmitted) {
            hasEmitted = true;
            controller.add([]);
          }
        }
      }

      try {
        if (userMessagingId.isEmpty &&
            (userDocId == null || userDocId.isEmpty)) {
          controller.add([]);
          await controller.close();
          return;
        }

        await emitFresh();
        changeSub = _realtime.subscribeMessageChanges(
          channelName: 'admin-thread-$userMessagingId',
          invokeImmediately: false,
          onChange: () {
            unawaited(emitFresh());
          },
        );
        controller.onCancel = () async {
          await changeSub?.cancel();
        };
      } catch (_) {
        await changeSub?.cancel();
        if (!controller.isClosed) controller.add([]);
      }
    }

    setup();
    return controller.stream;
  }

  Future<int> getUnreadMessagesCount() async {
    final userId = AppSession.userId;
    if (userId == null) return 0;

    try {
      final supabaseUid = await _repo.bridge.resolveSupabaseUserId(userId);
      if (supabaseUid == null) return 0;
      return _repo.countUnreadForRecipient(
        recipientSupabaseId: supabaseUid,
        senderRole: 'admin',
      );
    } catch (_) {
      return 0;
    }
  }

  Stream<int> getUnreadMessagesCountStream() {
    return _realtime.watchUnreadCount(
      fetchCount: getUnreadMessagesCount,
      resolveRecipientId: () async {
        final userId = AppSession.userId;
        if (userId == null) return null;
        return _repo.bridge.resolveSupabaseUserId(userId);
      },
    );
  }

  Future<void> markAdminMessagesAsRead() async {
    final userId = AppSession.userId;
    if (userId == null) return;

    try {
      final supabaseUid = await _repo.bridge.resolveSupabaseUserId(userId);
      if (supabaseUid == null) return;
      await _repo.markMessagesRead(
        recipientSupabaseId: supabaseUid,
        senderRole: 'admin',
      );
    } catch (e) {
      throw Exception('Error marking admin messages as read: $e');
    }
  }

  Future<int> getAdminUnreadUserMessagesCount() async {
    final adminId = AppSession.userId;
    if (adminId == null) return 0;

    try {
      final supabaseUid = await _repo.bridge.resolveSupabaseUserId(adminId);
      if (supabaseUid == null) return 0;
      return _repo.countUnreadForRecipient(
        recipientSupabaseId: supabaseUid,
        senderRole: 'user',
      );
    } catch (_) {
      return 0;
    }
  }

  Stream<int> watchAdminUnreadUserMessagesCount() {
    return _realtime.watchUnreadCount(
      fetchCount: getAdminUnreadUserMessagesCount,
      resolveRecipientId: () async {
        final adminId = AppSession.userId;
        if (adminId == null) return null;
        return _repo.bridge.resolveSupabaseUserId(adminId);
      },
    );
  }

  Future<void> markUserMessagesAsReadForAdmin(
    String userMessagingId, {
    String? userDocId,
  }) async {
    final adminId = AppSession.userId;
    if (adminId == null) return;

    try {
      final adminSupabaseId =
          await _repo.bridge.resolveSupabaseUserId(adminId);
      final userSupabaseId =
          await _repo.bridge.resolveSupabaseUserId(userMessagingId);
      if (adminSupabaseId == null) return;

      await _repo.markMessagesRead(
        recipientSupabaseId: adminSupabaseId,
        senderRole: 'user',
        senderId: userSupabaseId,
        senderDocId: userSupabaseId == null ? userDocId : null,
      );
    } catch (e) {
      throw Exception('Error marking user messages as read: $e');
    }
  }

  /// Registered alumni the admin can message first (same one-thread support channel).
  Future<List<RegisteredAlumniContact>> searchRegisteredAlumniForCompose({
    String query = '',
    int limit = 50,
  }) {
    return _repo.searchRegisteredAlumniContacts(
      query: query,
      limit: limit,
      excludeAuthUid: AppSession.userId,
    );
  }

  /// Resolve a registered alumni for admin deep-links (Jobs → Message, etc.).
  Future<RegisteredAlumniContact> resolveAlumniContact(String authUid) async {
    final id = authUid.trim();
    if (id.isEmpty) {
      return const RegisteredAlumniContact(
        authUid: '',
        name: 'Alumni',
      );
    }
    final profiles = await _repo.fetchUserProfiles([id]);
    final p = profiles[id];
    if (p == null) {
      return RegisteredAlumniContact(authUid: id, name: 'Alumni');
    }
    final name = (p.displayName ?? '').trim();
    return RegisteredAlumniContact(
      authUid: id,
      name: name.isNotEmpty ? name : 'Alumni',
      email: (p.email ?? '').trim(),
      program: (p.program ?? '').trim(),
      batch: (p.batch ?? '').trim(),
      avatarUrl: p.avatarUrl,
      tracerComplete: p.tracerComplete,
      lastActive: p.lastActive,
    );
  }
}
