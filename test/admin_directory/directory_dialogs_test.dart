import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/roster/widgets/admin_alumni_directory_dialogs.dart';

/// Opens [open] from a button and returns the dialog's result holder.
Future<List<Object?>> _openFrom(
  WidgetTester tester,
  Future<Object?> Function(BuildContext context) open,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1366, 900);
  addTearDown(tester.view.reset);
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

AlumniMember _member({bool registered = true}) => AlumniMember(
  id: 'm1',
  fullName: 'Juan Santos',
  course: 'BSIT',
  studentId: '2023304878',
  batchYear: '2024',
  isRegisteredUser: registered,
);

void main() {
  group('Roster entry dialog', () {
    testWidgets('empty form shows inline errors and does not submit', (
      tester,
    ) async {
      var submitted = 0;
      await _openFrom(
        tester,
        (context) => showRosterEntryDialog(
          context,
          onSubmit: (_) async {
            submitted++;
            return null;
          },
        ),
      );
      await tester.tap(find.text('Add member'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the full name.'), findsOneWidget);
      expect(find.text('Enter the ID number.'), findsOneWidget);
      expect(submitted, 0);
      expect(find.text('Add to official roster'), findsOneWidget);
    });

    testWidgets('invalid year is caught before saving', (tester) async {
      var submitted = 0;
      await _openFrom(
        tester,
        (context) => showRosterEntryDialog(
          context,
          onSubmit: (_) async {
            submitted++;
            return null;
          },
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Ana Cruz');
      await tester.enterText(find.byType(TextFormField).at(1), 'X1');
      await tester.enterText(find.byType(TextFormField).at(2), '24');
      await tester.tap(find.text('Add member'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a 4-digit year (e.g. 2024) or leave it blank.'),
        findsOneWidget,
      );
      expect(submitted, 0);
    });

    testWidgets('save error stays in the dialog and keeps typed values', (
      tester,
    ) async {
      RosterEntryInput? received;
      final results = await _openFrom(
        tester,
        (context) => showRosterEntryDialog(
          context,
          onSubmit: (input) async {
            received = input;
            return 'An alumni with this ID number and course already exists.';
          },
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Ana Cruz');
      await tester.enterText(find.byType(TextFormField).at(1), 'X1');
      await tester.enterText(find.byType(TextFormField).at(2), '2024');
      await tester.tap(find.text('Add member'));
      await tester.pumpAndSettle();

      expect(received?.fullName, 'Ana Cruz');
      expect(received?.course, 'BSIT');
      expect(received?.studentId, 'X1');
      expect(received?.yearGraduated, '2024');
      expect(
        find.text('An alumni with this ID number and course already exists.'),
        findsOneWidget,
      );
      expect(find.text('Ana Cruz'), findsOneWidget);
      expect(find.text('X1'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('busy while saving, submits once, closes with true', (
      tester,
    ) async {
      final completer = Completer<String?>();
      var submitted = 0;
      final results = await _openFrom(
        tester,
        (context) => showRosterEntryDialog(
          context,
          onSubmit: (_) {
            submitted++;
            return completer.future;
          },
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'Ana Cruz');
      await tester.enterText(find.byType(TextFormField).at(1), 'X1');
      await tester.tap(find.text('Add member'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.text('Saving…'));
      await tester.pump();
      expect(submitted, 1);
      final cancel = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      expect(cancel.onPressed, isNull);

      completer.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Add to official roster'), findsNothing);
      expect(results, [true]);
    });

    testWidgets('edit pre-fills values', (tester) async {
      await _openFrom(
        tester,
        (context) => showRosterEntryDialog(
          context,
          existing: _member(),
          onSubmit: (_) async => null,
        ),
      );
      expect(find.text('Edit roster entry'), findsOneWidget);
      expect(find.text('Juan Santos'), findsOneWidget);
      expect(find.text('2023304878'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('Cancel closes without saving', (tester) async {
      var submitted = 0;
      final results = await _openFrom(
        tester,
        (context) => showRosterEntryDialog(
          context,
          onSubmit: (_) async {
            submitted++;
            return null;
          },
        ),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, [false]);
      expect(submitted, 0);
    });
  });

  group('Remove dialog', () {
    testWidgets('registered member: three choices, focus on Cancel', (
      tester,
    ) async {
      final results = await _openFrom(
        tester,
        (context) => showRosterRemoveDialog(context, member: _member()),
      );
      expect(find.text('Remove registered alumni?'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      expect(find.text('Remove account'), findsOneWidget);
      final cancel = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      expect(cancel.autofocus, isTrue);

      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      expect(results, [RosterRemoveAction.deactivate]);
    });

    testWidgets('registered member: Remove account', (tester) async {
      final results = await _openFrom(
        tester,
        (context) => showRosterRemoveDialog(context, member: _member()),
      );
      await tester.tap(find.text('Remove account'));
      await tester.pumpAndSettle();
      expect(results, [RosterRemoveAction.delete]);
    });

    testWidgets('unregistered member: Delete only, Cancel gives null', (
      tester,
    ) async {
      final results = await _openFrom(
        tester,
        (context) =>
            showRosterRemoveDialog(context, member: _member(registered: false)),
      );
      expect(find.text('Delete roster entry?'), findsOneWidget);
      expect(find.text('Deactivate'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('Escape closes with no action', (tester) async {
      final results = await _openFrom(
        tester,
        (context) => showRosterRemoveDialog(context, member: _member()),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });
}
