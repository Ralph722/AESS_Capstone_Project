/// Canonical event categories for filtering and badges.
abstract final class EventCategoryConstants {
  static const String career = 'Career';
  static const String workshop = 'Workshop';
  static const String seminar = 'Seminar';
  static const String conference = 'Conference';
  static const String training = 'Training';
  static const String homecoming = 'Homecoming';
  static const String generalAssembly = 'General Assembly';
  static const String sports = 'Sports';
  static const String volunteer = 'Volunteer';
  static const String recognition = 'Recognition';
  static const String other = 'Other';

  static const List<String> all = [
    career,
    workshop,
    seminar,
    conference,
    training,
    homecoming,
    generalAssembly,
    sports,
    volunteer,
    recognition,
    other,
  ];

  static String normalize(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return other;
    for (final c in all) {
      if (c.toLowerCase() == v.toLowerCase()) return c;
    }
    return other;
  }
}
