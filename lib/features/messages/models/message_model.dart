// Typed messaging models with adapters for existing UI maps.
// Screens still consume [toLegacyMap] until Parts 3–4 migrate to models fully.

class ConversationMessage {
  const ConversationMessage({required this.docId, required this.data});

  final String docId;
  final Map<String, dynamic> data;

  factory ConversationMessage.fromMessage(MessageModel message) {
    return ConversationMessage(
      docId: message.id,
      data: message.toLegacyMap(),
    );
  }
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderId,
    this.senderDocId,
    required this.senderName,
    required this.senderEmail,
    required this.senderRole,
    required this.recipientId,
    this.recipientDocId,
    required this.body,
    this.imageUrl,
    required this.isRead,
    required this.reactions,
    required this.createdAt,
    this.updatedAt,
    this.editedAt,
  });

  final String id;
  final String senderId;
  final String? senderDocId;
  final String senderName;
  final String senderEmail;
  final String senderRole;
  final String recipientId;
  final String? recipientDocId;
  final String body;
  final String? imageUrl;
  final bool isRead;
  final Map<String, dynamic> reactions;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? editedAt;

  String get docId => id;
  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
  bool get isFromAdmin => senderRole.toLowerCase() == 'admin';
  bool get isFromUser => senderRole.toLowerCase() == 'user';
  bool get isEdited => editedAt != null;

  factory MessageModel.fromSupabaseRow(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    return MessageModel(
      id: id,
      senderId: row['sender_id']?.toString() ?? '',
      senderDocId: row['sender_doc_id']?.toString(),
      senderName: row['sender_name']?.toString() ?? '',
      senderEmail: row['sender_email']?.toString() ?? '',
      senderRole: row['sender_role']?.toString() ?? '',
      recipientId: row['recipient_id']?.toString() ?? '',
      recipientDocId: row['recipient_doc_id']?.toString(),
      body: row['body']?.toString() ?? '',
      imageUrl: row['image_base64']?.toString(),
      isRead: row['is_read'] == true,
      reactions: row['reactions'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(row['reactions'] as Map)
          : <String, dynamic>{},
      createdAt: parseMessageDateTime(row['created_at']),
      updatedAt: row['updated_at'] != null
          ? parseMessageDateTime(row['updated_at'])
          : null,
      editedAt: row['edited_at'] != null
          ? parseMessageDateTime(row['edited_at'])
          : null,
    );
  }

  /// Shape expected by current alumni/admin message screens.
  Map<String, dynamic> toLegacyMap() {
    return {
      'id': id,
      'docId': id,
      'senderId': senderId.isEmpty ? null : senderId,
      'senderDocId': senderDocId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'senderRole': senderRole,
      'recipientId': recipientId.isEmpty ? null : recipientId,
      'recipientDocId': recipientDocId,
      'messageText': body,
      'imageUrl': imageUrl,
      'timestamp': createdAt,
      'updatedAt': updatedAt,
      'editedAt': editedAt,
      'isRead': isRead,
      'isEdited': isEdited,
      'reactions': reactions,
    };
  }

  Map<String, dynamic> toSupabaseInsert({
    required String senderSupabaseId,
    required String recipientSupabaseId,
  }) {
    final at = createdAt.toUtc().toIso8601String();
    return {
      'id': id,
      'sender_id': senderSupabaseId,
      'recipient_id': recipientSupabaseId,
      'sender_doc_id': senderDocId,
      'recipient_doc_id': recipientDocId,
      'sender_role': senderRole,
      'sender_name': senderName,
      'sender_email': senderEmail,
      'body': body,
      'image_base64': imageUrl,
      'is_read': isRead,
      'reactions': reactions,
      'created_at': at,
      'updated_at': (updatedAt ?? createdAt).toUtc().toIso8601String(),
      if (editedAt != null) 'edited_at': editedAt!.toUtc().toIso8601String(),
    };
  }
}

class ConversationSummary {
  const ConversationSummary({
    required this.messagingId,
    required this.docId,
    required this.name,
    required this.email,
    required this.lastMessage,
    this.lastMessageTime,
    required this.isRead,
    this.program = '',
    this.batch = '',
    this.lastMessageFromRole = '',
    this.waitingSince,
    this.registrationLabel = 'Registered',
    this.tracerComplete = false,
    this.lastActive,
    this.avatarUrl,
    this.isArchived = false,
    this.isPinned = false,
  });

  final String messagingId;
  final String docId;
  final String name;
  final String email;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final bool isRead;
  final String program;
  final String batch;
  final String lastMessageFromRole;
  final DateTime? waitingSince;
  final String registrationLabel;
  final bool tracerComplete;
  final DateTime? lastActive;
  final String? avatarUrl;
  final bool isArchived;
  final bool isPinned;

  Map<String, dynamic> toLegacyMap() {
    return {
      'messagingId': messagingId,
      'docId': docId,
      'name': name,
      'email': email,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'isRead': isRead,
      'program': program,
      'batch': batch,
      'lastMessageFromRole': lastMessageFromRole,
      'waitingSince': waitingSince,
      'registrationLabel': registrationLabel,
      'tracerComplete': tracerComplete,
      'lastActive': lastActive,
      'avatarUrl': avatarUrl,
      'isArchived': isArchived,
      'isPinned': isPinned,
    };
  }

  ConversationSummary copyWith({
    String? name,
    String? email,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isRead,
    String? program,
    String? batch,
    String? lastMessageFromRole,
    DateTime? waitingSince,
    String? registrationLabel,
    bool? tracerComplete,
    DateTime? lastActive,
    String? avatarUrl,
    bool? isArchived,
    bool? isPinned,
  }) {
    return ConversationSummary(
      messagingId: messagingId,
      docId: docId,
      name: name ?? this.name,
      email: email ?? this.email,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isRead: isRead ?? this.isRead,
      program: program ?? this.program,
      batch: batch ?? this.batch,
      lastMessageFromRole: lastMessageFromRole ?? this.lastMessageFromRole,
      waitingSince: waitingSince ?? this.waitingSince,
      registrationLabel: registrationLabel ?? this.registrationLabel,
      tracerComplete: tracerComplete ?? this.tracerComplete,
      lastActive: lastActive ?? this.lastActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class UserProfileLite {
  const UserProfileLite({
    this.displayName,
    this.email,
    this.program,
    this.batch,
    this.tracerComplete = false,
    this.lastActive,
    this.avatarUrl,
  });

  final String? displayName;
  final String? email;
  final String? program;
  final String? batch;
  final bool tracerComplete;
  final DateTime? lastActive;
  final String? avatarUrl;
}

/// Registered alumni selectable when an admin starts a support thread.
class RegisteredAlumniContact {
  const RegisteredAlumniContact({
    required this.authUid,
    required this.name,
    this.rosterId = '',
    this.email = '',
    this.program = '',
    this.batch = '',
    this.avatarUrl,
    this.tracerComplete = false,
    this.lastActive,
  });

  final String authUid;
  final String rosterId;
  final String name;
  final String email;
  final String program;
  final String batch;
  final String? avatarUrl;
  final bool tracerComplete;
  final DateTime? lastActive;

  Map<String, dynamic> toConversationStub() {
    return {
      'messagingId': authUid,
      'docId': authUid,
      'name': name,
      'email': email,
      'program': program,
      'batch': batch,
      'avatarUrl': avatarUrl,
      'lastMessage': '',
      'lastMessageTime': null,
      'isRead': true,
      'lastMessageFromRole': '',
      'tracerComplete': tracerComplete,
      'lastActive': lastActive,
      'registrationLabel': 'Registered',
      'composeDraft': true,
    };
  }
}

class PrimaryAdminContact {
  const PrimaryAdminContact({
    required this.authUid,
    required this.docId,
    required this.displayName,
  });

  final String authUid;
  final String docId;
  final String displayName;
}

DateTime parseMessageDateTime(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toLocal();
  }
  return DateTime.now();
}
