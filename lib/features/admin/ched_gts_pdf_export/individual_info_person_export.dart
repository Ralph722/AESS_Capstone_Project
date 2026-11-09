import 'dart:typed_data';

import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_answer_assembler.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_person_export.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/individual_info_sheet_pdf.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_directory_detail_service.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';

/// Built Individual Information Sheet ready for browser download.
class IndividualInfoPersonExportResult {
  const IndividualInfoPersonExportResult({
    required this.bytes,
    required this.fileName,
    required this.assembled,
  });

  final Uint8List bytes;
  final String fileName;
  final ChedGtsAssembledAnswers assembled;
}

/// Per-person Individual Information Sheet (Section A + Q12) export.
///
/// Reuses [ChedGtsAnswerAssembler] / wave selection helpers from the official
/// CHED PDF path. Does not download files; callers use [tryDownloadBytesOnWeb].
class IndividualInfoPersonExportService {
  IndividualInfoPersonExportService({
    IdTracerService? tracerService,
    UserProfileService? profileService,
    AuditService? auditService,
  })  : _tracer = tracerService ?? IdTracerService(),
        _profiles = profileService ?? UserProfileService(),
        _audit = auditService ?? AuditService();

  final IdTracerService _tracer;
  final UserProfileService _profiles;
  final AuditService _audit;

  /// Build filled PDF bytes for [member].
  Future<IndividualInfoPersonExportResult> buildPdf({
    required AlumniMember member,
    AlumniDirectoryDetail? detail,
    String? surveyId,
    bool fillGapsFromProfile = true,
    bool allowLiveFallback = true,
  }) async {
    final uid = member.authUid;
    if (uid == null || uid.isEmpty || !member.isRegisteredUser) {
      throw StateError(
        'Member is not linked to a registered account; '
        'cannot export Individual Information Sheet',
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
      final waves = ChedGtsPdfPersonExportService.chedWaves(detail.tracerResponses);
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

    final bytes = await IndividualInfoSheetPdf.build(
      answers: assembled.answers,
      alumniName: member.fullName,
      generatedAt: DateTime.now(),
    );

    final fileName = IndividualInfoSheetPdf.suggestFileName(
      displayName: member.fullName,
      surveyLabel: assembled.surveyTitle,
      when: assembled.submittedAt ?? DateTime.now(),
    );

    return IndividualInfoPersonExportResult(
      bytes: bytes,
      fileName: fileName,
      assembled: assembled,
    );
  }

  Future<void> logExportSuccess({
    required AlumniMember member,
    required IndividualInfoPersonExportResult result,
  }) {
    final assembled = result.assembled;
    final resource =
        assembled.surveyId != null ? 'SurveyResponse' : 'AlumniMember';
    final resourceId = assembled.surveyId != null
        ? '${assembled.surveyId}:${member.authUid ?? member.id}'
        : member.id;

    return _audit.logAction(
      action: AuditActions.exportIndividualInfoPdf,
      resource: resource,
      resourceId: resourceId,
      description:
          'Exported Individual Information Sheet for ${member.fullName}'
          '${assembled.surveyTitle != null ? ' (${assembled.surveyTitle})' : ''}',
      userRole: 'admin',
      module: 'reports',
      category: 'security',
      targetLabel: member.fullName,
      changes: {
        'source': assembled.source.name,
        'surveyId': assembled.surveyId,
        'surveyTitle': assembled.surveyTitle,
        'missingRequiredCount': assembled.missingRequired.length,
        'fileName': result.fileName,
        'reportKind': 'individual_info_sheet',
      },
    );
  }

  Future<void> logExportFailure({
    required AlumniMember member,
    required Object error,
    String? surveyId,
  }) {
    return _audit.logAction(
      action: AuditActions.exportIndividualInfoPdf,
      resource: 'AlumniMember',
      resourceId: member.id,
      description:
          'Failed to export Individual Information Sheet for '
          '${member.fullName}: $error',
      userRole: 'admin',
      status: 'FAILED',
      module: 'reports',
      category: 'security',
      targetLabel: member.fullName,
      changes: {
        'surveyId': surveyId,
        'error': error.toString(),
        'reportKind': 'individual_info_sheet',
      },
    );
  }
}
