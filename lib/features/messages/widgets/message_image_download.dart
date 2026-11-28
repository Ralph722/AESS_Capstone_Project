import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:alumni_system/core/utils/image_file_delivery.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';

/// Downloads a chat attachment to the gallery (or share sheet / browser).
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

    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final result = await shareOrSaveImageBytes(
      bytes: bytes,
      fileName: imageFileNameForMime(fileName, mime),
      mimeType: mime,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.successMessage),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not download image')),
    );
  }
}
