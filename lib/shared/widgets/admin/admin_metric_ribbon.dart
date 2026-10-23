import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// An individual metric item inside [AdminMetricRibbon].
class AdminMetricRibbonItem {
  const AdminMetricRibbonItem({
    required this.label,
    required this.value,
    this.icon,
    this.color = AdminColors.primary,
    this.isSelected = false,
    this.onTap,
    this.tooltip,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;
  final String? tooltip;
}

/// Balanced SaaS KPI metrics row.
///
/// Provides executive-level glanceability with balanced breathing room (~72px height),
/// clear icon chips, bold numbers, and interactive 1-click filter capabilities.
class AdminMetricRibbon extends StatefulWidget {
  const AdminMetricRibbon({
    super.key,
    required this.items,
    this.collapsible = false,
    this.initiallyCollapsed = false,
    this.onCollapseChanged,
    this.cardHeight = 72.0,
  });

  final List<AdminMetricRibbonItem> items;
  final bool collapsible;
  final bool initiallyCollapsed;
  final ValueChanged<bool>? onCollapseChanged;
  final double cardHeight;

  @override
  State<AdminMetricRibbon> createState() => _AdminMetricRibbonState();
}

class _AdminMetricRibbonState extends State<AdminMetricRibbon> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.initiallyCollapsed;
  }

  void _toggleCollapsed() {
    setState(() {
      _collapsed = !_collapsed;
    });
    widget.onCollapseChanged?.call(_collapsed);
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bar_chart_rounded,
              size: 16,
              color: AdminColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.items.length} metrics collapsed',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AdminColors.textSecondary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _toggleCollapsed,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              label: const Text('Show metrics'),
              style: TextButton.styleFrom(
                foregroundColor: AdminColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 780;

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _buildMetricCard(widget.items[i])),
              ],
              if (widget.collapsible) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Collapse metrics',
                  child: InkWell(
                    onTap: _toggleCollapsed,
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                    child: Container(
                      height: widget.cardHeight,
                      width: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 16,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        }

        final columns = width >= 480 ? 2 : 1;
        const spacing = 10.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in widget.items)
              SizedBox(width: itemWidth, child: _buildMetricCard(item)),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(AdminMetricRibbonItem item) {
    final isSelected = item.isSelected;
    final isClickable = item.onTap != null;

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? item.color.withValues(alpha: 0.05)
                : AdminColors.card,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            border: Border.all(
              color: isSelected ? item.color : AdminColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected ? null : AdminSurfaces.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (item.icon != null)
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        item.icon,
                        size: 15,
                        color: item.color,
                      ),
                    )
                  else
                    const SizedBox(height: 28),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? item.color : AdminColors.textPrimary,
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? item.color : AdminColors.textSecondary,
                      ),
                    ),
                  ),
                  if (isClickable)
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                      size: 14,
                      color: isSelected ? item.color : AdminColors.textMuted.withValues(alpha: 0.6),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (item.tooltip != null && item.tooltip!.isNotEmpty) {
      return Tooltip(
        message: item.tooltip!,
        waitDuration: const Duration(milliseconds: 300),
        child: card,
      );
    }

    return card;
  }
}
