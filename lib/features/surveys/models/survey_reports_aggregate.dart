import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// One survey’s question-level stats for admin tracer reporting.
class SurveyReportRollup {
  SurveyReportRollup({
    required this.survey,
    required this.aggregates,
  });

  final Survey survey;
  final List<SurveyQuestionAggregate> aggregates;
}

class SurveyQuestionAggregate {
  SurveyQuestionAggregate({
    required this.questionId,
    required this.prompt,
    required this.type,
    required this.answeredCount,
    required this.totalResponses,
    this.choicePercentages = const {},
    this.scaleAverage,
    this.scaleMinObserved,
    this.scaleMaxObserved,
    this.textAnswerCount = 0,
    this.skippedCount = 0,
  });

  final String questionId;
  final String prompt;
  final SurveyQuestionType type;
  final int answeredCount;
  final int totalResponses;
  /// Label → % of respondents who answered this question (for choices).
  final Map<String, double> choicePercentages;
  final double? scaleAverage;
  final int? scaleMinObserved;
  final int? scaleMaxObserved;
  final int textAnswerCount;
  final int skippedCount;
}

/// Assignment funnel for one survey (or portfolio when summed).
class SurveyParticipationSnapshot {
  const SurveyParticipationSnapshot({
    required this.assigned,
    required this.notStarted,
    required this.inProgress,
    required this.completed,
  });

  final int assigned;
  final int notStarted;
  final int inProgress;
  final int completed;

  int get pending => notStarted + inProgress;

  double get completionRate =>
      assigned == 0 ? 0 : (completed / assigned) * 100;
}

class SurveyAudienceBucket {
  const SurveyAudienceBucket({
    required this.label,
    required this.assigned,
    required this.completed,
  });

  final String label;
  final int assigned;
  final int completed;

  double get completionRate =>
      assigned == 0 ? 0 : (completed / assigned) * 100;
}

class SurveySubmissionTrendPoint {
  const SurveySubmissionTrendPoint({
    required this.day,
    required this.count,
  });

  final DateTime day;
  final int count;
}

class SurveyReminderStats {
  const SurveyReminderStats({
    required this.assignmentsWithReminders,
    required this.totalRemindersSent,
    required this.completedAfterReminder,
  });

  final int assignmentsWithReminders;
  final int totalRemindersSent;
  final int completedAfterReminder;
}
