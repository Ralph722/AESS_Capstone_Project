// What today's DSS metrics produce for the demo dataset. When a DSS phase
// changes a definition (for example Q29 "Others" leaving the denominator in
// Phase 1), the matching expectation here changes with it.
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/demo_data/demo_dataset.dart';

void main() {
  final dataset = DemoDataset.build();

  ({int hits, int total}) share(DssProportion? p) =>
      (hits: p!.hits, total: p.total);

  group('not employed (Q16)', () {
    test('BSIT 2022 rises between waves (trend)', () {
      expect(
        share(
          DssMetrics.unemployment(dataset.answersFor('bsit-2022', 'w2024')),
        ),
        (hits: 3, total: 25),
      );
      expect(
        share(
          DssMetrics.unemployment(dataset.answersFor('bsit-2022', 'w2025')),
        ),
        (hits: 8, total: 25),
      );
    });

    test('BSIT 2023 improves in the next wave', () {
      expect(
        share(
          DssMetrics.unemployment(dataset.answersFor('bsit-2023', 'w2025')),
        ),
        (hits: 14, total: 40),
      );
      expect(
        share(
          DssMetrics.unemployment(dataset.answersFor('bsit-2023', 'w2026')),
        ),
        (hits: 5, total: 35),
      );
    });

    test('small groups still produce a rate today', () {
      expect(
        share(
          DssMetrics.unemployment(dataset.answersFor('bfpt-2023', 'w2025')),
        ),
        (hits: 1, total: 1),
      );
      expect(
        share(
          DssMetrics.unemployment(
            dataset.answersFor('btled-ict-2023', 'w2026'),
          ),
        ),
        (hits: 1, total: 3),
      );
    });

    test('Q16 counts further study as not employed today', () {
      final answers = dataset.answersFor('btled-ict-2023', 'w2025');
      expect(share(DssMetrics.unemployment(answers)), (hits: 8, total: 20));
      final furtherStudy = answers
          .where(
            (a) =>
                (a['ched_17'] as List?)?.contains('Advance or further study') ??
                false,
          )
          .length;
      expect(furtherStudy, 6);
    });
  });

  group('BTLED-HE 2024 (limited evidence)', () {
    final answers = dataset.answersFor('btled-he-2024', 'w2025');

    test('course mismatch and suggestions', () {
      final r = DssMetrics.relatedness(answers)!;
      expect((r.mismatch, r.answered), (6, 10));
      expect(r.mismatchSuggestions, hasLength(5));
    });

    test('clerical jobs', () {
      expect(share(DssMetrics.clerical(answers)), (hits: 6, total: 10));
    });

    test('Q29 "Others" is left out of the denominator', () {
      expect(share(DssMetrics.longTimeToFirstJob(answers)), (
        hits: 4,
        total: 9,
      ));
      expect(DssMetrics.timeToJobOthers(answers), 1);
    });

    test('low starting pay', () {
      final ranks = DssMetrics.salaryRanks(answers);
      expect(ranks, hasLength(10));
      expect(ranks.where((r) => r < 2), hasLength(7));
    });
  });

  test('BSIT 2023 relatedness is high (opportunity)', () {
    final r = DssMetrics.relatedness(dataset.answersFor('bsit-2023', 'w2025'))!;
    expect((r.aligned, r.answered), (24, 26));
  });

  test('BTLED-ICT 2024 has only 3 valid Q29 answers', () {
    final answers = dataset.answersFor('btled-ict-2024', 'w2025');
    expect(DssMetrics.timeToJobAnswers(answers), hasLength(3));
    expect(share(DssMetrics.unemployment(answers)), (hits: 17, total: 20));
  });
}
