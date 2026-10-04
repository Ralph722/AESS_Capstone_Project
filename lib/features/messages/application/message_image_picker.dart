import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_system/features/messages/data/message_image_pipeline.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';

/// Result of picking a chat attachment.
class PickedMessageImage {
  const PickedMessageImage({this.file, this.bytes});

  final File? file;
  final Uint8List? bytes;

  bool get hasImage => file != null || bytes != null;
}

/// Shared gallery/camera picker for alumni + admin composers (Part 11).
class MessageImagePicker {
  MessageImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Picks an image under [MessageImagePipeline.maxSourceBytes].
  ///
  /// When [galleryOnly] is true, skips the source sheet (desktop/web admin).
  Future<PickedMessageImage?> pick(
    BuildContext context, {
    bool galleryOnly = false,
  }) async {
    try {
      ImageSource? source;
      if (galleryOnly) {
        source = ImageSource.gallery;
      } else {
        source = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (ctx) => PortalOptionsSheet(
            title: 'Add a photo',
            children: [
              PortalSheetOption(
                label: 'Choose from gallery',
                icon: Icons.photo_library_outlined,
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              if (!kIsWeb)
                PortalSheetOption(
                  label: 'Take a photo',
                  icon: Icons.photo_camera_outlined,
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              PortalSheetOption(
                label: 'Cancel',
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }

      if (source == null) return null;

      final image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return null;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        if (bytes.length > MessageImagePipeline.maxSourceBytes) {
          if (context.mounted) _showTooLarge(context);
          return null;
        }
        return PickedMessageImage(bytes: bytes);
      }

      final file = File(image.path);
      if (await file.length() > MessageImagePipeline.maxSourceBytes) {
        if (context.mounted) _showTooLarge(context);
        return null;
      }
      return PickedMessageImage(file: file);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  void _showTooLarge(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image is too large. Please choose a file under 12 MB.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
