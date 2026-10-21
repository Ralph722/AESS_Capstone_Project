import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_comments_dialog.dart';
import 'package:alumni_system/features/events/data/event_comment_service.dart';
import 'package:alumni_system/features/events/data/event_rsvp_service.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/features/events/widgets/event_cover.dart';
import 'package:alumni_system/features/events/widgets/event_rsvp_bar.dart';
import 'package:alumni_system/features/events/widgets/event_status_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/safe_link_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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
    return showAdminSidePanel<void>(context: context, width: 520, child: child);
  }
  return showAdminDialogSurface<void>(
    context: context,
    maxWidth: 720,
    child: child,
  );
}

class AdminEventDetailPanel extends StatefulWidget {
  const AdminEventDetailPanel({
    super.key,
    required this.event,
    required this.onChanged,
    this.initialCounts,
  });

  final AlumniEvent event;
  final VoidCallback onChanged;
  final EventRsvpCounts? initialCounts;

  @override
  State<AdminEventDetailPanel> createState() => _AdminEventDetailPanelState();
}

class _AdminEventDetailPanelState extends State<AdminEventDetailPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _rsvpService = EventRsvpService();
  EventRsvpCounts _counts = const EventRsvpCounts();
  List<EventRsvp> _attendees = [];
  EventRsvpStatus? _attendeeFilter;
  bool _loadingRsvp = true;
  StreamSubscription<void>? _rsvpWatch;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _counts = widget.initialCounts ?? const EventRsvpCounts();
    _loadRsvp();
    _rsvpWatch = _rsvpService.watchEventChanges(widget.event.id).listen((_) {
      if (mounted) _loadRsvp(silent: true);
    });
  }

  @override
  void dispose() {
    _rsvpWatch?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadRsvp({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loadingRsvp = true);
    try {
      final counts = await _rsvpService.getCounts(widget.event.id);
      final list = await _rsvpService.listForEvent(
        widget.event.id,
        status: _attendeeFilter,
      );
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _attendees = list;
        _loadingRsvp = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRsvp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AdminEventTheme.space3,
            AdminEventTheme.space2,
            AdminEventTheme.space1,
            AdminEventTheme.space1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  e.theme,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminEventTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AdminEventTheme.primary,
          unselectedLabelColor: AdminEventTheme.textSecondary,
          indicatorColor: AdminEventTheme.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Agenda'),
            Tab(text: 'Attendance'),
            Tab(text: 'Comments'),
            Tab(text: 'Analytics'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _overview(e),
              _agenda(e),
              _attendance(),
              AdminEventCommentsDialog(
                event: e,
                commentService: EventCommentService(),
                onCommentDeleted: widget.onChanged,
                asDialog: true,
              ),
              _analytics(e),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overview(AlumniEvent e) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        EventCoverHero(event: e, borderRadius: 10, showDownload: true),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            EventStatusBadge(event: e),
            EventCategoryChip(category: e.category),
            if (e.capacity != null)
              _metaChip(Icons.event_seat, 'Cap ${e.capacity}'),
            if (e.registrationDeadline != null)
              _metaChip(
                Icons.timer_outlined,
                'Reg ends ${DateFormat('MMM d').format(e.registrationDeadline!)}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminEventTheme.surface,
            borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
            border: Border.all(color: AdminEventTheme.border),
          ),
          child: EventRsvpCountRow(
            counts: _counts,
            capacity: e.capacity,
            includeNotGoing: true,
          ),
        ),
        const SizedBox(height: 12),
        _detailSection(
          title: 'When & where',
          icon: Icons.place_outlined,
          child: Column(
            children: [
              _infoRow(
                Icons.calendar_today,
                DateFormat('EEEE, MMM d, yyyy').format(e.date),
              ),
              _infoRow(Icons.access_time, '${e.startTime} – ${e.endTime}'),
              _infoRow(
                Icons.location_on,
                e.venue,
                trailing: TextButton(
                  onPressed: () => openEventVenueInMaps(e),
                  child: Text(
                    e.hasVenuePin ? 'Open pinned location' : 'Open in Maps',
                  ),
                ),
              ),
              if (e.hasVenuePin)
                Padding(
                  padding: const EdgeInsets.only(left: 28, bottom: 4),
                  child: Text(
                    'Exact map pin saved for this venue',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (e.batchYear.trim().isNotEmpty)
                _infoRow(Icons.groups_outlined, 'Batch ${e.batchYear}'),
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
                height: 1.45,
                fontSize: 13.5,
                color: AdminEventTheme.textSecondary,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
        border: Border.all(color: AdminEventTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AdminEventTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AdminEventTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _agenda(AlumniEvent e) {
    if (e.agenda.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.list_alt_outlined,
                size: 40,
                color: AdminEventTheme.textMuted,
              ),
              const SizedBox(height: 10),
              const Text(
                'No agenda items yet',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AdminEventTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add agenda rows when editing this event.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AdminEventTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      itemCount: e.agenda.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = e.agenda[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AdminEventTheme.border),
            borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                decoration: BoxDecoration(
                  color: AdminEventTheme.infoBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.time.isEmpty ? '—' : item.time,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AdminEventTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AdminEventTheme.textPrimary,
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminEventTheme.surface,
              borderRadius: BorderRadius.circular(AdminEventTheme.radiusSm),
              border: Border.all(color: AdminEventTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: EventRsvpCountRow(
                    counts: _counts,
                    includeNotGoing: true,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: DirectoryFilterField<EventRsvpStatus?>(
                    label: 'RSVP',
                    value: _attendeeFilter,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
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
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingRsvp
              ? const Center(child: CircularProgressIndicator())
              : _attendees.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 40,
                          color: AdminEventTheme.textMuted,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No RSVPs yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AdminEventTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Alumni responses will appear here.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AdminEventTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  itemCount: _attendees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = _attendees[i];
                    final avatar = AppImage.provider(a.profileImageUrl);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AdminEventTheme.radiusSm,
                        ),
                        border: Border.all(color: AdminEventTheme.border),
                      ),
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
                                  a.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: AdminEventTheme.textPrimary,
                                  ),
                                ),
                                if (a.userEmail.trim().isNotEmpty)
                                  Text(
                                    a.userEmail,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminEventTheme.textSecondary,
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
                              color: AdminEventTheme.infoBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              a.status.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                color: AdminEventTheme.primary,
                              ),
                            ),
                          ),
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
    final capacityPct = (e.capacity == null || e.capacity! <= 0)
        ? 0.0
        : (_counts.going / e.capacity!).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _kpi('Views', '${e.viewsCount}'),
            _kpi('Going', '${_counts.going}'),
            _kpi('Not going', '${_counts.notGoing}'),
            _kpi('Going %', '${(goingPct * 100).round()}%'),
            _kpi('Capacity %', '${(capacityPct * 100).round()}%'),
            _kpi('Comments', '${e.comments}'),
          ],
        ),
        const SizedBox(height: 14),
        _detailSection(
          title: 'RSVP mix',
          icon: Icons.pie_chart_outline,
          child: SizedBox(
            height: 180,
            child: total == 0
                ? const Center(
                    child: Text(
                      'No RSVP data yet',
                      style: TextStyle(color: AdminEventTheme.textSecondary),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      sections: [
                        PieChartSectionData(
                          value: _counts.going.toDouble(),
                          color: const Color(0xFF059669),
                          title: 'Going',
                          radius: 48,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        PieChartSectionData(
                          value: _counts.notGoing.toDouble(),
                          color: const Color(0xFFDC2626),
                          title: 'Not going',
                          radius: 48,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _kpi(String label, String value) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(AdminDensity.kpiCardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AdminColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
