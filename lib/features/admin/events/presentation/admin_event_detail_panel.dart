import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_comments_dialog.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_editor_dialog.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/events/data/event_comment_service.dart';
import 'package:alumni_system/features/events/data/event_rsvp_service.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/features/events/widgets/event_cover.dart';
import 'package:alumni_system/features/events/widgets/event_rsvp_bar.dart';
import 'package:alumni_system/features/share/share_link_sheet.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_tab_bar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/safe_link_text.dart';

Future<void> showAdminEventDetail({
  required BuildContext context,
  required AlumniEvent event,
  required VoidCallback onChanged,
  EventRsvpCounts? initialCounts,
}) {
  final child = AdminEventDetailPanel(
    event: event,
    onChanged: onChanged,
    initialCounts: initialCounts,
  );
  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(context: context, width: 580, child: child);
  }
  return showAdminDialogSurface<void>(
    context: context,
    maxWidth: 740,
    child: child,
  );
}

class AdminEventDetailPanel extends StatefulWidget {
  const AdminEventDetailPanel({
    super.key,
    required this.event,
    required this.onChanged,
    this.initialCounts,
    this.rsvpService,
    this.eventService,
    this.commentService,
  });

  final AlumniEvent event;
  final VoidCallback onChanged;
  final EventRsvpCounts? initialCounts;
  final EventRsvpService? rsvpService;
  final EventService? eventService;
  final EventCommentService? commentService;

  @override
  State<AdminEventDetailPanel> createState() => _AdminEventDetailPanelState();
}

class _AdminEventDetailPanelState extends State<AdminEventDetailPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final _rsvpService = widget.rsvpService ?? EventRsvpService();
  late final _eventService = widget.eventService ?? EventService();
  late final _commentService = widget.commentService ?? EventCommentService();
  late AlumniEvent _event;
  late int _commentCount;
  EventRsvpCounts _counts = const EventRsvpCounts();
  List<EventRsvp> _attendees = [];
  EventRsvpStatus? _attendeeFilter;
  bool _loadingRsvp = true;
  String? _rsvpError;
  StreamSubscription<void>? _rsvpWatch;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _commentCount = widget.event.comments;
    _tabs = TabController(length: 5, vsync: this);
    _counts = widget.initialCounts ?? const EventRsvpCounts();
    _loadRsvp();
    _rsvpWatch = _rsvpService.watchEventChanges(_event.id).listen((_) {
      if (mounted) _loadRsvp(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant AdminEventDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id) {
      _event = widget.event;
      _commentCount = widget.event.comments;
      _counts = widget.initialCounts ?? const EventRsvpCounts();
      _rsvpWatch?.cancel();
      _loadRsvp();
      _rsvpWatch = _rsvpService.watchEventChanges(_event.id).listen((_) {
        if (mounted) _loadRsvp(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _rsvpWatch?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadRsvp({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loadingRsvp = true;
        _rsvpError = null;
      });
    }
    try {
      final counts = await _rsvpService.getCounts(_event.id);
      final list = await _rsvpService.listForEvent(
        _event.id,
        status: _attendeeFilter,
      );
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _attendees = list;
        _loadingRsvp = false;
        _rsvpError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRsvp = false;
        if (!silent) {
          _rsvpError = eventFriendlyError(
            e,
            "Couldn't load attendance responses.",
          );
        }
      });
    }
  }

  Future<void> _editEvent() async {
    final saved = await showAdminEventEditorDialog(
      context: context,
      event: _event,
    );
    if (saved != true || !mounted) return;
    widget.onChanged();
    final updated = await _eventService.getEventById(_event.id);
    if (updated != null && mounted) {
      setState(() {
        _event = updated;
        _commentCount = updated.comments;
      });
    }
  }

  void _handleCommentsChanged() {
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    final daysUntil = eventDaysUntil(e);
    final showCountdown =
        !e.cancelled &&
        e.status != 'Archived' &&
        daysUntil >= 0 &&
        daysUntil <= 7;
    final canShare =
        !e.cancelled && e.status.trim().toLowerCase() != 'archived';

    return ColoredBox(
      color: AdminColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AdminEventStatusBadge(event: e),
                          AdminEventCategoryBadge(category: e.category),
                          if (showCountdown)
                            AdminEventCountdownBadge(daysUntil: daysUntil),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Edit event',
                      onPressed: _editEvent,
                      style: AdminDensity.iconButtonStyle(
                        foregroundColor: AdminColors.primary,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    if (canShare)
                      IconButton(
                        tooltip: 'Share link…',
                        onPressed: () => showShareLinkSheet(
                          context,
                          ShareableContent.fromEvent(e),
                        ),
                        style: AdminDensity.iconButtonStyle(
                          foregroundColor: AdminColors.textSecondary,
                        ),
                        icon: const Icon(Icons.share_outlined, size: 18),
                      ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      style: AdminDensity.iconButtonStyle(
                        foregroundColor: AdminColors.textMuted,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  e.theme.trim().isEmpty ? 'Untitled event' : e.theme,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: -0.2,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '${DateFormat('EEEE, MMM d, yyyy').format(e.date)} · ${e.startTime}–${e.endTime}',
                    if (e.batchYear.trim().isNotEmpty) 'Batch ${e.batchYear.trim()}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AdminTabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: [
              const AdminTabSpec(
                label: 'Overview',
                icon: Icons.info_outline_rounded,
              ),
              AdminTabSpec(
                label: 'Agenda',
                icon: Icons.list_alt_outlined,
                count: e.agenda.isNotEmpty ? e.agenda.length : null,
              ),
              AdminTabSpec(
                label: 'Attendance',
                icon: Icons.people_outline_rounded,
                count: _counts.totalResponses > 0
                    ? _counts.totalResponses
                    : null,
              ),
              AdminTabSpec(
                label: 'Comments',
                icon: Icons.forum_outlined,
                count: _commentCount > 0 ? _commentCount : null,
              ),
              const AdminTabSpec(
                label: 'Analytics',
                icon: Icons.analytics_outlined,
              ),
            ],
          ),
          Expanded(
            child: ColoredBox(
              color: AdminColors.background,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _overview(e),
                  _agenda(e),
                  _attendance(),
                  AdminEventCommentsDialog(
                    event: e,
                    commentService: _commentService,
                    onCommentDeleted: _handleCommentsChanged,
                    asDialog: true,
                    embedded: true,
                    onCountChanged: (count) {
                      if (mounted && _commentCount != count) {
                        setState(() => _commentCount = count);
                      }
                    },
                  ),
                  _analytics(e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overview(AlumniEvent e) {
    final cap = e.capacity;
    final hasCap = cap != null && cap > 0;
    final progress = hasCap ? (_counts.going / cap).clamp(0.0, 1.0) : 0.0;
    final full = hasCap && _counts.going >= cap;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        EventCoverHero(
          event: e,
          borderRadius: AdminSurfaces.radiusMd,
          showDownload: true,
          placeholderColors: const [AdminColors.primary, AdminColors.secondary],
        ),
        if (e.capacity != null ||
            e.registrationDeadline != null ||
            e.batchYear.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (e.capacity != null)
                AdminBadge.neutral(
                  label: 'Capacity ${e.capacity}',
                  icon: Icons.event_seat_outlined,
                ),
              if (e.registrationDeadline != null)
                AdminBadge.neutral(
                  label:
                      'Reg closes ${DateFormat('MMM d, yyyy').format(e.registrationDeadline!)}',
                  icon: Icons.timer_outlined,
                ),
              if (e.batchYear.trim().isNotEmpty)
                AdminBadge.neutral(
                  label: 'Batch ${e.batchYear.trim()}',
                  icon: Icons.groups_outlined,
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AdminSurfaces.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EventRsvpCountRow(
                counts: _counts,
                capacity: e.capacity,
                includeNotGoing: true,
              ),
              if (hasCap) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AdminColors.surface,
                    color: full ? AdminColors.danger : AdminColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _detailSection(
          title: 'When & where',
          icon: Icons.place_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(
                Icons.calendar_today_outlined,
                DateFormat('EEEE, MMM d, yyyy').format(e.date),
              ),
              _infoRow(
                Icons.access_time_rounded,
                '${e.startTime} – ${e.endTime}',
              ),
              _infoRow(
                Icons.location_on_outlined,
                e.venue,
                bottomPadding: e.hasVenuePin ? 6 : 10,
                trailing: OutlinedButton.icon(
                  onPressed: () => openEventVenueInMaps(e),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    e.hasVenuePin ? 'Open pinned location' : 'Open in Maps',
                  ),
                  style: AdminButtonStyles.outlined().copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 10),
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              if (e.hasVenuePin)
                Padding(
                  padding: const EdgeInsets.only(left: 28, bottom: 8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: AdminColors.success,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Exact map pin saved for this venue',
                        style: TextStyle(
                          fontSize: 12,
                          color: AdminColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (e.batchYear.trim().isNotEmpty)
                _infoRow(
                  Icons.groups_outlined,
                  'Target audience: Batch ${e.batchYear}',
                  bottomPadding: 0,
                ),
            ],
          ),
        ),
        if (e.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _detailSection(
            title: 'Description',
            icon: Icons.notes_outlined,
            child: SafeLinkText(
              e.description,
              style: const TextStyle(
                height: 1.5,
                fontSize: 13.5,
                color: AdminColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AdminSurfaces.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AdminColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 15, color: AdminColors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _agenda(AlumniEvent e) {
    if (e.agenda.isEmpty) {
      return const AdminStateView.empty(
        compact: true,
        icon: Icons.list_alt_outlined,
        title: 'No agenda items yet',
        message: 'Add timed program items when editing this event.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      itemCount: e.agenda.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = e.agenda[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: AdminSurfaces.card(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 70),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: AdminColors.infoBg,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
                child: Text(
                  item.time.isEmpty ? '—' : item.time,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AdminColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _attendance() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: AdminSurfaces.card(),
            child: Row(
              children: [
                Expanded(
                  child: EventRsvpCountRow(
                    counts: _counts,
                    includeNotGoing: true,
                  ),
                ),
                const SizedBox(width: 10),
                DirectoryFilterField<EventRsvpStatus?>(
                  label: 'RSVP',
                  value: _attendeeFilter,
                  dense: true,
                  width: 128,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All RSVPs')),
                    DropdownMenuItem(
                      value: EventRsvpStatus.going,
                      child: Text('Going'),
                    ),
                    DropdownMenuItem(
                      value: EventRsvpStatus.notGoing,
                      child: Text('Not going'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _attendeeFilter = v);
                    _loadRsvp();
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loadingRsvp
              ? const AdminStateView.loading(
                  compact: true,
                  label: 'Loading attendance…',
                )
              : _rsvpError != null
              ? AdminStateView.error(
                  compact: true,
                  title: "Couldn't load RSVPs",
                  message: _rsvpError,
                  onRetry: _loadRsvp,
                )
              : _attendees.isEmpty
              ? AdminStateView.empty(
                  compact: true,
                  icon: Icons.people_outline_rounded,
                  title: _attendeeFilter == null
                      ? 'No RSVPs yet'
                      : 'No matching RSVPs',
                  message: _attendeeFilter == null
                      ? 'Alumni attendance responses will appear here.'
                      : 'Try changing the RSVP status filter.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: _attendees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = _attendees[i];
                    final avatar = AppImage.provider(a.profileImageUrl);
                    final isGoing = a.status == EventRsvpStatus.going;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: AdminSurfaces.card(),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AdminColors.primary,
                            backgroundImage: avatar,
                            child: avatar == null
                                ? Text(
                                    a.userName.isNotEmpty
                                        ? a.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.userName.isEmpty ? 'Alumni' : a.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: AdminColors.textPrimary,
                                  ),
                                ),
                                if (a.userEmail.trim().isNotEmpty)
                                  Text(
                                    a.userEmail,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          isGoing
                              ? AdminBadge.success(
                                  label: a.status.label,
                                  icon: Icons.check_rounded,
                                )
                              : AdminBadge.neutral(label: a.status.label),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _analytics(AlumniEvent e) {
    final total = _counts.totalResponses;
    final goingPct = total == 0 ? 0.0 : _counts.going / total;
    final notGoingPct = total == 0 ? 0.0 : _counts.notGoing / total;
    final hasCap = e.capacity != null && e.capacity! > 0;
    final capacityPct = !hasCap
        ? 0.0
        : (_counts.going / e.capacity!).clamp(0.0, 1.0);

    final tiles = <Widget>[
      _analyticsTile(
        label: 'Views',
        value: '${e.viewsCount}',
        icon: Icons.visibility_outlined,
        accent: AdminColors.primary,
      ),
      _analyticsTile(
        label: 'Going',
        value: '${_counts.going}',
        icon: Icons.check_circle_outline_rounded,
        accent: AdminColors.success,
      ),
      _analyticsTile(
        label: 'Not going',
        value: '${_counts.notGoing}',
        icon: Icons.cancel_outlined,
        accent: AdminColors.danger,
      ),
      _analyticsTile(
        label: 'Going rate',
        value: total == 0 ? '—' : '${(goingPct * 100).round()}%',
        icon: Icons.trending_up_rounded,
        accent: AdminColors.primary,
      ),
      _analyticsTile(
        label: 'Capacity used',
        value: hasCap ? '${(capacityPct * 100).round()}%' : 'Uncapped',
        icon: Icons.event_seat_outlined,
        accent: capacityPct >= 1.0 ? AdminColors.danger : AdminColors.secondary,
      ),
      _analyticsTile(
        label: 'Comments',
        value: '$_commentCount',
        icon: Icons.forum_outlined,
        accent: AdminColors.secondary,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 460 ? 3 : 2;
            const gap = 8.0;
            final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final tile in tiles) SizedBox(width: w, child: tile),
              ],
            );
          },
        ),
        if (hasCap) ...[
          const SizedBox(height: 12),
          _detailSection(
            title: 'Capacity utilization',
            icon: Icons.event_seat_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_counts.going} of ${e.capacity} seats filled',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(capacityPct * 100).round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: capacityPct >= 1.0
                            ? AdminColors.danger
                            : AdminColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: capacityPct,
                    minHeight: 7,
                    backgroundColor: AdminColors.surface,
                    color: capacityPct >= 1.0
                        ? AdminColors.danger
                        : AdminColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _detailSection(
          title: 'RSVP mix',
          icon: Icons.pie_chart_outline_rounded,
          child: total == 0
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No RSVP data yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 44,
                              sections: [
                                if (_counts.going > 0)
                                  PieChartSectionData(
                                    value: _counts.going.toDouble(),
                                    color: AdminColors.success,
                                    radius: 32,
                                    showTitle: false,
                                  ),
                                if (_counts.notGoing > 0)
                                  PieChartSectionData(
                                    value: _counts.notGoing.toDouble(),
                                    color: AdminColors.danger,
                                    radius: 32,
                                    showTitle: false,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$total',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              const Text(
                                'RSVPs',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AdminColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AdminColors.border),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _legendDot(
                          color: AdminColors.success,
                          label: 'Going',
                          value: '${_counts.going} (${(goingPct * 100).round()}%)',
                        ),
                        _legendDot(
                          color: AdminColors.danger,
                          label: 'Not going',
                          value:
                              '${_counts.notGoing} (${(notGoingPct * 100).round()}%)',
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _analyticsTile({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AdminSurfaces.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · ',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AdminColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            color: AdminColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    IconData icon,
    String text, {
    Widget? trailing,
    double bottomPadding = 10,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AdminColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AdminColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}
