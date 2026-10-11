import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// One screen of the onboarding flow.
class OnboardingStepInfo {
  const OnboardingStepInfo({
    required this.label,
    required this.title,
    required this.icon,
    this.counted = true,
    this.optional = false,
  });

  /// Short name for the progress header and the desktop stepper.
  final String label;

  /// App bar title while this step is open.
  final String title;
  final IconData icon;

  /// Whether the step counts toward "Step X of N" (Welcome and the final
  /// screen do not).
  final bool counted;
  final bool optional;
}

/// Buttons for the current step.
class OnboardingActions {
  const OnboardingActions({
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.showArrow = true,
    this.onBack,
    this.tertiaryLabel,
    this.onTertiary,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final bool showArrow;
  final VoidCallback? onBack;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;
}

/// Content and buttons for one step.
class OnboardingStepView {
  const OnboardingStepView({
    required this.content,
    required this.actions,
    this.centerContent = false,
  });

  final Widget content;
  final OnboardingActions actions;

  /// Vertically centers short content (Welcome, Photo, final screen).
  final bool centerContent;
}

abstract final class OnboardingLayout {
  /// Readable column width for the single-column (phone / tablet) layout.
  static const double compactContentMax = 600;
  static const double sidePanelWidth = 320;

  static bool isWide(double width) => width >= PortalBreakpoints.expanded;
}

/// Responsive onboarding body: progress header + single column on phones and
/// tablets; navy stepper panel + content card on desktop.
///
/// Every step stays mounted (like an [IndexedStack]) so typed values and
/// scroll positions survive going back; only the incoming step animates.
class OnboardingStepFrame extends StatelessWidget {
  const OnboardingStepFrame({
    super.key,
    required this.steps,
    required this.views,
    required this.currentIndex,
    this.forward = true,
    this.progressTrailing,
    this.panelName,
    this.panelBadge,
    this.showCompactActionBar = true,
  }) : assert(steps.length == views.length);

  /// Set false when the caller places [OnboardingActionBar] in
  /// [Scaffold.bottomNavigationBar] so floating snackbars sit above it.
  final bool showCompactActionBar;

  final List<OnboardingStepInfo> steps;
  final List<OnboardingStepView> views;
  final int currentIndex;

  /// Direction of the last step change, for the entrance slide.
  final bool forward;

  /// Optional right-hand text in the progress header (e.g. field count).
  final String? progressTrailing;
  final String? panelName;
  final String? panelBadge;

  @override
  Widget build(BuildContext context) {
    final wide = OnboardingLayout.isWide(MediaQuery.sizeOf(context).width);
    final actions = views[currentIndex].actions;

    final stack = IndexedStack(
      index: currentIndex,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < views.length; i++)
          _StepEntrance(
            active: i == currentIndex,
            forward: forward,
            child: _StepScroll(
              center: views[i].centerContent,
              padding: wide
                  ? const EdgeInsets.fromLTRB(
                      PortalTheme.space6,
                      PortalTheme.space5,
                      PortalTheme.space6,
                      PortalTheme.space5,
                    )
                  : const EdgeInsets.fromLTRB(
                      PortalTheme.space4,
                      PortalTheme.space4,
                      PortalTheme.space4,
                      PortalTheme.space5,
                    ),
              maxWidth: wide ? null : OnboardingLayout.compactContentMax,
              child: views[i].content,
            ),
          ),
      ],
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingProgressHeader(
            steps: steps,
            currentIndex: currentIndex,
            trailing: progressTrailing,
          ),
          Expanded(child: stack),
          if (showCompactActionBar)
            OnboardingActionBar(actions: actions, wide: false),
        ],
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: PortalBreakpoints.contentMax,
        ),
        child: Padding(
          padding: const EdgeInsets.all(PortalTheme.space5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: OnboardingLayout.sidePanelWidth,
                child: OnboardingSidePanel(
                  steps: steps,
                  currentIndex: currentIndex,
                  name: panelName,
                  badge: panelBadge,
                ),
              ),
              const SizedBox(width: PortalTheme.space5),
              Expanded(
                child: PortalCardShell(
                  borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: stack),
                      Container(
                        height: 1,
                        color: PortalTheme.border.withValues(alpha: 0.75),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PortalTheme.space6,
                          vertical: PortalTheme.space3,
                        ),
                        child: OnboardingActionBar(
                          actions: actions,
                          wide: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({
    required this.center,
    required this.padding,
    required this.maxWidth,
    required this.child,
  });

  final bool center;
  final EdgeInsets padding;
  final double? maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget body = ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - padding.vertical).clamp(
              0,
              double.infinity,
            ),
          ),
          child: center
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [child],
                )
              : child,
        );
        final cap = maxWidth;
        if (cap != null) {
          body = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cap),
              child: body,
            ),
          );
        }
        return SingleChildScrollView(padding: padding, child: body);
      },
    );
  }
}

/// Fades and slides a step in each time it becomes the active one.
class _StepEntrance extends StatefulWidget {
  const _StepEntrance({
    required this.active,
    required this.forward,
    required this.child,
  });

  final bool active;
  final bool forward;
  final Widget child;

  @override
  State<_StepEntrance> createState() => _StepEntranceState();
}

class _StepEntranceState extends State<_StepEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PortalTheme.normal,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: PortalTheme.ease,
  );

  @override
  void didUpdateWidget(covariant _StepEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dx = widget.forward ? 0.04 : -0.04;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(dx, 0),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Phone / tablet progress: one segment per counted step plus
/// "Step X of N · Label". Hidden on Welcome and the final screen.
class OnboardingProgressHeader extends StatelessWidget {
  const OnboardingProgressHeader({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.trailing,
  });

  final List<OnboardingStepInfo> steps;
  final int currentIndex;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final counted = [
      for (var i = 0; i < steps.length; i++)
        if (steps[i].counted) i,
    ];
    final position = counted.indexOf(currentIndex);
    if (position < 0) return const SizedBox.shrink();

    final label = steps[currentIndex].label;
    final stepText = 'Step ${position + 1} of ${counted.length}';

    return Semantics(
      container: true,
      label: '$stepText, $label',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PortalTheme.card,
            border: Border(
              bottom: BorderSide(
                color: PortalTheme.border.withValues(alpha: 0.9),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PortalTheme.space3,
              PortalTheme.space2,
              PortalTheme.space3,
              PortalTheme.space2,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OnboardingLayout.compactContentMax,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (var j = 0; j < counted.length; j++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: PortalTheme.normal,
                              curve: PortalTheme.ease,
                              height: 4,
                              margin: EdgeInsets.only(
                                right: j < counted.length - 1 ? 6 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: j < position
                                    ? PortalTheme.success
                                    : j == position
                                    ? PortalTheme.navy
                                    : PortalTheme.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: PortalTheme.space1),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: stepText,
                                  style: PortalTheme.meta.copyWith(
                                    color: PortalTheme.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: '  ·  $label',
                                  style: PortalTheme.meta,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trailing != null)
                          Text(trailing!, style: PortalTheme.meta),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop navy panel: who is onboarding, a vertical stepper, and why the
/// data is collected.
class OnboardingSidePanel extends StatelessWidget {
  const OnboardingSidePanel({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.name,
    this.badge,
  });

  final List<OnboardingStepInfo> steps;
  final int currentIndex;
  final String? name;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final counted = [
      for (var i = 0; i < steps.length; i++)
        if (steps[i].counted) i,
    ];
    final displayName = (name ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: PortalTheme.heroGradient),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: _Circle(
                size: 140,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              left: -36,
              bottom: -36,
              child: _Circle(
                size: 120,
                color: PortalTheme.gold.withValues(alpha: 0.10),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(PortalTheme.space5),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (constraints.maxHeight - PortalTheme.space5 * 2)
                              .clamp(0, double.infinity),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Setting up your profile',
                            style: PortalTheme.meta.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            displayName.isEmpty ? 'Welcome' : displayName,
                            style: PortalTheme.display.copyWith(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (badge != null && badge!.trim().isNotEmpty) ...[
                            const SizedBox(height: PortalTheme.space2),
                            OnboardingGoldPill(label: badge!),
                          ],
                          const SizedBox(height: PortalTheme.space6),
                          for (var j = 0; j < counted.length; j++)
                            _StepperRow(
                              number: j + 1,
                              info: steps[counted[j]],
                              state: counted[j] < currentIndex
                                  ? _StepState.done
                                  : counted[j] == currentIndex
                                  ? _StepState.active
                                  : _StepState.upcoming,
                              caption: counted[j] == currentIndex
                                  ? 'Step ${j + 1} of ${counted.length}'
                                  : steps[counted[j]].optional
                                  ? 'Optional'
                                  : null,
                              showConnector: j < counted.length - 1,
                            ),
                          const Spacer(),
                          const SizedBox(height: PortalTheme.space5),
                          const _WhyWeAsk(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Gold "BSIT • Batch 2024" style pill used on navy surfaces.
class OnboardingGoldPill extends StatelessWidget {
  const OnboardingGoldPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PortalTheme.gold,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PortalTheme.caption.copyWith(
          color: PortalTheme.navy,
          fontWeight: FontWeight.w800,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

enum _StepState { done, active, upcoming }

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.number,
    required this.info,
    required this.state,
    required this.caption,
    required this.showConnector,
  });

  final int number;
  final OnboardingStepInfo info;
  final _StepState state;
  final String? caption;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final active = state == _StepState.active;
    final done = state == _StepState.done;

    final circle = AnimatedContainer(
      duration: PortalTheme.normal,
      curve: PortalTheme.ease,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? PortalTheme.success
            : active
            ? PortalTheme.gold
            : Colors.transparent,
        border: Border.all(
          color: done || active
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Text(
              '$number',
              style: PortalTheme.meta.copyWith(
                fontWeight: FontWeight.w800,
                color: active ? PortalTheme.navy : Colors.white,
              ),
            ),
    );

    final status = switch (state) {
      _StepState.done => 'completed',
      _StepState.active => 'current step',
      _StepState.upcoming => 'not started',
    };

    return Semantics(
      label: '${info.label}, $status',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  circle,
                  if (showConnector)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: done
                            ? PortalTheme.success.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: PortalTheme.space2),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    bottom: showConnector ? PortalTheme.space4 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.label,
                        style: PortalTheme.body.copyWith(
                          color: active || done
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.72),
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (caption != null)
                        Text(
                          caption!,
                          style: PortalTheme.meta.copyWith(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhyWeAsk extends StatelessWidget {
  const _WhyWeAsk();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PortalTheme.space3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: PortalTheme.space2),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Why we ask\n',
                    style: PortalTheme.meta.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:
                        'CHED asks every university to keep Graduate Tracer '
                        'records. Your answers update your alumni record.',
                    style: PortalTheme.meta.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});

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

/// Step title + one-line explanation.
class OnboardingSectionHeading extends StatelessWidget {
  const OnboardingSectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: PortalTheme.sectionTitle.copyWith(color: PortalTheme.navy),
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: PortalTheme.bodySecondary),
      ],
    );
  }
}

/// Step heading with a small ring showing this step's required fields.
class OnboardingSectionIntro extends StatelessWidget {
  const OnboardingSectionIntro({
    super.key,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.total,
  });

  final String title;
  final String subtitle;
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && filled >= total;
    final ratio = total == 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: OnboardingSectionHeading(title: title, subtitle: subtitle),
        ),
        const SizedBox(width: PortalTheme.space2),
        Semantics(
          label: '$filled of $total required fields filled',
          child: ExcludeSemantics(
            child: SizedBox(
              width: 52,
              height: 52,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: ratio),
                duration: PortalTheme.slow,
                curve: PortalTheme.ease,
                builder: (context, value, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 4,
                      backgroundColor: PortalTheme.border,
                      color: complete ? PortalTheme.success : PortalTheme.gold,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: complete
                          ? const Icon(
                              Icons.check_rounded,
                              size: 22,
                              color: PortalTheme.success,
                            )
                          : Text(
                              '$filled/$total',
                              style: PortalTheme.meta.copyWith(
                                fontWeight: FontWeight.w800,
                                color: PortalTheme.navy,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft gold encouragement / hint box.
class OnboardingTip extends StatelessWidget {
  const OnboardingTip({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PortalTheme.space3,
        vertical: PortalTheme.space2,
      ),
      decoration: BoxDecoration(
        color: PortalTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: PortalTheme.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: PortalTheme.navy),
          const SizedBox(width: PortalTheme.space2),
          Expanded(
            child: Text(
              message,
              style: PortalTheme.meta.copyWith(
                color: PortalTheme.navy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back / primary / optional tertiary buttons. Sticky white bar on phones;
/// inline card footer on desktop.
class OnboardingActionBar extends StatelessWidget {
  const OnboardingActionBar({
    super.key,
    required this.actions,
    required this.wide,
  });

  final OnboardingActions actions;
  final bool wide;

  static final _minHeight = WidgetStateProperty.all(const Size(0, 48));

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton(
      onPressed: actions.primaryLoading ? null : actions.onPrimary,
      style: PortalTheme.primaryButton().copyWith(minimumSize: _minHeight),
      child: actions.primaryLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    actions.primaryLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions.showArrow) ...[
                  const SizedBox(width: PortalTheme.space1),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ],
            ),
    );

    final back = actions.onBack == null
        ? null
        : OutlinedButton(
            onPressed: actions.primaryLoading ? null : actions.onBack,
            style: PortalTheme.secondaryButton().copyWith(
              minimumSize: _minHeight,
            ),
            child: const Text('Back'),
          );

    final tertiary = actions.tertiaryLabel == null
        ? null
        : TextButton(
            onPressed: actions.primaryLoading ? null : actions.onTertiary,
            style: PortalTheme.ghostButton().copyWith(
              foregroundColor: WidgetStateProperty.all(
                PortalTheme.textSecondary,
              ),
              minimumSize: _minHeight,
            ),
            child: Text(actions.tertiaryLabel!),
          );

    if (wide) {
      return Row(
        children: [
          if (back != null) back,
          const Spacer(),
          if (tertiary != null) ...[
            tertiary,
            const SizedBox(width: PortalTheme.space1),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180),
            child: primary,
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PortalTheme.card,
        border: Border(
          top: BorderSide(color: PortalTheme.border.withValues(alpha: 0.9)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PortalTheme.space3,
            PortalTheme.space2,
            PortalTheme.space3,
            PortalTheme.space2,
          ),
          child: Center(
            // Scaffold.bottomNavigationBar offers the full screen height.
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OnboardingLayout.compactContentMax,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (back != null) ...[
                        back,
                        const SizedBox(width: PortalTheme.space2),
                      ],
                      Expanded(child: primary),
                    ],
                  ),
                  if (tertiary != null) ...[
                    const SizedBox(height: 4),
                    tertiary,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
