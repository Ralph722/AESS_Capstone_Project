import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdminBadge renders label and tone background/foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBadge(label: 'Active', tone: AdminBadgeTone.success),
        ),
      ),
    );

    expect(find.text('Active'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Active'));
    expect(text.style?.color, AdminColors.success);

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AdminColors.successBg);
  });

  testWidgets('AdminBadge renders with optional icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBadge(
            label: 'Warning',
            tone: AdminBadgeTone.warning,
            icon: Icons.warning_amber_rounded,
          ),
        ),
      ),
    );

    expect(find.text('Warning'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
    expect(icon.color, AdminColors.warning);
  });

  testWidgets('AdminBadge dense mode applies smaller padding and font', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminBadge(
            label: 'Draft',
            tone: AdminBadgeTone.neutral,
            dense: true,
          ),
        ),
      ),
    );

    expect(find.text('Draft'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Draft'));
    expect(text.style?.fontSize, 10.5);
  });
}
