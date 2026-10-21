import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_action_dialog.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Alumni forum visual tokens — aliases [PortalTheme].
abstract final class ForumTheme {
  static const navy = PortalTheme.navy;
  static const sky = PortalTheme.sky;
  static const gold = PortalTheme.gold;
  static const pageBg = PortalTheme.pageBg;
  static const card = PortalTheme.card;
  static const surfaceMuted = PortalTheme.surfaceMuted;
  static const border = PortalTheme.border;
  static const textPrimary = PortalTheme.textPrimary;
  static const textSecondary = PortalTheme.textSecondary;
  static const textMuted = PortalTheme.textMuted;
  static const announcement = PortalTheme.sky;
  static const announcementBg = Color(0xFFEFF6FF);
  static const solved = PortalTheme.success;
  static const solvedBg = Color(0xFFDCFCE7);
  static const pinned = PortalTheme.ember;
  static const pinnedBg = Color(0xFFFFF7ED);
  static const locked = PortalTheme.textMuted;
  static const lockedBg = PortalTheme.surfaceMuted;
  static const needsResponse = PortalTheme.warning;
  static const needsResponseBg = Color(0xFFFFFBEB);
  static const radius = PortalTheme.radiusMd;
  static const radiusXl = PortalTheme.radiusXl;
  static const radius2xl = PortalTheme.radius2xl;
  static List<BoxShadow> get softShadow => PortalTheme.softShadow;
}

class ForumStatusChip extends StatelessWidget {
  const ForumStatusChip({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  factory ForumStatusChip.pinned() => const ForumStatusChip(
    label: 'Pinned',
    foreground: ForumTheme.pinned,
    background: ForumTheme.pinnedBg,
    icon: Icons.push_pin_outlined,
  );

  factory ForumStatusChip.locked() => const ForumStatusChip(
    label: 'Locked',
    foreground: ForumTheme.locked,
    background: ForumTheme.lockedBg,
    icon: Icons.lock_outline,
  );

  factory ForumStatusChip.solved() => const ForumStatusChip(
    label: 'Solved',
    foreground: ForumTheme.solved,
    background: ForumTheme.solvedBg,
    icon: Icons.check_circle_outline,
  );

  factory ForumStatusChip.announcement() => const ForumStatusChip(
    label: 'Announcement',
    foreground: ForumTheme.announcement,
    background: ForumTheme.announcementBg,
    icon: Icons.campaign_outlined,
  );

  factory ForumStatusChip.needsResponse() => const ForumStatusChip(
    label: 'Needs Response',
    foreground: ForumTheme.needsResponse,
    background: ForumTheme.needsResponseBg,
    icon: Icons.mark_chat_unread_outlined,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForumStatusChipRow extends StatelessWidget {
  const ForumStatusChipRow({super.key, required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (topic.isAnnouncement) chips.add(ForumStatusChip.announcement());
    if (topic.isPinned && !topic.isAnnouncement) {
      chips.add(ForumStatusChip.pinned());
    }
    if (topic.isLocked) chips.add(ForumStatusChip.locked());
    if (topic.isSolved) chips.add(ForumStatusChip.solved());
    if (topic.needsResponse) chips.add(ForumStatusChip.needsResponse());
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class ForumTagChip extends StatelessWidget {
  const ForumTagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? ForumTheme.navy.withValues(alpha: 0.1)
            : ForumTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? ForumTheme.navy.withValues(alpha: 0.35)
              : ForumTheme.border.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? ForumTheme.navy : ForumTheme.textSecondary,
        ),
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: child,
    );
  }
}

class ForumTopicCard extends StatelessWidget {
  const ForumTopicCard({
    super.key,
    required this.topic,
    required this.onTap,
    this.compact = true,
  });

  final ForumTopic topic;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isAnnouncement = topic.isAnnouncement;
    final activity = topic.lastReplyAt ?? topic.createdAt;
    final posted = DateFormat.MMMd().add_jm().format(topic.createdAt);
    final activeLabel = DateFormat.MMMd().format(activity);

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: Material(
        color: ForumTheme.card,
        elevation: 1,
        shadowColor: ForumTheme.navy.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ForumTheme.radius2xl),
          side: BorderSide(color: ForumTheme.border.withValues(alpha: 0.75)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 16,
              compact ? 14 : 16,
              compact ? 12 : 14,
              compact ? 14 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _topicAuthorAvatar(topic, radius: compact ? 18 : 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.authorName.trim().isEmpty
                                ? 'Alumni'
                                : topic.authorName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PortalTheme.meta.copyWith(
                              color: ForumTheme.navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _authorContext(topic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PortalTheme.caption.copyWith(
                              color: ForumTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ForumTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        posted,
                        style: PortalTheme.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        topic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PortalTheme.cardTitle.copyWith(
                          fontSize: compact ? 16 : 17,
                          height: 1.25,
                          color: ForumTheme.navy,
                        ),
                      ),
                    ),
                    if (topic.isBookmarked)
                      const Padding(
                        padding: EdgeInsets.only(left: 6, top: 2),
                        child: Icon(
                          Icons.bookmark_rounded,
                          size: 18,
                          color: ForumTheme.navy,
                        ),
                      ),
                  ],
                ),
                if (_hasStatusOrTags(topic)) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ..._statusChips(topic),
                      ...topic.tags
                          .take(4)
                          .map((t) => ForumTagChip(label: t.label)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: topic.replyCount > 0
                          ? ForumTheme.navy
                          : ForumTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      topic.replyCount == 1
                          ? '1 reply'
                          : '${topic.replyCount} replies',
                      style: PortalTheme.caption.copyWith(
                        color: topic.replyCount > 0
                            ? ForumTheme.navy
                            : ForumTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: ForumTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isAnnouncement
                            ? 'Posted $activeLabel'
                            : 'Active $activeLabel',
                        style: PortalTheme.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: ForumTheme.navy.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: ForumTheme.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _authorContext(ForumTopic topic) {
    final parts = <String>[
      if (topic.authorProgram.isNotEmpty) topic.authorProgram,
      if (topic.authorBatch.isNotEmpty) 'Batch ${topic.authorBatch}',
    ];
    return parts.isEmpty ? 'Community member' : parts.join(' · ');
  }

  bool _hasStatusOrTags(ForumTopic topic) {
    return topic.isAnnouncement ||
        topic.isPinned ||
        topic.isLocked ||
        topic.isSolved ||
        topic.needsResponse ||
        topic.tags.isNotEmpty;
  }

  List<Widget> _statusChips(ForumTopic topic) {
    final chips = <Widget>[];
    if (topic.isAnnouncement) chips.add(ForumStatusChip.announcement());
    if (topic.isPinned && !topic.isAnnouncement) {
      chips.add(ForumStatusChip.pinned());
    }
    if (topic.isLocked) chips.add(ForumStatusChip.locked());
    if (topic.isSolved) chips.add(ForumStatusChip.solved());
    if (topic.needsResponse) chips.add(ForumStatusChip.needsResponse());
    return chips;
  }

  Widget _topicAuthorAvatar(ForumTopic topic, {required double radius}) {
    final isAnnouncement = topic.isAnnouncement;
    final url = topic.authorAvatarUrl?.trim() ?? '';
    final provider = url.isEmpty ? null : AppImage.provider(url);
    if (provider != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: isAnnouncement
            ? ForumTheme.announcementBg
            : ForumTheme.navy.withValues(alpha: 0.08),
        backgroundImage: provider,
      );
    }
    final initial = topic.authorName.trim().isNotEmpty
        ? topic.authorName.trim()[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: isAnnouncement
          ? ForumTheme.announcementBg
          : ForumTheme.navy.withValues(alpha: 0.08),
      child: Text(
        initial,
        style: TextStyle(
          color: isAnnouncement ? ForumTheme.announcement : ForumTheme.navy,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}

class ForumEmptyState extends StatelessWidget {
  const ForumEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.forum_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              color: ForumTheme.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
            ),
            child: Icon(icon, size: compact ? 28 : 36, color: ForumTheme.navy),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PortalTheme.cardTitle.copyWith(fontSize: compact ? 16 : 18),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: PortalTheme.bodySecondary.copyWith(height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              style: PortalTheme.primaryButton(),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );

    final card = Container(
      margin: compact ? EdgeInsets.zero : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ForumTheme.card,
        borderRadius: BorderRadius.circular(ForumTheme.radius2xl),
        border: Border.all(color: ForumTheme.border.withValues(alpha: 0.75)),
        boxShadow: ForumTheme.softShadow,
      ),
      child: content,
    );

    // Avoid Center inside scrollables (unbounded height) — shrink-wrap instead.
    if (compact) return card;
    return Center(child: card);
  }
}

class ForumErrorState extends StatelessWidget {
  const ForumErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ForumEmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      subtitle: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

Future<void> copyForumTopicLink(BuildContext context, String topicId) async {
  final link = ForumService.topicDeepLink(topicId);
  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Link copied')));
}

Future<String?> showForumModerationReasonDialog(
  BuildContext context, {
  required String title,
  String? confirmLabel,
}) async {
  final controller = TextEditingController();
  String? selected;
  const presets = [
    'Duplicate',
    'Spam',
    'Resolved',
    'Off-topic',
    'Inappropriate',
    'Other',
  ];

  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return PortalActionDialog(
              title: title.endsWith('?') ? title : '$title?',
              message:
                  'Optional reason (visible to alumni when relevant).',
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((p) {
                      final selectedChip = selected == p;
                      return ChoiceChip(
                        label: Text(p),
                        selected: selectedChip,
                        selectedColor:
                            PortalTheme.navy.withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          color: selectedChip
                              ? PortalTheme.navy
                              : PortalTheme.textPrimary,
                          fontWeight: selectedChip
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selectedChip
                              ? PortalTheme.navy.withValues(alpha: 0.35)
                              : PortalTheme.border,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selected = p;
                            if (p != 'Other') controller.text = p;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    style: PortalTheme.body,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      filled: true,
                      fillColor: PortalTheme.pageBg,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PortalTheme.radiusLg),
                        borderSide:
                            const BorderSide(color: PortalTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PortalTheme.radiusLg),
                        borderSide:
                            const BorderSide(color: PortalTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PortalTheme.radiusLg),
                        borderSide: const BorderSide(
                          color: PortalTheme.navy,
                          width: 1.4,
                        ),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: PortalTheme.primaryButton(),
                  child: Text(confirmLabel ?? 'Confirm'),
                ),
                TextButton(
                  style: PortalActionDialog.quietButton(),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    final reason = controller.text.trim();
    if (ok != true) return null;
    return reason;
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }
}
