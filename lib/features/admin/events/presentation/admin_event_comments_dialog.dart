import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/events/models/event_comment_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/features/events/data/event_comment_service.dart';

// Admin Event Comments Dialog
class AdminEventCommentsDialog extends StatefulWidget {
  final AlumniEvent event;
  final EventCommentService commentService;
  final VoidCallback onCommentDeleted;

  /// When true the content renders as a fixed desktop dialog panel instead of
  /// a draggable bottom sheet.
  final bool asDialog;

  const AdminEventCommentsDialog({
    required this.event,
    required this.commentService,
    required this.onCommentDeleted,
    this.asDialog = false,
  });

  @override
  State<AdminEventCommentsDialog> createState() =>
      _AdminEventCommentsDialogState();
}

class _AdminEventCommentsDialogState extends State<AdminEventCommentsDialog> {
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _showReplyInput = {};

  Widget _buildAvatar(
    EventComment comment, {
    double radius = 20,
    Color background = const Color(0xFF090A4F),
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
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _deleteComment(EventComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.commentService.deleteComment(
          eventId: comment.eventId,
          commentId: comment.id,
        );

        widget.onCommentDeleted();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted successfully'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting comment: $e'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
      }
    }
  }

  Future<void> _submitReply(EventComment comment) async {
    final controller = _replyControllers[comment.id];
    if (controller == null || controller.text.trim().isEmpty) return;

    try {
      await widget.commentService.createReply(
        eventId: comment.eventId,
        commentId: comment.id,
        reply: controller.text,
        originalComment: comment,
      );

      controller.clear();
      setState(() {
        _showReplyInput[comment.id] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent successfully'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reply: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Widget _buildCommentWithReplies(EventComment comment, String eventId) {
    if (!_replyControllers.containsKey(comment.id)) {
      _replyControllers[comment.id] = TextEditingController();
      _showReplyInput[comment.id] = false;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original Comment
          Row(
            children: [
              _buildAvatar(comment),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      comment.userEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.reply, size: 18, color: Color(0xFF090A4F)),
                        SizedBox(width: 8),
                        Text('Reply'),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () {
                          setState(() {
                            _showReplyInput[comment.id] = true;
                          });
                        },
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Color(0xFFFF6B6B)),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: Color(0xFFFF6B6B)),
                        ),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _deleteComment(comment),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment.comment,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM d, yyyy hh:mm a').format(comment.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          if (comment.updatedAt != null &&
              comment.updatedAt != comment.createdAt)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Edited ${DateFormat('MMM d, yyyy hh:mm a').format(comment.updatedAt!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Replies Section
          StreamBuilder<List<EventComment>>(
            stream: widget.commentService.getRepliesStream(eventId, comment.id),
            builder: (context, repliesSnapshot) {
              final replies = repliesSnapshot.data ?? [];
              if (replies.isEmpty && !(_showReplyInput[comment.id] ?? false)) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replies.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Column(
                        children: [
                          ...replies.map((reply) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF090A4F).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAvatar(
                                      reply,
                                      radius: 16,
                                      background: const Color(0xFFFFD700),
                                      foreground: const Color(0xFF090A4F),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                reply.userName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF090A4F),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFD700)
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Admin',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF090A4F),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            reply.comment,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('MMM d, hh:mm a')
                                                .format(reply.createdAt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],

                  // Reply Input
                  if (_showReplyInput[comment.id] ?? false) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyControllers[comment.id],
                              maxLines: null,
                              decoration: InputDecoration(
                                hintText: 'Type your reply...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _submitReply(comment),
                            icon: const Icon(Icons.send),
                            color: const Color(0xFF090A4F),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF090A4F).withOpacity(0.1),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showReplyInput[comment.id] = false;
                                _replyControllers[comment.id]?.clear();
                              });
                            },
                            icon: const Icon(Icons.close),
                            color: Colors.grey,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF090A4F),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.comment, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event Comments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.event.theme,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<List<EventComment>>(
            stream: widget.commentService.getCommentsStream(widget.event.id),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? widget.event.comments;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count ${count == 1 ? 'comment' : 'comments'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          if (!widget.asDialog) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsList({ScrollController? scrollController}) {
    return StreamBuilder<List<EventComment>>(
      stream: widget.commentService.getCommentsStream(widget.event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CommentListSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final comments = snapshot.data ?? [];

        if (comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No comments yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Users can ask questions about this event',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return _buildCommentWithReplies(comment, widget.event.id);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog) {
      return Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildCommentsList()),
        ],
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
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
