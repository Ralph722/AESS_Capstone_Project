import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
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
    SupabaseClient? supabase,
  }) : _profiles = profileService ?? UserProfileService(),
       _tracer = tracerService ?? IdTracerService(),
       _audit = auditService ?? AuditService(),
       _supabase = supabase ?? Supabase.instance.client;

  /// How long Profile may offer re-download after the first successful download.
  static const Duration profileRedownloadWindow = Duration(days: 30);

  final UserProfileService _profiles;
  final IdTracerService _tracer;
  final AuditService _audit;
  final SupabaseClient _supabase;

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

  /// First successful download time, or null if never recorded.
  Future<DateTime?> fetchDownloadedAt(String userId) async {
    try {
      final row = await _supabase
          .from('users')
          .select('membership_form_downloaded_at')
          .eq('id', userId)
          .maybeSingle();
      final raw = row?['membership_form_downloaded_at'];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString())?.toUtc();
    } catch (_) {
      return null;
    }
  }

  /// Records the first download only (idempotent). Returns the stored time.
  Future<DateTime> markDownloaded(String userId) async {
    final existing = await fetchDownloadedAt(userId);
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    await _supabase
        .from('users')
        .update({
          'membership_form_downloaded_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        })
        .eq('id', userId);
    return now;
  }

  /// Whether Profile should offer Preview / Download.
  static bool isProfileDownloadAvailable(
    DateTime? downloadedAt, {
    DateTime? now,
    Duration window = profileRedownloadWindow,
  }) {
    if (downloadedAt == null) return false;
    final n = (now ?? DateTime.now()).toUtc();
    final start = downloadedAt.toUtc();
    return !n.isAfter(start.add(window));
  }

  /// Days remaining in the Profile window (0 if expired / never downloaded).
  static int profileDaysRemaining(
    DateTime? downloadedAt, {
    DateTime? now,
    Duration window = profileRedownloadWindow,
  }) {
    if (downloadedAt == null) return 0;
    final remaining = downloadedAt.toUtc().add(window).difference(
      (now ?? DateTime.now()).toUtc(),
    );
    if (remaining <= Duration.zero) return 0;
    return remaining.inDays < 1 ? 1 : remaining.inDays;
  }
}
