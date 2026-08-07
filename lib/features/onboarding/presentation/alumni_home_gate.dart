import 'package:flutter/material.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_onboarding_page.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/features/onboarding/data/onboarding_service.dart';
import 'package:alumni_system/shared/widgets/onboarding/onboarding_ui.dart';

/// Routes alumni to onboarding or the main app based on profile onboarding state.
class AlumniHomeGate extends StatefulWidget {
  const AlumniHomeGate({super.key, this.initialIndex});

  final int? initialIndex;

  @override
  State<AlumniHomeGate> createState() => _AlumniHomeGateState();
}

class _AlumniHomeGateState extends State<AlumniHomeGate> {
  bool? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final complete = await OnboardingService().resolveForCurrentUser();
    if (!mounted) return;
    setState(() => _needsOnboarding = !complete);
  }

  @override
  Widget build(BuildContext context) {
    // Wait until onboarding status is known — never flash the home dashboard.
    if (_needsOnboarding == null) {
      return const Scaffold(
        backgroundColor: OnboardingTheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: OnboardingTheme.navy),
        ),
      );
    }

    if (_needsOnboarding == true) {
      return const AlumniOnboardingScreen();
    }

    return MainNavigation(initialIndex: widget.initialIndex);
  }
}
