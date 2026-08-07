/// Shared desktop form layout helpers for the Admin Portal.
///
/// Use with [showAdminDialogSurface] for dialogs and inside page bodies for
/// long editors. Multi-column rows kick in at [kAdminFormWideBreakpoint].
library;

import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Width at which form rows switch to two columns.
const double kAdminFormWideBreakpoint = 960.0;

/// Named dialog widths for consistent admin surfaces.
const double kAdminDialogSm = 400;
const double kAdminDialogMd = 560;
const double kAdminDialogLg = 640;
const double kAdminDialogXl = 800;

/// Section card with title + optional subtitle wrapping form fields.
class AdminFormSection extends StatelessWidget {
  const AdminFormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.padding = const EdgeInsets.all(AdminDensity.formSectionPadding),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AdminDensity.sectionTitleFontSize,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF64748B),
              ),
            ),
          ],
          const SizedBox(height: AdminDensity.formFieldGap),
          child,
        ],
      ),
    );
  }
}

/// Responsive form row: stacks below [kAdminFormWideBreakpoint], else side-by-side.
class AdminFormRow extends StatelessWidget {
  const AdminFormRow({
    super.key,
    required this.children,
    this.gap = AdminDensity.formFieldGap,
    this.breakpoint = kAdminFormWideBreakpoint,
  });

  final List<Widget> children;
  final double gap;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;
        if (!wide || children.length == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Sticky elevated action bar for long forms (page or dialog footer).
class AdminFormActionsBar extends StatelessWidget {
  const AdminFormActionsBar({
    super.key,
    this.leading = const [],
    this.actions = const [],
    this.padding = AdminDensity.formActionsPadding,
  });

  final List<Widget> leading;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;
            final leadingRow = leading.isEmpty
                ? null
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: leading,
                  );
            final actionsRow = actions.isEmpty
                ? null
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment:
                        narrow ? WrapAlignment.start : WrapAlignment.end,
                    children: actions,
                  );

            if (narrow) {
              return Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leadingRow != null) leadingRow,
                    if (leadingRow != null && actionsRow != null)
                      const SizedBox(height: 10),
                    if (actionsRow != null) actionsRow,
                  ],
                ),
              );
            }

            return Padding(
              padding: padding,
              child: Row(
                children: [
                  if (leadingRow != null) leadingRow,
                  const Spacer(),
                  if (actionsRow != null) actionsRow,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
