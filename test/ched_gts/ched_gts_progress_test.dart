import 'package:alumni_system/features/surveys/ched_gts/ched_gts_progress.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fills every currently required visible item (same approach as wizard tests).
Map<String, dynamic> _complete(Map<String, dynamic> base) {
  final answers = Map<String, dynamic>.from(base);
  for (var round = 0; round < 20; round++) {
    final missing = ChedGtsVisibility.missingRequired(answers);
    if (missing.isEmpty) break;
    for (final id in missing) {
      final item = ChedGtsBuiltin.byId(id)!;
      answers[id] = switch (item.type) {
        ChedGtsFieldType.text || ChedGtsFieldType.longText => 'Sample',
        ChedGtsFieldType.date => '2000-01-01',
        ChedGtsFieldType.single =>
          item.options.isEmpty ? 'Sample' : item.options.first,
        ChedGtsFieldType.multi => [item.options.first],
        ChedGtsFieldType.matrix => {
          item.matrixRows.first: {item.matrixColumns.first: true},
        },
        ChedGtsFieldType.tableRows => [
          {item.tableColumns.first: 'Sample'},
        ],
      };
    }
  }
  expect(ChedGtsVisibility.missingRequired(answers), isEmpty);
  return answers;
}

void main() {
  group('ChedGtsProgress', () {
    test('intro stays at 0% with no draft even when answers are complete', () {
      final answers = _complete({
        'ched_16': ChedGtsBuiltin.neverEmployed,
        'ched_17': const ['Lack of work experience'],
      });
      expect(ChedGtsProgress.requiredFillPercent(answers), 100);
      expect(ChedGtsProgress.introPercent(answers, hasDraft: false), 0);
    });

    test('intro with draft caps at 95% when answers are complete', () {
      final answers = _complete({
        'ched_16': ChedGtsBuiltin.no,
        'ched_17': const ['No job opportunity'],
      });
      expect(
        ChedGtsProgress.introPercent(answers, hasDraft: true),
        ChedGtsProgress.beforeReviewCap,
      );
    });

    test('wizard caps at 95% on section steps when answers are complete', () {
      final answers = _complete({
        'ched_16': ChedGtsBuiltin.neverEmployed,
        'ched_17': const ['Did not look for a job'],
      });
      expect(
        ChedGtsProgress.wizardPercent(answers, onReviewOrVerify: false),
        ChedGtsProgress.beforeReviewCap,
      );
    });

    test('wizard shows 100% on review/verify when nothing is missing', () {
      final answers = _complete({
        'ched_16': ChedGtsBuiltin.neverEmployed,
        'ched_17': const ['Advance or further study'],
      });
      expect(
        ChedGtsProgress.wizardPercent(answers, onReviewOrVerify: true),
        100,
      );
    });

    test('partial fill is shown as-is below the review cap', () {
      final percent = ChedGtsProgress.requiredFillPercent({
        'ched_16': ChedGtsBuiltin.neverEmployed,
      });
      expect(percent, lessThan(100));
      expect(
        ChedGtsProgress.wizardPercent(
          {'ched_16': ChedGtsBuiltin.neverEmployed},
          onReviewOrVerify: false,
        ),
        percent,
      );
      expect(
        ChedGtsProgress.introPercent(
          {'ched_16': ChedGtsBuiltin.neverEmployed},
          hasDraft: true,
        ),
        percent,
      );
    });
  });
}
