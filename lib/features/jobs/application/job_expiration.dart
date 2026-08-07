import 'package:alumni_system/features/jobs/models/job_posting_model.dart';

/// Pure helpers for deadline-based expiration.
abstract final class JobExpiration {
  static List<JobPosting> jobsNeedingExpire(List<JobPosting> jobs) {
    return jobs
        .where(
          (j) =>
              j.status.toLowerCase() == 'active' && j.isExpiredByDeadline,
        )
        .toList();
  }

  static DateTime endOfDeadlineDay(DateTime deadline) {
    return DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
      23,
      59,
      59,
    );
  }

  /// Days remaining until end of deadline day (negative if past).
  static int daysUntilDeadline(DateTime deadline) {
    final end = endOfDeadlineDay(deadline);
    return end.difference(DateTime.now()).inDays;
  }
}
