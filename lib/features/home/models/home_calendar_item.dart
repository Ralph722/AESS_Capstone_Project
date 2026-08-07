/// A single dated item shown on the Home important-dates calendar.
enum HomeCalendarItemKind { event, survey, tracer, job }

class HomeCalendarItem {
  const HomeCalendarItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
  });

  final HomeCalendarItemKind kind;
  final String id;
  final String title;
  final String subtitle;
  final DateTime date;

  DateTime get dayKey =>
      DateTime(date.year, date.month, date.day);
}
