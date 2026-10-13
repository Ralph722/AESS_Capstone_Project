// Dart-vs-SQL parity for dss_cohort_metrics on a real database export.
// Skipped unless DSS_PARITY_DIR points at a folder written by
// supabase/regression/dss_cohort_parity.ps1 (inputs.json, sql_rows.json).
import 'dart:convert';
import 'dart:io';

import 'package:alumni_system/features/admin/dss/application/dss_cohort_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/application/dss_rollup.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_tab_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Platform.environment['DSS_PARITY_DIR'];
  final skip = dir == null || dir.isEmpty
      ? 'Set DSS_PARITY_DIR to run the database parity check'
      : null;

  test('dss_cohort_metrics matches the Dart reference', () {
    final inputs = _read(dir!, 'inputs.json')! as Map<String, dynamic>;
    final sqlRows = (_read(dir, 'sql_rows.json')! as List)
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

  // The report builder and the Tracer tab count item 16 with the report
  // engine; their not-employed counts must equal the DSS rows.
  test('report engine item 16 matches dss_cohort_metrics', () {
    final inputs = _read(dir!, 'inputs.json')! as Map<String, dynamic>;
    final sqlRows = (_read(dir, 'sql_rows.json')! as List)
        .cast<Map<String, dynamic>>();
    final byAuth = <String, AlumniMember>{
      for (final m in (inputs['members'] as List).cast<Map<String, dynamic>>())
        if (AlumniMember.fromSupabaseRow(m) case final member
            when !member.isDeactivated && (member.authUid ?? '').isNotEmpty)
          member.authUid!: member,
    };

    final mismatches = <String>[];
    var compared = 0;
    for (final s in (inputs['surveys'] as List).cast<Map<String, dynamic>>()) {
      final surveyId = s['id'] as String;
      final respondents = [
        for (final r
            in (inputs['responses'] as List).cast<Map<String, dynamic>>())
          if (r['survey_id'] == surveyId)
            if (byAuth[r['user_id']] case final m)
              GtsRespondent(
                userId: r['user_id'] as String,
                surveyId: surveyId,
                answers: Map<String, dynamic>.from(r['answers'] as Map),
                course: m?.course ?? '',
                yearGraduated: m?.batchYear ?? '',
                onActiveRoster: m != null,
              ),
      ];
      final sql = {
        for (final r in sqlRows)
          if (r['survey_id'] == surveyId &&
              r['metric_key'] == 'unemployment_rate')
            DssCohortMetric.fromRow(r).key: DssCohortMetric.fromRow(r),
      };

      void check(
        DssCohortLevel level,
        String course,
        String batch,
        GtsReportRow row,
      ) {
        final key = '${level.dbValue}|$course|$batch|unemployment_rate';
        final dss = sql[key];
        final notEmployed = row.answered - TracerTabStats.yes(row);
        if (dss == null) {
          mismatches.add('$surveyId $key: only in the report engine');
        } else if (dss.hits != notEmployed || dss.total != row.answered) {
          mismatches.add(
            '$surveyId $key: engine $notEmployed/${row.answered}, '
            'DSS ${dss.hits}/${dss.total}',
          );
        }
        compared++;
      }

      final stats = TracerTabStats(
        waves: [(surveyId: surveyId, respondents: respondents)],
        surveyId: surveyId,
      );
      if (stats.employment.respondents == 0) continue;
      check(
        DssCohortLevel.institution,
        DssRollup.all,
        DssRollup.all,
        stats.employment,
      );
      for (final row
          in stats.run('ched_16', groupBy: GtsFieldDictionary.course).rows) {
        check(DssCohortLevel.course, row.groupValues.first, DssRollup.all, row);
      }
      final byBatch = GtsReportEngine.run(
        GtsReportConfig(
          surveyIds: [surveyId],
          measure: 'ched_16',
          population: GtsPopulation.rosterLinked,
          groupBy: const [
            GtsFieldDictionary.course,
            GtsFieldDictionary.yearGraduated,
          ],
        ),
        respondents,
      );
      for (final row in byBatch.rows) {
        if (row.groupValues[1] == gtsUnknownLabel) continue;
        check(
          DssCohortLevel.batch,
          row.groupValues[0],
          row.groupValues[1],
          row,
        );
      }
    }
    expect(compared, greaterThan(0));
    expect(mismatches, isEmpty, reason: mismatches.take(40).join('\n'));
    // ignore: avoid_print
    print('Report engine parity: $compared item-16 rows identical.');
  }, skip: skip);
}

// `supabase db query` wraps results as {"rows": [{"payload": ...}]}.
Object? _read(String dir, String name) {
  final raw = File('$dir${Platform.pathSeparator}$name').readAsStringSync();
  final json = jsonDecode(
    raw.substring(raw.indexOf('{'), raw.lastIndexOf('}') + 1),
  );
  return json is Map && json['rows'] is List
      ? ((json['rows'] as List).first as Map)['payload']
      : json;
}
