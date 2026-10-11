import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Which CHED tracer an alumnus is asked to answer.
///
/// Each tracer cycle is its own survey, and an older one may be left open by
/// mistake. Only the newest tracer assigned to the alumnus counts, whether or
/// not it is still open or already answered, so they answer one per cycle.
/// Mirrors `auto_assign_open_surveys` in the database.
abstract final class CurrentTracer {
  /// The assignment for the newest published (or closed) tracer, or null.
  static SurveyAssignment? pick(
    Iterable<SurveyAssignment> assignments,
    Survey? Function(String surveyId) surveyFor,
  ) {
    SurveyAssignment? best;
    DateTime? bestAt;
    for (final a in assignments) {
      final s = surveyFor(a.surveyId);
      if (s == null ||
          !s.isChedGtsBuiltin ||
          s.archived ||
          s.status == SurveyStatus.draft) {
        continue;
      }
      final at = s.publishedAt ?? s.openAt ?? s.createdAt;
      if (bestAt == null || at.isAfter(bestAt)) {
        best = a;
        bestAt = at;
      }
    }
    return best;
  }

  /// True for tracers other than [current]; non-tracer surveys are never stale.
  static bool isStale(
    SurveyAssignment assignment,
    Survey survey,
    SurveyAssignment? current,
  ) => survey.isChedGtsBuiltin && assignment.surveyId != current?.surveyId;
}
