import 'package:flutter/material.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';

/// Shared polish helpers for Reports & Analytics (presentation only).
abstract final class ReportsPolish {
  static const animFast = Duration(milliseconds: 180);
  static const animMed = Duration(milliseconds: 260);
  static const minTap = 44.0;

  static Widget fadeSlideSwitcher({
    required Widget child,
    Duration duration = animMed,
  }) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset =
            Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }
}

/// Hoverable surface used by charts and report cards.
///
/// Hover/focus only rebuilds decoration via [ValueNotifier] so heavy children
/// (fl_chart) are not recreated under the pointer — avoids mouse_tracker
/// recursion and chart swap-animation lag.
class ReportsHoverSurface extends StatefulWidget {
  const ReportsHoverSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<ReportsHoverSurface> createState() => _ReportsHoverSurfaceState();
}

class _ReportsHoverSurfaceState extends State<ReportsHoverSurface> {
  final ValueNotifier<bool> _hovered = ValueNotifier(false);
  final ValueNotifier<bool> _focused = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    _focused.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ??
        BorderRadius.circular(AdminReportsTheme.radiusLg);

    Widget surface = ListenableBuilder(
      listenable: Listenable.merge([_hovered, _focused]),
      child: widget.child,
      builder: (context, child) {
        final highlight = _hovered.value || _focused.value;
        return AnimatedContainer(
          duration: ReportsPolish.animFast,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: highlight
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
    );

    if (widget.onTap != null) {
      surface = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          onHover: (v) => _hovered.value = v,
          onFocusChange: (v) => _focused.value = v,
          child: surface,
        ),
      );
    } else {
      surface = MouseRegion(
        hitTestBehavior: HitTestBehavior.deferToChild,
        onEnter: (_) => _hovered.value = true,
        onExit: (_) => _hovered.value = false,
        child: FocusableActionDetector(
          onShowFocusHighlight: (v) => _focused.value = v,
          child: surface,
        ),
      );
    }

    if (widget.semanticLabel != null) {
      surface = Semantics(
        label: widget.semanticLabel,
        container: true,
        child: surface,
      );
    }

    return surface;
  }
}

/// Friendly empty panel for a whole analytics section.
class ReportsSectionEmptyState extends StatelessWidget {
  const ReportsSectionEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminReportsTheme.space3,
          vertical: 28,
        ),
        decoration: BoxDecoration(
          color: AdminReportsTheme.card,
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(color: AdminReportsTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AdminReportsTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AdminReportsTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AdminReportsTheme.textSecondary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminReportsTheme.primary,
                  minimumSize: const Size(0, ReportsPolish.minTap),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
