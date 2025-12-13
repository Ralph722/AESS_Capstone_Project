import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alumni_system/models/event_comment_model.dart';
import 'package:alumni_system/models/notification_model.dart';
import 'package:alumni_system/services/notification_service.dart';

class EventCommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get comments collection for an event
  CollectionReference _getCommentsCollection(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('comments');

  /// Create a new comment
  Future<EventComment> createComment({
    required String eventId,
    required String comment,
    String? userDocId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get user document ID if not provided
      String? docId = userDocId;
      if (docId == null) {
        final userSnapshot = await _firestore
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (userSnapshot.docs.isNotEmpty) {
          docId = userSnapshot.docs.first.id;
        }
      }

      final commentId = _getCommentsCollection(eventId).doc().id;
      final newComment = EventComment(
        id: commentId,
        eventId: eventId,
        userId: user.uid,
        userDocId: docId ?? '',
        userName: user.displayName ?? 'Anonymous',
        userEmail: user.email ?? '',
        comment: comment.trim(),
        createdAt: DateTime.now(),
      );

      await _getCommentsCollection(eventId)
          .doc(commentId)
          .set(newComment.toFirestore());

      // Update event comment count
      await _updateEventCommentCount(eventId, 1);

      return newComment;
    } catch (e) {
      throw Exception('Error creating comment: $e');
    }
  }

  /// Get all comments for an event
  Future<List<EventComment>> getComments(String eventId) async {
    try {
      final snapshot = await _getCommentsCollection(eventId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EventComment.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error fetching comments: $e');
    }
  }

  /// Stream of comments for real-time updates
  Stream<List<EventComment>> getCommentsStream(String eventId) {
    return _getCommentsCollection(eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventComment.fromFirestore(doc))
            .toList());
  }

  /// Update a comment
  Future<void> updateComment({
    required String eventId,
    required String commentId,
    required String newComment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final commentRef = _getCommentsCollection(eventId).doc(commentId);
      final commentDoc = await commentRef.get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data() as Map<String, dynamic>;
      final commentUserId = commentData['userId'] as String?;
      final commentUserDocId = commentData['userDocId'] as String?;

      // Check if user owns the comment or is admin
      final isOwner = commentUserId == user.uid ||
          (commentUserDocId != null &&
              await _isUserDocId(user.uid, commentUserDocId));
      final isAdmin = await _isAdmin();

      if (!isOwner && !isAdmin) {
        throw Exception('You do not have permission to edit this comment');
      }

      await commentRef.update({
        'comment': newComment.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error updating comment: $e');
    }
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String eventId,
    required String commentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final commentRef = _getCommentsCollection(eventId).doc(commentId);
      final commentDoc = await commentRef.get();

      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data() as Map<String, dynamic>;
      final commentUserId = commentData['userId'] as String?;
      final commentUserDocId = commentData['userDocId'] as String?;

      // Check if user owns the comment or is admin
      final isOwner = commentUserId == user.uid ||
          (commentUserDocId != null &&
              await _isUserDocId(user.uid, commentUserDocId));
      final isAdmin = await _isAdmin();

      if (!isOwner && !isAdmin) {
        throw Exception('You do not have permission to delete this comment');
      }

      await commentRef.delete();

      // Update event comment count
      await _updateEventCommentCount(eventId, -1);
    } catch (e) {
      throw Exception('Error deleting comment: $e');
    }
  }

  /// Get all comments across all events (for admin)
  Future<List<EventComment>> getAllComments() async {
    try {
      final eventsSnapshot = await _firestore.collection('events').get();
      final allComments = <EventComment>[];

      for (final eventDoc in eventsSnapshot.docs) {
        final commentsSnapshot = await eventDoc.reference
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .get();

        for (final commentDoc in commentsSnapshot.docs) {
          allComments.add(EventComment.fromFirestore(commentDoc));
        }
      }

      // Sort by creation date (newest first)
      allComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return allComments;
    } catch (e) {
      throw Exception('Error fetching all comments: $e');
    }
  }

  /// Stream of all comments (for admin)
  Stream<List<EventComment>> getAllCommentsStream() {
    return _firestore
        .collectionGroup('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventComment.fromFirestore(doc))
            .toList());
  }

  /// Helper: Check if user is admin
  Future<bool> _isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Try using UID as document ID first (standard approach)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['role'] == 'admin') {
          return true;
        }
      }

      // Fallback: Try querying by uid field (for backward compatibility)
      final userSnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data();
        return userData['role'] == 'admin';
      }

      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Helper: Check if uid matches userDocId
  Future<bool> _isUserDocId(String uid, String userDocId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userDocId).get();
      if (!userDoc.exists) return false;
      final userData = userDoc.data();
      return userData?['uid'] == uid;
    } catch (e) {
      return false;
    }
  }

  /// Update event comment count
  Future<void> _updateEventCommentCount(String eventId, int delta) async {
    try {
      final eventRef = _firestore.collection('events').doc(eventId);
      await eventRef.update({
        'comments': FieldValue.increment(delta),
      });
    } catch (e) {
      // Silently fail - comment count update is not critical
      print('Error updating comment count: $e');
    }
  }

  /// Get replies collection for a comment
  CollectionReference _getRepliesCollection(String eventId, String commentId) =>
      _firestore
          .collection('events')
          .doc(eventId)
          .collection('comments')
          .doc(commentId)
          .collection('replies');

  /// Create a reply to a comment (admin only)
  Future<EventComment> createReply({
    required String eventId,
    required String commentId,
    required String reply,
    required EventComment originalComment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Check if user is admin
    final isAdmin = await _isAdmin();
    if (!isAdmin) {
      throw Exception('Only admins can reply to comments');
    }

    try {
      // Get admin document ID
      String? adminDocId;
      final adminSnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (adminSnapshot.docs.isNotEmpty) {
        adminDocId = adminSnapshot.docs.first.id;
      }

      final replyId = _getRepliesCollection(eventId, commentId).doc().id;
      final newReply = EventComment(
        id: replyId,
        eventId: eventId,
        userId: user.uid,
        userDocId: adminDocId ?? '',
        userName: user.displayName ?? 'Admin',
        userEmail: user.email ?? '',
        comment: reply.trim(),
        createdAt: DateTime.now(),
      );

      await _getRepliesCollection(eventId, commentId)
          .doc(replyId)
          .set(newReply.toFirestore());

      // Send notification to the original commenter
      try {
        final notificationService = NotificationService();
        
        // Get event details for notification
        final eventDoc = await _firestore.collection('events').doc(eventId).get();
        final eventData = eventDoc.data();
        final eventTheme = eventData?['theme'] ?? 'Event';

        // Send notification to the user who made the original comment
        // Try both userId and userDocId
        if (originalComment.userId.isNotEmpty) {
          await notificationService.createNotification(
            userId: originalComment.userId,
            type: NotificationType.message,
            title: 'Admin replied to your comment',
            message: 'Admin replied to your comment on "$eventTheme": ${reply.trim()}',
            relatedId: eventId,
            data: {
              'commentId': commentId,
              'replyId': replyId,
              'eventId': eventId,
            },
          );
        } else if (originalComment.userDocId.isNotEmpty) {
          // Get user ID from doc ID
          final userDoc = await _firestore.collection('users').doc(originalComment.userDocId).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            final userUid = userData?['uid'] as String?;
            if (userUid != null && userUid.isNotEmpty) {
              await notificationService.createNotification(
                userId: userUid,
                type: NotificationType.message,
                title: 'Admin replied to your comment',
                message: 'Admin replied to your comment on "$eventTheme": ${reply.trim()}',
                relatedId: eventId,
                data: {
                  'commentId': commentId,
                  'replyId': replyId,
                  'eventId': eventId,
                },
              );
            }
          }
        }
      } catch (e) {
        // Don't fail reply creation if notification fails
        print('Error sending notification for reply: $e');
      }

      return newReply;
    } catch (e) {
      throw Exception('Error creating reply: $e');
    }
  }

  /// Get all replies for a comment
  Future<List<EventComment>> getReplies(String eventId, String commentId) async {
    try {
      final snapshot = await _getRepliesCollection(eventId, commentId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => EventComment.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error fetching replies: $e');
    }
  }

  /// Stream of replies for real-time updates
  Stream<List<EventComment>> getRepliesStream(String eventId, String commentId) {
    return _getRepliesCollection(eventId, commentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventComment.fromFirestore(doc))
            .toList());
  }

  /// Delete a reply
  Future<void> deleteReply({
    required String eventId,
    required String commentId,
    required String replyId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Only admins can delete replies
      final isAdmin = await _isAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can delete replies');
      }

      await _getRepliesCollection(eventId, commentId).doc(replyId).delete();
    } catch (e) {
      throw Exception('Error deleting reply: $e');
    }
  }
}

