import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/features/messages/models/message_filters.dart';
import 'package:alumni_system/features/messages/widgets/message_a11y.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

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
    required this.onSortChanged,
    this.onReset,
  });

  final TextEditingController searchController;
  final MessageInboxQuery query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MessageInboxFilter> onFilterChanged;
  final ValueChanged<MessageInboxSort> onSortChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdminMessageTheme.cardPadding,
        AdminMessageTheme.space1,
        AdminMessageTheme.cardPadding,
        AdminMessageTheme.space1,
      ),
      decoration: const BoxDecoration(
        color: AdminMessageTheme.surface,
        border: Border(bottom: BorderSide(color: AdminMessageTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AdminMessageTheme.toolbarControlHeight,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search name, email, program, batch…',
                hintStyle: const TextStyle(
                  color: AdminMessageTheme.textMuted,
                  fontSize: 13.5,
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: AdminMessageTheme.toolbarControlHeight,
                ),
                isDense: true,
                filled: true,
                fillColor: AdminMessageTheme.pageBg,
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
                    color: AdminMessageTheme.navy,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AdminMessageTheme.space1),
          Wrap(
            spacing: AdminMessageTheme.space1,
            runSpacing: AdminMessageTheme.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final f in MessageInboxFilter.values)
                if (f != MessageInboxFilter.archived)
                  FilterChip(
                    label: Text(f.label, style: const TextStyle(fontSize: 12)),
                    selected: query.filter == f,
                    tooltip: 'Filter: ${f.label}',
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => onFilterChanged(f),
                  ),
              const SizedBox(width: 4),
              SizedBox(
                height: AdminDensity.controlHeight,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MessageInboxSort>(
                    value: query.sort,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminMessageTheme.textPrimary,
                    ),
                    items: [
                      for (final s in MessageInboxSort.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) onSortChanged(v);
                    },
                  ),
                ),
              ),
              if (query.hasActiveFilters && onReset != null)
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminConversationListTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final name = (row['name'] as String?)?.trim().isNotEmpty == true
        ? row['name'] as String
        : 'Alumni';
    final program = row['program'] as String? ?? '';
    final batch = row['batch'] as String? ?? '';
    final last = row['lastMessage'] as String? ?? '';
    final unread = row['isRead'] != true;
    final time = row['lastMessageTime'] as DateTime?;
    final meta = [
      if (program.isNotEmpty) program,
      if (batch.isNotEmpty) batch,
    ].join(' · ');

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
      child: Material(
        color: selected
            ? AdminMessageTheme.selectedBg
            : (unread ? AdminMessageTheme.unreadBg : Colors.white),
        child: InkWell(
          onTap: onTap,
          focusColor: AdminMessageTheme.navy.withValues(alpha: 0.12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AdminMessageTheme.cardPadding,
              AdminMessageTheme.space1,
              AdminMessageTheme.cardPadding,
              AdminMessageTheme.space1,
            ),
            decoration: BoxDecoration(
              border: Border(
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
                                fontWeight:
                                    unread ? FontWeight.w700 : FontWeight.w600,
                                fontSize: 13.5,
                                color: MessageA11y.textPrimary(context),
                              ),
                            ),
                          ),
                          if (time != null)
                            ExcludeSemantics(
                              child: Text(
                                formatMessageRelativeTime(time),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: unread
                                      ? AdminMessageTheme.navy
                                      : MessageTheme.textMuted,
                                ),
                              ),
                            ),
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
                            color: MessageTheme.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
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
                                    ? MessageTheme.textPrimary
                                    : MessageTheme.textMuted,
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
                                  color: AdminMessageTheme.navy,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
  });

  final AlumniMessageProfile profile;
  final VoidCallback? onBack;
  final VoidCallback? onToggleProfile;
  final bool showProfileToggle;

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
      child: Container(
      height: AdminMessageTheme.toolbarControlHeight + 4,
      padding: const EdgeInsets.symmetric(horizontal: AdminMessageTheme.space1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: MessageA11y.border(context))),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back to inbox',
              onPressed: onBack,
              style: AdminDensity.iconButtonStyle(
                foregroundColor: AdminMessageTheme.navy,
              ),
              icon: const Icon(Icons.arrow_back),
            ),
          ExcludeSemantics(
            child: _Avatar(name: profile.name, url: profile.avatarUrl),
          ),
          const SizedBox(width: AdminMessageTheme.space2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AdminMessageTheme.textPrimary,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminMessageTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (showProfileToggle && onToggleProfile != null)
            IconButton(
              tooltip: 'Alumni details',
              onPressed: onToggleProfile,
              style: AdminDensity.iconButtonStyle(
                foregroundColor: AdminMessageTheme.navy,
              ),
              icon: const Icon(Icons.info_outline),
            ),
        ],
      ),
    ),
    );
  }
}

class AdminAlumniProfilePanel extends StatelessWidget {
  const AdminAlumniProfilePanel({super.key, required this.profile});

  final AlumniMessageProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AdminMessageTheme.profileWidth,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AdminMessageTheme.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AdminDensity.cardPadding),
        children: [
          const Text(
            'Alumni details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: MessageTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Center(child: _Avatar(name: profile.name, url: profile.avatarUrl)),
          const SizedBox(height: 10),
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (profile.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              profile.email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: MessageTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _infoRow('Program', profile.program.isEmpty ? '—' : profile.program),
          _infoRow('Batch', profile.batch.isEmpty ? '—' : profile.batch),
          _infoRow('Registration', profile.registrationLabel),
          _infoRow(
            'Tracer profile',
            profile.tracerComplete ? 'Complete' : 'Incomplete',
          ),
          _infoRow(
            'Last activity',
            profile.lastActive == null
                ? '—'
                : formatMessageRelativeTime(profile.lastActive!),
          ),
          const SizedBox(height: 12),
          const Text(
            'Context stays here so you can reply without leaving the thread.',
            style: TextStyle(
              fontSize: 11.5,
              color: MessageTheme.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
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
              color: MessageTheme.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: MessageTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminInboxEmpty extends StatelessWidget {
  const AdminInboxEmpty({super.key, this.filtered = false});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AdminMessageTheme.space4,
          horizontal: AdminMessageTheme.space3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AdminMessageTheme.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                filtered ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
                size: 32,
                color: AdminMessageTheme.navy,
              ),
            ),
            const SizedBox(height: AdminMessageTheme.space2),
            Text(
              filtered ? 'No conversations match' : 'No conversations yet',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AdminMessageTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AdminMessageTheme.space1),
            Text(
              filtered
                  ? 'Try clearing filters or search.'
                  : 'Use New to message a registered alumnus, '
                      'or wait for them to write in.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AdminMessageTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
