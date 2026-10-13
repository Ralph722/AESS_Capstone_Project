import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/application/gts_report_engine.dart';
import 'package:alumni_system/features/admin/reports/application/gts_stats.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

/// One CHED GTS wave's submitted responses.
typedef TracerWave = ({String surveyId, List<GtsRespondent> respondents});

/// Numbers behind the admin Tracer tab. Every card is a [GtsReportEngine]
/// result over roster-linked graduates (the DSS population) inside the
/// dashboard's wave, course and batch filters, so the tab, the report
/// builder and Program Insights count the same people the same way. With
/// every wave in scope, each graduate counts once, from their latest wave.
class TracerTabStats {
  TracerTabStats._(this._waves, this._latest);

  /// [waves] oldest first. [course] and [batch] match the roster values
  /// ignoring case; null means no filter.
  factory TracerTabStats({
    required List<TracerWave> waves,
    String? surveyId,
    String? course,
    String? batch,
  }) {
    final c = course?.trim().toLowerCase();
    final b = batch?.trim().toLowerCase();
    bool inCohort(GtsRespondent r) =>
        (c == null || r.course.trim().toLowerCase() == c) &&
        (b == null || r.yearGraduated.trim().toLowerCase() == b);

    final scoped = <TracerWave>[];
    final latest = <String, GtsRespondent>{};
    for (final w in waves) {
      if (surveyId != null && w.surveyId != surveyId) continue;
      final byUser = <String, GtsRespondent>{
        for (final r in w.respondents)
          if (r.userId.isNotEmpty && inCohort(r)) r.userId: r,
      };
      scoped.add((surveyId: w.surveyId, respondents: [...byUser.values]));
      for (final r in byUser.values) {
        latest[r.userId] = GtsRespondent(
          userId: r.userId,
          surveyId: latestWave,
          answers: r.answers,
          course: r.course,
          yearGraduated: r.yearGraduated,
          onActiveRoster: r.onActiveRoster,
        );
      }
    }
    return TracerTabStats._(scoped, [...latest.values]);
  }

  /// Survey id given to each graduate's latest answer.
  static const latestWave = 'latest';

  static const employedFilter = GtsReportFilter(
    field: 'ched_16',
    values: [ChedGtsBuiltin.yes],
  );

  final List<TracerWave> _waves;
  final List<GtsRespondent> _latest;
  final _cache = <String, GtsReportResult>{};

  /// [measure] over the graduates in scope. [employedOnly] keeps graduates
  /// who answered item 16 "Yes".
  GtsReportResult run(
    String measure, {
    String? groupBy,
    bool employedOnly = false,
    int? topN,
    bool byCount = false,
  }) => _cache.putIfAbsent(
    [measure, groupBy, employedOnly, topN, byCount].join('|'),
    () => GtsReportEngine.run(
      GtsReportConfig(
        surveyIds: const [latestWave],
        measure: measure,
        population: GtsPopulation.rosterLinked,
        groupBy: [?groupBy],
        filters: [if (employedOnly) employedFilter],
        topN: topN,
        sortBy: byCount ? GtsSortBy.count : GtsSortBy.natural,
        sortDescending: byCount,
      ),
      _latest,
    ),
  );

  /// Item 16 for everyone in scope.
  GtsReportRow get employment => run('ched_16').total;

  /// Item 16 per wave (each wave's own answers), oldest first. Waves
  /// without roster-linked respondents are left out.
  List<({String surveyId, GtsReportRow row})> employmentByWave() {
    final ids = [for (final w in _waves) w.surveyId];
    if (ids.isEmpty) return const [];
    final result = GtsReportEngine.run(
      GtsReportConfig(
        surveyIds: ids,
        measure: 'ched_16',
        population: GtsPopulation.rosterLinked,
        groupBy: const [GtsFieldDictionary.wave],
      ),
      [for (final w in _waves) ...w.respondents],
    );
    return [
      for (final row in result.rows)
        (surveyId: row.groupValues.first, row: row),
    ];
  }

  /// Roster-linked graduates in scope whose [groupBy] value is [label].
  List<GtsRespondent> membersOf(String groupBy, String label) {
    final field = GtsFieldDictionary.byKey(groupBy)!;
    return [
      for (final r in _latest)
        if (r.isRosterLinked && GtsStats.read(field, r).values.first == label)
          r,
    ];
  }

  /// "Yes" answers in [row].
  static int yes(GtsReportRow row) => row.counts[ChedGtsBuiltin.yes] ?? 0;
}
