import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_impact.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/dss/widgets/dss_outcome_card.dart';

/// Smoke layout for the Phase 5 "What happened" copy blocks used on detail.
void main() {
  test('coverage re-check timeline line uses impact verdict labels', () {
    expect(DssImpactVerdict.improved.label, 'Improved');
    expect(DssImpactVerdict.stillFlagged.label, isNotEmpty);
    expect(
      'Coverage re-check — ${DssImpactVerdict.improved.label}',
      'Coverage re-check — Improved',
    );
  });

  test('outcome wording stays non-causal', () {
    final i = DssIntervention.fromSupabaseRow({
      'id': 'i1',
      'flag_id': 'f1',
      'finding_key': 'UNEMPLOYMENT_HIGH|batch|BSIT|2024',
      'rule_id': 'UNEMPLOYMENT_HIGH',
      'intervention_type': 'Job fair',
      'description': '',
      'expected_outcome': '',
      'success_metric': 'unemployment_rate',
      'success_operator': 'lt',
      'success_target': 0.25,
      'started_on': '2026-10-05',
      'baseline_survey_title': '2025 wave',
      'baseline_value': 0.4,
      'baseline_n': 12,
      'outcome_status': 'successful',
      'created_by_name': 'Admin',
      'created_at': '2026-10-05T00:00:00Z',
    });
    expect(DssCopy.outcomeHint(i.outcomeStatus), isNot(contains('caused')));
    expect(DssCopy.successTest(i), isNotEmpty);
    expect(dssOutcomeColor(i.outcomeStatus), AdminDssTheme.success);
  });

  testWidgets('What happened title and panel hint strings render', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('What happened'),
              Text(
                'Same-wave coverage re-check is not intervention success. '
                'Next-wave outcome is judged when the following CHED GTS wave closes. '
                'Check outcome and Decide are on the Action panel.',
              ),
              Text('Coverage re-check — Improved'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('What happened'), findsOneWidget);
    expect(find.textContaining('Check outcome and Decide'), findsOneWidget);
    expect(find.text('Coverage re-check — Improved'), findsOneWidget);
  });
}
