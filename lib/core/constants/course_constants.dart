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

  /// Full program titles (and light variants) → canonical code.
  /// Keys are produced by [_aliasKey] (uppercase, punctuation stripped,
  /// spaces collapsed).
  static const Map<String, String> _fullNameAliases = {
    // BSIT
    'BACHELOR OF SCIENCE IN INFORMATION TECHNOLOGY': 'BSIT',
    'BS INFORMATION TECHNOLOGY': 'BSIT',
    'BACHELOR OF SCIENCE IN IT': 'BSIT',
    // BFPT (official campus wording)
    'BACHELOR IN FOOD PROCESSING AND TECHNOLOGY': 'BFPT',
    'BACHELOR OF FOOD PROCESSING AND TECHNOLOGY': 'BFPT',
    // BTLED majors
    'BACHELOR OF TECHNOLOGY AND LIVELIHOOD EDUCATION MAJOR IN INDUSTRIAL ARTS':
        'BTLED-IA',
    'BACHELOR OF TECHNOLOGY AND LIVELIHOOD EDUCATION MAJOR IN INFORMATION AND COMMUNICATION TECHNOLOGY':
        'BTLED-ICT',
    'BACHELOR OF TECHNOLOGY AND LIVELIHOOD EDUCATION MAJOR IN HOME ECONOMICS':
        'BTLED-HE',
    'BTLED MAJOR IN INDUSTRIAL ARTS': 'BTLED-IA',
    'BTLED MAJOR IN INFORMATION AND COMMUNICATION TECHNOLOGY': 'BTLED-ICT',
    'BTLED MAJOR IN HOME ECONOMICS': 'BTLED-HE',
  };

  /// Collapse punctuation/dashes and whitespace so import cells with
  /// inconsistent spacing or "Major in" capitalization still match.
  static String _aliasKey(String raw) {
    final upper = raw.toUpperCase();
    final buf = StringBuffer();
    var prevSpace = false;
    for (final unit in upper.runes) {
      final ch = String.fromCharCode(unit);
      final isLetterOrDigit =
          (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x30 && unit <= 0x39);
      if (isLetterOrDigit) {
        buf.write(ch);
        prevSpace = false;
      } else if (!prevSpace && buf.isNotEmpty) {
        buf.write(' ');
        prevSpace = true;
      }
    }
    return buf.toString().trim();
  }

  /// Returns the canonical course code when [raw] is a known code, typo, or
  /// official full program name; otherwise the trimmed input (caller should
  /// check [isValid]).
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final upper = trimmed.toUpperCase();
    for (final c in courses) {
      if (c.toUpperCase() == upper) return c;
    }

    // Legacy / common typos for codes
    switch (upper) {
      case 'BTLED HE':
      case 'BTLED- HE':
        return 'BTLED-HE';
      case 'BTLED IA':
        return 'BTLED-IA';
      case 'BTLED ICT':
        return 'BTLED-ICT';
    }

    final alias = _fullNameAliases[_aliasKey(trimmed)];
    if (alias != null) return alias;

    return trimmed;
  }

  static bool isValid(String? course) =>
      course != null && courses.contains(course);
}
