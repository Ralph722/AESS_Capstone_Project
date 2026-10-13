import 'package:alumni_system/features/admin/reports/models/gts_field.dart';

enum GtsChartType {
  table,
  bar,
  horizontalBar,
  donut,
  line,
  groupedBar,
  stackedBar,
}

enum GtsSortBy {
  /// Questionnaire order for answers, chronological for years.
  natural,
  label,
  count,
  share,
}

/// Who a report counts.
enum GtsPopulation {
  /// Every submitted response in the selected wave(s).
  allRespondents,

  /// Only respondents linked to an active roster record with a course,
  /// the same population the DSS uses.
  rosterLinked,
}

/// Keeps respondents whose [field] answer is any of [values]. For
/// multi-select fields a respondent matches when any picked option is listed.
class GtsReportFilter {
  const GtsReportFilter({required this.field, required this.values});

  final String field;
  final List<String> values;

  Map<String, dynamic> toJson() => {'field': field, 'values': values};

  factory GtsReportFilter.fromJson(Map<String, dynamic> json) =>
      GtsReportFilter(
        field: json['field']?.toString() ?? '',
        values: [
          for (final v in (json['values'] as List? ?? const [])) v.toString(),
        ],
      );
}

/// A GTS report definition. Holds field keys from the GTS field dictionary,
/// never results or personal data.
class GtsReportConfig {
  const GtsReportConfig({
    required this.surveyIds,
    required this.measure,
    this.version = currentVersion,
    this.templateKey,
    this.title = '',
    this.description = '',
    this.population = GtsPopulation.allRespondents,
    this.gridColumn,
    this.calculation = GtsCalculation.shareOfAnswered,
    this.groupBy = const [],
    this.filters = const [],
    this.sortBy = GtsSortBy.natural,
    this.sortDescending = false,
    this.chart = GtsChartType.table,
    this.showTable = true,
    this.topN,
  });

  static const currentVersion = 1;
  static const maxGroupBy = 2;

  final int version;

  /// Template this report started from; null for a custom report.
  final String? templateKey;
  final String title;
  final String description;

  /// Tracer waves in scope. Several waves must be grouped by wave.
  final List<String> surveyIds;
  final GtsPopulation population;

  /// Dictionary key of the field being measured.
  final String measure;

  /// Grid column to count (item 30: first or current job).
  final String? gridColumn;

  final GtsCalculation calculation;

  /// Up to [maxGroupBy] dictionary keys: rows, then columns.
  final List<String> groupBy;

  final List<GtsReportFilter> filters;
  final GtsSortBy sortBy;
  final bool sortDescending;
  final GtsChartType chart;
  final bool showTable;

  /// Show the largest [topN] categories and fold the rest into "All other
  /// answers".
  final int? topN;

  GtsReportConfig copyWith({
    String? templateKey,
    String? title,
    String? description,
    List<String>? surveyIds,
    GtsPopulation? population,
    String? measure,
    String? gridColumn,
    bool clearGridColumn = false,
    GtsCalculation? calculation,
    List<String>? groupBy,
    List<GtsReportFilter>? filters,
    GtsSortBy? sortBy,
    bool? sortDescending,
    GtsChartType? chart,
    bool? showTable,
    int? topN,
    bool clearTopN = false,
  }) => GtsReportConfig(
    version: version,
    templateKey: templateKey ?? this.templateKey,
    title: title ?? this.title,
    description: description ?? this.description,
    surveyIds: surveyIds ?? this.surveyIds,
    population: population ?? this.population,
    measure: measure ?? this.measure,
    gridColumn: clearGridColumn ? null : (gridColumn ?? this.gridColumn),
    calculation: calculation ?? this.calculation,
    groupBy: groupBy ?? this.groupBy,
    filters: filters ?? this.filters,
    sortBy: sortBy ?? this.sortBy,
    sortDescending: sortDescending ?? this.sortDescending,
    chart: chart ?? this.chart,
    showTable: showTable ?? this.showTable,
    topN: clearTopN ? null : (topN ?? this.topN),
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'templateKey': ?templateKey,
    'title': title,
    'description': description,
    'surveyIds': surveyIds,
    'population': population.name,
    'measure': measure,
    'gridColumn': ?gridColumn,
    'calculation': calculation.name,
    'groupBy': groupBy,
    'filters': [for (final f in filters) f.toJson()],
    'sortBy': sortBy.name,
    'sortDescending': sortDescending,
    'chart': chart.name,
    'showTable': showTable,
    'topN': ?topN,
  };

  /// Throws [FormatException] for configs saved by a newer app version.
  factory GtsReportConfig.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version > currentVersion) {
      throw FormatException(
        'Report saved by a newer version of AESS (v$version).',
      );
    }
    T byName<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    List<String> strings(Object? raw) => [
      for (final v in (raw as List? ?? const [])) v.toString(),
    ];

    return GtsReportConfig(
      version: version,
      templateKey: json['templateKey']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      surveyIds: strings(json['surveyIds']),
      population: byName(
        GtsPopulation.values,
        json['population'],
        GtsPopulation.allRespondents,
      ),
      measure: json['measure']?.toString() ?? '',
      gridColumn: json['gridColumn']?.toString(),
      calculation: byName(
        GtsCalculation.values,
        json['calculation'],
        GtsCalculation.shareOfAnswered,
      ),
      groupBy: strings(json['groupBy']),
      filters: [
        for (final f in (json['filters'] as List? ?? const []))
          if (f is Map) GtsReportFilter.fromJson(Map<String, dynamic>.from(f)),
      ],
      sortBy: byName(GtsSortBy.values, json['sortBy'], GtsSortBy.natural),
      sortDescending: json['sortDescending'] == true,
      chart: byName(GtsChartType.values, json['chart'], GtsChartType.table),
      showTable: json['showTable'] != false,
      topN: (json['topN'] as num?)?.toInt(),
    );
  }
}
