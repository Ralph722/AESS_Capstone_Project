import 'package:flutter/services.dart';

/// Codes Supabase Auth emails for sign-up and password reset.
///
/// Their length is the hosted "Email OTP Length" setting (6–10 digits), which
/// can differ from `otp_length` in `supabase/config.toml`, so any length in
/// that range is accepted.
class EmailCodePolicy {
  const EmailCodePolicy._();

  static const int minLength = 6;
  static const int maxLength = 10;

  static final RegExp _pattern = RegExp(r'^\d{6,10}$');

  /// Digits only, so a pasted "123 456" or "123-456" still fits.
  static final List<TextInputFormatter> inputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(maxLength),
  ];

  /// Strips spaces and dashes users copy along with the code.
  static String normalize(String code) => code.replaceAll(RegExp(r'\D'), '');

  /// Returns an error message, or null when [code] looks like a valid code.
  static String? validate(String? code) {
    if (code == null || !_pattern.hasMatch(normalize(code))) {
      return 'Enter the full code from the email';
    }
    return null;
  }
}
