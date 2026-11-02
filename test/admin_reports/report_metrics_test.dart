import 'package:flutter_test/flutter_test.dart';

import 'package:alumni_system/features/admin/reports/application/report_metrics.dart';

void main() {
  group('ReportMetrics', () {
    test('response rate uses eligible alumni as denominator', () {
      final rate = ReportMetrics.responseRate(
        submittedRespondents: 40,
        eligibleAlumni: 100,
      );
      expect(rate.percent, 40);
      expect(rate.coverageNote, contains('eligible alumni'));
    });

    test('employment rate ignores unanswered status', () {
      final rate = ReportMetrics.employmentRate(
        employedRespondents: 18,
        answeredEmploymentStatus: 20,
      );
      expect(rate.percent, 90);
      expect(rate.totalLabel, 'answered employment status');
    });

    test('zero denominator yields 0% without throwing', () {
      final rate = ReportMetrics.optionShare(
        optionCount: 0,
        answeredCount: 0,
      );
      expect(rate.percent, 0);
      expect(rate.hasDenominator, isFalse);
    });

    test('countFromShare keeps raw counts', () {
      expect(
        ReportMetrics.countFromShare(
          optionCount: 7,
          ignoredRoundedPercent: 33.333,
        ),
        7,
      );
    });
  });
}
