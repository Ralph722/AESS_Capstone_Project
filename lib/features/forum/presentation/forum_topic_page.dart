import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/data/forum_bookmark_service.dart';
import 'package:alumni_system/features/forum/presentation/forum_composer_page.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_headers.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';
import 'package:alumni_system/shared/widgets/safe_link_text.dart';

class ForumTopicScreen extends StatefulWidget {
  const ForumTopicScreen({
    super.key,
    required this.topicId,
    this.embedded = false,
    this.onClose,
    this.onChanged,
  });

  final String topicId;

  /// When true, render as an in-page panel (no route AppBar / full Scaffold chrome).
  final bool embedded;
  final VoidCallback? onClose;
  final VoidCallback? onChanged;

  @override
  State<ForumTopicScreen> createState() => _ForumTopicScreenState();
}

class _ForumTopicScreenState extends State<ForumTopicScreen> {
  final _forumService = ForumService();
  final _bookmarkService = ForumBookmarkService();
  final _authService = AuthService();
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  bool _isAdmin = false;
  bool _sending = false;
  bool _loading = true;
  String? _error;
  ForumTopic? _topic;
  List<ForumPost> _posts = const [];

  StreamSubscription<ForumTopic?>? _topicSub;
  StreamSubscription<List<ForumPost>>? _postsSub;
  Timer? _mentionDebounce;

  ForumPost? _quoting;
  List<ForumMentionCandidate> _mentionSuggestions = const [];
  final Map<String, String> _mentionNameToId = {};
  bool _showMentions = false;

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

    _topicSub = _forumService.watchTopic(widget.topicId).listen(
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

    _postsSub = _forumService.watchPosts(widget.topicId).listen(
      (posts) {
        if (!mounted) return;
        setState(() => _posts = posts);
      },
    );
  }

  Future<void> _loadRole() async {
    final userId = AppSession.userId;
    if (userId == null) return;
    final role = await _authService.getUserRole(userId);
    if (mounted) setState(() => _isAdmin = role == UserRole.admin);
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

  Future<void> _sendReply(ForumTopic topic) async {
    if (topic.isLocked || _sending) return;
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await _forumService.createPost(
        topicId: widget.topicId,
        body: text,
        quotedPostId: _quoting?.id,
        quotedExcerpt: _quoting?.body,
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
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
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
    final controller = TextEditingController();
    String selected = presets.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(postId == null ? 'Report discussion' : 'Report reply'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets
                          .map(
                            (p) => ChoiceChip(
                              label: Text(p),
                              selected: selected == p,
                              onSelected: (_) => setLocal(() {
                                selected = p;
                                if (p != 'Other') controller.text = p;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Details',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: ForumTheme.navy,
                  ),
                  child: const Text('Submit report'),
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
    controller.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editTopic(ForumTopic topic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumComposerPage(editTopic: topic),
      ),
    );
    if (mounted) await _loadAll(silent: true);
  }

  Future<void> _editPost(ForumPost post) async {
    final controller = TextEditingController(text: post.body);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit reply'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Reply',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ForumTheme.navy),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) {
      controller.dispose();
      return;
    }
    try {
      await _forumService.editPost(postId: post.id, body: controller.text);
      await _loadAll(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      controller.dispose();
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
            child: ColoredBox(
              color: ForumTheme.pageBg,
              child: body,
            ),
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
        ? _topic!.title
        : 'Discussion';
    return PortalAppBar(
      primary: false,
      title: title,
      subtitle: 'Forum discussion',
      leading: IconButton(
        tooltip: 'Back to forum list',
        onPressed: widget.onClose,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      automaticallyImplyLeading: false,
      actions: [
        PortalHeaderAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: () => _loadAll(),
        ),
      ],
    );
  }

  Widget _buildBody(String? uid) {
    if (_loading && _topic == null) {
      return const FeedbackDetailSkeleton();
    }
    if (_error != null && _topic == null) {
      return ForumErrorState(
        message: _error!,
        onRetry: () => _loadAll(),
      );
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
    final canEditTopic = (isOwner || _isAdmin) && topic.canEditWithinWindow;
    final canSolve = (isOwner || _isAdmin) && !topic.isAnnouncement;
    final canDelete = _isAdmin || isOwner;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              PortalTheme.space3,
              PortalTheme.space3,
              PortalTheme.space3,
              PortalTheme.space2,
            ),
            children: [
              _buildTopicHero(
                topic,
                canEdit: canEditTopic,
                canDelete: canDelete,
                canSolve: canSolve,
                canModerate: canModerate,
              ),
              const SizedBox(height: PortalTheme.space4),
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
          ),
        ),
        if (!topic.isLocked) _buildReplyBar(topic),
        if (topic.isLocked) _buildLockedBanner(topic),
      ],
    );
  }

  Widget _buildLockedBanner(ForumTopic topic) {
    return PortalHighlightPanel(
      variant: PortalHighlightVariant.attention,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: PortalTheme.space4,
        vertical: PortalTheme.space3,
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: ForumTheme.pinned, size: 20),
          const SizedBox(width: PortalTheme.space2),
          Expanded(
            child: Text(
              topic.moderationReason?.isNotEmpty == true
                  ? 'This topic is locked. ${topic.moderationReason}'
                  : 'This topic is locked. No new replies can be added.',
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

  Widget _buildTopicHero(
    ForumTopic topic, {
    required bool canEdit,
    required bool canDelete,
    required bool canSolve,
    required bool canModerate,
  }) {
    final meta = <String>[
      if (topic.authorProgram.isNotEmpty) topic.authorProgram,
      if (topic.authorBatch.isNotEmpty) 'Batch ${topic.authorBatch}',
    ].join(' · ');

    final timeLabel = DateFormat.yMMMd().add_jm().format(topic.createdAt);
    final edited = topic.editedAt != null;

    return PortalHighlightPanel(
      variant: topic.isAnnouncement
          ? PortalHighlightVariant.goldEdge
          : PortalHighlightVariant.soft,
      padding: const EdgeInsets.all(PortalTheme.space4),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topic.isAnnouncement)
            Padding(
              padding: const EdgeInsets.only(bottom: PortalTheme.space2),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign_outlined,
                    size: 16,
                    color: ForumTheme.announcement,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Official announcement',
                    style: PortalTheme.caption.copyWith(
                      color: ForumTheme.announcement,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
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
              PopupMenuButton<String>(
                tooltip: 'Actions',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                onSelected: (value) async {
                  switch (value) {
                    case 'bookmark':
                      await _toggleBookmark(topic);
                    case 'copy':
                      await copyForumTopicLink(context, topic.id);
                    case 'report':
                      await _report();
                    case 'edit':
                      await _editTopic(topic);
                    case 'solved':
                      await _forumService.setTopicSolved(
                        topic.id,
                        !topic.isSolved,
                      );
                      await _loadAll(silent: true);
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
                    case 'delete':
                      await _confirmDeleteTopic(topic);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'bookmark',
                    child: Text(
                      topic.isBookmarked ? 'Remove bookmark' : 'Bookmark',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Text('Copy link'),
                  ),
                  const PopupMenuItem(
                    value: 'report',
                    child: Text('Report'),
                  ),
                  if (canEdit)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                  if (canSolve)
                    PopupMenuItem(
                      value: 'solved',
                      child: Text(
                        topic.isSolved ? 'Unmark solved' : 'Mark solved',
                      ),
                    ),
                  if (canModerate) ...[
                    PopupMenuItem(
                      value: 'lock',
                      child: Text(topic.isLocked ? 'Unlock' : 'Lock'),
                    ),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(topic.isPinned ? 'Unpin' : 'Pin'),
                    ),
                  ],
                  if (canDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ],
          ),
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
              children:
                  topic.tags.map((t) => ForumTagChip(label: t.label)).toList(),
            ),
          ],
          const SizedBox(height: PortalTheme.space3),
          SafeLinkText(
            topic.body,
            style: PortalTheme.body.copyWith(fontSize: 15, height: 1.5),
          ),
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
                          setState(() => _quoting = post);
                          _replyFocus.requestFocus();
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
                        const PopupMenuItem(
                          value: 'quote',
                          child: Text('Quote reply'),
                        ),
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Report'),
                      ),
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                      if (canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (post.quotedExcerpt?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ForumTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
                    border: const Border(
                      left: BorderSide(color: ForumTheme.navy, width: 3),
                    ),
                  ),
                  child: SafeLinkText(
                    post.quotedExcerpt!,
                    style: PortalTheme.caption.copyWith(height: 1.35),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SafeLinkText(
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
                    onPressed: () => _forumService.toggleHelpful(
                      post.id,
                      post.helpfulByMe,
                    ),
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
                      onPressed: () {
                        setState(() => _quoting = post);
                        _replyFocus.requestFocus();
                      },
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
    return Material(
      elevation: 2,
      shadowColor: ForumTheme.navy.withValues(alpha: 0.08),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PortalTheme.space3,
            PortalTheme.space2,
            PortalTheme.space3,
            PortalTheme.space2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_quoting != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: PortalTheme.space2),
                  padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                  decoration: BoxDecoration(
                    color: ForumTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(ForumTheme.radiusXl),
                    border: const Border(
                      left: BorderSide(color: ForumTheme.navy, width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Quoting ${_quoting!.authorName}: ${_quoting!.body}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PortalTheme.caption,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel quote',
                        onPressed: () => setState(() => _quoting = null),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
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
                      decoration: InputDecoration(
                        hintText: 'Write a reply… Use @ to mention',
                        hintStyle: PortalTheme.bodySecondary,
                        filled: true,
                        fillColor: ForumTheme.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTheme.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTheme.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PortalTheme.radiusMd),
                          borderSide: const BorderSide(
                            color: ForumTheme.navy,
                            width: 1.2,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: PortalTheme.space2),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _replyController,
                    builder: (context, value, _) {
                      final canSend =
                          !_sending && value.text.trim().isNotEmpty;
                      return FilledButton(
                        onPressed: canSend ? () => _sendReply(topic) : null,
                        style: PortalTheme.primaryButton(dense: true).copyWith(
                          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(PortalTheme.radiusMd),
                            ),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _forumService.deleteTopic(
        widget.topicId,
        reason: reason,
      );
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
