import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const kAdminTestWidths = <double>[320, 768, 1366];

/// Pumps [child] in a MaterialApp at a fixed logical [width].
Future<void> pumpAdmin(
  WidgetTester tester,
  Widget child, {
  double width = 1366,
  double height = 900,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
