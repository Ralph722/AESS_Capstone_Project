import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_data.dart';

/// Persists the last successful digital card for offline display.
///
/// The QR cannot be verified offline; only identity fields are restored.
class AlumniCardCache {
  AlumniCardCache({SharedPreferences? prefs}) : _prefsOrNull = prefs;

  SharedPreferences? _prefsOrNull;

  static String _key(String uid) => 'alumni_card_cache_v1_$uid';

  Future<SharedPreferences> get _prefs async =>
      _prefsOrNull ??= await SharedPreferences.getInstance();

  Future<void> save(String uid, AlumniCardData data) async {
    final id = uid.trim();
    if (id.isEmpty) return;
    final prefs = await _prefs;
    final full = jsonEncode(data.toJson());
    try {
      await prefs.setString(_key(id), full);
    } catch (_) {
      // Prefer a leaner payload if the photo string is too large for prefs.
      await prefs.setString(
        _key(id),
        jsonEncode(data.copyWith(profileImageUrl: null).toJson()),
      );
    }
  }

  Future<AlumniCardData?> load(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return null;
    final prefs = await _prefs;
    final raw = prefs.getString(_key(id));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return AlumniCardData.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return;
    final prefs = await _prefs;
    await prefs.remove(_key(id));
  }
}
