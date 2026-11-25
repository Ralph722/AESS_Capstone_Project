import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/forum/widgets/admin_forum_ui.dart';
import 'package:alumni_system/features/forum/data/forum_service.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/forum/widgets/forum_formatted_text.dart';
import 'package:alumni_system/features/forum/widgets/forum_ui.dart';
import 'package:alumni_system/features/share/share_link_sheet.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_tab_bar.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/safe_link_text.dart';

/// Opens a forum topic in the admin side panel (Events-style), not the alumni UI.
Future<void> showAdminForumTopicDetail({
  required BuildContext context,
  required String topicId,
  required VoidCallback onChanged,
  ForumService? service,
  ForumTopic? initialTopic,
}) {
  final child = AdminForumTopicPanel(
    topicId: topicId,
    onChanged: onChanged,
    service: service,
    initialTopic: initialTopic,
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
    maxWidth: 720,
    maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: child,
    ),
  );
}

class AdminForumTopicPanel extends StatefulWidget {
  const AdminForumTopicPanel({
    super.key,
    required this.topicId,
    required this.onChanged,
    this.service,
    this.initialTopic,
  });

  final String topicId;
  final VoidCallback onChanged;
  final ForumService? service;
  final ForumTopic? initialTopic;

  @override
  State<AdminForumTopicPanel> createState() => _AdminForumTopicPanelState();
}

class _AdminForumTopicPanelState extends State<AdminForumTopicPanel>
    with SingleTickerProviderStateMixin {
  static const double _replyComposerHeight = 48;

  late final ForumService _forumService = widget.service ?? ForumService();
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  ForumTopic? _topic;
  List<ForumPost> _posts = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;
  bool _sendingReply = false;
  final Set<String> _busyPostIds = {};
  ForumPost? _quoting;

  late final TabController _jobTabs = TabController(length: 2, vsync: this);

  StreamSubscription<ForumTopic?>? _topicSub;
  StreamSubscription<List<ForumPost>>? _postsSub;

  @override
  void initState() {
    super.initState();
    _topic = widget.initialTopic;
    _bind();
  }

  @override
  void dispose() {
    _topicSub?.cancel();
    _postsSub?.cancel();
    _replyController.dispose();
    _replyFocus.dispose();
    _jobTabs.dispose();
    super.dispose();
  }

  void _bind() {
    _topicSub?.cancel();
    _postsSub?.cancel();
    setState(() {
      _loading = _topic == null;
      _error = null;
    });
    _topicSub = _forumService.watchTopic(widget.topicId).listen((topic) {
      if (!mounted) return;
      setState(() {
        _topic = topic;
        _loading = false;
        if (topic == null) _error = 'Topic not found';
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    });
    _postsSub = _forumService.watchPosts(widget.topicId).listen((posts) {
      if (!mounted) return;
      setState(() => _posts = posts);
    }, onError: (_) {});
  }

  void _notifyChanged() {
    widget.onChanged();
    ForumService.notifyTopicsChanged();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _notifyChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(forumFriendlyError(e, 'Action failed.')),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLock() async {
    final topic = _topic;
    if (topic == null) return;
    final reason = topic.isLocked
        ? ''
        : await showForumModerationReasonDialog(
            context,
            title: 'Lock topic',
            confirmLabel: 'Lock',
          );
    if (!mounted) return;
    if (!topic.isLocked && reason == null) return;
    await _runBusy(
      () => _forumService.setTopicLocked(
        topic.id,
        !topic.isLocked,
        reason: topic.isLocked ? null : reason,
      ),
    );
  }

  Future<void> _togglePin() async {
    final topic = _topic;
    if (topic == null) return;
    await _runBusy(
      () => _forumService.setTopicPinned(topic.id, !topic.isPinned),
    );
  }

  Future<void> _toggleSolved() async {
    final topic = _topic;
    if (topic == null || topic.isAnnouncement || topic.isJobOffer) return;
    await _runBusy(
      () => _forumService.setTopicSolved(topic.id, !topic.isSolved),
    );
  }

  Future<void> _deleteTopic() async {
    final topic = _topic;
    if (topic == null) return;
    final ok = await showAdminConfirmDialog(
      context,
      title: 'Delete topic?',
      message:
          '"${topic.title}" and all replies will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final reason = await showForumModerationReasonDialog(
      context,
      title: 'Delete topic',
      confirmLabel: 'Delete',
    );
    if (!mounted || reason == null) return;
    await _runBusy(() async {
      await _forumService.deleteTopic(topic.id, reason: reason);
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _approveJobOffer() async {
    final topic = _topic;
    if (topic == null || !topic.isPendingJobOffer) return;
    final ok = await showAdminConfirmDialog(
      context,
      title: 'Approve job offer?',
      message:
          '"${topic.title}" will become visible to alumni in the community forum.',
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    await _runBusy(() async {
      await _forumService.reviewJobOffer(topicId: topic.id, approve: true);
    });
  }

  Future<void> _declineJobOffer() async {
    final topic = _topic;
    if (topic == null || !topic.isPendingJobOffer) return;
    final ok = await showAdminConfirmDialog(
      context,
      title: 'Decline job offer?',
      message:
          '"${topic.title}" will be permanently removed. '
          'Message the alumnus separately if they should revise and submit a new offer.',
      confirmLabel: 'Decline',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _runBusy(() async {
      await _forumService.reviewJobOffer(
        topicId: topic.id,
        approve: false,
      );
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _deletePost(ForumPost post) async {
    final ok = await showAdminConfirmDialog(
      context,
      title: 'Delete reply?',
      message: 'This reply will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busyPostIds.add(post.id));
    try {
      await _forumService.deletePost(widget.topicId, post.id);
      _notifyChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(forumFriendlyError(e, 'Could not delete reply.')),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPostIds.remove(post.id));
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

  List<String> _mentionedIdsInBody(String text) {
    final quoting = _quoting;
    if (quoting == null || quoting.authorUid.trim().isEmpty) return const [];
    final name = quoting.authorName.trim().isEmpty
        ? 'Alumni'
        : quoting.authorName.trim();
    if (!text.toLowerCase().contains('@${name.toLowerCase()}')) {
      return const [];
    }
    return [quoting.authorUid];
  }

  Future<void> _sendReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty || _sendingReply) return;
    final topic = _topic;
    if (topic == null || topic.isLocked) return;
    setState(() => _sendingReply = true);
    try {
      await _forumService.createPost(
        topicId: topic.id,
        body: body,
        quotedPostId: _quoting?.id,
        quotedExcerpt: _quoting == null
            ? null
            : ForumFormattedText.plain(_quoting!.body),
        mentionedUserIds: _mentionedIdsInBody(body),
      );
      _replyController.clear();
      setState(() => _quoting = null);
      _notifyChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(forumFriendlyError(e, 'Could not post reply.')),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = _topic;
    return ColoredBox(
      color: AdminColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(topic),
          if (topic != null && topic.isJobOffer) ...[
            AdminTabBar(
              controller: _jobTabs,
              isScrollable: false,
              tabs: const [
                AdminTabSpec(
                  label: 'Job post',
                  icon: Icons.work_outline_rounded,
                ),
                AdminTabSpec(
                  label: 'Purpose letter',
                  icon: Icons.mail_outline_rounded,
                ),
              ],
            ),
          ] else
            const Divider(height: 1),
          Expanded(
            child: _loading && topic == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null && topic == null
                ? AdminStateView.error(
                    title: "Couldn't load topic",
                    message: forumFriendlyError(
                      _error!,
                      'Check your connection and try again.',
                    ),
                    onRetry: _bind,
                  )
                : topic == null
                ? const AdminStateView.empty(
                    title: 'Topic not found',
                    message: 'It may have been deleted.',
                  )
                : topic.isJobOffer
                ? TabBarView(
                    controller: _jobTabs,
                    children: [
                      _buildJobPostTab(topic),
                      _buildPurposeLetterTab(topic),
                    ],
                  )
                : _buildDiscussionBody(topic),
          ),
          if (topic != null && topic.isJobOfferInReviewQueue)
            _buildJobOfferFooter(topic),
          if (topic != null &&
              !topic.isLocked &&
              !topic.isJobOfferInReviewQueue)
            _buildReplyComposer(topic),
        ],
      ),
    );
  }

  Widget _buildHeader(ForumTopic? topic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: topic == null
                    ? const SizedBox.shrink()
                    : AdminForumTopicStatusBadges(topic: topic),
              ),
              if (topic != null) ...[
                PopupMenuButton<String>(
                  tooltip: 'Moderation',
                  enabled: !_busy,
                  onSelected: (value) async {
                    switch (value) {
                      case 'share':
                        await showShareLinkSheet(
                          context,
                          ShareableContent.fromTopic(topic),
                        );
                      case 'lock':
                        await _toggleLock();
                      case 'pin':
                        await _togglePin();
                      case 'solved':
                        await _toggleSolved();
                      case 'delete':
                        await _deleteTopic();
                    }
                  },
                  itemBuilder: (_) => [
                    if (!topic.isJobOfferInReviewQueue)
                      adminForumMenuItem(
                        value: 'share',
                        label: 'Share link…',
                        icon: Icons.share_outlined,
                      ),
                    if (!topic.isJobOfferInReviewQueue) ...[
                      adminForumMenuItem(
                        value: 'lock',
                        label: topic.isLocked ? 'Unlock topic' : 'Lock topic',
                        icon: topic.isLocked
                            ? Icons.lock_open_outlined
                            : Icons.lock_outlined,
                      ),
                      adminForumMenuItem(
                        value: 'pin',
                        label: topic.isPinned ? 'Unpin' : 'Pin to top',
                        icon: Icons.push_pin_outlined,
                      ),
                      if (!topic.isAnnouncement && !topic.isJobOffer)
                        adminForumMenuItem(
                          value: 'solved',
                          label: topic.isSolved
                              ? 'Mark unsolved'
                              : 'Mark solved',
                          icon: Icons.check_circle_outline,
                        ),
                      const PopupMenuDivider(height: 8),
                    ],
                    adminForumMenuItem(
                      value: 'delete',
                      label: 'Delete topic',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                    ),
                  ],
                ),
              ],
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                style: AdminDensity.iconButtonStyle(
                  foregroundColor: AdminColors.textMuted,
                ),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            topic?.title.trim().isNotEmpty == true
                ? topic!.title.trim()
                : 'Discussion',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: -0.2,
              color: AdminColors.textPrimary,
            ),
          ),
          if (topic != null) ...[
            const SizedBox(height: 4),
            Text(
              _metaLine(topic),
              style: const TextStyle(
                fontSize: 12.5,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _metaLine(ForumTopic topic) {
    final author =
        topic.authorName.trim().isEmpty ? 'Alumni' : topic.authorName.trim();
    final parts = <String>[
      author,
      if (!topic.isJobOffer && topic.authorProgram.trim().isNotEmpty)
        topic.authorProgram.trim(),
      if (!topic.isJobOffer && topic.authorBatch.trim().isNotEmpty)
        'Batch ${topic.authorBatch.trim()}',
      DateFormat.yMMMd().add_jm().format(topic.createdAt),
    ];
    return parts.join(' · ');
  }

  Widget _buildDiscussionBody(ForumTopic topic) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ForumFormattedText(
          topic.body,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        _buildRepliesSection(topic),
      ],
    );
  }

  Widget _buildJobPostTab(ForumTopic topic) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (topic.coverImageUrl.trim().isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: AppImage.widget(
                topic.coverImageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ForumFormattedText(
          topic.body,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AdminColors.textPrimary,
          ),
        ),
        if (topic.applyUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          SafeLinkText(
            topic.applyUrl.trim(),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AdminColors.primary,
            ),
          ),
        ],
        if (!topic.isPendingJobOffer) ...[
          const SizedBox(height: 20),
          _buildRepliesSection(topic),
        ],
      ],
    );
  }

  Widget _buildPurposeLetterTab(ForumTopic topic) {
    final letter = topic.purposeLetter.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Visible to community admins only. Alumni never see this letter.',
          style: TextStyle(
            fontSize: 12.5,
            color: AdminColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
            border: Border.all(color: AdminColors.border),
          ),
          child: Text(
            letter.isEmpty ? 'No purpose letter was provided.' : letter,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: letter.isEmpty
                  ? AdminColors.textMuted
                  : AdminColors.textPrimary,
              fontStyle: letter.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepliesSection(ForumTopic topic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Replies (${_posts.length})',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AdminColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (_posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No replies yet.',
              style: TextStyle(
                fontSize: 13,
                color: AdminColors.textSecondary,
              ),
            ),
          )
        else
          for (final post in _posts) ...[
            _buildPostCard(post, canQuote: !topic.isLocked),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  String _resolvedQuoteText(ForumPost post) {
    final excerpt = post.quotedExcerpt?.trim() ?? '';
    if (excerpt.isNotEmpty) return ForumFormattedText.plain(excerpt);
    final quotedId = post.quotedPostId?.trim() ?? '';
    if (quotedId.isEmpty) return '';
    for (final other in _posts) {
      if (other.id == quotedId) {
        return ForumFormattedText.plain(other.body);
      }
    }
    return '';
  }

  Widget _buildPostCard(ForumPost post, {required bool canQuote}) {
    final busy = _busyPostIds.contains(post.id);
    final name =
        post.authorName.trim().isEmpty ? 'Alumni' : post.authorName.trim();
    final quote = _resolvedQuoteText(post);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AdminColors.primaryTint,
                backgroundImage: () {
                  final url = post.authorAvatarUrl?.trim() ?? '';
                  if (url.isEmpty) return null;
                  return AppImage.provider(url);
                }(),
                child: (post.authorAvatarUrl?.trim().isNotEmpty ?? false)
                    ? null
                    : Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd().add_jm().format(post.createdAt),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (canQuote)
                IconButton(
                  tooltip: 'Quote reply',
                  onPressed: () => _startQuote(post),
                  style: AdminDensity.iconButtonStyle(
                    foregroundColor: AdminColors.primary,
                  ),
                  icon: const Icon(Icons.format_quote_rounded, size: 18),
                ),
              IconButton(
                tooltip: 'Delete reply',
                onPressed: busy ? null : () => _deletePost(post),
                style: AdminDensity.iconButtonStyle(
                  foregroundColor: AdminColors.danger,
                ),
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          if (quote.isNotEmpty) ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AdminColors.card,
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                border: Border.all(color: AdminColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: AdminColors.primary),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          child: Text(
                            quote,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AdminColors.textSecondary,
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
          const SizedBox(height: 8),
          ForumFormattedText(
            post.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AdminColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobOfferFooter(ForumTopic topic) {
    return Material(
      elevation: 6,
      color: AdminColors.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _declineJobOffer,
                  style: AdminButtonStyles.outlined(),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _approveJobOffer,
                  style: AdminButtonStyles.filled(),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyComposer(ForumTopic topic) {
    final quoting = _quoting;
    final quoteName = quoting == null
        ? ''
        : (quoting.authorName.trim().isEmpty
              ? 'Alumni'
              : quoting.authorName.trim());
    final quotePreview = quoting == null
        ? ''
        : ForumFormattedText.plain(quoting.body);

    return Material(
      elevation: 8,
      shadowColor: AdminColors.primary.withValues(alpha: 0.12),
      color: AdminColors.card,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AdminColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (quoting != null) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: AdminColors.primaryTint,
                      borderRadius:
                          BorderRadius.circular(AdminSurfaces.radiusSm),
                      border: Border.all(
                        color: AdminColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.format_quote_rounded,
                          size: 16,
                          color: AdminColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Quoting $quoteName: $quotePreview',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: AdminColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cancel quote',
                          onPressed: _cancelQuote,
                          style: AdminDensity.iconButtonStyle(
                            foregroundColor: AdminColors.textMuted,
                          ),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  height: _replyComposerHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AdminColors.surface,
                            borderRadius: BorderRadius.circular(
                              AdminSurfaces.radiusSm,
                            ),
                            border: Border.all(color: AdminColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Center(
                              child: TextField(
                                controller: _replyController,
                                focusNode: _replyFocus,
                                minLines: 1,
                                maxLines: 1,
                                enabled: !_sendingReply,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) {
                                  if (!_sendingReply) _sendReply();
                                },
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.25,
                                  color: AdminColors.textPrimary,
                                ),
                                cursorColor: AdminColors.primary,
                                decoration: const InputDecoration(
                                  hintText: 'Reply as community admin…',
                                  hintStyle: TextStyle(
                                    color: AdminColors.textMuted,
                                    fontSize: 14,
                                    height: 1.25,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sendingReply ? null : _sendReply,
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AdminColors.primary
                              .withValues(alpha: 0.55),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AdminSurfaces.radiusSm,
                            ),
                          ),
                        ),
                        child: _sendingReply
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.send_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text('Reply'),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
