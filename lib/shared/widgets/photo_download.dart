import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/image_file_delivery.dart';

/// Saves a photo: browser download on web; gallery (or share sheet) on device.
/// [baseName] becomes the file name (e.g. "Job_Title_cover").
Future<void> downloadPhoto(
  BuildContext context, {
  required String url,
  required String baseName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void show(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );

  final value = url.trim();
  if (value.isEmpty) return;

  try {
    final Uint8List bytes;
    String mime;
    if (AppImage.isDataUrl(value)) {
      bytes = AppImage.decodeDataUrl(value);
      mime =
          RegExp(r'^data:([^;,]+)').firstMatch(value)?.group(1) ?? 'image/jpeg';
    } else {
      final response = await http
          .get(Uri.parse(value))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('download failed (${response.statusCode})');
      }
      bytes = response.bodyBytes;
      mime =
          response.headers['content-type']?.split(';').first.trim() ??
          'image/jpeg';
    }

    final fileName = imageFileNameForMime(
      baseName
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_'),
      mime,
    );

    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final result = await shareOrSaveImageBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mime,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
    if (!context.mounted) return;
    show(result.successMessage);
  } catch (e) {
    if (!context.mounted) return;
    show('Could not download the photo: $e');
  }
}

/// Round "download" button for overlaying on a photo.
class PhotoDownloadButton extends StatefulWidget {
  const PhotoDownloadButton({
    super.key,
    required this.url,
    required this.baseName,
  });

  final String url;
  final String baseName;

  @override
  State<PhotoDownloadButton> createState() => _PhotoDownloadButtonState();
}

class _PhotoDownloadButtonState extends State<PhotoDownloadButton> {
  bool _saving = false;

  Future<void> _download() async {
    setState(() => _saving = true);
    await downloadPhoto(context, url: widget.url, baseName: widget.baseName);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _saving ? null : _download,
        child: Tooltip(
          message: 'Download photo',
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}
