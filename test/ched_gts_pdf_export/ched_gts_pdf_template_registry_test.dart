import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChedGtsPdfTemplate registry', () {
    test('active template matches builtin schema and catalog size', () {
      expect(ChedGtsPdfTemplate.active.schemaVersion, '3.0.0');
      expect(
        ChedGtsPdfTemplate.active.schemaVersion,
        ChedGtsBuiltin.schemaVersion,
      );
      expect(ChedGtsPdfTemplate.isCompatibleWithBuiltinSchema, isTrue);
      expect(
        ChedGtsPdfTemplate.expectedFieldCount,
        ChedGtsPdfFieldCatalog.fields.length,
      );
      expect(
        ChedGtsPdfTemplate.resolve('3.0.0'),
        same(ChedGtsPdfTemplate.v3_1_0),
      );
      expect(ChedGtsPdfTemplate.resolve('9.9.9'), isNull);
    });

    test('compatibilityNotes include known gaps and survey drift', () {
      final notes = ChedGtsPdfTemplate.compatibilityNotes(
        surveySchemaVersion: '2.0.0',
      );
      expect(notes, isNotEmpty);
      expect(
        notes.any((n) => n.contains('surveySchemaVersion') || n.contains('2.0.0')),
        isTrue,
      );
      expect(
        notes.any(
          (n) =>
              n.toLowerCase().contains('section e') ||
              n.toLowerCase().contains('header') ||
              n.contains('referral'),
        ),
        isTrue,
      );
    });
  });

  group('ChedGtsPdfExportLimits', () {
    test('batchCapMessage includes selected count and max', () {
      final msg = ChedGtsPdfExportLimits.batchCapMessage(150);
      expect(msg, contains('150'));
      expect(msg, contains('${ChedGtsPdfExportLimits.maxBatchSize}'));
      expect(ChedGtsPdfExportLimits.maxBatchSize, 100);
      expect(ChedGtsPdfExportLimits.batchWarnSize, lessThanOrEqualTo(100));
    });
  });
}
