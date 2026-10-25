import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/shared/widgets/admin/admin_compact_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_metric_ribbon.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_tabs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_saas_toolbar.dart';
import '../admin_shared/admin_test_harness.dart';

void main() {
  group('AdminCompactHeader', () {
    testWidgets('renders title, count badge, and action buttons', (tester) async {
      var addClicked = false;
      await pumpAdmin(
        tester,
        AdminCompactHeader(
          title: 'Alumni Directory',
          countBadge: '15 records',
          subtitle: 'Official alumni roster.',
          actions: [
            FilledButton(
              onPressed: () => addClicked = true,
              child: const Text('Add Alumni'),
            ),
          ],
        ),
      );

      expect(find.text('Alumni Directory'), findsOneWidget);
      expect(find.text('15 records'), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.text('Add Alumni'), findsOneWidget);

      await tester.tap(find.text('Add Alumni'));
      expect(addClicked, isTrue);
    });
  });

  group('AdminMetricRibbon', () {
    testWidgets('renders balanced mini-cards and handles tap selection', (tester) async {
      var tappedRegistered = false;
      await pumpAdmin(
        tester,
        AdminMetricRibbon(
          items: [
            const AdminMetricRibbonItem(
              label: 'On roster',
              value: '10',
              icon: Icons.groups_outlined,
            ),
            AdminMetricRibbonItem(
              label: 'Registered',
              value: '6',
              icon: Icons.verified_outlined,
              isSelected: true,
              onTap: () => tappedRegistered = true,
            ),
          ],
        ),
      );

      expect(find.text('On roster'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Registered'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      // Clean KPI behavior matching reference screens: no checkmark, no chevron
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await tester.tap(find.text('Registered'));
      expect(tappedRegistered, isTrue);
    });

    testWidgets('renders by default without collapse toggle icon', (tester) async {
      await pumpAdmin(
        tester,
        AdminMetricRibbon(
          items: const [
            AdminMetricRibbonItem(label: 'On roster', value: '10'),
            AdminMetricRibbonItem(label: 'Registered', value: '6'),
          ],
        ),
      );

      expect(find.text('On roster'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    });

    testWidgets('collapses and expands via collapse toggle when collapsible is true', (tester) async {
      await pumpAdmin(
        tester,
        AdminMetricRibbon(
          collapsible: true,
          items: const [
            AdminMetricRibbonItem(
              label: 'On roster',
              value: '10',
            ),
            AdminMetricRibbonItem(
              label: 'Registered',
              value: '6',
            ),
          ],
        ),
      );

      expect(find.text('On roster'), findsOneWidget);

      // Tap collapse icon
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await tester.pumpAndSettle();

      expect(find.text('2 metrics collapsed'), findsOneWidget);
      expect(find.text('Show metrics'), findsOneWidget);

      // Expand again
      await tester.tap(find.text('Show metrics'));
      await tester.pumpAndSettle();

      expect(find.text('On roster'), findsOneWidget);
      expect(find.text('Registered'), findsOneWidget);
    });
  });

  group('AdminSaaSTabs', () {
    testWidgets('renders standalone tabs and switches active tab', (tester) async {
      var activeIndex = 0;
      await pumpAdmin(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return AdminSaaSTabs(
              tabs: [
                AdminSaaSTabSpec(
                  label: 'All alumni',
                  isSelected: activeIndex == 0,
                  onTap: () => setState(() => activeIndex = 0),
                ),
                AdminSaaSTabSpec(
                  label: 'Updates',
                  count: 3,
                  isSelected: activeIndex == 1,
                  onTap: () => setState(() => activeIndex = 1),
                ),
                AdminSaaSTabSpec(
                  label: 'Deactivated',
                  count: 1,
                  isSelected: activeIndex == 2,
                  onTap: () => setState(() => activeIndex = 2),
                ),
              ],
            );
          },
        ),
      );

      expect(find.text('All alumni'), findsOneWidget);
      expect(find.text('Updates'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Deactivated'), findsOneWidget);

      await tester.tap(find.text('Updates'));
      await tester.pumpAndSettle();
      expect(activeIndex, 1);
    });
  });

  group('AdminSaaSToolbar', () {
    testWidgets('renders search, filters, reset, and refresh without overflow', (tester) async {
      var resetTriggered = false;
      var refreshTriggered = false;
      final searchCtrl = TextEditingController(text: 'Catherine');

      await pumpAdmin(
        tester,
        AdminSaaSToolbar(
          searchController: searchCtrl,
          hasActiveFilters: true,
          onResetFilters: () => resetTriggered = true,
          onRefresh: () => refreshTriggered = true,
          filters: const [
            Text('Course: BSIT'),
            Text('Batch: 2027'),
            Text('Status: All'),
          ],
        ),
      );

      expect(find.text('Course: BSIT'), findsOneWidget);
      expect(find.text('Batch: 2027'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      expect(resetTriggered, isTrue);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      expect(refreshTriggered, isTrue);
    });

    testWidgets('renders toolbar with filters, sort, and optional refresh', (tester) async {
      final searchCtrl = TextEditingController();

      await pumpAdmin(
        tester,
        AdminSaaSToolbar(
          searchController: searchCtrl,
          searchWidth: 270,
          onRefresh: () {},
          filters: const [
            Text('Filter 1'),
            Text('Filter 2'),
          ],
          sortControl: const Text('Sort: Name A-Z'),
        ),
      );

      expect(find.text('Filter 1'), findsOneWidget);
      expect(find.text('Filter 2'), findsOneWidget);
      expect(find.text('Sort: Name A-Z'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // Verify Sort is situated to the right of Filter 1
      final filter1Dx = tester.getTopLeft(find.text('Filter 1')).dx;
      final sortDx = tester.getTopLeft(find.text('Sort: Name A-Z')).dx;
      expect(sortDx, greaterThan(filter1Dx));
    });

    testWidgets('renders all filters in a unified sequence without gaps when onRefresh is omitted', (tester) async {
      final searchCtrl = TextEditingController();

      await pumpAdmin(
        tester,
        AdminSaaSToolbar(
          searchController: searchCtrl,
          searchWidth: 270,
          filters: const [
            Text('Course: BSIT'),
            Text('Batch: 2027'),
            Text('Sort: Name A-Z'),
          ],
        ),
      );

      expect(find.text('Course: BSIT'), findsOneWidget);
      expect(find.text('Batch: 2027'), findsOneWidget);
      expect(find.text('Sort: Name A-Z'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });
  });
}
