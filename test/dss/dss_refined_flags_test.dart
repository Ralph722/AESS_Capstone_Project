import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> q30({String? first, String? current}) => {
    if (first != null) first: {DssMetrics.firstJobCol: true},
    if (current != null) current: {DssMetrics.currentJobCol: true},
  };

  group('DssMetrics refined flags', () {
    test('longTimeToJob includes 7 to 11 months', () {
      expect(
        DssMetrics.longTimeToFirstJob([
          {'ched_29': 'Less than a month'},
          {'ched_29': '1 to 6 months'},
          {'ched_29': '7 to 11 months'},
          {'ched_29': '1 year to less than 2 years'},
          {'ched_29': 'Others, please specify'},
        ]),
        isA<DssProportion>()
            .having((p) => p.hits, 'hits', 2)
            .having((p) => p.total, 'total', 4),
      );
    });

    test('institutionalPlacement uses school and PESO channels', () {
      expect(
        DssMetrics.institutionalPlacement([
          {'ched_28': 'Response to an advertisement'},
          {
            'ched_28':
                "Arranged by school's job placement officer",
          },
          {
            'ched_28':
                'Job Fair or Public Employment Service Office (PESO)',
          },
          {'ched_28': 'Others, please specify'},
        ]),
        isA<DssProportion>()
            .having((p) => p.hits, 'hits', 2)
            .having((p) => p.total, 'total', 3),
      );
    });

    test('lowEntrySalary uses the bottom two brackets', () {
      expect(
        DssMetrics.lowEntrySalary([
          {'ched_31': 'Below P5,000.00'},
          {'ched_31': 'P5,000.00 to less than P10,000.00'},
          {'ched_31': 'P10,000.00 to less than P15,000.00'},
          {'ched_31': 'P25,000.00 and above'},
        ]),
        isA<DssProportion>()
            .having((p) => p.hits, 'hits', 2)
            .having((p) => p.total, 'total', 4),
      );
    });

    test('qualificationMismatch requires Q24 No and Q30.1 clerical', () {
      expect(
        DssMetrics.qualificationMismatch([
          {
            'ched_24a': 'No',
            'ched_30': q30(first: 'Rank or Clerical'),
          },
          {
            'ched_24a': 'No',
            'ched_30': q30(first: 'Professional, Technical or Supervisory'),
          },
          {
            'ched_24a': 'Yes',
            'ched_30': q30(first: 'Rank or Clerical'),
          },
          {
            // Current-only clerical does not count for Option B.
            'ched_24a': 'No',
            'ched_30': q30(current: 'Rank or Clerical'),
          },
        ]),
        isA<DssProportion>()
            .having((p) => p.hits, 'hits', 1)
            .having((p) => p.total, 'total', 3),
      );
    });
  });
}
