import 'package:flutter/material.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Section title with optional caption, leading icon and actions.
/// Actions move below the title when the width is too narrow for one row.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.leadingIcon,
    this.actions = const [],
    this.stackBelow = 480,
  });

  final String title;
  final String? caption;
  final IconData? leadingIcon;
  final List<Widget> actions;

  /// Width below which [actions] wrap under the title.
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleBlock = _buildTitleBlock();
        if (actions.isEmpty) return titleBlock;

        final actionWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        if (constraints.maxWidth < stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [titleBlock, const SizedBox(height: 8), actionWrap],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            actionWrap,
          ],
        );
      },
    );
  }

  Widget _buildTitleBlock() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leadingIcon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(leadingIcon, size: 18, color: AdminColors.primary),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: AdminText.sectionTitle),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(caption!, style: AdminText.caption),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
