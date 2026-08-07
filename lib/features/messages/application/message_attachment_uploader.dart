import 'dart:io';
import 'dart:typed_data';

import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/messages/data/message_image_pipeline.dart';

/// Upload progress/failure callbacks used by alumni + admin composers.
class MessageAttachmentUploadState {
  const MessageAttachmentUploadState({
    required this.isUploading,
    this.progress,
    this.failed = false,
  });

  final bool isUploading;
  final double? progress;
  final bool failed;
}

/// Shared compress+upload for chat attachments (Part 11).
abstract final class MessageAttachmentUploader {
  static Future<String?> upload({
    required MessageImagePipeline pipeline,
    required String messageId,
    File? file,
    Uint8List? bytes,
    required void Function(MessageAttachmentUploadState state) onState,
    required void Function(String errorMessage) onError,
  }) async {
    if (file == null && bytes == null) return null;

    onState(
      const MessageAttachmentUploadState(
        isUploading: true,
        progress: 0,
        failed: false,
      ),
    );

    try {
      final url = await pipeline.compressAndUpload(
        userId: AppSession.userId ?? 'unknown',
        messageId: messageId,
        file: file,
        bytes: bytes,
        onProgress: (p) {
          onState(
            MessageAttachmentUploadState(
              isUploading: true,
              progress: p,
              failed: false,
            ),
          );
        },
      );
      onState(
        const MessageAttachmentUploadState(
          isUploading: false,
          failed: false,
        ),
      );
      return url;
    } catch (e) {
      onState(
        const MessageAttachmentUploadState(
          isUploading: false,
          failed: true,
        ),
      );
      final msg = e is MessageImageException
          ? e.message
          : 'Error uploading image: $e';
      onError(msg);
      return null;
    }
  }
}
