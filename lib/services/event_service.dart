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

  /// Auto-archive past events (events where date has passed)
  Future<void> autoArchivePastEvents() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final snapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'Active')
          .get();

      final batch = _firestore.batch();
      int archivedCount = 0;

      for (var doc in snapshot.docs) {
        final event = AlumniEvent.fromFirestore(doc);
        final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
        
        // Archive events that have passed (date is before today)
        if (eventDate.isBefore(today)) {
          batch.update(doc.reference, {'status': 'Archived'});
          archivedCount++;
        }
      }

      if (archivedCount > 0) {
        await batch.commit();
        print('Auto-archived $archivedCount past event(s)');
      }
    } catch (e) {
      print('Error auto-archiving past events: $e');
      // Don't throw, just log the error
    }
  }

  /// Get all active events (for admin - includes all active events)
  Future<List<AlumniEvent>> getActiveEvents() async {
    try {
      // Auto-archive past events first
      await autoArchivePastEvents();
      
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

  /// Get upcoming events only (for users - excludes past events)
  Future<List<AlumniEvent>> getUpcomingEvents() async {
    try {
      // Auto-archive past events first
      await autoArchivePastEvents();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final snapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'Active')
          .get();

      // Filter out past events and sort
      final events = snapshot.docs
          .map((doc) => AlumniEvent.fromFirestore(doc))
          .where((event) {
            final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
            return eventDate.isAtSameMomentAs(today) || eventDate.isAfter(today);
          })
          .toList();
      
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      throw Exception('Error fetching upcoming events: $e');
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

  /// Get all archived events
  Future<List<AlumniEvent>> getArchivedEvents() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'Archived')
          .get();

      final events = snapshot.docs.map((doc) => AlumniEvent.fromFirestore(doc)).toList();
      events.sort((a, b) => b.date.compareTo(a.date)); // Most recent first
      return events;
    } catch (e) {
      throw Exception('Error fetching archived events: $e');
    }
  }

  /// Get total count of all events
  Future<int> getTotalEventsCount() async {
    try {
      final snapshot = await _firestore.collection('events').get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Error fetching total events count: $e');
    }
  }

  /// Get count of expiring events (events within 7 days)
  Future<int> getExpiringEventsCount() async {
    try {
      final snapshot = await _firestore.collection('events').where('status', isEqualTo: 'Active').get();
      
      final now = DateTime.now();
      final sevenDaysLater = now.add(const Duration(days: 7));
      
      final expiringCount = snapshot.docs.where((doc) {
        final event = AlumniEvent.fromFirestore(doc);
        return event.date.isAfter(now) && event.date.isBefore(sevenDaysLater);
      }).length;
      
      return expiringCount;
    } catch (e) {
      throw Exception('Error fetching expiring events count: $e');
    }
  }

  /// Get count of archived events
  Future<int> getArchivedEventsCount() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'Archived')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Error fetching archived events count: $e');
    }
  }

  /// Update event details
  Future<void> updateEvent(AlumniEvent event) async {
    try {
      await _firestore.collection('events').doc(event.id).update(
            event.toFirestore(),
          );
    } catch (e) {
      throw Exception('Error updating event: $e');
    }
  }

  /// Restore archived event (change status back to Active)
  Future<void> restoreEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'status': 'Active',
      });
    } catch (e) {
      throw Exception('Error restoring event: $e');
    }
  }

  /// Stream of active events (real-time updates) - for admin
  Stream<List<AlumniEvent>> getActiveEventsStream() {
    return _firestore
        .collection('events')
        .where('status', isEqualTo: 'Active')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AlumniEvent.fromFirestore(doc)).toList());
  }

  /// Stream of upcoming events (real-time updates) - for users
  Stream<List<AlumniEvent>> getUpcomingEventsStream() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return _firestore
        .collection('events')
        .where('status', isEqualTo: 'Active')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AlumniEvent.fromFirestore(doc))
              .where((event) {
                final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
                return eventDate.isAtSameMomentAs(today) || eventDate.isAfter(today);
              })
              .toList();
        });
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
