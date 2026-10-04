import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Going / Not going actions. Only Going is limited by capacity/registration.
class EventRsvpBar extends StatelessWidget {
  const EventRsvpBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.goingEnabled = true,
    this.dense = false,
    this.expanded = false,
    this.compact = false,
  });

  final EventRsvpStatus? selected;
  final ValueChanged<EventRsvpStatus> onChanged;
  final bool enabled;

  /// When false, only the Going chip is disabled (e.g. capacity full / registration closed).
  final bool goingEnabled;
  final bool dense;

  /// When true, renders equal-width action buttons across the available width.
  final bool expanded;

  /// Compact feed-card buttons (slightly smaller).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visible = selected;
    final height = compact ? 38.0 : (dense ? 40.0 : 46.0);

    Widget button({
      required EventRsvpStatus status,
      required IconData outlineIcon,
      required IconData filledIcon,
    }) {
      return _RsvpActionButton(
        label: status.label,
        outlineIcon: outlineIcon,
        filledIcon: filledIcon,
        selected: visible == status,
        enabled:
            enabled &&
            (status != EventRsvpStatus.going ||
                goingEnabled ||
                visible == status),
        height: height,
        compact: compact || dense,
        onTap: () => onChanged(status),
      );
    }

    final going = button(
      status: EventRsvpStatus.going,
      outlineIcon: Icons.check_circle_outline_rounded,
      filledIcon: Icons.check_circle_rounded,
    );
    final notGoing = button(
      status: EventRsvpStatus.notGoing,
      outlineIcon: Icons.cancel_outlined,
      filledIcon: Icons.cancel_rounded,
    );

    if (expanded || compact) {
      return Row(
        children: [
          Expanded(child: going),
          SizedBox(width: compact ? 8 : 10),
          Expanded(child: notGoing),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(width: 118, child: going),
        SizedBox(width: 118, child: notGoing),
      ],
    );
  }
}

class _RsvpActionButton extends StatelessWidget {
  const _RsvpActionButton({
    required this.label,
    required this.outlineIcon,
    required this.filledIcon,
    required this.selected,
    required this.enabled,
    required this.height,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData outlineIcon;
  final IconData filledIcon;
  final bool selected;
  final bool enabled;
  final double height;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? PortalTheme.textMuted
        : (selected ? PortalTheme.navy : PortalTheme.textPrimary);
    final bg = !enabled
        ? PortalTheme.surfaceMuted
        : (selected ? PortalTheme.navy.withValues(alpha: 0.08) : Colors.white);
    final border = !enabled
        ? PortalTheme.border
        : (selected
              ? PortalTheme.navy.withValues(alpha: 0.55)
              : PortalTheme.borderStrong);

    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
              border: Border.all(color: border, width: selected ? 1.6 : 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? filledIcon : outlineIcon,
                  size: compact ? 16 : 18,
                  color: fg,
                ),
                SizedBox(width: compact ? 5 : 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 13,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
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

/// Counts line: "✓ 1 Going" (alumni) or "✓ 1 Going · ✕ 2 Not going" (admin).
class EventRsvpCountRow extends StatelessWidget {
  const EventRsvpCountRow({
    super.key,
    required this.counts,
    this.capacity,
    this.compact = false,
    this.includeNotGoing = false,
  });

  final EventRsvpCounts counts;
  final int? capacity;
  final bool compact;

  /// Admin UIs show Not going totals; the alumni UI does not.
  final bool includeNotGoing;

  @override
  Widget build(BuildContext context) {
    final seats = capacity != null && capacity! > 0
        ? (capacity! - counts.going).clamp(0, capacity!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventRsvpCountsLine(
          counts: counts,
          compact: compact,
          includeNotGoing: includeNotGoing,
        ),
        if (seats != null) ...[
          SizedBox(height: compact ? 4 : 6),
          Text(
            seats == 0 ? 'No seats left' : '$seats of $capacity seats left',
            style: PortalTheme.caption.copyWith(
              color: seats == 0
                  ? PortalTheme.danger
                  : PortalTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ],
    );
  }
}

class EventRsvpCountsLine extends StatelessWidget {
  const EventRsvpCountsLine({
    super.key,
    required this.counts,
    this.compact = false,
    this.includeNotGoing = false,
  });

  final EventRsvpCounts counts;
  final bool compact;
  final bool includeNotGoing;

  @override
  Widget build(BuildContext context) {
    final style = PortalTheme.caption.copyWith(
      color: PortalTheme.navy.withValues(alpha: 0.85),
      fontWeight: FontWeight.w700,
      fontSize: compact ? 11.5 : 12.5,
      height: 1.2,
    );
    final iconSize = compact ? 14.0 : 15.0;

    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: iconSize,
          color: PortalTheme.navyMid,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: '${counts.going} Going'),
                if (includeNotGoing) ...[
                  TextSpan(
                    text: '  ·  ',
                    style: style.copyWith(color: PortalTheme.textMuted),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.cancel_rounded,
                        size: iconSize,
                        color: PortalTheme.navyMid,
                      ),
                    ),
                  ),
                  TextSpan(text: '${counts.notGoing} Not going'),
                ],
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

Future<void> openVenueInMaps(
  String venue, {
  double? latitude,
  double? longitude,
}) async {
  final hasPin =
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite;
  if (hasPin) {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  final query = Uri.encodeComponent(venue.trim());
  if (query.isEmpty) return;
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$query',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openEventVenueInMaps(AlumniEvent event) {
  return openVenueInMaps(
    event.venue,
    latitude: event.venueLatitude,
    longitude: event.venueLongitude,
  );
}
