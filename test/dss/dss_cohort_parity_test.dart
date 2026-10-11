// Dart-vs-SQL parity for dss_cohort_metrics on a real database export.
// Skipped unless DSS_PARITY_DIR points at a folder written by
// supabase/regression/dss_cohort_parity.ps1 (inputs.json, sql_rows.json).
import 'dart:convert';
import 'dart:io';

import 'package:alumni_system/features/admin/dss/application/dss_cohort_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Platform.environment['DSS_PARITY_DIR'];
  final skip = dir == null || dir.isEmpty
      ? 'Set DSS_PARITY_DIR to run the database parity check'
      : null;

  test('dss_cohort_metrics matches the Dart reference', () {
    // `supabase db query` wraps results as {"rows": [{"payload": ...}]}.
    Object? read(String name) {
      final raw = File('$dir${Platform.pathSeparator}$name').readAsStringSync();
      final json = jsonDecode(
        raw.substring(raw.indexOf('{'), raw.lastIndexOf('}') + 1),
      );
      return json is Map && json['rows'] is List
          ? ((json['rows'] as List).first as Map)['payload']
          : json;
    }

    final inputs = read('inputs.json')! as Map<String, dynamic>;
    final sqlRows = (read('sql_rows.json')! as List)
        .cast<Map<String, dynamic>>();
    final now = DateTime.parse(inputs['now'] as String);

    final roster = [
      for (final m in (inputs['members'] as List).cast<Map<String, dynamic>>())
        AlumniMember.fromSupabaseRow(m),
    ].where((m) => !m.isDeactivated).toList();
    final rules = [
      for (final r in (inputs['rules'] as List).cast<Map<String, dynamic>>())
        DssRule.fromSupabaseRow(r),
    ];
    final snapshots = [
      for (final s
          in (inputs['snapshots'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
        DssCohortSnapshot.fromSupabaseRow(s),
    ];
    final responses = (inputs['responses'] as List)
        .cast<Map<String, dynamic>>();

    final mismatches = <String>[];
    var compared = 0;
    for (final s in (inputs['surveys'] as List).cast<Map<String, dynamic>>()) {
      final survey = Survey.fromSupabaseRow(s);
      final dart = {
        for (final m in DssCohortMetrics.compute(
          survey: survey,
          responses: [
            for (final r in responses)
              if (r['survey_id'] == survey.id)
                SurveyResponse.fromSupabaseRow(r, surveyId: survey.id),
          ],
          roster: roster,
          rules: rules,
          now: now,
          snapshots: snapshots,
        ))
          m.key: m.toRow(),
      };
      final sql = {
        for (final r in sqlRows)
          if (r['survey_id'] == survey.id)
            DssCohortMetric.fromRow(r).key: DssCohortMetric.fromRow(r).toRow(),
      };
      for (final key in {...dart.keys, ...sql.keys}) {
        final a = dart[key];
        final b = sql[key];
        if (a == null || b == null) {
          mismatches.add(
            '${survey.id} $key: only in ${a == null ? 'SQL' : 'Dart'}',
          );
          continue;
        }
        compared++;
        for (final field in a.keys) {
          final x = a[field];
          final y = b[field];
          final same = x is num && y is num ? (x - y).abs() < 1e-9 : x == y;
          if (!same) {
            mismatches.add('${survey.id} $key.$field: Dart $x, SQL $y');
          }
        }
      }
    }
    expect(compared, greaterThan(0));
    expect(mismatches, isEmpty, reason: mismatches.take(40).join('\n'));
    // ignore: avoid_print
    print('Parity: $compared rows identical.');
  }, skip: skip);
}
