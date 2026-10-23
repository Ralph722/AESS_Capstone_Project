import 'package:alumni_system/features/admin/dashboard/application/admin_dashboard_metrics.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_dashboard_shell.dart';
import 'package:alumni_system/features/admin/profile/data/admin_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ana = AdminProfile(name: 'Ana Reyes', email: 'ana@ustp.edu.ph');

Future<AdminProfileController> _pumpHeader(
  WidgetTester tester, {
  int selected = 0,
  double width = 1366,
  VoidCallback? onLogout,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  final profile = AdminProfileController(initial: _ana);
  addTearDown(profile.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminDashboardTopHeader(
          profile: profile,
          onMenuSelected: (_) {},
          metrics: const AdminDashboardMetrics(),
          selectedMenuItem: selected,
          onLogout: onLogout,
        ),
      ),
    ),
  );
  await tester.pump();
  return profile;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
  });

  testWidgets('header does not show screen title or path in top bar', (tester) async {
    await _pumpHeader(tester);

    expect(find.text('Overview'), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('search sits in the right-hand control group', (tester) async {
    await _pumpHeader(tester, selected: 2);

    final search = find.byType(TextField);
    expect(tester.getSize(search).width, 320);
    expect(
      tester.getTopRight(search).dx,
      lessThan(tester.getTopLeft(find.byTooltip('Account')).dx),
    );
  });

  testWidgets('account chip follows profile changes', (tester) async {
    final profile = await _pumpHeader(tester, width: 1500);
    expect(find.text('Ana Reyes'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);

    profile.value = profile.value.copyWithName('Ben Cruz');
    await tester.pump();
    expect(find.text('Ben Cruz'), findsOneWidget);
    expect(find.text('BC'), findsOneWidget);
  });

  testWidgets('account menu lists profile actions and logout', (tester) async {
    var loggedOut = 0;
    await _pumpHeader(tester, onLogout: () => loggedOut++);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('ana@ustp.edu.ph'), findsOneWidget);
    for (final label in ['Edit profile', 'Change password', 'Help', 'Logout']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(loggedOut, 1);
  });

  testWidgets('Edit profile opens the edit dialog', (tester) async {
    await _pumpHeader(tester);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });
}
