import 'package:alumni_system/features/jobs/application/job_expiration.dart';
import 'package:alumni_system/features/jobs/data/favorite_job_service.dart';
import 'package:alumni_system/features/jobs/data/job_interest_service.dart';
import 'package:alumni_system/features/jobs/data/job_recommendation.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';

/// Session debounce so Home + Jobs open don't spam deadline notifications.
DateTime? _lastDeadlineReminderRun;
const _deadlineReminderCooldown = Duration(minutes: 30);

/// Runs deadline reminders for the signed-in alumni (interested / favorited /
/// recommended). Safe to call on Home or Jobs open.
///
/// Pass [jobs] when the caller already loaded active jobs to avoid a second
/// expire + list round-trip.
Future<void> runJobDeadlineReminders({
  String? alumniCourse,
  List<JobPosting>? jobs,
}) async {
  final userId = AppSession.userId;
  if (userId == null) return;

  final now = DateTime.now();
  if (_lastDeadlineReminderRun != null &&
      now.difference(_lastDeadlineReminderRun!) < _deadlineReminderCooldown) {
    return;
  }

  try {
    final list = jobs ?? await JobService().getActiveJobs();
    final interestIds =
        (await JobInterestService().getInterestedJobIds()).toSet();
    final favIds = (await FavoriteJobService().getFavoriteJobIds()).toSet();

    String? course = alumniCourse;
    if (course == null || course.isEmpty) {
      try {
        final profile = await UserProfileService().getTracerProfile(userId);
        course = profile?.program;
      } catch (_) {}
    }

    final notifications = NotificationService();
    var attempted = false;
    for (final job in list) {
      final days = JobExpiration.daysUntilDeadline(job.applicationDeadline);
      if (days != 1 && days != 3) continue;

      final relevant = interestIds.contains(job.id) ||
          favIds.contains(job.id) ||
          JobRecommendation.matches(job, course);
      if (!relevant) continue;

      attempted = true;
      await notifications.notifyJobDeadlineIfNeeded(
        userId: userId,
        jobId: job.id,
        jobTitle: job.jobTitle,
        companyName: job.companyName,
        daysLeft: days,
      );
    }
    // Mark cooldown even if none matched so we don't re-query every Home open.
    if (attempted || list.isNotEmpty) {
      _lastDeadlineReminderRun = now;
    }
  } catch (_) {}
}

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
