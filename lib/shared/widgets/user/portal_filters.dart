import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Search box used above the Events, Jobs and Community lists.
class PortalSearchField extends StatelessWidget {
  const PortalSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.textInputAction,
  });

  static const double height = 44;

  final TextEditingController controller;
  final String hintText;

  /// Also called with `''` when the clear button is pressed.
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(PortalTheme.radiusMd);
    return SizedBox(
      height: height,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: textInputAction,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: PortalTheme.body,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: PortalTheme.bodySecondary,
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: PortalTheme.textSecondary,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
            filled: true,
            fillColor: PortalTheme.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: PortalTheme.navy, width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped filter used under [PortalSearchField]: navy when [selected],
/// light grey otherwise.
class PortalFilterChip extends StatelessWidget {
  const PortalFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.trailingIcon,
  });

  static const double height = 36;

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : PortalTheme.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? PortalTheme.navy : PortalTheme.surfaceMuted,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? PortalTheme.navy : PortalTheme.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: foreground),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 2),
                  Icon(trailingIcon, size: 16, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [PortalFilterChip] that opens a single-choice menu below itself.
class PortalDropdownChip<T> extends StatelessWidget {
  const PortalDropdownChip({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.selected = false,
    this.icon,
  });

  final T value;

  /// `(value, label)` pairs; the chip shows the label of [value].
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final bool selected;
  final IconData? icon;

  Future<void> _open(BuildContext context) async {
    final chip = context.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        chip.localToGlobal(Offset(0, chip.size.height + 4), ancestor: overlay),
        chip.localToGlobal(
          chip.size.bottomRight(const Offset(0, 4)),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final picked = await showMenu<T>(
      context: context,
      position: position,
      items: [
        for (final item in items)
          portalMenuItem(
            value: item.$1,
            label: item.$2,
            selected: item.$1 == value,
          ),
      ],
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = items
        .firstWhere((e) => e.$1 == value, orElse: () => items.first)
        .$2;
    return Builder(
      builder: (chipContext) => PortalFilterChip(
        label: label,
        icon: icon,
        trailingIcon: Icons.expand_more_rounded,
        selected: selected,
        onTap: () => _open(chipContext),
      ),
    );
  }
}

/// A horizontally scrolling filter row with an edge feather-fade indicator
/// when additional filters extend beyond the visible screen width.
class PortalScrollableFilterRow extends StatefulWidget {
  const PortalScrollableFilterRow({
    super.key,
    required this.children,
    this.height = PortalFilterChip.height,
    this.fadeWidth = 36.0,
    this.fadeColor = Colors.white,
  })  : itemCount = null,
        itemBuilder = null,
        separatorWidth = 8.0;

  const PortalScrollableFilterRow.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorWidth = 8.0,
    this.height = PortalFilterChip.height,
    this.fadeWidth = 36.0,
    this.fadeColor = Colors.white,
  }) : children = null;

  final List<Widget>? children;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final double separatorWidth;
  final double height;
  final double fadeWidth;
  final Color fadeColor;

  @override
  State<PortalScrollableFilterRow> createState() =>
      _PortalScrollableFilterRowState();
}

class _PortalScrollableFilterRowState
    extends State<PortalScrollableFilterRow> {
  final _controller = ScrollController();
  bool _canScrollRight = false;
  bool _canScrollLeft = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_controller.hasClients) return;
    final pos = _controller.position;
    final nextRight = pos.maxScrollExtent - pos.pixels > 4;
    final nextLeft = pos.pixels > 4;
    if (nextRight != _canScrollRight || nextLeft != _canScrollLeft) {
      setState(() {
        _canScrollRight = nextRight;
        _canScrollLeft = nextLeft;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _update());
          return false;
        },
        child: Stack(
          children: [
            if (widget.itemBuilder != null)
              ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                itemCount: widget.itemCount!,
                separatorBuilder: (_, __) =>
                    SizedBox(width: widget.separatorWidth),
                itemBuilder: widget.itemBuilder!,
              )
            else
              SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                child: Row(
                  children: widget.children!,
                ),
              ),
            if (_canScrollLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: widget.fadeWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.fadeColor,
                          widget.fadeColor.withValues(alpha: 0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
            if (_canScrollRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: widget.fadeWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.fadeColor.withValues(alpha: 0),
                          widget.fadeColor,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
