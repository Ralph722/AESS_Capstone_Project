import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/data/forum_bookmark_service.dart';
import 'package:alumni_system/features/forum/data/forum_content_moderation_service.dart';
import 'package:alumni_system/features/forum/presentation/forum_composer_page.dart';
import 'package:alumni_system/features/forum/presentation/forum_job_offer_flow_page.dart';
import 'package:alumni_system/features/forum/widgets/forum_formatted_text.dart';
import 'package:alumni_system/features/forum/widgets/forum_moderation_dialog.dart';
import 'package:alumni_system/features/forum/widgets/forum_poll_card.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_breakpoints.dart';
import 'package:alumni_system/shared/widgets/user/portal_composer.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_action_dialog.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/safe_link_text.dart';

class ForumTopicScreen extends StatefulWidget {
  const ForumTopicScreen({
    super.key,
    required this.topicId,
    this.embedded = false,
    this.onClose,
    this.onChanged,
    this.service,
  });

  final String topicId;

  /// When true, render as an in-page panel (no route AppBar / full Scaffold chrome).
  final bool embedded;
  final VoidCallback? onClose;
  final VoidCallback? onChanged;

  /// Optional override for tests.
  final ForumService? service;

  @override
  State<ForumTopicScreen> createState() => _ForumTopicScreenState();
}

class _ForumTopicScreenState extends State<ForumTopicScreen> {
  late final ForumService _forumService = widget.service ?? ForumService();
  final _moderationService = ForumContentModerationService();
  final _bookmarkService = ForumBookmarkService();
  final _authService = AuthService();
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  bool _isAdmin = false;
  bool _sending = false;
  bool _votingPoll = false;
  bool _loading = true;
  String? _error;
  ForumTopic? _topic;
  List<ForumPost> _posts = const [];
  final Set<String> _helpfulBusy = {};

  StreamSubscription<ForumTopic?>? _topicSub;
  StreamSubscription<List<ForumPost>>? _postsSub;
  Timer? _mentionDebounce;

  ForumPost? _quoting;
  List<ForumMentionCandidate> _mentionSuggestions = const [];
  final Map<String, String> _mentionNameToId = {};
  bool _showMentions = false;

  /// Cached admin check for reply authors (hide Report on admin replies).
  final Map<String, bool> _authorIsAdmin = {};

  @override
  void initState() {
    super.initState();
    _loadRole();
    _subscribe();
    _replyController.addListener(_onReplyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forumService.incrementViews(widget.topicId);
    });
  }

  @override
  void didUpdateWidget(covariant ForumTopicScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicId != widget.topicId) {
      _quoting = null;
      _mentionNameToId.clear();
      _authorIsAdmin.clear();
      _subscribe();
      _forumService.incrementViews(widget.topicId);
    }
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _topicSub?.cancel();
    _postsSub?.cancel();
    _replyController.removeListener(_onReplyChanged);
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _subscribe() {
    _topicSub?.cancel();
    _postsSub?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _topic = null;
      _posts = const [];
    });

    _topicSub = _forumService
        .watchTopic(widget.topicId)
        .listen(
          (topic) {
            if (!mounted) return;
            setState(() {
              _topic = topic;
              _loading = false;
              if (topic == null) _error = null;
            });
            widget.onChanged?.call();
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = '$e';
            });
          },
        );

    _postsSub = _forumService.watchPosts(widget.topicId).listen((posts) {
      if (!mounted) return;
      setState(() => _posts = posts);
      unawaited(_resolveAdminAuthors(posts));
    });
  }

  Future<void> _resolveAdminAuthors(List<ForumPost> posts) async {
    final pending = <String>{};
    for (final post in posts) {
      final id = post.authorUid.trim();
      if (id.isEmpty || _authorIsAdmin.containsKey(id)) continue;
      pending.add(id);
    }
    if (pending.isEmpty) return;

    // Must use is_admin_user RPC — alumni cannot SELECT other users.role under RLS,
    // so getUserRole(adminId) always looked like a normal user and Report stayed visible.
    for (final id in pending) {
      _authorIsAdmin[id] = await _authService.isAdminUserId(id);
      if (!mounted) return;
    }
    if (mounted) setState(() {});
  }

  bool _isAdminAuthor(String authorUid) {
    final id = authorUid.trim();
    if (id.isEmpty) return false;
    final topic = _topic;
    // Fast path: announcement authors are always admins.
    if (topic != null &&
        topic.isAnnouncement &&
        topic.authorUid == id) {
      return true;
    }
    return _authorIsAdmin[id] == true;
  }

  Future<void> _loadRole() async {
    final userId = AppSession.userId;
    if (userId == null) return;
    final role = await _authService.getUserRole(userId);
    if (mounted) setState(() => _isAdmin = role == UserRole.admin);
  }

  Future<void> _toggleHelpful(ForumPost post) async {
    if (_helpfulBusy.contains(post.id)) return;
    final previous = post;
    final nextHelpful = !post.helpfulByMe;
    final nextCount = (post.helpfulCount + (nextHelpful ? 1 : -1)).clamp(
      0,
      1 << 30,
    );
    setState(() {
      _helpfulBusy.add(post.id);
      _posts = [
        for (final p in _posts)
          if (p.id == post.id)
            p.copyWith(helpfulByMe: nextHelpful, helpfulCount: nextCount)
          else
            p,
      ];
    });
    try {
      await _forumService.toggleHelpful(post.id, previous.helpfulByMe);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (final p in _posts)
            if (p.id == post.id) previous else p,
        ];
      });
      showPortalErrorSnack(context, e);
    } finally {
      if (mounted) {
        setState(() => _helpfulBusy.remove(post.id));
      } else {
        _helpfulBusy.remove(post.id);
      }
    }
  }

  Future<void> _loadAll({bool silent = false}) async {
    // Kept for explicit refresh actions; streams handle live updates.
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _forumService.getTopic(widget.topicId),
        _forumService.getPosts(widget.topicId),
      ]);
      if (!mounted) return;
      setState(() {
        _topic = results[0] as ForumTopic?;
        _posts = results[1] as List<ForumPost>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _onReplyChanged() {
    final text = _replyController.text;
    final cursor = _replyController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final before = text.substring(0, cursor);
    final match = RegExp(r'@([^\s@]*)$').firstMatch(before);
    if (match == null) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final query = match.group(1) ?? '';
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 220), () async {
      final results = await _forumService.searchMentionUsers(query);
      if (!mounted) return;
      setState(() {
        _mentionSuggestions = results;
        _showMentions = results.isNotEmpty;
      });
    });
  }

  void _insertMention(ForumMentionCandidate candidate) {
    final text = _replyController.text;
    final cursor = _replyController.selection.baseOffset;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final match = RegExp(r'@([^\s@]*)$').firstMatch(before);
    if (match == null) return;
    final start = match.start;
    final inserted = '@${candidate.displayName} ';
    final next = before.substring(0, start) + inserted + after;
    _replyController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    _mentionNameToId[candidate.displayName.toLowerCase()] = candidate.id;
    setState(() => _showMentions = false);
  }

  List<String> _mentionedIdsInBody(String body) {
    final ids = <String>{};
    for (final entry in _mentionNameToId.entries) {
      if (body.toLowerCase().contains('@${entry.key}')) {
        ids.add(entry.value);
      }
    }
    return ids.toList();
  }

  /// Wraps known `@Name` mentions in bold markup for display, without showing
  /// asterisks in the composer.
  String _bodyWithBoldMentions(String body) {
    var out = body;
    final names = _mentionNameToId.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      out = out.replaceAllMapped(
        RegExp('@${RegExp.escape(name)}', caseSensitive: false),
        (match) {
          final hit = match.group(0)!;
          final start = match.start;
          final end = match.end;
          final alreadyWrapped =
              start >= 2 &&
              end + 2 <= out.length &&
              out.substring(start - 2, start) == '**' &&
              out.substring(end, end + 2) == '**';
          return alreadyWrapped ? hit : '**$hit**';
        },
      );
    }
    return out;
  }

  Future<void> _sendReply(ForumTopic topic) async {
    if (topic.isLocked || _sending) return;
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() => _sending = true);
    ForumBusyHandle? busy = showForumBusyDialog(
      context,
      'Checking your reply…',
    );
    try {
      final moderation = await _moderationService.reviewReply(
        body: text,
        topicTitle: topic.title,
      );
      await busy.close();
      busy = null;
      if (!mounted) return;
      final proceed = await showForumModerationResult(
        context,
        moderation,
        subject: 'reply',
      );
      if (!proceed || !mounted) return;
      busy = showForumBusyDialog(context, 'Publishing reply…');
      final body = _bodyWithBoldMentions(text);
      await _forumService.createPost(
        topicId: widget.topicId,
        body: body,
        quotedPostId: _quoting?.id,
        quotedExcerpt: _quoting == null
            ? null
            : ForumFormattedText.plain(_quoting!.body),
        mentionedUserIds: _mentionedIdsInBody(text),
      );
      _replyController.clear();
      setState(() {
        _quoting = null;
        _showMentions = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(portalFriendlyError(e)),
            backgroundColor: PortalTheme.danger,
          ),
        );
      }
    } finally {
      await busy?.close();
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report({String? postId}) async {
    const presets = [
      'Spam',
      'Harassment',
      'Inappropriate',
      'Off-topic',
      'Misinformation',
      'Other',
    ];
    final controller = TextEditingController(text: presets.first);
    var selected = presets.first;
    try {
      final ok = await showDialog<bool>(
        context: context,
        // Keep dialog above the soft keyboard on phones.
        useSafeArea: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              final narrow = MediaQuery.sizeOf(ctx).width < 400;
              return PortalActionDialog(
                title: postId == null ? 'Report discussion?' : 'Report reply?',
                message:
                    'Choose a reason. Reports help moderators keep the '
                    'community safe.',
                body: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in presets)
                          ChoiceChip(
                            label: Text(p),
                            selected: selected == p,
                            visualDensity: narrow
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                            selectedColor:
                                PortalTheme.navy.withValues(alpha: 0.12),
                            labelStyle: TextStyle(
                              color: selected == p
                                  ? PortalTheme.navy
                                  : PortalTheme.textPrimary,
                              fontWeight: selected == p
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: selected == p
                                  ? PortalTheme.navy.withValues(alpha: 0.35)
                                  : PortalTheme.border,
                            ),
                            onSelected: (_) => setLocal(() {
                              selected = p;
                              if (p != 'Other') controller.text = p;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      // One fewer lines on narrow phones so the field stays
                      // visible with the keyboard open; content still scrolls.
                      maxLines: narrow ? 2 : 3,
                      minLines: 2,
                      // Keep the focused field above the keyboard while scrolling.
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      style: PortalTheme.body,
                      decoration: InputDecoration(
                        labelText: 'Details',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: PortalTheme.pageBg,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTheme.radiusLg),
                          borderSide: const BorderSide(color: PortalTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTheme.radiusLg),
                          borderSide: const BorderSide(color: PortalTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTheme.radiusLg),
                          borderSide: const BorderSide(
                            color: PortalTheme.navy,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: PortalMenu.dangerButton(dense: false),
                    child: const Text('Submit report'),
                  ),
                  TextButton(
                    style: PortalActionDialog.quietButton(),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        },
      );
      final reason = controller.text.trim().isEmpty
          ? selected
          : controller.text.trim();
      if (ok != true) return;
      try {
        await _forumService.reportContent(
          topicId: widget.topicId,
          postId: postId,
          reason: reason,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. Thank you.')),
          );
        }
      } catch (e) {
        if (mounted) showPortalErrorSnack(context, e);
      }
    } finally {
      // Dispose after the dialog exit animation finishes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  Future<void> _toggleBookmark(ForumTopic topic) async {
    try {
      await _bookmarkService.toggleBookmark(topic.id, topic.isBookmarked);
      await _loadAll(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              topic.isBookmarked ? 'Bookmark removed' : 'Discussion saved',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showPortalErrorSnack(context, e);
    }
  }

  Future<void> _votePoll(ForumTopic topic, String optionId) async {
    if (_votingPoll || topic.isLocked) return;
    if (topic.pollSummary?.myOptionId == optionId) return;
    setState(() => _votingPoll = true);
    try {
      final summary = await _forumService.votePoll(
        topicId: topic.id,
        optionId: optionId,
      );
      if (!mounted) return;
      setState(() {
        _topic = topic.copyWith(pollSummary: summary);
      });
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) showPortalErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _votingPoll = false);
    }
  }

  Future<void> _editTopic(ForumTopic topic) async {
    if (topic.isJobOffer) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForumJobOfferFlowPage(editTopic: topic),
        ),
      );
      await _loadAll(silent: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForumComposerPage(editTopic: topic)),
    );
    if (mounted) await _loadAll(silent: true);
  }

  Future<void> _editPost(ForumPost post) async {
    final controller = TextEditingController(text: post.body);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => PortalActionDialog(
          title: 'Edit reply?',
          message: 'Update your reply. Changes are visible to everyone.',
          body: TextField(
            controller: controller,
            maxLines: 6,
            style: PortalTheme.body,
            decoration: InputDecoration(
              labelText: 'Reply',
              alignLabelWithHint: true,
              filled: true,
              fillColor: PortalTheme.pageBg,
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
                borderSide: const BorderSide(
                  color: PortalTheme.navy,
                  width: 1.4,
                ),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: PortalTheme.primaryButton(),
              child: const Text('Save'),
            ),
            TextButton(
              style: PortalActionDialog.quietButton(),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final moderation = await _moderationService.reviewReply(
        body: controller.text,
        topicTitle: _topic?.title,
      );
      if (!mounted) return;
      final proceed = await showForumModerationResult(
        context,
        moderation,
        subject: 'reply',
      );
      if (!proceed || !mounted) return;
      await _forumService.editPost(postId: post.id, body: controller.text);
      await _loadAll(silent: true);
    } catch (e) {
      if (mounted) showPortalErrorSnack(context, e);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.userId;
    final body = _buildBody(uid);

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEmbeddedHeader(),
          Expanded(
            child: ColoredBox(color: AdminColors.background, child: body),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: ForumTheme.pageBg,
      appBar: PortalAppBar(
        title: 'Discussion',
        subtitle: _topic?.title.trim().isNotEmpty == true
            ? _topic!.title
            : null,
        actions: [
          PortalHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () => _loadAll(),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildEmbeddedHeader() {
    final title = _topic?.title.trim().isNotEmpty == true
        ? _topic!.title.trim()
        : 'Discussion';
    final isAnnouncement = _topic?.isAnnouncement ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        return Container(
          decoration: const BoxDecoration(
            color: AdminColors.card,
            border: Border(bottom: BorderSide(color: AdminColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              if (wide)
                Tooltip(
                  message: 'Back to forum list',
                  child: OutlinedButton.icon(
                    onPressed: widget.onClose,
                    style: AdminButtonStyles.outlined(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 17),
                    label: const Text('Back'),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Back to forum list',
                  onPressed: widget.onClose,
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminColors.textPrimary,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AdminColors.infoBg,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
                child: Icon(
                  isAnnouncement
                      ? Icons.campaign_outlined
                      : Icons.forum_outlined,
                  size: 18,
                  color: AdminColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    Text(
                      isAnnouncement
                          ? 'Announcement thread'
                          : 'Forum discussion',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : () => _loadAll(),
                style: AdminDensity.iconButtonStyle(
                  foregroundColor: AdminColors.textSecondary,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 19),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(String? uid) {
    if (_loading && _topic == null) {
      return const PortalDetailSkeleton();
    }
    if (_error != null && _topic == null) {
      return ForumErrorState(message: _error!, onRetry: () => _loadAll());
    }
    final topic = _topic;
    if (topic == null) {
      return ForumEmptyState(
        icon: Icons.search_off,
        title: 'Topic not found',
        subtitle: 'It may have been deleted or moved.',
        actionLabel: widget.embedded ? 'Back to list' : 'Go back',
        onAction: () {
          if (widget.embedded) {
            widget.onClose?.call();
          } else {
            Navigator.pop(context);
          }
        },
      );
    }

    final canModerate = _isAdmin;
    final isOwner = topic.authorUid == uid;
    final canEditTopic = topic.isJobOffer
        ? isOwner &&
              (topic.isPendingJobOffer || topic.isApprovedJobOffer)
        : (isOwner || _isAdmin) && topic.canEditWithinWindow;
    final canWithdrawJob =
        isOwner && topic.isJobOffer && topic.isJobOfferInReviewQueue;
    final canSolve =
        (isOwner || _isAdmin) &&
        !topic.isAnnouncement &&
        !topic.isJobOffer &&
        (topic.hasQuestionTag || topic.isSolved);
    final canDelete = _isAdmin || (isOwner && !topic.isJobOfferInReviewQueue);
    final canReportTopic = !isOwner && !topic.isAnnouncement;

    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = PortalBreakpoints.centeredInset(constraints.maxWidth);
        return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              inset,
              PortalTheme.space3,
              inset,
              PortalTheme.space2,
            ),
            children: [
              if (topic.isJobOfferInReviewQueue) ...[
                _buildJobOfferReviewBanner(topic),
                const SizedBox(height: PortalTheme.space3),
              ],
              _buildTopicHero(
                topic,
                canEdit: canEditTopic,
                canDelete: canDelete,
                canSolve: canSolve,
                canModerate: canModerate,
                canReport: canReportTopic,
                canWithdrawJob: canWithdrawJob,
              ),
              const SizedBox(height: PortalTheme.space4),
              if (!topic.isJobOfferInReviewQueue) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: PortalTheme.space2),
                  child: Text(
                    'Replies (${_posts.length})',
                    style: PortalTheme.sectionTitle.copyWith(fontSize: 16),
                  ),
                ),
                if (_posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: PortalTheme.space3),
                    child: ForumEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No replies yet',
                      subtitle: 'Be the first to share a helpful response.',
                      compact: true,
                    ),
                  )
                else
                  ..._posts.map((p) => _buildPostCard(p, uid, topic)),
              ],
            ],
          ),
        ),
        if (!topic.isLocked && !topic.isJobOfferInReviewQueue)
          _buildReplyBar(topic),
        // Pending job offers already explain the lock in the top review banner.
        if (topic.isLocked && !topic.isJobOfferInReviewQueue)
          _buildLockedBanner(topic, inset),
      ],
    );
      },
    );
  }

  Widget _buildLockedBanner(ForumTopic topic, double inset) {
    final message = topic.moderationReason?.isNotEmpty == true
        ? 'This topic is locked. ${topic.moderationReason}'
        : 'This topic is locked. No new replies can be added.';
    return PortalHighlightPanel(
      variant: PortalHighlightVariant.attention,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: inset + 4,
        vertical: PortalTheme.space3,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_rounded,
            color: ForumTheme.pinned,
            size: 20,
          ),
          const SizedBox(width: PortalTheme.space2),
          Expanded(
            child: Text(
              message,
              style: PortalTheme.body.copyWith(
                fontWeight: FontWeight.w600,
                color: ForumTheme.pinned,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobOfferReviewBanner(ForumTopic topic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ForumTheme.needsResponseBg,
        borderRadius: BorderRadius.circular(ForumTheme.radius),
        border: Border.all(
          color: ForumTheme.needsResponse.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Awaiting review',
            style: PortalTheme.meta.copyWith(
              fontWeight: FontWeight.w800,
              color: ForumTheme.needsResponse,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Only you and community admins can see this until it is approved. '
            'Replies open after approval.',
            style: PortalTheme.bodySecondary.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawJobOffer(ForumTopic topic) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: PortalMenu.dialogShape,
        title: const Text('Withdraw job offer?'),
        content: const Text(
          'This removes your submission from the review queue. You can share a new offer later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: PortalTheme.ghostButton(dense: true),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: PortalMenu.dangerButton(),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final busy = showForumBusyDialog(context, 'Withdrawing…');
    try {
      await _forumService.withdrawJobOffer(topic.id);
      if (!mounted) return;
      if (widget.embedded) {
        widget.onChanged?.call();
        widget.onClose?.call();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showPortalErrorSnack(context, e);
    } finally {
      await busy.close();
    }
  }

  void _startQuote(ForumPost post) {
    final name = post.authorName.trim().isEmpty
        ? 'Alumni'
        : post.authorName.trim();
    final mention = '@$name ';
    final current = _replyController.text;
    if (!current.toLowerCase().contains('@${name.toLowerCase()}')) {
      _replyController.value = TextEditingValue(
        text: '$mention$current',
        selection: TextSelection.collapsed(offset: mention.length),
      );
    }
    if (post.authorUid.trim().isNotEmpty) {
      _mentionNameToId[name.toLowerCase()] = post.authorUid;
    }
    setState(() => _quoting = post);
    _replyFocus.requestFocus();
  }

  void _cancelQuote() {
    final quoted = _quoting;
    final name = quoted == null
        ? ''
        : (quoted.authorName.trim().isEmpty
              ? 'Alumni'
              : quoted.authorName.trim());
    final prefix = name.isEmpty ? '' : '@$name ';
    final text = _replyController.text;
    if (prefix.isNotEmpty && text.startsWith(prefix)) {
      _replyController.value = TextEditingValue(
        text: text.substring(prefix.length),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    setState(() => _quoting = null);
  }

  Widget _buildTopicHero(
    ForumTopic topic, {
    required bool canEdit,
    required bool canDelete,
    required bool canSolve,
    required bool canModerate,
    required bool canReport,
    bool canWithdrawJob = false,
  }) {
    final meta = topic.isAnnouncement
        ? 'Community Admin'
        : <String>[
            if (topic.authorProgram.isNotEmpty) topic.authorProgram,
            if (topic.authorBatch.isNotEmpty) 'Batch ${topic.authorBatch}',
          ].join(' · ');

    final timeLabel = DateFormat.yMMMd().add_jm().format(topic.createdAt);
    final edited = topic.editedAt != null;
    final menuItems = <PopupMenuEntry<String>>[
      if (canReport)
        portalMenuItem(
          value: 'report',
          label: 'Report',
          icon: Icons.flag_outlined,
        ),
      if (canEdit)
        portalMenuItem(
          value: 'edit',
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
      if (canModerate && !topic.isJobOfferInReviewQueue) ...[
        portalMenuItem(
          value: 'lock',
          label: topic.isLocked ? 'Unlock' : 'Lock',
          icon: topic.isLocked
              ? Icons.lock_open_rounded
              : Icons.lock_outline,
        ),
        portalMenuItem(
          value: 'pin',
          label: topic.isPinned ? 'Unpin' : 'Pin',
          icon: Icons.push_pin_outlined,
        ),
      ],
      if (canWithdrawJob)
        portalMenuItem(
          value: 'withdraw',
          label: 'Withdraw',
          icon: Icons.undo_rounded,
          destructive: true,
        ),
      if (canDelete)
        portalMenuItem(
          value: 'delete',
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
    ];

    return PortalHighlightPanel(
      variant: topic.isAnnouncement
          ? PortalHighlightVariant.goldEdge
          : PortalHighlightVariant.soft,
      padding: const EdgeInsets.all(PortalTheme.space4),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: topic.isAnnouncement
                    ? ForumTheme.announcementBg
                    : ForumTheme.navy.withValues(alpha: 0.08),
                backgroundImage: () {
                  final url = topic.authorAvatarUrl?.trim() ?? '';
                  if (url.isEmpty) return null;
                  return AppImage.provider(url);
                }(),
                child: (topic.authorAvatarUrl?.trim().isNotEmpty ?? false)
                    ? null
                    : Text(
                        topic.authorName.isNotEmpty
                            ? topic.authorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: topic.isAnnouncement
                              ? ForumTheme.announcement
                              : ForumTheme.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
              const SizedBox(width: PortalTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.authorName.trim().isEmpty
                          ? 'Alumni'
                          : topic.authorName.trim(),
                      style: PortalTheme.meta.copyWith(
                        color: ForumTheme.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta, style: PortalTheme.caption),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ForumTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        edited ? '$timeLabel · Edited' : timeLabel,
                        style: PortalTheme.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (menuItems.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onSelected: (value) async {
                    switch (value) {
                      case 'report':
                        await _report();
                      case 'edit':
                        await _editTopic(topic);
                      case 'lock':
                        final reason = topic.isLocked
                            ? ''
                            : await showForumModerationReasonDialog(
                                context,
                                title: 'Lock topic',
                                confirmLabel: 'Lock',
                              );
                        if (reason == null && !topic.isLocked) return;
                        await _forumService.setTopicLocked(
                          topic.id,
                          !topic.isLocked,
                          reason: topic.isLocked ? null : reason,
                        );
                        await _loadAll(silent: true);
                      case 'pin':
                        await _forumService.setTopicPinned(
                          topic.id,
                          !topic.isPinned,
                        );
                        await _loadAll(silent: true);
                      case 'withdraw':
                        await _withdrawJobOffer(topic);
                      case 'delete':
                        await _confirmDeleteTopic(topic);
                    }
                  },
                  itemBuilder: (ctx) => menuItems,
                ),
            ],
          ),
          if (topic.isJobOffer && topic.coverImageUrl.trim().isNotEmpty) ...[
            const SizedBox(height: PortalTheme.space3),
            ClipRRect(
              borderRadius: BorderRadius.circular(ForumTheme.radius),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AppImage.widget(
                    topic.coverImageUrl,
                    width: constraints.maxWidth,
                    fit: BoxFit.fitWidth,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: PortalTheme.space3),
          Text(
            topic.title,
            style: PortalTheme.sectionTitle.copyWith(
              fontSize: 20,
              color: ForumTheme.navy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: PortalTheme.space2),
          ForumStatusChipRow(topic: topic),
          if (topic.tags.isNotEmpty) ...[
            const SizedBox(height: PortalTheme.space2),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: topic.tags
                  .map((t) => ForumTagChip(label: t.label))
                  .toList(),
            ),
          ],
          const SizedBox(height: PortalTheme.space3),
          if (topic.body.trim().isNotEmpty)
            ForumFormattedText(
              topic.body,
              style: PortalTheme.body.copyWith(fontSize: 15, height: 1.5),
            ),
          if (topic.isPoll) ...[
            if (topic.body.trim().isNotEmpty)
              const SizedBox(height: PortalTheme.space3),
            if (topic.pollSummary != null)
              ForumPollCard(
                summary: topic.pollSummary!,
                voting: _votingPoll,
                enabled: !topic.isLocked,
                onVote: (optionId) => _votePoll(topic, optionId),
              )
            else
              Text(
                'Loading poll options…',
                style: PortalTheme.caption.copyWith(
                  color: ForumTheme.textSecondary,
                ),
              ),
          ],
          if (topic.isJobOffer && topic.applyUrl.trim().isNotEmpty) ...[
            const SizedBox(height: PortalTheme.space3),
            Align(
              alignment: Alignment.centerLeft,
              child: SafeLinkText(
                topic.applyUrl.trim(),
                style: PortalTheme.body.copyWith(
                  color: ForumTheme.navy,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          const SizedBox(height: PortalTheme.space2),
          Wrap(
            spacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: topic.isBookmarked ? 'Remove bookmark' : 'Bookmark',
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleBookmark(topic),
                icon: Icon(
                  topic.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: ForumTheme.navy,
                ),
              ),
              IconButton(
                tooltip: 'Copy link',
                visualDensity: VisualDensity.compact,
                onPressed: () => copyForumTopicLink(context, topic.id),
                icon: const Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: ForumTheme.navy,
                ),
              ),
              if (canSolve)
                TextButton.icon(
                  style: PortalTheme.ghostButton(dense: true),
                  onPressed: () async {
                    await _forumService.setTopicSolved(
                      topic.id,
                      !topic.isSolved,
                    );
                    await _loadAll(silent: true);
                  },
                  icon: Icon(
                    topic.isSolved
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(topic.isSolved ? 'Solved' : 'Mark solved'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(ForumPost post, String? uid, ForumTopic topic) {
    final canDelete = _isAdmin || post.authorUid == uid;
    final canEdit =
        (post.authorUid == uid || _isAdmin) && post.canEditWithinWindow;
    final canReportReply =
        post.authorUid != uid && !_isAdminAuthor(post.authorUid);
    final timeLabel = DateFormat.yMMMd().add_jm().format(post.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: PortalTheme.space2),
      child: Material(
        color: ForumTheme.card,
        elevation: 1,
        shadowColor: ForumTheme.navy.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ForumTheme.radius2xl),
          side: BorderSide(color: ForumTheme.border.withValues(alpha: 0.75)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PortalTheme.space3,
            PortalTheme.space3,
            PortalTheme.space2,
            PortalTheme.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: ForumTheme.navy.withValues(alpha: 0.08),
                    backgroundImage: () {
                      final url = post.authorAvatarUrl?.trim() ?? '';
                      if (url.isEmpty) return null;
                      return AppImage.provider(url);
                    }(),
                    child: (post.authorAvatarUrl?.trim().isNotEmpty ?? false)
                        ? null
                        : Text(
                            post.authorName.isNotEmpty
                                ? post.authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: ForumTheme.navy,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName.trim().isEmpty
                              ? 'Alumni'
                              : post.authorName.trim(),
                          style: PortalTheme.meta.copyWith(
                            color: ForumTheme.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ForumTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            post.editedAt != null
                                ? '$timeLabel · Edited'
                                : timeLabel,
                            style: PortalTheme.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onSelected: (v) async {
                      switch (v) {
                        case 'quote':
                          _startQuote(post);
                        case 'report':
                          await _report(postId: post.id);
                        case 'edit':
                          await _editPost(post);
                        case 'delete':
                          await _forumService.deletePost(
                            widget.topicId,
                            post.id,
                          );
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (!topic.isLocked)
                        portalMenuItem(
                          value: 'quote',
                          label: 'Quote reply',
                          icon: Icons.format_quote_rounded,
                        ),
                      if (canReportReply)
                        portalMenuItem(
                          value: 'report',
                          label: 'Report',
                          icon: Icons.flag_outlined,
                        ),
                      if (canEdit)
                        portalMenuItem(
                          value: 'edit',
                          label: 'Edit',
                          icon: Icons.edit_outlined,
                        ),
                      if (canDelete)
                        portalMenuItem(
                          value: 'delete',
                          label: 'Delete',
                          icon: Icons.delete_outline_rounded,
                          destructive: true,
                        ),
                    ],
                  ),
                ],
              ),
              if (post.quotedExcerpt?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ForumTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
                    border: Border.all(
                      color: ForumTheme.border.withValues(alpha: 0.75),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ColoredBox(
                            color: ForumTheme.navy,
                            child: SizedBox(width: 3),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: SafeLinkText(
                                ForumFormattedText.plain(post.quotedExcerpt!),
                                style: PortalTheme.caption.copyWith(
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ForumFormattedText(
                post.body,
                style: PortalTheme.body.copyWith(fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _helpfulBusy.contains(post.id)
                        ? null
                        : () => _toggleHelpful(post),
                    icon: Icon(
                      post.helpfulByMe
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      size: 15,
                      color: post.helpfulByMe
                          ? ForumTheme.navy
                          : ForumTheme.textSecondary,
                    ),
                    label: Text(
                      post.helpfulCount == 0
                          ? 'Helpful'
                          : 'Helpful · ${post.helpfulCount}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: post.helpfulByMe
                            ? ForumTheme.navy
                            : ForumTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!topic.isLocked)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _startQuote(post),
                      child: const Text(
                        'Quote',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBar(ForumTopic topic) {
    return PortalComposerBar(
      maxWidth: PortalBreakpoints.contentMax,
      child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_quoting != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: PortalTheme.space2),
                  decoration: BoxDecoration(
                    color: ForumTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
                    border: Border.all(
                      color: ForumTheme.border.withValues(alpha: 0.75),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ColoredBox(
                            color: ForumTheme.navy,
                            child: SizedBox(width: 3),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Quoting ${_quoting!.authorName}: '
                                      '${ForumFormattedText.plain(_quoting!.body)}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: PortalTheme.caption,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Cancel quote',
                                    onPressed: _cancelQuote,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_showMentions)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 160),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
                    border: Border.all(
                      color: ForumTheme.border.withValues(alpha: 0.75),
                    ),
                    boxShadow: ForumTheme.softShadow,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mentionSuggestions.length,
                    itemBuilder: (context, index) {
                      final c = _mentionSuggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(c.displayName),
                        subtitle: c.program.isEmpty ? null : Text(c.program),
                        onTap: () => _insertMention(c),
                      );
                    },
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocus,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      style: PortalTheme.body,
                      decoration: PortalComposer.inputDecoration(
                        hintText: 'Write a reply… Use @ to mention',
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: PortalComposer.gap),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _replyController,
                    builder: (context, value, _) => PortalSendButton(
                      label: 'Send reply',
                      busy: _sending,
                      onPressed: value.text.trim().isNotEmpty
                          ? () => _sendReply(topic)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDeleteTopic(ForumTopic topic) async {
    String? reason;
    if (_isAdmin) {
      reason = await showForumModerationReasonDialog(
        context,
        title: 'Delete topic?',
        confirmLabel: 'Continue',
      );
      if (reason == null) return;
    }
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete topic?'),
        content: const Text('All replies will be removed.'),
        actions: [
          TextButton(
            style: PortalTheme.ghostButton(dense: true),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: PortalMenu.dangerButton(dense: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _forumService.deleteTopic(widget.topicId, reason: reason);
      widget.onChanged?.call();
      if (!mounted) return;
      if (widget.embedded) {
        widget.onClose?.call();
      } else {
        Navigator.pop(context);
      }
    }
  }
}
