import 'package:alumni_system/features/admin/dss/application/dss_evaluation_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/application/dss_finding_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('server Refresh result', () {
    test('reads like an in-app run with the same counts', () {
      const evaluation = DssEvaluation(
        flagRows: [{}, {}, {}, {}],
        snapshots: [],
        cohortsEvaluated: 12,
        rolledUpGroups: 2,
        chedWaves: 3,
        wavesWithResponses: 2,
        responsesScanned: 221,
        watch: 1,
        notEnoughData: 5,
        unclassified: 4,
      );
      const saved = DssSyncSummary(
        raised: 2,
        updated: 1,
        superseded: 1,
        skippedNewerWave: 3,
        skippedClosed: 1,
      );

      final result = DssEvaluationResult.fromServer({
        'dry_run': false,
        'trigger': 'manual',
        'ched_waves': 3,
        'waves_with_responses': 2,
        'responses_scanned': 221,
        'unclassified': 4,
        'cohorts_evaluated': 12,
        'rolled_up_groups': 2,
        'flag_rows': 4,
        'watch': 1,
        'not_enough_data': 5,
        'raised': 2,
        'updated': 1,
        'superseded': 1,
        'skipped_newer_wave': 3,
        'skipped_closed': 1,
        'snapshots_saved': 0,
      });

      expect(result.message, evaluation.message + saved.message);
      expect(result.cohortsEvaluated, 12);
      expect(result.flagsRaisedOrUpdated, 3);
      expect(result.chedWaves, 3);
      expect(result.wavesWithResponses, 2);
      expect(result.responsesScanned, 221);
      expect(result.onServer, isTrue);
    });

    test('no enabled rules', () {
      final result = DssEvaluationResult.fromServer({
        'no_rules': true,
        'message': 'No enabled DSS rules.',
      });
      expect(result.message, 'No enabled DSS rules.');
      expect(result.flagsRaisedOrUpdated, 0);
    });

    test('nothing met a rule', () {
      final result = DssEvaluationResult.fromServer({
        'ched_waves': 1,
        'waves_with_responses': 1,
        'responses_scanned': 8,
        'cohorts_evaluated': 1,
        'flag_rows': 0,
      });
      expect(result.message, contains('No group met an enabled rule.'));
      expect(result.message, contains('Saved: 0 new, 0 refreshed.'));
    });
  });

  group('falls back to the in-app engine', () {
    test('on unexpected server errors', () {
      expect(
        DssEvaluationService.fallsBackOn(
          const PostgrestException(message: 'boom', code: 'XX000'),
        ),
        isTrue,
      );
      expect(DssEvaluationService.fallsBackOn(Exception('network')), isTrue);
    });

    test('not while another run holds the lock', () {
      expect(
        DssEvaluationService.fallsBackOn(
          const PostgrestException(
            message: 'Another DSS evaluation is running. Try again in a minute.',
            code: '55P03',
          ),
        ),
        isFalse,
      );
    });

    test('not for callers without admin rights', () {
      expect(
        DssEvaluationService.fallsBackOn(
          const PostgrestException(
            message: 'Admin access required.',
            code: '42501',
          ),
        ),
        isFalse,
      );
    });
  });
}
