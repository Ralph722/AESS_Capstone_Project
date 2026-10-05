import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/data/forum_content_moderation_service.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/widgets/forum_format_toolbar.dart';
import 'package:alumni_system/features/forum/widgets/forum_formatted_text.dart';
import 'package:alumni_system/features/forum/widgets/forum_moderation_dialog.dart';
import 'package:alumni_system/features/forum/widgets/forum_rich_text_controller.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_action_dialog.dart';
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

enum _LeaveChoice { save, discard }

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
  final _bodyController = ForumRichTextController();
  final _bodyFocus = FocusNode();
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
  bool _draftRestored = false;
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
    _draftTimer = Timer(const Duration(milliseconds: 600), _saveDraftNow);
  }

  bool get _hasContent =>
      _titleController.text.trim().isNotEmpty ||
      _bodyController.text.trim().isNotEmpty;

  /// New posts ask whenever there is text (it is kept as a draft); edits ask
  /// only when something changed (edits are not drafted).
  bool get _shouldAskOnLeave => _isEditing ? _dirty : _hasContent;

  Future<void> _saveDraftNow() {
    _draftTimer?.cancel();
    if (!_hasContent) return _forumService.clearDraft();
    return _forumService.saveDraft(
      title: _titleController.text,
      body: _bodyController.markdown,
      tagIds: _selectedTagIds.toList(),
      asAnnouncement: _asAnnouncement,
    );
  }

  Future<void> _discardDraft() async {
    final title = _titleController.text;
    final body = _bodyController.markdown;
    final tagIds = Set<String>.of(_selectedTagIds);
    final asAnnouncement = _asAnnouncement;

    _draftTimer?.cancel();
    await _forumService.clearDraft();
    if (!mounted) return;
    _titleController.clear();
    _bodyController.clear();
    _draftTimer?.cancel();
    setState(() {
      _selectedTagIds.clear();
      _asAnnouncement = widget.initialAsAnnouncement;
      _draftRestored = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Draft discarded'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            _titleController.text = title;
            _bodyController.loadMarkdown(body);
            setState(() {
              _selectedTagIds.addAll(tagIds);
              _asAnnouncement = asAnnouncement;
            });
            _saveDraftNow();
          },
        ),
      ),
    );
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
      _bodyController.loadMarkdown(t.body);
      _selectedTagIds.addAll(t.tags.map((e) => e.id));
      _asAnnouncement = t.isAnnouncement;
      _dirty = false;
    } else {
      final draft = await _forumService.loadDraft();
      if (draft != null && mounted) {
        _titleController.text = draft['title'] as String? ?? '';
        _bodyController.loadMarkdown(draft['body'] as String? ?? '');
        final ids = draft['tagIds'];
        if (ids is List) {
          _selectedTagIds.addAll(ids.map((e) => e.toString()));
        }
        if (_isAdmin && draft['asAnnouncement'] == true) {
          _asAnnouncement = true;
        }
        _draftRestored = _hasContent;
        _dirty = false;
      }
    }

    if (mounted) {
      setState(() => _loadingTags = false);
    }
  }

  @override
  void dispose() {
    // Keeps the last few keystrokes when the page is left without _close().
    if (_draftTimer?.isActive ?? false) _saveDraftNow();
    _draftTimer?.cancel();
    _tabs.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!_shouldAskOnLeave) {
      if (!_isEditing) await _saveDraftNow();
      return true;
    }
    return _isEditing ? _confirmDiscardEdits() : _confirmSaveDraft();
  }

  Future<bool> _confirmDiscardEdits() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => PortalActionDialog(
        title: 'Discard changes?',
        message:
            'Your edits to this discussion have not been saved and '
            'will be lost.',
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: PortalTheme.primaryButton(),
            child: const Text('Keep editing'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: PortalActionDialog.dangerOutlinedButton(),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<bool> _confirmSaveDraft() async {
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => PortalActionDialog(
        title: 'Save as draft?',
        message:
            'Your title and message will be kept on this device so you '
            'can finish this post later.',
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.save),
            style: PortalTheme.primaryButton(),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save draft'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.discard),
            style: PortalActionDialog.dangerOutlinedButton(),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: PortalActionDialog.quietButton(),
            child: const Text('Keep writing'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return false;

    final messenger = ScaffoldMessenger.of(context);
    if (choice == _LeaveChoice.save) {
      await _saveDraftNow();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Draft saved. You can continue it next time.'),
        ),
      );
    } else {
      _draftTimer?.cancel();
      await _forumService.clearDraft();
      messenger.showSnackBar(const SnackBar(content: Text('Draft discarded')));
    }
    return true;
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

    final proceed = await showForumModerationResult(
      context,
      moderation,
      subject: 'topic',
    );
    if (!proceed || !mounted) return;

    _draftTimer?.cancel();
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _forumService.editTopic(
          topicId: widget.editTopic!.id,
          title: _titleController.text,
          body: _bodyController.markdown,
          tagIds: _selectedTagIds.toList(),
        );
        if (!mounted) return;
        Navigator.pop(context, widget.editTopic!.id);
      } else {
        final id = await _forumService.createTopic(
          title: _titleController.text,
          body: _bodyController.markdown,
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
              children: [_writeTab(), _previewTab()],
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
      canPop: !_shouldAskOnLeave,
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
        if (_draftRestored && !_isEditing) ...[
          _draftRestoredNote(),
          const SizedBox(height: 14),
        ],
        if (_isAdmin && !_isEditing) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ForumTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
              border: Border.all(
                color: ForumTheme.border.withValues(alpha: 0.75),
              ),
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
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
              borderSide: BorderSide(
                color: ForumTheme.border.withValues(alpha: 0.9),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
              borderSide: const BorderSide(color: ForumTheme.navy, width: 1.4),
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
        ForumFormatToolbar(
          controller: _bodyController,
          focusNode: _bodyFocus,
          enabled: !_busy,
        ),
        const SizedBox(height: 8),
        CallbackShortcuts(
          bindings: {
            for (final ctrl in [true, false]) ...{
              SingleActivator(
                LogicalKeyboardKey.keyB,
                control: ctrl,
                meta: !ctrl,
              ): () =>
                  _bodyController.toggle(ForumInline.bold),
              SingleActivator(
                LogicalKeyboardKey.keyI,
                control: ctrl,
                meta: !ctrl,
              ): () =>
                  _bodyController.toggle(ForumInline.italic),
            },
          },
          child: _bodyField(),
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

  Widget _bodyField() {
    return TextFormField(
      controller: _bodyController,
      focusNode: _bodyFocus,
      maxLength: ForumService.bodyMaxLength,
      minLines: widget.asSidePanel ? 10 : 8,
      maxLines: 18,
      decoration: InputDecoration(
        labelText: 'Message',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          borderSide: BorderSide(
            color: ForumTheme.border.withValues(alpha: 0.9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
          borderSide: const BorderSide(color: ForumTheme.navy, width: 1.4),
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
        if (_bodyController.markdown.trim().length >
            ForumService.bodyMaxLength) {
          return 'Message is too long (formatting counts toward the limit)';
        }
        return null;
      },
    );
  }

  Widget _draftRestoredNote() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: PortalTheme.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        border: Border.all(color: PortalTheme.navy.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 18, color: PortalTheme.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Draft restored from your last visit.',
              style: PortalTheme.body.copyWith(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _discardDraft,
            style: TextButton.styleFrom(
              foregroundColor: PortalTheme.danger,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Discard draft'),
          ),
        ],
      ),
    );
  }

  Widget _previewTab() {
    final title = _titleController.text.trim();
    final body = _bodyController.markdown.trim();
    final selectedTags = _tags
        .where((t) => _selectedTagIds.contains(t.id))
        .toList();

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
            borderRadius: BorderRadius.circular(ForumTheme.radius2xl),
            border: Border.all(
              color: ForumTheme.border.withValues(alpha: 0.75),
            ),
            boxShadow: ForumTheme.softShadow,
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
                          ForumFormattedText(
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
