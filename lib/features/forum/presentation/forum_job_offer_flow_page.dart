import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/forum/data/forum_content_moderation_service.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/widgets/forum_format_toolbar.dart';
import 'package:alumni_system/features/forum/widgets/forum_moderation_dialog.dart';
import 'package:alumni_system/features/forum/widgets/forum_rich_text_controller.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Alumni flow: intro → compose → purpose letter → submitted.
class ForumJobOfferFlowPage extends StatefulWidget {
  const ForumJobOfferFlowPage({super.key, this.editTopic});

  /// When set, opens on compose to edit a pending offer (declined offers are final).
  final ForumTopic? editTopic;

  @override
  State<ForumJobOfferFlowPage> createState() => _ForumJobOfferFlowPageState();
}

enum _JobOfferStep { intro, compose, letter, done }

class _ForumJobOfferFlowPageState extends State<ForumJobOfferFlowPage> {
  final _forumService = ForumService();
  final _imageStorage = ImageStorageService();
  final _moderationService = ForumContentModerationService();
  final _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _bodyController = ForumRichTextController();
  final _bodyFocus = FocusNode();
  final _applyUrlController = TextEditingController();
  final _letterController = TextEditingController();
  final _composeFormKey = GlobalKey<FormState>();
  final _letterFormKey = GlobalKey<FormState>();

  late _JobOfferStep _step;
  ForumTopicVisibility _visibility = ForumTopicVisibility.everyone;
  String _viewerProgram = '';
  String _viewerBatch = '';
  Uint8List? _pendingCoverBytes;
  String _coverUrl = '';
  bool _coverRemoved = false;
  bool _submitting = false;
  String? _submittedId;

  bool get _isEditing => widget.editTopic != null;

  bool get _isEditingApproved =>
      widget.editTopic?.isApprovedJobOffer == true;

  @override
  void initState() {
    super.initState();
    _step = _isEditing ? _JobOfferStep.compose : _JobOfferStep.intro;
    final edit = widget.editTopic;
    if (edit != null) {
      _titleController.text = edit.title;
      _bodyController.loadMarkdown(edit.body);
      _applyUrlController.text = edit.applyUrl;
      _letterController.text = edit.purposeLetter;
      _visibility = edit.visibility;
      _coverUrl = edit.coverImageUrl;
    }
    _loadAudience();
  }

  Future<void> _loadAudience() async {
    final cached = _forumService.cachedViewerAudience;
    if (cached != null) {
      setState(() {
        _viewerProgram = cached.program;
        _viewerBatch = cached.batch;
      });
      return;
    }
    final uid = AppSession.userId;
    if (uid == null) return;
    try {
      final profile = await UserProfileService().getTracerProfile(uid);
      final program = profile?.program.trim() ?? '';
      final batch = (profile?.batchYear.trim().isNotEmpty == true)
          ? profile!.batchYear.trim()
          : (profile?.yearGraduated.trim() ?? '');
      _forumService.cacheViewerAudience(program: program, batch: batch);
      if (!mounted) return;
      setState(() {
        _viewerProgram = program;
        _viewerBatch = batch;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    _applyUrlController.dispose();
    _letterController.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (_step == _JobOfferStep.intro || _step == _JobOfferStep.done) {
      return true;
    }
    final dirty =
        _titleController.text.trim().isNotEmpty ||
        _bodyController.text.trim().isNotEmpty ||
        _letterController.text.trim().isNotEmpty ||
        _pendingCoverBytes != null;
    if (!dirty && !_isEditing) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: PortalMenu.dialogShape,
        title: const Text('Leave job offer?'),
        content: const Text(
          'Your draft will be discarded. You can start again anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: PortalMenu.dangerButton(),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _pickCover() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 900,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final jpeg = await ImageStorageService.ensureJpegBytes(bytes);
      if (!mounted) return;
      setState(() {
        _pendingCoverBytes = jpeg;
        _coverRemoved = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  void _clearCover() {
    setState(() {
      _pendingCoverBytes = null;
      _coverRemoved = true;
      _coverUrl = '';
    });
  }

  Future<void> _submit() async {
    if (!_letterFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    var busy = showForumBusyDialog(context, 'Checking your post…');
    ForumModerationResult moderation;
    try {
      moderation = await _moderationService.reviewJobOffer(
        title: _titleController.text,
        body: _bodyController.markdown,
        purposeLetter: _letterController.text,
      );
    } catch (e) {
      await busy.close();
      if (mounted) {
        setState(() => _submitting = false);
        showPortalErrorSnack(context, e);
      }
      return;
    }
    await busy.close();
    if (!mounted) return;
    setState(() => _submitting = false);

    final proceed = await showForumModerationResult(
      context,
      moderation,
      subject: 'job offer',
    );
    if (!proceed || !mounted) return;

    setState(() => _submitting = true);
    busy = showForumBusyDialog(
      context,
      _isEditing ? 'Updating job offer…' : 'Submitting for review…',
    );
    try {
      final userId = AppSession.requireUserId();
      final topicId = widget.editTopic?.id ?? LocalId.generate();
      var coverUrl = _coverRemoved ? '' : _coverUrl;
      if (_pendingCoverBytes != null) {
        coverUrl = await _imageStorage.uploadForumJobCoverImage(
          userId: userId,
          topicId: topicId,
          bytes: _pendingCoverBytes!,
        );
      }

      final bodyMarkdown = _bodyController.markdown;
      if (_isEditing) {
        await _forumService.updateJobOffer(
          topicId: topicId,
          title: _titleController.text,
          body: bodyMarkdown,
          purposeLetter: _letterController.text,
          applyUrl: _applyUrlController.text,
          coverImageUrl: coverUrl,
          visibility: _visibility,
        );
      } else {
        await _forumService.createJobOffer(
          topicId: topicId,
          title: _titleController.text,
          body: bodyMarkdown,
          purposeLetter: _letterController.text,
          applyUrl: _applyUrlController.text,
          coverImageUrl: coverUrl,
          visibility: _visibility,
        );
      }
      if (!mounted) return;
      if (_isEditingApproved) {
        Navigator.pop(context, topicId);
        return;
      }
      setState(() {
        _submittedId = topicId;
        _step = _JobOfferStep.done;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      await busy.close();
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    bool alignHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignHint,
      filled: true,
      fillColor: PortalTheme.pageBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: const BorderSide(color: PortalTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: const BorderSide(color: PortalTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: const BorderSide(color: PortalTheme.navy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: const BorderSide(color: PortalTheme.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        borderSide: const BorderSide(color: PortalTheme.danger, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_step == _JobOfferStep.done) {
          Navigator.pop(context, _submittedId);
          return;
        }
        if (_step == _JobOfferStep.letter) {
          setState(() => _step = _JobOfferStep.compose);
          return;
        }
        if (_step == _JobOfferStep.compose && !_isEditing) {
          setState(() => _step = _JobOfferStep.intro);
          return;
        }
        final nav = Navigator.of(context);
        final leave = await _confirmLeave();
        if (!leave || !mounted) return;
        nav.pop();
      },
      child: Scaffold(
        backgroundColor: PortalTheme.pageBg,
        appBar: PortalAppBar(
          title: _appBarTitle,
          subtitle: _appBarSubtitle,
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: PortalTheme.normal,
            switchInCurve: PortalTheme.ease,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                _JobOfferStep.intro => _buildIntro(),
                _JobOfferStep.compose => _buildCompose(),
                _JobOfferStep.letter => _buildLetter(),
                _JobOfferStep.done => _buildDone(),
              },
            ),
          ),
        ),
      ),
    );
  }

  String get _appBarTitle => switch (_step) {
    _JobOfferStep.intro => 'Share a job',
    _JobOfferStep.compose => _isEditing ? 'Edit job offer' : 'Job details',
    _JobOfferStep.letter => 'Purpose letter',
    _JobOfferStep.done => 'Submitted',
  };

  String get _appBarSubtitle => switch (_step) {
    _JobOfferStep.intro => 'Community only · Admin review',
    _JobOfferStep.compose => 'Step 1 of 2 · Visible after approval',
    _JobOfferStep.letter => 'Step 2 of 2 · Admins only',
    _JobOfferStep.done => 'Awaiting community admin review',
  };

  EdgeInsets _pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = PortalBreakpoints.centeredInset(width, maxWidth: 720);
    return EdgeInsets.fromLTRB(
      inset + PortalTheme.space3,
      PortalTheme.space2,
      inset + PortalTheme.space3,
      PortalTheme.space3,
    );
  }

  Widget _buildIntro() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: _pagePadding(context),
            children: [
              PortalHighlightPanel(
                variant: PortalHighlightVariant.navy,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(PortalTheme.radiusMd),
                      ),
                      child: const Icon(
                        Icons.work_outline_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: PortalTheme.space3),
                    Text(
                      'Share an opportunity with fellow alumni',
                      style: PortalTheme.sectionTitle.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Post a role for classmates and graduates. A community '
                      'admin reviews it first, then alumni can read and reply.',
                      style: PortalTheme.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PortalTheme.space3),
              PortalCardShell(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
                child: Column(
                  children: [
                    _introPoint(
                      Icons.visibility_outlined,
                      'Choose who sees it',
                      'Pick everyone, your program, or your batch when you '
                          'share—and you can change it anytime after approval.',
                    ),
                    const Divider(height: 1, color: PortalTheme.border),
                    _introPoint(
                      Icons.mail_outline_rounded,
                      'Add a purpose letter',
                      'Tell admins why you’re sharing this role. Alumni never '
                          'see that note.',
                    ),
                    const Divider(height: 1, color: PortalTheme.border),
                    _introPoint(
                      Icons.notifications_active_outlined,
                      'Get notified',
                      'We’ll let you know when it’s approved or if anything '
                          'needs updating.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _bottomBar(
          primaryLabel: 'Get started',
          onPrimary: () => setState(() => _step = _JobOfferStep.compose),
          secondaryLabel: 'Cancel',
          onSecondary: () => Navigator.maybePop(context),
          primaryExpanded: true,
        ),
      ],
    );
  }

  Widget _introPoint(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PortalTheme.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
            ),
            child: Icon(icon, size: 20, color: PortalTheme.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PortalTheme.cardTitle.copyWith(
                    fontSize: 14,
                    color: PortalTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
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

  Widget _stepProgress({required int activeStep}) {
    // activeStep: 1 = details, 2 = letter
    Widget node(int step, String label) {
      final active = step == activeStep;
      final done = step < activeStep;
      final color = active || done
          ? PortalTheme.navy
          : PortalTheme.textMuted;
      return Expanded(
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done || active
                    ? PortalTheme.navy
                    : PortalTheme.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done || active
                      ? PortalTheme.navy
                      : PortalTheme.borderStrong,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text(
                      '$step',
                      style: PortalTheme.meta.copyWith(
                        color: active ? Colors.white : PortalTheme.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PortalTheme.meta.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PortalCardShell(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderRadius: BorderRadius.circular(PortalTheme.radiusXl),
      elevation: 0.75,
      child: Row(
        children: [
          node(1, 'Job details'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: PortalTheme.textMuted.withValues(alpha: 0.8),
            ),
          ),
          node(2, 'Purpose letter'),
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

  Widget _buildCompose() {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _composeFormKey,
            child: ListView(
              padding: _pagePadding(context),
              children: [
                _stepProgress(activeStep: 1),
                const SizedBox(height: PortalTheme.space3),
                _sectionCard(
                  title: 'Role details',
                  subtitle: 'This is what alumni will read after approval.',
                  children: [
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: ForumService.titleMaxLength,
                      style: PortalTheme.body,
                      decoration: _fieldDecoration(
                        label: 'Job title',
                        hint: 'e.g. Junior software engineer',
                      ),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ForumFormatToolbar(
                      controller: _bodyController,
                      focusNode: _bodyFocus,
                      enabled: !_submitting,
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
                      child: TextFormField(
                        controller: _bodyController,
                        focusNode: _bodyFocus,
                        minLines: 6,
                        maxLines: 12,
                        maxLength: ForumService.bodyMaxLength,
                        textCapitalization: TextCapitalization.sentences,
                        style: PortalTheme.body,
                        decoration: _fieldDecoration(
                          label: 'Details',
                          hint:
                              'Role summary, location, requirements, how to apply…',
                          alignHint: true,
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Add job details';
                          if (_bodyController.markdown.trim().length >
                              ForumService.bodyMaxLength) {
                            return 'Details are too long '
                                '(formatting counts toward the limit)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _applyUrlController,
                      keyboardType: TextInputType.url,
                      maxLength: ForumService.applyUrlMaxLength,
                      style: PortalTheme.body,
                      decoration: _fieldDecoration(
                        label: 'Application link (optional)',
                        hint: 'https://…',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PortalTheme.space3),
                _sectionCard(
                  title: 'Cover image',
                  subtitle: 'Optional. Shown at the top of your job post.',
                  children: [_buildCoverPicker()],
                ),
                const SizedBox(height: PortalTheme.space3),
                _sectionCard(
                  title: 'Audience',
                  subtitle: _isEditingApproved
                      ? 'Who can see this job offer in the community?'
                      : 'Who can see this after a community admin approves it?',
                  children: [
                    for (final v in ForumTopicVisibility.values) ...[
                      if (v != ForumTopicVisibility.values.first)
                        const SizedBox(height: 8),
                      _visibilityOption(v),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      _visibility.helperText(
                        program: _viewerProgram,
                        batch: _viewerBatch,
                      ),
                      style: PortalTheme.caption.copyWith(height: 1.35),
                    ),
                  ],
                ),
                const SizedBox(height: PortalTheme.space2),
              ],
            ),
          ),
        ),
        _bottomBar(
          primaryLabel: 'Continue',
          onPrimary: () {
            if (_composeFormKey.currentState!.validate()) {
              setState(() => _step = _JobOfferStep.letter);
            }
          },
          secondaryLabel: _isEditing ? 'Cancel' : 'Back',
          onSecondary: () {
            if (_isEditing) {
              Navigator.maybePop(context);
            } else {
              setState(() => _step = _JobOfferStep.intro);
            }
          },
        ),
      ],
    );
  }

  Widget _visibilityOption(ForumTopicVisibility value) {
    final selected = _visibility == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _visibility = value),
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? PortalTheme.navy.withValues(alpha: 0.06)
                : PortalTheme.pageBg,
            borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
            border: Border.all(
              color: selected
                  ? PortalTheme.navy.withValues(alpha: 0.45)
                  : PortalTheme.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? PortalTheme.navy : PortalTheme.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value.shortLabel,
                  style: PortalTheme.body.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? PortalTheme.navy
                        : PortalTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    final previewBytes = _pendingCoverBytes;
    final previewUrl = (!_coverRemoved && _coverUrl.trim().isNotEmpty)
        ? _coverUrl
        : null;
    final hasPreview = previewBytes != null || previewUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPreview)
          ClipRRect(
            borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: previewBytes != null
                  ? Image.memory(previewBytes, fit: BoxFit.cover)
                  : Image(
                      image: AppImage.provider(previewUrl!)!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: PortalTheme.surfaceMuted,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          )
        else
          Container(
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PortalTheme.pageBg,
              borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
              border: Border.all(
                color: PortalTheme.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 28,
                  color: PortalTheme.textMuted.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 8),
                Text(
                  'No cover selected',
                  style: PortalTheme.caption,
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickCover,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(hasPreview ? 'Replace' : 'Add cover'),
              style: PortalTheme.secondaryButton(dense: true),
            ),
            if (hasPreview) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _clearCover,
                style: PortalTheme.ghostButton(dense: true),
                child: const Text('Remove'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLetter() {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _letterFormKey,
            child: ListView(
              padding: _pagePadding(context),
              children: [
                _stepProgress(activeStep: 2),
                const SizedBox(height: PortalTheme.space3),
                PortalHighlightPanel(
                  variant: PortalHighlightVariant.attention,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: PortalTheme.gold.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(PortalTheme.radiusMd),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: PortalTheme.navy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visible to community admins only',
                              style: PortalTheme.meta.copyWith(
                                fontWeight: FontWeight.w800,
                                color: PortalTheme.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Alumni never see this letter. Use it to explain '
                              'why you’re sharing the role and who it may help.',
                              style: PortalTheme.caption.copyWith(
                                color: PortalTheme.textSecondary,
                                height: 1.4,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PortalTheme.space3),
                _sectionCard(
                  title: 'Your purpose letter',
                  subtitle:
                      'A few sentences is enough—context helps admins review faster.',
                  children: [
                    TextFormField(
                      controller: _letterController,
                      minLines: 8,
                      maxLines: 14,
                      maxLength: ForumService.purposeLetterMaxLength,
                      textCapitalization: TextCapitalization.sentences,
                      style: PortalTheme.body,
                      decoration: _fieldDecoration(
                        label: 'Purpose letter',
                        hint:
                            'How you know about this role, who it’s for, and any '
                            'context that helps review…',
                        alignHint: true,
                      ),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) {
                          return 'Purpose letter is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: PortalTheme.space2),
              ],
            ),
          ),
        ),
        _bottomBar(
          primaryLabel: _isEditing ? 'Save changes' : 'Submit for review',
          onPrimary: _submitting ? null : _submit,
          secondaryLabel: 'Back',
          onSecondary: _submitting
              ? null
              : () => setState(() => _step = _JobOfferStep.compose),
          primaryExpanded: true,
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: _pagePadding(context),
            children: [
              const SizedBox(height: PortalTheme.space3),
              PortalCardShell(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: ForumTheme.needsResponseBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ForumTheme.needsResponse.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        color: ForumTheme.needsResponse,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: PortalTheme.space4),
                    Text(
                      'Awaiting review',
                      style: PortalTheme.sectionTitle.copyWith(
                        fontSize: 22,
                        color: PortalTheme.navy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your job offer is hidden from other alumni until a '
                      'community admin approves it. Find it under Awaiting '
                      'review on the forum home.',
                      style: PortalTheme.bodySecondary.copyWith(height: 1.45),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: PortalTheme.space4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PortalTheme.pageBg,
                        borderRadius:
                            BorderRadius.circular(PortalTheme.radiusLg),
                        border: Border.all(color: PortalTheme.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: PortalTheme.navy.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You’ll get a notification when it’s reviewed.',
                              style: PortalTheme.caption.copyWith(
                                color: PortalTheme.textSecondary,
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
          ),
        ),
        _bottomBar(
          primaryLabel: 'Back to forum',
          onPrimary: () => Navigator.pop(context, _submittedId),
          secondaryLabel: '',
          onSecondary: null,
          primaryExpanded: true,
          hideSecondary: true,
        ),
      ],
    );
  }

  Widget _bottomBar({
    required String primaryLabel,
    required VoidCallback? onPrimary,
    required String secondaryLabel,
    required VoidCallback? onSecondary,
    bool primaryExpanded = false,
    bool hideSecondary = false,
  }) {
    return Material(
      color: PortalTheme.card,
      elevation: 8,
      shadowColor: PortalTheme.navy.withValues(alpha: 0.1),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: PortalTheme.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (!hideSecondary)
                TextButton(
                  onPressed: onSecondary,
                  style: PortalTheme.ghostButton(dense: true),
                  child: Text(secondaryLabel),
                ),
              if (!hideSecondary) const SizedBox(width: 8),
              if (primaryExpanded)
                Expanded(
                  child: FilledButton(
                    onPressed: onPrimary,
                    style: PortalTheme.primaryButton(),
                    child: Text(primaryLabel),
                  ),
                )
              else ...[
                const Spacer(),
                FilledButton(
                  onPressed: onPrimary,
                  style: PortalTheme.primaryButton(dense: true),
                  child: Text(primaryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
