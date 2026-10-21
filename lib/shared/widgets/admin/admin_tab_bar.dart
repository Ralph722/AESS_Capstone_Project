import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

class AdminTabSpec {
  const AdminTabSpec({required this.label, this.icon, this.count});

  final String label;
  final IconData? icon;
  final int? count;
}

/// Underline tabs with a label-sized indicator.
///
/// Drive it with an existing [TabController], or with [selectedIndex] +
/// [onSelected] when the screen keeps its own tab state (the bar then only
/// moves when [selectedIndex] changes).
class AdminTabBar extends StatefulWidget {
  const AdminTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.selectedIndex,
    this.onSelected,
    this.isScrollable = true,
    this.background = AdminColors.card,
  }) : assert(
         (controller == null) != (selectedIndex == null),
         'Provide either controller or selectedIndex',
       );

  final List<AdminTabSpec> tabs;
  final TabController? controller;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;

  /// Left-aligned and horizontally scrollable when true; evenly spaced
  /// across the width when false.
  final bool isScrollable;
  final Color background;

  @override
  State<AdminTabBar> createState() => _AdminTabBarState();
}

class _AdminTabBarState extends State<AdminTabBar>
    with SingleTickerProviderStateMixin {
  TabController? _internal;

  TabController get _controller => widget.controller ?? _internal!;

  @override
  void initState() {
    super.initState();
    _syncInternalController();
  }

  @override
  void didUpdateWidget(covariant AdminTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null) {
      _internal?.dispose();
      _internal = null;
      return;
    }
    if (_internal != null && _internal!.length != widget.tabs.length) {
      _internal!.dispose();
      _internal = null;
    }
    _syncInternalController();
  }

  void _syncInternalController() {
    final selected = widget.selectedIndex;
    if (widget.controller != null || selected == null) return;
    final index = selected.clamp(0, widget.tabs.length - 1);
    if (_internal == null) {
      _internal = TabController(
        length: widget.tabs.length,
        initialIndex: index,
        vsync: this,
      );
    } else if (_internal!.index != index) {
      _internal!.animateTo(index);
    }
  }

  void _handleTap(int index) {
    widget.onSelected?.call(index);
    if (_internal == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _internal == null) return;
      final selected = widget.selectedIndex!;
      if (_internal!.index != selected) _internal!.animateTo(selected);
    });
  }

  @override
  void dispose() {
    _internal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.tabs.isNotEmpty);
    final controller = _controller;

    return Material(
      color: widget.background,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AdminColors.border)),
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final selected = controller.index;
            return TabBar(
              controller: controller,
              onTap: _handleTap,
              isScrollable: widget.isScrollable,
              tabAlignment: widget.isScrollable
                  ? TabAlignment.start
                  : TabAlignment.fill,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: AdminColors.primary,
              indicatorWeight: 2.5,
              labelColor: AdminColors.primary,
              unselectedLabelColor: AdminColors.textSecondary,
              labelStyle: AdminText.tabActive,
              unselectedLabelStyle: AdminText.tab,
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.pressed)) {
                  return AdminColors.primary.withValues(alpha: 0.06);
                }
                return Colors.transparent;
              }),
              tabs: [
                for (var i = 0; i < widget.tabs.length; i++)
                  Tab(
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.tabs[i].icon != null) ...[
                          Icon(widget.tabs[i].icon, size: 17),
                          const SizedBox(width: 7),
                        ],
                        Text(widget.tabs[i].label),
                        if (widget.tabs[i].count != null) ...[
                          const SizedBox(width: 7),
                          _AdminTabCountBadge(
                            count: widget.tabs[i].count!,
                            selected: i == selected,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminTabCountBadge extends StatelessWidget {
  const _AdminTabCountBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = count > 999 ? '999+' : '$count';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? AdminColors.primary.withValues(alpha: 0.12)
            : AdminColors.infoBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? AdminColors.primary.withValues(alpha: 0.22)
              : Colors.transparent,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: selected ? AdminColors.primary : AdminColors.textSecondary,
        ),
      ),
    );
  }
}
