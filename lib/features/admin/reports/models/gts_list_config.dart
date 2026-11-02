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

  /// Text in the Tracer status column. Employment stays on item 16.
  String get columnLabel => switch (this) {
    GtsTracerStatus.employed ||
    GtsTracerStatus.notEmployed ||
    GtsTracerStatus.neverEmployed ||
    GtsTracerStatus.statusNotGiven => 'Answered',
    _ => label,
  };

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

/// Chart style for alumni-list distributions.
enum GtsListChart {
  none,
  /// Horizontal bars (best for long category labels).
  bars,
  /// Vertical bars.
  verticalBars,
  donut,
}

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
    this.includeTable = true,
    this.includeTally = true,
    this.includeUntracked = true,
    this.version = currentVersion,
    this.templateKey,
    this.title = '',
    this.description = '',
  });

  /// Stored as `mode` so saved lists are told apart from summary reports.
  static const mode = 'list';
  static const currentVersion = 3;

  /// Name column: best available name for every included row.
  /// Saved lists used `name` before version 2; section A `ched_1` folds in.
  static const nameColumn = 'untracked_name';
  static const legacyNameColumn = 'name';
  static const sectionANameColumn = 'ched_1';

  static const _removedColumns = {
    'registration',
    'email',
    'contact',
    'wave',
  };
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

  /// The row grid in the preview and the export.
  final bool includeTable;

  /// The column tally in the preview and the export.
  final bool includeTally;

  /// When false, alumni who have not submitted the tracer are hidden.
  final bool includeUntracked;

  bool get includeCharts => chart != GtsListChart.none;

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
    bool? includeTable,
    bool? includeTally,
    bool? includeUntracked,
    String? templateKey,
    String? title,
    String? description,
  }) => GtsListConfig(
    version: currentVersion,
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
    includeTable: includeTable ?? this.includeTable,
    includeTally: includeTally ?? this.includeTally,
    includeUntracked: includeUntracked ?? this.includeUntracked,
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
    'includeTable': includeTable,
    'includeTally': includeTally,
    'includeUntracked': includeUntracked,
  };

  /// `name` and section A `ched_1` become [nameColumn]. Removed keys are dropped.
  static List<String> migrateColumns(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final key in raw) {
      if (_removedColumns.contains(key)) continue;
      final next = key == legacyNameColumn || key == sectionANameColumn
          ? nameColumn
          : key;
      if (seen.add(next)) out.add(next);
    }
    return out;
  }

  static String? migrateSort(Object? raw) {
    final key = raw?.toString();
    if (key == null || key.isEmpty || _removedColumns.contains(key)) {
      return null;
    }
    if (key == legacyNameColumn || key == sectionANameColumn) {
      return nameColumn;
    }
    return key;
  }

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
    final migrated = json['columns'] is List
        ? migrateColumns(strings(json['columns']))
        : defaultColumns;
    return GtsListConfig(
      version: currentVersion,
      templateKey: json['templateKey']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      surveyId: json['surveyId']?.toString(),
      columns: migrated.isEmpty ? defaultColumns : migrated,
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
      sortBy: migrateSort(json['sortBy']),
      sortDescending: json['sortDescending'] == true,
      chart: GtsListChart.values.firstWhere(
        (v) => v.name == json['chart'],
        orElse: () => GtsListChart.bars,
      ),
      includeTable: json['includeTable'] != false,
      includeTally: json['includeTally'] != false,
      includeUntracked: json['includeUntracked'] != false,
    );
  }
}
