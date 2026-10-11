import 'package:flutter/material.dart';

/// Corner ribbon that marks a non-live build so demo data is never mistaken
/// for real alumni data. No ribbon when [label] is null.
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({
    super.key,
    required this.label,
    required this.child,
  });

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return child;
    return Banner(
      message: text,
      location: BannerLocation.topEnd,
      color: const Color(0xFFD97706),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
      child: child,
    );
  }
}
