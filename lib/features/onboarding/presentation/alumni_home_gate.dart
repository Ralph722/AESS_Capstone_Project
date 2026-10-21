import 'package:flutter/material.dart';
import 'package:alumni_system/features/onboarding/presentation/alumni_onboarding_page.dart';
import 'package:alumni_system/features/shell/presentation/main_navigation.dart';
import 'package:alumni_system/features/onboarding/data/onboarding_service.dart';
import 'package:alumni_system/shared/widgets/aess_logo.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

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
      return Scaffold(
        backgroundColor: Colors.white,
        body: Semantics(
          label: 'Checking your alumni profile',
          liveRegion: true,
          child: const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(child: AessLogo(height: 72)),
                  SizedBox(height: 36),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: PortalTheme.navy,
                        backgroundColor: Color(0x1F1A1851),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Preparing your alumni portal…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PortalTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_needsOnboarding == true) {
      return const AlumniOnboardingScreen();
    }

    return MainNavigation(initialIndex: widget.initialIndex);
  }
}
