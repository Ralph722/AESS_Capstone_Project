enum PasswordStrength {
  weak('Weak'),
  fair('Fair'),
  good('Good'),
  strong('Strong');

  const PasswordStrength(this.label);

  final String label;
}

/// AESS password rules. Keep in sync with `minimum_password_length` and
/// `password_requirements` under `[auth]` in `supabase/config.toml`.
class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;

  static const String requirementText =
      'At least 8 characters, with letters and numbers';

  static final RegExp _letter = RegExp(r'[A-Za-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9]');

  /// Returns an error message, or null when [password] meets the policy.
  static String? validate(String? password) {
    if (password == null || password.length < minLength) {
      return 'At least 8 characters';
    }
    if (!_letter.hasMatch(password) || !_digit.hasMatch(password)) {
      return 'Use both letters and numbers';
    }
    return null;
  }

  /// Advisory only; [validate] decides whether a password is accepted.
  static PasswordStrength strength(String password) {
    if (validate(password) != null) return PasswordStrength.weak;
    var points = 0;
    if (password.length >= 12) points++;
    if (password.length >= 16) points++;
    if (_upper.hasMatch(password) && _lower.hasMatch(password)) points++;
    if (_symbol.hasMatch(password)) points++;
    if (points >= 3) return PasswordStrength.strong;
    if (points >= 1) return PasswordStrength.good;
    return PasswordStrength.fair;
  }
}
