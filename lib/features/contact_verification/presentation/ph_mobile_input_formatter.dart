import 'package:flutter/services.dart';

/// Philippine mobile input: digits only, max 11, displayed like GCash
/// (`0917 123 4567`).
class PhMobileInputFormatter extends TextInputFormatter {
  const PhMobileInputFormatter();

  /// Digits-only form used for storage / SMS (e.g. `09171234567`).
  static String digitsOnly(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '');

  /// GCash-style grouping for up to 11 digits: `09XX XXX XXXX`.
  static String formatDisplay(String? value) {
    final d = digitsOnly(value);
    if (d.isEmpty) return '';
    final clipped = d.length > 11 ? d.substring(0, 11) : d;
    final b = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 4 || i == 7) b.write(' ');
      b.write(clipped[i]);
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = digitsOnly(newValue.text);
    final clipped = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = formatDisplay(clipped);

    // Keep the caret at the end of the typed digit run for simple UX.
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
