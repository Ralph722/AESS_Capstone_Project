import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';

/// Admin Forum visual tokens — aliases Alumni Directory / Surveys density chrome.
abstract final class AdminForumTheme {
  static const primary = AdminDirectoryTheme.primary;
  static const navy = AdminDirectoryTheme.navy;
  static const background = AdminDirectoryTheme.background;
  static const surface = AdminDirectoryTheme.surface;
  static const card = AdminDirectoryTheme.card;
  static const border = AdminDirectoryTheme.border;
  static const textPrimary = AdminDirectoryTheme.textPrimary;
  static const textSecondary = AdminDirectoryTheme.textSecondary;
  static const textMuted = AdminDirectoryTheme.textMuted;
  static const success = AdminDirectoryTheme.success;
  static const warning = AdminDirectoryTheme.warning;
  static const info = AdminDirectoryTheme.info;
  static const infoBg = AdminDirectoryTheme.infoBg;
  static const danger = AdminDirectoryTheme.danger;

  static const space1 = AdminDirectoryTheme.space1;
  static const space2 = AdminDirectoryTheme.space2;
  static const space3 = AdminDirectoryTheme.space3;
  static const buttonHeight = AdminDirectoryTheme.buttonHeight;
  static const toolbarControlHeight = AdminDirectoryTheme.toolbarControlHeight;
  static const radiusSm = AdminDirectoryTheme.radiusSm;
  static const radiusMd = AdminDirectoryTheme.radiusMd;
  static const radiusLg = AdminDirectoryTheme.radiusLg;

  static BoxDecoration surfaceCard({bool hovered = false}) =>
      AdminDirectoryTheme.surfaceCard(hovered: hovered);
}

ButtonStyle forumFilledButtonStyle({Color? background}) =>
    FilledButton.styleFrom(
      backgroundColor: background ?? AdminForumTheme.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, AdminForumTheme.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminForumTheme.radiusSm),
      ),
    );

ButtonStyle forumOutlinedButtonStyle() => OutlinedButton.styleFrom(
      foregroundColor: AdminForumTheme.textPrimary,
      side: const BorderSide(color: AdminForumTheme.border),
      minimumSize: const Size(0, AdminForumTheme.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminForumTheme.radiusSm),
      ),
    );

class ForumPageHeader extends StatelessWidget {
  const ForumPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: title,
      subtitle: subtitle,
      actions: actions,
      titleColor: AdminForumTheme.textPrimary,
      subtitleColor: AdminForumTheme.textSecondary,
      titleFontSize: AdminDensity.titleFontSize,
    );
  }
}

/// Compact status filter chip matching Surveys / Announcements toolbar chips.
class ForumToolbarFilterChip extends StatelessWidget {
  const ForumToolbarFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return DirectoryToolbarFilterChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
    );
  }
}
