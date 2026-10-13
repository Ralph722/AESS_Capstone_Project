import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_validator.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

void main() {
  const base = GtsReportConfig(surveyIds: ['w1'], measure: 'ched_16');

  GtsReportValidation check(GtsReportConfig c, {bool forSave = false}) =>
      GtsReportValidator.validate(c, forSave: forSave);

  Set<String> errors(GtsReportConfig c) => {
    for (final i in check(c).of(GtsIssueSeverity.error)) i.code,
  };

  Set<String> warnings(GtsReportConfig c) => {
    for (final i in check(c).of(GtsIssueSeverity.warning)) i.code,
  };

  group('GtsReportConfig json', () {
    test('round-trips every setting', () {
      const config = GtsReportConfig(
        templateKey: 'employment_by_year',
        title: 'Employment by year',
        description: 'Wave 1',
        surveyIds: ['w1', 'w2'],
        population: GtsPopulation.rosterLinked,
        measure: 'ched_30',
        gridColumn: '30.2. Current or Present Job',
        calculation: GtsCalculation.count,
        groupBy: ['survey', 'course'],
        filters: [
          GtsReportFilter(field: 'year_graduated', values: ['2024']),
        ],
        sortBy: GtsSortBy.count,
        sortDescending: true,
        chart: GtsChartType.groupedBar,
        showTable: false,
        topN: 5,
      );
      final restored = GtsReportConfig.fromJson(config.toJson());
      expect(restored.toJson(), config.toJson());
      expect(restored.filters.single.values, ['2024']);
    });

    test('omits unset optional keys', () {
      final json = base.toJson();
      expect(json.containsKey('templateKey'), isFalse);
      expect(json.containsKey('gridColumn'), isFalse);
      expect(json.containsKey('topN'), isFalse);
      expect(json['version'], GtsReportConfig.currentVersion);
    });

    test('unknown enum names fall back to defaults', () {
      final restored = GtsReportConfig.fromJson({
        'surveyIds': ['w1'],
        'measure': 'ched_16',
        'chart': 'radar',
        'calculation': 'average',
        'population': 'everyone',
      });
      expect(restored.chart, GtsChartType.table);
      expect(restored.calculation, GtsCalculation.shareOfAnswered);
      expect(restored.population, GtsPopulation.allRespondents);
    });

    test('rejects configs from a newer app version', () {
      expect(
        () => GtsReportConfig.fromJson({'version': 99, 'measure': 'ched_16'}),
        throwsFormatException,
      );
    });

    test('there is no average calculation', () {
      expect(
        GtsCalculation.values.map((c) => c.name),
        isNot(anyElement(contains('average'))),
      );
    });
  });

  group('scope', () {
    test('a simple employment share is valid and explained', () {
      final v = check(base.copyWith(chart: GtsChartType.donut));
      expect(v.isValid, isTrue);
      final denominator = v.issues.firstWhere((i) => i.code == 'denominator');
      expect(denominator.message, 'Percent of graduates who answered item 16.');
      expect(v.has('small_groups'), isTrue);
    });

    test('needs a wave, and several waves must be grouped by wave', () {
      expect(errors(base.copyWith(surveyIds: [])), contains('no_wave'));
      expect(
        errors(base.copyWith(surveyIds: ['w1', 'w2'])),
        contains('waves_not_grouped'),
      );
      expect(
        check(
          base.copyWith(surveyIds: ['w1', 'w2'], groupBy: ['survey']),
        ).isValid,
        isTrue,
      );
    });

    test('a name is required only when saving', () {
      expect(check(base).isValid, isTrue);
      expect(check(base, forSave: true).has('title_missing'), isTrue);
    });
  });

  group('measure and calculation', () {
    test('unknown and personal fields are blocked', () {
      expect(errors(base.copyWith(measure: 'nope')), {'measure_unknown'});
      expect(
        errors(base.copyWith(measure: 'ched_3')),
        contains('measure_personal'),
      );
    });

    test('median only for ordered brackets and only as a table', () {
      expect(
        errors(base.copyWith(calculation: GtsCalculation.medianBracket)),
        contains('calculation_invalid'),
      );
      final median = base.copyWith(
        measure: 'ched_31',
        calculation: GtsCalculation.medianBracket,
      );
      expect(check(median).isValid, isTrue);
      expect(
        errors(median.copyWith(chart: GtsChartType.bar)),
        contains('chart_invalid'),
      );
    });

    test('written answers only allow an answer count', () {
      final text = base.copyWith(measure: 'ched_34');
      expect(errors(text), contains('calculation_invalid'));
      expect(
        check(text.copyWith(calculation: GtsCalculation.answeredCount)).isValid,
        isTrue,
      );
    });

    test('grid column must belong to a grid item', () {
      expect(
        errors(base.copyWith(gridColumn: '30.1. First Job')),
        contains('grid_column_invalid'),
      );
      final grid = base.copyWith(measure: 'ched_30');
      expect(
        errors(grid.copyWith(gridColumn: 'Third job')),
        contains('grid_column_invalid'),
      );
      expect(
        check(grid.copyWith(gridColumn: '30.1. First Job')).isValid,
        isTrue,
      );
    });

    test('shares of everyone warn on items not asked of everyone', () {
      final c = base.copyWith(
        measure: 'ched_24a',
        calculation: GtsCalculation.shareOfAllRespondents,
      );
      expect(warnings(c), contains('share_includes_not_asked'));
      final asked = check(c).issues.firstWhere((i) => i.code == 'asked_of');
      expect(
        asked.message,
        '24. First job related to course is asked only when Item 22 = Yes.',
      );
    });
  });

  group('group by', () {
    test('only single-answer, non-personal fields can group', () {
      expect(
        errors(base.copyWith(groupBy: ['ched_17'])),
        contains('group_invalid'),
      );
      expect(
        errors(base.copyWith(groupBy: ['ched_34'])),
        contains('group_invalid'),
      );
      expect(
        errors(base.copyWith(groupBy: ['ched_1'])),
        contains('group_invalid'),
      );
      expect(
        check(base.copyWith(groupBy: ['course', 'year_graduated'])).isValid,
        isTrue,
      );
    });

    test('at most two distinct fields, never the measure itself', () {
      expect(
        errors(base.copyWith(groupBy: ['course', 'year_graduated', 'ched_21'])),
        contains('too_many_groups'),
      );
      expect(
        errors(base.copyWith(groupBy: ['course', 'course'])),
        contains('duplicate_group'),
      );
      expect(
        errors(base.copyWith(groupBy: ['ched_16'])),
        contains('group_is_measure'),
      );
      expect(
        errors(base.copyWith(groupBy: ['zzz'])),
        contains('group_unknown'),
      );
    });

    test('demographic groups warn about small groups', () {
      expect(
        warnings(base.copyWith(groupBy: ['ched_7'])),
        contains('demographic_group'),
      );
    });
  });

  group('charts', () {
    test('no donut for multi-select or grouped data', () {
      expect(
        errors(base.copyWith(measure: 'ched_33', chart: GtsChartType.donut)),
        contains('chart_invalid'),
      );
      expect(
        errors(base.copyWith(groupBy: ['course'], chart: GtsChartType.donut)),
        contains('chart_invalid'),
      );
    });

    test('long or numerous answers suggest a horizontal bar', () {
      expect(
        warnings(base.copyWith(measure: 'ched_20', chart: GtsChartType.donut)),
        contains('donut_many_slices'),
      );
      expect(
        warnings(base.copyWith(measure: 'ched_20', chart: GtsChartType.bar)),
        contains('long_labels'),
      );
      expect(
        warnings(
          base.copyWith(measure: 'ched_20', chart: GtsChartType.horizontalBar),
        ),
        isNot(contains('long_labels')),
      );
    });

    test('lines need a year or wave first', () {
      final line = base.copyWith(chart: GtsChartType.line);
      expect(errors(line), contains('chart_invalid'));
      expect(
        errors(line.copyWith(groupBy: ['course'])),
        contains('chart_invalid'),
      );
      expect(check(line.copyWith(groupBy: ['year_graduated'])).isValid, isTrue);
    });

    test('stacked bars need a group and single answers', () {
      expect(
        errors(base.copyWith(chart: GtsChartType.stackedBar)),
        contains('chart_invalid'),
      );
      expect(
        errors(
          base.copyWith(
            measure: 'ched_33',
            groupBy: ['course'],
            chart: GtsChartType.stackedBar,
          ),
        ),
        contains('chart_invalid'),
      );
      expect(
        check(
          base.copyWith(groupBy: ['course'], chart: GtsChartType.stackedBar),
        ).isValid,
        isTrue,
      );
    });

    test('chartIssue gives a reason the UI can show', () {
      final reason = GtsReportValidator.chartIssue(
        base.copyWith(measure: 'ched_17'),
        GtsChartType.donut,
      );
      expect(reason, contains('use a bar chart'));
      expect(GtsReportValidator.chartIssue(base, GtsChartType.table), isNull);
    });
  });

  group('filters', () {
    GtsReportConfig withFilter(String field, List<String> values) =>
        base.copyWith(
          filters: [GtsReportFilter(field: field, values: values)],
        );

    test('blocks unknown, personal, written and empty filters', () {
      expect(errors(withFilter('zzz', ['x'])), contains('filter_unknown'));
      expect(
        errors(withFilter('ched_3', ['a@b.c'])),
        contains('filter_invalid'),
      );
      expect(
        errors(withFilter('ched_19', ['Teacher'])),
        contains('filter_invalid'),
      );
      expect(errors(withFilter('course', [])), contains('filter_empty'));
    });

    test('allows multi-select filters and warns on unlisted values', () {
      expect(
        check(withFilter('ched_17', ['No job opportunity'])).isValid,
        isTrue,
      );
      expect(
        warnings(withFilter('ched_21', ['Overseas'])),
        contains('filter_value_unlisted'),
      );
    });

    test('conditional filters explain who remains', () {
      expect(
        warnings(withFilter('ched_21', ['Abroad'])),
        contains('filter_conditional'),
      );
      expect(
        warnings(withFilter('course', ['BSIT'])),
        isNot(contains('filter_conditional')),
      );
    });

    test('one filter per field', () {
      final c = base.copyWith(
        filters: const [
          GtsReportFilter(field: 'course', values: ['BSIT']),
          GtsReportFilter(field: 'course', values: ['BSCS']),
        ],
      );
      expect(errors(c), contains('duplicate_filter'));
    });
  });

  test('share explanations name the denominator', () {
    final q24 = GtsFieldDictionary.byKey('ched_24a')!;
    expect(
      GtsReportValidator.shareExplanation(q24, GtsCalculation.shareOfEligible),
      'Percent of graduates who were asked item 24, including those who '
      'left it blank.',
    );
    final course = GtsFieldDictionary.byKey('course')!;
    expect(
      GtsReportValidator.shareExplanation(
        course,
        GtsCalculation.shareOfAllRespondents,
      ),
      'Percent of all graduates in the report.',
    );
  });
}
