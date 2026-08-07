/// Career board categories for filtering and badges.
class JobCategoryConstants {
  JobCategoryConstants._();

  static const String others = 'Others';

  static const List<String> all = [
    'IT',
    'Education',
    'Business',
    'Engineering',
    'Healthcare',
    'Government',
    'Freelance',
    'Internship',
    others,
  ];

  static const List<String> jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
    'Temporary',
  ];

  static const List<String> experienceLevels = [
    'Entry-level',
    'Mid-level',
    'Senior',
    'Executive',
  ];

  static String normalize(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return others;
    for (final c in all) {
      if (c.toLowerCase() == t.toLowerCase()) return c;
    }
    return others;
  }
}
