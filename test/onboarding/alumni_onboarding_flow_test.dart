import 'dart:convert';

import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_onboarding_page.dart';
import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '00000000-0000-0000-0000-000000000001';
const _email = 'maria@example.com';

/// Saved record with birthday and employment still empty.
final _userRow = <String, dynamic>{
  'id': _userId,
  'display_name': 'Maria Santos',
  'email': _email,
  'address': '123 Rizal St',
  'telephone_number': '088-123-4567',
  'mobile_number': '09171234567',
  'civil_status': 'Single',
  'gender': 'Female',
  'region_of_origin': 'Region 10',
  'province': 'Misamis Oriental',
  'location_of_residence': 'City',
  'program': 'BSIT',
  'college_university': 'USTP',
  'year_graduated': '2024',
};

final _requests = <http.Request>[];

class _FakeContactService implements ContactVerificationService {
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
      ContactSaveResult(target: target);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async {
        _requests.add(request);
        const json = {'content-type': 'application/json'};
        final isUsers = request.url.path == '/rest/v1/users';
        if (isUsers && request.method == 'GET') {
          return http.Response(
            jsonEncode([_userRow]),
            200,
            headers: json,
            request: request,
          );
        }
        if (isUsers && request.method == 'POST') {
          return http.Response('', 201, request: request);
        }
        return http.Response('[]', 201, headers: json, request: request);
      }),
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
    // A non-JWT token has no expiry, so the session restores offline.
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'refresh_token': 'test-refresh',
        'user': {
          'id': _userId,
          'email': _email,
          'aud': 'authenticated',
          'created_at': '2024-01-01T00:00:00Z',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
        },
      }),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  Finder button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('walks every step through to Review', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AlumniOnboardingScreen(contactService: _FakeContactService()),
      ),
    );
    await tester.pumpAndSettle();

    // Welcome greets the graduate from the saved record.
    expect(find.text('Maria'), findsOneWidget);
    // The phone action bar must stay compact inside bottomNavigationBar.
    expect(
      tester.getSize(find.byType(OnboardingActionBar)).height,
      lessThan(120),
    );
    await tap(tester, find.byType(Checkbox));
    await tap(tester, button('Get started'));

    // About You: the empty birthday blocks Continue.
    expect(find.text('About You'), findsWidgets);
    await tap(tester, button('Continue'));
    expect(find.text('1 field needs your attention.'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);

    await tap(tester, find.text('Tap to choose date'));
    await tap(tester, find.text('OK'));
    await tap(tester, button('Continue'));

    // Contact & address is already complete from the record.
    expect(find.text('Where the alumni office can reach you.'), findsOneWidget);
    await tap(tester, button('Continue'));

    // SMS verification is required: confirm number, then enter OTP.
    expect(find.text('Confirm your mobile number'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
    await tap(tester, button('Yes, send the code'));
    expect(find.text('Enter Verification Code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tap(tester, button('Verify'));
    await tester.pumpAndSettle();

    // Education & Work: employment status is still required.
    expect(
      find.text('Your degree and current employment status.'),
      findsOneWidget,
    );
    await tap(tester, button('Save & continue'));
    expect(find.text('Choose one'), findsOneWidget);
    // Year is blanked on onboarding load — fill it before continuing.
    final yearHint = 'e.g. ${DateTime.now().year}';
    await tester.enterText(find.widgetWithText(TextFormField, yearHint), '2024');
    await tap(tester, find.text('Employed'));
    await tap(tester, find.text('Regular or Permanent'));
    // Present Occupation appears after Employed is chosen.
    await tester.enterText(find.byType(TextFormField).last, 'Developer');
    await tester.pumpAndSettle();
    await tap(tester, button('Save & continue'));

    // Photo can be skipped.
    expect(find.text('Add a Profile Photo'), findsOneWidget);
    await tap(tester, button('Skip for now'));

    // Review requires Membership Form download + save confirm before Enter.
    expect(find.text('You’re All Set, Maria!'), findsOneWidget);
    expect(find.text('Membership Form'), findsOneWidget);
    expect(find.text('I saved my Membership Form'), findsOneWidget);
    expect(find.textContaining('from Profile for 30 days'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    expect(find.textContaining('Optional'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    final enter = tester.widget<ButtonStyleButton>(
      button('Enter alumni portal'),
    );
    expect(enter.onPressed, isNull);

    final upserts = _requests.where(
      (r) => r.method == 'POST' && r.url.path == '/rest/v1/users',
    );
    // About You, Contact, Education.
    expect(upserts.length, 3);
    final last = jsonDecode(upserts.last.body) as Map<String, dynamic>;
    expect(last['employment_status'], 'Employed');
    expect(last['birth_date'], isNotNull);
    expect(last['program'], 'BSIT');

    // Let the feedback snackbar time out.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('desktop shows the side panel with inline actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AlumniOnboardingScreen(contactService: _FakeContactService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingSidePanel), findsOneWidget);
    expect(find.text('Welcome, Maria'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
      isNull,
    );

    await tap(tester, find.byType(Checkbox));
    await tap(tester, button('Get started'));
    expect(find.text('About You'), findsWidgets);
    expect(button('Back'), findsOneWidget);
  });
}
