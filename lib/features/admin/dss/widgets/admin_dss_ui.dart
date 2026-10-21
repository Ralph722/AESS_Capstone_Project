import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_priority.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_tab_bar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

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

ButtonStyle dssOutlinedButtonStyle() => AdminButtonStyles.outlined();

ButtonStyle dssFilledButtonStyle({Color? background}) =>
    AdminButtonStyles.filled(background: background);

Color dssStatusColor(DssFlagStatus status) => switch (status) {
  DssFlagStatus.open => AdminDssTheme.danger,
  DssFlagStatus.inProgress => AdminDssTheme.warning,
  DssFlagStatus.resolved => AdminDssTheme.success,
  DssFlagStatus.dismissed => AdminDssTheme.textMuted,
  DssFlagStatus.watch => AdminDssTheme.info,
  DssFlagStatus.superseded => AdminDssTheme.textMuted,
};

Color dssSeverityColor(DssSeverity severity) => switch (severity) {
  DssSeverity.critical => AdminDssTheme.danger,
  DssSeverity.warning => AdminDssTheme.warning,
  DssSeverity.info => AdminDssTheme.info,
};

IconData dssRuleIcon(String ruleId) => switch (ruleId) {
  'DATA_QUALITY_LOW' => Icons.fact_check_outlined,
  'UNEMPLOYMENT_HIGH' => Icons.work_off_outlined,
  'SEEKING_WORK_HIGH' => Icons.person_search_outlined,
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
    this.selectedSubnav,
    this.onSubnavSelected,
    this.trailingSubnav,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final String backTooltip;
  final int? selectedSubnav;
  final ValueChanged<int>? onSubnavSelected;
  final Widget? trailingSubnav;

  @override
  Widget build(BuildContext context) {
    final hasTabs = selectedSubnav != null && onSubnavSelected != null;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
        boxShadow: AdminSurfaces.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                if (onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      tooltip: backTooltip,
                      onPressed: onBack,
                      style: IconButton.styleFrom(
                        backgroundColor: AdminColors.surface,
                        foregroundColor: AdminColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AdminColors.border),
                        ),
                        minimumSize: const Size(36, 36),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 18),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AdminColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AdminColors.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        size: 20,
                        color: AdminColors.primary,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AdminDensity.titleFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AdminDensity.subtitleFontSize,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
          if (hasTabs) ...[
            const Divider(height: 1, thickness: 1, color: AdminColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: AdminTabBar(
                      selectedIndex: selectedSubnav!.clamp(0, 2),
                      onSelected: onSubnavSelected!,
                      isScrollable: true,
                      background: Colors.transparent,
                      tabs: const [
                        AdminTabSpec(
                          label: 'Findings',
                          icon: Icons.flag_outlined,
                        ),
                        AdminTabSpec(
                          label: 'History',
                          icon: Icons.timeline,
                        ),
                        AdminTabSpec(
                          label: 'Rules',
                          icon: Icons.tune,
                        ),
                      ],
                    ),
                  ),
                  if (trailingSubnav != null) ...[
                    const SizedBox(width: 8),
                    trailingSubnav!,
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
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
        borderRadius: BorderRadius.circular(6),
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

/// Sample-size level of an outcome flag. Hidden for strong evidence and for
/// data-quality checks.
class DssEvidenceChip extends StatelessWidget {
  const DssEvidenceChip({super.key, required this.flag});

  final DssFlag flag;

  @override
  Widget build(BuildContext context) {
    final strength = flag.evidenceStrength;
    if (strength == null || strength == DssEvidenceStrength.strong) {
      return const SizedBox.shrink();
    }
    final (icon, color) = switch (strength) {
      DssEvidenceStrength.insufficient => (
        Icons.block_outlined,
        AdminDssTheme.textMuted,
      ),
      DssEvidenceStrength.watch => (
        Icons.visibility_outlined,
        const Color(0xFFB45309),
      ),
      _ => (Icons.info_outline, AdminDssTheme.textSecondary),
    };
    return Tooltip(
      message: DssCopy.evidenceLabel(flag) ?? strength.label,
      child: DssMetaChip(label: strength.label, icon: icon, color: color),
    );
  }
}

Color dssPriorityColor(DssPriority priority) => switch (priority) {
  DssPriority.critical => AdminDssTheme.danger,
  DssPriority.high => AdminDssTheme.warning,
  DssPriority.medium => AdminDssTheme.info,
  DssPriority.low => AdminDssTheme.textSecondary,
  DssPriority.watch => AdminDssTheme.textMuted,
};

/// Rule-based priority of an active finding; the tooltip lists every reason.
class DssPriorityChip extends StatelessWidget {
  const DssPriorityChip({super.key, required this.flag});

  final DssFlag flag;

  @override
  Widget build(BuildContext context) {
    if (!flag.isActive) return const SizedBox.shrink();
    final p = DssPriorityCalc.of(flag, now: DateTime.now());
    if (p.level == DssPriority.watch) return const SizedBox.shrink();
    return Tooltip(
      message: [
        'Priority ${p.level.label} (score ${p.score})',
        for (final r in p.reasons) '• ${r.display}',
      ].join('\n'),
      child: DssMetaChip(
        label: p.level.label,
        icon: Icons.low_priority,
        color: dssPriorityColor(p.level),
      ),
    );
  }
}

/// Overdue, or due within [soonDays], for open and in-progress flags.
class DssDueChip extends StatelessWidget {
  const DssDueChip({super.key, required this.flag, this.soonDays = 7});

  final DssFlag flag;
  final int soonDays;

  @override
  Widget build(BuildContext context) {
    final due = flag.dueDate;
    final days = flag.daysUntilDue(DateTime.now());
    if (due == null || days == null || days > soonDays) {
      return const SizedBox.shrink();
    }
    final label = days < 0
        ? 'Overdue ${-days}d'
        : (days == 0 ? 'Due today' : 'Due in ${days}d');
    return Tooltip(
      message: 'Due ${DateFormat.yMMMd().format(due)}',
      child: DssMetaChip(
        label: label,
        icon: days < 0 ? Icons.event_busy : Icons.event,
        color: days < 0 ? AdminDssTheme.danger : AdminDssTheme.warning,
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

  static String _nextAction(DssFlag flag) => switch (flag.status) {
    DssFlagStatus.open => 'Start',
    DssFlagStatus.inProgress => 'Continue',
    DssFlagStatus.watch => 'Monitor',
    DssFlagStatus.resolved => 'Review',
    DssFlagStatus.dismissed => 'Reopen',
    DssFlagStatus.superseded => 'History',
  };

  @override
  Widget build(BuildContext context) {
    final flag = widget.flag;
    final title = DssCopy.displayTitle(flag);
    final why = DssCopy.whyFlagged(flag);
    final next = _nextAction(flag);

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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: AdminColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Icon(
                          dssRuleIcon(flag.ruleId),
                          size: 18,
                          color: AdminColors.primary,
                        ),
                      ),
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
                            const SizedBox(height: 3),
                            Text(
                              why,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AdminDssTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AdminColors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AdminColors.border),
                                  ),
                                  child: Text(
                                    flag.cohortLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AdminColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DssStatusChip(status: flag.status),
                                Text(
                                  '· ${DssCopy.responsesLabel(flag)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AdminDssTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  '· Next: $next',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DssDueChip(flag: flag),
                      const SizedBox(width: 6),
                      DssPriorityChip(flag: flag),
                      if (flag.evidenceStrength != null &&
                          flag.evidenceStrength !=
                              DssEvidenceStrength.strong) ...[
                        const SizedBox(width: 6),
                        DssEvidenceChip(flag: flag),
                      ],
                      if (flag.certainty != null && flag.isFinding) ...[
                        const SizedBox(width: 6),
                        DssCertaintyChip(flag: flag),
                      ],
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: AdminDssTheme.textMuted,
                        size: 20,
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

/// Derived workflow stage for a finding (display only).
enum DssWorkflowStage { detected, inProgress, resolved, outcome }

extension DssWorkflowStageX on DssWorkflowStage {
  String get label => switch (this) {
    DssWorkflowStage.detected => 'Detected',
    DssWorkflowStage.inProgress => 'In progress',
    DssWorkflowStage.resolved => 'Resolved',
    DssWorkflowStage.outcome => 'Outcome',
  };
}

/// Stage strip: Detected → In progress → Resolved → Outcome.
class DssStageStrip extends StatelessWidget {
  const DssStageStrip({
    super.key,
    required this.flag,
    this.hasUndecidedIntervention = false,
    this.outcomeReady = false,
  });

  final DssFlag flag;
  final bool hasUndecidedIntervention;
  final bool outcomeReady;

  static DssWorkflowStage stageOf(
    DssFlag flag, {
    required bool hasUndecidedIntervention,
    required bool outcomeReady,
  }) {
    if (flag.status == DssFlagStatus.watch) {
      return DssWorkflowStage.detected;
    }
    if (flag.status == DssFlagStatus.superseded) {
      return DssWorkflowStage.resolved;
    }
    if (flag.status == DssFlagStatus.dismissed) {
      return DssWorkflowStage.resolved;
    }
    if (flag.status == DssFlagStatus.open) {
      return DssWorkflowStage.detected;
    }
    if (flag.status == DssFlagStatus.inProgress) {
      return DssWorkflowStage.inProgress;
    }
    // Resolved (or closed with intervention follow-up).
    if (outcomeReady ||
        (hasUndecidedIntervention && flag.status == DssFlagStatus.resolved)) {
      return DssWorkflowStage.outcome;
    }
    if (flag.status == DssFlagStatus.resolved) {
      return hasUndecidedIntervention
          ? DssWorkflowStage.outcome
          : DssWorkflowStage.resolved;
    }
    return DssWorkflowStage.resolved;
  }

  @override
  Widget build(BuildContext context) {
    final current = stageOf(
      flag,
      hasUndecidedIntervention: hasUndecidedIntervention,
      outcomeReady: outcomeReady,
    );
    final stages = DssWorkflowStage.values;
    final currentIndex = stages.indexOf(current);
    String hint = switch (flag.status) {
      DssFlagStatus.watch => 'Watch — wait for more answers, or dismiss.',
      DssFlagStatus.superseded => 'Superseded — read-only.',
      DssFlagStatus.open => 'Next: Start',
      DssFlagStatus.inProgress => 'Next: act, add Proof, Resolve finding',
      DssFlagStatus.resolved =>
        hasUndecidedIntervention || outcomeReady
            ? 'Next: check outcome and decide'
            : 'Closed — awaiting next wave',
      DssFlagStatus.dismissed => 'Dismissed — Reopen if needed',
    };

    return DssSurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: i <= currentIndex
                          ? AdminDssTheme.primary.withValues(alpha: 0.45)
                          : AdminDssTheme.border,
                    ),
                  ),
                _StageDot(
                  label: stages[i].label,
                  active: i == currentIndex,
                  done: i < currentIndex,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AdminDssTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({
    required this.label,
    required this.active,
    required this.done,
  });

  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = active || done
        ? AdminDssTheme.primary
        : AdminDssTheme.textMuted;
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AdminDssTheme.primary
                : done
                ? AdminDssTheme.primary.withValues(alpha: 0.2)
                : AdminDssTheme.surface,
            border: Border.all(color: color, width: active ? 0 : 1.5),
          ),
          child: Icon(
            done && !active ? Icons.check : Icons.circle,
            size: done && !active ? 12 : 8,
            color: active
                ? Colors.white
                : done
                ? AdminDssTheme.primary
                : AdminDssTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Module sub-navigation: Findings | History | Rules.
class DssModuleSubnav extends StatelessWidget {
  const DssModuleSubnav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// 0 = Findings, 1 = History, 2 = Rules.
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return AdminTabBar(
      selectedIndex: selectedIndex.clamp(0, 2),
      onSelected: onSelected,
      isScrollable: true,
      background: Colors.transparent,
      tabs: const [
        AdminTabSpec(label: 'Findings', icon: Icons.flag_outlined),
        AdminTabSpec(label: 'History', icon: Icons.timeline),
        AdminTabSpec(label: 'Rules', icon: Icons.tune),
      ],
    );
  }
}

class DssInsightBanner extends StatelessWidget {
  const DssInsightBanner({
    super.key,
    required this.text,
    this.onDismiss,
    this.trailing,
    this.icon = Icons.auto_awesome,
  });

  final String text;
  final VoidCallback? onDismiss;
  final Widget? trailing;
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
          if (trailing != null) trailing!,
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
