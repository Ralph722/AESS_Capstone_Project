import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads images to Supabase Storage and returns public URLs.
///
/// Replaces the previous base64-in-database approach: only a short URL is
/// stored in Postgres, files live in the public `images` bucket.
class ImageStorageService {
  ImageStorageService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String bucket = 'images';
  static const int maxUploadBytes = 1024 * 1024;
  static final RegExp _safePathSegment = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');

  static bool isJpegBytes(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  /// Converts PNG/WebP/etc. to JPEG so Storage validation always passes.
  /// Gallery picks (especially on web) are often not JPEG even after resize.
  static Future<Uint8List> ensureJpegBytes(
    Uint8List bytes, {
    int maxSide = 1024,
    int quality = 85,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Cannot upload empty image.');
    }
    if (isJpegBytes(bytes) && bytes.length <= maxUploadBytes) {
      return bytes;
    }

    var qualityStep = quality;
    var compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxSide,
      minHeight: maxSide,
      quality: qualityStep,
      format: CompressFormat.jpeg,
    );

    while (compressed.length > maxUploadBytes && qualityStep > 40) {
      qualityStep -= 15;
      compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxSide,
        minHeight: maxSide,
        quality: qualityStep,
        format: CompressFormat.jpeg,
      );
    }

    if (compressed.isEmpty || !isJpegBytes(compressed)) {
      throw ArgumentError(
        'Could not convert this image to JPEG. Try a different photo.',
      );
    }
    if (compressed.length > maxUploadBytes) {
      // Last resort: smaller long edge.
      compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 640,
        minHeight: 640,
        quality: 70,
        format: CompressFormat.jpeg,
      );
    }
    if (compressed.isEmpty ||
        !isJpegBytes(compressed) ||
        compressed.length > maxUploadBytes) {
      throw ArgumentError('Image exceeds maximum upload size.');
    }
    return compressed;
  }

  /// True when [url] is a Storage message attachment (not raw base64).
  static bool isAllowedMessageImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final clean = url.trim();
    if (clean.startsWith('data:')) return false;
    if (clean.length > 2048) return false;
    return clean.contains('/object/public/$bucket/messages/') ||
        clean.startsWith('messages/');
  }

  static String sanitizePathSegment(String raw, {required String label}) {
    final trimmed = raw.trim();
    if (!_safePathSegment.hasMatch(trimmed)) {
      throw ArgumentError('Invalid $label for storage path.');
    }
    return trimmed;
  }

  /// Uploads [bytes] to [path] (overwriting) and returns a cache-busted URL.
  ///
  /// Non-JPEG inputs are converted automatically (PNG/WebP gallery picks).
  Future<String> uploadImage({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('Cannot upload empty image.');
    }
    if (contentType != 'image/jpeg' && contentType != 'image/jpg') {
      throw ArgumentError('Only JPEG uploads are allowed.');
    }

    final jpeg = await ensureJpegBytes(bytes);
    if (jpeg.length > maxUploadBytes) {
      throw ArgumentError('Image exceeds maximum upload size.');
    }
    if (!isJpegBytes(jpeg)) {
      throw ArgumentError('Upload rejected: not a valid JPEG.');
    }

    await _supabase.storage
        .from(bucket)
        .uploadBinary(
          path,
          jpeg,
          fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    final url = _supabase.storage.from(bucket).getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Uploads a profile avatar for [userId]. Stable path so it overwrites.
  Future<String> uploadProfileImage({
    required String userId,
    required Uint8List bytes,
  }) {
    final uid = _requireAuthUidMatching(userId);
    return uploadImage(bytes: bytes, path: 'avatars/$uid.jpg');
  }

  /// Uploads a chat image under the authenticated user's folder only.
  Future<String> uploadMessageImage({
    required String userId,
    required String messageId,
    required Uint8List bytes,
  }) {
    final uid = _requireAuthUidMatching(userId);
    final safeMessageId = sanitizePathSegment(messageId, label: 'messageId');
    return uploadImage(
      bytes: bytes,
      path: messageImagePath(uid, safeMessageId),
    );
  }

  String _requireAuthUidMatching(String userId) {
    final authUid = _supabase.auth.currentUser?.id;
    if (authUid == null || authUid.isEmpty) {
      throw StateError('Not signed in.');
    }
    final requested = sanitizePathSegment(userId, label: 'userId');
    if (requested != authUid) {
      throw StateError('Cannot upload images for another user.');
    }
    return authUid;
  }

  static String messageImagePath(String userId, String messageId) =>
      'messages/$userId/$messageId.jpg';

  /// Best-effort delete for a chat attachment URL or storage path.
  Future<void> deleteMessageImageByUrl(String? imageUrl) async {
    final path = storagePathFromPublicUrl(imageUrl);
    if (path == null) return;
    try {
      await _supabase.storage.from(bucket).remove([path]);
    } catch (_) {}
  }

  Future<void> deleteMessageImage({
    required String userId,
    required String messageId,
  }) async {
    try {
      await _supabase.storage.from(bucket).remove([
        messageImagePath(userId, messageId),
      ]);
    } catch (_) {}
  }

  /// Extracts `messages/...jpg` from a public Storage URL.
  static String? storagePathFromPublicUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (url.startsWith('data:')) return null;
    final clean = url.split('?').first;
    const marker = '/object/public/$bucket/';
    final idx = clean.indexOf(marker);
    if (idx >= 0) {
      final path = clean.substring(idx + marker.length);
      if (path.startsWith('messages/') ||
          path.startsWith('avatars/') ||
          path.startsWith('events/') ||
          path.startsWith('jobs/')) {
        return path;
      }
      return null;
    }
    if (clean.startsWith('messages/') ||
        clean.startsWith('avatars/') ||
        clean.startsWith('events/') ||
        clean.startsWith('jobs/')) {
      return clean;
    }
    return null;
  }

  /// Uploads an event cover image. Stable path so replace overwrites.
  Future<String> uploadEventCoverImage({
    required String eventId,
    required Uint8List bytes,
  }) {
    final safeEventId = sanitizePathSegment(eventId, label: 'eventId');
    return uploadImage(bytes: bytes, path: 'events/$safeEventId/cover.jpg');
  }

  /// Removes an event cover from storage when possible.
  Future<void> deleteEventCoverImage(String eventId) async {
    try {
      final safeEventId = sanitizePathSegment(eventId, label: 'eventId');
      await _supabase.storage.from(bucket).remove([
        'events/$safeEventId/cover.jpg',
      ]);
    } catch (_) {}
  }

  /// Company logo for a job posting (admin uploads; public read).
  Future<String> uploadJobCompanyLogo({
    required String jobId,
    required Uint8List bytes,
  }) {
    final safeJobId = sanitizePathSegment(jobId, label: 'jobId');
    return uploadImage(bytes: bytes, path: 'jobs/$safeJobId/logo.jpg');
  }

  /// Wide cover photo for a job posting (admin uploads; public read).
  Future<String> uploadJobCoverImage({
    required String jobId,
    required Uint8List bytes,
  }) {
    final safeJobId = sanitizePathSegment(jobId, label: 'jobId');
    return uploadImage(bytes: bytes, path: 'jobs/$safeJobId/cover.jpg');
  }

  Future<void> deleteJobCoverImage(String jobId) async {
    try {
      final safeJobId = sanitizePathSegment(jobId, label: 'jobId');
      await _supabase.storage.from(bucket).remove([
        'jobs/$safeJobId/cover.jpg',
      ]);
    } catch (_) {}
  }

  Future<void> deleteJobCompanyLogo(String jobId) async {
    try {
      final safeJobId = sanitizePathSegment(jobId, label: 'jobId');
      await _supabase.storage.from(bucket).remove(['jobs/$safeJobId/logo.jpg']);
    } catch (_) {}
  }
}
