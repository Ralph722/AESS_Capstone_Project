import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_kpi_card.dart';

import '../admin_shared/admin_test_harness.dart';

AlumniMember _member({
  String name = 'Catherine Jala',
  String batch = '2024',
  String? email = 'catherine@example.com',
  bool registered = true,
  bool tracer = true,
  bool deactivated = false,
}) {
  return AlumniMember(
    id: 'm1',
    fullName: name,
    course: 'BSIT',
    studentId: '2023303030',
    batchYear: batch,
    registeredEmail: email,
    isRegisteredUser: registered,
    tracerProfileComplete: tracer,
    isDeactivated: deactivated,
  );
}

Widget _tableRow(
  AlumniMember member, {
  ChedGtsProgress? ched = const (assigned: 2, submitted: 2),
}) {
  return AdminDataTable(
    columns: kDirectoryTableColumns,
    trailingHeader: const SizedBox.shrink(),
    trailingWidth: 44,
    rowCount: 1,
    shrinkWrap: true,
    rowBuilder: (_, __) => DirectoryMemberTableRow(
      member: member,
      showActiveBadge: false,
      chedProgress: ched,
      onTap: () {},
      onEdit: () {},
      onDelete: () {},
    ),
  );
}

Widget _filterField(String label) {
  return DirectoryFilterField<String?>(
    label: label,
    value: null,
    width: 136,
    items: const [DropdownMenuItem(value: null, child: Text('All'))],
    onChanged: (_) {},
  );
}

Widget _toolbar({double? singleRowMinWidth, bool hasActiveFilters = false}) {
  return DirectoryToolbarCard(
    searchController: TextEditingController(),
    onSearchChanged: (_) {},
    onClearSearch: () {},
    isLoading: false,
    onRefresh: () {},
    hasActiveFilters: hasActiveFilters,
    onResetFilters: () {},
    filters: Wrap(
      spacing: 6,
      children: [_filterField('Course'), _filterField('Batch')],
    ),
    activeFilterChips: hasActiveFilters
        ? [DirectoryActiveFilterChip(label: 'Course: BSIT', onRemoved: () {})]
        : const [],
    singleRowMinWidth: singleRowMinWidth,
  );
}

void main() {
  group('Directory table', () {
    testWidgets('has Batch and CHED GTS columns in order', (tester) async {
      await pumpAdmin(tester, _tableRow(_member()));
      final labels = kDirectoryTableColumns.map((c) => c.label).toList();
      expect(labels, [
        'NAME',
        'COURSE',
        'BATCH',
        'STUDENT ID',
        'EMAIL',
        'LAST ACTIVE',
        'CHED GTS',
        'STATUS',
      ]);
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('row shows batch, CHED completion and full-email tooltip', (
      tester,
    ) async {
      await pumpAdmin(tester, _tableRow(_member()));
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Registered'), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.text('catherine@example.com'),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'catherine@example.com');
    });

    testWidgets('partial CHED progress shows submitted over assigned', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        _tableRow(_member(), ched: const (assigned: 3, submitted: 1)),
      );
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('missing values show a dash; deactivated badge', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        _tableRow(
          _member(batch: '', email: null, tracer: false, deactivated: true),
          ched: null,
        ),
      );
      expect(find.text('—'), findsNWidgets(4));
      expect(find.text('Deactivated'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
    });

    for (final width in [1024.0, 1366.0, 1920.0]) {
      testWidgets('no overflow with a long name at $width', (tester) async {
        await pumpAdmin(
          tester,
          _tableRow(
            _member(
              name: 'Maria Concepcion Bernadette Dela Cruz-Villanueva',
              email: 'maria.concepcion.delacruz.villanueva@example.com',
            ),
          ),
          width: width,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('card row shows Batch', (tester) async {
    await pumpAdmin(
      tester,
      DirectoryMemberCard(
        member: _member(),
        showActiveBadge: false,
        onTap: () {},
        onEdit: () {},
        onDelete: () {},
      ),
      width: 700,
    );
    expect(find.text('Batch'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('DirectoryKpiRow', () {
    List<Widget> cards(int n) => [
      for (var i = 0; i < n; i++)
        AdminKpiCard(
          dense: true,
          label: 'Label $i',
          value: '$i',
          caption: i == 0
              ? 'Total alumni records, incl. 2 deactivated'
              : 'Caption',
          icon: Icons.groups_outlined,
        ),
    ];

    testWidgets('5 cards share one row with equal height at 1366', (
      tester,
    ) async {
      await pumpAdmin(tester, DirectoryKpiRow(children: cards(5)));
      final first = tester.getRect(find.byType(AdminKpiCard).first);
      final last = tester.getRect(find.byType(AdminKpiCard).last);
      expect(last.top, first.top);
      expect(last.height, first.height);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wraps to 2 columns at 700 and 1 at 400', (tester) async {
      await pumpAdmin(tester, DirectoryKpiRow(children: cards(4)), width: 700);
      var rects = tester
          .widgetList(find.byType(AdminKpiCard))
          .map((w) => tester.getRect(find.byWidget(w)))
          .toList();
      expect(rects[1].top, rects[0].top);
      expect(rects[2].top, greaterThan(rects[0].top));
      expect(tester.takeException(), isNull);

      await pumpAdmin(tester, DirectoryKpiRow(children: cards(4)), width: 400);
      rects = tester
          .widgetList(find.byType(AdminKpiCard))
          .map((w) => tester.getRect(find.byWidget(w)))
          .toList();
      expect(rects[1].top, greaterThan(rects[0].top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a card runs its filter action', (tester) async {
      var tapped = false;
      await pumpAdmin(
        tester,
        DirectoryKpiRow(
          children: [
            AdminKpiCard(
              dense: true,
              label: 'Registered alumni',
              value: '3',
              icon: Icons.verified_outlined,
              onTap: () => tapped = true,
            ),
          ],
        ),
      );
      await tester.tap(find.text('Registered alumni'));
      expect(tapped, isTrue);
    });
  });

  group('DirectoryToolbarCard', () {
    double searchTop(WidgetTester tester) =>
        tester.getTopLeft(find.byType(TextField).first).dy;
    double filterTop(WidgetTester tester) =>
        tester.getTopLeft(find.text('Course')).dy;

    testWidgets('default stays two rows (other screens unchanged)', (
      tester,
    ) async {
      await pumpAdmin(tester, _toolbar());
      expect(filterTop(tester), greaterThan(searchTop(tester) + 30));
    });

    testWidgets('opt-in single row when wide enough', (tester) async {
      await pumpAdmin(tester, _toolbar(singleRowMinWidth: 1000));
      expect(filterTop(tester), lessThan(searchTop(tester) + 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('opt-in falls back to two rows when narrow', (tester) async {
      await pumpAdmin(tester, _toolbar(singleRowMinWidth: 1000), width: 900);
      expect(filterTop(tester), greaterThan(searchTop(tester) + 30));
    });

    testWidgets('Reset and chips appear in both modes', (tester) async {
      for (final minWidth in [null, 1000.0]) {
        await pumpAdmin(
          tester,
          _toolbar(singleRowMinWidth: minWidth, hasActiveFilters: true),
        );
        expect(find.text('Reset'), findsOneWidget);
        expect(find.text('Course: BSIT'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('DirectoryFilterField', () {
    testWidgets('height unchanged (40) and floated label is readable', (
      tester,
    ) async {
      await pumpAdmin(tester, Center(child: _filterField('Course')));
      expect(
        tester.getSize(find.byType(DirectoryFilterField<String?>)).height,
        40,
      );
      final decoration = DirectoryFilterField.decoration(label: 'Course');
      // Flutter renders a floated label at 75% of this size (~11px).
      expect(decoration.floatingLabelStyle?.fontSize, 14.5);
    });
  });

  group('DirectoryPageHeader', () {
    testWidgets('new title and export label; callbacks fire', (tester) async {
      var added = false;
      var exported = false;
      await pumpAdmin(
        tester,
        DirectoryPageHeader(
          onAdd: () => added = true,
          onExport: () => exported = true,
          isLoading: false,
          canExport: true,
        ),
      );
      expect(find.text('Alumni Directory'), findsOneWidget);
      expect(
        find.text('Official roster used to validate alumni registration.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Export CHED GTS'));
      await tester.tap(find.text('Add Alumni'));
      expect(exported, isTrue);
      expect(added, isTrue);
    });

    testWidgets('export disabled when roster empty', (tester) async {
      await pumpAdmin(
        tester,
        DirectoryPageHeader(
          onAdd: () {},
          onExport: () {},
          isLoading: false,
          canExport: false,
        ),
      );
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Export CHED GTS'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });
}
