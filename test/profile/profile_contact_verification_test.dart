import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/shared/widgets/gts/gts_profile_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TracerProfile _profile({
  String contactEmail = 'ana@gmail.com',
  String mobile = '09171234567',
  String method = '',
  DateTime? mobileVerifiedAt,
}) => TracerProfile.fromSupabaseRow({
  'id': 'u1',
  'email': 'ana.login@school.edu',
  'contact_email': contactEmail,
  'display_name': 'Ana',
  'mobile_number': mobile,
  'mobile_verification_method': method,
  'mobile_verified_at': mobileVerifiedAt?.toIso8601String(),
});

void main() {
  group('TracerProfile verification status', () {
    test('contact email equal to the login counts as verified', () {
      expect(
        _profile(contactEmail: 'Ana.Login@school.edu').contactEmailVerified,
        isTrue,
      );
      expect(_profile().contactEmailVerified, isFalse);
      expect(
        TracerProfile.fromSupabaseRow({
          'id': 'u1',
          'email': 'a@school.edu',
          'contact_email': 'ana@gmail.com',
          'contact_email_verified_at': '2026-10-16T01:00:00Z',
        }).contactEmailVerified,
        isTrue,
      );
    });

    test('mobile: sms is verified, mock is only demo-confirmed', () {
      expect(_profile().mobileVerified, isFalse);
      expect(_profile().mobileDemoConfirmed, isFalse);
      expect(_profile(method: 'mock').mobileDemoConfirmed, isTrue);
      final sms = _profile(method: 'sms', mobileVerifiedAt: DateTime(2026));
      expect(sms.mobileVerified, isTrue);
      expect(sms.mobileDemoConfirmed, isFalse);
    });
  });

  group('GtsProfileFormState contacts', () {
    late GtsProfileFormState state;
    setUp(() => state = GtsProfileFormState()..applyFromProfile(_profile()));
    tearDown(() => state.dispose());

    test('loads the contact email and remembers saved contacts', () {
      expect(state.emailController.text, 'ana.login@school.edu');
      expect(state.contactEmailController.text, 'ana@gmail.com');
      expect(state.savedContact(ContactChannel.mobile), '09171234567');
    });

    test('formatting alone is not a change; a new value is', () {
      state.mobileController.text = '+63 917 123 4567';
      state.contactEmailController.text = ' ANA@gmail.com';
      expect(state.contactChanged(ContactChannel.mobile), isFalse);
      expect(state.contactChanged(ContactChannel.email), isFalse);

      state.mobileController.text = '09998887777';
      expect(state.contactChanged(ContactChannel.mobile), isTrue);
    });

    test('a cleared field is not a change (validation catches it)', () {
      state.mobileController.text = '';
      expect(state.contactChanged(ContactChannel.mobile), isFalse);
    });
  });

  group('GtsProfileFormFields with showContactEmail', () {
    late GtsProfileFormState state;
    late GlobalKey<FormState> formKey;

    setUp(() {
      state = GtsProfileFormState()..applyFromProfile(_profile());
      formKey = GlobalKey<FormState>();
    });
    tearDown(() => state.dispose());

    Future<void> pump(
      WidgetTester tester, {
      Widget? Function(ContactChannel)? footer,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: GtsProfileFormFields(
                  state: state,
                  onChanged: () {},
                  emailReadOnly: true,
                  showContactEmail: true,
                  chedStyleLabels: false,
                  contactFooter: footer,
                ),
              ),
            ),
          ),
        ),
      );
    }

    String? errorOf(WidgetTester tester, String label) {
      final field = find.ancestor(
        of: find.text(label, skipOffstage: false),
        matching: find.byType(TextField),
      );
      return tester.widget<TextField>(field.first).decoration?.errorText;
    }

    testWidgets('shows one editable email (also used to sign in)', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Login email', skipOffstage: false), findsNothing);
      expect(find.text('Contact email', skipOffstage: false), findsNothing);
      expect(
        find.text(GtsConstants.labelEmail, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('also how you sign in', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('footers render under email and mobile', (tester) async {
      await pump(tester, footer: (c) => Text('footer-${c.wire}'));
      expect(find.text('footer-email', skipOffstage: false), findsOneWidget);
      expect(find.text('footer-mobile', skipOffstage: false), findsOneWidget);
    });

    testWidgets('a changed contact must be valid; an untouched one is not '
        're-checked', (tester) async {
      state.applyFromProfile(_profile(mobile: '088-123'));
      await pump(tester);
      formKey.currentState!.validate();
      await tester.pump();
      expect(errorOf(tester, GtsConstants.labelMobile), isNull);

      state.mobileController.text = '0917';
      state.contactEmailController.text = 'ana.new@gmail';
      formKey.currentState!.validate();
      await tester.pump();
      expect(
        errorOf(tester, GtsConstants.labelMobile),
        contains('valid mobile'),
      );
      expect(
        errorOf(tester, GtsConstants.labelEmail),
        'Enter a valid email address.',
      );
    });
  });
}
