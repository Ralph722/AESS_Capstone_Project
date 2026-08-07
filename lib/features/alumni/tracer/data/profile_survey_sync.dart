import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Syncs overlapping survey answers back into the live profile on submission.
class ProfileSurveySync {
  ProfileSurveySync._();

  /// Returns partial users-row updates derived from submitted survey answers.
  static Map<String, dynamic> profileUpdatesFromAnswers({
    required List<SurveyQuestion> questions,
    required Map<String, dynamic> answers,
    required TracerProfile current,
  }) {
    final updates = <String, dynamic>{};

    for (final q in questions) {
      final answer = answers[q.id];
      if (answer == null || answer.toString().trim().isEmpty) continue;
      final key = q.prefillKey;
      if (key == 'employment.presentlyEmployed') {
        final status = GtsConstants.fromChedPresentlyEmployed(answer.toString());
        if (status != null && status != current.employmentStatus) {
          updates['employment_status'] = status;
        }
      }
    }

    return updates;
  }

  static TracerProfile applyUpdates(TracerProfile profile, Map<String, dynamic> updates) {
    if (updates.isEmpty) return profile;
    return profile.copyWith(
      employmentStatus:
          updates['employment_status'] as String? ?? profile.employmentStatus,
    );
  }
}
