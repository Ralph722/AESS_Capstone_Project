/// Official roster / registration program codes (USTP Oroquieta).
class CourseConstants {
  CourseConstants._();

  static const List<String> courses = [
    'BSIT',
    'BFPT',
    'BTLED-IA',
    'BTLED-ICT',
    'BTLED-HE',
  ];

  static String? normalize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final upper = trimmed.toUpperCase();
    for (final c in courses) {
      if (c.toUpperCase() == upper) return c;
    }

    // Legacy / common typos
    switch (upper) {
      case 'BTLED HE':
      case 'BTLED- HE':
        return 'BTLED-HE';
      case 'BTLED IA':
        return 'BTLED-IA';
      case 'BTLED ICT':
        return 'BTLED-ICT';
      default:
        return trimmed;
    }
  }

  static bool isValid(String? course) =>
      course != null && courses.contains(course);
}
