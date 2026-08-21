import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';

class UserAnnouncementsScreen extends StatefulWidget {
  const UserAnnouncementsScreen({
    super.key,
    this.initialAnnouncementId,
    this.embeddedInHub = false,
  });

  final String? initialAnnouncementId;

  /// When true, omit the top AppBar (parent Community hub provides chrome).
  final bool embeddedInHub;

  @override
  State<UserAnnouncementsScreen> createState() =>
      _UserAnnouncementsScreenState();
}

class _UserAnnouncementsScreenState extends State<UserAnnouncementsScreen> {
  final _service = AnnouncementService();
  int _streamGeneration = 0;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _expandedId = widget.initialAnnouncementId;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.userId;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: widget.embeddedInHub
          ? null
          : const PortalAppBar(
              title: 'Announcements',
              automaticallyImplyLeading: true,
            ),
      body: StreamBuilder<List<Announcement>>(
        key: ValueKey(_streamGeneration),
        stream: _service.watchPublishedForUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AnnouncementListSkeleton();
          }
          if (snapshot.hasError) {
            return PortalErrorState(
              error: snapshot.error,
              onRetry: () => setState(() => _streamGeneration++),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const PortalEmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements yet',
              subtitle:
                  'When the office publishes updates, they will show up here.',
            );
          }

          final important =
              items.where((a) => a.priority == AnnouncementPriority.important);
          final regular =
              items.where((a) => a.priority != AnnouncementPriority.important);

          return PortalContentFrame(
            child: ListView(
              padding: PortalBreakpoints.pagePadding(
                MediaQuery.sizeOf(context).width,
              ),
              children: [
                if (!widget.embeddedInHub)
                  const PortalPageIntro(
                    headline: 'Stay informed',
                    body:
                        'Official notices and updates from the alumni office.',
                    padding: EdgeInsets.fromLTRB(0, 4, 0, 16),
                  ),
                if (important.isNotEmpty) ...[
                  PortalSectionHeader(
                    title: 'Important',
                    padding: const EdgeInsets.only(bottom: PortalTheme.space2),
                  ),
                  for (final a in important)
                    _FeaturedAnnouncementTile(
                      announcement: a,
                      expanded: _expandedId == a.id,
                      onToggle: () => setState(() {
                        _expandedId = _expandedId == a.id ? null : a.id;
                      }),
                    ),
                  const SizedBox(height: PortalTheme.space4),
                ],
                if (regular.isNotEmpty) ...[
                  if (important.isNotEmpty)
                    PortalSectionHeader(
                      title: 'All updates',
                      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
                    ),
                  for (final a in regular)
                    _AnnouncementPreviewRow(
                      announcement: a,
                      expanded: _expandedId == a.id,
                      onToggle: () => setState(() {
                        _expandedId = _expandedId == a.id ? null : a.id;
                      }),
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

class _FeaturedAnnouncementTile extends StatelessWidget {
  const _FeaturedAnnouncementTile({
    required this.announcement,
    required this.expanded,
    required this.onToggle,
  });

  final Announcement announcement;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final date = announcement.publishedAt ?? announcement.createdAt;
    final preview = _previewBody(announcement.body);

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: PortalHighlightPanel(
        variant: PortalHighlightVariant.goldEdge,
        padding: const EdgeInsets.all(PortalTheme.space4),
        onTap: onToggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PortalTheme.gold.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.priority_high_rounded,
                        size: 14,
                        color: PortalTheme.navy,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Important',
                        style: PortalTheme.caption.copyWith(
                          color: PortalTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.yMMMd().format(date),
                  style: PortalTheme.caption,
                ),
              ],
            ),
            const SizedBox(height: PortalTheme.space2),
            Text(
              announcement.title,
              style: PortalTheme.sectionTitle.copyWith(fontSize: 18),
            ),
            if (!expanded && preview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PortalTheme.bodySecondary,
              ),
            ],
            if (expanded) ...[
              const SizedBox(height: PortalTheme.space3),
              Text(
                announcement.body,
                style: PortalTheme.body.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: PortalTheme.space2),
            Row(
              children: [
                Text(
                  expanded ? 'Show less' : 'Read full notice',
                  style: PortalTheme.meta.copyWith(
                    color: PortalTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: PortalTheme.navy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementPreviewRow extends StatelessWidget {
  const _AnnouncementPreviewRow({
    required this.announcement,
    required this.expanded,
    required this.onToggle,
  });

  final Announcement announcement;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final date = announcement.publishedAt ?? announcement.createdAt;
    final preview = _previewBody(announcement.body);

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: Material(
        color: PortalTheme.card,
        elevation: 1,
        shadowColor: PortalTheme.navy.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
          side: BorderSide(color: PortalTheme.border.withValues(alpha: 0.75)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              PortalTheme.space3,
              PortalTheme.space3,
              PortalTheme.space3,
              expanded ? PortalTheme.space3 : PortalTheme.space3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PortalTheme.navy.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(PortalTheme.radiusMd),
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        color: PortalTheme.navy,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: PortalTheme.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            announcement.title,
                            style: PortalTheme.cardTitle.copyWith(
                              fontSize: 15,
                              color: PortalTheme.navy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PortalTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              DateFormat.yMMMd().format(date),
                              style: PortalTheme.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: PortalTheme.navy.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.chevron_right_rounded,
                        color: PortalTheme.navy,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                if (!expanded && preview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PortalTheme.bodySecondary.copyWith(fontSize: 13),
                  ),
                ],
                if (expanded) ...[
                  const SizedBox(height: PortalTheme.space3),
                  Text(
                    announcement.body,
                    style: PortalTheme.body.copyWith(height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _previewBody(String body) {
  final trimmed = body.trim();
  if (trimmed.length <= 120) return trimmed;
  return '${trimmed.substring(0, 120).trim()}…';
}
