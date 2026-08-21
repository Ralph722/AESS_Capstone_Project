import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Shared portal chrome — consistent geometry across every user screen.
///
/// Content varies by screen; height, padding, title baseline, and icon sizing
/// stay fixed so navigation between tabs does not "jump".

/// Standard top app bar for list / hub / detail screens.
///
/// Use as [Scaffold.appBar] with [primary] true (default), or inline inside a
/// [Column]/[Stack] with [primary] false so height stays bounded.
class PortalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PortalAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.foreground = PortalAppBarTone.light,
    this.primary = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final PortalAppBarTone foreground;

  /// When false, builds a fixed-height inline toolbar (safe inside [Column]).
  final bool primary;

  bool get _dark => foreground == PortalAppBarTone.dark;

  @override
  Size get preferredSize {
    // Default hairline border is 1px when [bottom] is omitted.
    final bottomH = bottom?.preferredSize.height ?? 1;
    return Size.fromHeight(PortalTheme.headerHeight + bottomH);
  }

  @override
  Widget build(BuildContext context) {
    final fg = _dark ? PortalTheme.textOnNavy : PortalTheme.navy;
    final bg = _dark ? PortalTheme.navy : Colors.white;
    final borderColor = _dark
        ? Colors.transparent
        : PortalTheme.border.withValues(alpha: 0.9);

    // Subtitles are intentionally omitted for a cleaner header.
    final hasLeading = leading != null ||
        (automaticallyImplyLeading && Navigator.canPop(context));
    final titleWidget = Text(
      title,
      style: (_dark ? PortalTheme.pageTitleOnDark : PortalTheme.pageTitle)
          .copyWith(color: fg),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final hairline = bottom ??
        PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        );

    // Inline mode: never use Material [AppBar] (needs Scaffold height).
    if (!primary) {
      return Material(
        color: bg,
        child: SizedBox(
          height: preferredSize.height,
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: PortalTheme.headerHeight,
                child: IconTheme(
                  data: IconThemeData(
                    color: fg,
                    size: PortalTheme.headerIconSize,
                  ),
                  child: NavigationToolbar(
                    leading: leading ??
                        (automaticallyImplyLeading && Navigator.canPop(context)
                            ? BackButton(color: fg, onPressed: () => Navigator.maybePop(context))
                            : null),
                    middle: Align(
                      alignment: centerTitle
                          ? Alignment.center
                          : Alignment.centerLeft,
                      child: titleWidget,
                    ),
                    trailing: actions == null
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...actions!,
                              const SizedBox(width: PortalTheme.headerHPad),
                            ],
                          ),
                    centerMiddle: centerTitle,
                    middleSpacing: hasLeading ? 8 : PortalTheme.headerHPad,
                  ),
                ),
              ),
              SizedBox(
                height: hairline.preferredSize.height,
                width: double.infinity,
                child: hairline,
              ),
            ],
          ),
        ),
      );
    }

    return AppBar(
      primary: true,
      toolbarHeight: PortalTheme.headerHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      backgroundColor: bg,
      foregroundColor: fg,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      leadingWidth: hasLeading ? 56 : 0,
      iconTheme: IconThemeData(color: fg, size: PortalTheme.headerIconSize),
      actionsIconTheme:
          IconThemeData(color: fg, size: PortalTheme.headerIconSize),
      // Keep title off the screen edge when there is no leading control.
      titleSpacing: hasLeading ? 8 : PortalTheme.headerHPad,
      title: titleWidget,
      actions: actions == null
          ? null
          : [
              ...actions!,
              const SizedBox(width: PortalTheme.headerHPad),
            ],
      bottom: hairline,
    );
  }
}

enum PortalAppBarTone { light, dark }

/// Compact icon action sized to [PortalTheme.headerActionSize].
class PortalHeaderAction extends StatelessWidget {
  const PortalHeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount != null && badgeCount! > 0;
    return SizedBox(
      width: PortalTheme.headerActionSize,
      height: PortalTheme.headerActionSize,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Badge(
          isLabelVisible: showBadge,
          backgroundColor: PortalTheme.badge,
          label: Text(
            (badgeCount ?? 0) > 99 ? '99+' : '${badgeCount ?? 0}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          child: Icon(icon, size: PortalTheme.headerIconSize),
        ),
      ),
    );
  }
}

/// In-body section title with optional trailing action (not an AppBar).
class PortalSectionHeader extends StatelessWidget {
  const PortalSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PortalTheme.sectionTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: PortalTheme.bodySecondary),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: PortalTheme.ghostButton(dense: true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft page intro under the app bar (title already in AppBar → use for context).
class PortalPageIntro extends StatelessWidget {
  const PortalPageIntro({
    super.key,
    required this.headline,
    this.body,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 16),
  });

  final String headline;
  final String? body;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: PortalTheme.display.copyWith(fontSize: 24)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, style: PortalTheme.bodySecondary),
          ],
        ],
      ),
    );
  }
}

/// Status / category chip used across portal surfaces.
class PortalChip extends StatelessWidget {
  const PortalChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = PortalChipTone.neutral,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final PortalChipTone tone;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? PortalTheme.navy : colors.$1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? PortalTheme.navy : colors.$2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : colors.$3,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: PortalTheme.caption.copyWith(
              color: selected ? Colors.white : colors.$3,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: child,
    );
  }

  (Color, Color, Color) get _colors {
    switch (tone) {
      case PortalChipTone.neutral:
        return (
          PortalTheme.surfaceMuted,
          PortalTheme.border,
          PortalTheme.textSecondary,
        );
      case PortalChipTone.brand:
        return (
          PortalTheme.navy.withValues(alpha: 0.08),
          PortalTheme.navy.withValues(alpha: 0.2),
          PortalTheme.navy,
        );
      case PortalChipTone.gold:
        return (
          PortalTheme.gold.withValues(alpha: 0.2),
          PortalTheme.gold.withValues(alpha: 0.5),
          PortalTheme.navy,
        );
      case PortalChipTone.success:
        return (
          PortalTheme.success.withValues(alpha: 0.1),
          PortalTheme.success.withValues(alpha: 0.25),
          PortalTheme.success,
        );
      case PortalChipTone.warning:
        return (
          PortalTheme.warning.withValues(alpha: 0.12),
          PortalTheme.warning.withValues(alpha: 0.3),
          PortalTheme.warning,
        );
      case PortalChipTone.danger:
        return (
          PortalTheme.danger.withValues(alpha: 0.1),
          PortalTheme.danger.withValues(alpha: 0.25),
          PortalTheme.danger,
        );
    }
  }
}

enum PortalChipTone { neutral, brand, gold, success, warning, danger }

/// Highlight panel for primary CTAs / needs-attention (not a generic white card).
class PortalHighlightPanel extends StatelessWidget {
  const PortalHighlightPanel({
    super.key,
    required this.child,
    this.variant = PortalHighlightVariant.navy,
    this.onTap,
    this.margin,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final PortalHighlightVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final decoration = switch (variant) {
      PortalHighlightVariant.navy => BoxDecoration(
          gradient: PortalTheme.heroGradient,
          borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
          boxShadow: PortalTheme.elevatedShadow,
        ),
      PortalHighlightVariant.soft => BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
          border: Border.all(
            color: PortalTheme.border.withValues(alpha: 0.75),
          ),
          boxShadow: PortalTheme.softShadow,
        ),
      PortalHighlightVariant.goldEdge => BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
          border: Border.all(color: PortalTheme.gold, width: 1.5),
          boxShadow: PortalTheme.cardShadow,
        ),
      PortalHighlightVariant.attention => BoxDecoration(
          color: const Color(0xFFFFF8EB),
          borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
          border: Border.all(color: PortalTheme.gold.withValues(alpha: 0.65)),
        ),
    };

    final content = Container(
      margin: margin,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return content;
  }
}

enum PortalHighlightVariant { navy, soft, goldEdge, attention }
