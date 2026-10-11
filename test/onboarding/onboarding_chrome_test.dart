import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _steps = <OnboardingStepInfo>[
  OnboardingStepInfo(
    label: 'Welcome',
    title: 'Welcome',
    icon: Icons.waving_hand_outlined,
    counted: false,
  ),
  OnboardingStepInfo(
    label: 'Your profile',
    title: 'Set up your profile',
    icon: Icons.person_outline,
  ),
  OnboardingStepInfo(
    label: 'Profile photo',
    title: 'Set up your profile',
    icon: Icons.photo_camera_outlined,
    optional: true,
  ),
  OnboardingStepInfo(
    label: 'All set',
    title: 'All set',
    icon: Icons.check_circle_outline,
    counted: false,
  ),
];

void main() {
  Future<void> pumpFrame(
    WidgetTester tester, {
    required int index,
    required Size size,
    VoidCallback? onBack,
    VoidCallback? onSkip,
    String? panelName,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingStepFrame(
            steps: _steps,
            currentIndex: index,
            panelName: panelName,
            panelBadge: 'BSIT • Batch 2024',
            views: [
              for (var i = 0; i < _steps.length; i++)
                OnboardingStepView(
                  content: Text('content-$i'),
                  actions: OnboardingActions(
                    primaryLabel: 'Continue',
                    onPrimary: () {},
                    onBack: onBack,
                    tertiaryLabel: onSkip == null ? null : 'Skip for now',
                    onTertiary: onSkip,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const phone = Size(400, 800);
  const desktop = Size(1400, 900);

  testWidgets('phone: progress counts only the middle steps', (tester) async {
    await pumpFrame(tester, index: 1, size: phone);

    expect(find.byType(OnboardingProgressHeader), findsOneWidget);
    expect(find.textContaining('Step 1 of 2'), findsOneWidget);
    expect(find.byType(OnboardingSidePanel), findsNothing);
    expect(find.text('content-1'), findsOneWidget);
  });

  testWidgets('phone: welcome step has no step counter', (tester) async {
    await pumpFrame(tester, index: 0, size: phone);

    expect(find.textContaining('Step '), findsNothing);
  });

  testWidgets('desktop: side panel shows name, badge and stepper', (
    tester,
  ) async {
    await pumpFrame(tester, index: 2, size: desktop, panelName: 'Maria Santos');

    expect(find.byType(OnboardingSidePanel), findsOneWidget);
    expect(find.byType(OnboardingProgressHeader), findsNothing);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('BSIT • Batch 2024'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('Your profile'), findsOneWidget);
  });

  testWidgets('back and skip buttons fire their callbacks', (tester) async {
    var backs = 0;
    var skips = 0;
    await pumpFrame(
      tester,
      index: 2,
      size: phone,
      onBack: () => backs++,
      onSkip: () => skips++,
    );

    await tester.tap(find.text('Back'));
    await tester.tap(find.text('Skip for now'));
    expect(backs, 1);
    expect(skips, 1);
  });

  testWidgets('steps without a back action show no Back button', (
    tester,
  ) async {
    await pumpFrame(tester, index: 0, size: phone);

    expect(find.text('Back'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
  });
}
