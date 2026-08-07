import 'package:supabase_flutter/supabase_flutter.dart';

/// App-wide session — Supabase Auth is the only identity source.
class AppSession {
  const AppSession._();

  static GoTrueClient get _auth => Supabase.instance.client.auth;

  static User? get currentUser => _auth.currentUser;

  static Session? get currentSession => _auth.currentSession;

  static String? get userId => currentUser?.id;

  static String? get email => currentUser?.email;

  static String requireUserId() {
    final id = userId;
    if (id == null || id.isEmpty) {
      throw Exception('Not signed in');
    }
    return id;
  }

  static bool get isSignedIn => currentUser != null;

  static Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;
}
