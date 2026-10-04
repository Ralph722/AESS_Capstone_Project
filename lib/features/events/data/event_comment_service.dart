import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/events/models/event_comment_model.dart';
import 'package:alumni_system/core/services/app_session.dart';

class EventCommentService {
  EventCommentService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Create a new comment
  Future<EventComment> createComment({
    required String eventId,
    required String comment,
    String? userDocId,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final row = await _supabase
          .from('event_comments')
          .insert({
            'event_id': eventId,
            'user_id': userId,
            'body': comment.trim(),
          })
          .select()
          .single();

      // comments_count + admin notifications are handled by DB triggers
      // (alumni cannot update events or insert notifications for admins).

      final userInfo = await _fetchUserInfo(userId);
      return EventComment.fromSupabaseRow(
        row,
        userName: userInfo?['display_name'] as String? ?? 'Anonymous',
        userEmail: userInfo?['email'] as String? ?? '',
        profileImageUrl: userInfo?['profile_image_base64'] as String? ?? '',
      );
    } catch (e) {
      throw Exception('Error creating comment: $e');
    }
  }

  /// Get all comments for an event
  Future<List<EventComment>> getComments(String eventId) async {
    try {
      final rows = await _supabase
          .from('event_comments')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      return _attachUserInfo(rows);
    } catch (e) {
      throw Exception('Error fetching comments: $e');
    }
  }

  /// Stream of comments for real-time updates
  Stream<List<EventComment>> getCommentsStream(String eventId) async* {
    yield* _supabase
        .from('event_comments')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .asyncMap((rows) async {
          final sorted = List<Map<String, dynamic>>.from(rows)
            ..sort(
              (a, b) => (b['created_at'] as String? ?? '').compareTo(
                a['created_at'] as String? ?? '',
              ),
            );
          return _attachUserInfo(sorted);
        });
  }

  /// Update a comment
  Future<void> updateComment({
    required String eventId,
    required String commentId,
    required String newComment,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final commentRow = await _supabase
          .from('event_comments')
          .select()
          .eq('id', commentId)
          .maybeSingle();

      if (commentRow == null) {
        throw Exception('Comment not found');
      }

      final isOwner = commentRow['user_id'] == userId;
      final isAdmin = await _isAdmin();

      if (!isOwner && !isAdmin) {
        throw Exception('You do not have permission to edit this comment');
      }

      await _supabase
          .from('event_comments')
          .update({'body': newComment.trim()})
          .eq('id', commentId);
    } catch (e) {
      throw Exception('Error updating comment: $e');
    }
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String eventId,
    required String commentId,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final commentRow = await _supabase
          .from('event_comments')
          .select()
          .eq('id', commentId)
          .maybeSingle();

      if (commentRow == null) {
        throw Exception('Comment not found');
      }

      final isOwner = commentRow['user_id'] == userId;
      final isAdmin = await _isAdmin();

      if (!isOwner && !isAdmin) {
        throw Exception('You do not have permission to delete this comment');
      }

      await _supabase.from('event_comments').delete().eq('id', commentId);
      // comments_count is maintained by DB trigger.
    } catch (e) {
      throw Exception('Error deleting comment: $e');
    }
  }

  /// Get all comments across all events (for admin)
  Future<List<EventComment>> getAllComments() async {
    try {
      final rows = await _supabase
          .from('event_comments')
          .select()
          .order('created_at', ascending: false);
      return _attachUserInfo(rows);
    } catch (e) {
      throw Exception('Error fetching all comments: $e');
    }
  }

  /// Stream of all comments (for admin)
  Stream<List<EventComment>> getAllCommentsStream() {
    return _supabase.from('event_comments').stream(primaryKey: ['id']).asyncMap(
      (rows) async {
        final sorted = List<Map<String, dynamic>>.from(rows)
          ..sort(
            (a, b) => (b['created_at'] as String? ?? '').compareTo(
              a['created_at'] as String? ?? '',
            ),
          );
        return _attachUserInfo(sorted);
      },
    );
  }

  /// Helper: Check if current user is admin
  Future<bool> _isAdmin() async {
    final userId = AppSession.userId;
    if (userId == null) return false;

    try {
      final row = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return row?['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  /// Create a reply to a comment (admin only)
  Future<EventComment> createReply({
    required String eventId,
    required String commentId,
    required String reply,
    required EventComment originalComment,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final isAdmin = await _isAdmin();
    if (!isAdmin) {
      throw Exception('Only admins can reply to comments');
    }

    try {
      final row = await _supabase
          .from('event_replies')
          .insert({
            'event_id': eventId,
            'comment_id': commentId,
            'user_id': userId,
            'body': reply.trim(),
          })
          .select()
          .single();

      final userInfo = await _fetchUserInfo(userId);
      final newReply = EventComment.fromSupabaseRow(
        row,
        userName: userInfo?['display_name'] as String? ?? 'Admin',
        userEmail: userInfo?['email'] as String? ?? '',
        profileImageUrl: userInfo?['profile_image_base64'] as String? ?? '',
      );

      // The commenter is notified by the event_replies trigger
      // (notify_event_comment_reply).
      return newReply;
    } catch (e) {
      throw Exception('Error creating reply: $e');
    }
  }

  /// Get all replies for a comment
  Future<List<EventComment>> getReplies(
    String eventId,
    String commentId,
  ) async {
    try {
      final rows = await _supabase
          .from('event_replies')
          .select()
          .eq('comment_id', commentId)
          .order('created_at', ascending: true);
      return _attachUserInfo(rows);
    } catch (e) {
      throw Exception('Error fetching replies: $e');
    }
  }

  /// Stream of replies for real-time updates
  Stream<List<EventComment>> getRepliesStream(
    String eventId,
    String commentId,
  ) {
    return _supabase
        .from('event_replies')
        .stream(primaryKey: ['id'])
        .eq('comment_id', commentId)
        .asyncMap((rows) async {
          final sorted = List<Map<String, dynamic>>.from(rows)
            ..sort(
              (a, b) => (a['created_at'] as String? ?? '').compareTo(
                b['created_at'] as String? ?? '',
              ),
            );
          return _attachUserInfo(sorted);
        });
  }

  /// Delete a reply
  Future<void> deleteReply({
    required String eventId,
    required String commentId,
    required String replyId,
  }) async {
    if (AppSession.userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final isAdmin = await _isAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can delete replies');
      }

      await _supabase.from('event_replies').delete().eq('id', replyId);
    } catch (e) {
      throw Exception('Error deleting reply: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchUserInfo(String userId) async {
    try {
      return await _supabase
          .from('users')
          .select('display_name, email, profile_image_base64')
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<List<EventComment>> _attachUserInfo(
    List<Map<String, dynamic>> rows,
  ) async {
    final userIds = rows
        .map((r) => r['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final userInfoById = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      try {
        final users = await _supabase
            .from('users')
            .select('id, display_name, email, profile_image_base64, role')
            .inFilter('id', userIds);
        for (final u in users) {
          userInfoById[u['id'] as String] = u;
        }
      } catch (_) {}
    }

    return rows.map((row) {
      final info = userInfoById[row['user_id']?.toString()];
      return EventComment.fromSupabaseRow(
        row,
        userName: info?['display_name'] as String? ?? 'Unknown',
        userEmail: info?['email'] as String? ?? '',
        profileImageUrl: info?['profile_image_base64'] as String? ?? '',
      );
    }).toList();
  }
}
