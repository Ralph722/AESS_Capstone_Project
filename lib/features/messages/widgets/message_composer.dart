import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/features/messages/widgets/message_a11y.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_composer.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.onClearImage,
    this.selectedImage,
    this.selectedImageBytes,
    this.isUploading = false,
    this.uploadProgress,
    this.uploadFailed = false,
    this.onRetryUpload,
    this.enabled = true,
    this.hintText = 'Message the Alumni Office…',
    this.maxContentWidth,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final File? selectedImage;
  final Uint8List? selectedImageBytes;
  final bool isUploading;

  /// 0.0–1.0 while compressing/uploading; null when idle.
  final double? uploadProgress;
  final bool uploadFailed;
  final VoidCallback? onRetryUpload;
  final bool enabled;
  final String hintText;

  /// Centres the input within this width while the bar stays full width.
  final double? maxContentWidth;

  bool get _hasImage => selectedImage != null || selectedImageBytes != null;

  bool get _canSend =>
      enabled &&
      !isUploading &&
      !uploadFailed &&
      (controller.text.trim().isNotEmpty || _hasImage);

  String get _attachmentLabel {
    if (isUploading) {
      final pct = uploadProgress;
      if (pct != null && pct > 0) {
        return 'Uploading… ${(pct * 100).clamp(0, 100).round()}%';
      }
      return 'Preparing image…';
    }
    if (uploadFailed) return 'Upload failed';
    return 'Image ready to send';
  }

  @override
  Widget build(BuildContext context) {
    final length = controller.text.characters.length;
    final nearLimit = length >= (MessageTheme.messageMaxLength * 0.9).floor();
    final borderColor = MessageA11y.border(context);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (_canSend) onSend();
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (_canSend) onSend();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_hasImage && !isUploading) onClearImage();
        },
      },
      child: Focus(
        autofocus: false,
        child: PortalComposerBar(
          maxWidth: maxContentWidth,
          borderColor: borderColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasImage)
                Semantics(
                  label: _attachmentLabel,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MessageTheme.pageBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: uploadFailed
                            ? MessageTheme.failed.withValues(alpha: 0.45)
                            : borderColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb && selectedImageBytes != null
                                    ? Image.memory(
                                        selectedImageBytes!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      )
                                    : (!kIsWeb && selectedImage != null)
                                    ? Image.file(
                                        selectedImage!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _attachmentLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: uploadFailed
                                      ? MessageTheme.failed
                                      : MessageA11y.textPrimary(context),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (uploadFailed && onRetryUpload != null)
                              TextButton(
                                onPressed: isUploading ? null : onRetryUpload,
                                child: const Text('Retry upload'),
                              ),
                            if (isUploading)
                              Semantics(
                                label: uploadProgress != null
                                    ? 'Upload progress ${(uploadProgress! * 100).round()} percent'
                                    : 'Uploading image',
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Remove image',
                              onPressed: isUploading ? null : onClearImage,
                              icon: const Icon(
                                Icons.close,
                                color: MessageTheme.textSecondary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        if (isUploading &&
                            uploadProgress != null &&
                            uploadProgress! > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              label:
                                  'Upload progress ${(uploadProgress! * 100).round()} percent',
                              value: '${(uploadProgress! * 100).round()}%',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: uploadProgress!.clamp(0.0, 1.0),
                                  minHeight: 3,
                                  backgroundColor: MessageTheme.border,
                                  color: MessageTheme.navy,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled && !isUploading,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: MessageTheme.messageMaxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      textCapitalization: TextCapitalization.sentences,
                      style: PortalTheme.body.copyWith(
                        color: MessageA11y.textPrimary(context),
                      ),
                      decoration: PortalComposer.inputDecoration(
                        hintText: hintText,
                        prefixIcon: IconButton(
                          tooltip: 'Attach image',
                          onPressed: (enabled && !isUploading)
                              ? onPickImage
                              : null,
                          icon: const Icon(
                            Icons.image_outlined,
                            size: 22,
                            color: MessageTheme.navy,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (_canSend) onSend();
                      },
                    ),
                  ),
                  const SizedBox(width: PortalComposer.gap),
                  PortalSendButton(
                    label: 'Send message',
                    hint: 'Control Enter also sends',
                    busy: isUploading,
                    onPressed: _canSend ? onSend : null,
                  ),
                ],
              ),
              if (nearLimit)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Semantics(
                      liveRegion: true,
                      label:
                          '$length of ${MessageTheme.messageMaxLength} characters',
                      child: Text(
                        '$length / ${MessageTheme.messageMaxLength}',
                        style: TextStyle(
                          fontSize: 11,
                          color: length >= MessageTheme.messageMaxLength
                              ? MessageTheme.failed
                              : MessageTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
