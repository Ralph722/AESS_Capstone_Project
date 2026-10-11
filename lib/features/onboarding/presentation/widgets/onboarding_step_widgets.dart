import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/features/onboarding/presentation/widgets/onboarding_chrome.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// First word of a display name, as the Home welcome card shows it.
String onboardingFirstName(String displayName) {
  final name = displayName.trim();
  if (name.isEmpty) return 'Alumni';
  return name.split(RegExp(r'\s+')).first;
}

/// Navy welcome card matching the Home screen's identity hero.
class OnboardingIdentityCard extends StatelessWidget {
  const OnboardingIdentityCard({
    super.key,
    required this.greeting,
    required this.name,
    this.badge,
    this.image,
  });

  final String greeting;
  final String name;
  final String? badge;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(PortalTheme.radius2xl);
    return Semantics(
      label: '$greeting $name${badge == null ? '' : ', $badge'}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          elevation: 3,
          shadowColor: PortalTheme.navy.withValues(alpha: 0.28),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: PortalTheme.heroGradient),
            child: Stack(
              children: [
                Positioned(
                  right: -28,
                  top: -36,
                  child: _Dot(
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                Positioned(
                  right: 48,
                  bottom: -40,
                  child: _Dot(
                    size: 90,
                    color: PortalTheme.gold.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: PortalTheme.meta.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              style: PortalTheme.display.copyWith(
                                color: Colors.white,
                                fontSize: 26,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (badge != null) ...[
                              const SizedBox(height: 12),
                              OnboardingGoldPill(label: badge!),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OnboardingAvatar(image: image, size: 68),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold-ringed avatar (Home hero style).
class OnboardingAvatar extends StatelessWidget {
  const OnboardingAvatar({super.key, required this.image, required this.size});

  final ImageProvider? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: PortalTheme.gold, width: 2.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          image: image == null
              ? null
              : DecorationImage(
                  image: image!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
        ),
        child: image == null
            ? Icon(
                Icons.person_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: size * 0.42,
              )
            : null,
      ),
    );
  }
}

/// "Your setup" list of the steps ahead, shown on Welcome.
class OnboardingRoadmap extends StatelessWidget {
  const OnboardingRoadmap({super.key, required this.steps});

  final List<OnboardingStepInfo> steps;

  @override
  Widget build(BuildContext context) {
    final counted = steps.where((s) => s.counted).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < counted.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < counted.length - 1 ? PortalTheme.space2 : 0,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PortalTheme.navy.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                  ),
                  child: Icon(
                    counted[i].icon,
                    size: 20,
                    color: PortalTheme.navy,
                  ),
                ),
                const SizedBox(width: PortalTheme.space2),
                Expanded(
                  child: Text(
                    counted[i].label,
                    style: PortalTheme.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (counted[i].optional)
                  Text('Optional', style: PortalTheme.meta),
              ],
            ),
          ),
      ],
    );
  }
}

/// Circular photo picker with a dashed outline and camera badge.
class OnboardingPhotoPicker extends StatelessWidget {
  const OnboardingPhotoPicker({
    super.key,
    required this.image,
    required this.onTap,
    this.size = 148,
  });

  final ImageProvider? image;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;
    return Semantics(
      button: true,
      label: hasImage ? 'Change profile photo' : 'Choose a profile photo',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DashedCirclePainter(
                        color: hasImage
                            ? PortalTheme.navy
                            : PortalTheme.navy.withValues(alpha: 0.45),
                        dashed: !hasImage,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(
                        child: hasImage
                            ? Image(image: image!, fit: BoxFit.cover)
                            : const ColoredBox(
                                color: PortalTheme.surfaceMuted,
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 44,
                                  color: PortalTheme.navy,
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Drawn above the photo so the hover and ripple show on it.
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: onTap,
                        customBorder: const CircleBorder(),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: IgnorePointer(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: PortalTheme.navy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PortalTheme.space2),
            MouseRegion(
              cursor: onTap == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Text(
                      hasImage
                          ? 'Tap to change photo'
                          : 'Tap to choose a photo',
                      style: PortalTheme.cardTitle.copyWith(
                        color: PortalTheme.navy,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'JPG or PNG — we’ll resize it for you',
                      style: PortalTheme.meta,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;
    final circle = rect.deflate(1);
    if (!dashed) {
      canvas.drawOval(circle, paint);
      return;
    }
    const dashes = 36;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(circle, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color || old.dashed != dashed;
}

/// Green check with gold dots; animates once when it first appears.
class OnboardingCelebration extends StatelessWidget {
  const OnboardingCelebration({super.key});

  static const _dots = <(double angle, double distance, double size)>[
    (-2.6, 70, 7),
    (-2.0, 82, 5),
    (-1.3, 74, 8),
    (-0.6, 84, 5),
    (0.0, 72, 6),
    (0.7, 80, 7),
    (1.5, 76, 5),
    (2.3, 82, 6),
    (2.9, 70, 5),
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (context, t, _) {
          final dotT = t.clamp(0.0, 1.0);
          return SizedBox(
            width: 190,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final (angle, distance, size) in _dots)
                  Transform.translate(
                    offset: Offset(
                      math.cos(angle) * distance * dotT,
                      math.sin(angle) * distance * dotT * 0.8,
                    ),
                    child: Opacity(
                      opacity: dotT,
                      child: _Dot(size: size, color: PortalTheme.gold),
                    ),
                  ),
                Transform.scale(
                  scale: t,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: PortalTheme.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: PortalTheme.success.withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One row of the Review summary with an Edit link.
class OnboardingSummaryRow extends StatelessWidget {
  const OnboardingSummaryRow({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PortalTheme.space2),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PortalTheme.navy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            ),
            child: Icon(icon, size: 20, color: PortalTheme.navy),
          ),
          const SizedBox(width: PortalTheme.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PortalTheme.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: PortalTheme.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: PortalTheme.space1),
          TextButton(
            onPressed: onEdit,
            style: PortalTheme.ghostButton(dense: true),
            child: Text('Edit', semanticsLabel: 'Edit $title'),
          ),
        ],
      ),
    );
  }
}

/// White rounded card used for Welcome / Review content on phones.
class OnboardingContentCard extends StatelessWidget {
  const OnboardingContentCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(PortalTheme.space3),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.75)),
        boxShadow: PortalTheme.softShadow,
      ),
      child: child,
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
