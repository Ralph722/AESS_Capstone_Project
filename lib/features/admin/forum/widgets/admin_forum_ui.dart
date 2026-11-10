import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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

/// Maps technical exceptions to concise admin-facing messages.
String forumFriendlyError(Object error, String fallback) {
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

/// Forum moderation popup menu item with leading icon and consistent destructive tone.
PopupMenuItem<String> adminForumMenuItem({
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

ButtonStyle forumFilledButtonStyle({Color? background}) =>
    AdminButtonStyles.filled(background: background);

ButtonStyle forumOutlinedButtonStyle() => AdminButtonStyles.outlined();

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

/// Brand-aligned Admin status badges for forum topics (`AdminBadge` tokens).
class AdminForumTopicStatusBadges extends StatelessWidget {
  const AdminForumTopicStatusBadges({super.key, required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (topic.isAnnouncement)
        const AdminBadge.info(
          label: 'Announcement',
          icon: Icons.campaign_outlined,
          dense: true,
        ),
      if (topic.isPinned && !topic.isAnnouncement)
        const AdminBadge.warning(
          label: 'Pinned',
          icon: Icons.push_pin_outlined,
          dense: true,
        ),
      if (topic.isLocked)
        const AdminBadge.neutral(
          label: 'Locked',
          icon: Icons.lock_outline,
          dense: true,
        ),
      if (topic.isSolved)
        const AdminBadge.success(
          label: 'Solved',
          icon: Icons.check_circle_outline,
          dense: true,
        ),
      if (topic.needsResponse)
        const AdminBadge.warning(
          label: 'Needs response',
          icon: Icons.mark_chat_unread_outlined,
          dense: true,
        ),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: badges);
  }
}

/// Multi-zone SaaS card row for admin discussion moderation.
class AdminForumTopicCard extends StatefulWidget {
  const AdminForumTopicCard({
    super.key,
    required this.topic,
    required this.menuItems,
    required this.onMenuSelected,
    required this.onOpen,
    this.selected = false,
    this.busy = false,
  });

  static const double zoneLayoutMinWidth = 900.0;

  final ForumTopic topic;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onOpen;
  final bool selected;
  final bool busy;

  @override
  State<AdminForumTopicCard> createState() => _AdminForumTopicCardState();
}

class _AdminForumTopicCardState extends State<AdminForumTopicCard> {
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

  String _authorMeta(ForumTopic t) {
    final author = t.authorName.trim().isEmpty ? 'Alumni' : t.authorName.trim();
    return [
      author,
      if (t.authorProgram.trim().isNotEmpty) t.authorProgram.trim(),
      if (t.authorBatch.trim().isNotEmpty) 'Batch ${t.authorBatch.trim()}',
    ].join(' · ');
  }

  String _activityText(ForumTopic t) {
    final fmt = DateFormat.yMMMd();
    return t.lastReplyAt != null
        ? 'Last reply ${fmt.format(t.lastReplyAt!)}'
        : 'Created ${fmt.format(t.createdAt)}';
  }

  String _engagementLine(ForumTopic t) {
    final replies = '${t.replyCount} ${t.replyCount == 1 ? 'reply' : 'replies'}';
    final views = '${t.viewCount} ${t.viewCount == 1 ? 'view' : 'views'}';
    return '$replies · $views';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
        decoration: BoxDecoration(
          color: widget.selected
              ? AdminColors.primaryTint
              : (_hovered ? AdminColors.rowHover : AdminColors.card),
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
          border: Border.all(
            color: widget.selected
                ? AdminColors.primary.withValues(alpha: 0.35)
                : AdminColors.border,
          ),
          boxShadow: widget.selected ? null : AdminSurfaces.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Semantics(
            button: true,
            label: 'Open discussion ${t.title}',
            child: InkWell(
              onTap: widget.onOpen,
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= AdminForumTopicCard.zoneLayoutMinWidth
                        ? _buildZones(t)
                        : _buildStacked(t),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZones(ForumTopic t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildLeadingAvatar(t),
          const SizedBox(width: 12),
          Expanded(child: _buildIdentity(t)),
          const SizedBox(width: 24),
          SizedBox(width: 195, child: _buildEngagementZone(t)),
          const SizedBox(width: 8),
          _buildMenu(),
        ],
      ),
    );
  }

  Widget _buildStacked(ForumTopic t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeadingAvatar(t, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentity(t, showCompactStats: true),
              ],
            ),
          ),
          _buildMenu(),
        ],
      ),
    );
  }

  Widget _buildLeadingAvatar(ForumTopic t, {double size = 40}) {
    final avatarUrl = t.authorAvatarUrl?.trim() ?? '';
    final hasImage = avatarUrl.isNotEmpty;
    if (t.isAnnouncement && !hasImage) {
      return ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AdminColors.infoBg,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            border: Border.all(
              color: AdminColors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Icon(
            Icons.campaign_outlined,
            size: size >= 40 ? 20 : 18,
            color: AdminColors.primary,
          ),
        ),
      );
    }

    final initial = t.authorName.trim().isNotEmpty
        ? t.authorName.trim()[0].toUpperCase()
        : '?';
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: AdminColors.primaryTint,
        backgroundImage: hasImage ? AppImage.provider(avatarUrl) : null,
        child: hasImage
            ? null
            : Text(
                initial,
                style: const TextStyle(
                  color: AdminColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
      ),
    );
  }

  Widget _buildIdentity(ForumTopic t, {bool showCompactStats = false}) {
    final title = t.title.trim().isEmpty ? 'Untitled discussion' : t.title.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: title,
          waitDuration: const Duration(milliseconds: 600),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
              height: 1.3,
              color: AdminColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 5),
        AdminForumTopicStatusBadges(topic: t),
        if (t.isAnnouncement ||
            t.isPinned ||
            t.isLocked ||
            t.isSolved ||
            t.needsResponse)
          const SizedBox(height: 5),
        Text(
          _authorMeta(t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _secondary,
        ),
        if (showCompactStats) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              _metaItem(Icons.chat_bubble_outline_rounded, _engagementLine(t)),
              _metaItem(Icons.schedule_outlined, _activityText(t)),
            ],
          ),
        ],
        if (t.tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: t.tags
                .take(3)
                .map((tag) => _AdminTagChip(label: tag.label))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildEngagementZone(ForumTopic t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ENGAGEMENT & ACTIVITY', style: _zoneLabel),
        const SizedBox(height: 4),
        Text(
          _engagementLine(t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _zoneValue,
        ),
        const SizedBox(height: 4),
        _metaItem(Icons.schedule_outlined, _activityText(t)),
      ],
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AdminColors.textSecondary),
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
      tooltip: 'Discussion actions',
      onSelected: widget.onMenuSelected,
      itemBuilder: (_) => widget.menuItems,
      icon: const Icon(Icons.more_vert, color: AdminColors.textSecondary),
    );
  }
}

class _AdminTagChip extends StatelessWidget {
  const _AdminTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AdminColors.textSecondary,
        ),
      ),
    );
  }
}

/// Multi-zone card for flagged discussions and replies in Reports tab.
class AdminForumReportCard extends StatefulWidget {
  const AdminForumReportCard({
    super.key,
    required this.report,
    this.onOpenTopic,
    this.onResolve,
    this.onReopen,
    this.busy = false,
  });

  final ForumReport report;
  final VoidCallback? onOpenTopic;
  final VoidCallback? onResolve;
  final VoidCallback? onReopen;
  final bool busy;

  @override
  State<AdminForumReportCard> createState() => _AdminForumReportCardState();
}

class _AdminForumReportCardState extends State<AdminForumReportCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final title = (r.topicTitle?.trim().isNotEmpty == true)
        ? r.topicTitle!.trim()
        : 'Reported discussion';
    final reporter = (r.reporterName?.trim().isNotEmpty == true)
        ? r.reporterName!.trim()
        : 'Alumni report';
    final when = DateFormat.yMMMd().add_jm().format(r.createdAt);
    final isReply = r.postId != null && r.postId!.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
        decoration: BoxDecoration(
          color: _hovered ? AdminColors.rowHover : AdminColors.card,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
          border: Border.all(color: AdminColors.border),
          boxShadow: AdminSurfaces.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onOpenTopic,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 780;
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        r.isOpen
                            ? const AdminBadge.warning(
                                label: 'Open',
                                icon: Icons.flag_outlined,
                                dense: true,
                              )
                            : const AdminBadge.success(
                                label: 'Resolved',
                                icon: Icons.check_circle_outline,
                                dense: true,
                              ),
                        AdminBadge.neutral(
                          label: isReply ? 'Reply report' : 'Topic report',
                          icon: isReply
                              ? Icons.chat_bubble_outline
                              : Icons.forum_outlined,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.reason.trim().isEmpty
                          ? 'No reason provided.'
                          : r.reason.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$reporter · $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                );

                final actions = widget.busy
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.onOpenTopic != null)
                            OutlinedButton.icon(
                              onPressed: widget.onOpenTopic,
                              style: AdminButtonStyles.outlined(),
                              icon: const Icon(Icons.open_in_new, size: 15),
                              label: const Text('Open'),
                            ),
                          if (widget.onResolve != null)
                            FilledButton(
                              onPressed: widget.onResolve,
                              style: AdminButtonStyles.filled(),
                              child: const Text('Resolve'),
                            ),
                          if (widget.onReopen != null)
                            OutlinedButton(
                              onPressed: widget.onReopen,
                              style: AdminButtonStyles.outlined(),
                              child: const Text('Reopen'),
                            ),
                        ],
                      );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: r.isOpen
                                  ? AdminColors.warningBg
                                  : AdminColors.successBg,
                              borderRadius: BorderRadius.circular(
                                AdminSurfaces.radiusSm,
                              ),
                              border: Border.all(
                                color: (r.isOpen
                                        ? AdminColors.warning
                                        : AdminColors.success)
                                    .withValues(alpha: 0.22),
                              ),
                            ),
                            child: Icon(
                              r.isOpen
                                  ? Icons.flag_outlined
                                  : Icons.check_circle_outline,
                              size: 19,
                              color: r.isOpen
                                  ? AdminColors.warning
                                  : AdminColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: details),
                          if (wide) ...[
                            const SizedBox(width: 16),
                            actions,
                          ],
                        ],
                      ),
                      if (!wide) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: actions,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
