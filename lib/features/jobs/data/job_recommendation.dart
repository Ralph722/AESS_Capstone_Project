import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';

/// Simple program overlap matching — no AI.
abstract final class JobRecommendation {
  /// Normalize alumni course/program to a roster-style code when possible.
  static String? normalizeAlumniCourse(String? courseOrProgram) {
    return CourseConstants.normalize(courseOrProgram);
  }

  static bool matches(JobPosting job, String? alumniCourse) {
    final course = normalizeAlumniCourse(alumniCourse);
    if (course == null || course.isEmpty) return false;
    final targets = job.targetPrograms
        .map(CourseConstants.normalize)
        .whereType<String>()
        .toSet();
    if (targets.isEmpty) return false;
    return targets.contains(course);
  }

  /// Recommended jobs for [alumniCourse]; if none match, returns newest actives.
  static List<JobPosting> pick({
    required List<JobPosting> activeJobs,
    required String? alumniCourse,
    int limit = 8,
  }) {
    final matched = activeJobs
        .where((j) => matches(j, alumniCourse))
        .toList()
      ..sort((a, b) => b.postedDate.compareTo(a.postedDate));
    if (matched.isNotEmpty) {
      return matched.take(limit).toList();
    }
    final latest = List<JobPosting>.from(activeJobs)
      ..sort((a, b) => b.postedDate.compareTo(a.postedDate));
    return latest.take(limit).toList();
  }

  static bool usedFallback({
    required List<JobPosting> activeJobs,
    required String? alumniCourse,
  }) {
    return !activeJobs.any((j) => matches(j, alumniCourse));
  }
}
