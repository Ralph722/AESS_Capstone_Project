import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';

/// Which groups a rule is evaluated for once small groups are rolled up.
class DssRollupPlan {
  const DssRollupPlan({
    required this.batches,
    required this.courses,
    required this.institution,
  });

  /// `course|batch` keys evaluated as they are.
  final Set<String> batches;

  /// Courses evaluated across all their batches.
  final Set<String> courses;

  /// Whether the whole institution is evaluated.
  final bool institution;

  bool includesBatch(String course, String batch) =>
      batches.contains(DssRollup.batchKey(course, batch));
}

/// Roll-up for small schools: a course × batch below a rule's minimum
/// responses is pooled into its whole course, and a course still below the
/// minimum is pooled into the whole institution. Respondents whose batch is
/// not recorded ([DssPolicy.batchNotRecorded]) never form a batch group;
/// they count toward their course only.
abstract final class DssRollup {
  /// Stored in `course` / `batch_year` for rolled-up flags.
  static const all = 'All';

  static String batchKey(String course, String batch) => '$course|$batch';

  static bool _isBatch(String batch, int size, int minN) =>
      batch != DssPolicy.batchNotRecorded && size >= minN;

  /// [sizes] is course → batch → respondent count for one wave.
  static DssRollupPlan plan(Map<String, Map<String, int>> sizes, int minN) {
    final batches = <String>{};
    final courses = <String>{};
    var anyCourseTooSmall = false;
    var total = 0;

    for (final course in sizes.entries) {
      var courseTotal = 0;
      var hasSmallBatch = false;
      for (final batch in course.value.entries) {
        courseTotal += batch.value;
        if (_isBatch(batch.key, batch.value, minN)) {
          batches.add(batchKey(course.key, batch.key));
        } else {
          hasSmallBatch = true;
        }
      }
      total += courseTotal;
      if (!hasSmallBatch) continue;
      if (courseTotal >= minN) {
        courses.add(course.key);
      } else {
        anyCourseTooSmall = true;
      }
    }

    return DssRollupPlan(
      batches: batches,
      courses: courses,
      institution: anyCourseTooSmall && total >= minN,
    );
  }

  /// Roll-up for comparing two waves. A course × batch is compared when it
  /// has at least [minN] responses in both waves. Batches that cannot be
  /// compared (too small, or surveyed in only one wave) are covered by the
  /// whole course when both waves have [minN] for it, otherwise by the
  /// institution when both wave totals reach [minN].
  static DssRollupPlan planChange(
    Map<String, Map<String, int>> current,
    Map<String, Map<String, int>> previous,
    int minN,
  ) {
    int sum(Map<String, int>? m) =>
        (m ?? const <String, int>{}).values.fold(0, (a, b) => a + b);

    final batches = <String>{};
    final courses = <String>{};
    var anyCourseTooSmall = false;
    var currentTotal = 0;
    var previousTotal = 0;

    for (final course in {...current.keys, ...previous.keys}) {
      final cur = current[course] ?? const <String, int>{};
      final prev = previous[course] ?? const <String, int>{};
      currentTotal += sum(cur);
      previousTotal += sum(prev);
      var uncovered = false;
      for (final batch in {...cur.keys, ...prev.keys}) {
        if (_isBatch(batch, cur[batch] ?? 0, minN) &&
            _isBatch(batch, prev[batch] ?? 0, minN)) {
          batches.add(batchKey(course, batch));
        } else {
          uncovered = true;
        }
      }
      if (!uncovered) continue;
      if (sum(cur) >= minN && sum(prev) >= minN) {
        courses.add(course);
      } else {
        anyCourseTooSmall = true;
      }
    }

    return DssRollupPlan(
      batches: batches,
      courses: courses,
      institution:
          anyCourseTooSmall && currentTotal >= minN && previousTotal >= minN,
    );
  }

  /// Batches of [course] pooled into the course: below [minN], or with no
  /// batch recorded. E.g. `{'2023': 4, '2024': 6}`.
  static Map<String, int> smallBatches(
    Map<String, Map<String, int>> sizes,
    String course,
    int minN,
  ) => {
    for (final b in (sizes[course] ?? const <String, int>{}).entries)
      if (!_isBatch(b.key, b.value, minN)) b.key: b.value,
  };

  /// Courses whose total responses are below [minN].
  static Map<String, int> smallCourses(
    Map<String, Map<String, int>> sizes,
    int minN,
  ) {
    final out = <String, int>{};
    for (final c in sizes.entries) {
      final total = c.value.values.fold<int>(0, (a, b) => a + b);
      if (total < minN) out[c.key] = total;
    }
    return out;
  }
}
