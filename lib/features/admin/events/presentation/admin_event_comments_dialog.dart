import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/events/data/event_comment_service.dart';
import 'package:alumni_system/features/events/models/event_comment_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_badge.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Admin moderation view for event comments and replies.
class AdminEventCommentsDialog extends StatefulWidget {
  final AlumniEvent event;
  final EventCommentService commentService;
  final VoidCallback onCommentDeleted;

  /// When true, renders as a fixed desktop modal body rather than a draggable sheet.
  final bool asDialog;

  /// When true (inside [AdminEventDetailPanel]'s Comments tab), omits the modal header.
  final bool embedded;

  /// Notifies parent containers (e.g. tab count badges) when live comment count updates.
  final ValueChanged<int>? onCountChanged;

  const AdminEventCommentsDialog({
    super.key,
    required this.event,
    required this.commentService,
    required this.onCommentDeleted,
    this.asDialog = false,
    this.embedded = false,
    this.onCountChanged,
  });

  @override
  State<AdminEventCommentsDialog> createState() =>
      _AdminEventCommentsDialogState();
}

class _AdminEventCommentsDialogState extends State<AdminEventCommentsDialog> {
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _showReplyInput = {};
  final Set<String> _sendingReplyIds = {};
  int? _lastReportedCount;

  Widget _buildAvatar(
    EventComment comment, {
    double radius = 18,
    Color background = AdminColors.primary,
    Color foreground = Colors.white,
  }) {
    final provider = AppImage.provider(comment.profileImageUrl);
    if (provider != null) {
      return CircleAvatar(radius: radius, backgroundImage: provider);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
        style: TextStyle(
          color: foreground,
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reportCount(int count) {
    final cb = widget.onCountChanged;
    if (cb == null || _lastReportedCount == count) return;
    _lastReportedCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb(count);
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AdminColors.danger : AdminColors.success,
      ),
    );
  }

  Future<void> _deleteComment(EventComment comment) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Delete comment?',
      message:
          'This permanently deletes this comment by ${comment.userName.isEmpty ? 'Alumni' : comment.userName} and its replies.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;

    try {
      await widget.commentService.deleteComment(
        eventId: comment.eventId,
        commentId: comment.id,
      );
      widget.onCommentDeleted();
      _showSnack('Comment deleted');
    } catch (e) {
      _showSnack(
        eventFriendlyError(e, "Couldn't delete the comment. Please try again."),
        isError: true,
      );
    }
  }

  Future<void> _submitReply(EventComment comment) async {
    final controller = _replyControllers[comment.id];
    if (controller == null ||
        controller.text.trim().isEmpty ||
        _sendingReplyIds.contains(comment.id)) {
      return;
    }

    setState(() => _sendingReplyIds.add(comment.id));
    try {
      await widget.commentService.createReply(
        eventId: comment.eventId,
        commentId: comment.id,
        reply: controller.text,
        originalComment: comment,
      );
      controller.clear();
      if (!mounted) return;
      setState(() => _showReplyInput[comment.id] = false);
      _showSnack('Reply sent');
    } catch (e) {
      _showSnack(
        eventFriendlyError(e, "Couldn't send the reply. Please try again."),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sendingReplyIds.remove(comment.id));
    }
  }

  Widget _buildCommentWithReplies(EventComment comment, String eventId) {
    _replyControllers.putIfAbsent(comment.id, TextEditingController.new);
    _showReplyInput.putIfAbsent(comment.id, () => false);
    final showingInput = _showReplyInput[comment.id] ?? false;
    final sending = _sendingReplyIds.contains(comment.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(comment),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName.isEmpty ? 'Alumni' : comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    if (comment.userEmail.trim().isNotEmpty)
                      Text(
                        comment.userEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Comment actions',
                color: AdminColors.card,
                elevation: 8,
                shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusMd),
                ),
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AdminColors.textMuted,
                ),
                onSelected: (value) {
                  if (value == 'reply') {
                    setState(() => _showReplyInput[comment.id] = true);
                  } else if (value == 'delete') {
                    _deleteComment(comment);
                  }
                },
                itemBuilder: (_) => [
                  adminEventMenuItem(
                    value: 'reply',
                    label: 'Reply',
                    icon: Icons.reply_rounded,
                  ),
                  adminEventMenuItem(
                    value: 'delete',
                    label: 'Delete comment',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment.comment,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.updatedAt != null &&
                          comment.updatedAt != comment.createdAt
                      ? '${DateFormat('MMM d, yyyy · h:mm a').format(comment.createdAt)} · Edited'
                      : DateFormat('MMM d, yyyy · h:mm a')
                            .format(comment.createdAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ),
              if (!showingInput)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showReplyInput[comment.id] = true),
                  icon: const Icon(Icons.reply_rounded, size: 15),
                  label: const Text('Reply'),
                  style: AdminButtonStyles.ghost(foreground: AdminColors.primary)
                      .copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 28)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          StreamBuilder<List<EventComment>>(
            stream: widget.commentService.getRepliesStream(eventId, comment.id),
            builder: (context, repliesSnapshot) {
              final replies = repliesSnapshot.data ?? [];
              if (replies.isEmpty && !showingInput) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Column(
                        children: [
                          for (final reply in replies)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AdminColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AdminSurfaces.radiusSm,
                                ),
                                border: Border.all(
                                  color: AdminColors.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAvatar(
                                    reply,
                                    radius: 14,
                                    background: AdminColors.accent,
                                    foreground: AdminColors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              reply.userName.isEmpty
                                                  ? 'Admin'
                                                  : reply.userName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                                color: AdminColors.primary,
                                              ),
                                            ),
                                            const AdminBadge.info(
                                              label: 'Admin',
                                              dense: true,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          reply.comment,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: AdminColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('MMM d · h:mm a')
                                              .format(reply.createdAt),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AdminColors.textSecondary,
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
                  ],
                  if (showingInput) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyControllers[comment.id],
                              minLines: 1,
                              maxLines: 3,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AdminColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Write an admin reply…',
                                hintStyle: const TextStyle(
                                  fontSize: 12.5,
                                  color: AdminColors.textMuted,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: AdminColors.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AdminSurfaces.radiusSm,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AdminColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AdminSurfaces.radiusSm,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AdminColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AdminSurfaces.radiusSm,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AdminColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Send reply',
                            child: FilledButton(
                              onPressed: sending
                                  ? null
                                  : () => _submitReply(comment),
                              style: AdminButtonStyles.filled().copyWith(
                                minimumSize: const WidgetStatePropertyAll(
                                  Size(38, 36),
                                ),
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                              child: sending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 16),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Cancel reply',
                            onPressed: sending
                                ? null
                                : () => setState(() {
                                    _showReplyInput[comment.id] = false;
                                    _replyControllers[comment.id]?.clear();
                                  }),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AdminColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: AdminModalHeader(
        title: 'Event Comments',
        subtitle: widget.event.theme,
        icon: Icons.forum_outlined,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<List<EventComment>>(
              stream: widget.commentService.getCommentsStream(widget.event.id),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? widget.event.comments;
                return AdminBadge.info(
                  label: '$count ${count == 1 ? 'comment' : 'comments'}',
                );
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AdminColors.textMuted,
              ),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList({ScrollController? scrollController}) {
    return StreamBuilder<List<EventComment>>(
      stream: widget.commentService.getCommentsStream(widget.event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const CommentListSkeleton();
        }

        if (snapshot.hasError) {
          return AdminStateView.error(
            compact: true,
            title: "Couldn't load comments",
            message: 'Please try again in a moment.',
            details: '${snapshot.error}',
          );
        }

        final comments = snapshot.data ?? [];
        _reportCount(comments.length);

        if (comments.isEmpty) {
          return const AdminStateView.empty(
            compact: true,
            icon: Icons.forum_outlined,
            title: 'No comments yet',
            message: 'Alumni questions and comments about this event appear here.',
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          itemCount: comments.length,
          itemBuilder: (context, index) =>
              _buildCommentWithReplies(comments[index], widget.event.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog || widget.embedded) {
      return ColoredBox(
        color: widget.embedded ? AdminColors.background : AdminColors.card,
        child: Column(
          children: [
            if (!widget.embedded) _buildHeader(),
            Expanded(child: _buildCommentsList()),
          ],
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildCommentsList(scrollController: scrollController),
            ),
          ],
        ),
      ),
    );
  }
}
