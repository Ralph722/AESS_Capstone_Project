import 'dart:convert';

import 'package:alumni_system/features/auth/presentation/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _email = 'maria@gmail.com';
const _password = 'Alumni2024x';

final _requests = <http.Request>[];

/// Mimics a project with "Confirm email" off: sign-up returns a session.
var _autoConfirm = false;

const _eligible = {
  'eligible': true,
  'memberId': 'member-1',
  'rosterFullName': 'Maria Santos',
};

/// What the roster check returns for the current test.
Map<String, Object> _eligibility = _eligible;

/// An unconfirmed sign-up: no session, so the app asks for the emailed code.
final _signUpUser = {
  'id': '00000000-0000-0000-0000-000000000002',
  'aud': 'authenticated',
  'email': _email,
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'identities': [
    {
      'id': '00000000-0000-0000-0000-000000000002',
      'identity_id': '00000000-0000-0000-0000-000000000003',
      'user_id': '00000000-0000-0000-0000-000000000002',
      'identity_data': {'email': _email},
      'provider': 'email',
      'created_at': '2026-01-01T00:00:00Z',
      'last_sign_in_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    },
  ],
};

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async {
        _requests.add(request);
        const json = {'content-type': 'application/json'};
        final path = request.url.path;
        if (path == '/rest/v1/rpc/validate_alumni_eligibility') {
          return http.Response(
            jsonEncode(_eligibility),
            200,
            headers: json,
            request: request,
          );
        }
        if (path == '/auth/v1/signup') {
          return http.Response(
            jsonEncode(
              _autoConfirm
                  ? {
                      'access_token': 'test-token',
                      'token_type': 'bearer',
                      'expires_in': 3600,
                      'refresh_token': 'test-refresh',
                      'user': _signUpUser,
                    }
                  : _signUpUser,
            ),
            200,
            headers: json,
            request: request,
          );
        }
        return http.Response('[]', 200, headers: json, request: request);
      }),
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  Finder button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  Finder field(String label) =>
      find.widgetWithText(TextFormField, label, skipOffstage: false);

  // The resend countdown ticks every second, so the screen never settles;
  // pump a fixed second of frames instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  /// Sign-up does real async work (PKCE storage) before its request.
  Future<void> sendCode(WidgetTester tester) async {
    await tap(tester, button('Send code to Gmail'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settle(tester);
  }

  Iterable<http.Request> calls(String path) =>
      _requests.where((r) => r.url.path == path);

  Future<void> pumpRegister(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font is far wider than real text; ignore horizontal overflow.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pumpAndSettle();
  }

  setUp(() {
    _requests.clear();
    _autoConfirm = false;
    _eligibility = _eligible;
  });

  for (final (code, title) in [
    ('not_found', 'No matching alumni record'),
    ('already_exists', 'Account already exists'),
    ('failed_precondition', 'Alumni record deactivated'),
  ]) {
    testWidgets('roster check "$code" shows "$title"', (tester) async {
      _eligibility = {
        'eligible': false,
        'code': code,
        'message': 'Server message for $code.',
      };
      await pumpRegister(tester);

      await tester.enterText(field('Full name'), 'Maria Santos');
      await tester.enterText(field('ID number'), '2019-12345');
      await tap(tester, button('Verify alumni status'));

      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text(title)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Server message for $code.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Not an official alumni member'), findsNothing);
      expect(
        button('Go to login'),
        code == 'already_exists' ? findsOneWidget : findsNothing,
      );

      await tap(tester, find.text(code == 'already_exists' ? 'Close' : 'OK'));
      // The banner keeps the same reason on the form.
      expect(find.text(title), findsOneWidget);
      expect(field('Gmail address'), findsNothing);
    });
  }

  testWidgets('Go to login returns to the sign-in screen', (tester) async {
    _eligibility = {
      'eligible': false,
      'code': 'already_exists',
      'message': 'This alumni record already has an account.',
    };
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
            ),
            child: const Text('sign-in screen'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('sign-in screen'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Full name'), 'Maria Santos');
    await tester.enterText(field('ID number'), '2019-12345');
    await tap(tester, button('Verify alumni status'));
    await tap(tester, button('Go to login'));

    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('sign-in screen'), findsOneWidget);
  });

  testWidgets('never skips the email code when sign-up is auto-confirmed', (
    tester,
  ) async {
    _autoConfirm = true;
    await pumpRegister(tester);

    await tester.enterText(field('Full name'), 'Maria Santos');
    await tester.enterText(field('ID number'), '2019-12345');
    await tap(tester, button('Verify alumni status'));
    await tester.enterText(field('Gmail address'), _email);
    await tester.enterText(field('Password'), _password);
    await tester.enterText(field('Confirm password'), _password);
    await sendCode(tester);
    // Signing the unverified session out is real async work too.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await settle(tester);

    expect(calls('/auth/v1/signup'), hasLength(1));
    // The unverified session is dropped and the account is not linked.
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(calls('/rest/v1/rpc/link_alumni_registration'), isEmpty);
    expect(
      find.textContaining('couldn’t send a verification code'),
      findsOneWidget,
    );
    // Still on the account step of the registration page.
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3: Account'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
  });

  testWidgets('verifies the alumni record before asking for account details', (
    tester,
  ) async {
    await pumpRegister(tester);

    // Step 1 shows only what the roster check uses.
    expect(find.bySemanticsLabel('Step 1 of 3: Verify'), findsOneWidget);
    expect(field('Full name'), findsOneWidget);
    expect(field('ID number'), findsOneWidget);
    expect(field('Gmail address'), findsNothing);
    expect(field('Password'), findsNothing);

    // An empty submit flags only the record fields.
    await tap(tester, button('Verify alumni status'));
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your school ID number'), findsOneWidget);
    expect(find.text('Enter your Gmail address'), findsNothing);
    expect(calls('/rest/v1/rpc/validate_alumni_eligibility'), isEmpty);

    await tester.enterText(field('Full name'), 'maria santos');
    await tester.enterText(field('ID number'), '2019-12345');
    await tap(tester, button('Verify alumni status'));

    final check = calls('/rest/v1/rpc/validate_alumni_eligibility');
    expect(check, hasLength(1));
    expect(check.first.body, isNot(contains('@')));

    // Step 2: the record collapses and the account fields appear.
    expect(find.bySemanticsLabel('Step 2 of 3: Account'), findsOneWidget);
    expect(find.text('Verified on official alumni roster'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.textContaining('ID 2019-12345'), findsOneWidget);
    expect(field('Full name'), findsNothing);
    expect(field('Gmail address'), findsOneWidget);

    // Change returns to step 1 with the record kept for editing.
    await tap(tester, button('Change'));
    expect(field('Full name'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(field('Gmail address'), findsNothing);
    await tap(tester, button('Verify alumni status'));

    await tester.enterText(field('Gmail address'), _email);
    await tester.enterText(field('Password'), _password);
    await tester.enterText(field('Confirm password'), _password);
    await sendCode(tester);
    expect(calls('/auth/v1/signup'), hasLength(1));

    // Step 3: only the code is asked for; the record can no longer change.
    expect(find.bySemanticsLabel('Step 3 of 3: Email code'), findsOneWidget);
    expect(find.textContaining(_email), findsOneWidget);
    expect(field('Verification code'), findsOneWidget);
    expect(field('Password'), findsNothing);
    expect(button('Change'), findsNothing);

    // Short codes are rejected; the hosted project may send up to 10 digits.
    await tester.enterText(field('Verification code'), '12345');
    await tap(tester, button('Verify code & create account'));
    expect(find.text('Enter the full code from the email'), findsOneWidget);
    expect(calls('/auth/v1/verify'), isEmpty);

    await tester.enterText(field('Verification code'), '1234 5678');
    expect(find.text('12345678'), findsOneWidget);
    await tap(tester, button('Verify code & create account'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester);
    final verify = calls('/auth/v1/verify');
    expect(verify, hasLength(1));
    expect(jsonDecode(verify.first.body), containsPair('token', '12345678'));

    // A different email goes back to step 2 with the password kept.
    await tap(tester, button('Use a different email'));
    expect(field('Gmail address'), findsOneWidget);
    await sendCode(tester);
    expect(calls('/auth/v1/signup'), hasLength(2));
    expect(find.text('Enter your Gmail address'), findsNothing);
    expect(find.text('Confirm your password'), findsNothing);

    // Let the snackbars and the resend countdown run out.
    await tester.pump(const Duration(seconds: 61));
    await settle(tester);
  });
}
