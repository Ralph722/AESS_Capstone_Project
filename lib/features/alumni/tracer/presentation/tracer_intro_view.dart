import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/alumni/tracer/data/tracer_reminder_service.dart';
import 'package:alumni_system/features/alumni/tracer/presentation/tracer_reminder_sheet.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_wizard.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// "What is the tracer about" screen shown before the CHED GTS form opens.
class TracerIntroView extends StatelessWidget {
  const TracerIntroView({
    super.key,
    required this.survey,
    required this.fallbackTitle,
    required this.answers,
    required this.hasDraft,
    required this.onStart,
    this.reminder,
    this.onSetReminder,
    this.onCancelReminder,
  });

  final Survey? survey;
  final String fallbackTitle;
  final Map<String, dynamic> answers;
  final bool hasDraft;
  final VoidCallback onStart;
  final TracerReminder? reminder;
  final VoidCallback? onSetReminder;
  final VoidCallback? onCancelReminder;

  int get _requiredPercent {
    final visible = ChedGtsVisibility.visibleItemIds(answers);
    final requiredCount = ChedGtsBuiltin.items
        .where((i) => i.required && visible.contains(i.id))
        .length;
    if (requiredCount == 0) return 0;
    final missing = ChedGtsVisibility.missingRequired(answers).length;
    return (((requiredCount - missing) / requiredCount) * 100).round().clamp(
      0,
      100,
    );
  }

  String get _startLabel => hasDraft ? 'Continue answering' : 'Answer now';

  @override
  Widget build(BuildContext context) {
    final description = survey?.description.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(),
        if (reminder?.isUpcoming == true) ...[
          const SizedBox(height: PortalTheme.space2),
          _ReminderCard(
            reminder: reminder!,
            onChange: onSetReminder,
            onCancel: onCancelReminder,
          ),
        ] else if (hasDraft && onSetReminder != null) ...[
          const SizedBox(height: PortalTheme.space2),
          _RemindLaterCard(onTap: onSetReminder!),
        ],
        const SizedBox(height: PortalTheme.space3),
        _InfoCard(
          icon: Icons.school_outlined,
          title: 'What is the CHED GTS?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The Graduate Tracer Study (GTS) is the Commission on Higher '
                'Education\'s official survey of graduates. It follows up on '
                'where alumni are now (further studies, employment, and how '
                'well their degree prepared them) so the university can '
                'improve its programs for future students.',
                style: PortalTheme.bodySecondary,
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PortalTheme.pageBg,
                    borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                    border: Border.all(color: PortalTheme.border),
                  ),
                  child: Text(
                    description,
                    style: PortalTheme.body.copyWith(fontSize: 13.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: PortalTheme.space2),
        _InfoCard(
          icon: Icons.list_alt_rounded,
          title: 'What you\'ll answer',
          trailing: const PortalChip(
            label: '10–15 min',
            icon: Icons.timer_outlined,
            tone: PortalChipTone.neutral,
          ),
          child: Column(
            children: [
              for (final section in ChedGtsSection.values)
                _SectionRow(section: section),
            ],
          ),
        ),
        const SizedBox(height: PortalTheme.space2),
        const _InfoCard(
          icon: Icons.tips_and_updates_outlined,
          title: 'Before you start',
          child: Column(
            children: [
              _TipRow(
                icon: Icons.work_outline_rounded,
                text:
                    'Have your employment details ready: company, position, '
                    'and how you found the job.',
              ),
              _TipRow(
                icon: Icons.auto_awesome_outlined,
                text:
                    'Some answers are pre-filled from your profile. Please '
                    'check that they\'re still correct.',
              ),
              _TipRow(
                icon: Icons.save_outlined,
                text:
                    'You can save a draft anytime and continue where you '
                    'left off.',
              ),
              _TipRow(
                icon: Icons.priority_high_rounded,
                text:
                    'Questions marked Required must be answered before you '
                    'can move to the next step.',
              ),
            ],
          ),
        ),
        const SizedBox(height: PortalTheme.space2),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PortalTheme.navy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: PortalTheme.navy,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your answers are confidential and used only for CHED '
                  'reporting and program improvement.',
                  style: PortalTheme.meta,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hero() {
    final title = survey?.title.trim().isNotEmpty == true
        ? survey!.title.trim()
        : fallbackTitle;
    final closeAt = survey?.closeAt;
    final percent = _requiredPercent;
    final closingSoon =
        closeAt != null &&
        closeAt.difference(DateTime.now()) <= const Duration(days: 3);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFEEF0F8)],
        ),
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.75)),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _HeroPill(
                icon: Icons.circle,
                iconSize: 8,
                label: 'Open now',
                color: PortalTheme.success,
              ),
              if (closeAt != null)
                _HeroPill(
                  icon: Icons.event_outlined,
                  label: 'Closes ${DateFormat.yMMMd().format(closeAt)}',
                  color: closingSoon
                      ? PortalTheme.warning
                      : PortalTheme.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: PortalTheme.sectionTitle.copyWith(color: PortalTheme.navy),
          ),
          const SizedBox(height: 6),
          const Text(
            'Commission on Higher Education · Graduate Tracer Study',
            style: PortalTheme.meta,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    backgroundColor: PortalTheme.border,
                    color: PortalTheme.gold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PortalTheme.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasDraft
                ? 'In progress · your draft is saved'
                : 'Not started · some answers are pre-filled',
            style: PortalTheme.caption,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              style: PortalTheme.primaryButton(),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(_startLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 14,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatefulWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PortalTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        side: BorderSide(color: PortalTheme.border.withValues(alpha: 0.75)),
      ),
      shadowColor: PortalTheme.navy.withValues(alpha: 0.18),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              splashColor: PortalTheme.navy.withValues(alpha: 0.06),
              highlightColor: PortalTheme.navy.withValues(alpha: 0.04),
              hoverColor: PortalTheme.navy.withValues(alpha: 0.03),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PortalTheme.space3,
                  PortalTheme.space2,
                  PortalTheme.space2,
                  PortalTheme.space2,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: PortalTheme.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          PortalTheme.radiusMd,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: PortalTheme.navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: PortalTheme.cardTitle.copyWith(fontSize: 15),
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      widget.trailing!,
                      const SizedBox(width: 4),
                    ],
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: PortalTheme.normal,
                      curve: Curves.easeOutCubic,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: PortalTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: PortalTheme.normal,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PortalTheme.space3,
                      0,
                      PortalTheme.space3,
                      PortalTheme.space3,
                    ),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section});

  final ChedGtsSection section;

  @override
  Widget build(BuildContext context) {
    final count = ChedGtsBuiltin.items
        .where((i) => i.section == section && !i.isOthersSpecify)
        .length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PortalTheme.gold.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              section.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: PortalTheme.navy,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chedSectionLabel(section),
              style: PortalTheme.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            section == ChedGtsSection.d
                ? 'up to $count questions'
                : '$count ${count == 1 ? 'question' : 'questions'}',
            style: PortalTheme.meta,
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: PortalTheme.navyMid),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: PortalTheme.bodySecondary.copyWith(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration get _smallCardDecoration => BoxDecoration(
  color: PortalTheme.card,
  borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
  border: Border.all(color: PortalTheme.border.withValues(alpha: 0.75)),
);

Widget _bellTile(IconData icon) => Container(
  width: 36,
  height: 36,
  decoration: BoxDecoration(
    color: PortalTheme.navy.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
  ),
  child: Icon(icon, size: 20, color: PortalTheme.navy),
);

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onChange,
    required this.onCancel,
  });

  final TracerReminder reminder;
  final VoidCallback? onChange;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final when = formatReminderTime(reminder.remindAt);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: _smallCardDecoration,
      child: Row(
        children: [
          _bellTile(Icons.notifications_active_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder set for $when',
                  style: PortalTheme.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PortalTheme.navy,
                  ),
                ),
                if (reminder.repeatHourly) ...[
                  const SizedBox(height: 2),
                  const Text(
                    "Hourly follow-ups that day if you don't open it",
                    style: PortalTheme.meta,
                  ),
                ],
              ],
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              style: PortalTheme.ghostButton(dense: true),
              child: const Text('Change'),
            ),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              style: PortalTheme.ghostButton(dense: true).copyWith(
                foregroundColor: const WidgetStatePropertyAll(
                  PortalTheme.textSecondary,
                ),
              ),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }
}

class _RemindLaterCard extends StatelessWidget {
  const _RemindLaterCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: _smallCardDecoration,
      child: Row(
        children: [
          _bellTile(Icons.notifications_none_rounded),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Need more time? Set a reminder to finish later.',
              style: PortalTheme.bodySecondary,
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Remind me'),
          ),
        ],
      ),
    );
  }
}
