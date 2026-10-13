import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

/// Where a graduate stands in the tracer, as listed and tallied in an
/// alumni list. Same split as the Tracer tab coverage funnel (not
/// registered / registered without a tracer / took the tracer) and the
/// DSS item 16 answers.
enum GtsTracerStatus {
  employed('Employed'),
  notEmployed('Not employed'),
  neverEmployed('Never employed'),
  statusNotGiven('Answered, status not given'),
  untrackedRegistered('Untracked – registered, not yet answered'),
  untrackedNotRegistered('Untracked – not registered'),
  offRoster('Answered – not on active roster');

  const GtsTracerStatus(this.label);

  final String label;

  /// Submitted the tracer in scope.
  bool get answered => !untracked;

  bool get untracked =>
      this == untrackedRegistered || this == untrackedNotRegistered;

  /// Counted in the list's total alumni (the active roster in scope).
  bool get onRoster => this != offRoster;

  static GtsTracerStatus? byName(Object? raw) {
    for (final s in values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

/// Subtotal tallies under each group of rows.
enum GtsListSubtotal { none, batch, course }

/// Chart of the tracer-status tally.
enum GtsListChart { none, bars, donut }

/// An alumni list definition: one row per alumnus on the active roster.
/// Holds column keys and filters only, never names or answers.
class GtsListConfig {
  const GtsListConfig({
    this.surveyId,
    this.columns = defaultColumns,
    this.courses = const [],
    this.batches = const [],
    this.statuses = const [],
    this.answerFilters = const [],
    this.subtotalBy = GtsListSubtotal.none,
    this.sortBy,
    this.sortDescending = false,
    this.chart = GtsListChart.bars,
    this.version = currentVersion,
    this.templateKey,
    this.title = '',
    this.description = '',
  });

  /// Stored as `mode` so saved lists are told apart from summary reports.
  static const mode = 'list';
  static const currentVersion = 1;

  static const nameColumn = 'name';
  static const courseColumn = 'course';
  static const batchColumn = 'year_graduated';
  static const statusColumn = 'tracer_status';

  /// Added automatically; the admin can move or remove any of them.
  static const defaultColumns = [
    batchColumn,
    nameColumn,
    courseColumn,
    statusColumn,
  ];

  final int version;
  final String? templateKey;
  final String title;
  final String description;

  /// Tracer wave in scope; null uses each graduate's latest answer from any
  /// CHED wave.
  final String? surveyId;

  /// Column keys in display order.
  final List<String> columns;

  /// Only these roster courses / batches (empty = all).
  final List<String> courses;
  final List<String> batches;

  /// Only these tracer statuses (empty = all).
  final List<GtsTracerStatus> statuses;

  /// CHED answer filters; untracked alumni never match one.
  final List<GtsReportFilter> answerFilters;

  final GtsListSubtotal subtotalBy;

  /// Column key to sort by; null sorts by batch, then name.
  final String? sortBy;
  final bool sortDescending;
  final GtsListChart chart;

  bool get latestFromAnyWave => surveyId == null;

  static bool isList(Map<String, dynamic> json) => json['mode'] == mode;

  GtsListConfig copyWith({
    String? surveyId,
    bool latestFromAnyWave = false,
    List<String>? columns,
    List<String>? courses,
    List<String>? batches,
    List<GtsTracerStatus>? statuses,
    List<GtsReportFilter>? answerFilters,
    GtsListSubtotal? subtotalBy,
    String? sortBy,
    bool clearSortBy = false,
    bool? sortDescending,
    GtsListChart? chart,
    String? templateKey,
    String? title,
    String? description,
  }) => GtsListConfig(
    version: version,
    surveyId: latestFromAnyWave ? null : (surveyId ?? this.surveyId),
    columns: columns ?? this.columns,
    courses: courses ?? this.courses,
    batches: batches ?? this.batches,
    statuses: statuses ?? this.statuses,
    answerFilters: answerFilters ?? this.answerFilters,
    subtotalBy: subtotalBy ?? this.subtotalBy,
    sortBy: clearSortBy ? null : (sortBy ?? this.sortBy),
    sortDescending: sortDescending ?? this.sortDescending,
    chart: chart ?? this.chart,
    templateKey: templateKey ?? this.templateKey,
    title: title ?? this.title,
    description: description ?? this.description,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'version': version,
    'templateKey': ?templateKey,
    'title': title,
    'description': description,
    'surveyId': ?surveyId,
    'columns': columns,
    'courses': courses,
    'batches': batches,
    'statuses': [for (final s in statuses) s.name],
    'answerFilters': [for (final f in answerFilters) f.toJson()],
    'subtotalBy': subtotalBy.name,
    'sortBy': ?sortBy,
    'sortDescending': sortDescending,
    'chart': chart.name,
  };

  /// Throws [FormatException] for lists saved by a newer app version or
  /// for settings that are not an alumni list.
  factory GtsListConfig.fromJson(Map<String, dynamic> json) {
    if (!isList(json)) {
      throw const FormatException('These settings are not an alumni list.');
    }
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version > currentVersion) {
      throw FormatException(
        'Alumni list saved by a newer version of AESS (v$version).',
      );
    }
    List<String> strings(Object? raw) => [
      for (final v in (raw as List? ?? const [])) v.toString(),
    ];
    final subtotal = json['subtotalBy'];
    return GtsListConfig(
      version: version,
      templateKey: json['templateKey']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      surveyId: json['surveyId']?.toString(),
      columns: json['columns'] is List
          ? strings(json['columns'])
          : defaultColumns,
      courses: strings(json['courses']),
      batches: strings(json['batches']),
      statuses: [
        for (final raw in (json['statuses'] as List? ?? const []))
          ?GtsTracerStatus.byName(raw),
      ],
      answerFilters: [
        for (final f in (json['answerFilters'] as List? ?? const []))
          if (f is Map) GtsReportFilter.fromJson(Map<String, dynamic>.from(f)),
      ],
      subtotalBy: GtsListSubtotal.values.firstWhere(
        (v) => v.name == subtotal,
        orElse: () => GtsListSubtotal.none,
      ),
      sortBy: json['sortBy']?.toString(),
      sortDescending: json['sortDescending'] == true,
      chart: GtsListChart.values.firstWhere(
        (v) => v.name == json['chart'],
        orElse: () => GtsListChart.bars,
      ),
    );
  }
}
