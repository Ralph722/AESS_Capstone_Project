import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { admin, user }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user role from Firestore
  Future<UserRole?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final role = doc.data()?['role'] as String?;
        return role == 'admin' ? UserRole.admin : UserRole.user;
      }
      return UserRole.user; // Default to user role
    } catch (e) {
      return null;
    }
  }

  /// Set user role in Firestore
  Future<void> setUserRole(String uid, UserRole role) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'role': role == UserRole.admin ? 'admin' : 'user',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Login with email and password
  Future<User?> loginWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Register with email and password
  /// New sign-ups are always created as regular users
  Future<User?> registerWithEmailPassword(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Always set new sign-ups as regular users
        await setUserRole(user.uid, UserRole.user);
        
        // Update display name
        await user.updateDisplayName(fullName);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'email-already-in-use':
        return 'The email address is already in use.';
      case 'weak-password':
        return 'The password provided is too weak.';
      default:
        return 'An authentication error occurred: ${e.message}';
    }
  }
}
