import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_prefill.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Where the assembled `ched_*` map primarily came from.
enum ChedGtsAnswerSource {
  /// Submitted `survey_responses.answers` only (no live fill-in).
  submittedSnapshot,

  /// Live [TracerProfile] / [EmploymentRecord] only (no CHED submission).
  liveProfileFallback,

  /// Submitted snapshot with empty gaps filled from live profile/employment.
  merged,

  /// Neither snapshot nor live profile produced any answers.
  empty,
}

/// Flat `ched_*` answers ready for [ChedGtsPdfMapper.mapAnswers].
class ChedGtsAssembledAnswers {
  const ChedGtsAssembledAnswers({
    required this.answers,
    required this.source,
    this.surveyId,
    this.surveyTitle,
    this.submittedAt,
    this.notes = const [],
    this.missingRequired = const [],
  });

  final Map<String, dynamic> answers;
  final ChedGtsAnswerSource source;
  final String? surveyId;
  final String? surveyTitle;
  final DateTime? submittedAt;
  final List<String> notes;

  /// Visible required items still blank after assembly (for Phase 3 UI).
  final List<String> missingRequired;

  bool get hasAnswers => answers.isNotEmpty;
}

/// Builds CHED GTS answer maps for official PDF export.
///
/// Preferred source: submitted builtin response snapshot.
/// Fallback: live profile + employment via [ChedGtsPrefill.fromProfile].
/// Does not modify survey take/submit flows.
abstract final class ChedGtsAnswerAssembler {
  /// Pure / testable core — no I/O.
  ///
  /// [submittedAnswers] wins over [profile]/[employment] when
  /// [fillGapsFromProfile] is true (via [ChedGtsPrefill.merge]).
  static ChedGtsAssembledAnswers assemble({
    Map<String, dynamic>? submittedAnswers,
    TracerProfile? profile,
    EmploymentRecord? employment,
    bool fillGapsFromProfile = true,
    String? surveyId,
    String? surveyTitle,
    DateTime? submittedAt,
  }) {
    final notes = <String>[];
    final snapshot = _normalizeAnswers(submittedAnswers);
    final hasSnapshot = snapshot.isNotEmpty;

    Map<String, dynamic> live = const {};
    if (fillGapsFromProfile && profile != null) {
      live = ChedGtsPrefill.fromProfile(profile, employment: employment);
    } else if (!hasSnapshot && profile != null) {
      live = ChedGtsPrefill.fromProfile(profile, employment: employment);
    }

    late final Map<String, dynamic> combined;
    late final ChedGtsAnswerSource source;

    if (hasSnapshot && live.isNotEmpty && fillGapsFromProfile) {
      combined = ChedGtsPrefill.merge(existing: snapshot, prefill: live);
      final filledKeys = live.keys
          .where((k) => !_hasValue(snapshot[k]) && _hasValue(combined[k]))
          .toList();
      if (filledKeys.isNotEmpty) {
        source = ChedGtsAnswerSource.merged;
        notes.add(
          'Filled ${filledKeys.length} empty answer(s) from live profile/'
          'employment: ${filledKeys.take(8).join(', ')}'
          '${filledKeys.length > 8 ? ', …' : ''}',
        );
      } else {
        source = ChedGtsAnswerSource.submittedSnapshot;
      }
    } else if (hasSnapshot) {
      combined = Map<String, dynamic>.from(snapshot);
      source = ChedGtsAnswerSource.submittedSnapshot;
      if (!fillGapsFromProfile) {
        notes.add('Live profile fill-in disabled; using submitted snapshot only');
      }
    } else if (live.isNotEmpty) {
      combined = Map<String, dynamic>.from(live);
      source = ChedGtsAnswerSource.liveProfileFallback;
      notes.add(
        'No submitted CHED GTS response; using live profile/employment',
      );
    } else {
      return ChedGtsAssembledAnswers(
        answers: const {},
        source: ChedGtsAnswerSource.empty,
        surveyId: surveyId,
        surveyTitle: surveyTitle,
        submittedAt: submittedAt,
        notes: const [
          'No submitted CHED answers and no live profile data available',
        ],
      );
    }

    final pruned = ChedGtsVisibility.pruneHiddenAnswers(combined);
    final missing = ChedGtsVisibility.missingRequired(pruned);
    if (missing.isNotEmpty) {
      notes.add(
        '${missing.length} required visible item(s) still blank: '
        '${missing.take(8).join(', ')}'
        '${missing.length > 8 ? ', …' : ''}',
      );
    }

    return ChedGtsAssembledAnswers(
      answers: pruned,
      source: source,
      surveyId: surveyId,
      surveyTitle: surveyTitle,
      submittedAt: submittedAt,
      notes: notes,
      missingRequired: missing,
    );
  }

  /// Assemble from data already loaded by admin directory detail (or similar).
  ///
  /// Picks the newest submitted response whose answers look like builtin
  /// CHED (`ched_*` keys), optionally pinned by [surveyId].
  static ChedGtsAssembledAnswers assembleFromLoaded({
    required List<SurveyResponseWithMeta> submittedResponses,
    TracerProfile? profile,
    EmploymentRecord? employment,
    String? surveyId,
    bool fillGapsFromProfile = true,
    Map<String, Survey>? surveysById,
  }) {
    final pick = _pickChedResponse(
      submittedResponses,
      surveyId: surveyId,
      surveysById: surveysById,
    );

    final notes = <String>[];
    if (surveyId != null &&
        surveyId.isNotEmpty &&
        pick == null &&
        submittedResponses.isNotEmpty) {
      notes.add(
        'No submitted CHED response for surveyId=$surveyId; '
        'falling back to live profile if available',
      );
    }

    final assembled = assemble(
      submittedAnswers: pick?.response.answers,
      profile: profile,
      employment: employment,
      fillGapsFromProfile: fillGapsFromProfile,
      surveyId: pick?.response.surveyId,
      surveyTitle: pick?.surveyTitle,
      submittedAt: pick?.response.submittedAt,
    );

    if (notes.isEmpty) return assembled;
    return ChedGtsAssembledAnswers(
      answers: assembled.answers,
      source: assembled.source,
      surveyId: assembled.surveyId,
      surveyTitle: assembled.surveyTitle,
      submittedAt: assembled.submittedAt,
      notes: [...notes, ...assembled.notes],
      missingRequired: assembled.missingRequired,
    );
  }

  /// Loads profile, employment, and submitted responses via existing services.
  static Future<ChedGtsAssembledAnswers> assembleForUser({
    required String userId,
    String? surveyId,
    bool fillGapsFromProfile = true,
    SurveyService? surveyService,
    UserProfileService? profileService,
    IdTracerService? tracerService,
  }) async {
    final surveys = surveyService ?? SurveyService();
    final profiles = profileService ?? UserProfileService();
    final tracer = tracerService ?? IdTracerService();

    final futures = <Future<Object?>>[
      profiles.getTracerProfile(userId),
      tracer.getEmploymentRecordByUserId(userId),
    ];

    if (surveyId != null && surveyId.isNotEmpty) {
      futures.add(surveys.getResponse(surveyId, userId));
      futures.add(surveys.getSurvey(surveyId));
    } else {
      futures.add(surveys.getUserSubmittedResponses(userId));
    }

    final results = await Future.wait(futures);
    final profile = results[0] as TracerProfile?;
    final employment = results[1] as EmploymentRecord?;

    if (surveyId != null && surveyId.isNotEmpty) {
      final response = results[2] as SurveyResponse?;
      final survey = results[3] as Survey?;
      final notes = <String>[];

      Map<String, dynamic>? submitted;
      DateTime? submittedAt;
      String? title = survey?.title;

      if (response != null &&
          response.status == SurveyResponseStatus.submitted &&
          (survey?.isChedGtsBuiltin == true ||
              looksLikeChedGtsAnswers(response.answers))) {
        submitted = response.answers;
        submittedAt = response.submittedAt;
      } else if (response != null &&
          response.status != SurveyResponseStatus.submitted) {
        notes.add(
          'Response for surveyId=$surveyId is not submitted; '
          'ignoring draft for official export',
        );
      } else if (survey != null && !survey.isChedGtsBuiltin) {
        notes.add(
          'Survey "$title" is not a builtin CHED GTS form',
        );
      }

      final assembled = assemble(
        submittedAnswers: submitted,
        profile: profile,
        employment: employment,
        fillGapsFromProfile: fillGapsFromProfile,
        surveyId: surveyId,
        surveyTitle: title,
        submittedAt: submittedAt,
      );

      if (notes.isEmpty) return assembled;
      return ChedGtsAssembledAnswers(
        answers: assembled.answers,
        source: assembled.source,
        surveyId: assembled.surveyId,
        surveyTitle: assembled.surveyTitle,
        submittedAt: assembled.submittedAt,
        notes: [...notes, ...assembled.notes],
        missingRequired: assembled.missingRequired,
      );
    }

    final responses = results[2] as List<SurveyResponseWithMeta>;
    return assembleFromLoaded(
      submittedResponses: responses,
      profile: profile,
      employment: employment,
      surveyId: surveyId,
      fillGapsFromProfile: fillGapsFromProfile,
    );
  }

  /// True when answers look like builtin CHED GTS (`ched_*` keys).
  static bool looksLikeChedGtsAnswers(Map<String, dynamic> answers) {
    for (final key in answers.keys) {
      if (key.startsWith('ched_')) return true;
    }
    return false;
  }

  static SurveyResponseWithMeta? _pickChedResponse(
    List<SurveyResponseWithMeta> responses, {
    String? surveyId,
    Map<String, Survey>? surveysById,
  }) {
    final candidates = responses.where((meta) {
      final r = meta.response;
      if (r.status != SurveyResponseStatus.submitted) return false;
      if (surveyId != null &&
          surveyId.isNotEmpty &&
          r.surveyId != surveyId) {
        return false;
      }
      final survey = surveysById?[r.surveyId];
      if (survey != null) return survey.isChedGtsBuiltin;
      return looksLikeChedGtsAnswers(r.answers);
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aAt = a.response.submittedAt ?? a.response.updatedAt;
      final bAt = b.response.submittedAt ?? b.response.updatedAt;
      return bAt.compareTo(aAt);
    });
    return candidates.first;
  }

  static Map<String, dynamic> _normalizeAnswers(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const {};
    final out = <String, dynamic>{};
    for (final e in raw.entries) {
      if (!_hasValue(e.value)) continue;
      // Deep-ish copy for nested maps/lists so callers can mutate safely.
      final v = e.value;
      if (v is Map) {
        out[e.key] = Map<String, dynamic>.from(v);
      } else if (v is List) {
        out[e.key] = v
            .map((item) => item is Map
                ? Map<String, dynamic>.from(item)
                : item)
            .toList();
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }

  static bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }
}

/// Convenience: schema version this assembler targets.
abstract final class ChedGtsAnswerAssemblerContract {
  static const schemaVersion = ChedGtsBuiltin.schemaVersion;
  static const templateKey = ChedGtsBuiltin.templateKey;
}
