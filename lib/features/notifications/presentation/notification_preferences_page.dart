import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:alumni_system/features/notifications/data/notification_preferences_service.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/features/notifications/models/notification_preferences.dart';
import 'package:alumni_system/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:alumni_system/features/notifications/push/push_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Category toggles for in-app, email, SMS, and device alerts. Saves immediately.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key, this.showPushSection = true});

  final bool showPushSection;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _service = NotificationPreferencesService();

  NotificationPreferences _prefs = const NotificationPreferences();
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  PushDeviceState? _device;
  bool _deviceBusy = false;

  /// Preference rows (legacy Feedback tickets removed from the product).
  static Iterable<NotificationType> get _prefTypes => NotificationType.values
      .where((t) => t != NotificationType.feedback);

  /// Email toggles with a real send path (survey, announcement, event, job,
  /// system). Messages and Forum have no email path yet — hide those stubs.
  static const _emailTypes = <NotificationType>[
    NotificationType.event,
    NotificationType.job,
    NotificationType.announcement,
    NotificationType.survey,
    NotificationType.system,
  ];

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.showPushSection) _loadDevice();
  }

  Future<void> _loadDevice() async {
    final state = await PushService.instance.state();
    if (mounted) setState(() => _device = state);
  }

  Future<void> _toggleDevice(bool enable) async {
    setState(() => _deviceBusy = true);
    PushDeviceState state;
    try {
      state = enable
          ? await PushService.instance.enable()
          : await PushService.instance.disable();
    } catch (_) {
      state = await PushService.instance.state();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not update alerts for this device.'),
            ),
          );
      }
    }
    if (!mounted) return;
    setState(() {
      _device = state;
      _deviceBusy = false;
    });
    if (enable && state == PushDeviceState.blocked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are blocked. Allow them in your browser or '
              'phone settings, then try again.',
            ),
          ),
        );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await _service.load();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _update(NotificationPreferences next) async {
    final previous = _prefs;
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      await _service.save(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final minutes = start ? _prefs.quietStartMinutes : _prefs.quietEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final value = picked.hour * 60 + picked.minute;
    await _update(
      start
          ? _prefs.copyWith(quietStartMinutes: value)
          : _prefs.copyWith(quietEndMinutes: value),
    );
  }

  String _formatMinutes(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Notification settings',
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PortalTheme.navy,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: PortalContentFrame(
        maxWidth: PortalBreakpoints.chatMax,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const NotificationSettingsSkeleton();
    }
    if (_error != null) {
      return PortalErrorState(error: _error, onRetry: _load);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _sectionTitle('In the app'),
        _card([
          for (final type in _prefTypes)
            _prefRow(
              type: type,
              value: _prefs.inAppEnabled(type),
              locked: NotificationPreferences.isInAppLocked(type),
              onChanged: (v) => _update(_prefs.withInApp(type, v)),
              isLast: type == _prefTypes.last,
            ),
        ]),
        const SizedBox(height: 18),
        _sectionTitle('Email'),
        _card([
          for (final type in _emailTypes)
            _prefRow(
              type: type,
              value: _prefs.emailEnabled(type),
              locked: NotificationPreferences.isEmailLocked(type),
              onChanged: (v) => _update(_prefs.withEmail(type, v)),
              isLast: type == _emailTypes.last,
            ),
        ]),
        const SizedBox(height: 18),
        _sectionTitle('Text messages (SMS)'),
        _card([
          _prefRow(
            type: NotificationType.survey,
            value: _prefs.smsEnabled(NotificationType.survey),
            locked: false,
            onChanged: (v) =>
                _update(_prefs.withSms(NotificationType.survey, v)),
            isLast: true,
          ),
        ]),
        if (widget.showPushSection) ...[
          const SizedBox(height: 18),
          _sectionTitle('Phone and browser'),
          _card([
            _deviceRow(),
            const Divider(height: 1, indent: 56),
            for (final type in _prefTypes)
              _prefRow(
                type: type,
                value: _prefs.pushEnabled(type),
                locked: NotificationPreferences.isPushLocked(type),
                onChanged: (v) => _update(_prefs.withPush(type, v)),
                isLast: type == _prefTypes.last,
              ),
          ]),
          const SizedBox(height: 18),
          _sectionTitle('Quiet hours'),
          _card([
            _compactToggleRow(
              icon: Icons.bedtime_outlined,
              iconColor: PortalTheme.navy,
              title: 'Pause alerts',
              trailingLabel: _prefs.quietHoursEnabled
                  ? '${_formatMinutes(_prefs.quietStartMinutes)} – '
                        '${_formatMinutes(_prefs.quietEndMinutes)}'
                  : null,
              value: _prefs.quietHoursEnabled,
              onChanged: (v) =>
                  _update(_prefs.copyWith(quietHoursEnabled: v)),
            ),
            if (_prefs.quietHoursEnabled) ...[
              const Divider(height: 1, indent: 56),
              _timeRow(
                label: 'Starts',
                value: _formatMinutes(_prefs.quietStartMinutes),
                onTap: () => _pickTime(start: true),
              ),
              const Divider(height: 1, indent: 56),
              _timeRow(
                label: 'Ends',
                value: _formatMinutes(_prefs.quietEndMinutes),
                onTap: () => _pickTime(start: false),
                isLast: true,
              ),
            ],
          ]),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: PortalTheme.cardTitle.copyWith(
          color: PortalTheme.navy,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(color: PortalTheme.border.withValues(alpha: 0.9)),
        boxShadow: PortalTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _prefRow({
    required NotificationType type,
    required bool value,
    required bool locked,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(
      children: [
        _compactToggleRow(
          icon: notificationIconFor(type),
          iconColor: notificationColorFor(type),
          title: notificationTypeLabel(type),
          value: value,
          locked: locked,
          onChanged: locked || _saving ? null : onChanged,
        ),
        if (!isLast) const Divider(height: 1, indent: 56),
      ],
    );
  }

  Widget _compactToggleRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    ValueChanged<bool>? onChanged,
    String? trailingLabel,
    bool locked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: PortalTheme.cardTitle.copyWith(fontSize: 14),
            ),
          ),
          if (trailingLabel != null) ...[
            Text(
              trailingLabel,
              style: PortalTheme.caption.copyWith(
                color: PortalTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (locked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PortalTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Always on',
                style: PortalTheme.caption.copyWith(
                  color: PortalTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            )
          else
            Transform.scale(
              scale: 0.88,
              alignment: Alignment.centerRight,
              child: CupertinoSwitch(
                value: value,
                activeTrackColor: PortalTheme.navy,
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: _saving ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: PortalTheme.cardTitle.copyWith(fontSize: 14)),
            ),
            Text(
              value,
              style: PortalTheme.meta.copyWith(
                color: PortalTheme.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: PortalTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceRow() {
    final state = _device;
    final canToggle =
        !_deviceBusy &&
        (state == PushDeviceState.on ||
            state == PushDeviceState.off ||
            state == PushDeviceState.blocked);

    String? statusChip;
    switch (state) {
      case null:
        statusChip = 'Checking…';
      case PushDeviceState.on:
        statusChip = null;
      case PushDeviceState.off:
        statusChip = null;
      case PushDeviceState.blocked:
        statusChip = 'Blocked';
      case PushDeviceState.notConfigured:
        statusChip = 'Unavailable';
      case PushDeviceState.unsupported:
        statusChip = 'Unsupported';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: PortalTheme.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            ),
            child: _deviceBusy
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PortalTheme.navy,
                    ),
                  )
                : Icon(
                    state == PushDeviceState.on
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 18,
                    color: PortalTheme.navy,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This device',
              style: PortalTheme.cardTitle.copyWith(fontSize: 14),
            ),
          ),
          if (statusChip != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PortalTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusChip,
                style: PortalTheme.caption.copyWith(
                  color: PortalTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (canToggle || state == PushDeviceState.on || state == PushDeviceState.off)
            Transform.scale(
              scale: 0.88,
              alignment: Alignment.centerRight,
              child: CupertinoSwitch(
                value: state == PushDeviceState.on,
                activeTrackColor: PortalTheme.navy,
                onChanged: canToggle ? _toggleDevice : null,
              ),
            ),
        ],
      ),
    );
  }
}
