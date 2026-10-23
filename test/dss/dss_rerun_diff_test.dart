import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/dss/application/dss_rerun_diff.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';

DssFlag _flag(String id, DssFlagStatus status) {
  return DssFlag(
    id: id,
    ruleId: 'UNEMPLOYMENT_HIGH',
    course: 'BSIT',
    batchYear: '2024',
    surveyId: 's1',
    surveyTitle: 'Wave 1',
    metricValue: 0.4,
    thresholdSnapshot: 0.25,
    sampleN: 20,
    confidence: DssConfidence.ok,
    status: status,
    title: 'Test',
    body: 'Body',
    recommendedAction: 'Act',
    evidence: const {},
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('dssRerunDiff', () {
    test('empty when nothing changed', () {
      final before = {
        'a': DssFlagStatus.open,
        'b': DssFlagStatus.inProgress,
      };
      final after = [
        _flag('a', DssFlagStatus.open),
        _flag('b', DssFlagStatus.inProgress),
      ];
      final diff = dssRerunDiff(before: before, after: after);
      expect(diff.isEmpty, isTrue);
      expect(diff.bannerText, isNull);
    });

    test('counts new, watch, open, and superseded moves', () {
      final before = {
        'a': DssFlagStatus.open,
        'b': DssFlagStatus.watch,
        'c': DssFlagStatus.open,
      };
      final after = [
        _flag('a', DssFlagStatus.watch),
        _flag('b', DssFlagStatus.open),
        _flag('c', DssFlagStatus.superseded),
        _flag('d', DssFlagStatus.open),
      ];
      final diff = dssRerunDiff(before: before, after: after);
      expect(diff.raised, 1);
      expect(diff.movedToWatch, 1);
      expect(diff.becameFinding, 1);
      expect(diff.superseded, 1);
      expect(diff.bannerText, contains('new finding'));
      expect(diff.bannerText, contains('moved to Watch'));
      expect(diff.bannerText, contains('moved to Open'));
      expect(diff.bannerText, contains('superseded'));
    });
  });
}
