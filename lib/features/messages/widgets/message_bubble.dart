import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/messages/widgets/message_a11y.dart';
import 'package:alumni_system/features/messages/widgets/message_image_download.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/features/messages/widgets/resolved_message_image.dart';
import 'package:alumni_system/shared/widgets/safe_link_text.dart';

enum MessageSendStatus { sent, sending, failed }

/// Subtle delivery/read receipt for the sender's own bubbles.
enum MessageReceiptStatus {
  /// Optimistic / in flight
  sending,

  /// Send failed
  failed,

  /// Accepted by server (or still optimistic after send)
  sent,

  /// Persisted; not yet read by recipient
  delivered,

  /// Recipient marked the message read
  read,
}

MessageReceiptStatus resolveMessageReceipt({
  required MessageSendStatus sendStatus,
  required bool isRead,
  bool optimistic = false,
}) {
  switch (sendStatus) {
    case MessageSendStatus.sending:
      return MessageReceiptStatus.sending;
    case MessageSendStatus.failed:
      return MessageReceiptStatus.failed;
    case MessageSendStatus.sent:
      if (isRead) return MessageReceiptStatus.read;
      if (optimistic) return MessageReceiptStatus.sent;
      return MessageReceiptStatus.delivered;
  }
}

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.isMine,
    required this.body,
    required this.timestamp,
    required this.onLongPress,
    required this.onReact,
    required this.onOpenImage,
    this.imageUrl,
    this.imageBytes,
    this.reactions = const {},
    this.currentUserId,
    this.isEdited = false,
    this.status = MessageSendStatus.sent,
    this.isRead = false,
    this.optimistic = false,
    this.onRetry,
    this.onEdit,
    this.onDelete,
    this.onCopy,
    this.peerIsOffice = true,
    this.peerAvatarUrl,
    this.peerDisplayName,
  });

  final bool isMine;
  final String body;
  final DateTime timestamp;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final Map<String, dynamic> reactions;
  final String? currentUserId;
  final bool isEdited;
  final MessageSendStatus status;
  final bool isRead;
  final bool optimistic;
  final VoidCallback onLongPress;
  final ValueChanged<String> onReact;
  final VoidCallback? onOpenImage;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  /// When true (alumni app), received bubbles show office avatar.
  /// When false (admin inbox), received bubbles show a person avatar.
  final bool peerIsOffice;
  /// Profile image URL / data URL for the peer (alumni photo in admin inbox).
  final String? peerAvatarUrl;
  final String? peerDisplayName;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _hovered = false;
  bool _focused = false;

  String? get _receiptSpoken {
    if (!widget.isMine) return null;
    switch (resolveMessageReceipt(
      sendStatus: widget.status,
      isRead: widget.isRead,
      optimistic: widget.optimistic,
    )) {
      case MessageReceiptStatus.sending:
        return 'Sending';
      case MessageReceiptStatus.failed:
        return 'Failed, tap to retry';
      case MessageReceiptStatus.sent:
        return 'Sent';
      case MessageReceiptStatus.delivered:
        return 'Delivered';
      case MessageReceiptStatus.read:
        return 'Read';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDesktopActions = kIsWeb && (_hovered || _focused);
    final highContrast = MediaQuery.highContrastOf(context);
    final bubbleBorder = highContrast
        ? Border.all(color: MessageA11y.border(context), width: 1.5)
        : (widget.isMine ? null : Border.all(color: MessageTheme.border));

    final semantic = MessageA11y.bubbleLabel(
      isMine: widget.isMine,
      body: widget.body,
      timestamp: widget.timestamp,
      peerIsOffice: widget.peerIsOffice,
      imageUrl: widget.imageUrl,
      isEdited: widget.isEdited,
      receiptLabel: _receiptSpoken,
    );

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          container: true,
          label: semantic,
          hint: 'Long press for message actions. Double tap to react.',
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final paneW = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final maxWidth = (paneW * MessageTheme.maxBubbleWidthFactor)
                    .clamp(120.0, MessageTheme.maxBubbleWidthPx);
                return Column(
                  crossAxisAlignment: widget.isMine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: widget.isMine
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!widget.isMine) ...[
                          ExcludeSemantics(
                            child: _PeerAvatar(
                              peerIsOffice: widget.peerIsOffice,
                              avatarUrl: widget.peerAvatarUrl,
                              displayName: widget.peerDisplayName,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onLongPress: widget.onLongPress,
                                onDoubleTap: () => widget.onReact('👍'),
                                child: ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: maxWidth),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: widget.isMine
                                          ? MessageTheme.sentBubble
                                          : MessageTheme.receivedBubble,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(
                                          MessageTheme.bubbleRadius,
                                        ),
                                        topRight: const Radius.circular(
                                          MessageTheme.bubbleRadius,
                                        ),
                                        bottomLeft: Radius.circular(
                                          widget.isMine
                                              ? MessageTheme.bubbleRadius
                                              : MessageTheme.bubbleRadiusTight,
                                        ),
                                        bottomRight: Radius.circular(
                                          widget.isMine
                                              ? MessageTheme.bubbleRadiusTight
                                              : MessageTheme.bubbleRadius,
                                        ),
                                      ),
                                      border: bubbleBorder,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (widget.imageUrl != null &&
                                            widget.imageUrl!.isNotEmpty)
                                          _ImageThumb(
                                            imageUrl: widget.imageUrl!,
                                            imageBytes: widget.imageBytes,
                                            onTap: widget.onOpenImage,
                                            isMine: widget.isMine,
                                          ),
                                        if (widget.body.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              12,
                                              widget.imageUrl != null ? 8 : 10,
                                              12,
                                              4,
                                            ),
                                            child: SafeLinkText(
                                              widget.body,
                                              style: TextStyle(
                                                color: widget.isMine
                                                    ? MessageTheme.sentText
                                                    : MessageA11y.textPrimary(
                                                        context,
                                                      ),
                                                fontSize: 14.5,
                                                height: 1.35,
                                              ),
                                              linkStyle: TextStyle(
                                                color: widget.isMine
                                                    ? const Color(0xFFDCEBFF)
                                                    : const Color(0xFF2563EB),
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: widget.isMine
                                                    ? const Color(0xFFDCEBFF)
                                                    : const Color(0xFF2563EB),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        if (widget.reactions.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              10,
                                              0,
                                              10,
                                              4,
                                            ),
                                            child: Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: widget.reactions.entries
                                                  .map((entry) {
                                                final users = List<String>.from(
                                                  entry.value ?? [],
                                                );
                                                final mine = widget
                                                            .currentUserId !=
                                                        null &&
                                                    users.contains(
                                                      widget.currentUserId,
                                                    );
                                                return Semantics(
                                                  button: true,
                                                  label: mine
                                                      ? 'Remove reaction ${entry.key}'
                                                      : 'Add reaction ${entry.key}',
                                                  child: InkWell(
                                                    onTap: () => widget
                                                        .onReact(entry.key),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      10,
                                                    ),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: mine
                                                            ? (widget.isMine
                                                                ? Colors.white
                                                                    .withValues(
                                                                    alpha: 0.22,
                                                                  )
                                                                : MessageTheme
                                                                    .navy
                                                                    .withValues(
                                                                    alpha: 0.08,
                                                                  ))
                                                            : Colors
                                                                .transparent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        border: Border.all(
                                                          color: mine
                                                              ? (widget.isMine
                                                                  ? Colors.white
                                                                      .withValues(
                                                                      alpha:
                                                                          0.55,
                                                                    )
                                                                  : MessageTheme
                                                                      .navy
                                                                      .withValues(
                                                                      alpha:
                                                                          0.35,
                                                                    ))
                                                              : MessageA11y
                                                                  .border(
                                                                  context,
                                                                ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        users.length > 1
                                                            ? '${entry.key} ${users.length}'
                                                            : entry.key,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: widget.isMine
                                                              ? Colors.white
                                                              : MessageTheme
                                                                  .textPrimary,
                                                          fontWeight:
                                                              users.length > 1
                                                                  ? FontWeight
                                                                      .w600
                                                                  : FontWeight
                                                                      .w400,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ExcludeSemantics(
                                                child: Text(
                                                  formatMessageClockTime(
                                                    widget.timestamp,
                                                  ),
                                                  style: TextStyle(
                                                    color: widget.isMine
                                                        ? Colors.white
                                                            .withValues(
                                                            alpha: 0.72,
                                                          )
                                                        : MessageTheme
                                                            .textMuted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              if (widget.isEdited) ...[
                                                ExcludeSemantics(
                                                  child: Text(
                                                    ' · Edited',
                                                    style: TextStyle(
                                                      color: widget.isMine
                                                          ? Colors.white
                                                              .withValues(
                                                              alpha: 0.72,
                                                            )
                                                          : MessageTheme
                                                              .textMuted,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (widget.isMine) ...[
                                                const SizedBox(width: 6),
                                                _ReceiptIndicator(
                                                  receipt:
                                                      resolveMessageReceipt(
                                                    sendStatus: widget.status,
                                                    isRead: widget.isRead,
                                                    optimistic:
                                                        widget.optimistic,
                                                  ),
                                                  onRetry: widget.onRetry,
                                                  onLightBubble: true,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (showDesktopActions)
                                Positioned(
                                  top: -10,
                                  right: widget.isMine ? 0 : null,
                                  left: widget.isMine ? null : 0,
                                  child: _DesktopActionStrip(
                                    isMine: widget.isMine,
                                    onReact: () => widget.onReact('👍'),
                                    onMore: widget.onLongPress,
                                    onCopy: widget.onCopy,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptIndicator extends StatelessWidget {
  const _ReceiptIndicator({
    required this.receipt,
    this.onRetry,
    this.onLightBubble = false,
  });

  final MessageReceiptStatus receipt;
  final VoidCallback? onRetry;
  final bool onLightBubble;

  Color get _muted =>
      onLightBubble ? Colors.white.withValues(alpha: 0.72) : MessageTheme.textMuted;
  /// Delivered stays muted; read uses a clear sky accent (WhatsApp-style).
  Color get _read =>
      onLightBubble ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7);

  @override
  Widget build(BuildContext context) {
    switch (receipt) {
      case MessageReceiptStatus.sending:
        return Semantics(
          label: 'Sending',
          child: Text(
            'Sending…',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        );
      case MessageReceiptStatus.failed:
        return Semantics(
          button: true,
          label: 'Failed. Retry send',
          child: GestureDetector(
            onTap: onRetry,
            child: Text(
              'Failed · Retry',
              style: TextStyle(
                color: onLightBubble
                    ? const Color(0xFFFFD1D1)
                    : MessageTheme.failed,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      case MessageReceiptStatus.sent:
        return Semantics(
          label: 'Sent',
          child: Tooltip(
            message: 'Sent',
            child: Icon(Icons.check, size: 14, color: _muted),
          ),
        );
      case MessageReceiptStatus.delivered:
        return Semantics(
          label: 'Delivered',
          child: Tooltip(
            message: 'Delivered',
            child: Icon(Icons.done_all, size: 14, color: _muted),
          ),
        );
      case MessageReceiptStatus.read:
        return Semantics(
          label: 'Read',
          child: Tooltip(
            message: 'Read',
            child: Icon(Icons.done_all, size: 14, color: _read),
          ),
        );
    }
  }
}

class _DesktopActionStrip extends StatelessWidget {
  const _DesktopActionStrip({
    required this.isMine,
    required this.onReact,
    required this.onMore,
    this.onCopy,
  });

  final bool isMine;
  final VoidCallback onReact;
  final VoidCallback onMore;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Quick react',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: onReact,
            icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 16),
            ),
          IconButton(
            tooltip: 'More',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz, size: 16),
          ),
        ],
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({
    required this.peerIsOffice,
    this.avatarUrl,
    this.displayName,
  });

  final bool peerIsOffice;
  final String? avatarUrl;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final provider = AppImage.provider(avatarUrl);
    if (provider != null) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFFE8EAF2),
        backgroundImage: provider,
      );
    }
    if (!peerIsOffice) {
      final letter = (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()[0].toUpperCase()
          : 'A';
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFFE8EAF2),
        child: Text(
          letter,
          style: const TextStyle(
            color: MessageTheme.navy,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFE8EAF2),
      child: Icon(
        peerIsOffice ? Icons.apartment_rounded : Icons.person_outline,
        size: 16,
        color: MessageTheme.navy,
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({
    required this.imageUrl,
    required this.isMine,
    this.imageBytes,
    this.onTap,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final VoidCallback? onTap;
  final bool isMine;

  static const double _maxW = 260;
  static const double _maxH = 320;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (imageUrl.startsWith('data:') && imageBytes != null) {
      image = Image.memory(
        imageBytes!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _broken(),
      );
    } else if (imageUrl.startsWith('data:')) {
      image = _broken();
    } else {
      image = ResolvedMessageImage(
        imageRef: imageUrl,
        placeholder: _placeholder(),
        error: _broken(),
        builder: (url) => Image.network(
          url,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          // Width-only cache keeps original aspect ratio of decoded pixels.
          cacheWidth: 720,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _placeholder();
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _placeholder();
          },
          errorBuilder: (_, __, ___) => _broken(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Semantics(
              button: onTap != null,
              label: 'Open attached image',
              child: GestureDetector(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _maxW,
                    maxHeight: _maxH,
                  ),
                  child: ColoredBox(
                    color: isMine
                        ? Colors.black.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.04),
                    child: image,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => downloadMessageImage(
                    context: context,
                    imageUrl: imageUrl,
                    decodedBytes: imageBytes,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const SizedBox(
      width: 180,
      height: 140,
      child: ColoredBox(
        color: Color(0x22000000),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _broken() {
    return const SizedBox(
      width: 160,
      height: 120,
      child: ColoredBox(
        color: Color(0x22000000),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

Future<void> copyMessageText(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Message copied'),
      duration: Duration(seconds: 2),
    ),
  );
}
