import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Shared look for the "type a message and send" bars (forum replies, event
/// comments, support messages).
abstract final class PortalComposer {
  static const double height = 44;
  static const double gap = 8;

  static InputDecoration inputDecoration({
    required String hintText,
    Widget? prefixIcon,
  }) {
    final radius = BorderRadius.circular(height / 2);
    final none = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: PortalTheme.body.copyWith(color: PortalTheme.textMuted),
      filled: true,
      fillColor: PortalTheme.surfaceMuted,
      isDense: true,
      // Web/desktop default to compact density, which trims 8 px off the
      // field and makes it shorter than the send button.
      visualDensity: VisualDensity.standard,
      counterText: '',
      prefixIcon: prefixIcon == null
          ? null
          : SizedBox.square(dimension: height, child: prefixIcon),
      prefixIconConstraints: const BoxConstraints(
        minWidth: height,
        minHeight: height,
      ),
      contentPadding: EdgeInsets.fromLTRB(
        prefixIcon == null ? 16 : 0,
        12,
        16,
        12,
      ),
      border: none,
      enabledBorder: none,
      disabledBorder: none,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: PortalTheme.navy, width: 1.2),
      ),
    );
  }
}

/// White bottom bar whose background spans the full width while its content
/// stays centred within [maxWidth] (or uses a plain 16 px inset when null).
class PortalComposerBar extends StatelessWidget {
  const PortalComposerBar({
    super.key,
    required this.child,
    this.maxWidth,
    this.avoidKeyboard = false,
    this.borderColor = PortalTheme.border,
  });

  final Widget child;
  final double? maxWidth;

  /// Pads for the on-screen keyboard; needed inside bottom sheets, which the
  /// Scaffold does not resize.
  final bool avoidKeyboard;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final keyboard = avoidKeyboard
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inset = maxWidth == null
                  ? 16.0
                  : PortalBreakpoints.centeredInset(
                      constraints.maxWidth,
                      maxWidth: maxWidth!,
                    );
              return Padding(
                padding: EdgeInsets.fromLTRB(inset, 10, inset, 10),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Round navy send button. Pass a null [onPressed] to disable it.
class PortalSendButton extends StatelessWidget {
  const PortalSendButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.label = 'Send',
    this.hint,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? 'Sending, please wait' : label,
      hint: hint,
      child: Tooltip(
        message: label,
        child: SizedBox.square(
          dimension: PortalComposer.height,
          child: Material(
            color: enabled || busy ? PortalTheme.navy : PortalTheme.border,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Center(
                child: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: enabled ? Colors.white : PortalTheme.textMuted,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
