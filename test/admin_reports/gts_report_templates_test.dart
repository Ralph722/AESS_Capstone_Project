import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_templates.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_validator.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

import 'gts_fixtures.dart';

GtsReportResult run(String key, List<GtsRespondent> data) =>
    GtsReportEngine.run(
      GtsReportTemplates.byKey(key)!.forWaves(const ['w1']),
      data,
    );

double notEmployedShare(GtsReportRow row) =>
    row.cell(ChedGtsBuiltin.no).share! +
    row.cell(ChedGtsBuiltin.neverEmployed).share!;

void main() {
  final data = gtsFixtures();
  final linked = data.where((r) => r.isRosterLinked).toList();

  test('the six MVP templates have unique keys and known fields', () {
    expect(GtsReportTemplates.all, hasLength(6));
    final keys = GtsReportTemplates.all.map((t) => t.key).toSet();
    expect(keys, hasLength(6));
    for (final t in GtsReportTemplates.all) {
      expect(t.config.templateKey, t.key);
      expect(t.config.surveyIds, isEmpty, reason: t.key);
      expect(GtsFieldDictionary.byKey(t.config.measure), isNotNull);
      expect(GtsReportTemplates.byKey(t.key), same(t));
    }
    expect(GtsReportTemplates.byKey('nope'), isNull);
    expect(GtsReportTemplates.byKey(null), isNull);
  });

  test('every template is valid and its chart fits, for one or two waves', () {
    for (final t in GtsReportTemplates.all) {
      final one = t.forWaves(const ['w1']);
      expect(GtsReportValidator.validate(one).isValid, isTrue, reason: t.key);
      expect(GtsReportValidator.chartIssue(one, one.chart), isNull);

      final two = t.forWaves(const ['w1', 'w2']);
      expect(two.groupBy, [GtsFieldDictionary.wave, ...t.config.groupBy]);
      expect(GtsReportValidator.validate(two).isValid, isTrue, reason: t.key);
      expect(GtsReportValidator.chartIssue(two, two.chart), isNull);
      expect(two.chart, isNot(GtsChartType.table), reason: t.key);
    }
  });

  test('templates survive a JSON round trip', () {
    for (final t in GtsReportTemplates.all) {
      final config = t.forWaves(const ['w1']);
      final back = GtsReportConfig.fromJson(config.toJson());
      expect(back.toJson(), config.toJson(), reason: t.key);
    }
  });

  test('employment summary matches the DSS not-employed rate', () {
    final r = run('employment_summary', data);
    expect(r.total.respondents, 40);
    final dss = DssMetrics.unemployment(linked.map((x) => x.answers))!;
    expect(notEmployedShare(r.total), closeTo(dss.rate, 1e-9));
    expect(r.total.cell(ChedGtsBuiltin.yes).count, 30);
  });

  test('employment by course matches the DSS rate for each course', () {
    final r = run('employment_by_course', data);
    expect(r.rows.map((x) => x.groupValues.single), ['BSCS', 'BSIT']);
    for (final row in r.rows) {
      final course = row.groupValues.single;
      final dss = DssMetrics.unemployment(
        linked.where((x) => x.course == course).map((x) => x.answers),
      )!;
      expect(notEmployedShare(row), closeTo(dss.rate, 1e-9), reason: course);
      expect(row.denominator, dss.total);
    }
  });

  test('employment by graduation year has one row per batch, in order', () {
    final r = run('employment_by_year', data);
    expect(r.rows.map((x) => x.groupValues.single), ['2023', '2024']);
    expect(r.rows.map((x) => x.respondents), [20, 20]);
  });

  test('first job related to course counts only graduates asked item 24', () {
    final r = run('degree_alignment', data);
    final asked = linked.where((x) => x.answers.containsKey('ched_24a'));
    expect(r.total.denominator, asked.length);
    expect(
      r.total.cell(ChedGtsBuiltin.yes).count,
      asked.where((x) => x.answers['ched_24a'] == ChedGtsBuiltin.yes).length,
    );
    expect(
      r.validation.issues.any((i) => i.message.contains('Item 22 = Yes')),
      isTrue,
    );
  });

  test('employment type is a share of the employed who answered', () {
    final r = run('employment_type', data);
    expect(r.total.denominator, 30);
    expect(
      r.total.cell('Contractual').count +
          r.total.cell('Regular or Permanent').count,
      30,
    );
  });

  test('industry shows the 10 most common and combines the rest', () {
    final r = run('industry', data);
    final options = GtsFieldDictionary.byKey('ched_20')!.options;
    expect(r.hiddenCategories, hasLength(options.length - 10));
    expect(r.categories, hasLength(11));
    expect(r.categories.last, gtsAllOtherLabel);
    final counts = [
      for (final c in r.categories.take(10)) r.total.cell(c).count,
    ];
    expect(counts, [...counts]..sort((a, b) => b.compareTo(a)));
    final shown = counts.fold<int>(0, (a, b) => a + b);
    expect(shown + r.total.cell(gtsAllOtherLabel).count, r.total.answered);
  });
}
