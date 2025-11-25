import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alumni_system/models/event_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a new event to Firestore
  Future<void> addEvent(AlumniEvent event) async {
    try {
      await _firestore.collection('events').doc(event.id).set(
            event.toFirestore(),
          );
    } catch (e) {
      throw Exception('Error adding event: $e');
    }
  }

  /// Get all active events
  Future<List<AlumniEvent>> getActiveEvents() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'Active')
          .get();

      // Sort in Dart instead of Firestore (temporary until index is created)
      final events = snapshot.docs.map((doc) => AlumniEvent.fromFirestore(doc)).toList();
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      throw Exception('Error fetching events: $e');
    }
  }

  /// Get all events (including archived)
  Future<List<AlumniEvent>> getAllEvents() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs.map((doc) => AlumniEvent.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error fetching events: $e');
    }
  }

  /// Get events by batch year
  Future<List<AlumniEvent>> getEventsByBatchYear(String batchYear) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('batchYear', isEqualTo: batchYear)
          .where('status', isEqualTo: 'Active')
          .get();

      // Sort in Dart instead of Firestore (temporary until index is created)
      final events = snapshot.docs.map((doc) => AlumniEvent.fromFirestore(doc)).toList();
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      throw Exception('Error fetching events by batch year: $e');
    }
  }

  /// Update event status
  Future<void> updateEventStatus(String eventId, String newStatus) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'status': newStatus,
      });
    } catch (e) {
      throw Exception('Error updating event status: $e');
    }
  }

  /// Delete event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      throw Exception('Error deleting event: $e');
    }
  }

  /// Archive event
  Future<void> archiveEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'status': 'Archived',
      });
    } catch (e) {
      throw Exception('Error archiving event: $e');
    }
  }

  /// Stream of active events (real-time updates)
  Stream<List<AlumniEvent>> getActiveEventsStream() {
    return _firestore
        .collection('events')
        .where('status', isEqualTo: 'Active')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AlumniEvent.fromFirestore(doc)).toList());
  }

  /// Add reminder for user
  Future<void> addReminder(String userId, String eventId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .doc(eventId)
          .set({
        'eventId': eventId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error adding reminder: $e');
    }
  }

  /// Remove reminder for user
  Future<void> removeReminder(String userId, String eventId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .doc(eventId)
          .delete();
    } catch (e) {
      throw Exception('Error removing reminder: $e');
    }
  }

  /// Check if user has reminder for event
  Future<bool> hasReminder(String userId, String eventId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .doc(eventId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Add notification for user
  Future<void> addNotification(
    String userId,
    String title,
    String message,
    String eventId,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': message,
        'eventId': eventId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      throw Exception('Error adding notification: $e');
    }
  }

  /// Get user notifications
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  /// Stream of user notifications (real-time)
  Stream<List<Map<String, dynamic>>> getUserNotificationsStream(
      String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      throw Exception('Error marking notification as read: $e');
    }
  }
}
