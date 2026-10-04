import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

/// One registered official CHED GTS fillable PDF template version.
class ChedGtsPdfTemplateSpec {
  const ChedGtsPdfTemplateSpec({
    required this.schemaVersion,
    required this.assetPath,
    required this.expectedFieldCount,
    required this.displayName,
    this.notes = const [],
  });

  /// Aligns with [ChedGtsBuiltin.schemaVersion] when this is the active form.
  final String schemaVersion;
  final String assetPath;
  final int expectedFieldCount;
  final String displayName;

  /// Human notes (gaps vs app schema, PDF wording differences, etc.).
  final List<String> notes;
}

/// Registry of official CHED GTS PDF templates (current + future versions).
///
/// Fill/export code should resolve through [active] / [resolve] so a future
/// asset can be registered without rewriting callers.
abstract final class ChedGtsPdfTemplate {
  static const templateId = 'ched_gts_official_pdf';

  /// Legacy condensed digital copy (Letter, 90 fields). Kept for reference.
  static const ChedGtsPdfTemplateSpec v3_0_0 = ChedGtsPdfTemplateSpec(
    schemaVersion: '3.0.0',
    assetPath: 'assets/ched_gts/CHED-GTS-v3.0.0-fillable.pdf',
    expectedFieldCount: 90,
    displayName: 'CHED GTS fillable v3.0.0 (legacy condensed)',
    notes: [
      'Legacy template — superseded by v3.1.0 official-aligned fillable',
      'Graduate course-reason column (ched_14) had no PDF fields',
      'Most "Others, please specify" free-text answers had no PDF destination',
      'App region ARMM was written as PDF BARMM',
    ],
  );

  /// Official-aligned fillable (A4, numbered items, others-specify, Grad column).
  static const ChedGtsPdfTemplateSpec v3_1_0 = ChedGtsPdfTemplateSpec(
    schemaVersion: '3.0.0',
    assetPath: 'assets/ched_gts/CHED-GTS-v3.1.0-fillable.pdf',
    expectedFieldCount: 130,
    displayName:
        'CHED Graduate Tracer Study (GTS) — Official-aligned PDF v3.1.0',
    notes: [
      'Aligned to official CHED GTS structure (A–D; items 1-34)',
      'Header left blank (campus export copy; not official CHED letterhead)',
      'Section E alumni referrals omitted by design',
      'Paper duplicate 24 and missing 26 renumbered as 24, 25, 26',
    ],
  );

  static const List<ChedGtsPdfTemplateSpec> all = [v3_1_0, v3_0_0];

  static ChedGtsPdfTemplateSpec get active => v3_1_0;

  /// Convenience aliases used across export/audit code.
  static String get schemaVersion => active.schemaVersion;
  static String get assetPath => active.assetPath;
  static String get displayName => active.displayName;
  static int get expectedFieldCount => active.expectedFieldCount;

  /// Look up a registered template by schema version (e.g. `3.0.0`).
  /// Prefer [active] when multiple revisions share the same schema version.
  static ChedGtsPdfTemplateSpec? resolve(String schemaVersion) {
    if (schemaVersion == active.schemaVersion) return active;
    for (final spec in all) {
      if (spec.schemaVersion == schemaVersion) return spec;
    }
    return null;
  }

  /// True when the active PDF template matches the built-in survey schema.
  static bool get isCompatibleWithBuiltinSchema =>
      active.schemaVersion == ChedGtsBuiltin.schemaVersion;

  /// Soft warnings for operators (version drift, known gaps).
  static List<String> compatibilityNotes({String? surveySchemaVersion}) {
    final notes = <String>[...active.notes];
    if (!isCompatibleWithBuiltinSchema) {
      notes.add(
        'Active PDF template v${active.schemaVersion} differs from '
        'ChedGtsBuiltin schema v${ChedGtsBuiltin.schemaVersion}',
      );
    }
    if (surveySchemaVersion != null &&
        surveySchemaVersion.isNotEmpty &&
        surveySchemaVersion != active.schemaVersion) {
      notes.add(
        'Survey schemaVersion=$surveySchemaVersion differs from active '
        'PDF template v${active.schemaVersion}',
      );
    }
    return notes;
  }
}

/// Operational limits for client-side official PDF export (web admin).
abstract final class ChedGtsPdfExportLimits {
  /// Max alumni per ZIP in one browser session (Syncfusion fill is heavy).
  static const maxBatchSize = 100;

  /// Warn in UI when selection exceeds this (still allowed up to [maxBatchSize]).
  static const batchWarnSize = 25;

  static String batchCapMessage(int selectedCount) =>
      'Batch limited to $maxBatchSize alumni at a time '
      '(selected $selectedCount). Narrow the selection or export in chunks.';
}
