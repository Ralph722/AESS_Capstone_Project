import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_fill_engine.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_person_export.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_template.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:intl/intl.dart';

/// One alumni skipped or failed during batch official PDF export.
class ChedGtsPdfBatchFailure {
  const ChedGtsPdfBatchFailure({
    required this.memberId,
    required this.memberName,
    required this.reason,
  });

  final String memberId;
  final String memberName;
  final String reason;
}

/// Result of building a ZIP of official CHED GTS PDFs.
class ChedGtsPdfBatchExportResult {
  const ChedGtsPdfBatchExportResult({
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

typedef ChedGtsPdfBatchProgress = void Function(
  int completed,
  int total,
  String? currentName,
);

/// Batch official CHED GTS PDF → ZIP (reuses [ChedGtsPdfPersonExportService]).
class ChedGtsPdfBatchExportService {
  ChedGtsPdfBatchExportService({
    ChedGtsPdfPersonExportService? personExport,
    AuditService? auditService,
  })  : _personOverride = personExport,
        _auditOverride = auditService;

  final ChedGtsPdfPersonExportService? _personOverride;
  final AuditService? _auditOverride;
  ChedGtsPdfPersonExportService? _personLazy;
  AuditService? _auditLazy;

  ChedGtsPdfPersonExportService get _person =>
      _personOverride ?? (_personLazy ??= ChedGtsPdfPersonExportService());

  AuditService get _audit =>
      _auditOverride ?? (_auditLazy ??= AuditService());

  /// Throws [StateError] when [count] exceeds [ChedGtsPdfExportLimits.maxBatchSize].
  static void ensureWithinBatchLimit(int count) {
    if (count > ChedGtsPdfExportLimits.maxBatchSize) {
      throw StateError(ChedGtsPdfExportLimits.batchCapMessage(count));
    }
  }

  /// Build a ZIP of filled PDFs for [members].
  ///
  /// Continues on per-person errors. Throws [StateError] if zero PDFs succeed
  /// or if [members] exceeds [ChedGtsPdfExportLimits.maxBatchSize].
  Future<ChedGtsPdfBatchExportResult> buildZip({
    required List<AlumniMember> members,
    String? surveyId,
    bool fillGapsFromProfile = true,
    bool allowLiveFallback = true,
    bool flatten = false,
    bool auditEachPerson = true,
    ChedGtsPdfBatchProgress? onProgress,
    Uint8List? templateBytes,
  }) async {
    ensureWithinBatchLimit(members.length);

    final sharedTemplate =
        templateBytes ?? await ChedGtsPdfFillEngine.loadTemplateBytes();
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
        final result = await _person.buildOfficialPdf(
          member: member,
          surveyId: surveyId,
          fillGapsFromProfile: fillGapsFromProfile,
          allowLiveFallback: allowLiveFallback,
          flatten: flatten,
          templateBytes: sharedTemplate,
        );
        final entryName = uniqueEntryName(result.fileName, usedNames);
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
            ? 'No alumni selected for CHED GTS PDF batch export'
            : 'No PDFs generated (${failures.length} skipped/failed)',
      );
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Failed to encode CHED GTS PDF ZIP');
    }

    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final zipName = 'GTS-batch-$stamp-$success-pdfs.zip';

    return ChedGtsPdfBatchExportResult(
      zipBytes: Uint8List.fromList(encoded),
      zipFileName: zipName,
      successCount: success,
      failures: failures,
      attemptedCount: total,
    );
  }

  Future<void> logBatchSuccess({
    required ChedGtsPdfBatchExportResult result,
    required int selectedCount,
  }) {
    return _audit.logAction(
      action: 'EXPORT_CHED_GTS_PDF_BATCH',
      resource: 'AlumniMember',
      resourceId: 'batch',
      description:
          'Exported official CHED GTS PDF batch ZIP '
          '(${result.successCount} of $selectedCount)',
      userRole: 'admin',
      changes: {
        'selectedCount': selectedCount,
        'attemptedCount': result.attemptedCount,
        'successCount': result.successCount,
        'failureCount': result.failures.length,
        'fileName': result.zipFileName,
        'templateId': ChedGtsPdfTemplate.templateId,
        'schemaVersion': ChedGtsPdfTemplate.schemaVersion,
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
      action: 'EXPORT_CHED_GTS_PDF_BATCH',
      resource: 'AlumniMember',
      resourceId: 'batch',
      description: 'Failed official CHED GTS PDF batch ZIP: $error',
      userRole: 'admin',
      status: 'FAILED',
      changes: {
        'selectedCount': selectedCount,
        'error': error.toString(),
      },
    );
  }

  /// Deduplicate ZIP entry names (`report.pdf`, `report-2.pdf`, …).
  static String uniqueEntryName(String fileName, Set<String> used) {
    if (used.add(fileName)) return fileName;
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    var n = 2;
    while (true) {
      final candidate = '$stem-$n$ext';
      if (used.add(candidate)) return candidate;
      n++;
    }
  }
}
