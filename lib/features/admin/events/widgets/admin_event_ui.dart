import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/events/models/event_display_status.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';
import 'package:alumni_system/features/events/widgets/event_cover.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Visual chrome for admin Events — reuses [AdminDirectoryTheme] (no second navy).
abstract final class AdminEventTheme {
  static const primary = AdminDirectoryTheme.primary;
  static const gold = AdminDirectoryTheme.gold;
  static const background = AdminDirectoryTheme.background;
  static const surface = AdminDirectoryTheme.surface;
  static const card = AdminDirectoryTheme.card;
  static const border = AdminDirectoryTheme.border;
  static const textPrimary = AdminDirectoryTheme.textPrimary;
  static const textSecondary = AdminDirectoryTheme.textSecondary;
  static const textMuted = AdminDirectoryTheme.textMuted;
  static const success = AdminDirectoryTheme.success;
  static const successBg = AdminDirectoryTheme.successBg;
  static const warning = AdminDirectoryTheme.warning;
  static const warningBg = AdminDirectoryTheme.warningBg;
  static const info = AdminDirectoryTheme.info;
  static const infoBg = AdminDirectoryTheme.infoBg;
  static const danger = AdminDirectoryTheme.danger;
  static const dangerBg = AdminDirectoryTheme.dangerBg;

  static const space1 = AdminDirectoryTheme.space1;
  static const space2 = AdminDirectoryTheme.space2;
  static const space3 = AdminDirectoryTheme.space3;
  static const space4 = AdminDirectoryTheme.space4;
  static const sectionGap = AdminDensity.sectionGap;
  static const cardPadding = AdminDensity.cardPadding;
  static const gridGap = AdminDensity.gridGap;
  static const listItemGap = AdminDensity.listItemGap;
  static const buttonHeight = AdminDirectoryTheme.buttonHeight;
  static const toolbarControlHeight = AdminDirectoryTheme.toolbarControlHeight;
  static const radiusSm = AdminDirectoryTheme.radiusSm;
  static const radiusMd = AdminDirectoryTheme.radiusMd;
  static const radiusLg = AdminDirectoryTheme.radiusLg;

  static BoxDecoration surfaceCard({bool hovered = false}) =>
      AdminDirectoryTheme.surfaceCard(hovered: hovered);
}

ButtonStyle eventOutlinedButtonStyle() => AdminButtonStyles.outlined();

ButtonStyle eventFilledButtonStyle({Color? background}) =>
    AdminButtonStyles.filled(background: background);

/// Service messages are kept concise; technical exceptions fall back to [fallback].
String eventFriendlyError(Object error, String fallback) {
  var text = '$error';
  while (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  text = text.trim();
  final technical =
      text.isEmpty ||
      text.startsWith('Error ') ||
      text.contains('Exception') ||
      text.length > 160;
  return technical ? fallback : text;
}

/// Brand-aligned category badge for admin Events surfaces (avoids legacy hex).
class AdminEventCategoryBadge extends StatelessWidget {
  const AdminEventCategoryBadge({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminColors.primaryTint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.primary.withValues(alpha: 0.16)),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: AdminColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Dense 34px date-range control sized to sit inline inside [AdminSaaSToolbar].
class AdminEventDateRangeChip extends StatelessWidget {
  const AdminEventDateRangeChip({
    super.key,
    required this.from,
    required this.to,
    required this.onTap,
    this.onClear,
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  bool get _active => from != null || to != null;

  String get _label {
    if (from != null && to != null) {
      return DirectoryDateTimePickers.formatDateRange(from!, to!);
    }
    if (from != null) {
      return 'From ${DateFormat('MMM d').format(from!)}';
    }
    if (to != null) {
      return 'Until ${DateFormat('MMM d').format(to!)}';
    }
    return 'Date range';
  }

  @override
  Widget build(BuildContext context) {
    final fg = _active ? AdminColors.primary : AdminColors.textSecondary;
    return Material(
      color: _active ? AdminColors.infoBg : AdminColors.background,
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        child: Container(
          height: 34,
          padding: EdgeInsets.only(left: 10, right: _active && onClear != null ? 4 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            border: Border.all(
              color: _active
                  ? AdminColors.primary.withValues(alpha: 0.35)
                  : AdminColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.date_range_rounded, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                _label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _active ? FontWeight.w600 : FontWeight.w500,
                  color: _active ? AdminColors.primary : AdminColors.textPrimary,
                ),
              ),
              if (_active && onClear != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Clear date range',
                  child: InkWell(
                    onTap: onClear,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: AdminColors.primary,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AdminColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Event row menu item with leading icon and consistent destructive tone.
PopupMenuItem<String> adminEventMenuItem({
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

/// Calendar day delta between today and [event.date] (`0` = today, `-1` = past).
int eventDaysUntil(AlumniEvent event, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final eventDay = DateTime(event.date.year, event.date.month, event.date.day);
  return eventDay.difference(today).inDays;
}

/// SaaS-consistent event lifecycle status pill derived from [deriveEventDisplayStatus].
class AdminEventStatusBadge extends StatelessWidget {
  const AdminEventStatusBadge({
    super.key,
    required this.event,
    this.dense = true,
  });

  final AlumniEvent event;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final status = deriveEventDisplayStatus(event);
    final tone = switch (status) {
      EventDisplayStatus.upcoming => AdminBadgeTone.info,
      EventDisplayStatus.today => AdminBadgeTone.warning,
      EventDisplayStatus.ongoing => AdminBadgeTone.success,
      EventDisplayStatus.finished => AdminBadgeTone.neutral,
      EventDisplayStatus.cancelled => AdminBadgeTone.danger,
      EventDisplayStatus.archived => AdminBadgeTone.neutral,
    };
    return AdminBadge(
      label: status.label,
      tone: tone,
      dot:
          status == EventDisplayStatus.today ||
          status == EventDisplayStatus.ongoing,
      dense: dense,
    );
  }
}

/// Compact countdown badge for events within the next 7 days.
class AdminEventCountdownBadge extends StatelessWidget {
  const AdminEventCountdownBadge({super.key, required this.daysUntil});

  final int daysUntil;

  String get _label => switch (daysUntil) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => 'In $daysUntil days',
  };

  @override
  Widget build(BuildContext context) {
    final urgent = daysUntil <= 1;
    return AdminBadge(
      label: _label,
      tone: urgent ? AdminBadgeTone.danger : AdminBadgeTone.warning,
      icon: Icons.schedule_rounded,
      dense: true,
    );
  }
}

/// Multi-zone SaaS event row card (desktop zones ≥ 900px; stacked below).
class AdminEventListCard extends StatefulWidget {
  const AdminEventListCard({
    super.key,
    required this.event,
    required this.counts,
    required this.menuItems,
    required this.onMenuSelected,
    required this.onOpen,
    this.compact = false,
  });

  static const double zoneLayoutMinWidth = 900.0;

  final AlumniEvent event;
  final EventRsvpCounts counts;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onOpen;
  final bool compact;

  @override
  State<AdminEventListCard> createState() => _AdminEventListCardState();
}

class _AdminEventListCardState extends State<AdminEventListCard> {
  bool _hovered = false;

  static const _zoneLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AdminColors.textMuted,
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

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final daysUntil = eventDaysUntil(e);
    final showCountdown =
        !e.cancelled &&
        e.status != 'Archived' &&
        daysUntil >= 0 &&
        daysUntil <= 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _hovered ? AdminColors.rowHover : AdminColors.card,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
            border: Border.all(color: AdminColors.border),
            boxShadow: _hovered
                ? AdminSurfaces.cardShadowHover
                : AdminSurfaces.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              button: true,
              label: 'Open event details for ${e.theme}',
              child: InkWell(
                onTap: widget.onOpen,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        !widget.compact &&
                        constraints.maxWidth >=
                            AdminEventListCard.zoneLayoutMinWidth;
                    return wide
                        ? _buildZones(e, daysUntil, showCountdown)
                        : _buildStacked(
                            e,
                            daysUntil,
                            showCountdown,
                            showThumb: constraints.maxWidth >= 380,
                          );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZones(AlumniEvent e, int daysUntil, bool showCountdown) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildCover(e, width: 92, height: 62),
          const SizedBox(width: 14),
          Expanded(child: _buildIdentity(e, daysUntil, showCountdown)),
          const SizedBox(width: 20),
          SizedBox(width: 210, child: _buildAttendanceZone(e)),
          const SizedBox(width: 8),
          _buildMenu(e),
        ],
      ),
    );
  }

  Widget _buildStacked(
    AlumniEvent e,
    int daysUntil,
    bool showCountdown, {
    required bool showThumb,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 12 : 14,
        widget.compact ? 10 : 12,
        6,
        widget.compact ? 10 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showThumb) ...[
            _buildCover(
              e,
              width: widget.compact ? 64 : 78,
              height: widget.compact ? 48 : 56,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentity(e, daysUntil, showCountdown),
                const SizedBox(height: 6),
                _buildCompactAttendanceLine(e),
              ],
            ),
          ),
          _buildMenu(e),
        ],
      ),
    );
  }

  Widget _buildCover(
    AlumniEvent e, {
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      child: EventCover(
        event: e,
        height: height,
        borderRadius: AdminSurfaces.radiusSm,
        placeholderColors: const [AdminColors.primary, AdminColors.secondary],
      ),
    );
  }

  Widget _buildIdentity(AlumniEvent e, int daysUntil, bool showCountdown) {
    final title = e.theme.trim().isEmpty ? 'Untitled event' : e.theme.trim();
    final dateStr = DateFormat('MMM d, yyyy').format(e.date);
    final venueStr = e.venue.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.3,
            color: AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminEventStatusBadge(event: e),
            AdminEventCategoryBadge(category: e.category),
            if (showCountdown) AdminEventCountdownBadge(daysUntil: daysUntil),
            if (e.batchYear.trim().isNotEmpty)
              AdminBadge.neutral(
                label: 'Batch ${e.batchYear.trim()}',
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _metaItem(
              Icons.calendar_today_outlined,
              '$dateStr · ${e.startTime}–${e.endTime}',
            ),
            if (venueStr.isNotEmpty)
              _metaItem(
                e.hasVenuePin
                    ? Icons.pin_drop_outlined
                    : Icons.location_on_outlined,
                venueStr,
                iconColor: e.hasVenuePin ? AdminColors.success : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _metaItem(IconData icon, String text, {Color? iconColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor ?? AdminColors.textMuted),
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

  Widget _buildAttendanceZone(AlumniEvent e) {
    final c = widget.counts;
    final cap = e.capacity;
    final hasCap = cap != null && cap > 0;
    final left = e.seatsRemaining(c.going);
    final full = left != null && left <= 0;
    final progress = hasCap ? (c.going / cap).clamp(0.0, 1.0) : 0.0;
    final deadline = e.registrationDeadline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ATTENDANCE', style: _zoneLabel),
        const SizedBox(height: 4),
        if (hasCap) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${c.going} / $cap going', style: _zoneValue),
                TextSpan(
                  text: full ? ' · Full' : ' · $left left',
                  style: _secondary.copyWith(
                    color: full ? AdminColors.danger : AdminColors.textSecondary,
                    fontWeight: full ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AdminColors.surface,
                color: full ? AdminColors.danger : AdminColors.primary,
              ),
            ),
          ),
        ] else
          Text(
            c.notGoing > 0
                ? '${c.going} going · ${c.notGoing} declined'
                : '${c.going} going',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _zoneValue,
          ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 10,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _metaItem(Icons.forum_outlined, '${e.comments}'),
            _metaItem(Icons.visibility_outlined, '${e.viewsCount}'),
            if (deadline != null)
              _metaItem(
                Icons.timer_outlined,
                'Reg ${DateFormat('MMM d').format(deadline)}',
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactAttendanceLine(AlumniEvent e) {
    final c = widget.counts;
    final cap = e.capacity;
    final goingText = (cap != null && cap > 0)
        ? '${c.going}/$cap going'
        : '${c.going} going';
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _metaItem(
          Icons.check_circle_outline_rounded,
          goingText,
          iconColor: AdminColors.success,
        ),
        _metaItem(Icons.forum_outlined, '${e.comments}'),
        _metaItem(Icons.visibility_outlined, '${e.viewsCount}'),
      ],
    );
  }

  Widget _buildMenu(AlumniEvent e) {
    return PopupMenuButton<String>(
      tooltip: 'Actions for ${e.theme}',
      onSelected: widget.onMenuSelected,
      itemBuilder: (_) => widget.menuItems,
      color: AdminColors.card,
      elevation: 8,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
      ),
      icon: const Icon(Icons.more_vert, color: AdminColors.textMuted),
    );
  }
}
