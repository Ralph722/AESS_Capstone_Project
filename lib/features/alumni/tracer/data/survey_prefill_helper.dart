import 'package:alumni_system/core/constants/gts_constants.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Prefills CHED survey answers from live profile and prior submissions.
class SurveyPrefillHelper {
  SurveyPrefillHelper._();

  static Map<String, dynamic> valuesFromProfile(TracerProfile profile) {
    return {
      'employment.presentlyEmployed':
          GtsConstants.toChedPresentlyEmployed(profile.employmentStatus),
    };
  }

  static Map<String, dynamic> valuesFromEmployment(EmploymentRecord record) {
    final employed = isEmployed(record);
    if (!employed) {
      return {
        'employment.presentlyEmployed': presentlyEmployed(record),
        'employment.employmentStatus': null,
        'employment.position': null,
        'employment.companyName': null,
        'employment.industry': null,
        'employment.placeOfWork': null,
        'employment.salaryRange': null,
      };
    }
    return {
      'employment.presentlyEmployed': presentlyEmployed(record),
      'employment.employmentStatus': employmentStatusType(record),
      'employment.position': _nonEmpty(record.position),
      'employment.companyName': _nonEmpty(record.companyName),
      'employment.industry': _nonEmpty(record.industry),
      'employment.placeOfWork': placeOfWork(record),
      'employment.salaryRange': _nonEmpty(record.salaryRange),
    };
  }

  static bool isEmployed(EmploymentRecord record) {
    final status = record.employmentStatus.trim().toLowerCase();
    if (status == 'unemployed' || status.contains('unemploy')) return false;
    if (status == 'employed') return true;
    if (status.contains('employ') && !status.contains('unemploy')) return true;
    return false;
  }

  static String? presentlyEmployed(EmploymentRecord record) {
    if (isEmployed(record)) return 'Yes';
    final status = record.employmentStatus.trim().toLowerCase();
    if (status == 'unemployed' || status.contains('unemploy')) return 'No';
    if (status.contains('never')) return 'Never Employed';
    return null;
  }

  static String? employmentStatusType(EmploymentRecord record) {
    if (!isEmployed(record)) return null;
    final type = (record.employmentType ?? '').toLowerCase();
    if (type.contains('self')) return 'Self-employed';
    if (type.contains('contract')) return 'Contractual';
    if (type.contains('part')) return 'Casual';
    if (type.contains('full')) return 'Regular or Permanent';
    if (type.contains('temp')) return 'Temporary';
    if (type.contains('freelance')) return 'Casual';
    return null;
  }

  static String? placeOfWork(EmploymentRecord record) {
    if (!isEmployed(record)) return null;
    final country = (record.country ?? 'Philippines').toLowerCase();
    if (country.contains('philippine') || country.isEmpty) return 'Local';
    return 'Abroad';
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static Map<String, dynamic> applyToQuestions({
    required List<SurveyQuestion> questions,
    required Map<String, dynamic> valuesByPrefillKey,
    required Map<String, dynamic> existing,
    List<String>? industryOptions,
  }) {
    final out = <String, dynamic>{};
    for (final q in questions) {
      final key = q.prefillKey;
      if (key == null || key.isEmpty) continue;
      if (!key.startsWith('employment.') &&
          existing.containsKey(q.id) &&
          existing[q.id] != null &&
          existing[q.id].toString().trim().isNotEmpty) {
        continue;
      }
      if (!valuesByPrefillKey.containsKey(key)) continue;

      final raw = valuesByPrefillKey[key];
      if (raw == null || raw.toString().trim().isEmpty) {
        if (key.startsWith('employment.')) out[q.id] = null;
        continue;
      }

      if (q.type == SurveyQuestionType.singleChoice && q.options.isNotEmpty) {
        final matched = matchOption(raw.toString(), q.options);
        if (matched != null) out[q.id] = matched;
      } else if (q.type == SurveyQuestionType.text ||
          q.type == SurveyQuestionType.longText) {
        out[q.id] = raw.toString();
      }
    }
    return out;
  }

  static String? matchOption(String raw, List<String> options) {
    final lower = raw.trim().toLowerCase();
    for (final opt in options) {
      if (opt.trim().toLowerCase() == lower) return opt;
    }
    for (final opt in options) {
      final optLower = opt.trim().toLowerCase();
      if (optLower.length >= 4 &&
          (optLower.contains(lower) || lower.contains(optLower))) {
        return opt;
      }
    }
    return null;
  }
}
