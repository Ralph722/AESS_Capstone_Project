import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PortalTheme.radius2xl),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: 560),
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
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: PortalTheme.borderStrong.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: PortalTheme.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: PortalTheme.navy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: PortalTheme.pageTitle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          "We'll send you a notification so you can pick up where "
                          'you left off.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: PortalTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PortalTheme.pageBg,
                          border: Border.all(color: PortalTheme.border),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: PortalTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final (label, icon, at) in options)
              _ReminderOptionCard(
                label: label,
                icon: icon,
                meta: _afterClose(at)
                    ? 'After close'
                    : formatReminderTime(at),
                onTap: _afterClose(at) ? null : () => _choose(at),
              ),
            _ReminderOptionCard(
              label: 'Pick a date & time',
              icon: Icons.edit_calendar_outlined,
              onTap: _pickCustom,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: PortalTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(PortalTheme.radiusSm),
                    border: Border.all(
                      color: PortalTheme.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: PortalTheme.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: PortalTheme.meta.copyWith(
                            color: PortalTheme.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Material(
                color: PortalTheme.pageBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                  side: BorderSide(
                    color: _repeatHourly
                        ? PortalTheme.navy.withValues(alpha: 0.3)
                        : PortalTheme.border,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
                  onTap: () => setState(() => _repeatHourly = !_repeatHourly),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _repeatHourly
                                ? PortalTheme.navy.withValues(alpha: 0.12)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _repeatHourly
                                  ? PortalTheme.navy.withValues(alpha: 0.2)
                                  : PortalTheme.border,
                            ),
                          ),
                          child: Icon(
                            Icons.update_rounded,
                            size: 20,
                            color: _repeatHourly
                                ? PortalTheme.navy
                                : PortalTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Remind me hourly if I don't open\u00A0it",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: PortalTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Only on that day, until 9 PM (up to 3 times)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: PortalTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _repeatHourly,
                          activeThumbColor: Colors.white,
                          activeTrackColor: PortalTheme.navy,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: PortalTheme.borderStrong,
                          onChanged: (v) => setState(() => _repeatHourly = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.dismissLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: PortalTheme.secondaryButton(),
                  child: Text(widget.dismissLabel!),
                ),
              )
            else
              const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _ReminderOptionCard extends StatelessWidget {
  const _ReminderOptionCard({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4.5),
      child: Material(
        color: enabled ? Colors.white : PortalTheme.pageBg.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          side: BorderSide(
            color: enabled
                ? PortalTheme.border
                : PortalTheme.border.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: enabled
                        ? PortalTheme.navy.withValues(alpha: 0.06)
                        : PortalTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: enabled ? PortalTheme.navy : PortalTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? PortalTheme.textPrimary
                          : PortalTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (meta != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: enabled
                          ? PortalTheme.pageBg
                          : PortalTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: enabled
                            ? PortalTheme.border
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      meta!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? PortalTheme.navy
                            : PortalTheme.textMuted,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: PortalTheme.pageBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: PortalTheme.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PortalTheme.textSecondary,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: PortalTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
