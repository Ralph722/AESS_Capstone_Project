import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_overlay_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

class TracerReminderChoice {
  const TracerReminderChoice({
    required this.remindAt,
    required this.repeatHourly,
  });

  final DateTime remindAt;
  final bool repeatHourly;
}

/// "Today · 8:00 PM", "Tomorrow · 9:00 AM", "Tue, Oct 6 · 8:00 PM".
String formatReminderTime(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final time = DateFormat.jm().format(at);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today · $time';
  if (diff == 1) return 'Tomorrow · $time';
  return '${DateFormat('EEE, MMM d').format(at)} · $time';
}

/// Asks when to be reminded to finish a saved tracer draft.
/// Returns null when the user skips.
Future<TracerReminderChoice?> showTracerReminderSheet(
  BuildContext context, {
  DateTime? closeAt,
  bool initialRepeatHourly = false,
  String title = 'Want a reminder to finish?',
  String? dismissLabel = 'No thanks',
}) {
  return showModalBottomSheet<TracerReminderChoice>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _ReminderSheet(
      closeAt: closeAt?.toLocal(),
      initialRepeatHourly: initialRepeatHourly,
      title: title,
      dismissLabel: dismissLabel,
    ),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({
    required this.closeAt,
    required this.initialRepeatHourly,
    required this.title,
    required this.dismissLabel,
  });

  final DateTime? closeAt;
  final bool initialRepeatHourly;
  final String title;
  final String? dismissLabel;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late bool _repeatHourly = widget.initialRepeatHourly;
  String? _error;

  bool _afterClose(DateTime at) =>
      widget.closeAt != null && !at.isBefore(widget.closeAt!);

  String get _closesText =>
      DateFormat.yMMMd().add_jm().format(widget.closeAt ?? DateTime.now());

  void _choose(DateTime at) {
    Navigator.of(
      context,
    ).pop(TracerReminderChoice(remindAt: at, repeatHourly: _repeatHourly));
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = widget.closeAt ?? today.add(const Duration(days: 60));
    if (lastDay.isBefore(today)) return;

    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(lastDay.year, lastDay.month, lastDay.day),
      helpText: 'Remind me on',
      builder: PortalOverlayTheme.pickerBuilder,
    );
    if (date == null || !mounted) return;

    final suggested = now.add(const Duration(hours: 1));
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: suggested.hour, minute: 0),
      helpText: 'Remind me at',
      builder: PortalOverlayTheme.pickerBuilder,
    );
    if (time == null || !mounted) return;

    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!at.isAfter(now.add(const Duration(minutes: 1)))) {
      setState(() => _error = 'Please pick a time later than now.');
      return;
    }
    if (_afterClose(at)) {
      setState(
        () => _error =
            'This tracer closes on $_closesText, please pick an earlier time.',
      );
      return;
    }
    _choose(at);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final inThreeHours = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour + 3,
      (now.minute / 5).ceil() * 5,
    );
    final tonight = today.add(const Duration(hours: 20));
    final tomorrowMorning = today.add(const Duration(days: 1, hours: 9));

    final options = <(String, IconData, DateTime)>[
      ('In 3 hours', Icons.schedule_rounded, inThreeHours),
      if (now.isBefore(tonight.subtract(const Duration(minutes: 30))))
        ('Tonight', Icons.nightlight_outlined, tonight),
      ('Tomorrow morning', Icons.wb_sunny_outlined, tomorrowMorning),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PortalTheme.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(widget.title, style: PortalTheme.pageTitle),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                "We'll send you a notification so you can pick up where "
                'you left off.',
                style: PortalTheme.bodySecondary,
              ),
            ),
            for (final (label, icon, at) in options)
              _ReminderOption(
                label: label,
                icon: icon,
                meta: _afterClose(at)
                    ? 'After the tracer closes'
                    : formatReminderTime(at),
                onTap: _afterClose(at) ? null : () => _choose(at),
              ),
            _ReminderOption(
              label: 'Pick a date & time',
              icon: Icons.edit_calendar_outlined,
              onTap: _pickCustom,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: PortalTheme.danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: PortalTheme.meta.copyWith(
                          color: PortalTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 20, color: PortalTheme.border),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Remind me every hour if I don't open it",
                          style: PortalMenu.itemText,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Only on that day, until 9 PM (up to 3 times)',
                          style: PortalTheme.meta,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _repeatHourly,
                    activeTrackColor: PortalTheme.navy,
                    onChanged: (v) => setState(() => _repeatHourly = v),
                  ),
                ],
              ),
            ),
            if (widget.dismissLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: PortalTheme.secondaryButton(),
                  child: Text(widget.dismissLabel!),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ReminderOption extends StatelessWidget {
  const _ReminderOption({
    required this.label,
    required this.icon,
    required this.onTap,
    this.meta,
  });

  final String label;
  final IconData icon;
  final String? meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: PortalMenu.iconSize,
                color: enabled ? PortalTheme.navy : PortalTheme.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: PortalMenu.itemText.copyWith(
                    color: enabled
                        ? PortalTheme.textPrimary
                        : PortalTheme.textMuted,
                  ),
                ),
              ),
              if (meta != null) ...[
                const SizedBox(width: 12),
                Text(
                  meta!,
                  style: PortalTheme.meta.copyWith(
                    color: enabled ? PortalTheme.navy : PortalTheme.textMuted,
                    fontWeight: enabled ? FontWeight.w600 : FontWeight.w400,
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
