import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/events/data/event_comment_service.dart';
import 'package:alumni_system/features/events/models/event_comment_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/shared/widgets/safe_link_text.dart';
import 'package:alumni_system/shared/widgets/user/portal_menu.dart';
import 'package:alumni_system/shared/widgets/user/portal_skeletons.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Alumni discussion sheet for a single event (comments + admin replies).
class EventCommentsSheet extends StatefulWidget {
  const EventCommentsSheet({
    super.key,
    required this.event,
    required this.commentService,
    required this.onCommentsChanged,
  });

  final AlumniEvent event;
  final EventCommentService commentService;
  final ValueChanged<int> onCommentsChanged;

  @override
  State<EventCommentsSheet> createState() => _EventCommentsSheetState();
}

class _EventCommentsSheetState extends State<EventCommentsSheet> {
  static const double _avatarSize = 36;
  static const double _bodyIndent = _avatarSize + 10;
  static const double _composerHeight = 44;

  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  List<EventComment> _comments = [];
  final Map<String, List<EventComment>> _repliesByComment = {};
  bool _loadingComments = true;
  Object? _loadError;
  bool _isSubmitting = false;
  bool _savingEdit = false;
  String? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _reloadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // —— Data ——

  /// [silent] keeps the current list on screen (pull-to-refresh, after edits).
  Future<void> _reloadComments({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingComments = true;
        _loadError = null;
      });
    }
    try {
      final eventId = widget.event.id;
      final comments = await widget.commentService.getComments(eventId);
      final replies = await Future.wait(
        comments.map(
          (c) => widget.commentService
              .getReplies(eventId, c.id)
              .catchError((Object _) => const <EventComment>[]),
        ),
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _repliesByComment
          ..clear()
          ..addAll({
            for (var i = 0; i < comments.length; i++)
              comments[i].id: replies[i],
          });
        _loadingComments = false;
        _loadError = null;
      });
      widget.onCommentsChanged(comments.length);
    } catch (e) {
      if (!mounted) return;
      if (silent && _comments.isNotEmpty) {
        _toast(portalFriendlyError(e), error: true);
        return;
      }
      setState(() {
        _loadingComments = false;
        _loadError = e;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.commentService.createComment(
        eventId: widget.event.id,
        comment: text,
      );
      _commentController.clear();
      _inputFocus.unfocus();
      await _reloadComments(silent: true);
    } catch (e) {
      _toast('Could not post comment. ${portalFriendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startEditing(EventComment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _editController.text = comment.comment;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingCommentId = null;
      _editController.clear();
    });
  }

  Future<void> _updateComment(EventComment comment) async {
    final text = _editController.text.trim();
    if (text.isEmpty || text == comment.comment.trim()) {
      _cancelEditing();
      return;
    }
    setState(() => _savingEdit = true);
    try {
      await widget.commentService.updateComment(
        eventId: widget.event.id,
        commentId: comment.id,
        newComment: text,
      );
      if (!mounted) return;
      _cancelEditing();
      await _reloadComments(silent: true);
      _toast('Comment updated');
    } catch (e) {
      _toast(
        'Could not update comment. ${portalFriendlyError(e)}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _savingEdit = false);
    }
  }

  Future<void> _deleteComment(EventComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text(
          'Your comment will be removed from this event. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: PortalTheme.ghostButton(dense: true),
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
    if (confirmed != true) return;
    try {
      await widget.commentService.deleteComment(
        eventId: widget.event.id,
        commentId: comment.id,
      );
      await _reloadComments(silent: true);
      _toast('Comment deleted');
    } catch (e) {
      _toast(
        'Could not delete comment. ${portalFriendlyError(e)}',
        error: true,
      );
    }
  }

  bool _isMine(EventComment comment) {
    final userId = AppSession.userId;
    return userId != null && comment.userId == userId;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? PortalTheme.danger : PortalTheme.navy,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // —— Layout ——

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Material(
        color: PortalTheme.pageBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PortalTheme.radius2xl),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody(scrollController)),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final count = _comments.length;
    final subtitle = _loadingComments || _loadError != null
        ? widget.event.theme
        : '$count ${count == 1 ? 'comment' : 'comments'} · ${widget.event.theme}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 12),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        border: Border(
          bottom: BorderSide(color: PortalTheme.border.withValues(alpha: 0.75)),
        ),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PortalTheme.borderStrong,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PortalTheme.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: PortalTheme.navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Comments', style: PortalTheme.pageTitle),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PortalTheme.meta,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                color: PortalTheme.textSecondary,
                style: IconButton.styleFrom(
                  backgroundColor: PortalTheme.surfaceMuted,
                  minimumSize: const Size(36, 36),
                  fixedSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_loadingComments) return const CommentListSkeleton();

    if (_loadError != null) {
      return _fillScroll(
        scrollController,
        PortalErrorState(
          title: 'Couldn\'t load comments',
          error: _loadError,
          onRetry: _reloadComments,
        ),
      );
    }

    if (_comments.isEmpty) {
      return _fillScroll(
        scrollController,
        PortalEmptyState(
          icon: Icons.forum_outlined,
          title: 'No comments yet',
          subtitle:
              'Start the conversation. Ask a question or share a thought '
              'about this event.',
          actionLabel: 'Write a comment',
          onAction: _inputFocus.requestFocus,
        ),
      );
    }

    return RefreshIndicator(
      color: PortalTheme.navy,
      onRefresh: () => _reloadComments(silent: true),
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: _comments.length,
        itemBuilder: (context, index) => _buildCommentCard(_comments[index]),
      ),
    );
  }

  /// Keeps the drag-to-resize gesture working on empty / error states.
  Widget _fillScroll(ScrollController controller, Widget child) {
    return CustomScrollView(
      controller: controller,
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    );
  }

  Widget _buildCommentCard(EventComment comment) {
    final mine = _isMine(comment);
    final editing = _editingCommentId == comment.id;
    final edited =
        comment.updatedAt != null && comment.updatedAt != comment.createdAt;
    final replies = _repliesByComment[comment.id] ?? const <EventComment>[];

    return Container(
      margin: const EdgeInsets.only(bottom: PortalTheme.space2),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(
          color: editing
              ? PortalTheme.navy.withValues(alpha: 0.35)
              : PortalTheme.border,
        ),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(comment, size: _avatarSize),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PortalTheme.cardTitle.copyWith(fontSize: 14),
                          ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 6),
                          _tag(
                            'You',
                            background: PortalTheme.sky.withValues(alpha: 0.12),
                            foreground: PortalTheme.navyMid,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      edited
                          ? '${_formatDate(comment.createdAt)} · Edited'
                          : _formatDate(comment.createdAt),
                      style: PortalTheme.caption,
                    ),
                  ],
                ),
              ),
              if (mine && !editing)
                _buildMenu(comment)
              else
                const SizedBox(width: 8),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: _bodyIndent, right: 8, top: 8),
            child: editing
                ? _buildEditor(comment)
                : SafeLinkText(comment.comment, style: PortalTheme.body),
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: _bodyIndent,
                right: 8,
                top: 12,
              ),
              child: Column(
                children: [for (final reply in replies) _buildReply(reply)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenu(EventComment comment) {
    return PopupMenuButton<String>(
      tooltip: 'Comment options',
      padding: EdgeInsets.zero,
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: PortalTheme.textMuted,
      ),
      onSelected: (value) {
        if (value == 'edit') {
          _startEditing(comment);
        } else {
          _deleteComment(comment);
        }
      },
      itemBuilder: (_) => [
        portalMenuItem(
          value: 'edit',
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
        portalMenuItem(
          value: 'delete',
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
  }

  Widget _buildEditor(EventComment comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _editController,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          style: PortalTheme.body,
          decoration: _fieldDecoration('Edit your comment…'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _savingEdit ? null : _cancelEditing,
              style: PortalTheme.ghostButton(dense: true),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: _savingEdit ? null : () => _updateComment(comment),
              style: PortalTheme.primaryButton(dense: true),
              child: _savingEdit
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReply(EventComment reply) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: PortalTheme.space1),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: PortalTheme.pageBg,
        borderRadius: BorderRadius.circular(PortalTheme.radiusMd),
        border: Border.all(color: PortalTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(reply, size: 28, admin: true),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reply.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PortalTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Tooltip(
                      message: 'Verified admin',
                      child: Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: PortalTheme.sky,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_formatDate(reply.createdAt), style: PortalTheme.caption),
                const SizedBox(height: 6),
                SafeLinkText(
                  reply.comment,
                  style: PortalTheme.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        border: const Border(top: BorderSide(color: PortalTheme.border)),
        boxShadow: [
          BoxShadow(
            color: PortalTheme.navy.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _inputFocus,
                builder: (context, child) => AnimatedContainer(
                  duration: PortalTheme.fast,
                  constraints: const BoxConstraints(minHeight: _composerHeight),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: PortalTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(_composerHeight / 2),
                    border: Border.all(
                      color: _inputFocus.hasFocus
                          ? PortalTheme.navy.withValues(alpha: 0.35)
                          : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: child,
                ),
                child: TextField(
                  controller: _commentController,
                  focusNode: _inputFocus,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: PortalTheme.body,
                  decoration:
                      InputDecoration.collapsed(
                        hintText: 'Ask a question or share a thought…',
                        hintStyle: PortalTheme.body.copyWith(
                          color: PortalTheme.textMuted,
                        ),
                      ).copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _commentController,
              builder: (context, value, _) {
                final canSend = value.text.trim().isNotEmpty && !_isSubmitting;
                final active = canSend || _isSubmitting;
                return AnimatedContainer(
                  duration: PortalTheme.fast,
                  width: _composerHeight,
                  height: _composerHeight,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? PortalTheme.navy : PortalTheme.border,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canSend ? _submitComment : null,
                      child: Tooltip(
                        message: 'Post comment',
                        child: Center(
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  size: 20,
                                  color: active
                                      ? Colors.white
                                      : PortalTheme.textMuted,
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // —— Pieces ——

  Widget _buildAvatar(
    EventComment comment, {
    required double size,
    bool admin = false,
  }) {
    final provider = AppImage.provider(comment.profileImageUrl);
    final name = comment.userName.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: admin
            ? PortalTheme.gold.withValues(alpha: 0.22)
            : PortalTheme.navy.withValues(alpha: 0.08),
        border: admin ? Border.all(color: PortalTheme.gold, width: 1.5) : null,
        image: provider == null
            ? null
            : DecorationImage(image: provider, fit: BoxFit.cover),
      ),
      child: provider == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: PortalTheme.navy,
              ),
            )
          : null,
    );
  }

  Widget _tag(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    final radius = BorderRadius.circular(PortalTheme.radiusXl);
    return InputDecoration(
      hintText: hint,
      hintStyle: PortalTheme.body.copyWith(color: PortalTheme.textMuted),
      isDense: true,
      filled: true,
      fillColor: PortalTheme.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: PortalTheme.navy.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    }
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
