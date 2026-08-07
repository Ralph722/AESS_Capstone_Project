import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Visual chrome for admin Announcements — reuses [AdminDirectoryTheme].
abstract final class AdminAnnouncementTheme {
  static const primary = AdminDirectoryTheme.primary;
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
  static const infoBg = AdminDirectoryTheme.infoBg;
  static const danger = AdminDirectoryTheme.danger;
  static const dangerBg = AdminDirectoryTheme.dangerBg;

  static const space1 = AdminDirectoryTheme.space1;
  static const space2 = AdminDirectoryTheme.space2;
  static const space3 = AdminDirectoryTheme.space3;
  static const space4 = AdminDirectoryTheme.space4;
  static const sectionGap = AdminDensity.sectionGap;
  static const cardPadding = AdminDensity.cardPadding;
  static const listItemGap = AdminDensity.listItemGap;
  static const buttonHeight = AdminDirectoryTheme.buttonHeight;
  static const toolbarControlHeight = AdminDirectoryTheme.toolbarControlHeight;
  static const radiusSm = AdminDirectoryTheme.radiusSm;
  static const radiusMd = AdminDirectoryTheme.radiusMd;
  static const radiusLg = AdminDirectoryTheme.radiusLg;

  static BoxDecoration surfaceCard({bool hovered = false}) =>
      AdminDirectoryTheme.surfaceCard(hovered: hovered);

  static InputDecoration fieldDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    );
  }
}

ButtonStyle announcementFilledButtonStyle({
  Color? background,
  Color foreground = Colors.white,
}) =>
    FilledButton.styleFrom(
      backgroundColor: background ?? AdminAnnouncementTheme.primary,
      foregroundColor: foreground,
      minimumSize: const Size(0, AdminAnnouncementTheme.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminAnnouncementTheme.radiusSm),
      ),
    );

ButtonStyle announcementOutlinedButtonStyle() => OutlinedButton.styleFrom(
      foregroundColor: AdminAnnouncementTheme.textPrimary,
      side: const BorderSide(color: AdminAnnouncementTheme.border),
      minimumSize: const Size(0, AdminAnnouncementTheme.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminAnnouncementTheme.radiusSm),
      ),
    );

class AnnouncementStatusChip extends StatelessWidget {
  const AnnouncementStatusChip({super.key, required this.status});

  final AnnouncementStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, icon) = switch (status) {
      AnnouncementStatus.draft => (
          'Draft',
          AdminAnnouncementTheme.warningBg,
          AdminAnnouncementTheme.warning,
          Icons.edit_note_outlined,
        ),
      AnnouncementStatus.published => (
          'Published',
          AdminAnnouncementTheme.successBg,
          AdminAnnouncementTheme.success,
          Icons.campaign_outlined,
        ),
      AnnouncementStatus.archived => (
          'Archived',
          AdminAnnouncementTheme.surface,
          AdminAnnouncementTheme.textMuted,
          Icons.archive_outlined,
        ),
    };
    return _AnnouncementChip(label: label, bg: bg, fg: fg, icon: icon);
  }
}

class AnnouncementPriorityChip extends StatelessWidget {
  const AnnouncementPriorityChip({super.key, required this.priority});

  final AnnouncementPriority priority;

  @override
  Widget build(BuildContext context) {
    if (priority != AnnouncementPriority.important) {
      return const SizedBox.shrink();
    }
    return const _AnnouncementChip(
      label: 'Important',
      bg: AdminAnnouncementTheme.dangerBg,
      fg: AdminAnnouncementTheme.danger,
      icon: Icons.priority_high_rounded,
    );
  }
}

class _AnnouncementChip extends StatelessWidget {
  const _AnnouncementChip({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class AnnouncementListCard extends StatefulWidget {
  const AnnouncementListCard({
    super.key,
    required this.announcement,
    required this.metaLine,
    required this.onMenuSelected,
    required this.menuItems,
    this.onOpen,
  });

  final Announcement announcement;
  final String metaLine;
  final ValueChanged<String> onMenuSelected;
  final List<PopupMenuEntry<String>> menuItems;
  final VoidCallback? onOpen;

  @override
  State<AnnouncementListCard> createState() => _AnnouncementListCardState();
}

class _AnnouncementListCardState extends State<AnnouncementListCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final important = a.priority == AnnouncementPriority.important;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
        decoration: AdminAnnouncementTheme.surfaceCard(hovered: _hovered),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius:
                BorderRadius.circular(AdminAnnouncementTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminDensity.space3,
                vertical: AdminDensity.cardPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: important
                          ? AdminAnnouncementTheme.dangerBg
                          : AdminAnnouncementTheme.infoBg,
                      borderRadius: BorderRadius.circular(
                        AdminAnnouncementTheme.radiusSm,
                      ),
                    ),
                    child: Icon(
                      important
                          ? Icons.priority_high_rounded
                          : Icons.campaign_outlined,
                      size: 18,
                      color: important
                          ? AdminAnnouncementTheme.danger
                          : AdminAnnouncementTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title.isEmpty ? 'Untitled announcement' : a.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AdminAnnouncementTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            AnnouncementStatusChip(status: a.status),
                            AnnouncementPriorityChip(priority: a.priority),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.metaLine,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AdminAnnouncementTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Announcement actions',
                    onSelected: widget.onMenuSelected,
                    itemBuilder: (_) => widget.menuItems,
                    icon: const Icon(
                      Icons.more_vert,
                      color: AdminAnnouncementTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
