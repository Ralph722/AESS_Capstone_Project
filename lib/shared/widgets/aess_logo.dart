import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official AESS wordmark (navy letters, gold accents) sized by [height].
///
/// Meant for light backgrounds; the navy letterforms disappear on navy.
class AessLogo extends StatelessWidget {
  const AessLogo({super.key, required this.height});

  final double height;

  /// Aspect of the cropped SVG viewBox (780×320).
  static const double aspect = 780 / 320;

  @override
  Widget build(BuildContext context) {
    final width = height * aspect;
    return Semantics(
      label: 'AESS, Alumni Engagement and Support System',
      image: true,
      child: SvgPicture.asset(
        'assets/images/aess_logo.svg',
        width: width,
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        placeholderBuilder: (_) => SizedBox(width: width, height: height),
      ),
    );
  }
}
