import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

void main() {
  testWidgets('loading shows spinner and label', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AdminStateView.loading(label: 'Loading events')),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading events'), findsOneWidget);
  });

  testWidgets('empty state renders actions and invokes them', (tester) async {
    var primary = 0;
    var secondary = 0;
    await pumpAdmin(
      tester,
      AdminStateView.empty(
        title: 'No events yet',
        message: 'Create the first event.',
        primaryAction: AdminStateAction(
          label: 'New event',
          icon: Icons.add,
          onPressed: () => primary++,
        ),
        secondaryAction: AdminStateAction(
          label: 'Clear filters',
          onPressed: () => secondary++,
        ),
      ),
    );
    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Create the first event.'), findsOneWidget);
    await tester.tap(find.text('New event'));
    await tester.tap(find.text('Clear filters'));
    expect(primary, 1);
    expect(secondary, 1);
  });

  testWidgets('error hides details until expanded', (tester) async {
    await pumpAdmin(
      tester,
      const AdminStateView.error(
        message: 'We could not load events.',
        details: 'PostgrestException: relation does not exist',
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('PostgrestException'), findsNothing);
    expect(find.text('Try again'), findsNothing);

    await tester.tap(find.text('Show details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PostgrestException'), findsOneWidget);

    await tester.tap(find.text('Hide details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PostgrestException'), findsNothing);
  });

  testWidgets('error shows retry only with a callback', (tester) async {
    var retries = 0;
    await pumpAdmin(tester, AdminStateView.error(onRetry: () => retries++));
    expect(find.text('Show details'), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  for (final width in kAdminTestWidths) {
    testWidgets('no overflow at ${width.toInt()}px', (tester) async {
      for (final view in [
        AdminStateView.empty(
          title: 'Nothing matches these filters',
          message: 'Try a broader search or clear the filters.',
          primaryAction: AdminStateAction(label: 'Clear', onPressed: () {}),
          secondaryAction: AdminStateAction(label: 'Back', onPressed: () {}),
        ),
        const AdminStateView.empty(title: 'No data', compact: true),
        AdminStateView.error(details: 'x' * 400, onRetry: () {}),
      ]) {
        await pumpAdmin(tester, view, width: width);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
