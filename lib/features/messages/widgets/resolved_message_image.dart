import 'package:flutter/material.dart';

import 'package:alumni_system/features/messages/data/image_storage_service.dart';

/// Resolves a stored chat image reference to a displayable URL, then builds
/// [builder] with it. Private attachments need a signed URL first.
///
/// When a private attachment's signed URL fails to load (expired / revoked),
/// the cache entry is dropped and resolution is retried once.
class ResolvedMessageImage extends StatefulWidget {
  const ResolvedMessageImage({
    super.key,
    required this.imageRef,
    required this.builder,
    required this.placeholder,
    required this.error,
  });

  final String imageRef;
  final Widget Function(
    String url, {
    required ImageErrorWidgetBuilder errorBuilder,
  }) builder;
  final Widget placeholder;
  final Widget error;

  @override
  State<ResolvedMessageImage> createState() => _ResolvedMessageImageState();
}

class _ResolvedMessageImageState extends State<ResolvedMessageImage> {
  late Future<String> _url;
  var _retried = false;

  @override
  void initState() {
    super.initState();
    _url = ImageStorageService.resolveMessageImageUrl(widget.imageRef);
  }

  @override
  void didUpdateWidget(covariant ResolvedMessageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageRef != widget.imageRef) {
      _retried = false;
      _url = ImageStorageService.resolveMessageImageUrl(widget.imageRef);
    }
  }

  void _retrySignedUrl() {
    if (_retried || !ImageStorageService.isMessageAttachmentRef(widget.imageRef)) {
      return;
    }
    _retried = true;
    ImageStorageService.invalidateSignedUrl(widget.imageRef);
    setState(() {
      _url = ImageStorageService.resolveMessageImageUrl(widget.imageRef);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (!_retried &&
              ImageStorageService.isMessageAttachmentRef(widget.imageRef)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _retrySignedUrl();
            });
            return widget.placeholder;
          }
          return widget.error;
        }
        final url = snapshot.data;
        if (url == null) return widget.placeholder;
        return widget.builder(
          url,
          errorBuilder: (context, error, stack) {
            if (!_retried &&
                ImageStorageService.isMessageAttachmentRef(widget.imageRef)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _retrySignedUrl();
              });
              return widget.placeholder;
            }
            return widget.error;
          },
        );
      },
    );
  }
}
