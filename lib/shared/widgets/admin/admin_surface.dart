/// Desktop-first surface helpers for the Admin Portal.
///
/// The admin portal targets desktop web browsers, so detail views, pickers,
/// and previews should open as centered modal dialogs or docked side panels
/// rather than mobile bottom sheets. These helpers standardize that chrome
/// (fixed sizing, elevation, rounded corners, ESC-to-close, keyboard focus,
/// optional click-outside dismissal) while still allowing a bottom-sheet
/// fallback for unusually narrow windows.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Below this width the portal is considered "narrow" and callers may fall
/// back to a bottom sheet. Desktop breakpoints (1280px+) always use dialogs.
const double kAdminSurfaceBreakpoint = 700.0;

const Color _adminScrim = Color(0x730F172A);

/// Whether the current window is wide enough for desktop surfaces.
bool adminIsWideSurface(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kAdminSurfaceBreakpoint;

/// Whether the current window should use phone-oriented admin chrome
/// (drawer nav, full-width panels, bottom-sheet pickers).
bool adminIsPhoneSurface(BuildContext context) =>
    AdminDensity.isPhoneWidth(MediaQuery.sizeOf(context).width);

/// Opens [child] as a centered desktop modal dialog.
///
/// - Fixed [maxWidth] with a sensible [maxHeight] cap.
/// - Rounded corners + elevation.
/// - ESC closes the dialog; click-outside dismissal via [barrierDismissible].
/// - Autofocuses the content so keyboard/tab navigation starts inside.
Future<T?> showAdminDialogSurface<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 720,
  double? maxHeight,
  bool barrierDismissible = true,
  Color backgroundColor = Colors.white,
  double borderRadius = 16,
  EdgeInsets insetPadding = AdminDensity.dialogInsetPadding,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: _adminScrim,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final resolvedHeight = maxHeight ?? size.height * 0.9;
      return _AdminEscDismiss(
        child: Dialog(
          backgroundColor: backgroundColor,
          elevation: 12,
          clipBehavior: Clip.antiAlias,
          insetPadding: insetPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: resolvedHeight,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Opens [child] as a right-docked desktop side panel (drawer-style) that
/// slides in from the trailing edge. Preferred for frequently viewed detail
/// content (survey/alumni/event details) where the user wants to keep the
/// underlying list visible.
Future<T?> showAdminSidePanel<T>({
  required BuildContext context,
  required Widget child,
  double width = 460,
  bool barrierDismissible = true,
  Color backgroundColor = Colors.white,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: _adminScrim,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final size = MediaQuery.sizeOf(ctx);
      // Phone: nearly full-bleed. Wider: keep a gutter so the list stays visible.
      final gutter = AdminDensity.isPhoneWidth(size.width) ? 0.0 : 48.0;
      final resolvedWidth = math.min(width, size.width - gutter);
      return Align(
        alignment: Alignment.centerRight,
        child: _AdminEscDismiss(
          child: Material(
            elevation: 16,
            color: backgroundColor,
            child: SizedBox(
              width: resolvedWidth <= 0 ? size.width : resolvedWidth,
              height: double.infinity,
              child: child,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// A single selectable option for [showAdminOptionPicker].
class AdminPickerOption<T> {
  const AdminPickerOption({
    required this.value,
    required this.label,
    this.icon,
    this.selected = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool selected;
}

/// Desktop-friendly option picker. On wide windows it opens as a compact
/// centered dialog (popover-style); on narrow windows it falls back to a
/// bottom sheet. Returns the chosen value, or `null` if dismissed.
Future<T?> showAdminOptionPicker<T>({
  required BuildContext context,
  required String title,
  required List<AdminPickerOption<T>> options,
}) {
  Widget buildList(BuildContext ctx, {ScrollController? controller}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            controller: controller,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              for (final option in options)
                ListTile(
                  leading: option.icon == null ? null : Icon(option.icon),
                  title: Text(option.label),
                  trailing: option.selected
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () => Navigator.pop(ctx, option.value),
                ),
            ],
          ),
        ),
      ],
    );
  }

  if (adminIsWideSurface(context)) {
    return showAdminDialogSurface<T>(
      context: context,
      maxWidth: 380,
      maxHeight: 480,
      child: Builder(builder: (ctx) => buildList(ctx)),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(child: buildList(ctx)),
  );
}

/// Wraps modal content so the Escape key pops the route and keyboard focus
/// starts inside the surface (desktop keyboard affordances).
class _AdminEscDismiss extends StatelessWidget {
  const _AdminEscDismiss({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: FocusScope(
        autofocus: true,
        child: child,
      ),
    );
  }
}
