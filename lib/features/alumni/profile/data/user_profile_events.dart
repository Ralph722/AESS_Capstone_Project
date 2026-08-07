import 'dart:async';

/// Cross-screen signals for profile fields kept alive in [IndexedStack] tabs.
class UserProfileEvents {
  UserProfileEvents._();

  static final StreamController<String?> _avatarController =
      StreamController<String?>.broadcast();

  static final StreamController<void> _fieldsController =
      StreamController<void>.broadcast();

  /// Emits the new avatar URL (Storage URL or legacy data URL) after upload.
  static Stream<String?> get onAvatarChanged => _avatarController.stream;

  /// Fires when profile demographics were updated outside the Profile screen
  /// (e.g. CHED GTS Section A/B submit sync).
  static Stream<void> get onProfileFieldsChanged => _fieldsController.stream;

  static void notifyAvatarChanged(String? url) {
    if (!_avatarController.isClosed) {
      _avatarController.add(url);
    }
  }

  static void notifyProfileFieldsChanged() {
    if (!_fieldsController.isClosed) {
      _fieldsController.add(null);
    }
  }
}
