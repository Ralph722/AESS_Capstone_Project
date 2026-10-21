import 'package:alumni_system/shared/widgets/admin/admin_kpi_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

AdminKpiCard _fullCard({VoidCallback? onTap}) => AdminKpiCard(
  label: 'Employed alumni with a very long label that should wrap or clip',
  value: '1,234',
  icon: Icons.work_outline,
  caption: '3 of 8 programs reporting',
  pill: const AdminKpiPill('On track', tone: AdminTone.success),
  trend: const AdminKpiTrend(percent: 12.4, comparison: 'vs last month'),
  rows: const [('Full-time', '900'), ('Part-time', '334')],
  chart: const SizedBox(height: 40, key: Key('chart')),
  onTap: onTap,
);

void main() {
  testWidgets('renders all optional parts', (tester) async {
    await pumpAdmin(tester, _fullCard());
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('+12%'), findsOneWidget);
    expect(find.text('vs last month'), findsOneWidget);
    expect(find.text('3 of 8 programs reporting'), findsOneWidget);
    expect(find.text('Full-time'), findsOneWidget);
    expect(find.text('334'), findsOneWidget);
    expect(find.byKey(const Key('chart')), findsOneWidget);
  });

  testWidgets('tap invokes onTap', (tester) async {
    var taps = 0;
    await pumpAdmin(tester, _fullCard(onTap: () => taps++));
    await tester.tap(find.text('1,234'));
    expect(taps, 1);
  });

  testWidgets('exposes one combined semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAdmin(tester, _fullCard(onTap: () {}));
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Employed alumni.*, 1,234, On track, \+12% vs last month, '
          r'3 of 8 programs reporting, Full-time: 900, Part-time: 334$',
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('trend tone and formatting', (tester) async {
    expect(
      const AdminKpiTrend(percent: -3.25, comparison: '').formatted,
      '−3.3%',
    );
    expect(const AdminKpiTrend(percent: 0, comparison: '').formatted, '0.0%');
  });

  for (final width in kAdminTestWidths) {
    testWidgets('no overflow at ${width.toInt()}px', (tester) async {
      await pumpAdmin(tester, _fullCard(), width: width);
      await pumpAdmin(
        tester,
        SizedBox(width: 160, child: _fullCard()),
        width: width,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
