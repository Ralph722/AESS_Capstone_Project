import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _email = ContactChannel.email;
const _mobile = ContactChannel.mobile;

void main() {
  group('ContactNormalizer (same rules as contact_normalize_target)', () {
    test('email is trimmed and lower-cased; invalid ones are rejected', () {
      expect(
        ContactNormalizer.normalize(_email, '  Ana@Gmail.COM '),
        'ana@gmail.com',
      );
      expect(ContactNormalizer.normalize(_email, 'ana@gmail'), isNull);
      expect(ContactNormalizer.normalize(_email, 'ana @gmail.com'), isNull);
      expect(ContactNormalizer.normalize(_email, ''), isNull);
    });

    test('Philippine mobile forms become 09XXXXXXXXX', () {
      for (final raw in [
        '09171234567',
        '0917 123 4567',
        '+63 917 123 4567',
        '639171234567',
        '(917) 123-4567',
      ]) {
        expect(
          ContactNormalizer.normalize(_mobile, raw),
          '09171234567',
          reason: raw,
        );
      }
    });

    test('foreign numbers keep their + form; junk is rejected', () {
      expect(
        ContactNormalizer.normalize(_mobile, '+1 415 555 0123'),
        '+14155550123',
      );
      expect(ContactNormalizer.normalize(_mobile, '12345'), isNull);
      expect(ContactNormalizer.normalize(_mobile, '088-856-1738'), isNull);
    });

    test('same() ignores formatting', () {
      expect(
        ContactNormalizer.same(_email, 'Ana@Gmail.com', 'ana@gmail.com '),
        isTrue,
      );
      expect(
        ContactNormalizer.same(_mobile, '+639171234567', '0917-123-4567'),
        isTrue,
      );
      expect(
        ContactNormalizer.same(_mobile, '09171234567', '09998887777'),
        isFalse,
      );
      expect(ContactNormalizer.same(_mobile, 'n/a', ' n/a'), isTrue);
      expect(ContactNormalizer.same(_email, null, 'ana@gmail.com'), isFalse);
    });
  });

  group('error messages', () {
    String msg(String code, {Map<String, dynamic> extra = const {}}) =>
        ContactVerificationService.errorFor(_email, 400, {
          'error': code,
          ...extra,
        }).message;

    test('limits and wrong codes are explained', () {
      expect(
        msg('cooldown', extra: {'retryAfter': 42}),
        contains('42 seconds'),
      );
      expect(
        msg('too_many_requests', extra: {'retryAfter': 1500}),
        contains('25 minutes'),
      );
      expect(
        msg('wrong_code', extra: {'attemptsLeft': 1}),
        "That code isn't right. 1 try left.",
      );
      expect(
        msg('wrong_code', extra: {'attemptsLeft': 3}),
        "That code isn't right. 3 tries left.",
      );
      expect(msg('expired'), contains('expired'));
      expect(msg('email_failed'), contains("couldn't send"));
      expect(msg('email_in_use'), contains('already used'));
      expect(
        ContactVerificationService.errorFor(_email, 401, {
          'error': 'reauth_required',
        }).needsPassword,
        isTrue,
      );
    });

    test('cooldown carries the wait so the card can count down', () {
      final e = ContactVerificationService.errorFor(_email, 429, {
        'error': 'cooldown',
        'retryAfter': 30,
      });
      expect(e.retryAfterSeconds, 30);
    });

    test('invalid target message depends on the channel', () {
      expect(
        ContactVerificationService.errorFor(_mobile, 400, {
          'error': 'invalid_target',
        }).message,
        contains('mobile number'),
      );
    });
  });

  test('mock SMS response carries the demo code', () {
    final sent = ContactCodeSent.fromJson({
      'target': '09171234567',
      'resendAfter': 60,
      'demoCode': '123456',
    }, '0917 123 4567');
    expect(sent.isDemo, isTrue);
    expect(sent.demoCode, '123456');
    expect(sent.target, '09171234567');

    final email = ContactCodeSent.fromJson({'ok': true}, 'ana@gmail.com');
    expect(email.isDemo, isFalse);
    expect(email.target, 'ana@gmail.com');
    expect(email.resendAfterSeconds, 60);

    // Production gate: release builds must never surface demo OTP codes.
    final stripped = ContactCodeSent.fromJson({
      'target': '09171234567',
      'demoCode': '123456',
    }, '09171234567', allowDemoCode: false);
    expect(stripped.demoCode, isNull);
    expect(stripped.isDemo, isFalse);
  });
}
