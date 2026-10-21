import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Standard admin button styles (36px controls, 8px radius, flat).
abstract final class AdminButtonStyles {
  static ButtonStyle filled({
    Color? background,
    Color foreground = Colors.white,
  }) => FilledButton.styleFrom(
    backgroundColor: background ?? AdminColors.primary,
    foregroundColor: foreground,
    minimumSize: const Size(0, AdminDensity.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
    ),
  );

  static ButtonStyle outlined() => OutlinedButton.styleFrom(
    foregroundColor: AdminColors.textPrimary,
    side: const BorderSide(color: AdminColors.border),
    minimumSize: const Size(0, AdminDensity.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
    ),
  );

  static ButtonStyle danger() => filled(background: AdminColors.danger);

  /// Low-contrast transparent button with subtle hover tint.
  static ButtonStyle ghost({Color? foreground}) => TextButton.styleFrom(
    foregroundColor: foreground ?? AdminColors.textPrimary,
    minimumSize: const Size(0, AdminDensity.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
    ),
  );

  /// Subtle filled button for secondary actions and toolbar controls.
  static ButtonStyle subtle() => FilledButton.styleFrom(
    backgroundColor: AdminColors.surface,
    foregroundColor: AdminColors.textPrimary,
    minimumSize: const Size(0, AdminDensity.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
    ),
  );
}
