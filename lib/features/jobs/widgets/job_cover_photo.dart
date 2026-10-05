import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/shared/widgets/photo_download.dart';

String _coverFileName(JobPosting job) {
  final title = job.jobTitle.trim().isEmpty ? 'job' : job.jobTitle.trim();
  return '${title}_cover';
}

/// Full-width job cover for the top of the details sheet: tap to view full
/// screen, round download button in the corner. Height is 16:9, capped.
class JobCoverPhoto extends StatelessWidget {
  const JobCoverPhoto({super.key, required this.job, this.overlay});

  final JobPosting job;

  /// Drawn over the photo's top edge (e.g. the sheet drag handle).
  final Widget? overlay;

  static const double maxHeight = 260;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(constraints.maxWidth * 9 / 16, maxHeight);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Material(
                color: const Color(0xFF0B0C3A),
                child: InkWell(
                  onTap: () => showJobCoverViewer(context, job),
                  child: Semantics(
                    button: true,
                    label: 'View cover photo',
                    child: AppImage.widget(
                      job.coverImage,
                      fit: BoxFit.cover,
                      semanticLabel: 'Cover photo for ${job.jobTitle}',
                    ),
                  ),
                ),
              ),
              if (overlay != null)
                Positioned(top: 0, left: 0, right: 0, child: overlay!),
              Positioned(
                top: 10,
                right: 10,
                child: PhotoDownloadButton(
                  url: job.coverImage,
                  baseName: _coverFileName(job),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-screen, zoomable view of the job cover with close and download.
Future<void> showJobCoverViewer(BuildContext context, JobPosting job) {
  final provider = AppImage.provider(job.coverImage);
  if (provider == null) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image(image: provider, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 12 + MediaQuery.paddingOf(ctx).top,
            left: 12,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Close',
                color: Colors.white,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ),
          Positioned(
            top: 12 + MediaQuery.paddingOf(ctx).top,
            right: 12,
            child: PhotoDownloadButton(
              url: job.coverImage,
              baseName: _coverFileName(job),
            ),
          ),
        ],
      ),
    ),
  );
}
