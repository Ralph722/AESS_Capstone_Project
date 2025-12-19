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

  /// Mark messages from a specific user as read when admin views them
  /// This marks all unread messages from a specific user to the admin as read
  Future<void> markUserMessagesAsReadForAdmin(String userMessagingId, {String? userDocId}) async {
    final admin = _auth.currentUser;
    if (admin == null) return;

    try {
      // Get admin doc ID
      final adminSnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: admin.uid)
          .limit(1)
          .get();

      final adminDocId = adminSnapshot.docs.isNotEmpty ? adminSnapshot.docs.first.id : null;

      final adminIds = <String>{
        admin.uid,
        if (adminDocId != null) adminDocId,
      };

      final userIds = <String>{
        if (userMessagingId.isNotEmpty) userMessagingId,
        if (userDocId != null && userDocId.isNotEmpty) userDocId,
      };

      if (adminIds.isEmpty || userIds.isEmpty) return;

      // Get all unread messages from this user to admin
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      // Query by recipientId (admin uid)
      queries.add(
        _firestore
            .collection('messages')
            .where('recipientId', isEqualTo: admin.uid)
            .where('senderRole', isEqualTo: 'user')
            .where('isRead', isEqualTo: false)
            .get(),
      );

      // Query by recipientDocId (admin doc ID)
      if (adminDocId != null) {
        queries.add(
          _firestore
              .collection('messages')
              .where('recipientDocId', isEqualTo: adminDocId)
              .where('senderRole', isEqualTo: 'user')
              .where('isRead', isEqualTo: false)
              .get(),
        );
      }

      final snapshots = await Future.wait(queries);

      // Update all unread messages from this user to read
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final senderId = data['senderId'] as String?;
          final senderDocId = data['senderDocId'] as String?;

          // Only mark messages from this specific user
          if (userIds.contains(senderId) || userIds.contains(senderDocId)) {
            batch.update(doc.reference, {'isRead': true});
            batchCount++;
            
            // Firestore batch limit is 500
            if (batchCount >= 500) {
              await batch.commit();
              batchCount = 0;
            }
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('Error marking user messages as read for admin: $e');
    }
  }
}

