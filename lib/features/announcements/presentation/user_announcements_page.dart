import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
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
  static const _searchDebounce = Duration(milliseconds: 250);

  final _service = AnnouncementService();
  final _search = TextEditingController();
  Stream<List<Announcement>>? _stream;
  Timer? _searchTimer;
  String _query = '';
  String? _expandedId;
  _AnnouncementDateRange _dateRange = _AnnouncementDateRange.any;

  @override
  void initState() {
    super.initState();
    _expandedId = widget.initialAnnouncementId;
    _subscribe();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Created once (and on retry) — never inside build, or every setState
  /// would open a new subscription and flash the loading skeleton.
  void _subscribe() {
    final uid = AppSession.userId;
    _stream = uid == null ? null : _service.watchPublishedForUser(uid);
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      final next = _search.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
  }

  bool get _filtersActive =>
      _query.isNotEmpty || _dateRange != _AnnouncementDateRange.any;

  void _clearFilters() {
    _searchTimer?.cancel();
    setState(() {
      _search.clear();
      _query = '';
      _dateRange = _AnnouncementDateRange.any;
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _search.clear();
    if (_query.isNotEmpty) setState(() => _query = '');
  }

  void _toggle(String id) =>
      setState(() => _expandedId = _expandedId == id ? null : id);

  List<Announcement> _applyFilters(List<Announcement> items) {
    final query = _query;
    final cutoff = _dateRange.cutoff(DateTime.now());
    return items.where((a) {
      final date = a.publishedAt ?? a.createdAt;
      if (cutoff != null && date.isBefore(cutoff)) return false;
      if (query.isEmpty) return true;
      return a.title.toLowerCase().contains(query) ||
          a.body.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.userId;
    final stream = _stream;
    if (uid == null || stream == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
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
        stream: stream,
        initialData: _service.cachedPublishedForUser(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return PortalErrorState(
              error: snapshot.error,
              onRetry: () => setState(_subscribe),
            );
          }
          if (!snapshot.hasData) {
            return const AnnouncementListSkeleton();
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

          final filtered = _applyFilters(items);
          final important = filtered.where(
            (a) => a.priority == AnnouncementPriority.important,
          );
          final regular = filtered.where(
            (a) => a.priority != AnnouncementPriority.important,
          );

          return PortalContentFrame(
            child: ListView(
              padding: PortalBreakpoints.pagePadding(
                MediaQuery.sizeOf(context).width,
              ),
              children: [
                _AnnouncementFilterBar(
                  controller: _search,
                  dateRange: _dateRange,
                  onSearchChanged: _onSearchChanged,
                  onSearchCleared: _clearSearch,
                  onDateChanged: (range) => setState(() => _dateRange = range),
                ),
                if (_filtersActive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PortalTheme.space2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Showing ${filtered.length} of ${items.length} '
                            '${items.length == 1 ? 'announcement' : 'announcements'}',
                            style: PortalTheme.caption,
                          ),
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          style: TextButton.styleFrom(
                            foregroundColor: PortalTheme.navy,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Clear filters',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (filtered.isEmpty)
                  PortalEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No announcements match your filters',
                    subtitle: 'Try a different word or date range.',
                    actionLabel: 'Clear filters',
                    onAction: _clearFilters,
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
                      onToggle: () => _toggle(a.id),
                    ),
                  const SizedBox(height: PortalTheme.space4),
                ],
                if (regular.isNotEmpty) ...[
                  if (important.isNotEmpty)
                    PortalSectionHeader(
                      title: 'All updates',
                      padding: const EdgeInsets.only(
                        bottom: PortalTheme.space2,
                      ),
                    ),
                  for (final a in regular)
                    _AnnouncementPreviewRow(
                      announcement: a,
                      expanded: _expandedId == a.id,
                      onToggle: () => _toggle(a.id),
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
    const previewStyle = PortalTheme.bodySecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canExpand = _bodyOverflows(
            context,
            announcement.body,
            previewStyle,
            constraints.maxWidth - PortalTheme.space4 * 2,
          );
          final open = expanded && canExpand;
          return PortalHighlightPanel(
            variant: PortalHighlightVariant.goldEdge,
            padding: const EdgeInsets.all(PortalTheme.space4),
            onTap: canExpand ? onToggle : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                _ExpandableBody(
                  expanded: open,
                  preview: preview,
                  body: announcement.body,
                  previewGap: 6,
                  previewStyle: previewStyle,
                ),
                if (canExpand) ...[
                  const SizedBox(height: PortalTheme.space2),
                  Row(
                    children: [
                      Text(
                        open ? 'Show less' : 'Read full notice',
                        style: PortalTheme.meta.copyWith(
                          color: PortalTheme.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: PortalTheme.navy,
                      ),
                    ],
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
    final previewStyle = PortalTheme.bodySecondary.copyWith(fontSize: 13);

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canExpand = _bodyOverflows(
            context,
            announcement.body,
            previewStyle,
            constraints.maxWidth - PortalTheme.space3 * 2,
          );
          final open = expanded && canExpand;
          return Material(
            color: PortalTheme.card,
            elevation: 1,
            shadowColor: PortalTheme.navy.withValues(alpha: 0.08),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
              side: BorderSide(
                color: PortalTheme.border.withValues(alpha: 0.75),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: canExpand ? onToggle : null,
              child: Padding(
                padding: const EdgeInsets.all(PortalTheme.space3),
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
                            borderRadius: BorderRadius.circular(
                              PortalTheme.radiusMd,
                            ),
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
                        if (canExpand)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: PortalTheme.navy.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              open
                                  ? Icons.expand_less_rounded
                                  : Icons.chevron_right_rounded,
                              color: PortalTheme.navy,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    _ExpandableBody(
                      expanded: open,
                      preview: preview,
                      body: announcement.body,
                      previewGap: 10,
                      previewStyle: previewStyle,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Two-line preview when collapsed, full body when expanded, with a size
/// animation so toggling doesn't jump.
class _ExpandableBody extends StatelessWidget {
  const _ExpandableBody({
    required this.expanded,
    required this.preview,
    required this.body,
    required this.previewGap,
    required this.previewStyle,
  });

  final bool expanded;
  final String preview;
  final String body;
  final double previewGap;
  final TextStyle previewStyle;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (expanded) {
      child = Padding(
        key: const ValueKey('full'),
        padding: const EdgeInsets.only(top: PortalTheme.space3),
        child: Text(body, style: PortalTheme.body.copyWith(height: 1.5)),
      );
    } else if (preview.isNotEmpty) {
      child = Padding(
        key: const ValueKey('preview'),
        padding: EdgeInsets.only(top: previewGap),
        child: Text(
          preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: previewStyle,
        ),
      );
    } else {
      child = const SizedBox(key: ValueKey('empty'), width: double.infinity);
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

enum _AnnouncementDateRange {
  any('Any time', 'Any time', null),
  week('Past 7 days', '7 days', 7),
  month('Past 30 days', '30 days', 30),
  year('Past 12 months', '12 months', 365);

  const _AnnouncementDateRange(this.label, this.shortLabel, this.days);

  final String label;
  final String shortLabel;
  final int? days;

  DateTime? cutoff(DateTime now) =>
      days == null ? null : now.subtract(Duration(days: days!));
}

/// Search box plus date-range chip on one line above the announcement list.
class _AnnouncementFilterBar extends StatelessWidget {
  const _AnnouncementFilterBar({
    required this.controller,
    required this.dateRange,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onDateChanged,
  });

  final TextEditingController controller;
  final _AnnouncementDateRange dateRange;
  final VoidCallback onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<_AnnouncementDateRange> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: PortalTheme.space2),
      padding: const EdgeInsets.all(PortalTheme.space2),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: PortalTheme.navy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(child: _searchField()),
            const SizedBox(width: 8),
            _dateChip(compact: constraints.maxWidth < 360),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    final radius = BorderRadius.circular(PortalTheme.radiusMd);
    return TextField(
      controller: controller,
      onChanged: (_) => onSearchChanged(),
      style: PortalTheme.body,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search announcements…',
        hintStyle: PortalTheme.bodySecondary,
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: PortalTheme.textSecondary,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onSearchCleared,
                ),
        ),
        isDense: true,
        filled: true,
        fillColor: PortalTheme.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: PortalTheme.navy, width: 1.2),
        ),
      ),
    );
  }

  /// [compact] drops the "Any time" label and shortens active labels so the
  /// search box keeps its room on narrow phones.
  Widget _dateChip({required bool compact}) {
    final active = dateRange != _AnnouncementDateRange.any;
    final foreground = active ? Colors.white : PortalTheme.textSecondary;
    final label = !compact
        ? dateRange.label
        : (active ? dateRange.shortLabel : null);
    return PopupMenuButton<_AnnouncementDateRange>(
      tooltip: 'Filter by date',
      onSelected: onDateChanged,
      itemBuilder: (context) => [
        for (final range in _AnnouncementDateRange.values)
          portalMenuItem(
            value: range,
            label: range.label,
            selected: range == dateRange,
          ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 12),
        decoration: BoxDecoration(
          color: active ? PortalTheme.navy : PortalTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          border: Border.all(
            color: active
                ? PortalTheme.navy
                : PortalTheme.border.withValues(alpha: 0.9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 15, color: foreground),
            if (label != null) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }
}

const _previewChars = 120;

String _previewBody(String body) {
  final trimmed = body.trim();
  if (trimmed.length <= _previewChars) return trimmed;
  return '${trimmed.substring(0, _previewChars).trim()}…';
}

/// Whether [body] is cut off by the collapsed two-line preview, measured with
/// the same style and text scale the preview uses at [maxWidth].
bool _bodyOverflows(
  BuildContext context,
  String body,
  TextStyle style,
  double maxWidth,
) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.length > _previewChars) return true;
  final painter = TextPainter(
    text: TextSpan(
      text: trimmed,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    maxLines: 2,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth - 2);
  final overflows = painter.didExceedMaxLines;
  painter.dispose();
  return overflows;
}
