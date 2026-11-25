import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/data/forum_content_moderation_service.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/widgets/forum_format_toolbar.dart';
import 'package:alumni_system/features/forum/widgets/forum_moderation_dialog.dart';
import 'package:alumni_system/features/forum/widgets/forum_rich_text_controller.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_action_dialog.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
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

class _ForumComposerPageState extends State<ForumComposerPage> {
  final _forumService = ForumService();
  final _moderationService = ForumContentModerationService();
  final _titleController = TextEditingController();
  final _bodyController = ForumRichTextController();
  final _bodyFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  List<ForumTag> _tags = [];
  final Set<String> _selectedTagIds = {};
  bool _asAnnouncement = false;
  bool _isAdmin = false;
  ForumTopicVisibility _visibility = ForumTopicVisibility.everyone;
  String _viewerProgram = '';
  String _viewerBatch = '';
  bool _saving = false;
  bool _checkingContent = false;
  bool _dirty = false;
  bool _loadingTags = false;
  bool _draftRestored = false;
  Timer? _draftTimer;

  /// Bumped on discard so in-flight [saveDraft] cannot rewrite cleared prefs.
  int _draftEpoch = 0;

  bool get _isEditing => widget.editTopic != null;
  bool get _busy => _saving || _checkingContent;

  @override
  void initState() {
    super.initState();
    _asAnnouncement = widget.initialAsAnnouncement;
    final cached = _forumService.cachedTags;
    if (cached != null) {
      _tags = List<ForumTag>.of(cached);
      _loadingTags = false;
    } else {
      _loadingTags = true;
    }
    final audience = _forumService.cachedViewerAudience;
    if (audience != null) {
      _viewerProgram = audience.program;
      _viewerBatch = audience.batch;
    }
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

  Future<void> _saveDraftNow() async {
    _draftTimer?.cancel();
    final epoch = _draftEpoch;
    if (!_hasContent) {
      await _forumService.clearDraft();
      return;
    }
    final title = _titleController.text;
    final body = _bodyController.markdown;
    final tagIds = _selectedTagIds.toList();
    final asAnnouncement = _asAnnouncement;
    final visibility = _visibility;
    await _forumService.saveDraft(
      title: title,
      body: body,
      tagIds: tagIds,
      asAnnouncement: asAnnouncement,
      visibility: visibility,
    );
    // Discard raced this save — wipe the rewritten draft.
    if (epoch != _draftEpoch) {
      await _forumService.clearDraft();
    }
  }

  Future<void> _discardDraft() async {
    final title = _titleController.text;
    final body = _bodyController.markdown;
    final tagIds = Set<String>.of(_selectedTagIds);
    final asAnnouncement = _asAnnouncement;
    final visibility = _visibility;

    _draftEpoch++;
    _draftTimer?.cancel();
    _titleController.clear();
    _bodyController.clear();
    await _forumService.clearDraft();
    if (!mounted) return;
    setState(() {
      _selectedTagIds.clear();
      _asAnnouncement = widget.initialAsAnnouncement;
      _visibility = ForumTopicVisibility.everyone;
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
              _visibility = visibility;
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
      try {
        final profile = await UserProfileService().getTracerProfile(uid);
        _viewerProgram = profile?.program.trim() ?? '';
        _viewerBatch = (profile?.batchYear.trim().isNotEmpty == true)
            ? profile!.batchYear.trim()
            : (profile?.yearGraduated.trim() ?? '');
        _forumService.cacheViewerAudience(
          program: _viewerProgram,
          batch: _viewerBatch,
        );
      } catch (_) {}
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
      _visibility = t.visibility;
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
        _visibility = ForumTopicVisibility.fromWire(
          draft['visibility'] as String?,
        );
        _draftRestored = _hasContent;
        _dirty = false;
      }
    }

    if (!_canUseBatchAudience &&
        _visibility == ForumTopicVisibility.programBatch) {
      _visibility = _canUseProgramAudience
          ? ForumTopicVisibility.program
          : ForumTopicVisibility.everyone;
    } else if (!_canUseProgramAudience &&
        _visibility != ForumTopicVisibility.everyone) {
      _visibility = ForumTopicVisibility.everyone;
    }

    if (mounted) {
      setState(() => _loadingTags = false);
    }
  }

  @override
  void dispose() {
    // Keep the last keystrokes when leaving without an explicit discard.
    final shouldFlush = !_isEditing &&
        (_draftTimer?.isActive ?? false) &&
        _hasContent;
    _draftTimer?.cancel();
    if (shouldFlush) {
      final epoch = _draftEpoch;
      final title = _titleController.text;
      final body = _bodyController.markdown;
      final tagIds = _selectedTagIds.toList();
      final asAnnouncement = _asAnnouncement;
      final visibility = _visibility;
      unawaited(() async {
        await _forumService.saveDraft(
          title: title,
          body: body,
          tagIds: tagIds,
          asAnnouncement: asAnnouncement,
          visibility: visibility,
        );
        if (epoch != _draftEpoch) {
          await _forumService.clearDraft();
        }
      }());
    }
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.save),
            style: PortalTheme.primaryButton(),
            child: const Text('Save draft'),
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
      _draftEpoch++;
      _draftTimer?.cancel();
      _titleController.clear();
      _bodyController.clear();
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
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _checkingContent = true);
    var busy = showForumBusyDialog(context, 'Checking your post…');
    ForumModerationResult moderation;
    try {
      moderation = await _moderationService.reviewTopic(
        title: _titleController.text,
        body: _bodyController.text,
      );
    } catch (e) {
      await busy.close();
      if (mounted) {
        setState(() => _checkingContent = false);
        showPortalErrorSnack(context, e);
      }
      return;
    }
    await busy.close();
    if (!mounted) return;
    setState(() => _checkingContent = false);

    final proceed = await showForumModerationResult(
      context,
      moderation,
      subject: 'topic',
    );
    if (!proceed || !mounted) return;

    _draftTimer?.cancel();
    setState(() => _saving = true);
    busy = showForumBusyDialog(
      context,
      _isEditing ? 'Saving changes…' : 'Publishing…',
    );
    try {
      if (_isEditing) {
        await _forumService.editTopic(
          topicId: widget.editTopic!.id,
          title: _titleController.text,
          body: _bodyController.markdown,
          tagIds: _selectedTagIds.toList(),
        );
        await busy.close();
        if (!mounted) return;
        Navigator.pop(context, widget.editTopic!.id);
      } else {
        final id = await _forumService.createTopic(
          title: _titleController.text,
          body: _bodyController.markdown,
          tagIds: _selectedTagIds.toList(),
          asAnnouncement: _isAdmin && _asAnnouncement,
          visibility: _asAnnouncement
              ? ForumTopicVisibility.everyone
              : _visibility,
        );
        await busy.close();
        if (!mounted) return;
        Navigator.pop(context, id);
      }
    } catch (e) {
      await busy.close();
      if (!mounted) return;
      showPortalErrorSnack(context, e);
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
          if (widget.asSidePanel) ...[
            _panelHeader(),
            const Divider(height: 1, color: AdminColors.border),
          ],
          Expanded(child: _writeTab()),
          if (widget.asSidePanel) _panelFooter(),
        ],
      ),
    );

    if (widget.asSidePanel) {
      return ColoredBox(color: AdminColors.card, child: body);
    }

    return PopScope(
      canPop: !_shouldAskOnLeave,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _close();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PortalAppBar(
          title: _headerTitle,
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
    return Container(
      color: AdminColors.card,
      padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AdminColors.infoBg,
              borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
              border: Border.all(
                color: AdminColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Icon(
              _asAnnouncement
                  ? Icons.campaign_outlined
                  : Icons.forum_outlined,
              color: AdminColors.primary,
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
                    letterSpacing: -0.2,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _asAnnouncement
                      ? 'Pinned announcement for all alumni'
                      : 'Start a moderated discussion',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _busy ? null : _close,
            style: AdminDensity.iconButtonStyle(
              foregroundColor: AdminColors.textSecondary,
            ),
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _panelFooter() {
    return Container(
      color: AdminColors.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: AdminColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _close,
                  style: AdminButtonStyles.outlined(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: AdminButtonStyles.filled(),
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
                          _isEditing
                              ? Icons.save_outlined
                              : Icons.send_outlined,
                          size: 17,
                        ),
                  label: Text(
                    _checkingContent
                        ? 'Checking…'
                        : (_isEditing ? 'Save' : 'Post'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _writeTab() {
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
                setState(() {
                  _asAnnouncement = v;
                  if (v) _visibility = ForumTopicVisibility.everyone;
                });
                _onTextChanged();
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        TextFormField(
          controller: _titleController,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
        if (!_isEditing && !_asAnnouncement) ...[
          const SizedBox(height: 16),
          _visibilityPicker(),
        ],
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _loadingTags
              ? [
                  for (final label in const [
                    'Career',
                    'Employment',
                    'Business',
                    'Networking',
                    'Events',
                    'Question',
                  ])
                    Opacity(
                      opacity: 0.45,
                      child: ForumTagChip(label: label),
                    ),
                ]
              : _tags.map((tag) {
                  final selected = _selectedTagIds.contains(tag.id);
                  return ForumTagChip(
                    label: tag.label,
                    selected: selected,
                    onTap: _busy
                        ? null
                        : () {
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
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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

  bool get _canUseProgramAudience => _viewerProgram.trim().isNotEmpty;
  bool get _canUseBatchAudience =>
      _canUseProgramAudience && _viewerBatch.trim().isNotEmpty;

  String get _visibilityDescription {
    final enabled = switch (_visibility) {
      ForumTopicVisibility.everyone => true,
      ForumTopicVisibility.program => _canUseProgramAudience,
      ForumTopicVisibility.programBatch => _canUseBatchAudience,
    };
    if (!enabled) {
      return switch (_visibility) {
        ForumTopicVisibility.everyone =>
          ForumTopicVisibility.everyone.helperText(),
        ForumTopicVisibility.program =>
          'Add your program in Profile to enable.',
        ForumTopicVisibility.programBatch =>
          'Add your program and batch year in Profile to enable.',
      };
    }
    return _visibility.helperText(
      program: _viewerProgram,
      batch: _viewerBatch,
    );
  }

  bool _visibilityEnabled(ForumTopicVisibility option) => switch (option) {
    ForumTopicVisibility.everyone => true,
    ForumTopicVisibility.program => _canUseProgramAudience,
    ForumTopicVisibility.programBatch => _canUseBatchAudience,
  };

  Widget _visibilityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Visibility',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: ForumTheme.navy,
                  fontSize: 13,
                ),
              ),
              TextSpan(
                text: ' · $_visibilityDescription',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ForumTheme.textMuted,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in ForumTopicVisibility.values)
              Opacity(
                opacity: _visibilityEnabled(option) ? 1 : 0.45,
                child: IgnorePointer(
                  ignoring: _busy || !_visibilityEnabled(option),
                  child: ForumTagChip(
                    label: option.label,
                    selected: _visibility == option,
                    onTap: () {
                      setState(() => _visibility = option);
                      _onTextChanged();
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
