import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// App-wide defaults for menus, dropdowns, dialogs, sheets and pickers in the
/// alumni portal. Suspended while the admin dashboard is mounted so admin
/// screens keep their own styling.
abstract final class PortalOverlayTheme {
  static final ValueNotifier<bool> suspended = ValueNotifier<bool>(false);

  static ThemeData apply(ThemeData base) {
    final menuStyle = MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(PortalTheme.card),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(6),
      shadowColor: WidgetStatePropertyAll(PortalMenu.shadowColor),
      shape: WidgetStatePropertyAll(PortalMenu.menuShape as OutlinedBorder),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
    );

    return base.copyWith(
      canvasColor: PortalTheme.card,
      popupMenuTheme: PopupMenuThemeData(
        color: PortalTheme.card,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: PortalMenu.shadowColor,
        shape: PortalMenu.menuShape,
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
        position: PopupMenuPosition.under,
        textStyle: PortalMenu.itemText,
        labelTextStyle: const WidgetStatePropertyAll(PortalMenu.itemText),
        iconColor: PortalTheme.textSecondary,
      ),
      menuTheme: MenuThemeData(style: menuStyle),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: menuStyle,
        textStyle: PortalMenu.itemText,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PortalTheme.card,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: PortalMenu.shadowColor,
        shape: PortalMenu.dialogShape,
        titleTextStyle: PortalTheme.pageTitle,
        contentTextStyle: PortalTheme.bodySecondary,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PortalTheme.card,
        modalBackgroundColor: PortalTheme.card,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: PortalTheme.borderStrong,
        dragHandleSize: Size(40, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PortalTheme.radius2xl),
          ),
        ),
      ),
      datePickerTheme: datePicker,
      timePickerTheme: timePicker,
    );
  }

  static WidgetStateProperty<Color?> _selected(Color on, Color? off) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? on : off,
      );

  static ButtonStyle get _cancelButton =>
      PortalTheme.ghostButton(dense: true).copyWith(
        foregroundColor: const WidgetStatePropertyAll(
          PortalTheme.textSecondary,
        ),
      );

  static ButtonStyle get _confirmButton =>
      PortalTheme.primaryButton(dense: true);

  static InputDecorationTheme get _pickerInput => InputDecorationTheme(
    filled: true,
    fillColor: PortalTheme.surfaceMuted,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      borderSide: const BorderSide(color: PortalTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      borderSide: const BorderSide(color: PortalTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
      borderSide: const BorderSide(color: PortalTheme.navy, width: 1.5),
    ),
  );

  /// White calendar with navy selection and a gold ring on today.
  static DatePickerThemeData get datePicker => DatePickerThemeData(
    backgroundColor: PortalTheme.card,
    surfaceTintColor: Colors.transparent,
    elevation: 6,
    shadowColor: PortalMenu.shadowColor,
    shape: PortalMenu.dialogShape as OutlinedBorder,
    headerBackgroundColor: PortalTheme.card,
    headerForegroundColor: PortalTheme.navy,
    headerHelpStyle: PortalTheme.meta.copyWith(fontWeight: FontWeight.w600),
    headerHeadlineStyle: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: PortalTheme.navy,
    ),
    dividerColor: PortalTheme.border,
    weekdayStyle: PortalTheme.meta.copyWith(fontWeight: FontWeight.w700),
    dayStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      if (states.contains(WidgetState.disabled)) return PortalTheme.textMuted;
      return PortalTheme.textPrimary;
    }),
    dayBackgroundColor: _selected(PortalTheme.navy, null),
    dayOverlayColor: WidgetStatePropertyAll(
      PortalTheme.navy.withValues(alpha: 0.08),
    ),
    todayForegroundColor: _selected(Colors.white, PortalTheme.navy),
    todayBackgroundColor: _selected(PortalTheme.navy, null),
    todayBorder: const BorderSide(color: PortalTheme.gold, width: 2),
    yearForegroundColor: _selected(Colors.white, PortalTheme.textPrimary),
    yearBackgroundColor: _selected(PortalTheme.navy, null),
    yearOverlayColor: WidgetStatePropertyAll(
      PortalTheme.navy.withValues(alpha: 0.08),
    ),
    cancelButtonStyle: _cancelButton,
    confirmButtonStyle: _confirmButton,
    inputDecorationTheme: _pickerInput,
  );

  /// White clock with a navy hand / selected time and a gold AM-PM choice.
  static TimePickerThemeData get timePicker => TimePickerThemeData(
    backgroundColor: PortalTheme.card,
    elevation: 6,
    shape: PortalMenu.dialogShape as OutlinedBorder,
    helpTextStyle: PortalTheme.meta.copyWith(fontWeight: FontWeight.w600),
    hourMinuteShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
    ),
    hourMinuteColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? PortalTheme.navy
          : PortalTheme.surfaceMuted,
    ),
    hourMinuteTextColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.white
          : PortalTheme.textPrimary,
    ),
    dayPeriodShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
    ),
    dayPeriodBorderSide: const BorderSide(color: PortalTheme.border),
    dayPeriodColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? PortalTheme.gold
          : Colors.transparent,
    ),
    dayPeriodTextColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? PortalTheme.navy
          : PortalTheme.textSecondary,
    ),
    dialBackgroundColor: PortalTheme.surfaceMuted,
    dialHandColor: PortalTheme.navy,
    dialTextColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.white
          : PortalTheme.textPrimary,
    ),
    entryModeIconColor: PortalTheme.textSecondary,
    cancelButtonStyle: _cancelButton,
    confirmButtonStyle: _confirmButton,
    inputDecorationTheme: _pickerInput,
  );

  /// `builder:` for showDatePicker / showTimePicker. Also sets the colour
  /// scheme bits the picker themes don't cover (month arrows, edit mode).
  static Widget pickerBuilder(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: PortalTheme.navy,
          onPrimary: Colors.white,
          secondary: PortalTheme.gold,
          onSecondary: PortalTheme.navy,
          surface: PortalTheme.card,
          surfaceTint: Colors.transparent,
          onSurface: PortalTheme.textPrimary,
          onSurfaceVariant: PortalTheme.textSecondary,
        ),
        datePickerTheme: datePicker,
        timePickerTheme: timePicker,
      ),
      child: child!,
    );
  }
}
