import 'dart:typed_data';

import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_answer_assembler.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/individual_info_sheet_pdf.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/alumni/tracer/data/id_tracer_service.dart';

/// Result of building the alumni Membership Form PDF.
class AlumniMembershipFormPdf {
  const AlumniMembershipFormPdf({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

/// Alumni-facing Membership Form builder (same PDF as admin export).
///
/// Assembles answers from live profile (and any CHED submission if present)
/// without requiring admin [AlumniMember] models.
class AlumniMembershipFormService {
  AlumniMembershipFormService({
    UserProfileService? profileService,
    IdTracerService? tracerService,
    AuditService? auditService,
  })  : _profiles = profileService ?? UserProfileService(),
        _tracer = tracerService ?? IdTracerService(),
        _audit = auditService ?? AuditService();

  final UserProfileService _profiles;
  final IdTracerService _tracer;
  final AuditService _audit;

  /// Builds the Membership Form for [userId] using live-profile gap fill.
  Future<AlumniMembershipFormPdf> buildForUser({
    required String userId,
    required String displayName,
  }) async {
    final assembled = await ChedGtsAnswerAssembler.assembleForUser(
      userId: userId,
      fillGapsFromProfile: true,
      profileService: _profiles,
      tracerService: _tracer,
    );

    if (!assembled.hasAnswers) {
      throw StateError(
        'No profile data available yet to fill the Membership Form.',
      );
    }

    final name = displayName.trim().isEmpty ? 'Alumni' : displayName.trim();
    final bytes = await IndividualInfoSheetPdf.build(
      answers: assembled.answers,
      alumniName: name,
      generatedAt: DateTime.now(),
    );
    final fileName = IndividualInfoSheetPdf.suggestFileName(
      displayName: name,
      surveyLabel: assembled.surveyTitle,
      when: assembled.submittedAt ?? DateTime.now(),
    );

    await _audit.logAction(
      action: AuditActions.downloadMembershipForm,
      resource: 'MembershipForm',
      resourceId: userId,
      description: 'Alumni downloaded Membership Form: $name',
      status: 'SUCCESS',
      module: 'alumni',
      targetLabel: name,
      changes: {
        'fileName': fileName,
        'source': assembled.source.name,
        'surveyId': assembled.surveyId,
        'surveyTitle': assembled.surveyTitle,
        'reportKind': 'membership_form_self',
      },
    );

    return AlumniMembershipFormPdf(bytes: bytes, fileName: fileName);
  }
}
