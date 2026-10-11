import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_chrome.dart';
import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_step_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('first name follows the Home screen rule', () {
    expect(onboardingFirstName('Maria Santos Dela Cruz'), 'Maria');
    expect(onboardingFirstName('  Juan  '), 'Juan');
    expect(onboardingFirstName(''), 'Alumni');
  });

  testWidgets('identity card shows greeting, name and badge', (tester) async {
    await pumpPhone(
      tester,
      const OnboardingIdentityCard(
        greeting: 'Welcome to the Alumni Portal,',
        name: 'Maria',
        badge: 'Bachelor of Science in Information Technology • Batch 2024',
      ),
    );

    expect(find.text('Maria'), findsOneWidget);
    expect(find.textContaining('Batch 2024'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('roadmap lists counted steps and marks optional ones', (
    tester,
  ) async {
    await pumpPhone(
      tester,
      const OnboardingRoadmap(
        steps: [
          OnboardingStepInfo(
            label: 'Welcome',
            title: 'Welcome',
            icon: Icons.waving_hand_outlined,
            counted: false,
          ),
          OnboardingStepInfo(
            label: 'About you',
            title: 'Set up',
            icon: Icons.person_outline,
          ),
          OnboardingStepInfo(
            label: 'Profile photo',
            title: 'Set up',
            icon: Icons.photo_camera_outlined,
            optional: true,
          ),
        ],
      ),
    );

    expect(find.text('Welcome'), findsNothing);
    expect(find.text('About you'), findsOneWidget);
    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);
  });

  testWidgets('photo picker label reflects whether a photo is set', (
    tester,
  ) async {
    var taps = 0;
    await pumpPhone(
      tester,
      OnboardingPhotoPicker(image: null, onTap: () => taps++),
    );
    expect(find.text('Tap to choose a photo'), findsOneWidget);

    await tester.tap(find.byType(OnboardingPhotoPicker));
    expect(taps, 1);

    await tester.tap(find.text('Tap to choose a photo'));
    await tester.pump(const Duration(seconds: 1));
    expect(taps, 2);

    // The ripple is confined to the photo circle, not the whole picker.
    final ink = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(OnboardingPhotoPicker),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.customBorder, isA<CircleBorder>());
    expect(tester.getSize(find.byWidget(ink)), const Size.square(148));
  });

  testWidgets('summary row edit link fires and is labelled', (tester) async {
    var edits = 0;
    await pumpPhone(
      tester,
      OnboardingSummaryRow(
        icon: Icons.person_outline,
        title: 'About you',
        summary: 'Female · Single · Mar 14, 2002',
        onEdit: () => edits++,
      ),
    );

    await tester.tap(find.text('Edit'));
    expect(edits, 1);
    expect(find.bySemanticsLabel('Edit About you'), findsOneWidget);
  });

  testWidgets('celebration settles without errors', (tester) async {
    await pumpPhone(tester, const Center(child: OnboardingCelebration()));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
