import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';

/// Response lifecycle timeline with real tracked events when available.
///
/// Desktop opens a right-docked side panel; narrow windows fall back to a
/// bottom sheet.
Future<void> showAdminSurveyResponseTimelineSheet({
  required BuildContext context,
  required SurveyParticipant participant,
}) {
  Widget panel(BuildContext ctx) => _ResponseTimelinePanel(
        participant: participant,
        onClose: () => Navigator.pop(ctx),
      );

  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(
      context: context,
      width: 480,
      backgroundColor: AdminSurveyTheme.background,
      child: Builder(builder: panel),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AdminSurveyTheme.background,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.72;
      return SizedBox(
        height: height,
        child: panel(ctx),
      );
    },
  );
}

class _ResponseTimelinePanel extends StatefulWidget {
  const _ResponseTimelinePanel({
    required this.participant,
    required this.onClose,
  });

  final SurveyParticipant participant;
  final VoidCallback onClose;

  @override
  State<_ResponseTimelinePanel> createState() => _ResponseTimelinePanelState();
}

class _ResponseTimelinePanelState extends State<_ResponseTimelinePanel> {
  final _surveyService = SurveyService();
  List<SurveyResponseEvent> _events = [];
  bool _loadingEvents = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await _surveyService.getResponseEvents(
      surveyId: widget.participant.assignment.surveyId,
      userId: widget.participant.assignment.userId,
    );
    if (!mounted) return;
    setState(() {
      _events = events;
      _loadingEvents = false;
    });
  }

  static final _fmt = DateFormat.yMMMd().add_jm();

  SurveyResponseEvent? _firstEvent(SurveyResponseEventType type) {
    for (final event in _events) {
      if (event.eventType == type) return event;
    }
    return null;
  }

  List<SurveyResponseEvent> _eventsOfType(SurveyResponseEventType type) {
    return _events.where((e) => e.eventType == type).toList();
  }

  List<_TimelineEvent> _buildEvents() {
    final a = widget.participant.assignment;
    final r = widget.participant.response;
    final events = <_TimelineEvent>[
      _TimelineEvent(
        title: 'Assigned',
        subtitle: 'Survey assignment created for this alumnus.',
        timestamp: _fmt.format(a.assignedAt),
        icon: Icons.person_add_alt_1_outlined,
        state: _TimelineEventState.recorded,
      ),
    ];

    if (a.reminderCount > 0) {
      events.add(
        _TimelineEvent(
          title: a.reminderCount == 1
              ? 'Reminder sent'
              : '${a.reminderCount} reminders sent',
          subtitle: a.lastReminderAt == null
              ? 'Reminder count is recorded; last send time is missing.'
              : 'Last reminder activity on record.',
          timestamp: a.lastReminderAt == null
              ? 'Time not recorded'
              : _fmt.format(a.lastReminderAt!),
          icon: Icons.notifications_active_outlined,
          state: _TimelineEventState.recorded,
        ),
      );
    } else {
      events.add(
        const _TimelineEvent(
          title: 'Reminder sent',
          subtitle: 'No reminders have been sent yet.',
          timestamp: '—',
          icon: Icons.notifications_none_outlined,
          state: _TimelineEventState.pending,
        ),
      );
    }

    final opened = _firstEvent(SurveyResponseEventType.opened);
    if (opened != null) {
      events.add(
        _TimelineEvent(
          title: 'Opened survey',
          subtitle: _deviceSubtitle(opened),
          timestamp: _fmt.format(opened.createdAt),
          icon: Icons.visibility_outlined,
          state: _TimelineEventState.recorded,
        ),
      );
    } else if (r?.openedAt != null) {
      events.add(
        _TimelineEvent(
          title: 'Opened survey',
          subtitle: r!.deviceSummary == 'Device not recorded'
              ? 'First open time recorded.'
              : r.deviceSummary,
          timestamp: _fmt.format(r.openedAt!),
          icon: Icons.visibility_outlined,
          state: _TimelineEventState.recorded,
        ),
      );
    } else {
      events.add(
        const _TimelineEvent(
          title: 'Opened survey',
          subtitle: 'This response predates open tracking or was never opened.',
          timestamp: 'Not recorded',
          icon: Icons.visibility_outlined,
          state: _TimelineEventState.unavailable,
        ),
      );
    }

    final draftEvents = _eventsOfType(SurveyResponseEventType.draftSaved);
    if (draftEvents.isNotEmpty) {
      final first = draftEvents.first;
      final count = draftEvents.length;
      events.add(
        _TimelineEvent(
          title: count == 1 ? 'Saved draft' : '$count draft saves',
          subtitle: count == 1
              ? _deviceSubtitle(first)
              : 'First save ${_fmt.format(first.createdAt)} · '
                  'latest ${_fmt.format(draftEvents.last.createdAt)}.',
          timestamp: _fmt.format(draftEvents.last.createdAt),
          icon: Icons.edit_note_outlined,
          state: _TimelineEventState.recorded,
        ),
      );
    } else if (r != null && r.firstDraftAt != null) {
      events.add(
        _TimelineEvent(
          title: 'Saved draft',
          subtitle: 'First draft timestamp recorded.',
          timestamp: _fmt.format(r.firstDraftAt!),
          icon: Icons.edit_note_outlined,
          state: _TimelineEventState.recorded,
        ),
      );
    } else if (r != null && r.status == SurveyResponseStatus.draft) {
      events.add(
        _TimelineEvent(
          title: 'Saved draft',
          subtitle: 'A draft response exists for this alumnus.',
          timestamp: _fmt.format(r.updatedAt),
          icon: Icons.edit_note_outlined,
          state: _TimelineEventState.inferred,
        ),
      );
    } else if (a.status == SurveyAssignmentStatus.inProgress &&
        (r == null || r.status != SurveyResponseStatus.submitted)) {
      events.add(
        const _TimelineEvent(
          title: 'In progress',
          subtitle:
              'Assignment is marked in progress. No draft save events yet.',
          timestamp: 'Status only',
          icon: Icons.pending_actions_outlined,
          state: _TimelineEventState.inferred,
        ),
      );
    } else {
      events.add(
        const _TimelineEvent(
          title: 'Saved draft',
          subtitle: 'No draft save events recorded for this response.',
          timestamp: 'Not recorded',
          icon: Icons.edit_note_outlined,
          state: _TimelineEventState.unavailable,
        ),
      );
    }

    final submittedEvent = _firstEvent(SurveyResponseEventType.submitted);
    if (submittedEvent != null) {
      events.add(
        _TimelineEvent(
          title: 'Submitted',
          subtitle: _deviceSubtitle(submittedEvent),
          timestamp: _fmt.format(submittedEvent.createdAt),
          icon: Icons.task_alt_outlined,
          state: _TimelineEventState.recorded,
        ),
      );
    } else if (r != null && r.status == SurveyResponseStatus.submitted) {
      events.add(
        _TimelineEvent(
          title: 'Submitted',
          subtitle: 'Response marked submitted.',
          timestamp: r.submittedAt == null
              ? _fmt.format(r.updatedAt)
              : _fmt.format(r.submittedAt!),
          icon: Icons.task_alt_outlined,
          state: _TimelineEventState.recorded,
        ),
      );
    } else {
      events.add(
        const _TimelineEvent(
          title: 'Submitted',
          subtitle: 'This alumnus has not submitted yet.',
          timestamp: 'Pending',
          icon: Icons.hourglass_empty,
          state: _TimelineEventState.pending,
        ),
      );
    }

    return events;
  }

  static String _deviceSubtitle(SurveyResponseEvent event) {
    final parts = <String>[];
    if (event.deviceCategory != null && event.deviceCategory!.isNotEmpty) {
      parts.add(event.deviceCategory!);
    }
    if (event.platformFamily != null && event.platformFamily!.isNotEmpty) {
      parts.add(event.platformFamily!);
    }
    if (event.browserFamily != null && event.browserFamily!.isNotEmpty) {
      parts.add(event.browserFamily!);
    }
    if (parts.isEmpty) return 'Activity recorded.';
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final events = _buildEvents();
    final name = widget.participant.displayName.trim().isEmpty
        ? 'Alumni'
        : widget.participant.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Response timeline',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AdminSurveyTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminSurveyTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            _loadingEvents
                ? 'Loading tracked activity…'
                : 'Recorded steps use assignment, response, and privacy-safe '
                    'device metadata (category/platform/browser only).',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AdminSurveyTheme.textSecondary,
            ),
          ),
        ),
        const Divider(height: 1, color: AdminSurveyTheme.border),
        Expanded(
          child: _loadingEvents
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return _TimelineStep(
                      event: events[index],
                      isFirst: index == 0,
                      isLast: index == events.length - 1,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

enum _TimelineEventState { recorded, inferred, pending, unavailable }

class _TimelineEvent {
  const _TimelineEvent({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.state,
  });

  final String title;
  final String subtitle;
  final String timestamp;
  final IconData icon;
  final _TimelineEventState state;
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final _TimelineEvent event;
  final bool isFirst;
  final bool isLast;

  Color get _accent {
    switch (event.state) {
      case _TimelineEventState.recorded:
        return AdminSurveyTheme.primary;
      case _TimelineEventState.inferred:
        return AdminSurveyTheme.warning;
      case _TimelineEventState.pending:
        return AdminSurveyTheme.textMuted;
      case _TimelineEventState.unavailable:
        return AdminSurveyTheme.border;
    }
  }

  String get _stateLabel {
    switch (event.state) {
      case _TimelineEventState.recorded:
        return 'Recorded';
      case _TimelineEventState.inferred:
        return 'Inferred';
      case _TimelineEventState.pending:
        return 'Pending';
      case _TimelineEventState.unavailable:
        return 'Not tracked';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AdminSurveyTheme.border,
                    ),
                  )
                else
                  const SizedBox(height: 4),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: event.state == _TimelineEventState.recorded ||
                            event.state == _TimelineEventState.inferred
                        ? accent.withValues(alpha: 0.12)
                        : AdminSurveyTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 1.5),
                  ),
                  child: Icon(event.icon, size: 14, color: accent),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AdminSurveyTheme.border,
                    ),
                  )
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminSurveyTheme.card,
                  borderRadius:
                      BorderRadius.circular(AdminSurveyTheme.radiusMd),
                  border: Border.all(color: AdminSurveyTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: event.state ==
                                      _TimelineEventState.unavailable
                                  ? AdminSurveyTheme.textMuted
                                  : AdminSurveyTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _stateLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.timestamp,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminSurveyTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AdminSurveyTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
