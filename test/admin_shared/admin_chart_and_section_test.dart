import 'package:alumni_system/shared/widgets/admin/admin_chart_card.dart';
import 'package:alumni_system/shared/widgets/admin/admin_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

AdminChartCard _chart({bool isEmpty = false}) => AdminChartCard(
  title: 'Employment rate by program',
  caption: 'Graduates 2020–2025, latest tracer response',
  infoTooltip: 'Employed ÷ respondents',
  trailing: OutlinedButton(onPressed: () {}, child: const Text('By year')),
  legend: const [('Employed', Colors.blue), ('Unemployed', Colors.orange)],
  chartHeight: 160,
  isEmpty: isEmpty,
  child: const ColoredBox(color: Colors.grey, key: Key('chart-body')),
);

AdminSectionHeader _header() => AdminSectionHeader(
  title: 'Upcoming events',
  caption: 'Next 30 days',
  leadingIcon: Icons.event,
  actions: [
    OutlinedButton(onPressed: () {}, child: const Text('Export')),
    FilledButton(onPressed: () {}, child: const Text('New event')),
  ],
);

void main() {
  testWidgets('chart card renders title, caption, legend and child', (
    tester,
  ) async {
    await pumpAdmin(tester, _chart());
    expect(find.text('Employment rate by program'), findsOneWidget);
    expect(
      find.text('Graduates 2020–2025, latest tracer response'),
      findsOneWidget,
    );
    expect(find.text('Employed'), findsOneWidget);
    expect(find.text('By year'), findsOneWidget);
    expect(find.byKey(const Key('chart-body')), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);
  });

  testWidgets('chart card shows empty state instead of the chart', (
    tester,
  ) async {
    await pumpAdmin(tester, _chart(isEmpty: true));
    expect(find.byKey(const Key('chart-body')), findsNothing);
    expect(find.text('No data for this period'), findsOneWidget);
    expect(find.text('Employed'), findsNothing);
  });

  testWidgets('section header title is a semantics header', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAdmin(tester, _header());
    expect(
      tester.getSemantics(find.text('Upcoming events')),
      matchesSemantics(label: 'Upcoming events', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('section header stacks actions when narrow', (tester) async {
    await pumpAdmin(tester, _header(), width: 320);
    final titleY = tester.getTopLeft(find.text('Upcoming events')).dy;
    final actionY = tester.getTopLeft(find.text('Export')).dy;
    expect(actionY, greaterThan(titleY + 20));

    await pumpAdmin(tester, _header(), width: 1366);
    final wideTitle = tester.getCenter(find.text('Upcoming events')).dy;
    final wideAction = tester.getCenter(find.text('Export')).dy;
    expect((wideAction - wideTitle).abs(), lessThan(20));
  });

  for (final width in kAdminTestWidths) {
    testWidgets('no overflow at ${width.toInt()}px', (tester) async {
      await pumpAdmin(tester, _chart(), width: width);
      expect(tester.takeException(), isNull);
      await pumpAdmin(tester, _chart(isEmpty: true), width: width);
      expect(tester.takeException(), isNull);
      await pumpAdmin(tester, _header(), width: width);
      expect(tester.takeException(), isNull);
    });
  }
}
