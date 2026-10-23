import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Specification for a tab in [AdminSaaSToolbar] (for backwards compatibility).
class AdminSaaSTab {
  const AdminSaaSTab({
    required this.label,
    this.icon,
    this.count,
    this.isSelected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final int? count;
  final bool isSelected;
  final VoidCallback? onTap;
}

/// A responsive SaaS toolbar that cleanly handles search, filter dropdowns,
/// active filter chips, and reload actions without overflowing.
class AdminSaaSToolbar extends StatelessWidget {
  const AdminSaaSToolbar({
    super.key,
    this.tabs = const [],
    this.searchController,
    this.onSearchChanged,
    this.onClearSearch,
    this.searchHint = 'Search…',
    this.searchWidth = 270,
    this.filters = const [],
    this.sortControl,
    this.trailingActions = const [],
    this.hasActiveFilters = false,
    this.onResetFilters,
    this.onRefresh,
    this.isLoading = false,
    this.refreshTooltip = 'Refresh',
    this.resultsCountText,
    this.activeFilterChips = const [],
    this.singleRowBreakpoint = 960,
  });

  /// Optional view tabs (if embedded in toolbar; prefer standalone [AdminSaaSTabs]).
  final List<AdminSaaSTab> tabs;

  /// Optional active filter chips shown when filters are engaged.
  final List<Widget> activeFilterChips;

  /// Controller for search input.
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClearSearch;
  final String searchHint;
  final double searchWidth;

  /// Custom filter widgets (e.g. [DirectoryFilterField]s or compact dropdowns).
  final List<Widget> filters;

  /// Standalone sort control placed in the right-hand zone of the toolbar.
  final Widget? sortControl;

  /// Additional trailing action widgets placed in the right-hand zone.
  final List<Widget> trailingActions;

  /// Whether any filters (search or dropdowns) are currently non-default.
  final bool hasActiveFilters;

  /// Callback when user clicks Reset / Clear filters.
  final VoidCallback? onResetFilters;

  /// Callback when user clicks reload.
  final VoidCallback? onRefresh;
  final bool isLoading;
  final String refreshTooltip;

  /// Optional inline summary (kept for compatibility, omitted when null).
  final String? resultsCountText;

  /// Breakpoint width above which everything sits on a single row.
  final double singleRowBreakpoint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
        boxShadow: AdminSurfaces.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (tabs.isEmpty) {
            return _buildDedicatedFiltersRow(constraints.maxWidth);
          }
          final isWide = constraints.maxWidth >= singleRowBreakpoint;
          if (isWide) {
            return _buildSingleRowWithTabs();
          }
          return _buildTwoRows(constraints.maxWidth);
        },
      ),
    );
  }

  /// Modern SaaS two-zone row:
  /// - Left zone: Search box + Filter dropdowns + Reset button.
  /// - Right zone: Sort dropdown + Trailing actions + Refresh button.
  Widget _buildDedicatedFiltersRow(double maxWidth) {
    final showChips = activeFilterChips.isNotEmpty;
    final isDesktop = maxWidth >= 860;
    final effectiveSearchWidth = maxWidth < 500
        ? double.infinity
        : (maxWidth >= 1150 ? searchWidth : (maxWidth >= 860 ? 230.0 : double.infinity));

    final searchAndFilters = <Widget>[
      if (searchController != null)
        SizedBox(
          width: effectiveSearchWidth,
          child: _buildSearchBox(),
        ),
      ...filters,
      if (sortControl != null) sortControl!,
      if (hasActiveFilters && onResetFilters != null && !showChips)
        _buildResetButton(),
    ];

    final hasRightControls = trailingActions.isNotEmpty || onRefresh != null;

    final rightControls = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...trailingActions,
        if (onRefresh != null) ...[
          if (trailingActions.isNotEmpty) const SizedBox(width: 8),
          _buildRefreshButton(),
        ],
      ],
    );

    Widget content;
    if (isDesktop && hasRightControls) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.start,
              children: searchAndFilters,
            ),
          ),
          const SizedBox(width: 12),
          rightControls,
        ],
      );
    } else {
      content = Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.start,
        children: [
          ...searchAndFilters,
          ...trailingActions,
          if (onRefresh != null) _buildRefreshButton(),
        ],
      );
    }

    if (!showChips) return content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const SizedBox(height: 6),
        _buildActiveChipsRow(),
      ],
    );
  }

  Widget _buildSingleRowWithTabs() {
    final showChips = activeFilterChips.isNotEmpty;

    final mainRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (tabs.isNotEmpty) ...[
          _buildSegmentedTabs(),
          const SizedBox(width: 10),
        ],
        if (searchController != null) ...[
          SizedBox(
            width: searchWidth,
            child: _buildSearchBox(),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...filters,
              if (hasActiveFilters && onResetFilters != null && !showChips)
                _buildResetButton(),
              if (onRefresh != null)
                _buildRefreshButton(),
            ],
          ),
        ),
      ],
    );

    if (!showChips) return mainRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        mainRow,
        const SizedBox(height: 6),
        _buildActiveChipsRow(),
      ],
    );
  }

  Widget _buildTwoRows(double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (tabs.isNotEmpty)
              Expanded(child: _buildSegmentedTabs())
            else if (searchController != null)
              Expanded(child: _buildSearchBox()),
            if (onRefresh != null) ...[
              const SizedBox(width: 8),
              _buildRefreshButton(),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (tabs.isNotEmpty && searchController != null)
              SizedBox(
                width: width < 500 ? double.infinity : searchWidth,
                child: _buildSearchBox(),
              ),
            ...filters,
            if (hasActiveFilters && onResetFilters != null && activeFilterChips.isEmpty)
              _buildResetButton(),
          ],
        ),
        if (activeFilterChips.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildActiveChipsRow(),
        ],
      ],
    );
  }

  Widget _buildActiveChipsRow() {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: activeFilterChips,
          ),
        ),
        if (hasActiveFilters && onResetFilters != null) ...[
          const SizedBox(width: 8),
          _buildResetButton(),
        ],
      ],
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in tabs) _buildTabPill(tab),
        ],
      ),
    );
  }

  Widget _buildTabPill(AdminSaaSTab tab) {
    final selected = tab.isSelected;
    return InkWell(
      onTap: tab.onTap,
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm - 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm - 2),
          border: selected
              ? Border.all(color: AdminColors.border.withValues(alpha: 0.6))
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tab.icon != null) ...[
              Icon(
                tab.icon,
                size: 14,
                color: selected ? AdminColors.primary : AdminColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AdminColors.primary : AdminColors.textSecondary,
                height: 1.1,
              ),
            ),
            if (tab.count != null && tab.count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AdminColors.primary.withValues(alpha: 0.1)
                      : AdminColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tab.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? AdminColors.primary : AdminColors.textSecondary,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return SizedBox(
      height: 34,
      child: AnimatedBuilder(
        animation: searchController!,
        builder: (context, _) {
          final hasText = searchController!.text.isNotEmpty;
          return TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(
              fontSize: 13,
              color: AdminColors.textPrimary,
              height: 1.2,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: searchHint,
              hintStyle: const TextStyle(
                fontSize: 12.5,
                color: AdminColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 16,
                color: AdminColors.textSecondary,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 34,
              ),
              suffixIcon: hasText
                  ? Tooltip(
                      message: 'Clear search',
                      child: InkWell(
                        onTap: onClearSearch,
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AdminColors.textMuted,
                        ),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 34,
              ),
              filled: true,
              fillColor: AdminColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                borderSide: const BorderSide(color: AdminColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                borderSide: const BorderSide(color: AdminColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResetButton() {
    return Tooltip(
      message: 'Clear all active filters',
      child: OutlinedButton.icon(
        onPressed: onResetFilters,
        icon: const Icon(Icons.filter_alt_off_outlined, size: 13),
        label: const Text('Reset'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.textSecondary,
          side: const BorderSide(color: AdminColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 34),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Tooltip(
      message: refreshTooltip,
      child: Material(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        child: InkWell(
          onTap: isLoading ? null : onRefresh,
          borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AdminColors.border),
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AdminColors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}
