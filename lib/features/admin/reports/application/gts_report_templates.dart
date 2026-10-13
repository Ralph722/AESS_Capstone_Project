import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/models/gts_report_config.dart';

/// A ready-made starting point for the report builder. Templates are plain
/// [GtsReportConfig]s, so they run through the same validator and engine as
/// any custom report and can be adjusted after they are applied.
class GtsReportTemplate {
  const GtsReportTemplate({
    required this.key,
    required this.name,
    required this.summary,
    required this.config,
  });

  final String key;
  final String name;

  /// One line shown in the template picker.
  final String summary;

  /// Settings without waves; [forWaves] adds them.
  final GtsReportConfig config;

  /// Several waves are compared side by side: grouped by wave first, and a
  /// donut (one group only) becomes stacked bars.
  GtsReportConfig forWaves(List<String> surveyIds) {
    if (surveyIds.length < 2) return config.copyWith(surveyIds: surveyIds);
    return config.copyWith(
      surveyIds: surveyIds,
      groupBy: [GtsFieldDictionary.wave, ...config.groupBy],
      chart: config.chart == GtsChartType.donut
          ? GtsChartType.stackedBar
          : config.chart,
    );
  }
}

abstract final class GtsReportTemplates {
  static const _notEmployedNote =
      'The "No" and "Never Employed" shares together are the not-employed '
      'rate the DSS uses.';

  static const all = [
    GtsReportTemplate(
      key: 'employment_summary',
      name: 'Employment summary',
      summary: 'Item 16, presently employed, for the whole institution.',
      config: GtsReportConfig(
        templateKey: 'employment_summary',
        title: 'Employment summary',
        description:
            'Whether graduates are presently employed (item 16), as a share '
            'of those who answered. $_notEmployedNote',
        surveyIds: [],
        measure: 'ched_16',
        population: GtsPopulation.rosterLinked,
        chart: GtsChartType.donut,
      ),
    ),
    GtsReportTemplate(
      key: 'employment_by_year',
      name: 'Employment status by graduation year',
      summary: 'Item 16 for each batch.',
      config: GtsReportConfig(
        templateKey: 'employment_by_year',
        title: 'Employment status by graduation year',
        description:
            'Item 16 answers for each graduation year (batch) on the roster. '
            '$_notEmployedNote',
        surveyIds: [],
        measure: 'ched_16',
        population: GtsPopulation.rosterLinked,
        groupBy: [GtsFieldDictionary.yearGraduated],
        chart: GtsChartType.stackedBar,
      ),
    ),
    GtsReportTemplate(
      key: 'employment_by_course',
      name: 'Employment status by course',
      summary: 'Item 16 for each course, with sample sizes.',
      config: GtsReportConfig(
        templateKey: 'employment_by_course',
        title: 'Employment status by course',
        description:
            'Item 16 answers for each course on the roster. '
            '$_notEmployedNote',
        surveyIds: [],
        measure: 'ched_16',
        population: GtsPopulation.rosterLinked,
        groupBy: [GtsFieldDictionary.course],
        chart: GtsChartType.stackedBar,
      ),
    ),
    GtsReportTemplate(
      key: 'degree_alignment',
      name: 'First job related to course',
      summary: 'Item 24 for each course (asked only when item 22 = Yes).',
      config: GtsReportConfig(
        templateKey: 'degree_alignment',
        title: 'First job related to course',
        description:
            'Whether the first job was related to the course (item 24), for '
            'each course. Item 24 is asked only of graduates whose present '
            'job is their first job after college (item 22 = Yes).',
        surveyIds: [],
        measure: 'ched_24a',
        population: GtsPopulation.rosterLinked,
        groupBy: [GtsFieldDictionary.course],
        chart: GtsChartType.stackedBar,
      ),
    ),
    GtsReportTemplate(
      key: 'employment_type',
      name: 'Employment type',
      summary: 'Item 18, present employment status, among the employed.',
      config: GtsReportConfig(
        templateKey: 'employment_type',
        title: 'Employment type',
        description:
            'Present employment status (item 18) of graduates who are '
            'employed (item 16 = Yes).',
        surveyIds: [],
        measure: 'ched_18',
        population: GtsPopulation.rosterLinked,
        chart: GtsChartType.donut,
      ),
    ),
    GtsReportTemplate(
      key: 'industry',
      name: 'Industry (line of business)',
      summary: 'Item 20, the 10 most common lines of business.',
      config: GtsReportConfig(
        templateKey: 'industry',
        title: 'Industry (line of business)',
        description:
            'Line of business of the employer (item 20) of graduates who are '
            'employed. The 10 most common are shown; the rest are combined.',
        surveyIds: [],
        measure: 'ched_20',
        population: GtsPopulation.rosterLinked,
        chart: GtsChartType.horizontalBar,
        sortBy: GtsSortBy.count,
        sortDescending: true,
        topN: 10,
      ),
    ),
  ];

  static GtsReportTemplate? byKey(String? key) {
    for (final t in all) {
      if (t.key == key) return t;
    }
    return null;
  }
}
