import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/core/utils/web_file_download.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';

/// Downloads a chat attachment (web file save) or opens it (mobile).
Future<void> downloadMessageImage({
  required BuildContext context,
  required String imageUrl,
  Uint8List? decodedBytes,
  String fileName = 'aess-message-image.jpg',
}) async {
  try {
    Uint8List? bytes = decodedBytes;
    String mime = 'image/jpeg';

    if (bytes == null) {
      if (imageUrl.startsWith('data:')) {
        final comma = imageUrl.indexOf(',');
        if (comma < 0) throw StateError('Invalid data URL');
        final meta = imageUrl.substring(5, comma); // image/png;base64
        final mimePart = meta.split(';').first;
        if (mimePart.startsWith('image/')) mime = mimePart;
        bytes = base64Decode(imageUrl.substring(comma + 1));
      } else {
        final url = await ImageStorageService.resolveMessageImageUrl(imageUrl);
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError('HTTP ${response.statusCode}');
        }
        bytes = response.bodyBytes;
        final ct = response.headers['content-type'];
        if (ct != null && ct.startsWith('image/')) {
          mime = ct.split(';').first.trim();
        }
      }
    }

    if (kIsWeb) {
      if (!context.mounted) return;
      final ok = tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName: _fileNameForMime(fileName, mime),
        mimeType: mime,
      );
      if (!ok || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image downloaded'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Mobile / desktop: open the image URL when remote; otherwise save via web-only path.
    if (!imageUrl.startsWith('data:')) {
      final uri = Uri.tryParse(
        await ImageStorageService.resolveMessageImageUrl(imageUrl),
      );
      if (uri != null && await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    }

    if (!context.mounted) return;
    // Fallback: still try browser download helper when available.
    if (isWebFileDownloadSupported) {
      downloadBytesOnWeb(
        bytes: bytes,
        fileName: _fileNameForMime(fileName, mime),
        mimeType: mime,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Download is available in the web portal. '
          'Open the image and save it from your browser.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not download image')),
    );
  }
}

String _fileNameForMime(String base, String mime) {
  final lower = base.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif')) {
    return base;
  }
  if (mime.contains('png')) return '$base.png';
  if (mime.contains('webp')) return '$base.webp';
  if (mime.contains('gif')) return '$base.gif';
  return base.endsWith('.jpg') ? base : '$base.jpg';
}
