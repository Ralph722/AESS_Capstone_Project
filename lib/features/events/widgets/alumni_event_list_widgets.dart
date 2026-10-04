import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/events/models/event_display_status.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/features/events/widgets/event_cover.dart';
import 'package:alumni_system/features/events/widgets/event_rsvp_bar.dart';
import 'package:alumni_system/features/events/widgets/event_status_badge.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

String formatAlumniEventTimeRange(String start, String end) {
  String fmt(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1].split(' ').first);
    if (h == null || m == null) return raw;
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
  }

  return '${fmt(start)} – ${fmt(end)}';
}

class EventMetaRow extends StatelessWidget {
  const EventMetaRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: PortalTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: PortalTheme.meta.copyWith(color: PortalTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class EventSeatsLine extends StatelessWidget {
  const EventSeatsLine({
    super.key,
    required this.event,
    required this.goingCount,
  });

  final AlumniEvent event;
  final int goingCount;

  @override
  Widget build(BuildContext context) {
    final seats = event.seatsRemaining(goingCount);
    if (seats == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            Icons.event_seat_outlined,
            size: 14,
            color: seats == 0 ? PortalTheme.danger : PortalTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            '$seats / ${event.capacity} seats left',
            style: PortalTheme.meta.copyWith(
              fontWeight: FontWeight.w700,
              color: seats == 0
                  ? PortalTheme.danger
                  : PortalTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class EventConstraintLabels extends StatelessWidget {
  const EventConstraintLabels({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: labels
            .map(
              (label) => PortalChip(label: label, tone: PortalChipTone.danger),
            )
            .toList(),
      ),
    );
  }
}

class AlumniEventsEmptyState extends StatelessWidget {
  const AlumniEventsEmptyState({
    super.key,
    required this.hasSearchQuery,
    this.onClearSearch,
  });

  final bool hasSearchQuery;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    return PortalEmptyState(
      icon: Icons.event_busy_outlined,
      title: hasSearchQuery ? 'No matching events' : 'No upcoming events',
      subtitle: hasSearchQuery
          ? 'Try a different search or clear your filters.'
          : 'There aren\'t any alumni events scheduled right now. Check back soon.',
      actionLabel: hasSearchQuery ? 'Clear search' : null,
      onAction: hasSearchQuery ? onClearSearch : null,
    );
  }
}

/// Compact feed summary: "✓ 1 Going"
class EventRsvpSummaryPill extends StatelessWidget {
  const EventRsvpSummaryPill({
    super.key,
    required this.counts,
    this.selectedStatus,
  });

  final EventRsvpCounts counts;
  final EventRsvpStatus? selectedStatus;

  @override
  Widget build(BuildContext context) {
    return EventRsvpCountsLine(counts: counts, compact: true);
  }
}

/// Discovery card — consistent image teaser, meta, counts, quick RSVP.
class AlumniEventListCard extends StatelessWidget {
  const AlumniEventListCard({
    super.key,
    required this.event,
    required this.counts,
    required this.selectedStatus,
    required this.constraintLabels,
    required this.onTap,
    this.featured = false,
    this.goingEnabled = true,
    this.busy = false,
    this.onRsvpChanged,
  });

  final AlumniEvent event;
  final EventRsvpCounts counts;
  final EventRsvpStatus? selectedStatus;
  final List<String> constraintLabels;
  final VoidCallback onTap;
  final bool featured;
  final bool goingEnabled;
  final bool busy;
  final ValueChanged<EventRsvpStatus>? onRsvpChanged;

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMM').format(event.date).toUpperCase();
    final day = DateFormat('d').format(event.date);
    final when =
        '${DateFormat('EEE, MMM d').format(event.date)} · ${formatAlumniEventTimeRange(event.startTime, event.endTime)}';
    final status = deriveEventDisplayStatus(event);
    final isTodayEmphasis =
        status == EventDisplayStatus.today ||
        status == EventDisplayStatus.ongoing;

    final radius = BorderRadius.circular(PortalTheme.radius2xl);

    // Border is a foreground layer so the cover image can't paint over it at
    // the rounded top corners.
    return Align(
      alignment: Alignment.topCenter,
      widthFactor: 1,
      heightFactor: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: isTodayEmphasis
              ? [
                  BoxShadow(
                    color: PortalTheme.gold.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : PortalTheme.cardShadow,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: isTodayEmphasis
                ? PortalTheme.gold.withValues(alpha: 0.85)
                : PortalTheme.border.withValues(alpha: 0.7),
            width: isTodayEmphasis ? 1.6 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      ColoredBox(
                        color: PortalTheme.surfaceMuted,
                        child: EventCover(
                          event: event,
                          aspectRatio: EventCover.feedTeaserRatio,
                          borderRadius: 0,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 64,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x990A1128), Color(0x000A1128)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _FrostedDateBadge(month: month, day: day),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EventCategoryChip(category: event.category),
                        const SizedBox(height: 8),
                        Text(
                          event.theme,
                          style: PortalTheme.cardTitle.copyWith(
                            fontSize: 16,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        EventMetaRow(icon: Icons.schedule_outlined, text: when),
                        const SizedBox(height: 6),
                        EventMetaRow(
                          icon: Icons.place_outlined,
                          text: event.venue.trim().isEmpty
                              ? 'Venue TBA'
                              : event.venue,
                        ),
                        const SizedBox(height: 6),
                        EventMetaRow(
                          icon: Icons.groups_outlined,
                          text: '${counts.going} Going',
                        ),
                        EventSeatsLine(event: event, goingCount: counts.going),
                        if (constraintLabels.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          EventConstraintLabels(labels: constraintLabels),
                        ],
                        if (onRsvpChanged != null) ...[
                          const SizedBox(height: 12),
                          IgnorePointer(
                            ignoring: busy,
                            child: Opacity(
                              opacity: busy ? 0.55 : 1,
                              child: EventRsvpBar(
                                compact: true,
                                selected: selectedStatus,
                                goingEnabled: goingEnabled,
                                onChanged: onRsvpChanged!,
                              ),
                            ),
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

class _FrostedDateBadge extends StatelessWidget {
  const _FrostedDateBadge({required this.month, required this.day});

  final String month;
  final String day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: PortalTheme.softShadow,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text(
            month,
            style: PortalTheme.caption.copyWith(
              color: PortalTheme.navy,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              fontSize: 10,
            ),
          ),
          Text(
            day,
            style: PortalTheme.cardTitle.copyWith(
              fontSize: 18,
              height: 1.1,
              color: PortalTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}
