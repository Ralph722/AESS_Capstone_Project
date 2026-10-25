import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/contact_verification/presentation/contact_verify_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements ContactVerificationService {
  final sent = <String>[];
  final checked = <String>[];
  String? demoCode;
  String goodCode = '123456';

  @override
  Future<ContactCodeSent> sendCode(
    ContactChannel channel,
    String target,
  ) async {
    sent.add(target);
    return ContactCodeSent(
      target: target,
      resendAfterSeconds: 60,
      demoCode: demoCode,
    );
  }

  @override
  Future<String> verifyCode(
    ContactChannel channel,
    String target,
    String code,
  ) async {
    checked.add(code);
    if (code != goodCode) {
      throw const ContactVerificationException(
        "That code isn't right. 4 tries left.",
      );
    }
    return target;
  }

  @override
  Future<ContactSaveResult> saveVerified(
    ContactChannel channel,
    String target, {
    String? password,
  }) async => ContactSaveResult(target: target);

  @override
  bool needsPasswordRecheck() => false;

  @override
  Future<void> confirmPassword(String password) async {}

  @override
  Future<ContactSaveResult> applyEmail(String target) async =>
      ContactSaveResult(target: target, loginChanged: true);
}

Future<void> _pump(
  WidgetTester tester, {
  required ContactChannel channel,
  required _FakeService service,
  String original = 'ana@gmail.com',
  String value = 'ana.new@gmail.com',
  bool verified = false,
  ValueChanged<String>? onValueChanged,
  ValueChanged<String>? onVerified,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContactVerifyCard(
            channel: channel,
            original: original,
            value: value,
            verified: verified,
            service: service,
            onValueChanged: onValueChanged ?? (_) {},
            onVerified: onVerified ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the previous and new email for checking', (tester) async {
    await _pump(tester, channel: ContactChannel.email, service: _FakeService());
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('ana@gmail.com'), findsOneWidget);
    expect(find.text('ana.new@gmail.com'), findsOneWidget);
    expect(find.text('Needs verification'), findsOneWidget);
    expect(find.text('Send code to this email'), findsOneWidget);
  });

  testWidgets('email: send, wrong code, then the right code verifies', (
    tester,
  ) async {
    final service = _FakeService();
    String? verifiedTarget;
    await _pump(
      tester,
      channel: ContactChannel.email,
      service: service,
      onVerified: (t) => verifiedTarget = t,
    );

    await tester.tap(find.text('Send code to this email'));
    await tester.pump();
    expect(service.sent, ['ana.new@gmail.com']);
    expect(find.textContaining('We sent a 6-digit code'), findsOneWidget);
    expect(find.text('Resend code in 1:00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '111111');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(find.text("That code isn't right. 4 tries left."), findsOneWidget);
    expect(verifiedTarget, isNull);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(verifiedTarget, 'ana.new@gmail.com');
  });

  testWidgets('Verify stays disabled until 6 digits are entered', (
    tester,
  ) async {
    await _pump(tester, channel: ContactChannel.email, service: _FakeService());
    await tester.tap(find.text('Send code to this email'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '12a4');
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('mobile shows SMS note; mock mode still shows demo code', (
    tester,
  ) async {
    final service = _FakeService()..demoCode = '654321';
    service.goodCode = '654321';
    String? verifiedTarget;
    await _pump(
      tester,
      channel: ContactChannel.mobile,
      service: service,
      original: '09171234567',
      value: '09998887777',
      onVerified: (t) => verifiedTarget = t,
    );
    expect(find.textContaining('Philippine mobile'), findsOneWidget);
    expect(find.text('Send code by text'), findsOneWidget);

    await tester.tap(find.text('Send code by text'));
    await tester.pump();
    expect(find.text('Demo code'), findsOneWidget);
    expect(find.text('654321'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump();
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(verifiedTarget, '09998887777');
  });

  testWidgets('mobile live path: no demo code, texted confirmation', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(
      tester,
      channel: ContactChannel.mobile,
      service: service,
      original: '09171234567',
      value: '09998887777',
    );
    await tester.tap(find.text('Send code by text'));
    await tester.pump();
    expect(find.text('Demo code'), findsNothing);
    expect(find.textContaining('We texted a 6-digit code'), findsOneWidget);
  });

  testWidgets('Edit rejects an invalid email and passes a valid one up', (
    tester,
  ) async {
    String? edited;
    await _pump(
      tester,
      channel: ContactChannel.email,
      service: _FakeService(),
      onValueChanged: (v) => edited = v,
    );

    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ana.new@gmail');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(edited, isNull);

    await tester.enterText(find.byType(TextField), 'ana.fixed@gmail.com');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(edited, 'ana.fixed@gmail.com');
  });

  testWidgets('verified card says it will be saved on submit', (tester) async {
    await _pump(
      tester,
      channel: ContactChannel.email,
      service: _FakeService(),
      verified: true,
    );
    expect(find.text('Verified'), findsOneWidget);
    expect(find.textContaining('saved when you submit'), findsOneWidget);
    expect(find.text('Send code to this email'), findsNothing);
  });
}
