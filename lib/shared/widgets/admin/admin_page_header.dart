/// Shared desktop page chrome for the Admin Portal.
///
/// Provides a consistent rhythm across admin screens:
/// title → optional short subtitle → visible action toolbar. The shell's
/// sidebar selection and top-header title already signal location, so page
/// headers stay breadcrumb-free.
library;

import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

/// Standard admin page header: title, optional subtitle, actions.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.below,
    this.titleColor = const Color(0xFF0F172A),
    this.subtitleColor = const Color(0xFF64748B),
    this.titleFontSize = AdminDensity.titleFontSize,
    this.narrowBreakpoint = 768,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? below;
  final Color titleColor;
  final Color subtitleColor;
  final double titleFontSize;
  final double narrowBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < narrowBreakpoint;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: AdminDensity.subtitleFontSize,
                  height: 1.35,
                  color: subtitleColor,
                ),
              ),
            ],
          ],
        );

        final actionRow = actions.isEmpty
            ? null
            : Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: narrow ? WrapAlignment.start : WrapAlignment.end,
                children: actions,
              );

        Widget header;
        if (actionRow == null) {
          header = titleBlock;
        } else if (narrow) {
          header = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleBlock, const SizedBox(height: 8), actionRow],
          );
        } else {
          header = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 12),
              actionRow,
            ],
          );
        }

        if (below == null) return header;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, const SizedBox(height: 8), below!],
        );
      },
    );
  }
}
