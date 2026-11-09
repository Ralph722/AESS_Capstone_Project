import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_batch_export.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_template.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/individual_info_person_export.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';

/// Result of building a ZIP of Individual Information Sheets.
class IndividualInfoBatchExportResult {
  const IndividualInfoBatchExportResult({
    required this.zipBytes,
    required this.zipFileName,
    required this.successCount,
    required this.failures,
    required this.attemptedCount,
  });

  final Uint8List zipBytes;
  final String zipFileName;
  final int successCount;
  final List<ChedGtsPdfBatchFailure> failures;
  final int attemptedCount;

  bool get hasZip => successCount > 0;
}

/// Batch Individual Information Sheet PDFs → ZIP.
class IndividualInfoBatchExportService {
  IndividualInfoBatchExportService({
    IndividualInfoPersonExportService? personExport,
    AuditService? auditService,
  })  : _personOverride = personExport,
        _auditOverride = auditService;

  final IndividualInfoPersonExportService? _personOverride;
  final AuditService? _auditOverride;
  IndividualInfoPersonExportService? _personLazy;
  AuditService? _auditLazy;

  IndividualInfoPersonExportService get _person =>
      _personOverride ?? (_personLazy ??= IndividualInfoPersonExportService());

  AuditService get _audit =>
      _auditOverride ?? (_auditLazy ??= AuditService());

  /// Build a ZIP of Individual Information Sheets for registered [members].
  Future<IndividualInfoBatchExportResult> buildZip({
    required List<AlumniMember> members,
    String? surveyId,
    bool fillGapsFromProfile = true,
    bool allowLiveFallback = true,
    bool auditEachPerson = true,
    ChedGtsPdfBatchProgress? onProgress,
  }) async {
    ChedGtsPdfBatchExportService.ensureWithinBatchLimit(members.length);

    final failures = <ChedGtsPdfBatchFailure>[];
    final archive = Archive();
    final usedNames = <String>{};
    var success = 0;
    final total = members.length;

    for (var i = 0; i < members.length; i++) {
      final member = members[i];
      onProgress?.call(i, total, member.fullName);

      final uid = member.authUid;
      if (uid == null || uid.isEmpty || !member.isRegisteredUser) {
        failures.add(
          ChedGtsPdfBatchFailure(
            memberId: member.id,
            memberName: member.fullName,
            reason: 'Not registered / no linked account',
          ),
        );
        if (auditEachPerson) {
          await _person.logExportFailure(
            member: member,
            error: 'Not registered / no linked account',
            surveyId: surveyId,
          );
        }
        continue;
      }

      try {
        final result = await _person.buildPdf(
          member: member,
          surveyId: surveyId,
          fillGapsFromProfile: fillGapsFromProfile,
          allowLiveFallback: allowLiveFallback,
        );
        final entryName = ChedGtsPdfBatchExportService.uniqueEntryName(
          result.fileName,
          usedNames,
        );
        archive.addFile(
          ArchiveFile(entryName, result.bytes.length, result.bytes),
        );
        success++;
        if (auditEachPerson) {
          await _person.logExportSuccess(member: member, result: result);
        }
      } catch (e) {
        failures.add(
          ChedGtsPdfBatchFailure(
            memberId: member.id,
            memberName: member.fullName,
            reason: e.toString(),
          ),
        );
        if (auditEachPerson) {
          await _person.logExportFailure(
            member: member,
            error: e,
            surveyId: surveyId,
          );
        }
      }
    }

    onProgress?.call(total, total, null);

    if (success == 0) {
      throw StateError(
        failures.isEmpty
            ? 'No alumni selected for Individual Information Sheet batch export'
            : 'No PDFs generated (${failures.length} skipped/failed)',
      );
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Failed to encode Individual Information Sheet ZIP');
    }

    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final zipName = 'Membership-Form-batch-$stamp-$success-pdfs.zip';

    return IndividualInfoBatchExportResult(
      zipBytes: Uint8List.fromList(encoded),
      zipFileName: zipName,
      successCount: success,
      failures: failures,
      attemptedCount: total,
    );
  }

  Future<void> logBatchSuccess({
    required IndividualInfoBatchExportResult result,
    required int selectedCount,
  }) {
    return _audit.logAction(
      action: AuditActions.exportIndividualInfoPdfBatch,
      resource: 'AlumniMember',
      resourceId: 'batch',
      description:
          'Exported Individual Information Sheet batch ZIP '
          '(${result.successCount} of $selectedCount)',
      userRole: 'admin',
      module: 'reports',
      category: 'security',
      changes: {
        'selectedCount': selectedCount,
        'attemptedCount': result.attemptedCount,
        'successCount': result.successCount,
        'failureCount': result.failures.length,
        'fileName': result.zipFileName,
        'reportKind': 'individual_info_sheet',
        'maxBatchSize': ChedGtsPdfExportLimits.maxBatchSize,
        'failures': result.failures
            .take(25)
            .map(
              (f) => {
                'memberId': f.memberId,
                'memberName': f.memberName,
                'reason': f.reason,
              },
            )
            .toList(),
      },
    );
  }

  Future<void> logBatchFailure({
    required Object error,
    required int selectedCount,
  }) {
    return _audit.logAction(
      action: AuditActions.exportIndividualInfoPdfBatch,
      resource: 'AlumniMember',
      resourceId: 'batch',
      description: 'Failed Individual Information Sheet batch ZIP: $error',
      userRole: 'admin',
      status: 'FAILED',
      module: 'reports',
      category: 'security',
      changes: {
        'selectedCount': selectedCount,
        'error': error.toString(),
        'reportKind': 'individual_info_sheet',
      },
    );
  }
}
