/// Soft survey/tracer reminder: once per app session while items are pending.
class SurveyAttentionReminder {
  SurveyAttentionReminder._();

  static bool _shownThisSession = false;

  static Future<bool> shouldShow({required bool hasActions}) async {
    if (!hasActions || _shownThisSession) return false;
    return true;
  }

  static void markShownThisSession() {
    _shownThisSession = true;
  }

  /// User chose Later — don't remind again until the next app session.
  static Future<void> snoozeForToday() async {
    _shownThisSession = true;
  }

  static Future<void> markActed() async {
    _shownThisSession = true;
  }

  /// For hot-restart / tests: allow the reminder again in this session.
  static void resetForSession() {
    _shownThisSession = false;
  }
}
