import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/shared/widgets/photo_download.dart';

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
    this.placeholderColors,
  });

  final AlumniEvent event;
  final double height;

  /// When set, overrides [height] and locks a consistent teaser frame.
  final double? aspectRatio;
  final double borderRadius;
  final BoxFit fit;
  final List<Color>? placeholderColors;

  /// Compact feed teaser — shorter than 16:9 so cards stay scannable.
  /// Image is cropped with [BoxFit.cover] (not stretched).
  static const double feedTeaserRatio = 2.35;

  @override
  Widget build(BuildContext context) {
    final url = event.coverImageUrl.trim();
    final image = url.isEmpty
        ? _Placeholder(title: event.theme, colors: placeholderColors)
        : AppImage.widget(
            url,
            width: 720,
            height: aspectRatio != null ? 420 : height,
            fit: fit,
            semanticLabel: 'Cover for ${event.theme}',
            errorBuilder: (_, __, ___) =>
                _Placeholder(title: event.theme, colors: placeholderColors),
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
    this.placeholderColors,
  });

  final AlumniEvent event;
  final double borderRadius;
  final bool showDownload;
  final List<Color>? placeholderColors;

  @override
  State<EventCoverHero> createState() => _EventCoverHeroState();
}

String _eventCoverFileName(AlumniEvent event) =>
    '${event.theme.trim().isEmpty ? 'event' : event.theme}_cover';

/// Saves [event]'s cover photo (see [downloadPhoto]).
Future<void> downloadEventCover(BuildContext context, AlumniEvent event) =>
    downloadPhoto(
      context,
      url: event.coverImageUrl,
      baseName: _eventCoverFileName(event),
    );

/// Round "download" button for overlaying on a cover photo.
class EventCoverDownloadButton extends StatelessWidget {
  const EventCoverDownloadButton({super.key, required this.event});

  final AlumniEvent event;

  @override
  Widget build(BuildContext context) => PhotoDownloadButton(
    url: event.coverImageUrl,
    baseName: _eventCoverFileName(event),
  );
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
              child: _Placeholder(
                title: widget.event.theme,
                colors: widget.placeholderColors,
              ),
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
                child: _Placeholder(
                  title: widget.event.theme,
                  colors: widget.placeholderColors,
                ),
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
  const _Placeholder({required this.title, this.colors});

  final String title;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? const [Color(0xFF090A4F), Color(0xFF1A237E)],
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
