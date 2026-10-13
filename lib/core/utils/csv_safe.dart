/// CSV cells for files that admins open in Excel or Google Sheets.
abstract final class CsvSafe {
  static const _formulaStart = '=+-@\t\r';
  static final _dashesOnly = RegExp(r'^[-\s]+$');

  /// Quotes [value] when needed, and puts `'` in front of text a spreadsheet
  /// would run as a formula (`=HYPERLINK(...)`, `@SUM(...)`). Plain numbers
  /// such as `-0.5` and "-" placeholders stay as they are.
  static String cell(String value) {
    var s = value;
    if (s.isNotEmpty &&
        _formulaStart.contains(s[0]) &&
        num.tryParse(s.trim()) == null &&
        !_dashesOnly.hasMatch(s)) {
      s = "'$s";
    }
    if (s.contains(RegExp('[",\r\n]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }
}
