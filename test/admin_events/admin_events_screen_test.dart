import 'dart:convert';

import 'package:alumni_system/features/admin/events/presentation/admin_events_page.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<dynamic>[]),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  testWidgets(
      'header omits count badge and info icon; toolbar orders Date range, filter chips, then dropdowns',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminEventsScreen(enableLiveUpdates: false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final headerWidget = tester.widget<AdminCompactHeader>(
      find.byType(AdminCompactHeader),
    );
    expect(headerWidget.title, 'Events');
    expect(headerWidget.countBadge, isNull);
    expect(headerWidget.subtitle, isNull);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Archived'), findsWidgets);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('List'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AdminCompactHeader),
        matching: find.byIcon(Icons.info_outline_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AdminCompactHeader),
        matching: find.textContaining('active'),
      ),
      findsNothing,
    );

    final toolbar = tester.widget<AdminSaaSToolbar>(
      find.byType(AdminSaaSToolbar),
    );
    expect(toolbar.filters.first, isA<AdminEventDateRangeChip>());
    expect(toolbar.filters[1], isA<DirectoryToolbarFilterChip>());
    expect(toolbar.filters[2], isA<DirectoryToolbarFilterChip>());
    expect(toolbar.filters[3], isA<DirectoryToolbarFilterChip>());
    expect(toolbar.filters[4], isA<DirectoryFilterField<String?>>());
    expect(toolbar.filters[5], isA<DirectoryFilterField<String?>>());
    expect(toolbar.filters[6], isA<DirectoryFilterField<String?>>());

    final dateRangeDx = tester.getTopLeft(find.byType(AdminEventDateRangeChip)).dx;
    final firstChipDx =
        tester.getTopLeft(find.byType(DirectoryToolbarFilterChip).first).dx;
    final lastChipDx =
        tester.getTopLeft(find.byType(DirectoryToolbarFilterChip).last).dx;
    final firstDropdownDx =
        tester.getTopLeft(find.byType(DirectoryFilterField<String?>).first).dx;

    expect(dateRangeDx, lessThan(firstChipDx));
    expect(lastChipDx, lessThan(firstDropdownDx));
    expect(tester.takeException(), isNull);

    // Dispose live stream timers before tearDown.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
