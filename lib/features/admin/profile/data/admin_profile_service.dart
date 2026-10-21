import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/avatar_image_prepare.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';

/// The signed-in admin's display name, email and avatar.
@immutable
class AdminProfile {
  const AdminProfile({required this.name, required this.email, this.avatarUrl});

  /// Built from the auth session alone, before the `users` row has loaded.
  factory AdminProfile.fromUser(User? user) {
    final email = user?.email ?? '';
    final metaName = (user?.userMetadata?['display_name'] as String?)?.trim();
    return AdminProfile(
      name: _fallbackName(metaName, email),
      email: email,
    );
  }

  static const int maxNameLength = 60;

  final String name;
  final String email;

  /// Storage URL (or legacy data URL); null when the admin has no photo.
  final String? avatarUrl;

  bool get hasAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  AdminProfile copyWithName(String name) => AdminProfile(
    name: normalizeName(name),
    email: email,
    avatarUrl: avatarUrl,
  );

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Trims and collapses inner whitespace.
  static String normalizeName(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? validateName(String? raw) {
    final name = normalizeName(raw ?? '');
    if (name.isEmpty) return 'Enter your name.';
    if (name.length < 2) return 'Name must be at least 2 characters.';
    if (name.length > maxNameLength) {
      return 'Name must be $maxNameLength characters or fewer.';
    }
    return null;
  }

  static String _fallbackName(String? name, String email) {
    if (name != null && name.isNotEmpty) return name;
    if (email.isNotEmpty) return email.split('@').first;
    return 'Admin';
  }

  @override
  bool operator ==(Object other) =>
      other is AdminProfile &&
      other.name == name &&
      other.email == email &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(name, email, avatarUrl);
}

/// Reads and saves the admin's own profile.
///
/// The name is written to both `users.display_name` (what alumni see in
/// messages and event replies) and the auth metadata (used for feedback
/// responses), so the two never drift apart.
class AdminProfileService {
  AdminProfileService({SupabaseClient? supabase, ImageStorageService? storage})
    : _supabase = supabase ?? Supabase.instance.client,
      _storage = storage;

  final SupabaseClient _supabase;
  final ImageStorageService? _storage;

  ImageStorageService get _images =>
      _storage ?? ImageStorageService(supabase: _supabase);

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Not signed in.');
    return user;
  }

  Future<AdminProfile> load() async {
    final user = _supabase.auth.currentUser;
    final fallback = AdminProfile.fromUser(user);
    if (user == null) return fallback;

    final row = await _supabase
        .from('users')
        .select('display_name, email, profile_image_base64')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return fallback;

    final name = (row['display_name'] as String?)?.trim() ?? '';
    final email = (row['email'] as String?)?.trim() ?? '';
    final avatar = (row['profile_image_base64'] as String?)?.trim() ?? '';
    return AdminProfile(
      name: name.isNotEmpty ? name : fallback.name,
      email: email.isNotEmpty ? email : fallback.email,
      avatarUrl: avatar.isNotEmpty ? avatar : null,
    );
  }

  /// Saves [name] and, when given, a new [photo] (raw picked bytes) or
  /// removes the current photo. Returns the saved profile.
  Future<AdminProfile> save({
    required AdminProfile current,
    required String name,
    Uint8List? photo,
    bool removePhoto = false,
  }) async {
    final user = _requireUser();
    final normalized = AdminProfile.normalizeName(name);
    final error = AdminProfile.validateName(normalized);
    if (error != null) throw ArgumentError(error);

    String? avatarUrl = current.avatarUrl;
    if (photo != null) {
      final prepared = await AvatarImagePrepare.toSquareJpeg(photo);
      avatarUrl = await _images.uploadProfileImage(
        userId: user.id,
        bytes: prepared,
      );
      AppImage.clearDecodedCache();
    } else if (removePhoto) {
      await _images.deleteProfileImage(user.id, avatarUrl: avatarUrl);
      avatarUrl = null;
    }

    final updated = await _supabase
        .from('users')
        .update({
          'display_name': normalized,
          'profile_image_base64': avatarUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id)
        .select('id');
    if (updated.isEmpty) {
      throw StateError('Profile row not found or not writable.');
    }

    if (user.userMetadata?['display_name'] != normalized) {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'display_name': normalized}),
      );
    }

    return AdminProfile(
      name: normalized,
      email: current.email,
      avatarUrl: avatarUrl,
    );
  }
}

/// Shared, listenable admin profile for the header and dashboard.
class AdminProfileController extends ValueNotifier<AdminProfile> {
  AdminProfileController({
    required AdminProfile initial,
    AdminProfileService? service,
  }) : _service = service,
       super(initial);

  final AdminProfileService? _service;

  AdminProfileService get _svc => _service ?? AdminProfileService();

  /// Reloads from the database; keeps the current value on failure.
  Future<void> refresh() async {
    try {
      value = await _svc.load();
    } catch (_) {}
  }

  Future<void> save({
    required String name,
    Uint8List? photo,
    bool removePhoto = false,
  }) async {
    value = await _svc.save(
      current: value,
      name: name,
      photo: photo,
      removePhoto: removePhoto,
    );
  }
}
