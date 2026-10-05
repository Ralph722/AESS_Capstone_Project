import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/supabase_user_bridge.dart';
import 'package:alumni_system/features/messages/models/message_model.dart';

/// Database access for messages — no UI, no notifications, no streams.
class MessageRepository {
  MessageRepository({
    SupabaseClient? supabase,
    SupabaseUserBridge? bridge,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _bridge = bridge ?? SupabaseUserBridge(client: supabase);

  final SupabaseClient _supabase;
  final SupabaseUserBridge _bridge;

  /// Newest-page size for alumni/admin threads.
  static const int threadPageSize = 40;

  /// Columns needed to render a bubble.
  static const String threadSelectColumns =
      'id,sender_id,sender_doc_id,sender_name,sender_email,sender_role,'
      'recipient_id,recipient_doc_id,body,image_base64,is_read,reactions,'
      'created_at,updated_at,edited_at';

  /// Lean columns for client-side inbox fallback.
  static const String inboxFallbackSelectColumns =
      'id,sender_id,recipient_id,sender_role,sender_name,sender_email,'
      'body,image_base64,is_read,created_at';

  SupabaseClient get client => _supabase;
  SupabaseUserBridge get bridge => _bridge;

  Future<Set<String>> resolveIdentityIds(String authUid) async {
    final ids = <String>{authUid};
    try {
      final alumni = await _supabase
          .from('alumni_members')
          .select('id')
          .eq('auth_uid', authUid);
      for (final row in alumni) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    } catch (_) {}
    return ids;
  }

  Future<Set<String>> resolveAdminIdentityIds() async {
    try {
      final ids = <String>{};
      final admins =
          await _supabase.from('users').select('id').eq('role', 'admin');
      for (final row in admins) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      return ids;
    } catch (_) {
      return <String>{};
    }
  }

  Future<PrimaryAdminContact?> resolvePrimaryAdminContact() async {
    try {
      final row = await _supabase
          .from('users')
          .select()
          .eq('role', 'admin')
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final id = row['id']?.toString() ?? '';
      return PrimaryAdminContact(
        authUid: id,
        docId: id,
        displayName: row['display_name'] as String? ?? 'Admin',
      );
    } catch (_) {
      return null;
    }
  }

  Future<MessageModel?> getMessageById(String messageId) async {
    try {
      final row = await _supabase
          .from('messages')
          .select(threadSelectColumns)
          .eq('id', messageId)
          .maybeSingle();
      if (row == null) return null;
      return MessageModel.fromSupabaseRow(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertMessage({
    required MessageModel message,
    required String senderSupabaseId,
    required String recipientSupabaseId,
  }) async {
    await _supabase.from('messages').upsert(
          message.toSupabaseInsert(
            senderSupabaseId: senderSupabaseId,
            recipientSupabaseId: recipientSupabaseId,
          ),
          onConflict: 'id',
        );
  }

  Future<void> updateMessageBody(String messageId, String newText) async {
    await _supabase.from('messages').update({
      'body': newText,
      // edited_at is also set by DB trigger when body changes.
      'edited_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('messages').delete().eq('id', messageId);
  }

  Future<void> updateReactions(
    String messageId,
    Map<String, dynamic> reactions,
  ) async {
    await _supabase.from('messages').update({
      'reactions': reactions,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  /// Server-side admin inbox summaries (Part 8). Returns null if RPC unavailable.
  Future<List<Map<String, dynamic>>?> fetchAdminInboxSummariesRpc() async {
    try {
      final rows = await _supabase.rpc('admin_conversation_inbox');
      if (rows is! List) return null;
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Inbox fallback: only messages involving admin identities (not the full table).
  Future<List<MessageModel>> fetchAdminInvolvedMessages() async {
    final adminIds = await resolveAdminIdentityIds();
    if (adminIds.isEmpty) return [];
    final orExpr =
        adminIds.map((id) => 'sender_id.eq.$id,recipient_id.eq.$id').join(',');
    final rows = await _supabase
        .from('messages')
        .select(inboxFallbackSelectColumns)
        .or(orExpr);
    return rows.map(MessageModel.fromSupabaseRow).toList();
  }

  @Deprecated('Prefer fetchAdminInvolvedMessages / admin_conversation_inbox RPC')
  Future<List<MessageModel>> fetchAllMessages() async {
    return fetchAdminInvolvedMessages();
  }

  Future<List<MessageModel>> fetchMessagesInvolvingUserIds(
    Set<String> userIds, {
    int? limit,
    DateTime? before,
  }) async {
    if (userIds.isEmpty) return [];
    final orExpr =
        userIds.map((id) => 'sender_id.eq.$id,recipient_id.eq.$id').join(',');

    var filter =
        _supabase.from('messages').select(threadSelectColumns).or(orExpr);
    if (before != null) {
      filter = filter.lt('created_at', before.toUtc().toIso8601String());
    }

    final rows = limit != null
        ? await filter.order('created_at', ascending: false).limit(limit)
        : await filter.order('created_at', ascending: false);

    return rows.map(MessageModel.fromSupabaseRow).toList();
  }

  /// Newest-first page for a participant set.
  Future<List<MessageModel>> fetchConversationPage({
    required Set<String> participantIds,
    DateTime? before,
    int limit = threadPageSize,
  }) {
    return fetchMessagesInvolvingUserIds(
      participantIds,
      limit: limit,
      before: before,
    );
  }

  Future<Map<String, UserProfileLite>> fetchUserProfiles(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    final result = <String, UserProfileLite>{};
    try {
      final userRows =
          await _supabase.from('users').select().inFilter('id', ids);
      for (final row in userRows) {
        final id = row['id']?.toString();
        if (id == null) continue;
        final program = (row['program'] as String? ?? '').trim();
        final year = (row['year_graduated'] as String? ?? '').trim();
        result[id] = UserProfileLite(
          displayName: row['display_name'] as String?,
          email: row['email'] as String?,
          program: program,
          batch: year,
          tracerComplete: row['tracer_profile_complete'] == true,
          lastActive: row['updated_at'] != null
              ? parseMessageDateTime(row['updated_at'])
              : null,
          // Users table stores avatars in profile_image_base64 (URL or data URL).
          avatarUrl: () {
            final primary =
                (row['profile_image_base64'] as String?)?.trim();
            if (primary != null && primary.isNotEmpty) return primary;
            final legacy =
                (row['profile_image_url'] as String?)?.trim();
            if (legacy != null && legacy.isNotEmpty) return legacy;
            return null;
          }(),
        );
      }
    } catch (_) {}
    return result;
  }

  @Deprecated('Use fetchUserProfiles')
  Future<Map<String, ({String? displayName, String? email})>>
      fetchUserDisplayInfo(Iterable<String> userIds) async {
    final profiles = await fetchUserProfiles(userIds);
    return {
      for (final e in profiles.entries)
        e.key: (displayName: e.value.displayName, email: e.value.email),
    };
  }

  Future<int> countUnreadForRecipient({
    required String recipientSupabaseId,
    required String senderRole,
  }) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('recipient_id', recipientSupabaseId)
          .eq('sender_role', senderRole)
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (_) {
      final rows = await _supabase
          .from('messages')
          .select('id')
          .eq('recipient_id', recipientSupabaseId)
          .eq('sender_role', senderRole)
          .eq('is_read', false);
      return rows.length;
    }
  }

  Future<void> markMessagesRead({
    required String recipientSupabaseId,
    required String senderRole,
    String? senderId,
    String? senderDocId,
  }) async {
    var query = _supabase.from('messages').update({
      'is_read': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('recipient_id', recipientSupabaseId).eq('sender_role', senderRole).eq(
          'is_read',
          false,
        );

    if (senderId != null && senderId.isNotEmpty) {
      query = query.eq('sender_id', senderId);
    } else if (senderDocId != null && senderDocId.isNotEmpty) {
      query = query.eq('sender_doc_id', senderDocId);
    }

    await query;
  }

  /// Registered, active alumni with an auth account — for admin "New message".
  Future<List<RegisteredAlumniContact>> searchRegisteredAlumniContacts({
    String query = '',
    int limit = 50,
    String? excludeAuthUid,
  }) async {
    try {
      var builder = _supabase
          .from('alumni_members')
          .select(
            'id, full_name, auth_uid, registered_email, email_address, '
            'course, year_graduated, profile_image_url, '
            'tracer_profile_complete, last_active_at',
          )
          .eq('is_registered_user', true)
          .eq('is_deactivated', false)
          .not('auth_uid', 'is', null);

      final q = query.trim().replaceAll(RegExp(r'[%_,"]'), ' ').trim();
      if (q.isNotEmpty) {
        final pattern = '"%$q%"';
        builder = builder.or(
          'full_name.ilike.$pattern,'
          'registered_email.ilike.$pattern,'
          'email_address.ilike.$pattern,'
          'course.ilike.$pattern,'
          'student_id.ilike.$pattern',
        );
      }

      final rows = await builder.order('full_name').limit(limit);
      final out = <RegisteredAlumniContact>[];
      for (final row in rows) {
        final authUid = row['auth_uid']?.toString().trim() ?? '';
        if (authUid.isEmpty) continue;
        if (excludeAuthUid != null &&
            excludeAuthUid.isNotEmpty &&
            authUid == excludeAuthUid) {
          continue;
        }
        final year = (row['year_graduated'] as String? ?? '').trim();
        final email = (row['registered_email'] as String? ?? '').trim().isNotEmpty
            ? (row['registered_email'] as String).trim()
            : (row['email_address'] as String? ?? '').trim();
        out.add(
          RegisteredAlumniContact(
            authUid: authUid,
            rosterId: row['id']?.toString() ?? '',
            name: (row['full_name'] as String? ?? '').trim().isNotEmpty
                ? (row['full_name'] as String).trim()
                : 'Alumni',
            email: email,
            program: (row['course'] as String? ?? '').trim(),
            batch: year,
            avatarUrl: (row['profile_image_url'] as String?)?.trim(),
            tracerComplete: row['tracer_profile_complete'] == true,
            lastActive: row['last_active_at'] != null
                ? parseMessageDateTime(row['last_active_at'])
                : null,
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
