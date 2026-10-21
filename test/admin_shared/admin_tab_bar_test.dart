import 'package:alumni_system/shared/widgets/admin/admin_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

const _tabs = [
  AdminTabSpec(label: 'Overview', icon: Icons.dashboard_outlined),
  AdminTabSpec(label: 'Responses', icon: Icons.inbox_outlined, count: 1500),
  AdminTabSpec(label: 'Settings', count: 3),
];

class _Controlled extends StatefulWidget {
  const _Controlled({this.accept = true});

  final bool accept;

  @override
  State<_Controlled> createState() => _ControlledState();
}

class _ControlledState extends State<_Controlled> {
  int index = 0;
  final taps = <int>[];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdminTabBar(
          tabs: _tabs,
          selectedIndex: index,
          onSelected: (i) {
            taps.add(i);
            if (widget.accept) setState(() => index = i);
          },
        ),
        Text('selected:$index'),
      ],
    );
  }
}

void main() {
  testWidgets('renders labels and capped counts', (tester) async {
    await pumpAdmin(tester, const _Controlled());
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('999+'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('selectedIndex mode reports taps', (tester) async {
    await pumpAdmin(tester, const _Controlled());
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('selected:2'), findsOneWidget);
    final state = tester.state<_ControlledState>(find.byType(_Controlled));
    expect(state.taps, [2]);
  });

  testWidgets('selectedIndex mode snaps back when the screen ignores a tap', (
    tester,
  ) async {
    await pumpAdmin(tester, const _Controlled(accept: false));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 0);
  });

  testWidgets('controller mode drives the given controller', (tester) async {
    final controller = TabController(length: 3, vsync: const TestVSync());
    addTearDown(controller.dispose);
    await pumpAdmin(tester, AdminTabBar(tabs: _tabs, controller: controller));
    await tester.tap(find.text('Responses'));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });

  for (final width in kAdminTestWidths) {
    testWidgets('no overflow at ${width.toInt()}px', (tester) async {
      await pumpAdmin(tester, const _Controlled(), width: width);
      expect(tester.takeException(), isNull);
    });
  }
}
