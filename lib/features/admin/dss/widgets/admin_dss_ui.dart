import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_page_header.dart';

/// DSS admin chrome — aliases Alumni Directory tokens (same as Surveys).
abstract final class AdminDssTheme {
  static const primary = AdminDirectoryTheme.primary;
  static const navy = AdminDirectoryTheme.navy;
  static const background = AdminDirectoryTheme.background;
  static const surface = AdminDirectoryTheme.surface;
  static const card = AdminDirectoryTheme.card;
  static const border = AdminDirectoryTheme.border;
  static const textPrimary = AdminDirectoryTheme.textPrimary;
  static const textSecondary = AdminDirectoryTheme.textSecondary;
  static const textMuted = AdminDirectoryTheme.textMuted;
  static const success = AdminDirectoryTheme.success;
  static const successBg = AdminDirectoryTheme.successBg;
  static const warning = AdminDirectoryTheme.warning;
  static const warningBg = AdminDirectoryTheme.warningBg;
  static const info = AdminDirectoryTheme.info;
  static const infoBg = AdminDirectoryTheme.infoBg;
  static const danger = AdminDirectoryTheme.danger;
  static const dangerBg = AdminDirectoryTheme.dangerBg;
  static const space1 = AdminDirectoryTheme.space1;
  static const space2 = AdminDirectoryTheme.space2;
  static const space3 = AdminDirectoryTheme.space3;
  static const buttonHeight = AdminDirectoryTheme.buttonHeight;
  static const toolbarControlHeight = AdminDirectoryTheme.toolbarControlHeight;
  static const radiusSm = AdminDirectoryTheme.radiusSm;
  static const radiusMd = AdminDirectoryTheme.radiusMd;
}

ButtonStyle dssOutlinedButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: AdminDssTheme.textPrimary,
  side: const BorderSide(color: AdminDssTheme.border),
  minimumSize: const Size(0, AdminDssTheme.buttonHeight),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
  ),
);

ButtonStyle dssFilledButtonStyle({Color? background}) =>
    FilledButton.styleFrom(
      backgroundColor: background ?? AdminDssTheme.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, AdminDssTheme.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
      ),
    );

Color dssStatusColor(DssFlagStatus status) => switch (status) {
  DssFlagStatus.open => AdminDssTheme.danger,
  DssFlagStatus.inProgress => AdminDssTheme.warning,
  DssFlagStatus.resolved => AdminDssTheme.success,
  DssFlagStatus.dismissed => AdminDssTheme.textMuted,
};

Color dssSeverityColor(DssSeverity severity) => switch (severity) {
  DssSeverity.critical => AdminDssTheme.danger,
  DssSeverity.warning => AdminDssTheme.warning,
  DssSeverity.info => AdminDssTheme.info,
};

IconData dssRuleIcon(String ruleId) => switch (ruleId) {
  'DATA_QUALITY_LOW' => Icons.fact_check_outlined,
  'UNEMPLOYMENT_HIGH' => Icons.work_off_outlined,
  'RELATEDNESS_LOW' => Icons.school_outlined,
  'RELATEDNESS_HIGH' => Icons.emoji_events_outlined,
  'UNDEREMPLOYMENT' => Icons.trending_down,
  'TIME_TO_JOB_LONG' => Icons.schedule_outlined,
  'SALARY_STAGNATION' => Icons.payments_outlined,
  'UNEMPLOYMENT_TREND_UP' => Icons.trending_up,
  _ => Icons.lightbulb_outline,
};

class DssPageHeader extends StatelessWidget {
  const DssPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.backTooltip = 'Back',
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: title,
      subtitle: subtitle,
      titleFontSize: AdminDensity.titleFontSize,
      titleColor: AdminDssTheme.textPrimary,
      subtitleColor: AdminDssTheme.textSecondary,
      leading: onBack == null
          ? null
          : IconButton(
              tooltip: backTooltip,
              onPressed: onBack,
              style: AdminDensity.iconButtonStyle(
                foregroundColor: AdminDssTheme.textSecondary,
              ),
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
      actions: actions,
    );
  }
}

class DssStatusChip extends StatelessWidget {
  const DssStatusChip({super.key, required this.status});

  final DssFlagStatus status;

  @override
  Widget build(BuildContext context) {
    final color = dssStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class DssCertaintyChip extends StatelessWidget {
  const DssCertaintyChip({super.key, required this.flag});

  final DssFlag flag;

  @override
  Widget build(BuildContext context) {
    final certainty = flag.certainty;
    if (certainty == null) return const SizedBox.shrink();
    final confirmed = certainty == DssCertainty.confirmed;
    return Tooltip(
      message: DssCopy.certaintyHint(flag),
      child: DssMetaChip(
        label: certainty.label,
        icon: confirmed ? Icons.verified_outlined : Icons.help_outline,
        color: confirmed ? AdminDssTheme.navy : AdminDssTheme.textSecondary,
      ),
    );
  }
}

class DssMetaChip extends StatelessWidget {
  const DssMetaChip({
    super.key,
    required this.label,
    this.color = AdminDssTheme.textSecondary,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DssSurfaceCard extends StatelessWidget {
  const DssSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AdminDensity.cardPadding),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: AdminDirectoryTheme.surfaceCard(),
      child: child,
    );
  }
}

/// Compact task-queue row matching Surveys list cards.
class DssFlagListCard extends StatefulWidget {
  const DssFlagListCard({
    super.key,
    required this.flag,
    required this.onOpen,
    this.selected = false,
  });

  final DssFlag flag;
  final VoidCallback onOpen;
  final bool selected;

  @override
  State<DssFlagListCard> createState() => _DssFlagListCardState();
}

class _DssFlagListCardState extends State<DssFlagListCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final flag = widget.flag;
    final severity = flag.severity ?? DssSeverity.warning;
    final sevColor = dssSeverityColor(severity);
    final title = DssCopy.displayTitle(flag);
    final why = DssCopy.whyFlagged(flag);

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminDensity.listItemGap),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(AdminDssTheme.radiusMd),
            child: Tooltip(
              message: why,
              waitDuration: const Duration(milliseconds: 500),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: AdminDssTheme.card,
                  borderRadius: BorderRadius.circular(AdminDssTheme.radiusMd),
                  border: Border.all(
                    color: widget.selected
                        ? AdminDssTheme.primary
                        : AdminDssTheme.border,
                    width: widget.selected ? 1.5 : 1,
                  ),
                  boxShadow: _hovered || widget.selected
                      ? AdminDirectoryTheme.cardShadowHover
                      : AdminDirectoryTheme.cardShadow,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: sevColor),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AdminDssTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${flag.cohortLabel} · ${flag.status.label} · ${DssCopy.responsesLabel(flag)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AdminDssTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (flag.certainty != null) ...[
                                const SizedBox(width: 8),
                                DssCertaintyChip(flag: flag),
                              ],
                              const Icon(
                                Icons.chevron_right,
                                color: AdminDssTheme.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DssInsightBanner extends StatelessWidget {
  const DssInsightBanner({
    super.key,
    required this.text,
    this.onDismiss,
    this.icon = Icons.auto_awesome,
  });

  final String text;
  final VoidCallback? onDismiss;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DssSurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AdminDssTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              softWrap: true,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AdminDssTheme.textPrimary,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              style: AdminDensity.iconButtonStyle(
                foregroundColor: AdminDssTheme.textMuted,
              ),
              icon: const Icon(Icons.close, size: 16),
            ),
        ],
      ),
    );
  }
}
