import 'package:alumni_system/features/admin/dashboard/widgets/admin_dashboard_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpSidebar(
  WidgetTester tester, {
  bool collapsed = false,
  VoidCallback? onToggleCollapse,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1366, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            AdminDashboardSidebar(
              selectedMenuItem: 0,
              onMenuSelected: (_) {},
              currentUser: null,
              collapsed: collapsed,
              onToggleCollapse: onToggleCollapse,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sidebar shows brand header in expanded state and emblem when collapsed', (
    tester,
  ) async {
    await _pumpSidebar(tester, onToggleCollapse: () {});
    expect(find.text('AESS'), findsOneWidget);
    expect(find.text('Admin Portal'), findsOneWidget);
  });

  testWidgets('sidebar has no logout action in either state', (tester) async {
    await _pumpSidebar(tester, onToggleCollapse: () {});
    expect(find.text('Logout'), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
  });

  testWidgets('footer toggle collapses the sidebar', (tester) async {
    var toggles = 0;
    await _pumpSidebar(tester, onToggleCollapse: () => toggles++);
    await tester.tap(find.text('Collapse sidebar'));
    expect(toggles, 1);
  });

  testWidgets('footer toggle expands the sidebar', (tester) async {
    var toggles = 0;
    await _pumpSidebar(
      tester,
      collapsed: true,
      onToggleCollapse: () => toggles++,
    );
    await tester.tap(find.byTooltip('Expand sidebar'));
    expect(toggles, 1);
  });

  testWidgets('footer is hidden without a toggle callback', (tester) async {
    await _pumpSidebar(tester);
    expect(find.text('Collapse sidebar'), findsNothing);
  });
}
