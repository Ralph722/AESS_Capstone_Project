import 'package:alumni_system/features/admin/reports/application/report_percent_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatReportPercent', () {
    test('keeps one decimal when needed; drops trailing .0', () {
      expect(formatReportPercent(0.375), '37.5%');
      expect(formatReportPercent(2 / 3), '66.7%');
      expect(formatReportPercent(0.2), '20%');
      expect(formatReportPercent(1), '100%');
      expect(formatReportPercent(0), '0%');
    });
  });

  group('formatReportPercentPoints', () {
    test('formats values already in percent points', () {
      expect(formatReportPercentPoints(72.727), '72.7%');
      expect(formatReportPercentPoints(20), '20%');
      expect(formatReportPercentPoints(0), '0%');
    });
  });
}
