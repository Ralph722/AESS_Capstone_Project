import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

enum GtsIssueSeverity {
  /// The report cannot run.
  error,

  /// The report runs but may mislead; suggest a better choice.
  warning,

  /// Explains how the numbers are calculated.
  note,
}

class GtsReportIssue {
  const GtsReportIssue(this.severity, this.code, this.message);

  final GtsIssueSeverity severity;

  /// Stable identifier for tests and UI hooks.
  final String code;

  /// Plain-language message for administrators.
  final String message;

  @override
  String toString() => '${severity.name}: $code';
}

class GtsReportValidation {
  const GtsReportValidation(this.issues);

  final List<GtsReportIssue> issues;

  bool get isValid => !issues.any((i) => i.severity == GtsIssueSeverity.error);

  Iterable<GtsReportIssue> of(GtsIssueSeverity severity) =>
      issues.where((i) => i.severity == severity);

  bool has(String code) => issues.any((i) => i.code == code);
}

/// Checks a [GtsReportConfig] against the GTS field dictionary so only
/// meaningful combinations run.
abstract final class GtsReportValidator {
  /// Most slices a donut can show and still be readable.
  static const donutMaxSlices = 6;

  /// Longest label a vertical bar axis can show.
  static const verticalLabelMax = 25;

  /// Categories above which a top-N limit is suggested.
  static const manyCategories = 20;

  static GtsReportValidation validate(
    GtsReportConfig config, {
    bool forSave = false,
  }) {
    final issues = <GtsReportIssue>[];
    void error(String code, String message) =>
        issues.add(GtsReportIssue(GtsIssueSeverity.error, code, message));
    void warning(String code, String message) =>
        issues.add(GtsReportIssue(GtsIssueSeverity.warning, code, message));
    void note(String code, String message) =>
        issues.add(GtsReportIssue(GtsIssueSeverity.note, code, message));

    if (forSave && config.title.trim().isEmpty) {
      error('title_missing', 'Enter a report name.');
    }
    if (config.surveyIds.isEmpty) {
      error('no_wave', 'Select at least one tracer wave.');
    } else if (config.surveyIds.length > 1 &&
        !config.groupBy.contains(GtsFieldDictionary.wave)) {
      error(
        'waves_not_grouped',
        'Several waves are selected. Compare them by tracer wave so each '
            'graduate is counted once per wave instead of being added together.',
      );
    }

    final measure = GtsFieldDictionary.byKey(config.measure);
    if (measure == null) {
      error('measure_unknown', 'Choose a field to report on.');
      return GtsReportValidation(issues);
    }

    if (measure.isPersonal) {
      error(
        'measure_personal',
        '${measure.label} is personal information. It can only appear in '
            'the alumni directory, not in a calculated report.',
      );
    }

    final calcReason = measure.isPersonal
        ? null
        : calculationIssue(measure, config.calculation);
    if (calcReason != null) error('calculation_invalid', calcReason);

    final column = config.gridColumn;
    if (column != null) {
      if (measure.valueClass != GtsValueClass.grid) {
        error(
          'grid_column_invalid',
          'A column can only be chosen for a grid question.',
        );
      } else if (!measure.gridColumns.contains(column)) {
        error('grid_column_invalid', '"$column" is not a column of this item.');
      }
    }

    _checkGroupBy(config, measure, error, warning, note);
    _checkFilters(config, measure, error, warning);

    final chartReason = chartIssue(config, config.chart);
    if (chartReason != null) error('chart_invalid', chartReason);
    _chartAdvice(config, measure, warning);

    final topN = config.topN;
    if (topN != null && topN < 1) {
      error('top_n_invalid', 'Show at least one category.');
    } else if (topN == null &&
        measure.options.length > manyCategories &&
        config.chart != GtsChartType.table) {
      warning(
        'many_categories',
        '${measure.label} has ${measure.options.length} answers. Show the top '
            '10 and fold the rest into "All other answers" to keep the chart '
            'readable.',
      );
    }

    if (measure.isConditional &&
        config.calculation == GtsCalculation.shareOfAllRespondents) {
      warning(
        'share_includes_not_asked',
        '${measure.label} is asked only when ${measure.askedOf}. Shares of '
            'all respondents include people who were never asked; share of '
            'answered is usually clearer.',
      );
    }
    if (measure.isConditional) {
      note(
        'asked_of',
        '${measure.numberedLabel} is asked only when ${measure.askedOf}.',
      );
    }
    if (measure.factNote != null) {
      note('field_note', '${measure.label}: ${measure.factNote}');
    }
    if (config.calculation != GtsCalculation.count &&
        config.calculation != GtsCalculation.medianBracket &&
        config.calculation != GtsCalculation.answeredCount) {
      note('denominator', shareExplanation(measure, config.calculation));
    }
    if (measure.valueClass == GtsValueClass.multiSelect ||
        (measure.valueClass == GtsValueClass.grid && column == null)) {
      note(
        'shares_over_100',
        'Graduates can pick more than one answer, so shares can add up to '
            'more than 100%.',
      );
    }
    note(
      'small_groups',
      'Groups with fewer than ${DssPolicy.notEnoughBelow} answers show '
          '"Not enough data"; their counts and percentages are hidden so no '
          'graduate can be identified.',
    );

    return GtsReportValidation(issues);
  }

  /// Why [calculation] cannot be used on [field]; null when it can.
  static String? calculationIssue(GtsField field, GtsCalculation calculation) {
    if (field.allows(calculation)) return null;
    if (field.isPersonal) return '${field.label} cannot be calculated.';
    return switch (calculation) {
      GtsCalculation.medianBracket =>
        'A median needs ordered brackets; ${field.label} has none.',
      GtsCalculation.answeredCount =>
        'Use a count or share for ${field.label}.',
      _ => switch (field.valueClass) {
        GtsValueClass.freeText || GtsValueClass.table =>
          '${field.label} is written text; only the number of answers can '
              'be counted.',
        _ => 'This calculation is not available for ${field.label}.',
      },
    };
  }

  /// Why [chart] cannot show [config]; null when it can.
  static String? chartIssue(GtsReportConfig config, GtsChartType chart) {
    final measure = GtsFieldDictionary.byKey(config.measure);
    if (measure == null) return null;
    final multi =
        measure.valueClass == GtsValueClass.multiSelect ||
        (measure.valueClass == GtsValueClass.grid && config.gridColumn == null);
    final groups = config.groupBy.length;

    if (chart == GtsChartType.table) return null;
    if (config.calculation == GtsCalculation.medianBracket) {
      return 'A median bracket is a label, not a number; show it as a table.';
    }
    switch (chart) {
      case GtsChartType.donut:
        if (multi) {
          return 'A donut needs answers that add up to 100%. Graduates can '
              'pick several answers here; use a bar chart.';
        }
        if (groups > 0) return 'A donut shows one group; use grouped bars.';
        if (config.calculation == GtsCalculation.answeredCount) {
          return 'A donut needs answer categories; use a bar chart.';
        }
      case GtsChartType.line:
        final first = groups == 0
            ? null
            : GtsFieldDictionary.byKey(config.groupBy.first);
        final ordered =
            first != null &&
            (first.key == GtsFieldDictionary.wave ||
                first.valueClass == GtsValueClass.year);
        if (!ordered) {
          return 'A line shows change over time; compare by batch or '
              'compare tracer waves.';
        }
        if (groups > 1) {
          return 'A line can follow one comparison only; remove the second '
              'or use grouped bars.';
        }
      case GtsChartType.groupedBar:
        if (groups == 0) return 'Grouped bars need a "Compare by" choice.';
      case GtsChartType.stackedBar:
        if (groups == 0) return 'Stacked bars need a "Compare by" choice.';
        if (multi) {
          return 'Stacked bars would add multi-select shares past 100%; use '
              'grouped bars.';
        }
        if (config.calculation == GtsCalculation.answeredCount) {
          return 'Stacked bars need answer categories.';
        }
      case GtsChartType.bar:
      case GtsChartType.horizontalBar:
      case GtsChartType.table:
        break;
    }
    return null;
  }

  /// Plain-language denominator, e.g. "Percent of graduates who answered
  /// item 24."
  static String shareExplanation(GtsField field, GtsCalculation calculation) {
    final number = field.chedNumber;
    if (number == null) return 'Percent of all graduates in the report.';
    final item = 'item $number';
    return switch (calculation) {
      GtsCalculation.shareOfAnswered =>
        'Percent of graduates who answered $item.',
      GtsCalculation.shareOfEligible =>
        'Percent of graduates who were asked $item, including those who left '
            'it blank.',
      GtsCalculation.shareOfAllRespondents =>
        'Percent of all graduates in the report, whether or not they were '
            'asked $item.',
      _ => '',
    };
  }

  static void _checkGroupBy(
    GtsReportConfig config,
    GtsField measure,
    void Function(String, String) error,
    void Function(String, String) warning,
    void Function(String, String) note,
  ) {
    final keys = config.groupBy;
    if (keys.length > GtsReportConfig.maxGroupBy) {
      error(
        'too_many_groups',
        'Group by at most ${GtsReportConfig.maxGroupBy} fields.',
      );
    }
    if (keys.toSet().length != keys.length) {
      error('duplicate_group', 'Each group-by field can be used once.');
    }
    for (final key in keys) {
      final f = GtsFieldDictionary.byKey(key);
      if (f == null) {
        error('group_unknown', 'Unknown group-by field "$key".');
        continue;
      }
      if (key == measure.key) {
        error(
          'group_is_measure',
          'Group by a different field than the one being measured.',
        );
      } else if (!f.groupable) {
        error('group_invalid', _notGroupableReason(f));
      }
      if (f.sensitivity == GtsSensitivity.demographic) {
        warning(
          'demographic_group',
          'Grouping by ${f.label.toLowerCase()} can make groups small. '
              'Groups under ${DssPolicy.notEnoughBelow} answers are hidden.',
        );
      }
    }
    if (keys.length == GtsReportConfig.maxGroupBy) {
      note(
        'two_groups',
        'Two group-by fields split graduates into many small groups; '
            'check the answer counts before drawing conclusions.',
      );
    }
  }

  static String _notGroupableReason(GtsField f) {
    if (f.isPersonal) {
      return '${f.label} is personal information and cannot be used to '
          'group a report.';
    }
    return switch (f.valueClass) {
      GtsValueClass.multiSelect =>
        '${f.label} allows several answers, so a graduate would land in '
            'several groups. Use it as a filter instead.',
      GtsValueClass.freeText || GtsValueClass.table =>
        '${f.label} is written text and has no fixed groups.',
      _ => '${f.label} cannot be used to group a report.',
    };
  }

  static void _checkFilters(
    GtsReportConfig config,
    GtsField measure,
    void Function(String, String) error,
    void Function(String, String) warning,
  ) {
    final seen = <String>{};
    for (final filter in config.filters) {
      final f = GtsFieldDictionary.byKey(filter.field);
      if (f == null) {
        error('filter_unknown', 'Unknown filter field "${filter.field}".');
        continue;
      }
      if (!seen.add(f.key)) {
        error(
          'duplicate_filter',
          'Combine the ${f.label.toLowerCase()} filters into one.',
        );
      }
      if (!f.filterable) {
        error(
          'filter_invalid',
          f.isPersonal
              ? '${f.label} is personal information and cannot be used as a '
                    'filter.'
              : '${f.label} is written text and cannot be used as a filter.',
        );
        continue;
      }
      if (filter.values.isEmpty) {
        error('filter_empty', 'Choose at least one ${f.label} value.');
        continue;
      }
      if (f.options.isNotEmpty) {
        final unknown = filter.values.where((v) => !f.options.contains(v));
        if (unknown.isNotEmpty) {
          warning(
            'filter_value_unlisted',
            '${f.label}: "${unknown.join('", "')}" is not a questionnaire '
                'answer, so it only matches older or edited responses.',
          );
        }
      }
      if (f.isConditional) {
        warning(
          'filter_conditional',
          'Filtering on ${f.numberedLabel} keeps only graduates who were '
              'asked it (${f.askedOf}).',
        );
      }
    }
  }

  static void _chartAdvice(
    GtsReportConfig config,
    GtsField measure,
    void Function(String, String) warning,
  ) {
    final categories = measure.valueClass == GtsValueClass.grid
        ? measure.gridRows
        : measure.options;
    if (config.chart == GtsChartType.donut &&
        categories.length > donutMaxSlices) {
      warning(
        'donut_many_slices',
        '${measure.label} has ${categories.length} answers; a horizontal bar '
            'chart is easier to read than a donut.',
      );
    }
    if (config.chart == GtsChartType.bar &&
        categories.any((c) => c.length > verticalLabelMax)) {
      warning(
        'long_labels',
        'Some ${measure.label.toLowerCase()} answers are long; a horizontal '
            'bar chart keeps them readable.',
      );
    }
  }
}
