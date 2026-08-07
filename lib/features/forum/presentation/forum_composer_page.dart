import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/data/forum_content_moderation_service.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/shared/widgets/safe_link_text.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Opens the forum composer as a right side panel (admin announcements) or
/// full-screen route (alumni / edit discussion).
Future<String?> showAdminForumComposer({
  required BuildContext context,
  bool initialAsAnnouncement = true,
  ForumTopic? editTopic,
}) {
  final child = ForumComposerPage(
    initialAsAnnouncement: initialAsAnnouncement,
    editTopic: editTopic,
    asSidePanel: true,
  );
  if (adminIsWideSurface(context)) {
    return showAdminSidePanel<String>(
      context: context,
      width: 560,
      child: child,
    );
  }
  final height = math.min(720.0, MediaQuery.sizeOf(context).height * 0.9);
  return showAdminDialogSurface<String>(
    context: context,
    maxWidth: 640,
    maxHeight: height,
    child: SizedBox(width: 640, height: height, child: child),
  );
}

class ForumComposerPage extends StatefulWidget {
  const ForumComposerPage({
    super.key,
    this.initialAsAnnouncement = false,
    this.editTopic,
    this.asSidePanel = false,
  });

  final bool initialAsAnnouncement;
  final ForumTopic? editTopic;

  /// When true, renders panel chrome (no full-screen Scaffold AppBar).
  final bool asSidePanel;

  @override
  State<ForumComposerPage> createState() => _ForumComposerPageState();
}

class _ForumComposerPageState extends State<ForumComposerPage>
    with SingleTickerProviderStateMixin {
  final _forumService = ForumService();
  final _moderationService = ForumContentModerationService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final TabController _tabs;
  List<ForumTag> _tags = [];
  final Set<String> _selectedTagIds = {};
  bool _asAnnouncement = false;
  bool _isAdmin = false;
  bool _saving = false;
  bool _checkingContent = false;
  bool _dirty = false;
  bool _loadingTags = true;
  Timer? _draftTimer;

  bool get _isEditing => widget.editTopic != null;
  bool get _busy => _saving || _checkingContent;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _asAnnouncement = widget.initialAsAnnouncement;
    _bootstrap();
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() => _dirty = true);
    _draftTimer?.cancel();
    if (_isEditing) return;
    _draftTimer = Timer(const Duration(milliseconds: 600), () {
      _forumService.saveDraft(
        title: _titleController.text,
        body: _bodyController.text,
        tagIds: _selectedTagIds.toList(),
        asAnnouncement: _asAnnouncement,
      );
    });
  }

  Future<void> _bootstrap() async {
    final uid = AppSession.userId;
    if (uid != null) {
      final role = await AuthService().getUserRole(uid);
      _isAdmin = role == UserRole.admin;
    }

    try {
      _tags = await _forumService.fetchTags();
    } catch (_) {
      _tags = [];
    }

    if (_isEditing) {
      final t = widget.editTopic!;
      _titleController.text = t.title;
      _bodyController.text = t.body;
      _selectedTagIds.addAll(t.tags.map((e) => e.id));
      _asAnnouncement = t.isAnnouncement;
      _dirty = false;
    } else {
      final draft = await _forumService.loadDraft();
      if (draft != null && mounted) {
        _titleController.text = draft['title'] as String? ?? '';
        _bodyController.text = draft['body'] as String? ?? '';
        final ids = draft['tagIds'];
        if (ids is List) {
          _selectedTagIds.addAll(ids.map((e) => e.toString()));
        }
        if (_isAdmin && draft['asAnnouncement'] == true) {
          _asAnnouncement = true;
        }
        _dirty = _titleController.text.isNotEmpty ||
            _bodyController.text.isNotEmpty;
      }
    }

    if (mounted) {
      setState(() => _loadingTags = false);
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _tabs.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: Text(
          _isEditing
              ? 'Your edits will be lost.'
              : 'Your draft is saved on this device. Leave anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ForumTheme.navy),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _close() async {
    final leave = await _confirmLeave();
    if (leave && mounted) Navigator.pop(context);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      if (_tabs.index != 0) _tabs.animateTo(0);
      return;
    }

    setState(() => _checkingContent = true);
    ForumModerationResult moderation;
    try {
      moderation = await _moderationService.reviewTopic(
        title: _titleController.text,
        body: _bodyController.text,
      );
    } finally {
      if (mounted) setState(() => _checkingContent = false);
    }
    if (!mounted) return;

    if (moderation.isBlocked) {
      await _showModerationDialog(
        title: 'Content cannot be published',
        message:
            'This topic appears to contain inappropriate or sensitive content. '
            'Please revise the title or description before posting.',
        reasons: moderation.reasons,
        allowPublishAnyway: false,
      );
      return;
    }

    if (moderation.isWarned) {
      final proceed = await _showModerationDialog(
        title: 'Please review before posting',
        message:
            'This topic may include sensitive content. You can edit it, '
            'or publish anyway if it is appropriate for the alumni community.',
        reasons: moderation.reasons,
        allowPublishAnyway: true,
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _forumService.editTopic(
          topicId: widget.editTopic!.id,
          title: _titleController.text,
          body: _bodyController.text,
          tagIds: _selectedTagIds.toList(),
        );
        if (!mounted) return;
        Navigator.pop(context, widget.editTopic!.id);
      } else {
        final id = await _forumService.createTopic(
          title: _titleController.text,
          body: _bodyController.text,
          tagIds: _selectedTagIds.toList(),
          asAnnouncement: _isAdmin && _asAnnouncement,
        );
        if (!mounted) return;
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _showModerationDialog({
    required String title,
    required String message,
    required List<String> reasons,
    required bool allowPublishAnyway,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: allowPublishAnyway
                              ? PortalTheme.gold.withValues(alpha: 0.18)
                              : PortalTheme.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          allowPublishAnyway
                              ? Icons.info_outline_rounded
                              : Icons.shield_outlined,
                          color: allowPublishAnyway
                              ? PortalTheme.navy
                              : PortalTheme.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: PortalTheme.sectionTitle.copyWith(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    style: PortalTheme.bodySecondary.copyWith(height: 1.4),
                  ),
                  if (reasons.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PortalTheme.pageBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PortalTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why this was flagged',
                            style: PortalTheme.caption.copyWith(
                              color: PortalTheme.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final reason in reasons)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '•  ',
                                    style: PortalTheme.meta.copyWith(
                                      color: PortalTheme.navy,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style: PortalTheme.meta.copyWith(
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: PortalTheme.secondaryButton(dense: true),
                          child: Text(allowPublishAnyway ? 'Edit' : 'OK'),
                        ),
                      ),
                      if (allowPublishAnyway) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: PortalTheme.primaryButton(dense: true),
                            child: const Text('Publish anyway'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _headerTitle {
    if (_isEditing) return 'Edit discussion';
    if (_asAnnouncement) return 'New announcement';
    return 'New discussion';
  }

  @override
  Widget build(BuildContext context) {
    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.asSidePanel) _panelHeader() else const SizedBox.shrink(),
          if (widget.asSidePanel) ...[
            TabBar(
              controller: _tabs,
              labelColor: ForumTheme.navy,
              unselectedLabelColor: ForumTheme.textSecondary,
              indicatorColor: ForumTheme.navy,
              tabs: const [
                Tab(text: 'Write'),
                Tab(text: 'Preview'),
              ],
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _writeTab(),
                _previewTab(),
              ],
            ),
          ),
          if (widget.asSidePanel) _panelFooter(),
        ],
      ),
    );

    if (widget.asSidePanel) {
      return ColoredBox(color: Colors.white, child: body);
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _close();
      },
      child: Scaffold(
        backgroundColor: PortalTheme.pageBg,
        appBar: PortalAppBar(
          title: _headerTitle,
          bottom: TabBar(
            controller: _tabs,
            labelColor: PortalTheme.navy,
            unselectedLabelColor: PortalTheme.textSecondary,
            indicatorColor: PortalTheme.navy,
            tabs: const [
              Tab(text: 'Write'),
              Tab(text: 'Preview'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : _submit,
              style: PortalTheme.ghostButton(dense: true),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save' : 'Post'),
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _panelHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ForumTheme.announcementBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: ForumTheme.announcement,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headerTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ForumTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _asAnnouncement
                      ? 'Pinned announcement for all alumni'
                      : 'Start a moderated discussion',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ForumTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _busy ? null : _close,
            style: AdminDensity.iconButtonStyle(
              foregroundColor: ForumTheme.textMuted,
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _panelFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: _busy ? null : _close,
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isEditing ? Icons.save_outlined : Icons.send_outlined,
                        size: 17,
                      ),
                label: Text(
                  _checkingContent
                      ? 'Checking…'
                      : (_isEditing ? 'Save' : 'Post'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ForumTheme.navy,
                  minimumSize: const Size(0, AdminDensity.buttonHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _writeTab() {
    final titleLen = _titleController.text.characters.length;
    final bodyLen = _bodyController.text.characters.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (_isAdmin && !_isEditing) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ForumTheme.pageBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ForumTheme.border),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Post as announcement',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              subtitle: const Text(
                'Pins automatically and uses announcement styling.',
                style: TextStyle(fontSize: 12),
              ),
              value: _asAnnouncement,
              onChanged: (v) {
                setState(() => _asAnnouncement = v);
                _onTextChanged();
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        TextFormField(
          controller: _titleController,
          maxLength: ForumService.titleMaxLength,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: _asAnnouncement
                ? 'Announcement headline'
                : 'Discussion title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Title is required';
            if (t.length > ForumService.titleMaxLength) {
              return 'Title is too long';
            }
            return null;
          },
        ),
        Text(
          '$titleLen / ${ForumService.titleMaxLength}',
          style: const TextStyle(fontSize: 12, color: ForumTheme.textMuted),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bodyController,
          maxLength: ForumService.bodyMaxLength,
          minLines: widget.asSidePanel ? 10 : 8,
          maxLines: 18,
          decoration: InputDecoration(
            labelText: 'Message',
            alignLabelWithHint: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Message is required';
            if (t.length > ForumService.bodyMaxLength) {
              return 'Message is too long';
            }
            return null;
          },
        ),
        Text(
          '$bodyLen / ${ForumService.bodyMaxLength}',
          style: const TextStyle(fontSize: 12, color: ForumTheme.textMuted),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tags (optional)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: ForumTheme.navy,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingTags)
          const LinearProgressIndicator()
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              final selected = _selectedTagIds.contains(tag.id);
              return ForumTagChip(
                label: tag.label,
                selected: selected,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedTagIds.remove(tag.id);
                    } else {
                      _selectedTagIds.add(tag.id);
                    }
                  });
                  _onTextChanged();
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _previewTab() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final selectedTags =
        _tags.where((t) => _selectedTagIds.contains(t.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'Live preview',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: ForumTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ForumTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_asAnnouncement)
                  Container(width: 4, color: ForumTheme.announcement),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_asAnnouncement) ...[
                          ForumStatusChip.announcement(),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          title.isEmpty ? 'Untitled discussion' : title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: title.isEmpty
                                ? ForumTheme.textMuted
                                : ForumTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (body.isEmpty)
                          Text(
                            'Your message will appear here as you type.',
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              color: ForumTheme.textMuted,
                            ),
                          )
                        else
                          SafeLinkText(
                            body,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              color: ForumTheme.textPrimary,
                            ),
                          ),
                        if (selectedTags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedTags
                                .map((t) => ForumTagChip(label: t.label))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
