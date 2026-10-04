import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/web_file_download.dart';
import 'package:alumni_system/features/events/models/event_model.dart';

/// Cover image or branded placeholder for event cards/details.
///
/// Prefer [aspectRatio] for feed teasers so every card shares a consistent
/// thumbnail window. Use a fixed [height] only when a specific size is needed.
class EventCover extends StatelessWidget {
  const EventCover({
    super.key,
    required this.event,
    this.height = 120,
    this.aspectRatio,
    this.borderRadius = 10,
    this.fit = BoxFit.cover,
  });

  final AlumniEvent event;
  final double height;

  /// When set, overrides [height] and locks a consistent teaser frame.
  final double? aspectRatio;
  final double borderRadius;
  final BoxFit fit;

  /// Compact feed teaser — shorter than 16:9 so cards stay scannable.
  /// Image is cropped with [BoxFit.cover] (not stretched).
  static const double feedTeaserRatio = 2.35;

  @override
  Widget build(BuildContext context) {
    final url = event.coverImageUrl.trim();
    final image = url.isEmpty
        ? _Placeholder(title: event.theme)
        : AppImage.widget(
            url,
            width: 720,
            height: aspectRatio != null ? 420 : height,
            fit: fit,
            semanticLabel: 'Cover for ${event.theme}',
            errorBuilder: (_, __, ___) => _Placeholder(title: event.theme),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: aspectRatio != null
          ? AspectRatio(
              aspectRatio: aspectRatio!,
              child: SizedBox(width: double.infinity, child: image),
            )
          : SizedBox(height: height, width: double.infinity, child: image),
    );
  }
}

/// Full-width cover that preserves the image aspect ratio (no forced crop).
class EventCoverHero extends StatefulWidget {
  const EventCoverHero({
    super.key,
    required this.event,
    this.borderRadius = 12,
    this.showDownload = true,
  });

  final AlumniEvent event;
  final double borderRadius;
  final bool showDownload;

  @override
  State<EventCoverHero> createState() => _EventCoverHeroState();
}

/// Saves [event]'s cover photo: a browser download on web; on phones the
/// photo opens in the browser/viewer where it can be saved.
Future<void> downloadEventCover(BuildContext context, AlumniEvent event) async {
  final messenger = ScaffoldMessenger.of(context);
  void show(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );

  final value = event.coverImageUrl.trim();
  if (value.isEmpty) return;

  if (!isWebFileDownloadSupported) {
    final uri = Uri.tryParse(value);
    if (AppImage.isDataUrl(value) || uri == null || !uri.hasScheme) {
      show('This photo can be saved from the web portal.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) show('Could not open the photo.');
    return;
  }

  try {
    final Uint8List bytes;
    String mime;
    if (AppImage.isDataUrl(value)) {
      bytes = AppImage.decodeDataUrl(value);
      mime =
          RegExp(r'^data:([^;,]+)').firstMatch(value)?.group(1) ?? 'image/jpeg';
    } else {
      final response = await http.get(Uri.parse(value));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('download failed (${response.statusCode})');
      }
      bytes = response.bodyBytes;
      mime =
          response.headers['content-type']?.split(';').first.trim() ??
          'image/jpeg';
    }
    final ext = switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
    final safeName = event.theme
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    downloadBytesOnWeb(
      bytes: bytes,
      fileName: '${safeName.isEmpty ? 'event' : safeName}_cover.$ext',
      mimeType: mime,
    );
    show('Cover photo downloaded');
  } catch (e) {
    show('Could not download the photo: $e');
  }
}

/// Round "download" button for overlaying on a cover photo.
class EventCoverDownloadButton extends StatefulWidget {
  const EventCoverDownloadButton({super.key, required this.event});

  final AlumniEvent event;

  @override
  State<EventCoverDownloadButton> createState() =>
      _EventCoverDownloadButtonState();
}

class _EventCoverDownloadButtonState extends State<EventCoverDownloadButton> {
  bool _saving = false;

  Future<void> _download() async {
    setState(() => _saving = true);
    await downloadEventCover(context, widget.event);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _saving ? null : _download,
        child: Tooltip(
          message: 'Download photo',
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}

class _EventCoverHeroState extends State<EventCoverHero> {
  @override
  Widget build(BuildContext context) {
    final provider = AppImage.provider(widget.event.coverImageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          if (provider == null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: _Placeholder(title: widget.event.theme),
            )
          else
            Image(
              image: provider,
              fit: BoxFit.contain,
              width: double.infinity,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => SizedBox(
                height: 160,
                width: double.infinity,
                child: _Placeholder(title: widget.event.theme),
              ),
            ),
          if (widget.showDownload && widget.event.hasCoverImage)
            Positioned(
              top: 8,
              right: 8,
              child: EventCoverDownloadButton(event: widget.event),
            ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF090A4F), Color(0xFF1A237E)],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(
              Icons.event,
              size: 72,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              title.isEmpty ? 'Alumni Event' : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
