import 'dart:typed_data';

import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_answer_assembler.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_fill_engine.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_template.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_directory_detail_service.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Built official CHED GTS PDF ready for browser download.
class ChedGtsPdfPersonExportResult {
  const ChedGtsPdfPersonExportResult({
    required this.bytes,
    required this.fileName,
    required this.assembled,
    required this.filled,
    this.flatten = false,
  });

  final Uint8List bytes;
  final String fileName;
  final ChedGtsAssembledAnswers assembled;
  final ChedGtsPdfFillResult filled;

  /// True when AcroForm fields were flattened (print-ready).
  final bool flatten;
}

/// Per-person official CHED GTS PDF export (assemble → fill → audit helpers).
///
/// Does not download files; callers use [tryDownloadBytesOnWeb].
class ChedGtsPdfPersonExportService {
  ChedGtsPdfPersonExportService({
    IdTracerService? tracerService,
    UserProfileService? profileService,
    AuditService? auditService,
  })  : _tracer = tracerService ?? IdTracerService(),
        _profiles = profileService ?? UserProfileService(),
        _audit = auditService ?? AuditService();

  final IdTracerService _tracer;
  final UserProfileService _profiles;
  final AuditService _audit;

  /// CHED waves from a member's submitted survey history (newest first).
  static List<SurveyResponseWithMeta> chedWaves(
    List<SurveyResponseWithMeta> responses,
  ) {
    final waves = responses
        .where(
          (m) =>
              m.response.status == SurveyResponseStatus.submitted &&
              ChedGtsAnswerAssembler.looksLikeChedGtsAnswers(
                m.response.answers,
              ),
        )
        .toList();
    waves.sort((a, b) {
      final aAt = a.response.submittedAt ?? a.response.updatedAt;
      final bAt = b.response.submittedAt ?? b.response.updatedAt;
      return bAt.compareTo(aAt);
    });
    return waves;
  }

  /// Build filled PDF bytes for [member].
  ///
  /// Prefers [detail] when provided; otherwise loads profile + responses via
  /// [ChedGtsAnswerAssembler.assembleForUser].
  Future<ChedGtsPdfPersonExportResult> buildOfficialPdf({
    required AlumniMember member,
    AlumniDirectoryDetail? detail,
    String? surveyId,
    bool fillGapsFromProfile = true,
    bool flatten = false,
    Uint8List? templateBytes,
    /// When true and no CHED wave exists, still export from live profile.
    bool allowLiveFallback = true,
  }) async {
    final uid = member.authUid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'Member is not linked to a registered account; cannot export CHED GTS PDF',
      );
    }

    EmploymentRecord? employment;
    try {
      employment = await _tracer.getEmploymentRecordByUserId(uid);
    } catch (_) {
      employment = null;
    }

    late final ChedGtsAssembledAnswers assembled;
    if (detail != null) {
      final waves = chedWaves(detail.tracerResponses);
      if (waves.isEmpty && !allowLiveFallback) {
        throw StateError('No submitted CHED GTS response for this alumni');
      }
      assembled = ChedGtsAnswerAssembler.assembleFromLoaded(
        submittedResponses: detail.tracerResponses,
        profile: detail.tracer,
        employment: employment,
        surveyId: surveyId,
        fillGapsFromProfile: fillGapsFromProfile,
      );
    } else {
      assembled = await ChedGtsAnswerAssembler.assembleForUser(
        userId: uid,
        surveyId: surveyId,
        fillGapsFromProfile: fillGapsFromProfile,
        profileService: _profiles,
        tracerService: _tracer,
      );
    }

    if (!assembled.hasAnswers) {
      throw StateError(
        'No CHED GTS answers available (no submission and no live profile data)',
      );
    }

    if (assembled.source == ChedGtsAnswerSource.liveProfileFallback &&
        !allowLiveFallback) {
      throw StateError('No submitted CHED GTS response for this alumni');
    }

    final filled = await ChedGtsPdfFillEngine.fillFromAnswers(
      answers: assembled.answers,
      flatten: flatten,
      templateBytes: templateBytes,
    );

    final fileName = ChedGtsPdfFillEngine.suggestFileName(
      displayName: member.fullName,
      surveyLabel: assembled.surveyTitle,
      when: assembled.submittedAt ?? DateTime.now(),
    );

    return ChedGtsPdfPersonExportResult(
      bytes: filled.bytes,
      fileName: fileName,
      assembled: assembled,
      filled: filled,
      flatten: flatten,
    );
  }

  /// Audit a successful official PDF download (admin-only action).
  Future<void> logExportSuccess({
    required AlumniMember member,
    required ChedGtsPdfPersonExportResult result,
  }) {
    final assembled = result.assembled;
    final resource = assembled.surveyId != null ? 'SurveyResponse' : 'AlumniMember';
    final resourceId = assembled.surveyId != null
        ? '${assembled.surveyId}:${member.authUid ?? member.id}'
        : member.id;

    return _audit.logAction(
      action: 'EXPORT_CHED_GTS_PDF',
      resource: resource,
      resourceId: resourceId,
      description:
          'Exported official CHED GTS PDF for ${member.fullName}'
          '${assembled.surveyTitle != null ? ' (${assembled.surveyTitle})' : ''}',
      userRole: 'admin',
      changes: {
        'source': assembled.source.name,
        'surveyId': assembled.surveyId,
        'surveyTitle': assembled.surveyTitle,
        'templateId': ChedGtsPdfTemplate.templateId,
        'schemaVersion': ChedGtsPdfTemplate.schemaVersion,
        'appliedFieldCount': result.filled.appliedFieldCount,
        'missingRequiredCount': assembled.missingRequired.length,
        'fileName': result.fileName,
        'printReady': result.flatten,
        'fitNotes': result.filled.notes
            .where(
              (n) =>
                  n.startsWith('OVERFLOW') ||
                  n.startsWith('Cleared MaxLen'),
            )
            .toList(),
      },
    );
  }

  Future<void> logExportFailure({
    required AlumniMember member,
    required Object error,
    String? surveyId,
  }) {
    return _audit.logAction(
      action: 'EXPORT_CHED_GTS_PDF',
      resource: 'AlumniMember',
      resourceId: member.id,
      description:
          'Failed to export official CHED GTS PDF for ${member.fullName}: $error',
      userRole: 'admin',
      status: 'FAILED',
      changes: {
        'surveyId': surveyId,
        'error': error.toString(),
      },
    );
  }
}
