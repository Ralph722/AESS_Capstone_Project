import 'package:flutter/material.dart';
import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/admin/announcements/widgets/admin_announcement_ui.dart';
import 'package:alumni_system/features/announcements/data/announcement_service.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';

/// Opens the announcement editor as a side panel (wide) or dialog (narrow).
Future<void> showAdminAnnouncementEditor({
  required BuildContext context,
  required String announcementId,
  required VoidCallback onChanged,
}) {
  final child = AdminAnnouncementEditorPanel(
    announcementId: announcementId,
    onChanged: onChanged,
  );
  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<void>(
      context: context,
      width: 540,
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
  });

  final String announcementId;
  final VoidCallback onChanged;

  @override
  State<AdminAnnouncementEditorPanel> createState() =>
      _AdminAnnouncementEditorPanelState();
}

class _AdminAnnouncementEditorPanelState
    extends State<AdminAnnouncementEditorPanel> {
  final _service = AnnouncementService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _batchController = TextEditingController();

  Announcement? _item;
  List<String> _targetPrograms = [];
  List<String> _targetBatches = [];
  String? _batchInputError;
  bool _notifyInApp = true;
  bool _notifyEmail = false;
  AnnouncementPriority _priority = AnnouncementPriority.normal;
  bool _isLoading = false;
  bool _isSaving = false;

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

  Future<void> _load() async {
    setState(() => _isLoading = true);
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
      _priority = item.priority;
    }
    setState(() {
      _item = item;
      _isLoading = false;
      _batchInputError = null;
    });
  }

  bool _syncBatchFromField() {
    final text = _batchController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _targetBatches = [];
        _batchInputError = null;
      });
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
      return true;
    } on FormatException catch (e) {
      setState(() => _batchInputError = e.message);
      return false;
    }
  }

  Future<bool> _validateAudienceAvailable() async {
    if (!_syncBatchFromField()) return false;

    final count = await _service.countAudience(
      targetPrograms: _targetPrograms,
      targetBatchYears: _targetBatches,
    );

    final hasFilters =
        _targetPrograms.isNotEmpty || _batchController.text.trim().isNotEmpty;

    if (hasFilters && count == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No alumni match this program/batch range. '
              'Adjust filters or ensure tracer profiles have matching batch years.',
            ),
            backgroundColor: AdminAnnouncementTheme.danger,
          ),
        );
      }
      return false;
    }

    if (!hasFilters && count == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No alumni accounts found to notify.'),
            backgroundColor: AdminAnnouncementTheme.danger,
          ),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _persistDraft() async {
    if (_item == null) return;
    await _service.updateAnnouncement(
      _item!.copyWith(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        targetPrograms: _targetPrograms,
        targetBatchYears: _targetBatches,
        notifyInApp: _notifyInApp,
        notifyEmail: _notifyEmail,
        priority: _priority,
      ),
    );
  }

  Future<void> _save() async {
    if (_item == null || _isSaving) return;
    if (!_syncBatchFromField()) return;
    setState(() => _isSaving = true);
    try {
      await _persistDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      widget.onChanged();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AdminAnnouncementTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _publish() async {
    if (_item == null || _isSaving) return;
    if (!_syncBatchFromField()) return;
    if (!await _validateAudienceAvailable()) return;

    setState(() => _isSaving = true);
    try {
      await _persistDraft();
      final count = await _service.publishAnnouncement(widget.announcementId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Published to $count alumni'),
          backgroundColor: AdminAnnouncementTheme.success,
        ),
      );
      widget.onChanged();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AdminAnnouncementTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Material(
      color: AdminAnnouncementTheme.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: item?.title.trim().isNotEmpty == true
                ? item!.title
                : 'Edit announcement',
            status: item?.status,
            priority: item?.priority ?? _priority,
            onClose: () => Navigator.pop(context),
          ),
          const Divider(height: 1, color: AdminAnnouncementTheme.border),
          Expanded(
            child: _isLoading && item == null
                ? const AdminFormEditorSkeleton()
                : item == null
                    ? const Center(child: Text('Announcement not found'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AdminAnnouncementTheme.space3,
                          AdminAnnouncementTheme.space2,
                          AdminAnnouncementTheme.space3,
                          AdminAnnouncementTheme.space3,
                        ),
                        children: [
                          _SectionCard(
                            title: 'Content',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _titleController,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration:
                                      AdminAnnouncementTheme.fieldDecoration(
                                    label: 'Title',
                                  ),
                                ),
                                const SizedBox(height: AdminDensity.space2),
                                TextField(
                                  controller: _bodyController,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration:
                                      AdminAnnouncementTheme.fieldDecoration(
                                    label: 'Message',
                                  ).copyWith(alignLabelWithHint: true),
                                  maxLines: 7,
                                  minLines: 5,
                                ),
                                const SizedBox(height: AdminDensity.space2),
                                DropdownButtonFormField<AnnouncementPriority>(
                                  key: ValueKey(_priority),
                                  initialValue: _priority,
                                  isDense: true,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AdminAnnouncementTheme.textPrimary,
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
                                const Text(
                                  'Courses',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: AdminAnnouncementTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: CourseConstants.courses.map((p) {
                                    final selected =
                                        _targetPrograms.contains(p);
                                    return FilterChip(
                                      label: Text(p),
                                      selected: selected,
                                      showCheckmark: false,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      labelPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      selectedColor:
                                          AdminAnnouncementTheme.infoBg,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        color: selected
                                            ? AdminAnnouncementTheme.primary
                                            : AdminAnnouncementTheme
                                                .textSecondary,
                                      ),
                                      side: const BorderSide(
                                        color: AdminAnnouncementTheme.border,
                                      ),
                                      onSelected: (v) {
                                        setState(() {
                                          if (v) {
                                            _targetPrograms.add(p);
                                          } else {
                                            _targetPrograms.remove(p);
                                          }
                                        });
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
                                  onChanged: (_) {
                                    setState(_syncBatchFromField);
                                  },
                                ),
                                const SizedBox(height: AdminDensity.space1),
                                _AudiencePreview(
                                  targetPrograms: _targetPrograms,
                                  targetBatchYears: _targetBatches,
                                  batchInputError: _batchInputError,
                                  batchText: _batchController.text,
                                ),
                                const SizedBox(height: AdminDensity.space2),
                                _DeliveryToggle(
                                  title: 'In-app notification',
                                  value: _notifyInApp,
                                  onChanged: (v) =>
                                      setState(() => _notifyInApp = v),
                                ),
                                _DeliveryToggle(
                                  title: 'Email notification',
                                  subtitle: EmailDeliveryConfig.isConfigured
                                      ? 'Sends through Gmail SMTP'
                                      : 'Check Gmail SMTP / Supabase secrets',
                                  value: _notifyEmail,
                                  onChanged: EmailDeliveryConfig.isConfigured
                                      ? (v) =>
                                          setState(() => _notifyEmail = v)
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
  });

  final String title;
  final VoidCallback onClose;
  final AnnouncementStatus? status;
  final AnnouncementPriority? priority;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminAnnouncementTheme.space3,
        AdminAnnouncementTheme.space2,
        AdminAnnouncementTheme.space1,
        AdminAnnouncementTheme.space1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Announcement',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminAnnouncementTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminAnnouncementTheme.textPrimary,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      AnnouncementStatusChip(status: status!),
                      if (priority != null)
                        AnnouncementPriorityChip(priority: priority!),
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
              foregroundColor: AdminAnnouncementTheme.textSecondary,
            ),
            icon: const Icon(Icons.close),
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
    required this.saveLabel,
    required this.onClose,
    required this.onSave,
    required this.onPublish,
  });

  final bool canPublish;
  final bool busy;
  final String saveLabel;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: AdminAnnouncementTheme.card,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.1),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: busy ? null : onClose,
                style: announcementOutlinedButtonStyle(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: busy ? null : onSave,
                style: announcementFilledButtonStyle(
                  background: AdminAnnouncementTheme.infoBg,
                  foreground: AdminAnnouncementTheme.primary,
                ),
                child: Text(saveLabel),
              ),
              if (canPublish)
                FilledButton.icon(
                  onPressed: busy ? null : onPublish,
                  icon: const Icon(Icons.publish_outlined, size: 16),
                  label: const Text('Publish'),
                  style: announcementFilledButtonStyle(
                    background: AdminAnnouncementTheme.success,
                  ),
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
      padding: const EdgeInsets.all(AdminDensity.cardPadding),
      decoration: BoxDecoration(
        color: AdminAnnouncementTheme.background,
        borderRadius: BorderRadius.circular(AdminAnnouncementTheme.radiusMd),
        border: Border.all(color: AdminAnnouncementTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AdminAnnouncementTheme.textPrimary,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminAnnouncementTheme.textSecondary,
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
                    color: AdminAnnouncementTheme.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminAnnouncementTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AdminAnnouncementTheme.primary,
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
  });

  final List<String> targetPrograms;
  final List<String> targetBatchYears;
  final String? batchInputError;
  final String batchText;

  @override
  Widget build(BuildContext context) {
    if (batchInputError != null) {
      return Text(
        batchInputError!,
        style: const TextStyle(
          color: AdminAnnouncementTheme.danger,
          fontSize: 12.5,
        ),
      );
    }

    final hasFilters =
        targetPrograms.isNotEmpty || batchText.trim().isNotEmpty;
    if (!hasFilters) {
      return _countFuture(
        targetPrograms,
        targetBatchYears,
        labelWhenReady: (n) => 'All alumni ($n) — no filters applied',
      );
    }

    if (targetBatchYears.isEmpty && batchText.trim().isNotEmpty) {
      return const Text(
        'Fix batch year format to see audience count.',
        style: TextStyle(
          color: AdminAnnouncementTheme.warning,
          fontSize: 12.5,
        ),
      );
    }

    return _countFuture(
      targetPrograms,
      targetBatchYears,
      labelWhenReady: (n) => n == 0
          ? 'No alumni in this range — adjust filters before publishing'
          : '$n alumni match this range',
      highlightZero: true,
    );
  }

  Widget _countFuture(
    List<String> programs,
    List<String> batches, {
    required String Function(int) labelWhenReady,
    bool highlightZero = false,
  }) {
    return FutureBuilder<int>(
      future: AnnouncementService().countAudience(
        targetPrograms: programs,
        targetBatchYears: batches,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            'Checking audience…',
            style: TextStyle(
              fontSize: 12.5,
              color: AdminAnnouncementTheme.textMuted,
            ),
          );
        }
        final count = snapshot.data ?? 0;
        final isZero = highlightZero && count == 0;
        return Text(
          labelWhenReady(count),
          style: TextStyle(
            fontSize: 12.5,
            color: isZero
                ? AdminAnnouncementTheme.warning
                : AdminAnnouncementTheme.textSecondary,
            fontWeight: isZero ? FontWeight.w600 : FontWeight.w500,
          ),
        );
      },
    );
  }
}
