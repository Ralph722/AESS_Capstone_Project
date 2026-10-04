import 'package:alumni_system/features/jobs/data/job_interest_service.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';

// Deadline reminders (3 days / 1 day before) are sent by the server
// schedule `run_scheduled_notifications()`; nothing runs on the device.

/// Enrich jobs with interest + favorite counts for admin cards.
Future<List<JobPosting>> attachJobEngagementCounts(
  List<JobPosting> jobs,
) async {
  if (jobs.isEmpty) return jobs;
  final ids = jobs.map((j) => j.id);
  final interest = await JobInterestService().countByJobIds(ids);
  final favs = await JobService().countFavoritesByJobIds(ids);
  return jobs
      .map(
        (j) => j.copyWith(
          interestedCount: interest[j.id] ?? 0,
          favoriteCount: favs[j.id] ?? 0,
        ),
      )
      .toList();
}
