import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';

DssFlag _flag(DssFlagStatus status, {DateTime? verifyDueAt}) {
  return DssFlag(
    id: 'f1',
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
    verifyDueAt: verifyDueAt,
  );
}

void main() {
  group('dssNextAction', () {
    test('open → Start', () {
      final next = dssNextAction(
        _flag(DssFlagStatus.open),
        hasUndecidedIntervention: false,
        outcomeReady: false,
      );
      expect(next.kind, DssNextActionKind.start);
      expect(next.label, 'Start');
    });

    test('inProgress → Resolve finding', () {
      final next = dssNextAction(
        _flag(DssFlagStatus.inProgress),
        hasUndecidedIntervention: false,
        outcomeReady: false,
      );
      expect(next.kind, DssNextActionKind.resolve);
      expect(next.label, 'Resolve finding');
    });

    test('resolved with undecided, not ready → Check outcome', () {
      final next = dssNextAction(
        _flag(DssFlagStatus.resolved),
        hasUndecidedIntervention: true,
        outcomeReady: false,
      );
      expect(next.kind, DssNextActionKind.checkOutcome);
      expect(next.label, 'Check outcome');
    });

    test('resolved with undecided and ready → Decide', () {
      final next = dssNextAction(
        _flag(DssFlagStatus.resolved),
        hasUndecidedIntervention: true,
        outcomeReady: true,
      );
      expect(next.kind, DssNextActionKind.decide);
      expect(next.label, 'Decide');
    });

    test('resolved awaiting wave → wait / Reopen', () {
      final next = dssNextAction(
        _flag(
          DssFlagStatus.resolved,
          verifyDueAt: DateTime(2026, 6, 1),
        ),
        hasUndecidedIntervention: false,
        outcomeReady: false,
      );
      expect(next.kind, DssNextActionKind.wait);
      expect(next.label, 'Reopen');
      expect(next.hint, contains('verify due'));
    });

    test('dismissed → Reopen', () {
      final next = dssNextAction(
        _flag(DssFlagStatus.dismissed),
        hasUndecidedIntervention: false,
        outcomeReady: false,
      );
      expect(next.kind, DssNextActionKind.reopen);
      expect(next.label, 'Reopen');
    });

    test('watch → Dismiss only', () {
      final next = dssNextAction(
        _flag(DssFlagStatus.watch),
        hasUndecidedIntervention: false,
        outcomeReady: false,
      );
      expect(next.kind, DssNextActionKind.dismissOnly);
    });

    test('superseded → none', () {
      final next = dssNextAction(
        _flag(DssFlagStatus.superseded),
        hasUndecidedIntervention: false,
        outcomeReady: false,
      );
      expect(next.kind, DssNextActionKind.none);
    });

    test('stage strip hint matches next-action helper', () {
      for (final status in DssFlagStatus.values) {
        for (final undecided in [false, true]) {
          for (final ready in [false, true]) {
            final flag = _flag(status);
            final next = dssNextAction(
              flag,
              hasUndecidedIntervention: undecided,
              outcomeReady: ready,
            );
            // Hint is non-empty for every actionable/display state.
            expect(next.hint, isNotEmpty, reason: '$status/$undecided/$ready');
          }
        }
      }
    });
  });
}
