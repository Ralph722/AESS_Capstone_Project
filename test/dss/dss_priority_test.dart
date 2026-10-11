// DSS Phase 5: deterministic priority (no AI), with a reason for every point.
import 'package:alumni_system/features/admin/dss/application/dss_priority.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 11);

DssFlag _flag({
  String ruleId = 'UNEMPLOYMENT_HIGH',
  String severity = 'critical',
  String operator = 'gte',
  String category = 'outcome',
  double metric = 0.5,
  double threshold = 0.25,
  int answers = 20,
  String strength = 'limited',
  String? certainty = 'confirmed',
  String status = 'open',
  int ageDays = 1,
  int sampleN = 20,
  int? eligibleN,
}) => DssFlag.fromSupabaseRow({
  'id': 'f',
  'rule_id': ruleId,
  'cohort_level': 'batch',
  'course': 'BSIT',
  'batch_year': '2024',
  'survey_id': 'w',
  'status': status,
  'metric_value': metric,
  'threshold_snapshot': threshold,
  'sample_n': sampleN,
  'eligible_n': eligibleN,
  'title': 't',
  'evidence': {
    if (ruleId != 'DATA_QUALITY_LOW') ...{
      'valid_answers': answers,
      'evidence_strength': strength,
    },
    'certainty': ?certainty,
  },
  'created_at': _now.subtract(Duration(days: ageDays)).toIso8601String(),
  'updated_at': _now.toIso8601String(),
  'dss_rules': {
    'name': ruleId,
    'severity': severity,
    'operator': operator,
    'min_n': ruleId == 'DATA_QUALITY_LOW' ? 1 : 10,
    'category': category,
  },
});

DssPriorityResult _p(DssFlag f) => DssPriorityCalc.of(f, now: _now);

void main() {
  test('unemployment 50% of 20, confirmed: 3+2+1+1 = 7, Critical', () {
    final p = _p(_flag());
    expect(p.score, 7);
    expect(p.level, DssPriority.critical);
    expect(p.reasons.map((r) => r.display), [
      'Rule severity: Critical (+3)',
      '50.0% against a threshold of 25.0%: far past (+2)',
      'Limited evidence: 20 valid answers',
      'Confirmed: the whole 95% range is past the threshold (+1)',
      '10 alumni affected (+1)',
    ]);
  });

  test('unemployment 30% of 20, possible: 3+1 = 4, Medium', () {
    final p = _p(_flag(metric: 0.30, certainty: 'possible'));
    expect(p.score, 4);
    expect(p.level, DssPriority.medium);
    expect(p.reasons[1].display, contains('well past (+1)'));
    expect(p.reasons.last.display, '6 alumni affected');
  });

  test('distance bands: 50% beyond is far past even with rounding', () {
    // 37.5% against 25% is exactly 50% beyond.
    expect(_p(_flag(metric: 0.375)).reasons[1].points, 2);
    // 30% against 25% is exactly 20% beyond.
    expect(_p(_flag(metric: 0.30)).reasons[1].points, 1);
    expect(_p(_flag(metric: 0.29)).reasons[1].points, 0);
  });

  test('strong evidence adds a point', () {
    final p = _p(_flag(answers: 40, strength: 'strong', sampleN: 40));
    expect(
      p.reasons.map((r) => r.display),
      contains('Strong evidence: 40 valid answers (+1)'),
    );
  });

  test(
    'open and not started for 30+ days adds a point; in progress does not',
    () {
      final old = _p(_flag(metric: 0.30, certainty: 'possible', ageDays: 45));
      expect(old.reasons.last.display, 'Not started for 45 days (+1)');
      expect(old.score, 5);
      expect(old.level, DssPriority.high);

      final started = _p(
        _flag(
          metric: 0.30,
          certainty: 'possible',
          ageDays: 45,
          status: 'in_progress',
        ),
      );
      expect(started.score, 4);
    },
  );

  test('level boundaries: 7 Critical, 5–6 High, 3–4 Medium, 0–2 Low', () {
    // info (1) + just past (0) = 1
    expect(
      _p(_flag(severity: 'info', metric: 0.26, certainty: 'possible')).level,
      DssPriority.low,
    );
    // warning (2) + well past (1) = 3
    expect(
      _p(_flag(severity: 'warning', metric: 0.31, certainty: 'possible')).score,
      3,
    );
    // warning (2) + far past (2) + confirmed (1) + affected (1) = 6
    final high = _p(_flag(severity: 'warning'));
    expect(high.score, 6);
    expect(high.level, DssPriority.high);
  });

  test('Watch status and small samples are Watch, not ranked', () {
    expect(
      _p(_flag(status: 'watch', strength: 'watch')).level,
      DssPriority.watch,
    );
    final small = _p(_flag(answers: 7, strength: 'watch', sampleN: 7));
    expect(small.level, DssPriority.watch);
    expect(small.reasons.single.text, contains('(7)'));
  });

  test('opportunity findings are always Low', () {
    final p = _p(
      _flag(
        ruleId: 'RELATEDNESS_HIGH',
        severity: 'critical',
        category: 'opportunity',
        metric: 0.95,
        threshold: 0.75,
        answers: 40,
        strength: 'strong',
      ),
    );
    expect(p.level, DssPriority.low);
    expect(p.reasons.single.text, 'Opportunity, not a problem');
  });

  test('data quality: below-threshold distance and non-respondents', () {
    final p = _p(
      _flag(
        ruleId: 'DATA_QUALITY_LOW',
        severity: 'warning',
        operator: 'lt',
        category: 'data_quality',
        metric: 0.10,
        threshold: 0.40,
        certainty: null,
        sampleN: 3,
        eligibleN: 30,
      ),
    );
    // warning (2) + 75% below (2) + 27 not answered (1) = 5
    expect(p.score, 5);
    expect(p.level, DssPriority.high);
    expect(
      p.reasons.map((r) => r.display),
      contains('27 alumni in the group have not answered (+1)'),
    );
  });

  test('trends and salary gaps have no affected count', () {
    final trend = _p(
      _flag(
        ruleId: 'UNEMPLOYMENT_TREND_UP',
        severity: 'warning',
        category: 'trend',
        metric: 0.25,
        threshold: 0.10,
        certainty: null,
      ),
    );
    expect(trend.reasons.any((r) => r.text.contains('affected')), isFalse);
    expect(trend.reasons[1].text, contains('far past'));

    final salary = _p(
      _flag(
        ruleId: 'SALARY_STAGNATION',
        severity: 'info',
        metric: 1.3,
        threshold: 1.0,
        certainty: null,
      ),
    );
    expect(salary.reasons.any((r) => r.text.contains('affected')), isFalse);
    expect(salary.score, 2); // info (1) + 30% beyond, well past (1)
  });

  test('sorting: level, then score, then oldest first', () {
    final critical = _flag();
    final medium = _flag(metric: 0.30, certainty: 'possible');
    final mediumOlder = _flag(metric: 0.30, certainty: 'possible', ageDays: 20);
    final watch = _flag(status: 'watch', strength: 'watch');
    final sorted = [watch, medium, critical, mediumOlder]
      ..sort((a, b) => DssPriorityCalc.compare(a, b, now: _now));
    expect(sorted, [critical, mediumOlder, medium, watch]);
  });

  test('same facts give the same priority', () {
    expect(_p(_flag()).score, _p(_flag()).score);
    expect(_p(_flag()).level, _p(_flag()).level);
  });
}
