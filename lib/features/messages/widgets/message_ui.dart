import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:alumni_system/features/messages/widgets/message_image_download.dart';

/// Fullscreen zoomable image viewer for chat attachments.
Future<void> showMessageImageViewer({
  required BuildContext context,
  required String imageUrl,
  Uint8List? decodedBytes,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: imageUrl.startsWith('data:')
                  ? Image.memory(
                      decodedBytes ??
                          base64Decode(imageUrl.split(',').last),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return _brokenImage();
                      },
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return _brokenImage();
                      },
                    ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Download',
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => downloadMessageImage(
                    context: context,
                    imageUrl: imageUrl,
                    decodedBytes: decodedBytes,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    shape: const CircleBorder(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _brokenImage() {
  return Container(
    padding: const EdgeInsets.all(20),
    color: Colors.grey.shade800,
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image, color: Colors.white, size: 48),
        SizedBox(height: 16),
        Text('Failed to load image', style: TextStyle(color: Colors.white)),
      ],
    ),
  );
}
