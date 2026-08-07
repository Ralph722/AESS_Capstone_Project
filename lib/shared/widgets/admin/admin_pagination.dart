/// Client-side pagination chrome for the Admin Portal.
///
/// Slices in-memory filtered lists — no API/service changes. Pair with
/// [AdminDataTable] for dense desktop lists that can grow large.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Default page size options for admin lists.
const List<int> kAdminPageSizeOptions = [25, 50, 100];

/// Returns a 0-based page slice of [items].
List<T> adminPaginate<T>(List<T> items, int page, int pageSize) {
  if (items.isEmpty || pageSize <= 0) return <T>[];
  final start = page * pageSize;
  if (start >= items.length) return <T>[];
  final end = math.min(start + pageSize, items.length);
  return items.sublist(start, end);
}

/// Number of pages for [totalItems] given [pageSize].
int adminPageCount(int totalItems, int pageSize) {
  if (totalItems <= 0 || pageSize <= 0) return 1;
  return ((totalItems + pageSize - 1) / pageSize).ceil();
}

/// Clamps [page] into a valid range for the current totals.
int adminClampPage(int page, int totalItems, int pageSize) {
  final count = adminPageCount(totalItems, pageSize);
  if (page < 0) return 0;
  if (page >= count) return count - 1;
  return page;
}

/// Compact pagination bar: “Showing X–Y of Z” + prev/next + page size.
class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    super.key,
    required this.totalItems,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.pageSizeOptions = kAdminPageSizeOptions,
    this.dense = false,
  });

  final int totalItems;

  /// 0-based page index.
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final List<int> pageSizeOptions;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    final pageCount = adminPageCount(totalItems, pageSize);
    final safePage = adminClampPage(page, totalItems, pageSize);
    final start = safePage * pageSize + 1;
    final end = math.min((safePage + 1) * pageSize, totalItems);

    return Material(
      color: AdminTableTheme.headerBg,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 16,
          vertical: dense ? 8 : 10,
        ),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AdminTableTheme.border),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 560;
            final rangeLabel = Text(
              'Showing $start–$end of $totalItems',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminTableTheme.textSecondary,
              ),
            );

            final controls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onPageSizeChanged != null) ...[
                  const Text(
                    'Rows',
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminTableTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: pageSizeOptions.contains(pageSize)
                          ? pageSize
                          : pageSizeOptions.first,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminTableTheme.textPrimary,
                      ),
                      items: [
                        for (final size in pageSizeOptions)
                          DropdownMenuItem(
                            value: size,
                            child: Text('$size'),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) onPageSizeChanged!(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: safePage > 0
                      ? () => onPageChanged(safePage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  style: AdminDensity.iconButtonStyle(),
                ),
                Text(
                  'Page ${safePage + 1} of $pageCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminTableTheme.textPrimary,
                  ),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: safePage < pageCount - 1
                      ? () => onPageChanged(safePage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 20),
                  style: AdminDensity.iconButtonStyle(),
                ),
              ],
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  rangeLabel,
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: controls),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: rangeLabel),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }
}
