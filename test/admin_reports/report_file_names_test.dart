import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/application/report_file_names.dart';

void main() {
  group('ReportFileNames', () {
    test('builds catalog stem filenames without personal data', () {
      final name = ReportFileNames.forSurveyExportKind(
        kindName: 'chedOutcomes',
        surveyTitle: 'CHED GTS 2026 / Wave A',
        extension: 'pdf',
        at: DateTime(2026, 11, 3),
      );
      expect(name, startsWith('AESS_GTS_Outcomes_'));
      expect(name, contains('CHED_GTS_2026_Wave_A'));
      expect(name, endsWith('_20261103.pdf'));
      expect(name.contains('@'), isFalse);
    });

    test('includes optional cohort scope', () {
      final name = ReportFileNames.forSurveyExportKind(
        kindName: 'pending',
        surveyTitle: 'Tracer',
        extension: 'xlsx',
        batchYear: '2024',
        course: 'BSIT',
        at: DateTime(2026, 1, 2),
      );
      expect(name, startsWith('AESS_Survey_Pending_Assignments_'));
      expect(name, contains('2024_BSIT'));
      expect(name, endsWith('.xlsx'));
    });

    test('safeSlug strips unsafe characters', () {
      expect(
        ReportFileNames.safeSlug('Hello / World??'),
        'Hello_World',
      );
    });
  });
}
