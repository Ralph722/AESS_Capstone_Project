import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';

/// Shared compress → validate → upload pipeline for chat attachments.
class MessageImagePipeline {
  MessageImagePipeline({ImageStorageService? storage})
      : _storage = storage ?? ImageStorageService();

  final ImageStorageService _storage;

  static const int maxSourceBytes = ImageStorageService.maxSourceBytes;
  static const int targetUploadBytes = 700 * 1024; // ~700KB JPEG
  static const int absoluteMaxUploadBytes = ImageStorageService.maxUploadBytes;

  /// Compresses [file] / [bytes] to a validated JPEG under [targetUploadBytes].
  Future<Uint8List> compress({
    File? file,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.05);

    if (bytes != null && bytes.length > maxSourceBytes) {
      throw MessageImageException(
        'Image is too large. Please choose a file under 12 MB.',
      );
    }
    if (file != null) {
      final len = await file.length();
      if (len > maxSourceBytes) {
        throw MessageImageException(
          'Image is too large. Please choose a file under 12 MB.',
        );
      }
    }

    onProgress?.call(0.15);

    Uint8List compressed;
    if (kIsWeb && bytes != null) {
      compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 1920,
        minWidth: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );
    } else if (file != null) {
      final out = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minHeight: 1920,
        minWidth: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      compressed = out ?? await file.readAsBytes();
    } else if (bytes != null) {
      compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 1920,
        minWidth: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );
    } else {
      throw MessageImageException('No image selected.');
    }

    onProgress?.call(0.35);

    var quality = 85;
    while (compressed.length > targetUploadBytes && quality > 30) {
      quality -= 10;
      Uint8List? next;
      if (kIsWeb && bytes != null) {
        next = await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 1920,
          minWidth: 1920,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      } else if (file != null) {
        next = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minHeight: 1920,
          minWidth: 1920,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      } else if (bytes != null) {
        next = await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 1920,
          minWidth: 1920,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      }
      if (next == null) break;
      compressed = next;
      onProgress?.call(0.35 + ((85 - quality) / 55) * 0.25);
    }

    if (compressed.length > targetUploadBytes) {
      Uint8List? smaller;
      if (kIsWeb && bytes != null) {
        smaller = await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 1280,
          minWidth: 1280,
          quality: 70,
          format: CompressFormat.jpeg,
        );
      } else if (file != null) {
        smaller = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minHeight: 1280,
          minWidth: 1280,
          quality: 70,
          format: CompressFormat.jpeg,
        );
      } else if (bytes != null) {
        smaller = await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 1280,
          minWidth: 1280,
          quality: 70,
          format: CompressFormat.jpeg,
        );
      }
      if (smaller != null) compressed = smaller;
    }

    onProgress?.call(0.65);

    if (compressed.isEmpty) {
      throw MessageImageException('Failed to process image.');
    }
    if (compressed.length > absoluteMaxUploadBytes) {
      throw MessageImageException(
        'Could not compress this image enough. Try a smaller photo.',
      );
    }

    // JPEG SOI check
    if (compressed.length < 3 ||
        compressed[0] != 0xFF ||
        compressed[1] != 0xD8) {
      throw MessageImageException('Invalid image data after compression.');
    }

    return compressed;
  }

  /// Compress + upload. [onProgress] is 0.0–1.0.
  ///
  /// [userId] must match the signed-in auth uid (enforced in Storage service).
  Future<String> compressAndUpload({
    required String userId,
    required String messageId,
    File? file,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
  }) async {
    final compressed = await compress(
      file: file,
      bytes: bytes,
      onProgress: onProgress,
    );
    onProgress?.call(0.75);
    final url = await _storage.uploadMessageImage(
      userId: userId,
      messageId: messageId,
      bytes: compressed,
    );
    onProgress?.call(1.0);
    return url;
  }
}

class MessageImageException implements Exception {
  MessageImageException(this.message);
  final String message;

  @override
  String toString() => message;
}
