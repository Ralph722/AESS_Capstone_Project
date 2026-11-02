import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/models/report_catalog.dart';
import 'package:alumni_system/features/admin/reports/models/report_filter_config.dart';

void main() {
  group('ReportFilterSchemas', () {
    test('every available Downloads catalog entry has a filter schema', () {
      final downloads = AessReportCatalog.available.where(
        (e) => e.surface == ReportCatalogSurface.downloadsLibrary,
      );
      for (final entry in downloads) {
        final schema = ReportFilterSchemas.byCatalogId(entry.id);
        expect(schema, isNotNull, reason: entry.id);
        expect(schema!.catalogId, entry.id);
      }
    });

    test('wave comparison requires multi-wave selection', () {
      final schema = ReportFilterSchemas.forDownloadsPreset('ched_wave_compare');
      expect(schema, isNotNull);
      expect(schema!.requiredKeys, contains(ReportFilterKey.surveyWaves));
      expect(schema.supports(ReportFilterKey.batchYear), isTrue);
    });

    test('selection constrainedTo drops unsupported keys', () {
      final schema = ReportFilterSchemas.byCatalogId(
        'downloads.survey_participation',
      )!;
      const selection = ReportFilterSelection(
        batchYear: '2024',
        course: 'BSIT',
        surveyType: 'Official CHED GTS',
      );
      final constrained = selection.constrainedTo(schema);
      expect(constrained.batchYear, isNull);
      expect(constrained.course, isNull);
      expect(constrained.surveyType, 'Official CHED GTS');
    });

    test('institutional GTS summary declares cohort and wave filters', () {
      final schema = ReportFilterSchemas.byCatalogId(
        'downloads.institutional_gts_summary',
      )!;
      expect(schema.supports(ReportFilterKey.batchYear), isTrue);
      expect(schema.supports(ReportFilterKey.course), isTrue);
      expect(schema.supports(ReportFilterKey.surveyWaves), isTrue);
    });

    test('program cohort comparison supports compare-by via surveyType', () {
      final schema = ReportFilterSchemas.forDownloadsPreset(
        'program_cohort_comparison',
      )!;
      expect(schema.supports(ReportFilterKey.surveyType), isTrue);
      expect(schema.supports(ReportFilterKey.surveyWaves), isTrue);
    });
  });
}
