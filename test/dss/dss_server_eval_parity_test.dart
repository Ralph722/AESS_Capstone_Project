// Dart-vs-SQL parity for dss_evaluate_all (DSS Phase 8) on a real database
// export. Skipped unless DSS_EVAL_PARITY_DIR points at a folder holding
// parity.json: the inputs (rules, members, surveys, submitted responses,
// snapshots, stored flags, now) plus `dss_evaluate_all('manual', true)` as
// "server".
import 'dart:convert';
import 'dart:io';

import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/application/dss_finding_sync.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Platform.environment['DSS_EVAL_PARITY_DIR'];
  final skip = dir == null || dir.isEmpty
      ? 'Set DSS_EVAL_PARITY_DIR to run the server evaluation parity check'
      : null;

  test('dss_evaluate_all matches the Dart engine', () {
    final raw = File(
      '$dir${Platform.pathSeparator}parity.json',
    ).readAsStringSync();
    final inputs = jsonDecode(raw) as Map<String, dynamic>;
    final server = inputs['server'] as Map<String, dynamic>;
    final now = DateTime.parse(inputs['now'] as String);
    List<Map<String, dynamic>> list(String k) =>
        (inputs[k] as List? ?? const []).cast<Map<String, dynamic>>();

    final roster = [
      for (final m in list('members')) AlumniMember.fromSupabaseRow(m),
    ].where((m) => !m.isDeactivated).toList();
    final rules = [for (final r in list('rules')) DssRule.fromSupabaseRow(r)];
    final waves = [
      for (final s in list('surveys')) Survey.fromSupabaseRow(s),
    ].where((s) {
      return !s.archived &&
          s.isChedGtsBuiltin &&
          (s.status == SurveyStatus.published ||
              s.status == SurveyStatus.closed);
    }).toList();
    final snapshots = [
      for (final s in list('snapshots'))
        if (waves.any((w) => w.id == s['survey_id']))
          DssCohortSnapshot.fromSupabaseRow(s),
    ];
    final responses = list('responses');

    final evaluation = DssEvaluator(
      rules: rules,
      roster: roster,
      now: now,
      snapshots: snapshots,
    ).run([
      for (final w in waves)
        DssWaveInput(
          survey: w,
          responses: [
            for (final r in responses)
              if (r['survey_id'] == w.id)
                SurveyResponse.fromSupabaseRow(r, surveyId: w.id),
          ],
        ),
    ]);
    final waveDates = {for (final w in waves) w.id: DssEvaluator.waveDate(w)};
    final stored = <DssStoredFlag>[
      for (final f in list('stored'))
        if (waveDates.containsKey(f['survey_id']))
          (
            id: f['id'].toString(),
            findingKey: f['finding_key'].toString(),
            surveyId: f['survey_id'].toString(),
            status: DssFlagStatusX.fromDb(f['status']?.toString()),
          ),
    ];
    final plan = DssFindingSync.plan(
      rows: evaluation.flagRows,
      checked: evaluation.checked,
      suppressed: evaluation.suppressed,
      waveDates: waveDates,
      stored: stored,
    );

    final mismatches = <String>[];
    void same(String where, Object? dart, Object? sql) {
      if (dart is Map && sql is Map) {
        for (final k in {...dart.keys, ...sql.keys}) {
          if (!dart.containsKey(k) || !sql.containsKey(k)) {
            mismatches.add(
              '$where.$k: only in ${dart.containsKey(k) ? 'Dart' : 'SQL'}',
            );
          } else {
            same('$where.$k', dart[k], sql[k]);
          }
        }
      } else if (dart is List && sql is List) {
        if (dart.length != sql.length) {
          mismatches.add('$where: Dart $dart, SQL $sql');
          return;
        }
        for (var i = 0; i < dart.length; i++) {
          same('$where[$i]', dart[i], sql[i]);
        }
      } else if (dart is num && sql is num) {
        if ((dart - sql).abs() > 1e-9) {
          mismatches.add('$where: Dart $dart, SQL $sql');
        }
      } else if (dart != sql) {
        mismatches.add('$where: Dart $dart, SQL $sql');
      }
    }

    // Flag rows, field by field (JSON round trip drops Dart-only types).
    String rowKey(Map r) =>
        '${DssFindingSync.keyOfRow(r.cast<String, dynamic>())}@${r['survey_id']}';
    final dartRows = {
      for (final r in evaluation.flagRows)
        rowKey(r): jsonDecode(jsonEncode(r)) as Map<String, dynamic>,
    };
    final sqlRows = {
      for (final r in (server['rows'] as List).cast<Map<String, dynamic>>())
        rowKey(r): {...r}..remove('finding_key'),
    };
    same('rows', dartRows, sqlRows);

    same('checked', {
      for (final e in evaluation.checked.entries) e.key: (e.value.toList()..sort()),
    }, {
      for (final e in (server['checked'] as Map).entries)
        e.key: ((e.value as List).cast<String>().toList()..sort()),
    });

    same(
      'suppressed',
      ([
        for (final s in evaluation.suppressed)
          '${s.findingKey}@${s.surveyId}=${s.validAnswers}',
      ]..sort()),
      ([
        for (final s in (server['suppressed'] as List).cast<Map>())
          '${s['finding_key']}@${s['survey_id']}=${s['valid_answers']}',
      ]..sort()),
    );

    final active = {
      for (final f in stored)
        if (!f.status.isClosed) '${f.findingKey}@${f.surveyId}',
      for (final i in plan.inserts) '${i.event.findingKey}@${i.event.surveyId}',
    };
    same(
      'actions',
      ([
        for (final i in plan.inserts)
          'insert ${i.event.findingKey}@${i.event.surveyId} '
              '${i.row['status']} ${i.event.reason} ${i.event.validAnswers}',
        for (final u in plan.updates)
          'update ${u.event.findingKey}@${u.event.surveyId} ${u.id} '
              '${u.from.dbValue}>${u.statusTo?.dbValue} ${u.event.reason} '
              '${u.event.validAnswers}',
        for (final e in plan.events)
          'suppress ${e.findingKey}@${e.surveyId} ${e.reason} ${e.validAnswers}',
        for (final s in plan.supersedes)
          'supersede ${s.findingKey}@${s.newerSurveyId} ${s.id} '
              '${active.contains('${s.findingKey}@${s.newerSurveyId}') ? 'newer_wave_raised' : 'newer_wave_clear'}',
      ]..sort()),
      ([
        for (final a in (server['actions'] as List).cast<Map>())
          switch (a['action']) {
            'insert' =>
              'insert ${a['finding_key']}@${a['survey_id']} '
                  '${a['status_to']} ${a['reason']} ${a['valid_answers']}',
            'update' =>
              'update ${a['finding_key']}@${a['survey_id']} ${a['flag_id']} '
                  '${a['status_from']}>${a['status_to']} ${a['reason']} '
                  '${a['valid_answers']}',
            'supersede' =>
              'supersede ${a['finding_key']}@${a['newer_survey_id']} '
                  '${a['flag_id']} ${a['reason']}',
            _ =>
              'suppress ${a['finding_key']}@${a['survey_id']} ${a['reason']} '
                  '${a['valid_answers']}',
          },
      ]..sort()),
    );

    same('counts', {
      'ched_waves': evaluation.chedWaves,
      'waves_with_responses': evaluation.wavesWithResponses,
      'responses_scanned': evaluation.responsesScanned,
      'unclassified': evaluation.unclassified,
      'cohorts_evaluated': evaluation.cohortsEvaluated,
      'rolled_up_groups': evaluation.rolledUpGroups,
      'flag_rows': evaluation.flagRows.length,
      'watch': evaluation.watch,
      'not_enough_data': evaluation.notEnoughData,
    }, {
      for (final k in [
        'ched_waves',
        'waves_with_responses',
        'responses_scanned',
        'unclassified',
        'cohorts_evaluated',
        'rolled_up_groups',
        'flag_rows',
        'watch',
        'not_enough_data',
      ])
        k: server[k],
    });

    expect(dartRows, isNotEmpty);
    expect(mismatches, isEmpty, reason: mismatches.take(60).join('\n'));
    // ignore: avoid_print
    print(
      'Parity: ${dartRows.length} flag rows, ${evaluation.checked.length} '
      'checked findings, ${plan.inserts.length + plan.updates.length + plan.events.length + plan.supersedes.length} '
      'sync actions identical.',
    );
  }, skip: skip);
}
