import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Visibility for classic / legacy surveys (not Official CHED GTS).
abstract final class ClassicSurveyVisibility {
  static bool isQuestionVisible({
    required String questionId,
    required Map<String, dynamic> answers,
    required Map<String, SurveyVisibilityRule> rules,
  }) {
    final rule = rules[questionId];
    if (rule == null || rule.sourceQuestionId.isEmpty) return true;

    final raw = answers[rule.sourceQuestionId];
    final actual = raw == null ? '' : raw.toString().trim();
    final expected = rule.value.trim();

    switch (rule.operator) {
      case SurveyVisibilityOperator.equals:
        return actual == expected;
      case SurveyVisibilityOperator.notEquals:
        return actual != expected;
    }
  }

  static List<SurveyQuestion> visibleQuestions({
    required List<SurveyQuestion> questions,
    required Map<String, dynamic> answers,
    required Map<String, SurveyVisibilityRule> rules,
  }) {
    if (rules.isEmpty) return questions;
    return questions
        .where(
          (q) => isQuestionVisible(
            questionId: q.id,
            answers: answers,
            rules: rules,
          ),
        )
        .toList();
  }

  /// Drop answers for questions that are currently hidden.
  static Map<String, dynamic> pruneHiddenAnswers({
    required List<SurveyQuestion> questions,
    required Map<String, dynamic> answers,
    required Map<String, SurveyVisibilityRule> rules,
  }) {
    if (rules.isEmpty) return Map<String, dynamic>.from(answers);
    final visibleIds = visibleQuestions(
      questions: questions,
      answers: answers,
      rules: rules,
    ).map((q) => q.id).toSet();
    return {
      for (final e in answers.entries)
        if (visibleIds.contains(e.key)) e.key: e.value,
    };
  }
}
