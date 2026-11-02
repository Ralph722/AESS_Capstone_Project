import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:intl/intl.dart';

/// Safe, descriptive download names for AESS reports.
///
/// Avoids personal identifiers in filenames. Uses catalog stems when present.
abstract final class ReportFileNames {
  static final _date = DateFormat('yyyyMMdd');

  /// Filename-safe slug from a survey or cohort label.
  static String safeSlug(String raw, {int maxLen = 48}) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[^\w\-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (cleaned.isEmpty) return 'export';
    if (cleaned.length <= maxLen) return cleaned;
    return cleaned.substring(0, maxLen);
  }

  static String dated({
    required String stem,
    required String extension,
    String? surveyTitle,
    String? cohortScope,
    DateTime? at,
  }) {
    final parts = <String>[stem];
    final survey = surveyTitle?.trim();
    if (survey != null && survey.isNotEmpty) {
      parts.add(safeSlug(survey));
    }
    final cohort = cohortScope?.trim();
    if (cohort != null && cohort.isNotEmpty) {
      parts.add(safeSlug(cohort, maxLen: 32));
    }
    parts.add(_date.format(at ?? DateTime.now()));
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '${parts.join('_')}.$ext';
  }

  /// Optional batch/course slice for open-to-all CHED filters.
  static String? cohortScopeLabel({String? batchYear, String? course}) {
    final parts = <String>[];
    if (batchYear != null && batchYear.trim().isNotEmpty) {
      parts.add(batchYear.trim());
    }
    if (course != null && course.trim().isNotEmpty) {
      parts.add(course.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join('_');
  }

  /// [kindName] matches `SurveyExportReportKind.name`.
  static String forSurveyExportKind({
    required String kindName,
    required String surveyTitle,
    required String extension,
    String? batchYear,
    String? course,
    DateTime? at,
  }) {
    final entry = AessReportCatalog.bySurveyExportKindName(kindName);
    final stem = entry?.fileNameStem ?? 'AESS_Survey_Export';
    return dated(
      stem: stem,
      extension: extension,
      surveyTitle: surveyTitle,
      cohortScope: cohortScopeLabel(batchYear: batchYear, course: course),
      at: at,
    );
  }
}
