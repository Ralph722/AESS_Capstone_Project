import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteJobService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get favorites collection for a specific user
  CollectionReference _getFavoritesCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('favorite_jobs');

  /// Get the correct user ID for favorites (handles both uid and userDocId)
  Future<String> _getUserIdForFavorites() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // First, try using uid as document ID
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      return user.uid;
    }

    // If not found, try finding by uid field
    final userSnapshot = await _firestore
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (userSnapshot.docs.isNotEmpty) {
      return userSnapshot.docs.first.id;
    }

    // Fallback to uid
    return user.uid;
  }

  /// Add a job to favorites
  Future<void> addToFavorites(String jobId) async {
    try {
      final userId = await _getUserIdForFavorites();
      
      await _getFavoritesCollection(userId).doc(jobId).set({
        'jobId': jobId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error adding job to favorites: $e');
    }
  }

  /// Remove a job from favorites
  Future<void> removeFromFavorites(String jobId) async {
    try {
      final userId = await _getUserIdForFavorites();
      
      await _getFavoritesCollection(userId).doc(jobId).delete();
    } catch (e) {
      throw Exception('Error removing job from favorites: $e');
    }
  }

  /// Check if a job is in favorites
  Future<bool> isFavorite(String jobId) async {
    try {
      final userId = await _getUserIdForFavorites();
      
      final doc = await _getFavoritesCollection(userId).doc(jobId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get all favorite job IDs
  Future<List<String>> getFavoriteJobIds() async {
    try {
      final userId = await _getUserIdForFavorites();
      
      final snapshot = await _getFavoritesCollection(userId).get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream of favorite job IDs for real-time updates
  Stream<List<String>> getFavoriteJobIdsStream() async* {
    try {
      await for (final user in _auth.authStateChanges()) {
        if (user == null) {
          yield <String>[];
          continue;
        }

        try {
          // Try using uid as document ID first
          yield* _firestore
              .collection('users')
              .doc(user.uid)
              .collection('favorite_jobs')
              .snapshots()
              .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
        } catch (e) {
          // If that fails, try finding by uid field
          try {
            final userSnapshot = await _firestore
                .collection('users')
                .where('uid', isEqualTo: user.uid)
                .limit(1)
                .get();

            if (userSnapshot.docs.isNotEmpty) {
              final userDocId = userSnapshot.docs.first.id;
              yield* _firestore
                  .collection('users')
                  .doc(userDocId)
                  .collection('favorite_jobs')
                  .snapshots()
                  .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
            } else {
              yield <String>[];
            }
          } catch (e2) {
            yield <String>[];
          }
        }
      }
    } catch (e) {
      yield <String>[];
    }
  }
}

