import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_contacts.dart';
import 'package:flutter_test/flutter_test.dart';

const _originals = ChedGtsContactOriginals(
  email: 'ana@gmail.com',
  mobile: '09171234567',
);

void main() {
  test('unchanged or reformatted contacts need no verification', () {
    expect(
      ChedGtsContacts.changed({
        'ched_3': ' ANA@gmail.com',
        'ched_5': '+63 917 123 4567',
      }, _originals),
      isEmpty,
    );
  });

  test('a cleared answer is not a change', () {
    expect(ChedGtsContacts.changed({'ched_3': '', 'ched_5': ''}, _originals), isEmpty);
  });

  test('only the changed contact needs verification', () {
    final answers = {'ched_3': 'ana.new@gmail.com', 'ched_5': '09171234567'};
    expect(ChedGtsContacts.changed(answers, _originals), [ContactChannel.email]);
    expect(
      ChedGtsContacts.unverified(answers, _originals, const {}),
      [ContactChannel.email],
    );
  });

  test('verified only counts for the value that was verified', () {
    final answers = {'ched_3': 'ana.new@gmail.com', 'ched_5': '0999 888 7777'};
    final verified = {
      ContactChannel.email: 'ana.new@gmail.com',
      ContactChannel.mobile: '09990000000',
    };
    expect(
      ChedGtsContacts.unverified(answers, _originals, verified),
      [ContactChannel.mobile],
    );
  });

  test('leaving puts unverified contacts back and keeps verified ones', () {
    final answers = {
      'ched_1': 'Ana',
      'ched_3': 'ana.new@gmail.com',
      'ched_5': '09998887777',
    };
    final reverted = ChedGtsContacts.revertUnverified(answers, _originals, {
      ContactChannel.email: 'ana.new@gmail.com',
    });
    expect(reverted['ched_3'], 'ana.new@gmail.com');
    expect(reverted['ched_5'], '09171234567');
    expect(reverted['ched_1'], 'Ana');
  });

  test('a new contact with nothing on the profile is removed on leave', () {
    const blank = ChedGtsContactOriginals(email: 'ana@gmail.com', mobile: '');
    final reverted = ChedGtsContacts.revertUnverified(
      {'ched_5': '09998887777'},
      blank,
      const {},
    );
    expect(reverted.containsKey('ched_5'), isFalse);
    expect(
      ChedGtsContacts.revertMessage([ContactChannel.mobile], blank),
      "Your new mobile number isn't verified yet, so it won't be saved.",
    );
  });

  test('leave message names the original value', () {
    expect(
      ChedGtsContacts.revertMessage([ContactChannel.email], _originals),
      "Your new email address isn't verified yet, so it will go back to "
      'ana@gmail.com.',
    );
    expect(
      ChedGtsContacts.revertMessage(ContactChannel.values, _originals),
      contains('email address and mobile number'),
    );
  });
}
