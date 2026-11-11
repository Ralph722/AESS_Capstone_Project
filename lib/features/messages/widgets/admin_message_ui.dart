import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/messages/models/message_filters.dart';
import 'package:alumni_system/features/messages/widgets/message_a11y.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Admin Messages chrome — aliases [AdminDirectoryTheme] (no second color system).
abstract final class AdminMessageTheme {
  static const Color surface = AdminDirectoryTheme.card;
  static const Color pageBg = AdminDirectoryTheme.background;
  static const Color border = AdminDirectoryTheme.border;
  static const Color navy = AdminDirectoryTheme.primary;
  static const Color textPrimary = AdminDirectoryTheme.textPrimary;
  static const Color textSecondary = AdminDirectoryTheme.textSecondary;
  static const Color textMuted = AdminDirectoryTheme.textMuted;
  static const Color unreadBg = AdminDirectoryTheme.infoBg;
  static const Color selectedBg = Color(0xFFE8E7F2);

  static const double inboxWidth = 340;
  static const double profileWidth = 280;
  static const double toolbarControlHeight =
      AdminDirectoryTheme.toolbarControlHeight;
  static const double radiusSm = AdminDirectoryTheme.radiusSm;
  static const double space1 = AdminDensity.space1;
  static const double space2 = AdminDensity.space2;
  static const double space3 = AdminDensity.space3;
  static const double space4 = AdminDensity.space4;
  static const double cardPadding = AdminDensity.cardPadding;
}

class AdminInboxToolbar extends StatelessWidget {
  const AdminInboxToolbar({
    super.key,
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onFilterChanged,
    this.onReset,
  });

  final TextEditingController searchController;
  final MessageInboxQuery query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MessageInboxFilter> onFilterChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final hasSearchText =
        searchController.text.isNotEmpty || query.search.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AdminMessageTheme.toolbarControlHeight,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search name, email, program, batch…',
                hintStyle: const TextStyle(
                  color: AdminColors.textSecondary,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AdminColors.textSecondary,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: AdminMessageTheme.toolbarControlHeight,
                ),
                suffixIcon: hasSearchText
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: AdminColors.textSecondary,
                        ),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: AdminColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AdminMessageTheme.radiusSm),
                  borderSide: BorderSide(color: MessageA11y.border(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AdminMessageTheme.radiusSm),
                  borderSide: BorderSide(color: MessageA11y.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AdminMessageTheme.radiusSm),
                  borderSide: const BorderSide(
                    color: AdminColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final f in MessageInboxFilter.values)
                if (f != MessageInboxFilter.archived)
                  Tooltip(
                    message: 'Filter: ${f.label}',
                    child: DirectoryToolbarFilterChip(
                      label: f.label,
                      selected: query.filter == f,
                      onSelected: (_) => onFilterChanged(f),
                    ),
                  ),
              if (query.hasActiveFilters && onReset != null)
                TextButton.icon(
                  onPressed: onReset,
                  style: AdminButtonStyles.ghost(foreground: AdminColors.primary),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                  label: const Text('Reset'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminConversationListTile extends StatefulWidget {
  const AdminConversationListTile({
    super.key,
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> row;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<AdminConversationListTile> createState() =>
      _AdminConversationListTileState();
}

class _AdminConversationListTileState extends State<AdminConversationListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final selected = widget.selected;
    final name = (row['name'] as String?)?.trim().isNotEmpty == true
        ? row['name'] as String
        : 'Alumni';
    final program = row['program'] as String? ?? '';
    final batch = row['batch'] as String? ?? '';
    final last = row['lastMessage'] as String? ?? '';
    final unread = row['isRead'] != true;
    final needsReply =
        (row['lastMessageFromRole'] as String?)?.toLowerCase() == 'user';
    final isDraft = row['composeDraft'] == true;
    final time = row['lastMessageTime'] as DateTime?;
    final meta = [
      if (program.isNotEmpty) program,
      if (batch.isNotEmpty) batch,
    ].join(' · ');

    final bgColor = selected
        ? AdminColors.primaryTint
        : (_hovered
              ? AdminColors.rowHover
              : (unread
                    ? AdminColors.infoBg.withValues(alpha: 0.45)
                    : AdminColors.card));

    return Semantics(
      button: true,
      selected: selected,
      label: MessageA11y.conversationTileLabel(
        name: name,
        lastMessage: last,
        unread: unread,
        program: program,
        batch: batch,
        relativeTime:
            time != null ? formatMessageRelativeTime(time) : null,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bgColor,
          child: InkWell(
            onTap: widget.onTap,
            focusColor: AdminColors.primary.withValues(alpha: 0.12),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                selected ? 11 : 14,
                10,
                14,
                10,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: selected
                      ? const BorderSide(color: AdminColors.primary, width: 3)
                      : BorderSide.none,
                  bottom: BorderSide(color: MessageA11y.border(context)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: _Avatar(name: name, url: row['avatarUrl'] as String?),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: (unread || selected)
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 13.5,
                                  color: MessageA11y.textPrimary(context),
                                ),
                              ),
                            ),
                            if (time != null) ...[
                              const SizedBox(width: 6),
                              ExcludeSemantics(
                                child: Text(
                                  formatMessageRelativeTime(time),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: unread
                                        ? AdminColors.primary
                                        : AdminColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AdminColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                last.isEmpty ? 'No messages yet' : last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: unread
                                      ? AdminColors.textPrimary
                                      : AdminColors.textSecondary,
                                  fontWeight: unread
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (unread) ...[
                              const SizedBox(width: 6),
                              Semantics(
                                label: 'Unread',
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AdminColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (isDraft || needsReply || unread) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (isDraft)
                                const AdminBadge.info(
                                  label: 'Draft',
                                  dense: true,
                                )
                              else if (needsReply)
                                const AdminBadge.warning(
                                  label: 'Needs reply',
                                  dense: true,
                                )
                              else if (unread)
                                const AdminBadge.info(
                                  label: 'Unread',
                                  dense: true,
                                ),
                            ],
                          ),
                        ],
                      ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final provider = AppImage.provider(url);
    if (provider != null) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: AdminMessageTheme.navy.withValues(alpha: 0.08),
        backgroundImage: provider,
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: AdminMessageTheme.navy.withValues(alpha: 0.1),
      child: Text(
        letter,
        style: const TextStyle(
          color: AdminMessageTheme.navy,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class AdminConversationHeader extends StatelessWidget {
  const AdminConversationHeader({
    super.key,
    required this.profile,
    this.onBack,
    this.onToggleProfile,
    this.showProfileToggle = false,
    this.showProfilePanel = true,
    this.needsReply = false,
  });

  final AlumniMessageProfile profile;
  final VoidCallback? onBack;
  final VoidCallback? onToggleProfile;
  final bool showProfileToggle;
  final bool showProfilePanel;
  final bool needsReply;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (profile.program.isNotEmpty) profile.program,
      if (profile.batch.isNotEmpty) profile.batch,
    ].join(' · ');

    return Semantics(
      header: true,
      label: [
        'Conversation with ${profile.name}',
        if (meta.isNotEmpty) meta,
      ].join('. '),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 460;
          return Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AdminColors.card,
              border: Border(
                bottom: BorderSide(color: MessageA11y.border(context)),
              ),
            ),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    tooltip: 'Back to inbox',
                    onPressed: onBack,
                    style: AdminDensity.iconButtonStyle(
                      foregroundColor: AdminColors.primary,
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ExcludeSemantics(
                  child: _Avatar(name: profile.name, url: profile.avatarUrl),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                          ),
                          if (wide && needsReply) ...[
                            const SizedBox(width: 8),
                            const AdminBadge.warning(
                              label: 'Needs reply',
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showProfileToggle && onToggleProfile != null) ...[
                  const SizedBox(width: 8),
                  if (wide)
                    OutlinedButton.icon(
                      onPressed: onToggleProfile,
                      style: AdminButtonStyles.outlined(),
                      icon: Icon(
                        showProfilePanel
                            ? Icons.info
                            : Icons.info_outline,
                        size: 16,
                        color: showProfilePanel
                            ? AdminColors.primary
                            : AdminColors.textSecondary,
                      ),
                      label: const Text('Details'),
                    )
                  else
                    IconButton(
                      tooltip: 'Alumni details',
                      onPressed: onToggleProfile,
                      style: AdminDensity.iconButtonStyle(
                        foregroundColor: AdminColors.primary,
                      ),
                      icon: const Icon(Icons.info_outline),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class AdminAlumniProfilePanel extends StatelessWidget {
  const AdminAlumniProfilePanel({
    super.key,
    required this.profile,
    this.width = AdminMessageTheme.profileWidth,
    this.onClose,
  });

  final AlumniMessageProfile profile;
  final double? width;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: AdminColors.card,
      child: ListView(
        padding: const EdgeInsets.all(AdminDensity.cardPadding),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Alumni details',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminColors.textSecondary,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AdminColors.border),
          const SizedBox(height: 14),
          Center(child: _Avatar(name: profile.name, url: profile.avatarUrl)),
          const SizedBox(height: 10),
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AdminColors.textPrimary,
            ),
          ),
          if (profile.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    profile.email,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Copy email',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: profile.email));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Email copied')),
                      );
                  },
                  icon: const Icon(
                    Icons.copy_outlined,
                    size: 14,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              border: Border.all(color: AdminColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  'Program',
                  profile.program.isEmpty ? '—' : profile.program,
                ),
                _infoRow('Batch', profile.batch.isEmpty ? '—' : profile.batch),
                _badgeRow(
                  'Registration',
                  AdminBadge.info(
                    label: profile.registrationLabel,
                    dense: true,
                  ),
                ),
                _badgeRow(
                  'Tracer profile',
                  profile.tracerComplete
                      ? const AdminBadge.success(
                          label: 'Complete',
                          icon: Icons.check_circle_outline,
                          dense: true,
                        )
                      : const AdminBadge.warning(
                          label: 'Incomplete',
                          icon: Icons.pending_outlined,
                          dense: true,
                        ),
                ),
                _infoRow(
                  'Last activity',
                  profile.lastActive == null
                      ? '—'
                      : formatMessageRelativeTime(profile.lastActive!),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Context stays here so you can reply without leaving the thread.',
            style: TextStyle(
              fontSize: 11.5,
              color: AdminColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeRow(String label, Widget badge) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          badge,
        ],
      ),
    );
  }
}

/// Maps technical messaging exceptions to concise admin-facing copy.
String messageFriendlyError(Object error, String fallback) {
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

Future<void> copyAdminMessageText(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Message copied'), duration: Duration(seconds: 2)),
  );
}

Future<void> copyAdminImageLink(BuildContext context, String? url) async {
  if (url == null || url.trim().isEmpty || url.startsWith('data:')) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No image link available')),
    );
    return;
  }
  final String link;
  try {
    link = await ImageStorageService.resolveMessageImageUrl(url);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not create an image link')),
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ImageStorageService.isMessageAttachmentRef(url)
            ? 'Image link copied (works for 1 hour)'
            : 'Image link copied',
      ),
    ),
  );
}
