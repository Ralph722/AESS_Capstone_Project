import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Simple month calendar highlighting days that have events.
class EventsMonthCalendar extends StatelessWidget {
  const EventsMonthCalendar({
    super.key,
    required this.month,
    required this.events,
    required this.onMonthChanged,
    required this.onDaySelected,
    this.selectedDay,
    this.adminSurface = false,
    this.showSelectedSummary = true,
  });

  final DateTime month;
  final List<AlumniEvent> events;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? selectedDay;
  final bool adminSurface;
  final bool showSelectedSummary;

  Map<DateTime, List<AlumniEvent>> get _byDay {
    final map = <DateTime, List<AlumniEvent>>{};
    for (final e in events) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday=1 ... Sunday=7 → convert to 0-based Monday-first index
    final startWeekday = (firstOfMonth.weekday + 6) % 7;
    final totalCells = startWeekday + daysInMonth;
    final rows = ((totalCells + 6) / 7).floor();
    final byDay = _byDay;

    final primary = adminSurface ? AdminColors.primary : PortalTheme.navy;
    final accent = adminSurface ? AdminColors.accent : PortalTheme.gold;
    final textPrimary = adminSurface ? AdminColors.textPrimary : PortalTheme.navy;
    final textSecondary =
        adminSurface ? AdminColors.textSecondary : PortalTheme.textSecondary;
    final borderColor = adminSurface
        ? AdminColors.border
        : PortalTheme.border.withValues(alpha: 0.75);

    return Container(
      decoration: adminSurface
          ? AdminSurfaces.card()
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
              border: Border.all(color: borderColor),
              boxShadow: PortalTheme.softShadow,
            ),
      padding: EdgeInsets.fromLTRB(
        adminSurface ? 16 : 12,
        adminSurface ? 14 : 12,
        adminSurface ? 16 : 12,
        14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1, 1)),
                icon: Icon(Icons.chevron_left, color: primary),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  textAlign: TextAlign.center,
                  style: adminSurface
                      ? AdminText.sectionTitle.copyWith(fontSize: 15.5)
                      : PortalTheme.sectionTitle.copyWith(fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1, 1)),
                icon: Icon(Icons.chevron_right, color: primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: (adminSurface
                                ? AdminText.caption
                                : PortalTheme.caption)
                            .copyWith(
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: List.generate(7, (c) {
                  final cell = r * 7 + c;
                  final dayNum = cell - startWeekday + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 44));
                  }
                  final day = DateTime(month.year, month.month, dayNum);
                  final dayEvents = byDay[day] ?? const <AlumniEvent>[];
                  final hasEvents = dayEvents.isNotEmpty;
                  final isSelected =
                      selectedDay != null &&
                      selectedDay!.year == day.year &&
                      selectedDay!.month == day.month &&
                      selectedDay!.day == day.day;
                  final isToday = _isSameDay(day, DateTime.now());
                  final cellRadius = adminSurface
                      ? AdminSurfaces.radiusSm
                      : 12.0;

                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(cellRadius),
                      onTap: () => onDaySelected(day),
                      child: Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primary
                              : (hasEvents
                                    ? accent.withValues(alpha: 0.18)
                                    : Colors.transparent),
                          borderRadius: BorderRadius.circular(cellRadius),
                          border: isToday && !isSelected
                              ? Border.all(color: primary, width: 1.2)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : textPrimary,
                              ),
                            ),
                            if (hasEvents)
                              adminSurface && dayEvents.length > 1
                                  ? Container(
                                      margin: const EdgeInsets.only(top: 1),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 0.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accent
                                            : primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${dayEvents.length}',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? AdminColors.primary
                                              : primary,
                                          height: 1.1,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected ? accent : primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          if (adminSurface) ...[
            const SizedBox(height: 6),
            const Divider(height: 1, color: AdminColors.border),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              alignment: WrapAlignment.start,
              children: [
                _legendItem(
                  color: accent.withValues(alpha: 0.25),
                  dotColor: primary,
                  label: 'Has events',
                ),
                _legendItem(
                  color: Colors.transparent,
                  borderColor: primary,
                  label: 'Today',
                ),
                _legendItem(
                  color: primary,
                  dotColor: accent,
                  label: 'Selected',
                ),
              ],
            ),
          ],
          if (showSelectedSummary && selectedDay != null) ...[
            Divider(height: 16, color: borderColor),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEEE, MMM d').format(selectedDay!),
                style: (adminSurface
                        ? AdminText.sectionTitle
                        : PortalTheme.cardTitle)
                    .copyWith(color: primary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            if ((byDay[DateTime(
                      selectedDay!.year,
                      selectedDay!.month,
                      selectedDay!.day,
                    )] ??
                    const <AlumniEvent>[])
                .isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No events on this day',
                  style: PortalTheme.bodySecondary.copyWith(fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _legendItem({
    required Color color,
    Color? borderColor,
    Color? dotColor,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor ?? AdminColors.border,
              width: borderColor != null ? 1.2 : 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: dotColor != null
              ? Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: AdminText.caption),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
