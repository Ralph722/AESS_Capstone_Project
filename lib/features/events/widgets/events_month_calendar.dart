import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/events/models/event_model.dart';

/// Simple month calendar highlighting days that have events.
class EventsMonthCalendar extends StatelessWidget {
  const EventsMonthCalendar({
    super.key,
    required this.month,
    required this.events,
    required this.onMonthChanged,
    required this.onDaySelected,
    this.selectedDay,
  });

  final DateTime month;
  final List<AlumniEvent> events;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? selectedDay;

  static const _navy = Color(0xFF090A4F);
  static const _gold = Color(0xFFFFD700);

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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month - 1, 1),
                ),
                icon: const Icon(Icons.chevron_left, color: _navy),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month + 1, 1),
                ),
                icon: const Icon(Icons.chevron_right, color: _navy),
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
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
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
                  final isSelected = selectedDay != null &&
                      selectedDay!.year == day.year &&
                      selectedDay!.month == day.month &&
                      selectedDay!.day == day.day;
                  final isToday = _isSameDay(day, DateTime.now());

                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onDaySelected(day),
                      child: Container(
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _navy
                              : (hasEvents
                                  ? _gold.withValues(alpha: 0.18)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !isSelected
                              ? Border.all(color: _navy, width: 1.2)
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
                                color: isSelected
                                    ? Colors.white
                                    : _navy,
                              ),
                            ),
                            if (hasEvents)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? _gold : _navy,
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
          if (selectedDay != null) ...[
            const Divider(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEEE, MMM d').format(selectedDay!),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _navy,
                  fontSize: 13,
                ),
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
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
