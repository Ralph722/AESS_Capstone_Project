import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/profile/data/admin_profile_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Circular admin avatar: the profile photo, or gold initials without one.
class AdminProfileAvatar extends StatelessWidget {
  const AdminProfileAvatar({
    super.key,
    required this.profile,
    required this.size,
    this.photoBytes,
    this.showStoredPhoto = true,
  });

  final AdminProfile profile;
  final double size;

  /// Unsaved photo shown instead of the stored one.
  final Uint8List? photoBytes;

  /// False previews a pending "remove photo".
  final bool showStoredPhoto;

  @override
  Widget build(BuildContext context) {
    final initials = _Initials(text: profile.initials, size: size);
    final Widget content;
    if (photoBytes != null) {
      content = Image.memory(
        photoBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => initials,
      );
    } else if (showStoredPhoto && profile.hasAvatar) {
      content = AppImage.widget(
        profile.avatarUrl!,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => initials,
      );
    } else {
      content = initials;
    }
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(dimension: size, child: content),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminColors.accent,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: AdminColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
