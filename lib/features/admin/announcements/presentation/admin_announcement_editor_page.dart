import 'package:flutter/material.dart';
import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/announcements/widgets/admin_announcement_ui.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Opens the announcement editor as a side panel (wide) or dialog (narrow).
Future<void> showAdminAnnouncementEditor({
  required BuildContext context,
  required String announcementId,
  required VoidCallback onChanged,
  AnnouncementService? service,
}) {
  final child = AdminAnnouncementEditorPanel(
    announcementId: announcementId,
    onChanged: onChanged,
    service: service,
  );
  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(
      context: context,
      width: 560,
      child: child,
    );
  }
  return showAdminDialogSurface<void>(
    context: context,
    maxWidth: 640,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: child,
    ),
  );
}

class AdminAnnouncementEditorPanel extends StatefulWidget {
  const AdminAnnouncementEditorPanel({
    super.key,
    required this.announcementId,
    required this.onChanged,
    this.service,
  });

  final String announcementId;
  final VoidCallback onChanged;
  final AnnouncementService? service;

  @override
  State<AdminAnnouncementEditorPanel> createState() =>
      _AdminAnnouncementEditorPanelState();
}

class _AdminAnnouncementEditorPanelState
    extends State<AdminAnnouncementEditorPanel> {
  late final AnnouncementService _service =
      widget.service ?? AnnouncementService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _batchController = TextEditingController();

  Announcement? _item;
  List<String> _targetPrograms = [];
  List<String> _targetBatches = [];
  String? _batchInputError;
  String? _titleError;
  String? _bodyError;
  bool _notifyInApp = true;
  bool _notifyEmail = false;
  bool _notifyPush = true;
  bool _urgent = false;
  AnnouncementPriority _priority = AnnouncementPriority.normal;
  bool _isLoading = false;
  String? _loadError;
  bool _isSaving = false;

  int? _audienceCount;
  bool _countingAudience = false;
  String? _audienceError;
  String? _lastAudienceKey;
  int _audienceRequestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  String _computeAudienceKey() {
    final programs = List<String>.from(_targetPrograms)..sort();
    final batches = List<String>.from(_targetBatches)..sort();
    return '${programs.join(',')}|${batches.join(',')}';
  }

  Future<void> _refreshAudienceCount({bool force = false}) async {
    if (_batchInputError != null) return;
    final key = _computeAudienceKey();
    if (!force && key == _lastAudienceKey) return;
    _lastAudienceKey = key;

    final requestId = ++_audienceRequestId;
    setState(() {
      _countingAudience = true;
      _audienceError = null;
    });

    try {
      final count = await _service.countAudience(
        targetPrograms: List.of(_targetPrograms),
        targetBatchYears: List.of(_targetBatches),
      );
      if (!mounted || requestId != _audienceRequestId) return;
      setState(() {
        _audienceCount = count;
        _countingAudience = false;
        _audienceError = null;
      });
    } catch (e) {
      if (!mounted || requestId != _audienceRequestId) return;
      setState(() {
        _countingAudience = false;
        _audienceError = announcementFriendlyError(
          e,
          'Could not check audience size.',
        );
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final item = await _service.getAnnouncement(widget.announcementId);
      if (!mounted) return;
      if (item != null) {
        _titleController.text = item.title;
        _bodyController.text = item.body;
        _targetPrograms = AudienceTargeting.normalizeCourseTargets(
          item.targetPrograms,
        );
        _targetBatches = List.from(item.targetBatchYears);
        _batchController.text = AudienceTargeting.formatBatchYearsForDisplay(
          _targetBatches,
        );
        _notifyInApp = item.notifyInApp;
        _notifyEmail = item.notifyEmail;
        _notifyPush = item.notifyPush;
        _urgent = item.urgent;
        _priority = item.priority;
      }
      setState(() {
        _item = item;
        _isLoading = false;
        _batchInputError = null;
        _titleError = null;
        _bodyError = null;
      });
      if (item != null) {
        await _refreshAudienceCount(force: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '$e';
      });
    }
  }

  bool _syncBatchFromField() {
    final text = _batchController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _targetBatches = [];
        _batchInputError = null;
      });
      _refreshAudienceCount();
      return true;
    }
    final formatError = AudienceTargeting.validateBatchYearInput(text);
    if (formatError != null) {
      setState(() => _batchInputError = formatError);
      return false;
    }
    try {
      final parsed = AudienceTargeting.parseBatchYearInput(text);
      setState(() {
        _targetBatches = parsed;
        _batchInputError = null;
      });
      _refreshAudienceCount();
      return true;
    } on FormatException catch (e) {
      setState(() => _batchInputError = e.message);
      return false;
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AdminColors.danger,
      ),
    );
  }

  Future<int?> _resolveValidAudienceCount() async {
    if (!_syncBatchFromField()) return null;

    final int count;
    try {
      count = await _service.countAudience(
        targetPrograms: _targetPrograms,
        targetBatchYears: _targetBatches,
      );
    } catch (e) {
      _showErrorSnack(
        announcementFriendlyError(
          e,
          'Could not verify audience before publishing. Please try again.',
        ),
      );
      return null;
    }

    if (mounted) {
      setState(() {
        _audienceCount = count;
        _countingAudience = false;
        _audienceError = null;
        _lastAudienceKey = _computeAudienceKey();
      });
    }

    final hasFilters =
        _targetPrograms.isNotEmpty || _batchController.text.trim().isNotEmpty;

    if (hasFilters && count == 0) {
      _showErrorSnack(
        'No alumni match this program/batch range. '
        'Adjust filters or ensure tracer profiles have matching batch years.',
      );
      return null;
    }

    if (!hasFilters && count == 0) {
      _showErrorSnack('No alumni accounts found to notify.');
      return null;
    }

    return count;
  }

  Announcement? _draftFromFields() {
    final item = _item;
    if (item == null) return null;
    return item.copyWith(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      targetPrograms: _targetPrograms,
      targetBatchYears: _targetBatches,
      notifyInApp: _notifyInApp,
      notifyEmail: _notifyEmail,
      notifyPush: _notifyPush,
      urgent: _urgent,
      priority: _priority,
    );
  }

  Future<void> _persistDraft() async {
    final updated = _draftFromFields();
    if (updated == null) return;
    await _service.updateAnnouncement(updated);
  }

  Future<void> _save() async {
    if (_item == null || _isSaving) return;
    if (!_syncBatchFromField()) return;
    setState(() => _isSaving = true);
    try {
      await _persistDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved')),
      );
      widget.onChanged();
      await _load();
    } catch (e) {
      _showErrorSnack(
        announcementFriendlyError(
          e,
          'Could not save changes. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _validatePublishFields() {
    final titleEmpty = _titleController.text.trim().isEmpty;
    final bodyEmpty = _bodyController.text.trim().isEmpty;
    setState(() {
      _titleError = titleEmpty ? 'Enter a title before publishing.' : null;
      _bodyError = bodyEmpty ? 'Enter a message body before publishing.' : null;
    });
    if (titleEmpty || bodyEmpty) {
      _showErrorSnack('Title and message are required before publishing.');
      return false;
    }
    return true;
  }

  Future<void> _publish() async {
    if (_item == null || _isSaving) return;
    if (!_validatePublishFields()) return;
    if (!_syncBatchFromField()) return;

    setState(() => _isSaving = true);
    try {
      final audienceCount = await _resolveValidAudienceCount();
      if (audienceCount == null || !mounted) return;

      final draft = _draftFromFields()!;
      final audienceSummary = announcementAudienceSummary(draft);
      final channels = announcementDeliveryChannels(draft);
      final channelSummary =
          channels.isEmpty ? 'No alerts' : channels.join(' · ');
      final emailNote = draft.notifyEmail && EmailDeliveryConfig.isConfigured
          ? ' Emails will be sent immediately.'
          : '';

      final confirmed = await showAdminConfirmDialog(
        context,
        title: 'Publish announcement?',
        message:
            'Publish “${draft.title}” to $audienceCount '
            '${audienceCount == 1 ? 'alumnus' : 'alumni'} '
            '($audienceSummary) via $channelSummary.$emailNote',
        confirmLabel: 'Publish now',
        icon: Icons.campaign_outlined,
      );
      if (!confirmed || !mounted) return;

      await _persistDraft();
      final count = await _service.publishAnnouncement(widget.announcementId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Published to $count alumni'),
          backgroundColor: AdminColors.success,
        ),
      );
      widget.onChanged();
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnack(
        announcementFriendlyError(
          e,
          'Could not publish this announcement. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final allCoursesSelected =
        _targetPrograms.length == CourseConstants.courses.length;
    return Material(
      color: AdminColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _titleController,
            builder: (context, value, _) {
              final liveTitle = value.text.trim();
              final headerTitle = liveTitle.isNotEmpty
                  ? liveTitle
                  : (item?.title.trim().isNotEmpty == true
                        ? item!.title.trim()
                        : 'Edit announcement');
              return _PanelHeader(
                title: headerTitle,
                status: item?.status,
                priority: item?.priority ?? _priority,
                urgent: _notifyInApp && _urgent,
                onClose: _isSaving ? null : () => Navigator.pop(context),
              );
            },
          ),
          const Divider(height: 1, color: AdminColors.border),
          Expanded(
            child: _isLoading && item == null
                ? const AdminFormEditorSkeleton()
                : _loadError != null && item == null
                ? AdminStateView.error(
                    compact: true,
                    title: "Couldn't load announcement",
                    message: 'Please try again in a moment.',
                    details: _loadError,
                    onRetry: _load,
                  )
                : item == null
                ? const AdminStateView.empty(
                    compact: true,
                    icon: Icons.campaign_outlined,
                    title: 'Announcement not found',
                    message: 'This notice may have been deleted.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AdminDensity.space3,
                      AdminDensity.space2,
                      AdminDensity.space3,
                      AdminDensity.space3,
                    ),
                    children: [
                      _SectionCard(
                        title: 'Content',
                        subtitle:
                            'Title and message shown to alumni when published.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _titleController,
                              style: const TextStyle(fontSize: 13.5),
                              onChanged: (_) {
                                if (_titleError != null) {
                                  setState(() => _titleError = null);
                                }
                              },
                              decoration:
                                  AdminAnnouncementTheme.fieldDecoration(
                                label: 'Title *',
                                hint: 'Headline for alumni',
                              ).copyWith(errorText: _titleError),
                            ),
                            const SizedBox(height: AdminDensity.space2),
                            TextField(
                              controller: _bodyController,
                              style: const TextStyle(fontSize: 13.5),
                              onChanged: (_) {
                                if (_bodyError != null) {
                                  setState(() => _bodyError = null);
                                }
                              },
                              decoration:
                                  AdminAnnouncementTheme.fieldDecoration(
                                label: 'Message *',
                                hint: 'Write the announcement details…',
                              ).copyWith(
                                alignLabelWithHint: true,
                                errorText: _bodyError,
                              ),
                              maxLines: 7,
                              minLines: 5,
                            ),
                            const SizedBox(height: AdminDensity.space2),
                            DropdownButtonFormField<AnnouncementPriority>(
                              key: ValueKey(_priority),
                              initialValue: _priority,
                              isDense: true,
                              isExpanded: true,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AdminColors.textPrimary,
                              ),
                              decoration:
                                  AdminAnnouncementTheme.fieldDecoration(
                                label: 'Priority',
                              ),
                              items: AnnouncementPriority.values
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        p == AnnouncementPriority.important
                                            ? 'Important'
                                            : 'Normal',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _priority = v);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AdminDensity.space2),
                      _SectionCard(
                        title: 'Audience & delivery',
                        subtitle:
                            'Leave course filters empty to reach all courses and batches.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Courses',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: AdminColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                if (_targetPrograms.isNotEmpty)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: const Size(0, 28),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      setState(() => _targetPrograms.clear());
                                      _refreshAudienceCount();
                                    },
                                    child: const Text(
                                      'Clear courses',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  )
                                else if (!allCoursesSelected)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: const Size(0, 28),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _targetPrograms = List.of(
                                          CourseConstants.courses,
                                        );
                                      });
                                      _refreshAudienceCount();
                                    },
                                    child: const Text(
                                      'Select all',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: CourseConstants.courses.map((p) {
                                final selected = _targetPrograms.contains(p);
                                return FilterChip(
                                  label: Text(p),
                                  selected: selected,
                                  showCheckmark: false,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AdminSurfaces.radiusSm,
                                    ),
                                  ),
                                  backgroundColor: AdminColors.card,
                                  selectedColor: AdminColors.primaryTint,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: selected
                                        ? AdminColors.primary
                                        : AdminColors.textSecondary,
                                  ),
                                  side: BorderSide(
                                    color: selected
                                        ? AdminColors.primary.withValues(
                                            alpha: 0.35,
                                          )
                                        : AdminColors.border,
                                  ),
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) {
                                        _targetPrograms.add(p);
                                      } else {
                                        _targetPrograms.remove(p);
                                      }
                                    });
                                    _refreshAudienceCount();
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AdminDensity.space2),
                            TextField(
                              controller: _batchController,
                              style: const TextStyle(fontSize: 13.5),
                              decoration:
                                  AdminAnnouncementTheme.fieldDecoration(
                                label: 'Target batch years',
                                hint: 'e.g. 2020-2027 or 2024, 2025',
                              ).copyWith(
                                helperText:
                                    'Use a year range or comma-separated years',
                                errorText: _batchInputError,
                              ),
                              onChanged: (_) => _syncBatchFromField(),
                            ),
                            const SizedBox(height: AdminDensity.space1),
                            _AudiencePreview(
                              targetPrograms: _targetPrograms,
                              targetBatchYears: _targetBatches,
                              batchInputError: _batchInputError,
                              batchText: _batchController.text,
                              audienceCount: _audienceCount,
                              countingAudience: _countingAudience,
                              audienceError: _audienceError,
                              onRetryCount: () =>
                                  _refreshAudienceCount(force: true),
                            ),
                            const SizedBox(height: AdminDensity.space2),
                            const Divider(height: 1, color: AdminColors.border),
                            const SizedBox(height: AdminDensity.space1),
                            _DeliveryToggle(
                              title: 'In-app notification',
                              value: _notifyInApp,
                              onChanged: (v) =>
                                  setState(() => _notifyInApp = v),
                            ),
                            _DeliveryToggle(
                              title: 'Phone / browser alert',
                              subtitle:
                                  'For alumni who allowed alerts on their device',
                              value: _notifyInApp && _notifyPush,
                              onChanged: _notifyInApp
                                  ? (v) => setState(() => _notifyPush = v)
                                  : null,
                            ),
                            _DeliveryToggle(
                              title: 'Mark as urgent',
                              subtitle:
                                  'Ignores alumni category settings and quiet hours',
                              value: _notifyInApp && _urgent,
                              onChanged: _notifyInApp
                                  ? (v) => setState(() => _urgent = v)
                                  : null,
                            ),
                            _DeliveryToggle(
                              title: 'Email notification',
                              subtitle: EmailDeliveryConfig.isConfigured
                                  ? 'Sends through Gmail SMTP'
                                  : 'Check Gmail SMTP / Supabase secrets',
                              value: _notifyEmail,
                              onChanged: EmailDeliveryConfig.isConfigured
                                  ? (v) => setState(() => _notifyEmail = v)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          _PanelFooter(
            canPublish: item?.status == AnnouncementStatus.draft,
            busy: _isSaving || (_isLoading && item == null),
            canSave: item != null,
            saveLabel: item?.status == AnnouncementStatus.published
                ? 'Save changes'
                : 'Save draft',
            onClose: () => Navigator.pop(context),
            onSave: _save,
            onPublish: _publish,
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.onClose,
    this.status,
    this.priority,
    this.urgent = false,
  });

  final String title;
  final VoidCallback? onClose;
  final AnnouncementStatus? status;
  final AnnouncementPriority? priority;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final important = priority == AnnouncementPriority.important;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: important ? AdminColors.dangerBg : AdminColors.primaryTint,
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            ),
            child: Icon(
              important ? Icons.priority_high_rounded : Icons.campaign_outlined,
              size: 20,
              color: important ? AdminColors.danger : AdminColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Announcement',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      AnnouncementStatusChip(status: status!),
                      if (priority != null)
                        AnnouncementPriorityChip(priority: priority!),
                      if (urgent)
                        const AdminBadge.warning(
                          label: 'Urgent',
                          icon: Icons.bolt_rounded,
                          dense: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            style: AdminDensity.iconButtonStyle(
              foregroundColor: AdminColors.textSecondary,
            ),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _PanelFooter extends StatelessWidget {
  const _PanelFooter({
    required this.canPublish,
    required this.busy,
    required this.canSave,
    required this.saveLabel,
    required this.onClose,
    required this.onSave,
    required this.onPublish,
  });

  final bool canPublish;
  final bool busy;
  final bool canSave;
  final String saveLabel;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: busy ? null : onClose,
                style: AdminButtonStyles.outlined(),
                child: const Text('Close'),
              ),
              if (canSave)
                canPublish
                    ? OutlinedButton(
                        onPressed: busy ? null : onSave,
                        style: AdminButtonStyles.outlined(),
                        child: Text(saveLabel),
                      )
                    : FilledButton(
                        onPressed: busy ? null : onSave,
                        style: AdminButtonStyles.filled(),
                        child: Text(saveLabel),
                      ),
              if (canPublish)
                FilledButton.icon(
                  onPressed: (busy || !canSave) ? null : onPublish,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.publish_outlined, size: 16),
                  label: const Text('Publish'),
                  style: AdminButtonStyles.filled(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AdminDensity.space2),
          child,
        ],
      ),
    );
  }
}

class _DeliveryToggle extends StatelessWidget {
  const _DeliveryToggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AdminColors.primary,
          ),
        ],
      ),
    );
  }
}

class _AudiencePreview extends StatelessWidget {
  const _AudiencePreview({
    required this.targetPrograms,
    required this.targetBatchYears,
    required this.batchInputError,
    required this.batchText,
    required this.audienceCount,
    required this.countingAudience,
    required this.audienceError,
    required this.onRetryCount,
  });

  final List<String> targetPrograms;
  final List<String> targetBatchYears;
  final String? batchInputError;
  final String batchText;
  final int? audienceCount;
  final bool countingAudience;
  final String? audienceError;
  final VoidCallback onRetryCount;

  @override
  Widget build(BuildContext context) {
    if (batchInputError != null) {
      return Text(
        batchInputError!,
        style: const TextStyle(
          color: AdminColors.danger,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final hasFilters =
        targetPrograms.isNotEmpty || batchText.trim().isNotEmpty;
    if (hasFilters && targetBatchYears.isEmpty && batchText.trim().isNotEmpty) {
      return const Text(
        'Fix batch year format to see audience count.',
        style: TextStyle(
          color: AdminColors.warning,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (countingAudience) {
      return const Text(
        'Checking audience…',
        style: TextStyle(
          fontSize: 12.5,
          color: AdminColors.textSecondary,
        ),
      );
    }

    if (audienceError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              audienceError!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AdminColors.warning,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetryCount,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final count = audienceCount ?? 0;
    final label = !hasFilters
        ? 'All alumni ($count) — no filters applied'
        : count == 0
        ? 'No alumni in this range — adjust filters before publishing'
        : '$count ${count == 1 ? 'alumnus matches' : 'alumni match'} this range';
    final isZero = hasFilters && count == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isZero ? AdminColors.warningBg : AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(
          color: isZero
              ? AdminColors.warning.withValues(alpha: 0.3)
              : AdminColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isZero ? Icons.warning_amber_rounded : Icons.groups_outlined,
            size: 15,
            color: isZero ? AdminColors.warning : AdminColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isZero
                    ? AdminColors.warning
                    : AdminColors.textSecondary,
                fontWeight: isZero ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
