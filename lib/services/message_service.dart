import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get count of unread messages from admin to current user
  Future<int> getUnreadMessagesCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      // Get user doc ID
      final userSnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      final userDocId = userSnapshot.docs.isNotEmpty ? userSnapshot.docs.first.id : null;

      // Query for unread messages from admin to this user
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _firestore
            .collection('messages')
            .where('recipientId', isEqualTo: user.uid)
            .where('senderRole', isEqualTo: 'admin')
            .where('isRead', isEqualTo: false)
            .get(),
      ];

      if (userDocId != null) {
        queries.add(
          _firestore
              .collection('messages')
              .where('recipientId', isEqualTo: userDocId)
              .where('senderRole', isEqualTo: 'admin')
              .where('isRead', isEqualTo: false)
              .get(),
        );
      }

      final snapshots = await Future.wait(queries);
      final messageIds = <String>{};

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          messageIds.add(doc.id);
        }
      }

      return messageIds.length;
    } catch (e) {
      print('Error getting unread messages count: $e');
      return 0;
    }
  }

  /// Stream of unread messages count for real-time updates using Firestore snapshots
  Stream<int> getUnreadMessagesCountStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    // Use Firestore snapshots for real-time updates
    // Primary query: messages where recipientId matches user uid
    return _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: user.uid)
        .where('senderRole', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
      print('Error in unread messages stream: $error');
      return 0;
    });
  }

  /// Mark messages from admin as read when user views them
  Future<void> markAdminMessagesAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get user doc ID
      final userSnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      final userDocId = userSnapshot.docs.isNotEmpty ? userSnapshot.docs.first.id : null;

      // Get all unread messages from admin
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _firestore
            .collection('messages')
            .where('recipientId', isEqualTo: user.uid)
            .where('senderRole', isEqualTo: 'admin')
            .where('isRead', isEqualTo: false)
            .get(),
      ];

      if (userDocId != null) {
        queries.add(
          _firestore
              .collection('messages')
              .where('recipientId', isEqualTo: userDocId)
              .where('senderRole', isEqualTo: 'admin')
              .where('isRead', isEqualTo: false)
              .get(),
        );
      }

      final snapshots = await Future.wait(queries);

      // Update all unread messages to read
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
          batchCount++;
          
          // Firestore batch limit is 500
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
}

