import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'package:alumni_system/core/utils/web_file_download.dart';

/// How an image was delivered to the user.
enum ImageDeliveryKind {
  /// Browser download (Flutter web).
  browserDownload,

  /// Written straight into the device photo library / Pictures.
  gallery,

  /// System share sheet (Save to Files / Photos / other apps).
  shareSheet,
}

class ImageDeliveryResult {
  const ImageDeliveryResult(this.kind);

  final ImageDeliveryKind kind;

  String get successMessage => switch (kind) {
    ImageDeliveryKind.browserDownload => 'Photo downloaded',
    ImageDeliveryKind.gallery => 'Saved to your gallery',
    ImageDeliveryKind.shareSheet =>
      'Use Save Image or Files to keep a copy',
  };
}

bool get _supportsGallerySave {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    _ => false,
  };
}

/// Web: browser download. Mobile/desktop: save to gallery when possible,
/// otherwise open the system share sheet so the user can save to Photos/Files.
Future<ImageDeliveryResult> shareOrSaveImageBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  Rect? sharePositionOrigin,
}) async {
  final safeName = _sanitizeFileName(fileName);
  final mime = mimeType.trim().isEmpty ? 'image/jpeg' : mimeType.trim();

  if (kIsWeb) {
    downloadBytesOnWeb(bytes: bytes, fileName: safeName, mimeType: mime);
    return const ImageDeliveryResult(ImageDeliveryKind.browserDownload);
  }

  if (_supportsGallerySave) {
    try {
      final granted =
          await Gal.hasAccess() || await Gal.requestAccess();
      if (granted) {
        await Gal.putImageBytes(bytes, name: _galleryBaseName(safeName));
        return const ImageDeliveryResult(ImageDeliveryKind.gallery);
      }
    } on GalException {
      // Fall through to the share sheet.
    } catch (_) {
      // Fall through to the share sheet.
    }
  }

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mime, name: safeName)],
      fileNameOverrides: [safeName],
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
  return const ImageDeliveryResult(ImageDeliveryKind.shareSheet);
}

String imageFileNameForMime(String base, String mime) {
  final trimmed = base.trim().isEmpty ? 'photo' : base.trim();
  final lower = trimmed.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif')) {
    return trimmed;
  }
  if (mime.contains('png')) return '$trimmed.png';
  if (mime.contains('webp')) return '$trimmed.webp';
  if (mime.contains('gif')) return '$trimmed.gif';
  return '$trimmed.jpg';
}

String _sanitizeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[^\w\s.\-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return cleaned.isEmpty ? 'photo.jpg' : cleaned;
}

/// [Gal.putImageBytes] takes a name without extension.
String _galleryBaseName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0) return fileName;
  return fileName.substring(0, dot);
}
