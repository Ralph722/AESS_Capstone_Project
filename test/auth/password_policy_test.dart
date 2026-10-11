import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/auth/data/password_policy.dart';

void main() {
  group('PasswordPolicy.validate', () {
    test('rejects empty and short passwords', () {
      expect(PasswordPolicy.validate(null), 'At least 8 characters');
      expect(PasswordPolicy.validate(''), 'At least 8 characters');
      expect(PasswordPolicy.validate('abc1234'), 'At least 8 characters');
    });

    test('requires both letters and numbers', () {
      expect(
        PasswordPolicy.validate('abcdefgh'),
        'Use both letters and numbers',
      );
      expect(
        PasswordPolicy.validate('12345678'),
        'Use both letters and numbers',
      );
      expect(
        PasswordPolicy.validate('!!!!!!!!'),
        'Use both letters and numbers',
      );
    });

    test('accepts passwords that meet the policy', () {
      expect(PasswordPolicy.validate('abcdefg1'), isNull);
      expect(PasswordPolicy.validate('Password2026!'), isNull);
    });
  });

  group('PasswordPolicy.strength', () {
    test('passwords failing the policy are weak', () {
      expect(PasswordPolicy.strength('abc'), PasswordStrength.weak);
      expect(PasswordPolicy.strength('abcdefghijkl'), PasswordStrength.weak);
    });

    test('minimum valid password is fair', () {
      expect(PasswordPolicy.strength('abcdefg1'), PasswordStrength.fair);
    });

    test('mixed case or extra length is good', () {
      expect(PasswordPolicy.strength('Abcdefg1'), PasswordStrength.good);
      expect(PasswordPolicy.strength('abcdefghijk1'), PasswordStrength.good);
    });

    test('long, mixed-case password with a symbol is strong', () {
      expect(PasswordPolicy.strength('Abcdefghijk1!'), PasswordStrength.strong);
    });
  });
}
