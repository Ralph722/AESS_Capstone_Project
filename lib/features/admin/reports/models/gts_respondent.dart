/// One submitted CHED GTS response with the roster cohort it belongs to.
class GtsRespondent {
  const GtsRespondent({
    required this.userId,
    required this.surveyId,
    required this.answers,
    this.course = '',
    this.yearGraduated = '',
    this.onActiveRoster = false,
  });

  final String userId;
  final String surveyId;

  /// `survey_responses.answers`, keyed by CHED item id.
  final Map<String, dynamic> answers;

  /// Roster course; empty when the respondent has none.
  final String course;

  /// Roster graduation year (batch); empty when unknown.
  final String yearGraduated;

  /// Linked to an active (not deactivated) roster record.
  final bool onActiveRoster;

  /// Counted by the DSS: on the active roster with a course.
  bool get isRosterLinked => onActiveRoster && course.trim().isNotEmpty;
}
