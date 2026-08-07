/// Shared desktop data-table chrome for the Admin Portal.
///
/// Presentational only — sorting, filtering, pagination, and selection state
/// stay in the calling screen. Rows are dense, hoverable, and aligned to a
/// sticky column header so lists scan like Firebase Console / GitHub tables
/// rather than mobile card stacks.
library;

import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Visual tokens for admin tables (aligned with directory/survey navy).
abstract final class AdminTableTheme {
  static const Color primary = Color(0xFF1A1851);
  static const Color headerBg = Color(0xFFF8FAFC);
  static const Color rowBg = Colors.white;
  static const Color rowHover = Color(0xFFF1F5F9);
  static const Color rowSelected = Color(0xFFE8E7F2);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFEA580C);
  static const Color warningBg = Color(0xFFFFF7ED);

  static const double headerHeight = AdminDensity.tableHeaderHeight;
  static const double rowMinHeight = AdminDensity.tableRowMinHeight;
  static const double horizontalPadding = AdminDensity.tableHorizontalPadding;
  static const double cellGap = AdminDensity.tableCellGap;
}

/// Column definition for [AdminDataHeader] / [AdminDataRow].
class AdminDataColumn {
  const AdminDataColumn({
    required this.label,
    this.flex = 1,
    this.width,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final int flex;

  /// When set, the column uses a fixed width instead of [flex].
  final double? width;
  final Alignment alignment;
}

/// Sticky-looking column header bar.
class AdminDataHeader extends StatelessWidget {
  const AdminDataHeader({
    super.key,
    required this.columns,
    this.leading,
    this.trailing,
    this.leadingWidth = 40,
    this.trailingWidth = 40,
  });

  final List<AdminDataColumn> columns;
  final Widget? leading;
  final Widget? trailing;
  final double leadingWidth;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminTableTheme.headerBg,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: AdminTableTheme.headerHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTableTheme.horizontalPadding,
          vertical: 6,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AdminTableTheme.border),
          ),
        ),
        child: Row(
          children: [
            if (leading != null)
              SizedBox(width: leadingWidth, child: leading)
            else if (leadingWidth > 0 && leading == null)
              const SizedBox.shrink(),
            if (leading != null) const SizedBox(width: 4),
            ..._buildCells(columns, isHeader: true),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              SizedBox(width: trailingWidth, child: trailing),
            ],
          ],
        ),
      ),
    );
  }
}

/// One dense, hoverable table row. [cells] must align 1:1 with the header
/// columns (same flex/width contract).
class AdminDataRow extends StatefulWidget {
  const AdminDataRow({
    super.key,
    required this.columns,
    required this.cells,
    this.leading,
    this.trailing,
    this.leadingWidth = 40,
    this.trailingWidth = 40,
    this.onTap,
    this.selected = false,
    this.minHeight = AdminTableTheme.rowMinHeight,
  }) : assert(cells.length == columns.length);

  final List<AdminDataColumn> columns;
  final List<Widget> cells;
  final Widget? leading;
  final Widget? trailing;
  final double leadingWidth;
  final double trailingWidth;
  final VoidCallback? onTap;
  final bool selected;
  final double minHeight;

  @override
  State<AdminDataRow> createState() => _AdminDataRowState();
}

class _AdminDataRowState extends State<AdminDataRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? AdminTableTheme.rowSelected
        : _hovered
            ? AdminTableTheme.rowHover
            : AdminTableTheme.rowBg;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          canRequestFocus: widget.onTap != null,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return AdminTableTheme.primary.withValues(alpha: 0.12);
            }
            return Colors.transparent;
          }),
          child: Container(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTableTheme.horizontalPadding,
              vertical: 6,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AdminTableTheme.border),
              ),
            ),
            child: Row(
              children: [
                if (widget.leading != null)
                  SizedBox(width: widget.leadingWidth, child: widget.leading),
                if (widget.leading != null) const SizedBox(width: 4),
                ..._buildCells(
                  widget.columns,
                  cells: widget.cells,
                  isHeader: false,
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: widget.trailingWidth,
                    child: widget.trailing,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header + scrollable body for desktop admin lists.
///
/// Use [shrinkWrap] when embedding inside an outer scroll view (e.g. Activity
/// Logs). Otherwise the table expands and owns its own scroll.
class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
    this.leadingHeader,
    this.trailingHeader,
    this.leadingWidth = 40,
    this.trailingWidth = 40,
    this.shrinkWrap = false,
    this.physics,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 12,
    this.showBorder = true,
  });

  final List<AdminDataColumn> columns;
  final int rowCount;
  final Widget Function(BuildContext context, int index) rowBuilder;
  final Widget? leadingHeader;
  final Widget? trailingHeader;
  final double leadingWidth;
  final double trailingWidth;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final header = AdminDataHeader(
      columns: columns,
      leading: leadingHeader,
      trailing: trailingHeader,
      leadingWidth: leadingHeader == null ? 0 : leadingWidth,
      trailingWidth: trailingHeader == null ? 0 : trailingWidth,
    );

    final list = ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ??
          (shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics()),
      itemCount: rowCount,
      itemBuilder: rowBuilder,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (shrinkWrap) list else Expanded(child: list),
      ],
    );

    final framed = showBorder
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: AdminTableTheme.rowBg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: AdminTableTheme.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: body,
            ),
          )
        : body;

    if (padding == EdgeInsets.zero) return framed;
    return Padding(padding: padding, child: framed);
  }
}

/// Compact status / meta badge used inside table cells.
class AdminTableBadge extends StatelessWidget {
  const AdminTableBadge({
    super.key,
    required this.label,
    this.bg = AdminTableTheme.headerBg,
    this.fg = AdminTableTheme.textSecondary,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary / secondary text pair for identity cells (name + email).
class AdminTableIdentityCell extends StatelessWidget {
  const AdminTableIdentityCell({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminTableTheme.textPrimary,
                  height: 1.25,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminTableTheme.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Plain ellipsis text cell.
class AdminTableTextCell extends StatelessWidget {
  const AdminTableTextCell(
    this.text, {
    super.key,
    this.muted = false,
    this.bold = false,
    this.maxLines = 1,
  });

  final String text;
  final bool muted;
  final bool bold;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.isEmpty ? '—' : text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
        color: muted || text.isEmpty
            ? AdminTableTheme.textMuted
            : AdminTableTheme.textPrimary,
        height: 1.25,
      ),
    );
  }
}

List<Widget> _buildCells(
  List<AdminDataColumn> columns, {
  List<Widget>? cells,
  required bool isHeader,
}) {
  final out = <Widget>[];
  for (var i = 0; i < columns.length; i++) {
    if (i > 0) out.add(const SizedBox(width: AdminTableTheme.cellGap));
    final col = columns[i];
    final child = isHeader
        ? Align(
            alignment: col.alignment,
            child: Text(
              col.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AdminTableTheme.textSecondary,
              ),
            ),
          )
        : Align(
            alignment: col.alignment,
            child: cells![i],
          );

    if (col.width != null) {
      out.add(SizedBox(width: col.width, child: child));
    } else {
      out.add(Expanded(flex: col.flex, child: child));
    }
  }
  return out;
}
