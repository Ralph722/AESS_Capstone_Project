import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_contacts.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements ContactVerificationService {
  @override
  Future<ContactCodeSent> sendCode(
    ContactChannel channel,
    String target,
  ) async => ContactCodeSent(target: target, resendAfterSeconds: 60);

  @override
  Future<String> verifyCode(
    ContactChannel channel,
    String target,
    String code,
  ) async => target;

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

const _originals = ChedGtsContactOriginals(
  email: 'ana@gmail.com',
  mobile: '09171234567',
);

/// Answers every required question so the wizard can reach Review.
Map<String, dynamic> _complete(Map<String, dynamic> base) {
  final answers = Map<String, dynamic>.from(base);
  for (var round = 0; round < 20; round++) {
    final missing = ChedGtsVisibility.missingRequired(answers);
    if (missing.isEmpty) break;
    for (final id in missing) {
      final item = ChedGtsBuiltin.byId(id)!;
      answers[id] = switch (item.type) {
        ChedGtsFieldType.text || ChedGtsFieldType.longText => 'Sample',
        ChedGtsFieldType.date => '2000-01-01',
        ChedGtsFieldType.single =>
          item.options.isEmpty ? 'Sample' : item.options.first,
        ChedGtsFieldType.multi => [item.options.first],
        ChedGtsFieldType.matrix => {
          item.matrixRows.first: {item.matrixColumns.first: true},
        },
        ChedGtsFieldType.tableRows => [
          {item.tableColumns.first: 'Sample'},
        ],
      };
    }
  }
  expect(ChedGtsVisibility.missingRequired(answers), isEmpty);
  return answers;
}

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, dynamic> answers,
  Map<ContactChannel, String> verified = const {},
  Future<void> Function()? onSubmit,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ChedGtsWizard(
        answers: answers,
        onChanged: (_) {},
        onSubmit: onSubmit ?? () async {},
        onClose: () {},
        contactOriginals: _originals,
        verifiedContacts: verified,
        contactService: _FakeService(),
      ),
    ),
  );
}

Future<void> _tapPrimary(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.scrollUntilVisible(
    button,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _goToReview(WidgetTester tester) async {
  for (var i = 0; i < ChedGtsSection.values.length; i++) {
    await _tapPrimary(tester, 'Next');
  }
}

void main() {
  testWidgets('no contact change: Review submits, 5 steps', (tester) async {
    var submitted = false;
    await _pump(
      tester,
      answers: _complete({
        'ched_3': 'ANA@gmail.com ',
        'ched_5': '0917 123 4567',
      }),
      onSubmit: () async => submitted = true,
    );
    expect(find.textContaining('of 5'), findsOneWidget);
    await _goToReview(tester);
    expect(find.text('Review & submit'), findsOneWidget);
    await _tapPrimary(tester, 'Submit CHED GTS');
    expect(submitted, isTrue);
  });

  testWidgets('choosing Married prompts rename; keep leaves name locked', (
    tester,
  ) async {
    bool? optedIn;
    await tester.pumpWidget(
      MaterialApp(
        home: ChedGtsWizard(
          answers: _complete({
            'ched_3': 'ana@gmail.com',
            'ched_5': '09171234567',
          }),
          onChanged: (_) {},
          onSubmit: () async {},
          onClose: () {},
          contactOriginals: _originals,
          contactService: _FakeService(),
          onMarriageNameOptChanged: (v) => optedIn = v,
        ),
      ),
    );
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    final nameText = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(nameText.readOnly, isTrue);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Married'));
    await tester.pumpAndSettle();
    expect(find.text('Update your name?'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Keep current name'));
    await tester.pumpAndSettle();
    expect(optedIn, isFalse);
    expect(
      tester.widget<EditableText>(find.byType(EditableText).first).readOnly,
      isTrue,
    );
  });

  testWidgets('choosing Update name unlocks the name field', (tester) async {
    bool? optedIn;
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ChedGtsWizard(
          answers: _complete({
            'ched_3': 'ana@gmail.com',
            'ched_5': '09171234567',
          }),
          onChanged: (_) {},
          onSubmit: () async {},
          onClose: () {},
          contactOriginals: _originals,
          contactService: _FakeService(),
          onMarriageNameOptChanged: (v) => optedIn = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Married'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Update name'));
    await tester.pumpAndSettle();
    expect(optedIn, isTrue);
    expect(
      tester.widget<EditableText>(find.byType(EditableText).first).readOnly,
      isFalse,
    );
  });

  testWidgets('changed email adds the verify step and blocks submit', (
    tester,
  ) async {
    var submitted = false;
    await _pump(
      tester,
      answers: _complete({
        'ched_3': 'ana.new@gmail.com',
        'ched_5': '09171234567',
      }),
      onSubmit: () async => submitted = true,
    );
    expect(find.textContaining('of 6'), findsOneWidget);
    await _goToReview(tester);
    expect(find.text('Almost done'.toUpperCase()), findsOneWidget);

    await _tapPrimary(tester, 'Continue to verification');
    expect(find.text('Verify your contact details'), findsOneWidget);
    expect(find.textContaining('Step 6 of 6'), findsOneWidget);
    expect(find.text('Email address (Q3)'), findsOneWidget);
    expect(find.text('Mobile number (Q5)'), findsNothing);
    expect(find.text('ana.new@gmail.com'), findsOneWidget);

    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit CHED GTS'),
    );
    expect(submit.onPressed, isNull);
    expect(submitted, isFalse);
  });

  testWidgets('verified contacts unlock submit', (tester) async {
    var submitted = false;
    await _pump(
      tester,
      answers: _complete({
        'ched_3': 'ana.new@gmail.com',
        'ched_5': '0999 888 7777',
      }),
      verified: {
        ContactChannel.email: 'ana.new@gmail.com',
        ContactChannel.mobile: '09998887777',
      },
      onSubmit: () async => submitted = true,
    );
    await _goToReview(tester);
    await _tapPrimary(tester, 'Continue to verification');
    expect(find.text('Verified'), findsNWidgets(2));
    await _tapPrimary(tester, 'Submit CHED GTS');
    expect(submitted, isTrue);
  });
}
