import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_cache.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_service.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_token_service.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_verify_launch.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_data.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_token.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_dialog.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_verify_dialog.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_verify_page.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_digital_card.dart';
import 'package:alumni_system/features/home/widgets/home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AlumniCardData _data({
  String name = 'Juan Dela Cruz',
  String program = 'BS Information Technology',
}) => AlumniCardData(
  fullName: name,
  program: program,
  studentId: '2020-30512',
  batchYear: '2020',
  sex: 'Male',
  email: 'juan@gmail.com',
  memberSince: DateTime(2024, 6, 1),
  campus: 'USTP Oroquieta',
);

AlumniCardToken _token() => AlumniCardToken(
  token: 'abc123def456abc123def456abc123def456abc123def456',
  shortCode: 'K7Q4MZ',
  expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 45)),
);

class _FakeCardService extends AlumniCardService {
  _FakeCardService(this.result);

  final AlumniCardLoadResult result;

  @override
  Future<AlumniCardLoadResult> loadForCurrentUser() async => result;
}

class _FakeTokenService extends AlumniCardTokenService {
  _FakeTokenService(this.result);

  final AlumniCardVerifyResult result;
  String? lastCode;

  @override
  Future<AlumniCardVerifyResult> verify(String code) async {
    lastCode = code;
    return result;
  }
}

Future<void> _openDialog(
  WidgetTester tester, {
  required AlumniCardService service,
  Future<AlumniCardToken?> Function()? issueToken,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showAlumniCardDialog(
                context,
                service: service,
                issueToken: issueToken,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('AlumniCardData', () {
    test('initials from full name', () {
      expect(_data().initials, 'JC');
      expect(_data(name: 'Ana').initials, 'AN');
    });

    test('fromMember prefers registered email and batch year', () {
      final member = AlumniMember(
        id: 'm1',
        fullName: 'Ana Reyes',
        course: 'BSIT',
        studentId: '2023303030',
        registeredEmail: 'ana@gmail.com',
        emailAddress: 'old@school.edu',
        batchYear: '2023',
        yearGraduated: '2023',
        gender: 'female',
        createdAt: DateTime(2023, 1, 15),
      );
      final card = AlumniCardData.fromMember(member);
      expect(card.email, 'ana@gmail.com');
      expect(card.batchYear, '2023');
      expect(card.program, 'BSIT');
      expect(card.sex, 'Female');
      expect(card.initials, 'AR');
    });

    test('fromMember prefers profile sex over empty roster gender', () {
      final member = AlumniMember(
        id: 'm2',
        fullName: 'Juan Cruz',
        course: 'BSIT',
        studentId: '202030512',
        gender: null,
        createdAt: DateTime(2024, 1, 1),
      );
      final card = AlumniCardData.fromMember(member, sex: 'male');
      expect(card.sex, 'Male');
    });

    test('json round-trip', () {
      final original = _data();
      final restored = AlumniCardData.fromJson(original.toJson());
      expect(restored.fullName, original.fullName);
      expect(restored.studentId, original.studentId);
      expect(restored.email, original.email);
      expect(restored.campus, original.campus);
    });
  });

  test('AlumniCardCache save and load', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = AlumniCardCache(prefs: await SharedPreferences.getInstance());
    await cache.save('uid-1', _data());
    final loaded = await cache.load('uid-1');
    expect(loaded?.fullName, 'Juan Dela Cruz');
    expect(loaded?.studentId, '2020-30512');
    await cache.clear('uid-1');
    expect(await cache.load('uid-1'), isNull);
  });

  group('AlumniCardToken', () {
    test('formats short code and verify URL', () {
      final t = _token();
      expect(t.displayShortCode, 'K7Q-4MZ');
      expect(t.verifyUrl, contains('verify='));
      expect(t.verifyUrl, contains(t.token));
      // Tests / mobile use the public Hosting origin, not localhost.
      expect(t.verifyUrl, startsWith('https://ustp-aess.web.app'));
      expect(t.isExpired, isFalse);
    });

    test('verify result parses verified and not_valid', () {
      final ok = AlumniCardVerifyResult.fromJson({
        'ok': true,
        'status': 'verified',
        'fullName': 'Ana',
        'program': 'BSIT',
        'batchYear': '2023',
        'profileImageUrl': null,
      });
      expect(ok.ok, isTrue);
      expect(ok.fullName, 'Ana');

      final bad = AlumniCardVerifyResult.fromJson({
        'ok': false,
        'status': 'not_valid',
      });
      expect(bad.ok, isFalse);
    });
  });

  testWidgets('identity hero shows the alumni-card hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeAlumniIdentityHero(
            firstName: 'Juan',
            program: 'BSIT',
            batchYear: '2020',
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Tap to show your alumni card'), findsOneWidget);
  });

  testWidgets('card switches front to back when tapped', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AlumniDigitalCard(
              data: _data(),
              issueToken: () async => _token(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(); // resolve token
    expect(find.text('DIGITAL ID'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('SCAN TO VERIFY'), findsNothing);

    await tester.tap(find.byType(AlumniDigitalCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('SCAN TO VERIFY'), findsOneWidget);
    expect(find.text('K7Q-4MZ'), findsOneWidget);
    expect(find.textContaining('Non-transferable'), findsOneWidget);
    expect(find.textContaining('Refreshes in'), findsWidgets);

    await tester.tap(find.byType(AlumniDigitalCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('DIGITAL ID'), findsOneWidget);
  });

  testWidgets('dialog shows unmatched status', (tester) async {
    await _openDialog(
      tester,
      service: _FakeCardService(const AlumniCardLoadResult.unmatched()),
    );
    expect(find.text('Card not ready yet'), findsOneWidget);
    expect(
      find.textContaining('Alumni Office confirms your record'),
      findsOneWidget,
    );
  });

  testWidgets('dialog shows deactivated status', (tester) async {
    await _openDialog(
      tester,
      service: _FakeCardService(const AlumniCardLoadResult.deactivated()),
    );
    expect(find.text('Card unavailable'), findsOneWidget);
    expect(find.textContaining('deactivated'), findsOneWidget);
  });

  testWidgets('dialog shows card with switch hint only', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openDialog(
      tester,
      service: _FakeCardService(AlumniCardLoadResult.ready(_data())),
      issueToken: () async => _token(),
    );
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('DIGITAL ID'), findsOneWidget);
    expect(find.text('Tap the card to switch sides'), findsOneWidget);
    expect(find.text('Show back'), findsNothing);
    expect(find.text('Done'), findsNothing);

    await tester.tap(find.byType(AlumniDigitalCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('SCAN TO VERIFY'), findsOneWidget);
    expect(find.text('K7Q-4MZ'), findsOneWidget);
  });

  testWidgets('offline dialog shows saved copy without QR', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openDialog(
      tester,
      service: _FakeCardService(
        AlumniCardLoadResult.ready(_data(), offline: true),
      ),
    );
    expect(find.text('Saved copy · QR needs internet'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Saved copy · not live'), findsOneWidget);

    await tester.tap(find.byType(AlumniDigitalCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('OFFLINE COPY'), findsOneWidget);
    expect(find.text('QR needs internet'), findsOneWidget);
  });

  group('AlumniCardVerifyLaunch', () {
    test('peekCode reads verify query param', () {
      expect(
        AlumniCardVerifyLaunch.peekCode(
          Uri.parse('https://app.example/?verify=abc123'),
        ),
        'abc123',
      );
      expect(
        AlumniCardVerifyLaunch.peekCode(Uri.parse('https://app.example/')),
        isNull,
      );
    });
  });

  testWidgets('verify page shows Verified for a valid code', (tester) async {
    final tokens = _FakeTokenService(
      AlumniCardVerifyResult.verified(
        fullName: 'Ana Reyes',
        program: 'BSIT',
        batchYear: '2023',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AlumniCardVerifyPage(code: 'K7Q4MZ', tokenService: tokens),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Ana Reyes'), findsOneWidget);
    expect(find.text('Batch 2023'), findsOneWidget);
    expect(tokens.lastCode, 'K7Q4MZ');
  });

  testWidgets('verify page shows Expired / Not valid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlumniCardVerifyPage(
          code: 'dead',
          tokenService: _FakeTokenService(
            const AlumniCardVerifyResult.notValid(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Expired / Not valid'), findsOneWidget);
  });

  testWidgets('admin verify dialog checks a typed code', (tester) async {
    final tokens = _FakeTokenService(
      AlumniCardVerifyResult.verified(
        fullName: 'Juan Dela Cruz',
        program: 'BSIT',
        batchYear: '2020',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    showAlumniCardVerifyDialog(context, tokenService: tokens),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Verify alumni card'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'A1B-2C3');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(tokens.lastCode, 'A1B-2C3');
  });
}
