import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';

void main() {
  test('example finding is labelled and never a persisted id pattern', () {
    final flag = dssExampleFinding();
    expect(flag.id, 'example-preview-not-saved');
    expect(flag.title, contains('EXAMPLE'));
    expect(flag.body, contains('not a real finding'));
    expect(flag.status, DssFlagStatus.open);
  });

  testWidgets('How this works strip shows four steps and dismiss', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DssHowThisWorksStrip(
            onDismiss: () => dismissed = true,
            onSeeExample: () {},
          ),
        ),
      ),
    );
    expect(find.text('How this works'), findsOneWidget);
    expect(find.text('Start the finding'), findsOneWidget);
    expect(find.text('Plan, act in AESS, add Proof'), findsOneWidget);
    expect(find.text('Resolve finding'), findsOneWidget);
    expect(find.textContaining('Check outcome'), findsOneWidget);
    expect(find.text('See example'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('example preview dialog shows EXAMPLE badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDssExampleFindingPreview(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('EXAMPLE'), findsOneWidget);
    expect(find.textContaining('Sample finding'), findsOneWidget);
    expect(find.textContaining('nothing here is saved'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.textContaining('Next: Start'), findsWidgets);
  });
}
