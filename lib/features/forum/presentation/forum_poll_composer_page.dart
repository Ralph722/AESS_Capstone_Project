import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/forum/data/forum_content_moderation_service.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/widgets/forum_moderation_dialog.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Opens the poll composer as an admin side panel or full-screen route.
Future<String?> showAdminForumPollComposer(BuildContext context) {
  const child = ForumPollComposerPage(asSidePanel: true);
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

/// Community poll composer — portal styling aligned with Share a job / discussions.
class ForumPollComposerPage extends StatefulWidget {
  const ForumPollComposerPage({super.key, this.asSidePanel = false});

  final bool asSidePanel;

  @override
  State<ForumPollComposerPage> createState() => _ForumPollComposerPageState();
}

class _ForumPollComposerPageState extends State<ForumPollComposerPage> {
  final _forumService = ForumService();
  final _moderationService = ForumContentModerationService();
  final _questionController = TextEditingController();
  final _bodyController = TextEditingController();
  final _questionFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  late final List<TextEditingController> _optionControllers;
  late final List<FocusNode> _optionFocusNodes;
  bool _saving = false;
  bool _checkingContent = false;
  ForumTopicVisibility _visibility = ForumTopicVisibility.everyone;
  String _viewerProgram = '';
  String _viewerBatch = '';

  bool get _busy => _saving || _checkingContent;

  @override
  void initState() {
    super.initState();
    _optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    _optionFocusNodes = [FocusNode(), FocusNode()];
    final audience = _forumService.cachedViewerAudience;
    if (audience != null) {
      _viewerProgram = audience.program;
      _viewerBatch = audience.batch;
    }
    _loadAudience();
  }

  Future<void> _loadAudience() async {
    final userId = AppSession.userId;
    if (userId == null) return;
    try {
      final profile = await UserProfileService().getTracerProfile(userId);
      final program = profile?.program.trim() ?? '';
      final batch = (profile?.batchYear.trim().isNotEmpty == true)
          ? profile!.batchYear.trim()
          : (profile?.yearGraduated.trim() ?? '');
      _forumService.cacheViewerAudience(program: program, batch: batch);
      if (!mounted) return;
      setState(() {
        _viewerProgram = program;
        _viewerBatch = batch;
        if (_visibility == ForumTopicVisibility.programBatch &&
            !_canUseBatchAudience) {
          _visibility = _canUseProgramAudience
              ? ForumTopicVisibility.program
              : ForumTopicVisibility.everyone;
        } else if (_visibility == ForumTopicVisibility.program &&
            !_canUseProgramAudience) {
          _visibility = ForumTopicVisibility.everyone;
        }
      });
    } catch (_) {
      // Keep Everyone.
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _bodyController.dispose();
    _questionFocus.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    for (final f in _optionFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  List<String> get _cleanedOptions {
    final out = <String>[];
    for (final c in _optionControllers) {
      final t = c.text.trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  bool get _canUseProgramAudience => _viewerProgram.trim().isNotEmpty;
  bool get _canUseBatchAudience =>
      _canUseProgramAudience && _viewerBatch.trim().isNotEmpty;

  bool _visibilityEnabled(ForumTopicVisibility option) => switch (option) {
    ForumTopicVisibility.everyone => true,
    ForumTopicVisibility.program => _canUseProgramAudience,
    ForumTopicVisibility.programBatch => _canUseBatchAudience,
  };

  String get _visibilityDescription {
    final enabled = _visibilityEnabled(_visibility);
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

  void _addOption() {
    if (_optionControllers.length >= ForumService.pollMaxOptions) return;
    setState(() {
      _optionControllers.add(TextEditingController());
      _optionFocusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _optionFocusNodes.last.requestFocus();
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= ForumService.pollMinOptions) return;
    setState(() {
      _optionControllers.removeAt(index).dispose();
      _optionFocusNodes.removeAt(index).dispose();
    });
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    bool alignHint = false,
    String? counterText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignHint,
      counterText: counterText,
      filled: true,
      fillColor: widget.asSidePanel ? AdminColors.surface : PortalTheme.pageBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: BorderSide(
          color: widget.asSidePanel ? AdminColors.border : PortalTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: BorderSide(
          color: widget.asSidePanel ? AdminColors.border : PortalTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: BorderSide(
          color: widget.asSidePanel ? AdminColors.primary : PortalTheme.navy,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: BorderSide(
          color: widget.asSidePanel ? AdminColors.danger : PortalTheme.danger,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: BorderSide(
          color: widget.asSidePanel ? AdminColors.danger : PortalTheme.danger,
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _publish() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final options = _cleanedOptions;
    if (options.length < ForumService.pollMinOptions) {
      showPortalErrorSnack(
        context,
        Exception('Add at least ${ForumService.pollMinOptions} options'),
      );
      return;
    }

    setState(() => _checkingContent = true);
    final busy = showForumBusyDialog(context, 'Checking content…');
    ForumModerationResult moderation;
    try {
      moderation = await _moderationService.reviewTopic(
        title: _questionController.text.trim(),
        body: [
          _bodyController.text.trim(),
          ...options,
        ].where((s) => s.isNotEmpty).join('\n'),
      );
    } catch (e) {
      await busy.close();
      if (!mounted) return;
      setState(() => _checkingContent = false);
      showPortalErrorSnack(context, e);
      return;
    }
    await busy.close();
    if (!mounted) return;
    setState(() => _checkingContent = false);

    final proceed = await showForumModerationResult(
      context,
      moderation,
      subject: 'poll',
    );
    if (!proceed || !mounted) return;

    setState(() => _saving = true);
    final publishBusy = showForumBusyDialog(context, 'Publishing poll…');
    try {
      final id = await _forumService.createPoll(
        title: _questionController.text,
        body: _bodyController.text,
        options: options,
        visibility: _visibility,
      );
      await publishBusy.close();
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      await publishBusy.close();
      if (!mounted) return;
      showPortalErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _tipBanner() {
    final navy = widget.asSidePanel ? AdminColors.primary : PortalTheme.navy;
    final bg = navy.withValues(alpha: 0.07);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
        border: Border.all(color: navy.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            ),
            child: Icon(Icons.bar_chart_rounded, size: 20, color: navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community pulse',
                  style: PortalTheme.cardTitle.copyWith(
                    fontSize: 14,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ask one short question with 2–4 choices. '
                  'This is a Community poll — not a system survey.',
                  style: PortalTheme.bodySecondary.copyWith(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return PortalCardShell(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
      elevation: widget.asSidePanel ? 0 : 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PortalTheme.cardTitle.copyWith(
              color: widget.asSidePanel
                  ? AdminColors.textPrimary
                  : PortalTheme.navy,
              fontSize: 15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: PortalTheme.caption.copyWith(height: 1.35),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _optionRow(int index) {
    final canRemove =
        _optionControllers.length > ForumService.pollMinOptions && !_busy;
    return Padding(
      padding: EdgeInsets.only(
        bottom: index == _optionControllers.length - 1 ? 0 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (widget.asSidePanel
                        ? AdminColors.primary
                        : PortalTheme.navy)
                    .withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: PortalTheme.meta.copyWith(
                  fontWeight: FontWeight.w800,
                  color: widget.asSidePanel
                      ? AdminColors.primary
                      : PortalTheme.navy,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _optionControllers[index],
              focusNode: _optionFocusNodes[index],
              maxLength: ForumService.pollOptionMaxLength,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              textInputAction:
                  index == _optionControllers.length - 1 &&
                      _optionControllers.length < ForumService.pollMaxOptions
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: (_) {
                if (index == _optionControllers.length - 1 &&
                    _optionControllers.length < ForumService.pollMaxOptions) {
                  _addOption();
                }
              },
              style: PortalTheme.body,
              decoration: _fieldDecoration(
                label: 'Option ${index + 1}',
                hint: index == 0
                    ? 'First choice'
                    : index == 1
                    ? 'Second choice'
                    : 'Another choice',
                counterText: '',
              ),
              validator: (v) {
                final filled = _cleanedOptions.length;
                final t = (v ?? '').trim();
                if (t.isEmpty &&
                    filled < ForumService.pollMinOptions &&
                    index < ForumService.pollMinOptions) {
                  return 'Required';
                }
                if (t.length > ForumService.pollOptionMaxLength) {
                  return 'Too long';
                }
                return null;
              },
            ),
          ),
          if (canRemove) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Remove option',
              onPressed: () => _removeOption(index),
              style: IconButton.styleFrom(
                foregroundColor: PortalTheme.textMuted,
              ),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _visibilityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _visibilityDescription,
          style: PortalTheme.caption.copyWith(height: 1.35),
        ),
        const SizedBox(height: 10),
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
                    label: option.shortLabel,
                    selected: _visibility == option,
                    onTap: () => setState(() => _visibility = option),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildScrollBody() {
    final bottomPad = widget.asSidePanel ? 24.0 : 120.0;
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          widget.asSidePanel ? AdminDensity.space4 : PortalTheme.space3,
          widget.asSidePanel ? 12 : PortalTheme.space2,
          widget.asSidePanel ? AdminDensity.space4 : PortalTheme.space3,
          bottomPad,
        ),
        children: [
          _tipBanner(),
          const SizedBox(height: PortalTheme.space3),
          _sectionCard(
            title: 'Your question',
            subtitle: 'Keep it clear — alumni should answer in one tap.',
            children: [
              TextFormField(
                controller: _questionController,
                focusNode: _questionFocus,
                maxLength: ForumService.titleMaxLength,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: PortalTheme.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _fieldDecoration(
                  label: 'Question',
                  hint: 'What should we ask the community?',
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Question is required';
                  if (t.length > ForumService.titleMaxLength) {
                    return 'Question is too long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLength: 500,
                maxLines: 3,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                style: PortalTheme.body,
                decoration: _fieldDecoration(
                  label: 'Details (optional)',
                  hint: 'Add context if it helps',
                  alignHint: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: PortalTheme.space3),
          _sectionCard(
            title: 'Choices',
            subtitle:
                'Add ${_optionControllers.length} of ${ForumService.pollMaxOptions} '
                'options · at least ${ForumService.pollMinOptions} required',
            children: [
              for (var i = 0; i < _optionControllers.length; i++)
                _optionRow(i),
              if (_optionControllers.length < ForumService.pollMaxOptions) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _addOption,
                    style: TextButton.styleFrom(
                      foregroundColor: widget.asSidePanel
                          ? AdminColors.primary
                          : PortalTheme.navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add option'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: PortalTheme.space3),
          _sectionCard(
            title: 'Audience',
            children: [_visibilityPicker()],
          ),
        ],
      ),
    );
  }

  Widget _publishButton({required bool dense}) {
    final label = _busy ? 'Publishing…' : 'Publish poll';
    if (widget.asSidePanel) {
      return FilledButton(
        onPressed: _busy ? null : _publish,
        style: AdminButtonStyles.filled(),
        child: Text(label),
      );
    }
    return FilledButton(
      onPressed: _busy ? null : _publish,
      style: PortalTheme.primaryButton(dense: dense),
      child: Text(label),
    );
  }

  Widget _alumniFooter() {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: PortalTheme.navy.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: _publishButton(dense: false),
          ),
        ),
      ),
    );
  }

  Widget _adminHeader() {
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
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AdminColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a poll',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AdminColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Community pulse · Publishes immediately',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _busy ? null : () => Navigator.pop(context),
            style: AdminDensity.iconButtonStyle(
              foregroundColor: AdminColors.textSecondary,
            ),
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _adminFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Not a system survey',
              style: AdminText.caption,
            ),
          ),
          const SizedBox(width: 12),
          _publishButton(dense: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSidePanel) {
      return ColoredBox(
        color: AdminColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _adminHeader(),
            const Divider(height: 1, color: AdminColors.border),
            Expanded(child: _buildScrollBody()),
            _adminFooter(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      appBar: const PortalAppBar(
        title: 'Create a poll',
        subtitle: 'Community pulse · Not a survey',
      ),
      body: Column(
        children: [
          Expanded(child: _buildScrollBody()),
          _alumniFooter(),
        ],
      ),
    );
  }
}
