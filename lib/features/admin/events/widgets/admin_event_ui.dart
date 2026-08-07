import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Visual chrome for admin Events — reuses [AdminDirectoryTheme] (no second navy).
abstract final class AdminEventTheme {
  static const primary = AdminDirectoryTheme.primary;
  static const gold = AdminDirectoryTheme.gold;
  static const background = AdminDirectoryTheme.background;
  static const surface = AdminDirectoryTheme.surface;
  static const card = AdminDirectoryTheme.card;
  static const border = AdminDirectoryTheme.border;
  static const textPrimary = AdminDirectoryTheme.textPrimary;
  static const textSecondary = AdminDirectoryTheme.textSecondary;
  static const textMuted = AdminDirectoryTheme.textMuted;
  static const success = AdminDirectoryTheme.success;
  static const successBg = AdminDirectoryTheme.successBg;
  static const warning = AdminDirectoryTheme.warning;
  static const warningBg = AdminDirectoryTheme.warningBg;
  static const info = AdminDirectoryTheme.info;
  static const infoBg = AdminDirectoryTheme.infoBg;
  static const danger = AdminDirectoryTheme.danger;
  static const dangerBg = AdminDirectoryTheme.dangerBg;

  static const space1 = AdminDirectoryTheme.space1;
  static const space2 = AdminDirectoryTheme.space2;
  static const space3 = AdminDirectoryTheme.space3;
  static const space4 = AdminDirectoryTheme.space4;
  static const sectionGap = AdminDensity.sectionGap;
  static const cardPadding = AdminDensity.cardPadding;
  static const gridGap = AdminDensity.gridGap;
  static const listItemGap = AdminDensity.listItemGap;
  static const buttonHeight = AdminDirectoryTheme.buttonHeight;
  static const toolbarControlHeight = AdminDirectoryTheme.toolbarControlHeight;
  static const radiusSm = AdminDirectoryTheme.radiusSm;
  static const radiusMd = AdminDirectoryTheme.radiusMd;
  static const radiusLg = AdminDirectoryTheme.radiusLg;

  static BoxDecoration surfaceCard({bool hovered = false}) =>
      AdminDirectoryTheme.surfaceCard(hovered: hovered);
}

ButtonStyle eventOutlinedButtonStyle() => OutlinedButton.styleFrom(
      foregroundColor: AdminEventTheme.textPrimary,
      side: const BorderSide(color: AdminEventTheme.border),
      minimumSize: const Size(0, AdminEventTheme.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
      ),
    );

ButtonStyle eventFilledButtonStyle({Color? background}) =>
    FilledButton.styleFrom(
      backgroundColor: background ?? AdminEventTheme.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, AdminEventTheme.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
      ),
    );
