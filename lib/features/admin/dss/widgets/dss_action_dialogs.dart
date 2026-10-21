import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/dss/application/dss_action_service.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Tracer reminder to the flag group's non-respondents. Returns the server
/// result, or null when cancelled.
Future<DssActionResult?> showDssReminderDialog(
  BuildContext context,
  DssFlag flag,
) {
  return showDialog<DssActionResult>(
    context: context,
    builder: (_) => _DssActionDialog(flag: flag, mode: _Mode.reminder),
  );
}

/// Matching job postings to the flag group's unemployed respondents.
Future<DssActionResult?> showDssJobMatchDialog(
  BuildContext context,
  DssFlag flag,
) {
  return showDialog<DssActionResult>(
    context: context,
    builder: (_) => _DssActionDialog(flag: flag, mode: _Mode.jobs),
  );
}

enum _Mode { reminder, jobs }

class _DssActionDialog extends StatefulWidget {
  const _DssActionDialog({required this.flag, required this.mode});

  final DssFlag flag;
  final _Mode mode;

  @override
  State<_DssActionDialog> createState() => _DssActionDialogState();
}

class _DssActionDialogState extends State<_DssActionDialog> {
  static const _preselectJobs = 3;

  final _service = DssActionService();
  final _repo = DssRepository();

  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<DssActionPerson> _people = [];
  List<DssJobSuggestion> _jobs = [];
  final Set<String> _selectedPeople = {};
  final Set<String> _selectedJobs = {};

  bool get _isJobs => widget.mode == _Mode.jobs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = _isJobs
          ? await _service.unemployedRespondents(widget.flag)
          : await _service.nonRespondents(widget.flag);
      final jobs = _isJobs
          ? await _service.suggestJobs(widget.flag)
          : <DssJobSuggestion>[];
      if (!mounted) return;
      setState(() {
        _people = people;
        _jobs = jobs;
        _selectedPeople.addAll(
          people.where((p) => p.canNotify).map((p) => p.authUid!),
        );
        _selectedJobs.addAll(
          jobs
              .where((j) => j.matchesProgram)
              .take(_preselectJobs)
              .map((j) => j.job.id),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await _repo.runFlagAction(
        flagId: widget.flag.id,
        action: _isJobs ? 'job_matches' : 'survey_reminder',
        userIds: _selectedPeople.toList(),
        jobIds: _selectedJobs.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('PostgrestException(message: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifiable = _people.where((p) => p.canNotify).toList();
    final unregistered = _people.where((p) => !p.canNotify).toList();
    final canSend =
        !_loading &&
        !_sending &&
        _selectedPeople.isNotEmpty &&
        (!_isJobs || _selectedJobs.isNotEmpty);
    final survey = widget.flag.surveyTitle.trim().isEmpty
        ? 'the tracer survey'
        : '"${widget.flag.surveyTitle.trim()}"';

    return Dialog(
      backgroundColor: AdminDialogStandards.backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: AdminDialogStandards.elevation,
      shape: AdminDialogStandards.shape,
      insetPadding: AdminDialogStandards.defaultInsetPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: AdminDialogStandards.defaultContentPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminModalHeader(
                title: _isJobs ? 'Send Matching Jobs' : 'Send Tracer Reminder',
                subtitle: _isJobs
                    ? 'To respondents in ${widget.flag.cohortLabel} who said they are not employed.'
                    : 'To alumni in ${widget.flag.cohortLabel} who have not submitted $survey.',
                icon: _isJobs ? Icons.work_outline_rounded : Icons.send_outlined,
                onClose: _sending ? null : () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isJobs) ..._jobSection(),
                        _sectionHeader(
                          _isJobs ? 'Recipients' : 'Can be notified in the app',
                          count: notifiable.length,
                          allSelected:
                              notifiable.isNotEmpty &&
                              _selectedPeople.length == notifiable.length,
                          onToggleAll: notifiable.isEmpty
                              ? null
                              : (all) => setState(() {
                                  _selectedPeople.clear();
                                  if (all) {
                                    _selectedPeople.addAll(
                                      notifiable.map((p) => p.authUid!),
                                    );
                                  }
                                }),
                        ),
                        if (notifiable.isEmpty)
                          _emptyText(
                            _isJobs
                                ? 'No unemployed respondents with an account in this group.'
                                : 'Everyone registered in this group has already submitted.',
                          )
                        else
                          ...notifiable.map(_personTile),
                        if (unregistered.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _sectionHeader(
                            'Not registered yet',
                            count: unregistered.length,
                          ),
                          _emptyText(
                            'These alumni have no account, so they cannot get in-app '
                            'reminders. Reach them by email, text or Facebook: '
                            '${_names(unregistered)}.',
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AdminColors.danger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AdminColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AdminColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 15,
                                color: AdminColors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sending logs this action on the flag and moves it to '
                                  'In Progress. Anyone already notified today is skipped.',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AdminColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _sending ? null : () => Navigator.of(context).pop(),
                    style: AdminButtonStyles.outlined(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: canSend ? _send : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined, size: 16),
                    label: Text(
                      _sending
                          ? 'Sending…'
                          : 'Send to ${_selectedPeople.length} '
                              '${_selectedPeople.length == 1 ? 'person' : 'people'}',
                    ),
                    style: AdminButtonStyles.filled(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _jobSection() {
    return [
      _sectionHeader('Job postings', count: _jobs.length),
      if (_jobs.isEmpty)
        _emptyText(
          'No active job postings match this program or are open to all '
          'programs. Post one in Jobs first.',
        )
      else
        ..._jobs.map(
          (s) => CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _selectedJobs.contains(s.job.id),
            onChanged: (v) => setState(() {
              if (v == true) {
                _selectedJobs.add(s.job.id);
              } else {
                _selectedJobs.remove(s.job.id);
              }
            }),
            title: Text(
              s.job.jobTitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${s.job.companyName} · '
              '${s.matchesProgram ? 'Matches this program' : 'Open to all programs'}',
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ),
      const SizedBox(height: 12),
    ];
  }

  Widget _personTile(DssActionPerson p) {
    final uid = p.authUid!;
    final batch = p.batchYear.isEmpty ? '' : ' · Batch ${p.batchYear}';
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selectedPeople.contains(uid),
      onChanged: (v) => setState(() {
        if (v == true) {
          _selectedPeople.add(uid);
        } else {
          _selectedPeople.remove(uid);
        }
      }),
      title: Text(p.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '${p.course}$batch',
        style: const TextStyle(fontSize: 11.5),
      ),
    );
  }

  Widget _sectionHeader(
    String label, {
    required int count,
    bool allSelected = false,
    ValueChanged<bool>? onToggleAll,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label ($count)',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AdminDssTheme.textPrimary,
              ),
            ),
          ),
          if (onToggleAll != null)
            TextButton(
              onPressed: () => onToggleAll(!allSelected),
              child: Text(allSelected ? 'Clear all' : 'Select all'),
            ),
        ],
      ),
    );
  }

  Widget _emptyText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        height: 1.35,
        color: AdminDssTheme.textSecondary,
      ),
    ),
  );

  static String _names(List<DssActionPerson> people) {
    const shown = 6;
    final names = people.take(shown).map((p) => p.name).join(', ');
    return people.length > shown
        ? '$names and ${people.length - shown} more'
        : names;
  }
}
