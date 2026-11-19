import 'package:alumni_system/features/contact_verification/presentation/ph_mobile_input_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhMobileInputFormatter', () {
    test('formats GCash-style groups', () {
      expect(
        PhMobileInputFormatter.formatDisplay('09171234567'),
        '0917 123 4567',
      );
      expect(PhMobileInputFormatter.formatDisplay('0917'), '0917');
      expect(PhMobileInputFormatter.formatDisplay('0917123'), '0917 123');
    });

    test('strips non-digits and caps at 11', () {
      expect(
        PhMobileInputFormatter.digitsOnly('0917-123-4567 extra'),
        '09171234567',
      );
      expect(
        PhMobileInputFormatter.formatDisplay('09171234567890'),
        '0917 123 4567',
      );
    });
  });
}
