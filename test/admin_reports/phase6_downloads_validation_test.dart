import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/application/institutional_ched_templates.dart';
import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:alumni_system/features/admin/reports/models/report_filter_config.dart';
import 'package:alumni_system/features/admin/reports/widgets/reports_downloads_panel.dart';

/// Contract checks across catalog ↔ Downloads UI ↔ filters ↔ generators.
void main() {
  group('Audience Downloads validation', () {
    test('panel presets are available, filtered, and uniquely ordered', () {
      final panelIds = ReportsDownloadsPanel.presets.map((p) => p.id).toList();
      expect(panelIds.toSet().length, panelIds.length);

      final declared = <String>{
        for (final ids in ReportsDownloadsPanel.categoryPresetIds.values)
          ...ids,
      };
      expect(declared, panelIds.toSet());

      for (final preset in ReportsDownloadsPanel.presets) {
        final entry = AessReportCatalog.byDownloadsPresetId(preset.id);
        expect(entry, isNotNull, reason: preset.id);
        expect(entry!.isAvailable, isTrue, reason: preset.id);
        expect(entry.title, preset.title);
        expect(entry.subtitle, preset.description);
        expect(entry.category, preset.category);

        final schema = ReportFilterSchemas.forDownloadsPreset(preset.id);
        expect(schema, isNotNull, reason: preset.id);
        expect(schema!.catalogId, entry.id);
      }
    });

    test('institutional CHED outcome presets have distinct field sets and stems',
        () {
      for (final id in InstitutionalChedTemplates.outcomePresetIds) {
        final fields = InstitutionalChedTemplates.fieldsFor(id);
        expect(fields, isNotEmpty, reason: id);
        expect(
          fields.map((f) => f.questionId).toSet().length,
          fields.length,
          reason: 'duplicate questionIds in $id',
        );

        final stem = InstitutionalChedTemplates.fileStem(id);
        expect(stem.startsWith('AESS_'), isTrue, reason: id);

        final entry = AessReportCatalog.byDownloadsPresetId(id);
        expect(entry?.fileNameStem, stem, reason: id);
        expect(
          ReportsDownloadsPanel.presets.any((p) => p.id == id),
          isTrue,
          reason: id,
        );
      }
    });

    test('participation quality remains wired under comparisons', () {
      const id = InstitutionalChedTemplates.gtsParticipationQuality;
      expect(InstitutionalChedTemplates.isInstitutionalChedPreset(id), isTrue);
      expect(AessReportCatalog.byDownloadsPresetId(id)?.isAvailable, isTrue);
      expect(
        ReportsDownloadsPanel.presets.any((p) => p.id == id),
        isTrue,
      );
      expect(ReportFilterSchemas.forDownloadsPreset(id), isNotNull);
      expect(AessReportCatalog.planned, isEmpty);
    });

    test('T1 employment pack is narrower than compliance master', () {
      final compliance = InstitutionalChedTemplates.fieldsFor(
        InstitutionalChedTemplates.chedComplianceMaster,
      );
      final employment = InstitutionalChedTemplates.fieldsFor(
        InstitutionalChedTemplates.employmentEmployability,
      );
      expect(employment.length, lessThan(compliance.length));
      expect(
        employment.map((e) => e.questionId),
        containsAll(['ched_16', 'ched_21', 'ched_29']),
      );
      expect(
        InstitutionalChedTemplates.fieldsFor(
          InstitutionalChedTemplates.curriculumCompetency,
        ).map((e) => e.questionId),
        contains('ched_15b'),
      );
    });

    test('every available downloads catalog entry appears on the panel', () {
      final panelIds = {
        for (final p in ReportsDownloadsPanel.presets) p.id,
      };
      for (final entry in AessReportCatalog.available) {
        if (entry.surface != ReportCatalogSurface.downloadsLibrary) continue;
        expect(entry.downloadsPresetId, isNotNull, reason: entry.id);
        expect(
          panelIds.contains(entry.downloadsPresetId),
          isTrue,
          reason: entry.id,
        );
      }
    });
  });
}
