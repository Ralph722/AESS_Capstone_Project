import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alumni_system/models/notification_model.dart';
import 'dart:async';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get notifications collection for a specific user
  CollectionReference _getNotificationsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  // Create a notification
  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = NotificationModel(
        id: _getNotificationsCollection(userId).doc().id,
        userId: userId,
        type: type,
        title: title,
        message: message,
        relatedId: relatedId,
        isRead: false,
        createdAt: DateTime.now(),
        data: data,
      );

      await _getNotificationsCollection(
        userId,
      ).doc(notification.id).set(notification.toMap());
    } catch (e) {
      print('Error creating notification: $e');
      rethrow;
    }
  }

  // Create notification for all users (admin announcements)
  Future<void> createNotificationForAllUsers({
    required NotificationType type,
    required String title,
    required String message,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all user IDs from Firestore users collection
      final usersSnapshot = await _firestore.collection('users').get();

      final Set<String> userIds = {};

      // Add all users from Firestore
      for (var doc in usersSnapshot.docs) {
        userIds.add(doc.id);
      }

      if (userIds.isEmpty) {
        return;
      }

      // Firestore batch limit is 500, so we need to handle large batches
      WriteBatch? batch = _firestore.batch();
      int batchCount = 0;

      for (var userId in userIds) {
        final notification = NotificationModel(
          id: _getNotificationsCollection(userId).doc().id,
          userId: userId,
          type: type,
          title: title,
          message: message,
          relatedId: relatedId,
          isRead: false,
          createdAt: DateTime.now(),
          data: data,
        );
        final notificationRef = _getNotificationsCollection(
          userId,
        ).doc(notification.id);
        batch!.set(notificationRef, notification.toMap());
        batchCount++;

        // Commit batch if it reaches 500 (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          batch = _firestore.batch(); // Create new batch
          batchCount = 0;
        }
      }

      // Commit remaining notifications
      if (batchCount > 0 && batch != null) {
        await batch.commit();
      }
    } catch (e) {
      print('Error creating notifications for all users: $e');
      rethrow;
    }
  }

  // Get notifications for current user
  Future<List<NotificationModel>> getUserNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      // Get notifications from user's subcollection
      Query query = _getNotificationsCollection(user.uid);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      final snapshot = await query.get();

      // Sort by createdAt descending and limit
      final notifications = snapshot.docs
          .map((doc) {
            try {
              return NotificationModel.fromFirestore(doc);
            } catch (e) {
              print('Error parsing notification doc ${doc.id}: $e');
              return null;
            }
          })
          .where((n) => n != null)
          .cast<NotificationModel>()
          .toList();

      // Sort by createdAt descending
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply limit
      return notifications.take(limit).toList();
    } catch (e) {
      print('Error getting user notifications: $e');
      return [];
    }
  }

  // Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final snapshot = await _getNotificationsCollection(
        user.uid,
      ).where('isRead', isEqualTo: false).get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Stream of unread count
  Stream<int> getUnreadCountStream() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Stream.value(0);
      }

      return _getNotificationsCollection(user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('Error getting unread count stream: $e');
      return Stream.value(0);
    }
  }

  // Stream of notifications
  Stream<List<NotificationModel>> getNotificationsStream({int limit = 50}) {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Stream.value([]);
      }

      return _getNotificationsCollection(user.uid)
          .snapshots()
          .map((snapshot) {
            final notifications = snapshot.docs
                .map((doc) {
                  try {
                    return NotificationModel.fromFirestore(doc);
                  } catch (e) {
                    return null;
                  }
                })
                .where((n) => n != null)
                .cast<NotificationModel>()
                .toList();

            // Sort by createdAt descending
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            // Apply limit
            return notifications.take(limit).toList();
          })
          .handleError((error) {
            print('Error in notifications stream: $error');
            return <NotificationModel>[];
          });
    } catch (e) {
      print('Error getting notifications stream: $e');
      return Stream.value([]);
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _getNotificationsCollection(
        user.uid,
      ).doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _getNotificationsCollection(
        user.uid,
      ).where('isRead', isEqualTo: false).get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _getNotificationsCollection(user.uid).doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }

  // Delete all read notifications
  Future<void> deleteAllRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _getNotificationsCollection(
        user.uid,
      ).where('isRead', isEqualTo: true).get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting all read notifications: $e');
      rethrow;
    }
  }

  // Helper: Notify users about new event
  Future<void> notifyNewEvent({
    required String eventId,
    required String eventTitle,
    required String eventDate,
  }) async {
    await createNotificationForAllUsers(
      type: NotificationType.event,
      title: 'New Event: $eventTitle',
      message: 'A new event has been scheduled on $eventDate',
      relatedId: eventId,
      data: {'eventTitle': eventTitle, 'eventDate': eventDate},
    );
  }

  // Helper: Notify users about new job
  Future<void> notifyNewJob({
    required String jobId,
    required String jobTitle,
    required String companyName,
  }) async {
    await createNotificationForAllUsers(
      type: NotificationType.job,
      title: 'New Job Opportunity: $jobTitle',
      message: '$companyName is looking for $jobTitle',
      relatedId: jobId,
      data: {'jobTitle': jobTitle, 'companyName': companyName},
    );
  }

  // Helper: Notify user about new message
  Future<void> notifyNewMessage({
    required String userId,
    required String messageId,
    required String senderName,
  }) async {
    await createNotification(
      userId: userId,
      type: NotificationType.message,
      title: 'New Message from $senderName',
      message: 'You have received a new message',
      relatedId: messageId,
      data: {'senderName': senderName},
    );
  }
}
