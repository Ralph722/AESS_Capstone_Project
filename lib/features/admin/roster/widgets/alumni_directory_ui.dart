import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/profile/data/profile_change_diff.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/shared/widgets/user/skeleton.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Design tokens for the admin alumni directory (dense desktop spacing).
/// Colors and surfaces alias [AdminColors] / [AdminSurfaces].
abstract final class AdminDirectoryTheme {
  static const primary = AdminColors.primary;
  static const navy = primary;
  static const navyLight = AdminColors.primary;
  static const gold = AdminColors.accent;
  static const background = AdminColors.background;
  static const surface = AdminColors.surface;
  static const card = AdminColors.card;
  static const border = AdminColors.border;
  static const textPrimary = AdminColors.textPrimary;
  static const textSecondary = AdminColors.textSecondary;
  static const textMuted = AdminColors.textMuted;
  static const success = AdminColors.success;
  static const successBg = AdminColors.successBg;
  static const warning = AdminColors.warning;
  static const warningBg = AdminColors.warningBg;
  static const info = AdminColors.info;
  static const infoBg = AdminColors.infoBg;
  static const danger = AdminColors.danger;
  static const dangerBg = AdminColors.dangerBg;

  /// Spacing aliases → [AdminDensity] (Phase 2 global density system).
  static const space1 = AdminDensity.space1;
  static const space2 = AdminDensity.space2;
  static const space3 = AdminDensity.space3;
  static const space4 = AdminDensity.space4;
  static const buttonHeight = AdminDensity.buttonHeight;

  /// Search / filter / toolbar control target height (~40–44px).
  static const toolbarControlHeight = 40.0;
  static const radiusSm = AdminSurfaces.radiusSm;
  static const radiusMd = AdminSurfaces.radiusMd;
  static const radiusLg = AdminSurfaces.radiusLg;

  static List<BoxShadow> get cardShadow => AdminSurfaces.cardShadow;

  static List<BoxShadow> get cardShadowHover => AdminSurfaces.cardShadowHover;

  static BoxDecoration surfaceCard({bool hovered = false}) =>
      AdminSurfaces.card(hovered: hovered);
}

class DirectoryPageHeader extends StatelessWidget {
  const DirectoryPageHeader({
    super.key,
    required this.onAdd,
    required this.onExport,
    required this.isLoading,
    required this.canExport,
    this.isExporting = false,
  });

  final VoidCallback onAdd;
  final VoidCallback onExport;
  final bool isLoading;
  final bool canExport;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: 'Alumni Directory',
      subtitle: 'Official roster used to validate alumni registration.',
      titleFontSize: AdminDensity.titleFontSize,
      titleColor: AdminDirectoryTheme.textPrimary,
      subtitleColor: AdminDirectoryTheme.textSecondary,
      actions: [
        _HeaderActions(
          onAdd: onAdd,
          onExport: onExport,
          isLoading: isLoading,
          canExport: canExport,
          isExporting: isExporting,
        ),
      ],
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.onAdd,
    required this.onExport,
    required this.isLoading,
    required this.canExport,
    required this.isExporting,
  });

  final VoidCallback onAdd;
  final VoidCallback onExport;
  final bool isLoading;
  final bool canExport;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AdminDirectoryTheme.space1,
      runSpacing: AdminDirectoryTheme.space1,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: 'Download CHED GTS PDFs as a ZIP',
          child: OutlinedButton.icon(
            onPressed: isLoading || isExporting || !canExport ? null : onExport,
            icon: isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 17),
            label: Text(isExporting ? 'Exporting…' : 'Export CHED GTS'),
            style: AdminButtonStyles.outlined(),
          ),
        ),
        FilledButton.icon(
          onPressed: isLoading ? null : onAdd,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
          label: const Text('Add Alumni'),
          style: AdminButtonStyles.filled(),
        ),
      ],
    );
  }
}

class DirectoryStatCard extends StatefulWidget {
  const DirectoryStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  State<DirectoryStatCard> createState() => _DirectoryStatCardState();
}

class _DirectoryStatCardState extends State<DirectoryStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      label: '${widget.label}: ${widget.value}. ${widget.description}',
      child: MouseRegion(
        onEnter: widget.onTap != null
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.onTap != null
            ? (_) => setState(() => _hovered = false)
            : null,
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusMd),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(AdminDensity.kpiCardPadding),
              decoration: AdminDirectoryTheme.surfaceCard(hovered: _hovered),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AdminDensity.kpiIconBox,
                    height: AdminDensity.kpiIconBox,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accent,
                      size: AdminDensity.kpiIconSize,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.value,
                          style: const TextStyle(
                            fontSize: AdminDensity.kpiValueFontSize,
                            fontWeight: FontWeight.w700,
                            color: AdminDirectoryTheme.textPrimary,
                            height: 1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: AdminDensity.kpiLabelFontSize,
                            fontWeight: FontWeight.w600,
                            color: AdminDirectoryTheme.textPrimary,
                          ),
                        ),
                        Text(
                          widget.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AdminDirectoryTheme.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DirectoryStatsGrid extends StatelessWidget {
  const DirectoryStatsGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= AdminDensity.statsFourColMin
            ? 4
            : width >= AdminDensity.statsTwoColMin
            ? 2
            : 1;
        const spacing = AdminDirectoryTheme.space2;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

/// Directory KPI strip: every card on one equal-height row on desktop
/// (4 or 5 cards); 2 / 1 columns on narrow widths like [DirectoryStatsGrid].
class DirectoryKpiRow extends StatelessWidget {
  const DirectoryKpiRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const spacing = AdminDirectoryTheme.space2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= AdminDensity.statsFourColMin) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: spacing),
                  Expanded(child: children[i]),
                ],
              ],
            ),
          );
        }
        final columns = width >= AdminDensity.statsTwoColMin ? 2 : 1;
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class DirectoryToolbarCard extends StatelessWidget {
  const DirectoryToolbarCard({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.isLoading,
    required this.onRefresh,
    required this.hasActiveFilters,
    required this.onResetFilters,
    required this.filters,
    this.activeFilterChips = const [],
    this.searchHint = 'Search by name, ID number, course, or email…',
    this.refreshTooltip = 'Refresh roster',
    this.singleRowMinWidth,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool isLoading;
  final VoidCallback onRefresh;
  final bool hasActiveFilters;
  final VoidCallback onResetFilters;
  final Widget filters;
  final List<Widget> activeFilterChips;
  final String searchHint;

  /// Tooltip for the toolbar reload icon (defaults to Directory wording).
  final String refreshTooltip;

  /// When set and the card's content is at least this wide, search, filters
  /// and refresh share one row and Reset moves next to the active chips.
  /// [filters] then gets an unbounded width, so it must size itself.
  final double? singleRowMinWidth;

  @override
  Widget build(BuildContext context) {
    final minWidth = singleRowMinWidth;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: AdminDirectoryTheme.surfaceCard(),
      child: minWidth == null
          ? _buildTwoRows()
          : LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= minWidth
                  ? _buildSingleRow()
                  : _buildTwoRows(),
            ),
    );
  }

  Widget _buildSingleRow() {
    final showChipRow = activeFilterChips.isNotEmpty || hasActiveFilters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildSearchField()),
            const SizedBox(width: 8),
            filters,
            const SizedBox(width: 8),
            _buildRefreshButton(),
          ],
        ),
        if (showChipRow) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: activeFilterChips,
                ),
              ),
              if (hasActiveFilters) _buildResetButton(),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTwoRows() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildSearchField()),
            const SizedBox(width: 8),
            _buildRefreshButton(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: filters),
            if (hasActiveFilters) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _buildResetButton(),
              ),
            ],
          ],
        ),
        if (activeFilterChips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: activeFilterChips),
        ],
      ],
    );
  }

  Widget _buildResetButton() {
    return TextButton.icon(
      onPressed: onResetFilters,
      icon: const Icon(Icons.filter_alt_off_outlined, size: 14),
      label: const Text('Reset'),
      style: TextButton.styleFrom(
        foregroundColor: AdminDirectoryTheme.textSecondary,
        minimumSize: const Size(0, AdminDirectoryTheme.toolbarControlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildSearchField() {
    return AnimatedBuilder(
      animation: searchController,
      builder: (context, _) {
        return SizedBox(
          height: AdminDirectoryTheme.toolbarControlHeight,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.2,
              color: AdminDirectoryTheme.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: searchHint,
              hintStyle: const TextStyle(
                color: AdminDirectoryTheme.textMuted,
                fontSize: 13.5,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AdminDirectoryTheme.textMuted,
                size: 18,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: AdminDirectoryTheme.toolbarControlHeight,
              ),
              filled: true,
              fillColor: AdminDirectoryTheme.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AdminDirectoryTheme.radiusSm,
                ),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AdminDirectoryTheme.radiusSm,
                ),
                borderSide: const BorderSide(color: AdminDirectoryTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AdminDirectoryTheme.radiusSm,
                ),
                borderSide: const BorderSide(
                  color: AdminDirectoryTheme.primary,
                  width: 1.5,
                ),
              ),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                      style: AdminDensity.iconButtonStyle(
                        foregroundColor: AdminDirectoryTheme.textSecondary,
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: AdminDirectoryTheme.toolbarControlHeight,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      onPressed: isLoading ? null : onRefresh,
      tooltip: refreshTooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(
          AdminDirectoryTheme.toolbarControlHeight,
          AdminDirectoryTheme.toolbarControlHeight,
        ),
        fixedSize: const Size(
          AdminDirectoryTheme.toolbarControlHeight,
          AdminDirectoryTheme.toolbarControlHeight,
        ),
        backgroundColor: AdminDirectoryTheme.background,
        foregroundColor: AdminDirectoryTheme.textPrimary,
        side: const BorderSide(color: AdminDirectoryTheme.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusSm),
        ),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh, size: 18),
    );
  }
}

/// Removable chip showing an applied filter (or search query).
class DirectoryActiveFilterChip extends StatelessWidget {
  const DirectoryActiveFilterChip({
    super.key,
    required this.label,
    required this.onRemoved,
    this.icon,
  });

  final String label;
  final VoidCallback onRemoved;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 14, color: AdminDirectoryTheme.primary),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AdminDirectoryTheme.textPrimary,
        ),
      ),
      onDeleted: onRemoved,
      deleteIcon: const Icon(Icons.close, size: 14),
      deleteIconColor: AdminDirectoryTheme.textSecondary,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      labelPadding: const EdgeInsets.only(left: 6, right: 2),
      side: const BorderSide(color: AdminDirectoryTheme.border),
      backgroundColor: AdminDirectoryTheme.infoBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusSm),
      ),
    );
  }
}

/// Compact status / quick-filter chip for list toolbars.
///
/// Prefer this over ad-hoc [FilterChip]s so every admin screen matches.
class DirectoryToolbarFilterChip extends StatelessWidget {
  const DirectoryToolbarFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      selectedColor: AdminDirectoryTheme.infoBg,
      backgroundColor: AdminDirectoryTheme.card,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected
            ? AdminDirectoryTheme.primary
            : AdminDirectoryTheme.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? AdminDirectoryTheme.primary.withValues(alpha: 0.28)
            : AdminDirectoryTheme.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusSm),
      ),
      onSelected: onSelected,
    );
  }
}

class DirectoryFilterField<T> extends StatelessWidget {
  const DirectoryFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
    this.minWidth = 128,
    this.enabled = true,
    this.dense = false,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double? width;
  final double minWidth;
  final bool enabled;
  final bool dense;

  /// Outer height shared by filter dropdowns and date chips.
  static const double controlHeight =
      AdminDirectoryTheme.toolbarControlHeight + 4;

  static InputDecoration decoration({
    required String label,
    FloatingLabelBehavior floatingLabelBehavior = FloatingLabelBehavior.auto,
    Color borderColor = AdminDirectoryTheme.border,
    Color fillColor = Colors.white,
    bool dense = false,
  }) {
    final radius = BorderRadius.circular(AdminDirectoryTheme.radiusSm);
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: TextStyle(
        fontSize: dense ? 10.5 : 11,
        color: AdminDirectoryTheme.textSecondary,
      ),
      // Flutter scales a floated label to 75%; 14.5 renders at ~11px.
      floatingLabelStyle: TextStyle(
        fontSize: dense ? 12.5 : 14.5,
        fontWeight: FontWeight.w600,
        color: AdminDirectoryTheme.textSecondary,
      ),
      floatingLabelBehavior: floatingLabelBehavior,
      filled: true,
      fillColor: fillColor,
      contentPadding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 8,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AdminDirectoryTheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AdminDirectoryTheme.radiusSm);
    final field = DropdownButtonFormField<T>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      isDense: true,
      dropdownColor: Colors.white,
      iconSize: dense ? 16 : 18,
      borderRadius: radius,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: dense ? 16 : 18,
        color: AdminDirectoryTheme.textMuted,
      ),
      style: TextStyle(
        fontSize: dense ? 12 : 12.5,
        color: AdminDirectoryTheme.textPrimary,
      ),
      decoration: decoration(
        label: label,
        fillColor: dense ? AdminDirectoryTheme.background : Colors.white,
        dense: dense,
      ),
      items: items,
      onChanged: enabled ? onChanged : null,
    );

    if (width != null) {
      return SizedBox(width: width, child: field);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: field,
    );
  }
}

/// Shared themed date / time / range pickers for admin chrome.
abstract final class DirectoryDateTimePickers {
  static ThemeData _theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AdminDirectoryTheme.primary,
        onPrimary: Colors.white,
        surface: AdminDirectoryTheme.card,
        onSurface: AdminDirectoryTheme.textPrimary,
      ),
      datePickerTheme: DatePickerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusLg),
        ),
        headerBackgroundColor: AdminDirectoryTheme.primary,
        headerForegroundColor: Colors.white,
        todayForegroundColor: const WidgetStatePropertyAll(
          AdminDirectoryTheme.primary,
        ),
        todayBackgroundColor: WidgetStatePropertyAll(
          AdminDirectoryTheme.primary.withValues(alpha: 0.08),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AdminDirectoryTheme.card,
        dialHandColor: AdminDirectoryTheme.primary,
        dialBackgroundColor: AdminDirectoryTheme.surface,
        dialTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AdminDirectoryTheme.textPrimary;
        }),
        hourMinuteColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AdminDirectoryTheme.primary;
          }
          return AdminDirectoryTheme.infoBg;
        }),
        hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AdminDirectoryTheme.textPrimary;
        }),
        dayPeriodColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AdminDirectoryTheme.primary;
          }
          return AdminDirectoryTheme.card;
        }),
        dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AdminDirectoryTheme.textSecondary;
        }),
        dayPeriodBorderSide: const BorderSide(
          color: AdminDirectoryTheme.border,
        ),
        entryModeIconColor: AdminDirectoryTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusLg),
        ),
      ),
    );
  }

  static Widget _wrap(BuildContext context, Widget? child) {
    return Theme(data: _theme(context), child: child!);
  }

  static Future<DateTime?> pickDate(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2100),
      helpText: helpText,
      builder: _wrap,
    );
  }

  static Future<TimeOfDay?> pickTime(
    BuildContext context, {
    TimeOfDay? initialTime,
    String? helpText,
  }) {
    return showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      helpText: helpText,
      builder: _wrap,
    );
  }

  static Future<DateTimeRange?> pickDateRange(
    BuildContext context, {
    DateTimeRange? initialDateRange,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) {
    final now = DateTime.now();
    return showDateRangePicker(
      context: context,
      firstDate: firstDate ?? DateTime(now.year - 25),
      lastDate: lastDate ?? DateTime(now.year + 2),
      initialDateRange:
          initialDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month - 3, now.day),
            end: now,
          ),
      helpText: helpText,
      builder: _wrap,
    );
  }

  /// Date then time, combined into one [DateTime]. Cancel on either step aborts.
  static Future<DateTime?> pickDateTime(
    BuildContext context, {
    DateTime? initial,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final base = initial ?? now;
    final date = await pickDate(
      context,
      initialDate: base,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !context.mounted) return null;
    final time = await pickTime(
      context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static String formatDate(DateTime date, {bool includeYear = true}) {
    return DateFormat(includeYear ? 'MMM d, yyyy' : 'MMM d').format(date);
  }

  static String formatDateRange(DateTime start, DateTime end) {
    final sameYear = start.year == end.year;
    if (sameYear) {
      return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
    }
    return '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
  }

  static String formatTime(BuildContext context, TimeOfDay time) {
    return time.format(context);
  }
}

/// Shared shell for date / time / range filter controls (matches [DirectoryFilterField]).
class _DirectoryPickerFilterShell extends StatelessWidget {
  const _DirectoryPickerFilterShell({
    required this.label,
    required this.displayText,
    required this.onTap,
    required this.trailingIcon,
    this.active = false,
    this.enabled = true,
    this.width = 132,
    this.expand = false,
    this.minWidth = 128,
  });

  final String label;
  final String displayText;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final bool active;
  final bool enabled;
  final double? width;
  final bool expand;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final borderColor = !enabled
        ? AdminDirectoryTheme.border
        : active
        ? AdminDirectoryTheme.primary.withValues(alpha: 0.35)
        : AdminDirectoryTheme.border;
    final valueColor = !enabled
        ? AdminDirectoryTheme.textMuted
        : active
        ? AdminDirectoryTheme.primary
        : AdminDirectoryTheme.textMuted;
    final iconColor = !enabled
        ? AdminDirectoryTheme.textMuted
        : active
        ? AdminDirectoryTheme.primary
        : AdminDirectoryTheme.textSecondary;

    final field = Stack(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('$label-$displayText-$active'),
          initialValue: displayText,
          isExpanded: true,
          isDense: true,
          iconSize: 14,
          icon: Icon(trailingIcon, size: 14, color: iconColor),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: valueColor,
          ),
          decoration: DirectoryFilterField.decoration(
            label: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            borderColor: borderColor,
          ),
          items: [
            DropdownMenuItem<String>(
              value: displayText,
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: enabled ? (_) {} : null,
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusSm),
            ),
          ),
        ),
      ],
    );

    if (expand) {
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: field,
      );
    }
    if (width != null) {
      return SizedBox(width: width, child: field);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: field,
    );
  }
}

/// Date filter that renders with the same shell as [DirectoryFilterField].
class DirectoryDateFilterChip extends StatelessWidget {
  const DirectoryDateFilterChip({
    super.key,
    required this.label,
    required this.displayText,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.width = 132,
    this.expand = false,
    this.minWidth = 128,
  });

  final String label;
  final String displayText;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;
  final double? width;
  final bool expand;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return _DirectoryPickerFilterShell(
      label: label,
      displayText: displayText,
      onTap: onTap,
      trailingIcon: Icons.calendar_today_rounded,
      active: active,
      enabled: enabled,
      width: width,
      expand: expand,
      minWidth: minWidth,
    );
  }
}

/// Date-range filter (single control) matching [DirectoryFilterField] density.
class DirectoryDateRangeFilterChip extends StatelessWidget {
  const DirectoryDateRangeFilterChip({
    super.key,
    required this.label,
    required this.displayText,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.width = 220,
    this.expand = false,
    this.minWidth = 180,
  });

  final String label;
  final String displayText;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;
  final double? width;
  final bool expand;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return _DirectoryPickerFilterShell(
      label: label,
      displayText: displayText,
      onTap: onTap,
      trailingIcon: Icons.date_range_rounded,
      active: active,
      enabled: enabled,
      width: width,
      expand: expand,
      minWidth: minWidth,
    );
  }
}

/// Time-of-day filter matching [DirectoryFilterField] density.
class DirectoryTimeFilterChip extends StatelessWidget {
  const DirectoryTimeFilterChip({
    super.key,
    required this.label,
    required this.displayText,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.width = 120,
    this.expand = false,
    this.minWidth = 110,
  });

  final String label;
  final String displayText;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;
  final double? width;
  final bool expand;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return _DirectoryPickerFilterShell(
      label: label,
      displayText: displayText,
      onTap: onTap,
      trailingIcon: Icons.schedule_rounded,
      active: active,
      enabled: enabled,
      width: width,
      expand: expand,
      minWidth: minWidth,
    );
  }
}

class DirectoryResultsBar extends StatelessWidget {
  const DirectoryResultsBar({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AdminDirectoryTheme.textSecondary,
      ),
    );
  }
}

class DirectoryEmptyState extends StatelessWidget {
  const DirectoryEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.primaryAction,
    this.primaryLabel,
    this.secondaryAction,
    this.secondaryLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? primaryAction;
  final String? primaryLabel;
  final VoidCallback? secondaryAction;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminDirectoryTheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AdminDirectoryTheme.primary),
              ),
              const SizedBox(height: AdminDirectoryTheme.space2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AdminDirectoryTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AdminDirectoryTheme.space1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AdminDirectoryTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (primaryAction != null && primaryLabel != null) ...[
                const SizedBox(height: AdminDirectoryTheme.space3),
                FilledButton.icon(
                  onPressed: primaryAction,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(primaryLabel!),
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminDirectoryTheme.primary,
                    minimumSize: const Size(
                      0,
                      AdminDirectoryTheme.buttonHeight,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ],
              if (secondaryAction != null && secondaryLabel != null) ...[
                const SizedBox(height: AdminDirectoryTheme.space1),
                OutlinedButton.icon(
                  onPressed: secondaryAction,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(secondaryLabel!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminDirectoryTheme.textPrimary,
                    side: const BorderSide(color: AdminDirectoryTheme.border),
                    minimumSize: const Size(
                      0,
                      AdminDirectoryTheme.buttonHeight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DirectoryMemberCard extends StatefulWidget {
  const DirectoryMemberCard({
    super.key,
    required this.member,
    required this.showActiveBadge,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onReactivate,
    this.isSelected = false,
    this.isChecked = false,
    this.onCheckedChanged,
    this.chedProgress,
  });

  final AlumniMember member;
  final bool showActiveBadge;
  final bool isSelected;
  final bool isChecked;
  final ValueChanged<bool?>? onCheckedChanged;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReactivate;

  /// CHED GTS waves assigned vs submitted; null while loading or unknown.
  final ChedGtsProgress? chedProgress;

  @override
  State<DirectoryMemberCard> createState() => _DirectoryMemberCardState();
}

class _DirectoryMemberCardState extends State<DirectoryMemberCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final isActive = widget.showActiveBadge && member.isRegisteredUser;
    final hasUpdate = member.hasProfileUpdates;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AdminDirectoryTheme.infoBg.withValues(alpha: 0.55)
                : member.isDeactivated
                ? AdminDirectoryTheme.surface
                : AdminDirectoryTheme.card,
            borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusLg),
            boxShadow: _hovered || widget.isSelected
                ? AdminDirectoryTheme.cardShadowHover
                : AdminDirectoryTheme.cardShadow,
            border: widget.isSelected
                ? Border.all(color: AdminDirectoryTheme.primary, width: 1.5)
                : hasUpdate
                ? Border.all(
                    color: AdminDirectoryTheme.warning.withValues(alpha: 0.45),
                  )
                : null,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusLg),
              border: hasUpdate
                  ? const Border(
                      left: BorderSide(
                        color: AdminDirectoryTheme.warning,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminDirectoryTheme.space3,
                vertical: 12,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  final menu = _MemberMenu(
                    onView: widget.onTap,
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                    onReactivate: widget.onReactivate,
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.onCheckedChanged != null) ...[
                              Checkbox(
                                value: widget.isChecked,
                                onChanged: widget.onCheckedChanged,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: _MemberIdentityColumn(
                                member: member,
                                isActive: isActive,
                              ),
                            ),
                            menu,
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MemberMetaGrid(member: member, compact: true),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MemberStatusColumn(
                                member: member,
                                isActive: isActive,
                                chedProgress: widget.chedProgress,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (widget.onCheckedChanged != null) ...[
                        Checkbox(
                          value: widget.isChecked,
                          onChanged: widget.onCheckedChanged,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        flex: 3,
                        child: _MemberIdentityColumn(
                          member: member,
                          isActive: isActive,
                        ),
                      ),
                      const SizedBox(width: AdminDirectoryTheme.space3),
                      Expanded(flex: 4, child: _MemberMetaGrid(member: member)),
                      const SizedBox(width: AdminDirectoryTheme.space2),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _MemberStatusColumn(
                              member: member,
                              isActive: isActive,
                              chedProgress: widget.chedProgress,
                            ),
                            const SizedBox(height: 4),
                            menu,
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CHED GTS wave progress for one member: waves assigned vs submitted.
typedef ChedGtsProgress = ({int assigned, int submitted});

/// Column definitions for the wide desktop directory table.
const kDirectoryTableColumns = <AdminDataColumn>[
  AdminDataColumn(label: 'NAME', flex: 3),
  AdminDataColumn(label: 'COURSE', width: 96),
  AdminDataColumn(label: 'BATCH', width: 64),
  AdminDataColumn(label: 'STUDENT ID', width: 112),
  AdminDataColumn(label: 'EMAIL', flex: 2),
  AdminDataColumn(label: 'LAST ACTIVE', width: 120),
  AdminDataColumn(label: 'CHED GTS', width: 100),
  AdminDataColumn(label: 'STATUS', width: 116),
];

/// Dense desktop table row for the alumni directory (wide layouts).
class DirectoryMemberTableRow extends StatelessWidget {
  const DirectoryMemberTableRow({
    super.key,
    required this.member,
    required this.showActiveBadge,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onReactivate,
    this.isSelected = false,
    this.isChecked = false,
    this.onCheckedChanged,
    this.chedProgress,
  });

  final AlumniMember member;
  final bool showActiveBadge;
  final bool isSelected;
  final bool isChecked;
  final ValueChanged<bool?>? onCheckedChanged;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReactivate;

  /// CHED GTS waves assigned vs submitted; null while loading or unknown.
  final ChedGtsProgress? chedProgress;

  Widget get _chedCell {
    final progress = chedProgress;
    if (progress == null || progress.assigned == 0) {
      return const AdminTableTextCell('—', muted: true);
    }
    if (progress.submitted >= progress.assigned) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: AdminTableBadge(
          label: 'Complete',
          bg: AdminTableTheme.successBg,
          fg: AdminTableTheme.success,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: AdminTableBadge(
        label: '${progress.submitted}/${progress.assigned}',
        bg: AdminTableTheme.warningBg,
        fg: AdminTableTheme.warning,
      ),
    );
  }

  String get _statusLabel {
    if (member.isDeactivated) return 'Deactivated';
    if (showActiveBadge && member.isRegisteredUser) return 'Active';
    if (member.isRegisteredUser) return 'Registered';
    return 'Not registered';
  }

  Color get _statusFg {
    if (member.isDeactivated) return AdminTableTheme.danger;
    if (showActiveBadge && member.isRegisteredUser) {
      return AdminTableTheme.success;
    }
    if (member.isRegisteredUser) return AdminTableTheme.primary;
    return AdminTableTheme.warning;
  }

  Color get _statusBg {
    if (member.isDeactivated) return AdminTableTheme.dangerBg;
    if (showActiveBadge && member.isRegisteredUser) {
      return AdminTableTheme.successBg;
    }
    if (member.isRegisteredUser) return AdminColors.infoBg;
    return AdminTableTheme.warningBg;
  }

  @override
  Widget build(BuildContext context) {
    final email = member.registeredEmail?.trim();
    final hasEmail = email != null && email.isNotEmpty;
    final batch = member.effectiveBatchYear;
    final lastActive = member.lastActiveAt == null
        ? '—'
        : DateFormat.MMMd().add_jm().format(member.lastActiveAt!);
    final isActive = showActiveBadge && member.isRegisteredUser;

    return AdminDataRow(
      columns: kDirectoryTableColumns,
      selected: isSelected || isChecked,
      onTap: onTap,
      leadingWidth: onCheckedChanged == null ? 0 : 40,
      leading: onCheckedChanged == null
          ? null
          : Checkbox(value: isChecked, onChanged: onCheckedChanged),
      trailingWidth: 44,
      trailing: _MemberMenu(
        onView: onTap,
        onEdit: onEdit,
        onDelete: onDelete,
        onReactivate: onReactivate,
      ),
      cells: [
        AdminTableIdentityCell(
          title: member.fullName.isEmpty ? 'Unnamed' : member.fullName,
          subtitle: member.hasProfileUpdates ? 'Profile updated' : null,
          leading: _DirectoryTableAvatar(member: member, isActive: isActive),
        ),
        AdminTableTextCell(
          member.course.isEmpty ? 'No course' : member.course,
          muted: member.course.isEmpty,
        ),
        AdminTableTextCell(batch.isEmpty ? '—' : batch, muted: batch.isEmpty),
        AdminTableTextCell(
          member.studentId.isEmpty ? '—' : member.studentId,
          muted: member.studentId.isEmpty,
        ),
        hasEmail
            ? Tooltip(message: email, child: AdminTableTextCell(email))
            : const AdminTableTextCell('—', muted: true),
        AdminTableTextCell(lastActive, muted: member.lastActiveAt == null),
        _chedCell,
        Align(
          alignment: Alignment.centerLeft,
          child: AdminTableBadge(
            label: _statusLabel,
            bg: _statusBg,
            fg: _statusFg,
          ),
        ),
      ],
    );
  }
}

class _DirectoryTableAvatar extends StatelessWidget {
  const _DirectoryTableAvatar({required this.member, required this.isActive});

  final AlumniMember member;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final image = member.profileImageUrl?.trim();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AdminDirectoryTheme.surface,
          ),
          child: ClipOval(
            child: image != null && image.isNotEmpty
                ? AppImage.widget(
                    image,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: AdminDirectoryTheme.infoBg,
                      child: Center(
                        child: Text(
                          member.fullName.isNotEmpty
                              ? member.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AdminDirectoryTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                : ColoredBox(
                    color: AdminDirectoryTheme.infoBg,
                    child: Center(
                      child: Text(
                        member.fullName.isNotEmpty
                            ? member.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AdminDirectoryTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (isActive)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AdminDirectoryTheme.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member, required this.isActive});

  final AlumniMember member;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final image = member.profileImageUrl?.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AdminDirectoryTheme.surface,
          ),
          child: ClipOval(
            child: image != null && image.isNotEmpty
                ? AppImage.widget(
                    image,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _AvatarFallback(fullName: member.fullName),
                  )
                : _AvatarFallback(fullName: member.fullName),
          ),
        ),
        if (isActive)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AdminDirectoryTheme.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.fullName});

  final String fullName;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminDirectoryTheme.infoBg,
      child: Center(
        child: Text(
          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AdminDirectoryTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class _MemberIdentityColumn extends StatelessWidget {
  const _MemberIdentityColumn({required this.member, required this.isActive});

  final AlumniMember member;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(member: member, isActive: isActive),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      member.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: member.isDeactivated
                            ? AdminDirectoryTheme.textMuted
                            : AdminDirectoryTheme.textPrimary,
                        decoration: member.isDeactivated
                            ? TextDecoration.lineThrough
                            : null,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (member.hasProfileUpdates) ...[
                    const SizedBox(width: 6),
                    const _DirectoryBadge(
                      label: 'Updated',
                      bg: AdminDirectoryTheme.warningBg,
                      fg: AdminDirectoryTheme.warning,
                      icon: Icons.notifications_active_outlined,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _CourseBadge(course: member.course),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseBadge extends StatelessWidget {
  const _CourseBadge({required this.course});

  final String course;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminDirectoryTheme.infoBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        course.isEmpty ? 'No course' : course,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AdminDirectoryTheme.info,
        ),
      ),
    );
  }
}

class _MemberMetaGrid extends StatelessWidget {
  const _MemberMetaGrid({required this.member, this.compact = false});

  final AlumniMember member;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final email = member.registeredEmail?.trim();
    final lastActive = member.lastActiveAt == null
        ? 'No activity recorded'
        : DateFormat.MMMd().add_jm().format(member.lastActiveAt!);

    final items = [
      _MemberMetaItem(
        icon: Icons.badge_outlined,
        label: 'Student ID',
        value: member.studentId.isEmpty ? 'Not provided' : member.studentId,
      ),
      _MemberMetaItem(
        icon: Icons.calendar_today_outlined,
        label: 'Batch',
        value: member.effectiveBatchYear.isEmpty
            ? 'Not provided'
            : member.effectiveBatchYear,
      ),
      _MemberMetaItem(
        icon: Icons.mail_outline,
        label: 'Email',
        value: email == null || email.isEmpty ? 'Not provided' : email,
      ),
      _MemberMetaItem(
        icon: Icons.schedule_outlined,
        label: 'Last active',
        value: lastActive,
      ),
    ];

    if (compact) {
      return Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: item,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: item,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MemberMetaItem extends StatelessWidget {
  const _MemberMetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AdminDirectoryTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AdminDirectoryTheme.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AdminDirectoryTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberStatusColumn extends StatelessWidget {
  const _MemberStatusColumn({
    required this.member,
    required this.isActive,
    this.chedProgress,
  });

  final AlumniMember member;
  final bool isActive;
  final ChedGtsProgress? chedProgress;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    if (isActive) {
      badges.add(
        const _DirectoryBadge(
          label: 'Active recently',
          bg: AdminDirectoryTheme.successBg,
          fg: AdminDirectoryTheme.success,
          icon: Icons.circle,
        ),
      );
    }
    if (!member.isRegisteredUser && !member.isDeactivated) {
      badges.add(
        const _DirectoryBadge(
          label: 'Not registered',
          bg: AdminDirectoryTheme.warningBg,
          fg: AdminDirectoryTheme.warning,
          icon: Icons.person_outline,
        ),
      );
    }
    if (member.isDeactivated) {
      badges.add(
        const _DirectoryBadge(
          label: 'Deactivated',
          bg: AdminDirectoryTheme.dangerBg,
          fg: AdminDirectoryTheme.danger,
          icon: Icons.block,
        ),
      );
    }
    if (member.isRegisteredUser && !member.isDeactivated) {
      badges.add(
        const _DirectoryBadge(
          label: 'Registered',
          bg: AdminDirectoryTheme.infoBg,
          fg: AdminDirectoryTheme.info,
          icon: Icons.verified_outlined,
        ),
      );
    }
    final ched = chedProgress;
    if (ched != null && ched.assigned > 0) {
      final done = ched.submitted >= ched.assigned;
      badges.add(
        _DirectoryBadge(
          label: done
              ? 'CHED complete'
              : 'CHED ${ched.submitted}/${ched.assigned}',
          bg: done
              ? AdminDirectoryTheme.successBg
              : AdminDirectoryTheme.warningBg,
          fg: done ? AdminDirectoryTheme.success : AdminDirectoryTheme.warning,
          icon: done ? Icons.task_alt : Icons.assignment_outlined,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: badges
          .map(
            (badge) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: badge,
            ),
          )
          .toList(),
    );
  }
}

class _DirectoryBadge extends StatelessWidget {
  const _DirectoryBadge({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberMenu extends StatelessWidget {
  const _MemberMenu({
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    this.onReactivate,
  });

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_horiz,
        color: AdminDirectoryTheme.textSecondary,
      ),
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: AdminDirectoryTheme.buttonHeight,
        minHeight: AdminDirectoryTheme.buttonHeight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDirectoryTheme.radiusMd),
      ),
      color: AdminDirectoryTheme.card,
      elevation: 8,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView();
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
          case 'reactivate':
            onReactivate?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: ListTile(
            leading: Icon(Icons.open_in_new, color: AdminDirectoryTheme.navy),
            title: Text('View details'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined, color: AdminDirectoryTheme.navy),
            title: Text('Edit roster entry'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        if (onReactivate != null)
          const PopupMenuItem(
            value: 'reactivate',
            child: ListTile(
              leading: Icon(Icons.restore, color: AdminDirectoryTheme.success),
              title: Text('Reactivate'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          )
        else
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: const Text('Delete / deactivate'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
      ],
    );
  }
}

// ——— Member detail view ———

class MemberDetailHeader extends StatelessWidget {
  const MemberDetailHeader({
    super.key,
    required this.member,
    this.profileImageUrl,
    this.tracerCompletion,
    this.activityCount = 0,
  });

  final AlumniMember member;
  final String? profileImageUrl;
  final double? tracerCompletion;
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    final isActive =
        member.isRegisteredUser &&
        member.isActiveWithin(const Duration(days: 7));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminDirectoryTheme.navy, AdminDirectoryTheme.navyLight],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              profileImageUrl != null &&
                                  profileImageUrl!.isNotEmpty
                              ? NetworkImage(profileImageUrl!)
                              : null,
                          child:
                              profileImageUrl == null ||
                                  profileImageUrl!.isEmpty
                              ? Text(
                                  member.fullName.isNotEmpty
                                      ? member.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AdminDirectoryTheme.navy,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (isActive)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AdminDirectoryTheme.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          member.course,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'ID ${member.studentId}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tracerCompletion != null)
                    _CompletionRing(percent: tracerCompletion!),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (member.hasProfileUpdates)
                    _HeaderPill(
                      label: 'Profile updated',
                      icon: Icons.notifications_active,
                      bg: AdminDirectoryTheme.warningBg,
                      fg: AdminDirectoryTheme.warning,
                    ),
                  if (!member.isRegisteredUser)
                    _HeaderPill(
                      label: 'Not registered',
                      icon: Icons.person_off_outlined,
                      bg: Colors.white.withValues(alpha: 0.15),
                      fg: Colors.white,
                    ),
                  if (member.isRegisteredUser)
                    _HeaderPill(
                      label: 'In app',
                      icon: Icons.verified_user_outlined,
                      bg: Colors.white.withValues(alpha: 0.15),
                      fg: Colors.white,
                    ),
                  if (member.isDeactivated)
                    _HeaderPill(
                      label: 'Deactivated',
                      icon: Icons.block,
                      bg: Colors.red.withValues(alpha: 0.25),
                      fg: Colors.white,
                    ),
                  if (isActive)
                    _HeaderPill(
                      label: 'Active · 7d',
                      icon: Icons.circle,
                      bg: AdminDirectoryTheme.success.withValues(alpha: 0.3),
                      fg: Colors.white,
                    ),
                  if (member.tracerProfileComplete)
                    _HeaderPill(
                      label: 'Tracer complete',
                      icon: Icons.check_circle_outline,
                      bg: AdminDirectoryTheme.success.withValues(alpha: 0.3),
                      fg: Colors.white,
                    ),
                ],
              ),
              if (member.registeredEmail != null &&
                  member.registeredEmail!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _HeaderMetaRow(
                  icon: Icons.email_outlined,
                  text: member.registeredEmail!,
                ),
              ],
              if (member.lastActiveAt != null) ...[
                const SizedBox(height: 6),
                _HeaderMetaRow(
                  icon: Icons.schedule,
                  text:
                      'Last active ${DateFormat.MMMd().add_jm().format(member.lastActiveAt!)}',
                ),
              ],
              if (activityCount > 0) ...[
                const SizedBox(height: 6),
                _HeaderMetaRow(
                  icon: Icons.history,
                  text: '$activityCount activity log entries',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final p = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: p,
            strokeWidth: 4,
            backgroundColor: Colors.white24,
            color: AdminDirectoryTheme.gold,
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetaRow extends StatelessWidget {
  const _HeaderMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class MemberDetailSection extends StatelessWidget {
  const MemberDetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AdminColors.primaryTint,
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                  ),
                  child: Icon(icon, size: 17, color: AdminColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: AdminText.sectionTitle),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Label/value row. Empty values are hidden unless [emptyText] is given.
class MemberDetailInfoRow extends StatelessWidget {
  const MemberDetailInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
    this.emptyText,
    this.trailing,
    this.changed = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;
  final String? emptyText;

  /// Shown after a non-empty value, e.g. a verification badge.
  final Widget? trailing;

  /// Marks the field as changed since the admin last reviewed the profile.
  final bool changed;

  static const double _labelWidth = 160;
  static const double _stackBelow = 360;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim().isEmpty;
    if (isEmpty && emptyText == null) return const SizedBox.shrink();

    final text = Text(
      isEmpty ? emptyText! : value,
      style: isEmpty
          ? const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AdminColors.textMuted,
            )
          : TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              color: AdminColors.textPrimary,
            ),
    );
    final valueText = isEmpty || trailing == null
        ? text
        : Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [text, trailing!],
          );
    final labelText = Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: AdminColors.textSecondary,
      ),
    );
    final labelWidget = changed
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: labelText),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Changed since last review',
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AdminDirectoryTheme.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          )
        : labelText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < _stackBelow;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 16, color: AdminColors.textMuted),
                ),
                const SizedBox(width: 10),
              ],
              if (stacked)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [labelWidget, const SizedBox(height: 2), valueText],
                  ),
                )
              else ...[
                SizedBox(width: _labelWidth, child: labelWidget),
                const SizedBox(width: 12),
                Expanded(child: valueText),
              ],
            ],
          );
        },
      ),
    );
  }
}

enum ContactVerificationStatus { verified, demo, notVerified }

/// Verification badge for an alumnus's contact email or mobile number.
class ContactVerificationBadge extends StatelessWidget {
  const ContactVerificationBadge({super.key, required this.status});

  ContactVerificationBadge.email(TracerProfile profile, {super.key})
    : status = profile.contactEmailVerified
          ? ContactVerificationStatus.verified
          : ContactVerificationStatus.notVerified;

  ContactVerificationBadge.mobile(TracerProfile profile, {super.key})
    : status = profile.mobileVerified
          ? ContactVerificationStatus.verified
          : profile.mobileDemoConfirmed
          ? ContactVerificationStatus.demo
          : ContactVerificationStatus.notVerified;

  final ContactVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tooltip, icon, bg, fg) = switch (status) {
      ContactVerificationStatus.verified => (
        'Verified',
        'Confirmed with a one-time code.',
        Icons.verified_outlined,
        AdminTableTheme.successBg,
        AdminTableTheme.success,
      ),
      ContactVerificationStatus.demo => (
        'Demo code',
        'Confirmed with an on-screen demo code. Text message checks are not '
            'live yet, so this is not counted as verified.',
        Icons.science_outlined,
        AdminTableTheme.warningBg,
        AdminTableTheme.warning,
      ),
      ContactVerificationStatus.notVerified => (
        'Not verified',
        'Not yet confirmed by the alumnus.',
        Icons.help_outline,
        AdminTableTheme.headerBg,
        AdminTableTheme.textSecondary,
      ),
    };
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: '$label. $tooltip',
        excludeSemantics: true,
        child: AdminTableBadge(label: label, icon: icon, bg: bg, fg: fg),
      ),
    );
  }
}

class MemberDetailEmptyPanel extends StatelessWidget {
  const MemberDetailEmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AdminDirectoryTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminDirectoryTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AdminDirectoryTheme.navy),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AdminDirectoryTheme.navy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (child != null) ...[const SizedBox(height: 20), child!],
        ],
      ),
    );
  }
}

/// Status chip used in the member detail header.
class MemberDetailChip extends StatelessWidget {
  const MemberDetailChip({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
    this.tooltip,
    this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
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
    if (onTap != null) {
      chip = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: chip),
      );
    }
    if (tooltip != null) chip = Tooltip(message: tooltip!, child: chip);
    return chip;
  }
}

/// Identity and status for the member detail panel: photo, name, details
/// line (course · ID · batch · email) and status chips.
class MemberDetailPanelHeader extends StatelessWidget {
  const MemberDetailPanelHeader({
    super.key,
    required this.member,
    required this.onClose,
    this.imageUrl,
    this.tracerPercent,
    this.activityCount = 0,
    this.onActivityTap,
    this.actions = const [],
  });

  static const activeWindow = Duration(days: 30);

  final AlumniMember member;
  final VoidCallback onClose;
  final String? imageUrl;

  /// Loaded tracer completion (0–100); no chip when null.
  final double? tracerPercent;
  final int activityCount;
  final VoidCallback? onActivityTap;
  final List<Widget> actions;

  static String detailsLine(AlumniMember member) {
    final batch = member.effectiveBatchYear;
    final email = member.registeredEmail?.trim() ?? '';
    return [
      if (member.course.trim().isNotEmpty) member.course.trim(),
      if (member.studentId.trim().isNotEmpty) 'ID ${member.studentId.trim()}',
      if (batch.isNotEmpty) 'Batch $batch',
      if (email.isNotEmpty) email,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isActive = member.isActiveWithin(activeWindow);
    final percent = tracerPercent?.clamp(0, 100).round();
    final details = detailsLine(member);

    final chips = <Widget>[
      if (member.isDeactivated)
        const MemberDetailChip(
          label: 'Deactivated',
          bg: AdminColors.dangerBg,
          fg: AdminColors.danger,
          icon: Icons.block,
        )
      else if (member.isRegisteredUser)
        const MemberDetailChip(
          label: 'Registered',
          bg: AdminColors.infoBg,
          fg: AdminColors.info,
          icon: Icons.verified_outlined,
        )
      else
        const MemberDetailChip(
          label: 'Not registered',
          bg: AdminColors.warningBg,
          fg: AdminColors.warning,
          icon: Icons.person_outline,
        ),
      if (isActive)
        const MemberDetailChip(
          label: 'Active (30d)',
          bg: AdminColors.successBg,
          fg: AdminColors.success,
          icon: Icons.circle,
          tooltip: 'Used the app in the last 30 days',
        ),
      if (percent != null)
        MemberDetailChip(
          label: 'Tracer $percent%',
          bg: percent >= 100 ? AdminColors.successBg : AdminColors.warningBg,
          fg: percent >= 100 ? AdminColors.success : AdminColors.warning,
          icon: percent >= 100 ? Icons.task_alt : Icons.pending_outlined,
        ),
      if (member.hasProfileUpdates)
        const MemberDetailChip(
          label: 'Profile updated',
          bg: AdminColors.warningBg,
          fg: AdminColors.warning,
        ),
      if (activityCount > 0)
        MemberDetailChip(
          label: '$activityCount activities',
          bg: AdminColors.surface,
          fg: AdminColors.textSecondary,
          icon: Icons.history,
          tooltip: 'Open activity logs',
          onTap: onActivityTap,
        ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close details',
            onPressed: onClose,
            style: IconButton.styleFrom(
              foregroundColor: AdminColors.textSecondary,
              minimumSize: const Size(
                AdminDensity.buttonHeight,
                AdminDensity.buttonHeight,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _MemberDetailAvatar(
            name: member.fullName,
            imageUrl: imageUrl,
            isActive: isActive,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    member.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.caption,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ],
      ),
    );
  }
}

class _MemberDetailAvatar extends StatelessWidget {
  const _MemberDetailAvatar({
    required this.name,
    required this.imageUrl,
    required this.isActive,
  });

  final String name;
  final String? imageUrl;
  final bool isActive;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim() ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: _size,
            height: _size,
            child: image.isNotEmpty
                ? AppImage.widget(
                    image,
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                  )
                : ColoredBox(
                    color: AdminColors.primaryTint,
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.primary,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (isActive)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AdminColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.card, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Slim notice above member detail content (not registered, missing
/// tracer fields, …).
class MemberDetailNotice extends StatelessWidget {
  const MemberDetailNotice({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final fg = warning ? AdminColors.warning : AdminColors.primary;
    final bg = warning ? AdminColors.warningBg : AdminColors.primaryTint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textPrimary,
                  ),
                ),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// GTS labels for the required tracer fields that are empty in [tracer]
/// (same field list as [TracerProfile.requiredFieldKeys]).
List<String> memberDetailMissingTracerLabels(TracerProfile tracer) {
  const labels = {
    'displayName': GtsConstants.labelName,
    'address': GtsConstants.labelPermanentAddress,
    'email': GtsConstants.labelEmail,
    'telephoneNumber': GtsConstants.labelTelephone,
    'mobileNumber': GtsConstants.labelMobile,
    'civilStatus': GtsConstants.labelCivilStatus,
    'gender': GtsConstants.labelSex,
    'birthDate': GtsConstants.labelBirthday,
    'regionOfOrigin': GtsConstants.labelRegionOfOrigin,
    'province': GtsConstants.labelProvince,
    'locationOfResidence': GtsConstants.labelLocationOfResidence,
    'program': GtsConstants.labelDegreeSpecialization,
    'collegeUniversity': GtsConstants.labelCollegeUniversity,
    'yearGraduated': GtsConstants.labelYearGraduated,
    'employmentStatus': GtsConstants.labelEmploymentStatus,
  };
  final missing = TracerProfile.missingRequiredKeys({
    'displayName': tracer.displayName,
    'address': tracer.address,
    'email': tracer.email,
    'telephoneNumber': tracer.telephoneNumber,
    'mobileNumber': tracer.mobileNumber,
    'civilStatus': tracer.civilStatus,
    'gender': tracer.gender,
    'birthDate': tracer.birthDate,
    'regionOfOrigin': tracer.regionOfOrigin,
    'province': tracer.province,
    'locationOfResidence': tracer.locationOfResidence,
    'program': tracer.program,
    'collegeUniversity': tracer.collegeUniversity,
    'yearGraduated': tracer.yearGraduated,
    'employmentStatus': tracer.employmentStatus,
  });
  return [for (final key in missing) labels[key] ?? key];
}

/// Banner for an incomplete tracer profile, naming the missing fields.
class MemberDetailCompletenessBanner extends StatelessWidget {
  const MemberDetailCompletenessBanner({
    super.key,
    required this.percent,
    required this.missingLabels,
  });

  final double percent;
  final List<String> missingLabels;

  @override
  Widget build(BuildContext context) {
    final rounded = percent.clamp(0, 100).round();
    return MemberDetailNotice(
      icon: Icons.info_outline,
      warning: true,
      title: 'Tracer profile $rounded% complete',
      message: missingLabels.isEmpty
          ? 'Some tracer profile fields are still missing.'
          : 'Missing: ${missingLabels.join(', ')}',
    );
  }
}

/// Two columns side by side when at least [AdminDensity.desktopSplitMin]
/// wide; one column (left, then right) below that.
class MemberDetailColumns extends StatelessWidget {
  const MemberDetailColumns({
    super.key,
    required this.left,
    this.right = const [],
    this.gap = 16,
  });

  final List<Widget> left;
  final List<Widget> right;
  final double gap;

  List<Widget> _spaced(List<Widget> items) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      items[i],
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminDensity.desktopSplitMin) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced([...left, ...right]),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _spaced(left),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _spaced(right),
              ),
            ),
          ],
        );
      },
    );
  }
}

const _activityAcronyms = {'CHED', 'GTS', 'PDF', 'DSS', 'FCM', 'SMS', 'ID'};

/// Readable form of an audit action code: `UPDATE_ROSTER_MEMBER` →
/// "Update roster member". Known acronyms stay upper case.
String memberDetailActionLabel(String action) {
  final words = action
      .trim()
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return action;
  final out = <String>[];
  for (var i = 0; i < words.length; i++) {
    final upper = words[i].toUpperCase();
    if (_activityAcronyms.contains(upper)) {
      out.add(upper);
    } else {
      final lower = words[i].toLowerCase();
      out.add(
        i == 0 ? '${lower[0].toUpperCase()}${lower.substring(1)}' : lower,
      );
    }
  }
  return out.join(' ');
}

/// Timeline filter category for an audit entry: where the change came from.
String memberDetailActivitySource(AuditLog log) {
  final source = log.changes?['source']?.toString() ?? '';
  if (source.isNotEmpty) return source;
  if (log.userRole == 'admin') return 'admin';
  return 'other';
}

const _activitySourceOrder = [
  'profile',
  'tracer',
  'survey',
  'onboarding',
  'admin',
  'other',
];

String _activitySourceFilterLabel(String source) => switch (source) {
  'admin' => 'Admin',
  'other' => 'Other',
  _ => profileChangeSourceLabel(source),
};

String _activitySourceChipLabel(String source) => switch (source) {
  'admin' => 'Admin action',
  'other' => '',
  _ => 'Via ${profileChangeSourceLabel(source)}',
};

String _relativeActivityTime(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '';
}

/// Audit entries as a timeline inside one bordered card, with a source
/// filter and expandable field-level diffs for profile changes.
class MemberDetailActivityList extends StatefulWidget {
  const MemberDetailActivityList({super.key, required this.logs, this.limit});

  final List<AuditLog> logs;

  /// Maximum rows the source returns; a note is shown when it is reached.
  final int? limit;

  static final _format = DateFormat.yMMMd().add_jm();

  @override
  State<MemberDetailActivityList> createState() =>
      _MemberDetailActivityListState();
}

class _MemberDetailActivityListState extends State<MemberDetailActivityList> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final logs = widget.logs;
    final limit = widget.limit;
    final reachedLimit = limit != null && logs.length >= limit;

    final present = logs.map(memberDetailActivitySource).toSet();
    final categories = [
      for (final source in _activitySourceOrder)
        if (present.contains(source)) source,
    ];
    final filtered = _filter == 'all'
        ? logs
        : logs
              .where((log) => memberDetailActivitySource(log) == _filter)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reachedLimit) ...[
          Text('Showing the latest $limit entries', style: AdminText.caption),
          const SizedBox(height: 8),
        ],
        if (categories.length > 1) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final source in ['all', ...categories])
                FilterChip(
                  label: Text(
                    source == 'all'
                        ? 'All'
                        : _activitySourceFilterLabel(source),
                  ),
                  selected: _filter == source,
                  onSelected: (_) => setState(() => _filter = source),
                  labelStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No entries in this category.',
              style: TextStyle(
                fontSize: 13,
                color: AdminColors.textSecondary,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
              border: Border.all(color: AdminColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AdminColors.border),
                  _MemberDetailActivityRow(
                    log: filtered[i],
                    format: MemberDetailActivityList._format,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _MemberDetailActivityRow extends StatefulWidget {
  const _MemberDetailActivityRow({required this.log, required this.format});

  final AuditLog log;
  final DateFormat format;

  @override
  State<_MemberDetailActivityRow> createState() =>
      _MemberDetailActivityRowState();
}

class _MemberDetailActivityRowState extends State<_MemberDetailActivityRow> {
  bool _expanded = false;

  AuditLog get log => widget.log;

  Map<String, dynamic>? get _fields {
    final fields = log.changes?['fields'];
    if (log.action != 'PROFILE_UPDATE' || fields is! Map || fields.isEmpty) {
      return null;
    }
    return fields.map((k, v) => MapEntry(k.toString(), v));
  }

  bool get _hasFromTo =>
      (log.action == 'NAME_CHANGE' || log.action == 'LOGIN_EMAIL_CHANGE') &&
      log.changes?['from'] != null &&
      log.changes?['to'] != null;

  String get _title {
    switch (log.action) {
      case 'PROFILE_UPDATE':
        return 'Profile updated';
      case 'NAME_CHANGE':
        return 'Name changed';
      case 'LOGIN_EMAIL_CHANGE':
        return log.changes?['loginChanged'] == true
            ? 'Login email changed'
            : 'Contact email confirmed';
      default:
        return memberDetailActionLabel(log.action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = log.status.toUpperCase() == 'SUCCESS';
    final fg = ok ? AdminColors.success : AdminColors.danger;
    final fields = _fields;
    final description = log.description.isNotEmpty
        ? log.description
        : '${log.resource} · ${log.resourceId}';
    final relative = _relativeActivityTime(log.timestamp);
    final meta = [
      if (relative.isNotEmpty) relative,
      widget.format.format(log.timestamp),
      if (log.userName.trim().isNotEmpty) log.userName,
    ].join(' · ');
    final sourceChip = _activitySourceChipLabel(
      memberDetailActivitySource(log),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              fields != null
                  ? Icons.edit_outlined
                  : ok
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 18,
              color: fields != null ? AdminColors.primary : fg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: log.action,
                        child: Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    if (sourceChip.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AdminColors.infoBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          sourceChip,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (fields == null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
                if (_hasFromTo) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${log.changes!['from']} → ${log.changes!['to']}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ],
                if (fields != null) ...[
                  const SizedBox(height: 6),
                  _fieldSummary(fields),
                  if (_expanded) ...[
                    const SizedBox(height: 8),
                    for (final entry in fields.entries)
                      _fieldDiffRow(entry.key, entry.value),
                  ],
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(meta, style: AdminText.caption),
                    Text(
                      log.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldSummary(Map<String, dynamic> fields) {
    final labels = [
      for (final key in fields.keys) profileFieldLabels[key] ?? key,
    ];
    final shown = labels.take(4).toList();
    final extra = labels.length - shown.length;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                extra > 0
                    ? '${shown.join(', ')} +$extra more'
                    : shown.join(', '),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AdminColors.textSecondary,
                ),
              ),
            ),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: AdminColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldDiffRow(String key, dynamic value) {
    final label = profileFieldLabels[key] ?? key;
    var from = '';
    var to = '';
    if (value is Map) {
      from = value['from']?.toString() ?? '';
      to = value['to']?.toString() ?? '';
    }
    final text = (from.isEmpty && to.isEmpty)
        ? 'Changed'
        : '${from.isEmpty ? '—' : from} → ${to.isEmpty ? '—' : to}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AdminColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Question/answer pairs for a non-CHED survey snapshot. When the survey's
/// questions are unavailable, answers are listed by position with the stored
/// key in a tooltip.
class MemberDetailAnswerList extends StatelessWidget {
  const MemberDetailAnswerList({
    super.key,
    required this.questions,
    required this.answers,
  });

  final List<SurveyQuestion> questions;
  final Map<String, dynamic> answers;

  static String formatAnswer(dynamic answer) {
    if (answer == null) return '—';
    if (answer is List) return answer.join(', ');
    return answer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty && answers.isEmpty) {
      return const Text(
        'No answers recorded for this response.',
        style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
      );
    }
    final blocks = questions.isNotEmpty
        ? [
            for (final q in questions)
              _MemberDetailAnswerBlock(
                label: q.prompt,
                value: formatAnswer(answers[q.id]),
              ),
          ]
        : [
            for (final (i, entry) in answers.entries.indexed)
              _MemberDetailAnswerBlock(
                label: 'Answer ${i + 1} (question no longer available)',
                value: formatAnswer(entry.value),
                tooltip: entry.key,
              ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }
}

class _MemberDetailAnswerBlock extends StatelessWidget {
  const _MemberDetailAnswerBlock({
    required this.label,
    required this.value,
    this.tooltip,
  });

  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget labelText = Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AdminColors.textPrimary,
      ),
    );
    if (tooltip != null) {
      labelText = Tooltip(message: tooltip!, child: labelText);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelText,
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AdminColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder for member detail tab content.
class MemberDetailSkeleton extends StatelessWidget {
  const MemberDetailSkeleton({super.key});

  Widget _card(int lines) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 160, height: 14),
          for (var i = 0; i < lines; i++) ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Skeleton(width: 120, height: 10),
                SizedBox(width: 24),
                Expanded(child: Skeleton(height: 10)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: MemberDetailColumns(
          left: [_card(8)],
          right: [_card(3), _card(1)],
        ),
      ),
    );
  }
}

class MemberDetailActivityTile extends StatelessWidget {
  const MemberDetailActivityTile({
    super.key,
    required this.description,
    required this.action,
    required this.resource,
    required this.userName,
    required this.timestamp,
    required this.isAdmin,
    this.isFailed = false,
    this.showConnector = true,
  });

  final String description;
  final String action;
  final String resource;
  final String userName;
  final DateTime timestamp;
  final bool isAdmin;
  final bool isFailed;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final dotColor = isFailed
        ? Colors.red
        : isAdmin
        ? AdminDirectoryTheme.navy
        : AdminDirectoryTheme.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminDirectoryTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFailed
                        ? Colors.red.shade200
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AdminDirectoryTheme.navy,
                            ),
                          ),
                        ),
                        if (isFailed)
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AdminDirectoryTheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$action · $resource',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$userName · ${DateFormat.MMMd().add_jm().format(timestamp)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmploymentStatusBanner extends StatelessWidget {
  const EmploymentStatusBanner({
    super.key,
    required this.status,
    this.company,
    this.position,
  });

  final String status;
  final String? company;
  final String? position;

  @override
  Widget build(BuildContext context) {
    final employed = status == 'Employed';
    final color = employed
        ? AdminDirectoryTheme.success
        : AdminDirectoryTheme.warning;
    final bg = employed
        ? AdminDirectoryTheme.successBg
        : AdminDirectoryTheme.warningBg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              employed ? Icons.work : Icons.person_off_outlined,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (employed && company != null && company!.isNotEmpty)
                  Text(
                    company!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdminDirectoryTheme.navy,
                    ),
                  ),
                if (employed && position != null && position!.isNotEmpty)
                  Text(
                    position!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
