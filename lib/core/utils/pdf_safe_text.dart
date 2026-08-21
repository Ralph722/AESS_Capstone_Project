/// Helpers for `package:pdf` text.
///
/// The default PDF fonts (Helvetica / WinAnsi) cannot render many Unicode
/// glyphs (em dashes, smart quotes, bullets, arrows, etc.). Those show up as
/// empty boxes or "X" placeholders in exported PDFs.
abstract final class PdfSafeText {
  PdfSafeText._();

  /// ASCII / Latin-1-safe string for Helvetica-based PDF rendering.
  static String sanitize(String? input) {
    if (input == null || input.isEmpty) return '';

    var s = input
        // Dashes / minus
        .replaceAll('\u2014', '-') // em dash —
        .replaceAll('\u2013', '-') // en dash –
        .replaceAll('\u2212', '-') // minus −
        .replaceAll('\u2012', '-') // figure dash
        .replaceAll('\u2015', '-') // horizontal bar
        // Quotes
        .replaceAll('\u2018', "'") // ‘
        .replaceAll('\u2019', "'") // ’
        .replaceAll('\u201A', "'")
        .replaceAll('\u201B', "'")
        .replaceAll('\u201C', '"') // “
        .replaceAll('\u201D', '"') // ”
        .replaceAll('\u201E', '"')
        .replaceAll('\u00AB', '"') // «
        .replaceAll('\u00BB', '"') // »
        // Dots / ellipsis / bullets
        .replaceAll('\u2026', '...') // …
        .replaceAll('\u00B7', ' | ') // · middle dot
        .replaceAll('\u2022', '-') // •
        .replaceAll('\u2023', '-')
        .replaceAll('\u25E6', '-')
        .replaceAll('\u2043', '-')
        // Spaces
        .replaceAll('\u00A0', ' ') // nbsp
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\u2008', ' ')
        .replaceAll('\u2009', ' ')
        .replaceAll('\u200A', ' ')
        .replaceAll('\u200B', '') // zero-width
        .replaceAll('\uFEFF', '')
        // Arrows / relations
        .replaceAll('\u2192', '->')
        .replaceAll('\u2190', '<-')
        .replaceAll('\u2194', '<->')
        .replaceAll('\u21D2', '=>')
        .replaceAll('\u2264', '<=')
        .replaceAll('\u2265', '>=')
        .replaceAll('\u2260', '!=')
        .replaceAll('\u00D7', 'x')
        .replaceAll('\u00F7', '/')
        // Check marks / boxes
        .replaceAll('\u2713', '[x]')
        .replaceAll('\u2714', '[x]')
        .replaceAll('\u2610', '[ ]')
        .replaceAll('\u2611', '[x]')
        .replaceAll('\u2612', '[x]')
        // Misc symbols sometimes returned by AI
        .replaceAll('\u00A9', '(c)')
        .replaceAll('\u00AE', '(R)')
        .replaceAll('\u2122', '(TM)');

    // Drop remaining non-Latin-1 code points Helvetica cannot encode.
    final buf = StringBuffer();
    for (final unit in s.codeUnits) {
      if (unit == 0x09 || unit == 0x0A || unit == 0x0D) {
        buf.writeCharCode(unit);
      } else if (unit >= 0x20 && unit <= 0x7E) {
        buf.writeCharCode(unit);
      } else if (unit >= 0xA0 && unit <= 0xFF) {
        buf.writeCharCode(unit);
      } else {
        buf.write('?');
      }
    }
    return buf.toString();
  }

  /// Sanitize every cell in a table row.
  static List<String> sanitizeRow(List<String> row) =>
      [for (final cell in row) sanitize(cell)];

  /// Sanitize a list of rows.
  static List<List<String>> sanitizeRows(List<List<String>> rows) =>
      [for (final row in rows) sanitizeRow(row)];
}
