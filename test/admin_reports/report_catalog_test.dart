import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';

void main() {
  group('AessReportCatalog', () {
    test('available survey modal entries keep stable kind wiring', () {
      final ched = AessReportCatalog.surveyModalEntries(isChedGts: true);
      expect(ched.map((e) => e.surveyExportKindName).toList(), [
        'responses',
        'management',
        'chedOutcomes',
        'ched',
        'chedFillable',
        'pending',
      ]);

      final custom = AessReportCatalog.surveyModalEntries(isChedGts: false);
      expect(custom.map((e) => e.surveyExportKindName).toList(), [
        'responses',
        'management',
        'pending',
      ]);
    });

    test('downloads presets map one-to-one to available catalog entries', () {
      const presetIds = [
        'employment_employability',
        'curriculum_competency',
        'industry_placement',
        'career_mobility',
        'ched_compliance_master',
        'gts_participation_quality',
        'executive',
        'ched',
        'ched_wave_compare',
        'tracer',
        'survey',
        'roster',
      ];
      for (final id in presetIds) {
        final entry = AessReportCatalog.byDownloadsPresetId(id);
        expect(entry, isNotNull, reason: id);
        expect(entry!.isAvailable, isTrue);
        expect(entry.surface, ReportCatalogSurface.downloadsLibrary);
        expect(entry.scope, ReportScopeKind.institutional);
        expect(entry.title, isNotEmpty);
        expect(entry.subtitle, isNotEmpty);
      }
    });

    test('survey and institutional scopes stay separated', () {
      for (final entry in AessReportCatalog.available) {
        if (entry.surface == ReportCatalogSurface.surveyExportModal) {
          expect(entry.scope, ReportScopeKind.surveySpecific);
        }
        if (entry.surface == ReportCatalogSurface.downloadsLibrary) {
          expect(entry.scope, ReportScopeKind.institutional);
        }
      }
    });

    test('phase-1 renames are in place for confusing titles', () {
      expect(
        AessReportCatalog.bySurveyExportKindName('management')!.title,
        'Survey management summary',
      );
      expect(
        AessReportCatalog.bySurveyExportKindName('pending')!.title,
        'Pending assignments',
      );
      expect(
        AessReportCatalog.byDownloadsPresetId('executive')!.title,
        'Portal executive snapshot',
      );
      expect(
        AessReportCatalog.byDownloadsPresetId('tracer')!.title,
        'Alumni employment records extract',
      );
      expect(
        AessReportCatalog.byDownloadsPresetId('ched')!.title,
        'CHED GTS portfolio pack',
      );
      expect(
        AessReportCatalog.byDownloadsPresetId('roster')!.title,
        'Active alumni list extract',
      );
    });

    test('audience institutional GTS template set is available in Downloads', () {
      for (final id in [
        'employment_employability',
        'curriculum_competency',
        'industry_placement',
        'career_mobility',
        'ched_compliance_master',
        'gts_participation_quality',
      ]) {
        expect(
          AessReportCatalog.byDownloadsPresetId(id)?.isAvailable,
          isTrue,
          reason: id,
        );
      }
      expect(
        AessReportCatalog.byDownloadsPresetId('institutional_gts'),
        isNull,
      );
      expect(
        AessReportCatalog.byDownloadsPresetId('program_cohort_comparison'),
        isNull,
      );
      expect(AessReportCatalog.planned, isEmpty);
    });

    test('every available entry has a file name stem and privacy class', () {
      for (final entry in AessReportCatalog.available) {
        expect(entry.fileNameStem, isNotNull, reason: entry.id);
        expect(entry.fileNameStem, isNotEmpty, reason: entry.id);
        expect(entry.fileNameStem!.startsWith('AESS_'), isTrue, reason: entry.id);
      }
    });
  });
}
