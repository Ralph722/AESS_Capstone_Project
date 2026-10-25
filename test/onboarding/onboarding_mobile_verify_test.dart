import 'dart:convert';

import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '00000000-0000-0000-0000-000000000002';
const _email = 'jose@example.com';

final _userRow = <String, dynamic>{
  'id': _userId,
  'display_name': 'Jose Rizal',
  'email': _email,
  'address': '1 Mabini St',
  'telephone_number': '088-111-2222',
  'mobile_number': '09171234567',
  'civil_status': 'Single',
  'gender': 'Male',
  'region_of_origin': 'Region 10',
  'province': 'Misamis Oriental',
  'location_of_residence': 'City',
  'program': 'BSIT',
  'college_university': 'USTP',
  'year_graduated': '2024',
  'birth_date': '2000-01-15',
  'employment_status': 'Employed',
};

class _FakeContactService implements ContactVerificationService {
  final sent = <String>[];
  String goodCode = '123456';

  @override
  Future<ContactCodeSent> sendCode(
    ContactChannel channel,
    String target,
  ) async {
    sent.add(target);
    return ContactCodeSent(target: target, resendAfterSeconds: 60);
  }

  @override
  Future<String> verifyCode(
    ContactChannel channel,
    String target,
    String code,
  ) async {
    if (code != goodCode) {
      throw const ContactVerificationException("That code isn't right.");
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
      ContactSaveResult(target: target);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async {
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

  testWidgets('confirm mobile: send code, verify, then continue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final contact = _FakeContactService();
    await tester.pumpWidget(
      MaterialApp(home: AlumniOnboardingScreen(contactService: contact)),
    );
    await tester.pumpAndSettle();

    await tap(tester, button('Get started'));
    await tap(tester, button('Continue')); // About you (birthday loaded)
    await tap(tester, button('Continue')); // Contact → Confirm mobile

    expect(find.text('Confirm your mobile number'), findsOneWidget);
    expect(button('Continue'), findsOneWidget);
    // Continue stays disabled until verified.
    expect(
      tester.widget<ButtonStyleButton>(button('Continue')).onPressed,
      isNull,
    );

    await tap(tester, button('Send code by text'));
    expect(contact.sent, ['09171234567']);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tap(tester, button('Verify'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Number confirmed'), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(button('Continue')).onPressed,
      isNotNull,
    );
    await tap(tester, button('Continue'));
    expect(
      find.text('Your degree and current employment status.'),
      findsOneWidget,
    );
  });
}
