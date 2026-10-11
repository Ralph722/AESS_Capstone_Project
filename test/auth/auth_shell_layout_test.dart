import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _shell() {
  return MaterialApp(
    home: AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to continue to your alumni portal.',
      form: Column(
        children: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: TextField(),
            ),
          FilledButton(onPressed: () {}, child: const Text('Log in')),
        ],
      ),
    ),
  );
}

Future<void> _pushShell(WidgetTester tester, {required bool showBack}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(navigatorKey: nav, home: const SizedBox()),
  );
  nav.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => AuthShell(
        title: 'Create account',
        subtitle: 'Register',
        backLabel: 'Back to login',
        showBackButton: showBack,
        form: const SizedBox(height: 40),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile sheet reaches the bottom of the screen', (tester) async {
    const size = Size(400, 900);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final sheet = tester.getRect(
      find
          .ancestor(
            of: find.text('Welcome back'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(sheet.bottom, size.height);
  });

  testWidgets('desktop hides the back pill when the screen opts out', (
    tester,
  ) async {
    await _pushShell(tester, showBack: false);
    expect(find.text('Back to login'), findsNothing);
  });

  testWidgets('desktop shows the back pill on pushed screens by default', (
    tester,
  ) async {
    await _pushShell(tester, showBack: true);
    expect(find.text('Back to login'), findsOneWidget);
  });

  for (final size in const [
    Size(900, 640),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('desktop form sits in a card over the photo at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final card = tester.getRect(
        find
            .ancestor(
              of: find.text('Welcome back'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(card.right, lessThan(size.width));
      expect(card.top, greaterThan(0));
      expect(card.bottom, lessThan(size.height));
      expect(card.width, lessThanOrEqualTo(472));
      expect(
        find.text(
          'Stay connected to campus life, careers, and your alumni '
          'community.',
        ),
        findsOneWidget,
      );
    });
  }
}
