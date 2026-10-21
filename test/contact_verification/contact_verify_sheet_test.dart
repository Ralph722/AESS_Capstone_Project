import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/contact_verification/presentation/contact_verify_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements ContactVerificationService {
  final saved = <ContactChannel, String>{};
  bool failSave = false;

  @override
  Future<ContactCodeSent> sendCode(
    ContactChannel channel,
    String target,
  ) async => ContactCodeSent(
    target: target,
    resendAfterSeconds: 60,
    demoCode: channel == ContactChannel.mobile ? '123456' : null,
  );

  @override
  Future<String> verifyCode(
    ContactChannel channel,
    String target,
    String code,
  ) async => target;

  bool requirePassword = false;

  @override
  Future<ContactSaveResult> saveVerified(
    ContactChannel channel,
    String target, {
    String? password,
  }) async {
    if (requirePassword && (password == null || password.isEmpty)) {
      throw const ContactVerificationException(
        'Confirm your password to change your sign-in email.',
        needsPassword: true,
      );
    }
    if (failSave) {
      throw const ContactVerificationException(
        'Your verification has expired. Please verify your email address '
        'again.',
      );
    }
    saved[channel] = target;
    return ContactSaveResult(
      target: target,
      loginChanged: channel == ContactChannel.email,
      previousEmail: channel == ContactChannel.email ? 'ana@gmail.com' : null,
    );
  }

  @override
  bool needsPasswordRecheck() => requirePassword;

  @override
  Future<void> confirmPassword(String password) async {}

  @override
  Future<ContactSaveResult> applyEmail(String target) async =>
      saveVerified(ContactChannel.email, target);
}

const _emailChange = ContactChange(
  channel: ContactChannel.email,
  original: 'ana@gmail.com',
  value: 'ana.new@gmail.com',
);
const _mobileChange = ContactChange(
  channel: ContactChannel.mobile,
  original: '09171234567',
  value: '09998887777',
);

/// Opens the sheet from a button and records what it returned.
Future<List<Map<ContactChannel, String>>> _open(
  WidgetTester tester,
  _FakeService service,
  List<ContactChange> changes,
) async {
  final results = <Map<ContactChannel, String>>[];
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async => results.add(
                await showContactVerifySheet(
                  context,
                  changes: changes,
                  service: service,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _verify(WidgetTester tester, String sendLabel) async {
  await tester.tap(find.text(sendLabel));
  await tester.pump();
  final codeField = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == '000000',
  );
  await tester.enterText(codeField, '123456');
  await tester.pump();
  await tester.tap(find.text('Verify'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('each contact is saved as soon as it is verified; Done '
      'returns them', (tester) async {
    final service = _FakeService();
    final results = await _open(tester, service, [_emailChange]);
    expect(find.text('Verify your contact details'), findsOneWidget);

    final done = find.widgetWithText(FilledButton, 'Done');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);

    await _verify(tester, 'Send code to this email');
    expect(service.saved, {ContactChannel.email: 'ana.new@gmail.com'});
    expect(find.textContaining('sign in with this address'), findsOneWidget);

    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(results.single, {ContactChannel.email: 'ana.new@gmail.com'});
  });

  testWidgets('asks for the password when the last sign-in is old', (
    tester,
  ) async {
    final service = _FakeService()..requirePassword = true;
    await _open(tester, service, [_emailChange]);
    await _verify(tester, 'Send code to this email');
    expect(find.text('Confirm it is you'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Current password'),
      'secret',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump();
    expect(service.saved, {ContactChannel.email: 'ana.new@gmail.com'});
    expect(
      find.textContaining('From now on, sign in with ana.new@gmail.com'),
      findsOneWidget,
    );
  });

  testWidgets('closing with an unverified contact asks first, then returns '
      'only what was saved', (tester) async {
    final service = _FakeService();
    final results = await _open(tester, service, [_emailChange, _mobileChange]);

    await _verify(tester, 'Send code to this email');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without verifying?'), findsOneWidget);
    expect(find.textContaining('your new mobile number'), findsOneWidget);

    await tester.tap(find.text('Keep verifying'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your contact details'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(results.single, {ContactChannel.email: 'ana.new@gmail.com'});
  });

  testWidgets('a failed save keeps the contact unverified with the reason', (
    tester,
  ) async {
    final service = _FakeService()..failSave = true;
    await _open(tester, service, [_emailChange]);
    await _verify(tester, 'Send code to this email');
    expect(find.textContaining('verification has expired'), findsOneWidget);
    expect(find.text('Needs verification'), findsOneWidget);
    expect(service.saved, isEmpty);
  });

  testWidgets('verifying an unchanged number shows it once, not as a change', (
    tester,
  ) async {
    await _open(tester, _FakeService(), const [
      ContactChange(
        channel: ContactChannel.mobile,
        original: '09171234567',
        value: '09171234567',
      ),
    ]);
    expect(find.text('Previous'), findsNothing);
    expect(find.text('Number'), findsOneWidget);
  });
}
