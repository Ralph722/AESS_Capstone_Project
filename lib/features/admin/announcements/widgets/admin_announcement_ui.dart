import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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
      fillColor: AdminColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
      ),
    );
  }
}

/// Converts raw Supabase/service errors into concise admin-facing messages.
String announcementFriendlyError(Object error, String fallback) {
  var text = '$error';
  while (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  text = text.trim();
  final technical =
      text.isEmpty ||
      text.startsWith('Error ') ||
      text.contains('Exception') ||
      text.contains('Postgrest') ||
      text.contains('SocketException') ||
      text.length > 160;
  return technical ? fallback : text;
}

/// Consistent row popup menu item with leading icon and destructive styling.
PopupMenuItem<String> adminAnnouncementMenuItem({
  required String value,
  required String label,
  required IconData icon,
  bool destructive = false,
  bool enabled = true,
  String? note,
}) {
  final Color textColor;
  final Color iconColor;
  if (!enabled) {
    textColor = AdminColors.textMuted;
    iconColor = AdminColors.textMuted;
  } else if (destructive) {
    textColor = AdminColors.danger;
    iconColor = AdminColors.danger;
  } else {
    textColor = AdminColors.textPrimary;
    iconColor = AdminColors.primary;
  }
  return PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    height: note == null ? 40 : 52,
    child: Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

ButtonStyle announcementFilledButtonStyle({
  Color? background,
  Color foreground = Colors.white,
}) => AdminButtonStyles.filled(background: background, foreground: foreground);

ButtonStyle announcementOutlinedButtonStyle() => AdminButtonStyles.outlined();

/// Summarizes course and batch targeting into a compact single-line label.
String announcementAudienceSummary(Announcement a) {
  final programs = a.targetPrograms;
  final batches = a.targetBatchYears;
  if (programs.isEmpty && batches.isEmpty) return 'All alumni';
  final parts = <String>[];
  if (programs.isNotEmpty) {
    parts.add(
      programs.length == 1 ? programs.first : '${programs.length} courses',
    );
  }
  if (batches.isNotEmpty) {
    parts.add(
      batches.length == 1 ? 'Batch ${batches.first}' : '${batches.length} batches',
    );
  }
  return parts.join(' · ');
}

/// Enabled delivery channels formatted for list summaries and confirmations.
List<String> announcementDeliveryChannels(Announcement a) => [
  if (a.notifyInApp) 'In-app',
  if (a.notifyInApp && a.notifyPush) 'Push',
  if (a.notifyEmail) 'Email',
];

class AnnouncementStatusChip extends StatelessWidget {
  const AnnouncementStatusChip({super.key, required this.status});

  final AnnouncementStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      AnnouncementStatus.draft => const AdminBadge.warning(
        label: 'Draft',
        icon: Icons.edit_note_outlined,
        dense: true,
      ),
      AnnouncementStatus.published => const AdminBadge.success(
        label: 'Published',
        dot: true,
        dense: true,
      ),
      AnnouncementStatus.archived => const AdminBadge.neutral(
        label: 'Archived',
        icon: Icons.archive_outlined,
        dense: true,
      ),
    };
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
    return const AdminBadge.danger(
      label: 'Important',
      icon: Icons.priority_high_rounded,
      dense: true,
    );
  }
}

class AnnouncementListCard extends StatefulWidget {
  const AnnouncementListCard({
    super.key,
    required this.announcement,
    required this.onMenuSelected,
    required this.menuItems,
    this.metaLine,
    this.onOpen,
    this.busy = false,
  });

  static const double zoneLayoutMinWidth = 900.0;

  final Announcement announcement;
  final String? metaLine;
  final ValueChanged<String> onMenuSelected;
  final List<PopupMenuEntry<String>> menuItems;
  final VoidCallback? onOpen;
  final bool busy;

  @override
  State<AnnouncementListCard> createState() => _AnnouncementListCardState();
}

class _AnnouncementListCardState extends State<AnnouncementListCard> {
  bool _hovered = false;

  static const _zoneLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AdminColors.textSecondary,
  );
  static const _zoneValue = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AdminColors.textPrimary,
  );
  static const _secondary = TextStyle(
    fontSize: 12,
    height: 1.35,
    color: AdminColors.textSecondary,
  );

  String get _title => widget.announcement.title.trim().isEmpty
      ? 'Untitled announcement'
      : widget.announcement.title.trim();

  String get _excerpt => widget.announcement.body
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  String _dateText(Announcement a) {
    final fmt = DateFormat.yMMMd();
    return a.publishedAt != null
        ? 'Published ${fmt.format(a.publishedAt!)}'
        : 'Created ${fmt.format(a.createdAt)}';
  }

  String _channelsText(Announcement a) {
    final channels = announcementDeliveryChannels(a);
    return channels.isEmpty ? 'No alerts' : channels.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final archived = a.status == AnnouncementStatus.archived;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
        decoration: BoxDecoration(
          color: _hovered
              ? AdminColors.rowHover
              : (archived ? const Color(0xFFFAFAFC) : AdminColors.card),
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
          border: Border.all(color: AdminColors.border),
          boxShadow: AdminSurfaces.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            button: true,
            label: 'Open announcement $_title',
            child: InkWell(
              onTap: widget.onOpen,
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= AnnouncementListCard.zoneLayoutMinWidth
                        ? _buildZones(a)
                        : _buildStacked(a),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZones(Announcement a) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIcon(a),
          const SizedBox(width: 12),
          Expanded(child: _buildIdentity(a, maxSnippetLines: 1)),
          const SizedBox(width: 24),
          SizedBox(width: 205, child: _buildAudienceZone(a)),
          const SizedBox(width: 20),
          SizedBox(width: 175, child: _buildReachZone(a)),
          const SizedBox(width: 8),
          _buildMenu(),
        ],
      ),
    );
  }

  Widget _buildStacked(Announcement a) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(a, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentity(a, maxSnippetLines: 2),
                const SizedBox(height: 6),
                _buildCompactMeta(a),
              ],
            ),
          ),
          _buildMenu(),
        ],
      ),
    );
  }

  Widget _buildIcon(Announcement a, {double size = 40}) {
    final important = a.priority == AnnouncementPriority.important;
    final archived = a.status == AnnouncementStatus.archived;
    final Color bg;
    final Color fg;
    final Color borderColor;
    final IconData icon;

    if (archived) {
      bg = AdminColors.surface;
      fg = AdminColors.textSecondary;
      borderColor = AdminColors.border;
      icon = Icons.archive_outlined;
    } else if (important) {
      bg = AdminColors.dangerBg;
      fg = AdminColors.danger;
      borderColor = AdminColors.danger.withValues(alpha: 0.22);
      icon = Icons.priority_high_rounded;
    } else {
      bg = AdminColors.primaryTint;
      fg = AdminColors.primary;
      borderColor = AdminColors.primary.withValues(alpha: 0.16);
      icon = Icons.campaign_outlined;
    }

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: size >= 40 ? 20 : 18, color: fg),
      ),
    );
  }

  Widget _buildIdentity(Announcement a, {required int maxSnippetLines}) {
    final excerpt = _excerpt;
    final isUrgent = a.notifyInApp && a.urgent;
    final isDraft = a.status == AnnouncementStatus.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _title,
          waitDuration: const Duration(milliseconds: 600),
          child: Text(
            _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.3,
              color: AdminColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AnnouncementStatusChip(status: a.status),
            AnnouncementPriorityChip(priority: a.priority),
            if (isUrgent)
              const AdminBadge.warning(
                label: 'Urgent',
                icon: Icons.bolt_rounded,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (excerpt.isNotEmpty)
          Text(
            excerpt,
            maxLines: maxSnippetLines,
            overflow: TextOverflow.ellipsis,
            style: _secondary,
          )
        else
          Text(
            isDraft ? 'No message body added yet' : 'No message preview',
            style: _secondary.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _buildAudienceZone(Announcement a) {
    final summary = announcementAudienceSummary(a);
    final tooltipParts = [
      if (a.targetPrograms.isNotEmpty)
        'Courses: ${a.targetPrograms.join(', ')}',
      if (a.targetBatchYears.isNotEmpty)
        'Batches: ${a.targetBatchYears.join(', ')}',
    ];
    final summaryWidget = Text(
      summary,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _zoneValue,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('AUDIENCE & DELIVERY', style: _zoneLabel),
        const SizedBox(height: 4),
        tooltipParts.isEmpty
            ? summaryWidget
            : Tooltip(
                message: tooltipParts.join('\n'),
                child: summaryWidget,
              ),
        const SizedBox(height: 4),
        _metaItem(
          Icons.notifications_none_rounded,
          _channelsText(a),
        ),
      ],
    );
  }

  Widget _buildReachZone(Announcement a) {
    final published = a.status == AnnouncementStatus.published;
    final draft = a.status == AnnouncementStatus.draft;
    final String primaryText;
    if (published) {
      final n = a.recipientCount;
      primaryText = '$n ${n == 1 ? 'alumnus' : 'alumni'} reached';
    } else if (draft) {
      primaryText =
          a.body.trim().isEmpty ? 'Needs message' : 'Ready to publish';
    } else {
      primaryText = a.recipientCount > 0
          ? '${a.recipientCount} reached'
          : 'Retired notice';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('REACH & TIMELINE', style: _zoneLabel),
        const SizedBox(height: 4),
        Text(
          primaryText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _zoneValue.copyWith(
            color: (draft && a.body.trim().isEmpty)
                ? AdminColors.warning
                : AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        _metaItem(Icons.schedule_outlined, _dateText(a)),
      ],
    );
  }

  Widget _buildCompactMeta(Announcement a) {
    final summary = announcementAudienceSummary(a);
    final reach = a.status == AnnouncementStatus.published
        ? '${a.recipientCount} reached'
        : null;
    final items = <Widget>[
      _metaItem(Icons.groups_outlined, summary),
      if (reach != null)
        _metaItem(
          Icons.check_circle_outline_rounded,
          reach,
          iconColor: AdminColors.success,
        ),
      _metaItem(Icons.notifications_none_rounded, _channelsText(a)),
      _metaItem(Icons.schedule_outlined, _dateText(a)),
    ];
    if (widget.metaLine != null && widget.metaLine!.trim().isNotEmpty && items.isEmpty) {
      return Text(widget.metaLine!, style: _secondary);
    }
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }

  Widget _metaItem(IconData icon, String text, {Color? iconColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor ?? AdminColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    if (widget.busy) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Announcement actions',
      onSelected: widget.onMenuSelected,
      itemBuilder: (_) => widget.menuItems,
      icon: const Icon(
        Icons.more_vert,
        color: AdminColors.textSecondary,
      ),
    );
  }
}
