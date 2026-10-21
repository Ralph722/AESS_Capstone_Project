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

/// Which categories reach the user in the app and as phone / browser alerts,
/// plus quiet hours for alerts. Changes save immediately.
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

  static const _descriptions = <NotificationType, String>{
    NotificationType.event: 'New events, schedule or venue changes, replies',
    NotificationType.job: 'New openings for your program, deadlines',
    NotificationType.message: 'Messages from the alumni office',
    NotificationType.announcement: 'Announcements from the alumni office',
    NotificationType.survey: 'Tracer and alumni surveys, reminders',
    NotificationType.feedback: 'Replies and updates to your feedback',
    NotificationType.forum: 'Replies, mentions, and moderation',
    NotificationType.system: 'Account and verification updates',
  };

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
      backgroundColor: Colors.white,
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
        _sectionTitle('In the app', 'What appears in your notification list.'),
        _card([
          for (final type in NotificationType.values)
            _switchRow(
              type: type,
              value: _prefs.inAppEnabled(type),
              locked: NotificationPreferences.isInAppLocked(type),
              onChanged: (v) => _update(_prefs.withInApp(type, v)),
            ),
        ]),
        const SizedBox(height: 20),
        _sectionTitle(
          'Email',
          'Email copies sent to your address on file. Turning a category '
              'off stops its emails (including survey reminders) but never '
              'its in-app notices. Sign-in and password codes always arrive.',
        ),
        _card([
          for (final type in NotificationType.values)
            _switchRow(
              type: type,
              value: _prefs.emailEnabled(type),
              locked: NotificationPreferences.isEmailLocked(type),
              onChanged: (v) => _update(_prefs.withEmail(type, v)),
            ),
        ]),
        if (widget.showPushSection) ...[
          const SizedBox(height: 20),
          _sectionTitle(
            'Phone and browser alerts',
            'Alerts outside the app on devices where you allowed '
                'notifications. Urgent announcements always come through.',
          ),
          _card([_deviceRow()]),
          const SizedBox(height: 12),
          _card([
            for (final type in NotificationType.values)
              _switchRow(
                type: type,
                value: _prefs.pushEnabled(type),
                locked: NotificationPreferences.isPushLocked(type),
                onChanged: (v) => _update(_prefs.withPush(type, v)),
              ),
          ]),
          const SizedBox(height: 20),
          _sectionTitle(
            'Quiet hours',
            'Alerts wait until quiet hours end. They still appear in the app.',
          ),
          _card([
            SwitchListTile.adaptive(
              activeThumbColor: Colors.white,
              activeTrackColor: PortalTheme.navy,
              value: _prefs.quietHoursEnabled,
              onChanged: (v) => _update(_prefs.copyWith(quietHoursEnabled: v)),
              title: Text('Pause alerts', style: PortalTheme.cardTitle),
              subtitle: Text(
                '${_formatMinutes(_prefs.quietStartMinutes)} – '
                '${_formatMinutes(_prefs.quietEndMinutes)} '
                '(${_prefs.timezone})',
                style: PortalTheme.meta,
              ),
            ),
            if (_prefs.quietHoursEnabled) ...[
              const Divider(height: 1),
              ListTile(
                title: Text('Starts', style: PortalTheme.cardTitle),
                trailing: Text(
                  _formatMinutes(_prefs.quietStartMinutes),
                  style: PortalTheme.meta.copyWith(
                    color: PortalTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => _pickTime(start: true),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text('Ends', style: PortalTheme.cardTitle),
                trailing: Text(
                  _formatMinutes(_prefs.quietEndMinutes),
                  style: PortalTheme.meta.copyWith(
                    color: PortalTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => _pickTime(start: false),
              ),
            ],
          ]),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PortalTheme.cardTitle.copyWith(
              color: PortalTheme.navy,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: PortalTheme.meta.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(color: PortalTheme.borderStrong),
        boxShadow: PortalTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _deviceRow() {
    final state = _device;
    final String subtitle;
    switch (state) {
      case null:
        subtitle = 'Checking…';
      case PushDeviceState.on:
        subtitle = 'Alerts are on for this device.';
      case PushDeviceState.off:
        subtitle = 'Turn on to get alerts on this device.';
      case PushDeviceState.blocked:
        subtitle = 'Blocked in your browser or phone settings.';
      case PushDeviceState.notConfigured:
        subtitle = 'Alerts are not set up in this version of the app.';
      case PushDeviceState.unsupported:
        subtitle = 'This device or browser does not support alerts.';
    }
    final canToggle =
        !_deviceBusy &&
        (state == PushDeviceState.on ||
            state == PushDeviceState.off ||
            state == PushDeviceState.blocked);
    return SwitchListTile.adaptive(
      value: state == PushDeviceState.on,
      onChanged: canToggle ? _toggleDevice : null,
      secondary: _deviceBusy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(3),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PortalTheme.navy,
                ),
              ),
            )
          : Icon(
              state == PushDeviceState.on
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: PortalTheme.navy,
            ),
      title: Text('This device', style: PortalTheme.cardTitle),
      subtitle: Text(subtitle, style: PortalTheme.meta.copyWith(fontSize: 12)),
    );
  }

  Widget _switchRow({
    required NotificationType type,
    required bool value,
    required bool locked,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      activeThumbColor: Colors.white,
      activeTrackColor: PortalTheme.navy,
      value: value,
      onChanged: locked || _saving ? null : onChanged,
      secondary: Icon(
        notificationIconFor(type),
        color: notificationColorFor(type),
      ),
      title: Text(notificationTypeLabel(type), style: PortalTheme.cardTitle),
      subtitle: Text(
        locked
            ? '${_descriptions[type]} · Always on'
            : _descriptions[type] ?? '',
        style: PortalTheme.meta.copyWith(fontSize: 12),
      ),
    );
  }
}
