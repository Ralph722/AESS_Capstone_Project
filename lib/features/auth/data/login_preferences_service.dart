import 'package:shared_preferences/shared_preferences.dart';

/// Persists login UI preferences (email only — never store passwords).
class LoginPreferencesService {
  static const _rememberMeKey = 'login_remember_me';
  static const _savedEmailKey = 'login_saved_email';

  Future<({bool rememberMe, String? email})> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    final email = prefs.getString(_savedEmailKey);
    if (!rememberMe || email == null || email.isEmpty) {
      return (rememberMe: false, email: null);
    }
    return (rememberMe: true, email: email);
  }

  Future<void> save({required bool rememberMe, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe && email.trim().isNotEmpty) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, email.trim());
    } else {
      await clear();
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_savedEmailKey);
  }
}
