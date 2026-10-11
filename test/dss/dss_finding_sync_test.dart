// DSS Phase 4: one active flag per finding across waves (DssFindingSync).
import 'package:alumni_system/features/admin/dss/application/dss_finding_sync.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _w1 = 'wave-2024';
const _w2 = 'wave-2025';
const _w3 = 'wave-2026';
final _dates = {
  _w1: DateTime(2024, 6),
  _w2: DateTime(2025, 6),
  _w3: DateTime(2026, 6),
};
final _key = dssFindingKey('UNEMPLOYMENT_HIGH', 'batch', 'BSIT', '2024');

Map<String, dynamic> _row(
  String surveyId, {
  String status = 'open',
  String rule = 'UNEMPLOYMENT_HIGH',
  int n = 20,
}) => {
  'rule_id': rule,
  'cohort_level': 'batch',
  'course': 'BSIT',
  'batch_year': '2024',
  'survey_id': surveyId,
  'sample_n': n,
  'status': status,
};

DssStoredFlag _flag(String id, String surveyId, DssFlagStatus status) =>
    (id: id, findingKey: _key, surveyId: surveyId, status: status);

DssFindingPlan _plan({
  List<Map<String, dynamic>> rows = const [],
  Map<String, Set<String>>? checked,
  List<DssStoredFlag> stored = const [],
}) => DssFindingSync.plan(
  rows: rows,
  checked:
      checked ??
      {
        for (final r in rows)
          DssFindingSync.keyOfRow(r): {
            for (final x in rows)
              if (DssFindingSync.keyOfRow(x) == DssFindingSync.keyOfRow(r))
                x['survey_id'] as String,
          },
      },
  suppressed: const [],
  waveDates: _dates,
  stored: stored,
);

void main() {
  test('finding key matches the generated column', () {
    expect(_key, 'UNEMPLOYMENT_HIGH|batch|BSIT|2024');
    expect(DssFindingSync.keyOfRow(_row(_w1)), _key);
  });

  test('first run: only the newest wave is raised', () {
    final plan = _plan(rows: [_row(_w1), _row(_w2), _row(_w3)]);
    expect(plan.inserts.map((i) => i.row['survey_id']), [_w3]);
    expect(plan.inserts.single.event.reason, 'finding');
    expect(
      plan.events.map((e) => '${e.surveyId}:${e.outcome}:${e.reason}'),
      unorderedEquals([
        '$_w1:suppressed:newer_wave',
        '$_w2:suppressed:newer_wave',
      ]),
    );
    expect(plan.supersedes, isEmpty);
  });

  test('old open and Watch flags are superseded by the newest wave', () {
    final plan = _plan(
      rows: [_row(_w1), _row(_w3)],
      stored: [
        _flag('a', _w1, DssFlagStatus.open),
        _flag('b', _w2, DssFlagStatus.watch),
      ],
    );
    expect(plan.inserts.single.row['survey_id'], _w3);
    expect(plan.updates, isEmpty);
    expect(
      plan.supersedes.map((s) => '${s.id}>${s.newerSurveyId}'),
      unorderedEquals(['a>$_w3', 'b>$_w3']),
    );
    expect(
      plan.supersedes.firstWhere((s) => s.id == 'b').from,
      DssFlagStatus.watch,
    );
  });

  test('a wave checked without crossing still supersedes older flags', () {
    final plan = _plan(
      rows: const [],
      checked: {
        _key: {_w3},
      },
      stored: [_flag('a', _w2, DssFlagStatus.open)],
    );
    expect(plan.inserts, isEmpty);
    expect(plan.supersedes.single.id, 'a');
    expect(plan.supersedes.single.newerSurveyId, _w3);
  });

  test('in-progress flags are never superseded, and are still refreshed', () {
    final plan = _plan(
      rows: [_row(_w1), _row(_w3)],
      stored: [_flag('p', _w1, DssFlagStatus.inProgress)],
    );
    expect(plan.supersedes, isEmpty);
    final u = plan.updates.single;
    expect(u.id, 'p');
    expect(u.statusTo, isNull);
    expect(u.event.reason, 'refreshed');
    expect(plan.inserts.single.row['survey_id'], _w3);
  });

  test('closed flags are left alone and not raised again', () {
    final plan = _plan(
      rows: [_row(_w1), _row(_w3)],
      stored: [
        _flag('r', _w1, DssFlagStatus.resolved),
        _flag('d', _w3, DssFlagStatus.dismissed),
      ],
    );
    expect(plan.inserts, isEmpty);
    expect(plan.supersedes, isEmpty);
    expect(
      plan.events.map((e) => '${e.surveyId}:${e.reason}'),
      unorderedEquals(['$_w1:newer_wave', '$_w3:closed_in_wave']),
    );
  });

  test('a superseded wave is not raised again', () {
    final plan = _plan(
      rows: [_row(_w2)],
      checked: {
        _key: {_w2},
      },
      stored: [_flag('s', _w2, DssFlagStatus.superseded)],
    );
    expect(plan.inserts, isEmpty);
    expect(plan.events.single.reason, 'superseded_in_wave');
  });

  test('an open flag in the newest wave moves to Watch and back', () {
    final toWatch = _plan(
      rows: [_row(_w3, status: 'watch', n: 7)],
      stored: [_flag('a', _w3, DssFlagStatus.open)],
    );
    expect(toWatch.updates.single.statusTo, DssFlagStatus.watch);
    expect(toWatch.updates.single.event.reason, 'became_watch');
    expect(toWatch.updates.single.event.validAnswers, 7);

    final toFinding = _plan(
      rows: [_row(_w3)],
      stored: [_flag('a', _w3, DssFlagStatus.watch)],
    );
    expect(toFinding.updates.single.statusTo, DssFlagStatus.open);
    expect(toFinding.updates.single.event.reason, 'became_finding');

    final same = _plan(
      rows: [_row(_w3)],
      stored: [_flag('a', _w3, DssFlagStatus.open)],
    );
    expect(same.updates.single.statusTo, isNull);
    expect(same.updates.single.event.reason, 'refreshed');
  });

  test('an in-progress flag never moves to Watch', () {
    final plan = _plan(
      rows: [_row(_w3, status: 'watch', n: 7)],
      stored: [_flag('p', _w3, DssFlagStatus.inProgress)],
    );
    expect(plan.updates.single.statusTo, isNull);
  });

  test('raise reasons: finding, watch, data quality', () {
    String reasonOf(Map<String, dynamic> row) =>
        _plan(rows: [row]).inserts.single.event.reason;
    expect(reasonOf(_row(_w3)), 'finding');
    expect(reasonOf(_row(_w3, status: 'watch', n: 6)), 'watch');
    expect(reasonOf(_row(_w3, rule: 'DATA_QUALITY_LOW')), 'data_quality');
  });

  test('waves without a known date are never treated as older', () {
    final plan = DssFindingSync.plan(
      rows: [_row('archived'), _row(_w3)],
      checked: {
        _key: {'archived', _w3},
      },
      suppressed: const [],
      waveDates: _dates,
      stored: [_flag('x', 'archived', DssFlagStatus.open)],
    );
    expect(plan.supersedes, isEmpty);
    expect(plan.inserts.map((i) => i.row['survey_id']), [_w3]);
  });

  test('suppressed measures become not_enough_data events', () {
    final plan = DssFindingSync.plan(
      rows: const [],
      checked: const {},
      suppressed: [(findingKey: _key, surveyId: _w3, validAnswers: 3)],
      waveDates: _dates,
      stored: const [],
    );
    final e = plan.events.single;
    expect(e.outcome, 'suppressed');
    expect(e.reason, 'not_enough_data');
    expect(e.validAnswers, 3);
    expect(e.flagId, isNull);
  });

  test('event rows carry the run id and trigger', () {
    const e = DssEvaluationEvent(
      findingKey: 'k',
      surveyId: _w3,
      outcome: 'raised',
      reason: 'finding',
      validAnswers: 12,
    );
    expect(e.withFlag('f1').toRow(runId: 'r1', trigger: 'manual'), {
      'run_id': 'r1',
      'run_trigger': 'manual',
      'finding_key': 'k',
      'survey_id': _w3,
      'flag_id': 'f1',
      'outcome': 'raised',
      'reason': 'finding',
      'valid_answers': 12,
    });
  });

  group('status model', () {
    test('watch and superseded round-trip through the database value', () {
      for (final s in DssFlagStatus.values) {
        expect(DssFlagStatusX.fromDb(s.dbValue), s);
      }
      expect(DssFlagStatus.superseded.isClosed, isTrue);
      expect(DssFlagStatus.watch.isClosed, isFalse);
    });

    test('a Watch flag is active but not a finding', () {
      final watch = DssFlag.fromSupabaseRow({
        'id': 'w',
        'rule_id': 'UNEMPLOYMENT_HIGH',
        'cohort_level': 'batch',
        'course': 'BSIT',
        'batch_year': '2024',
        'survey_id': _w3,
        'status': 'watch',
        'metric_value': 0.5,
        'threshold_snapshot': 0.25,
        'title': 't',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(watch.isActive, isTrue);
      expect(watch.isFinding, isFalse);
      expect(watch.findingKey, _key);
    });

    test('a superseded flag is not active and keeps its link', () {
      final s = DssFlag.fromSupabaseRow({
        'id': 's',
        'rule_id': 'UNEMPLOYMENT_HIGH',
        'cohort_level': 'batch',
        'course': 'BSIT',
        'batch_year': '2024',
        'survey_id': _w1,
        'status': 'superseded',
        'superseded_by': 'n',
        'superseded_at': '2026-02-01T00:00:00Z',
        'metric_value': 0.5,
        'threshold_snapshot': 0.25,
        'title': 't',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(s.isActive, isFalse);
      expect(s.supersededBy, 'n');
      expect(s.supersededAt, DateTime.utc(2026, 2));
    });
  });
}
