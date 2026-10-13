import 'package:alumni_system/features/admin/reports/application/gts_list_columns.dart';
import 'package:alumni_system/features/admin/reports/models/gts_list_config.dart';

/// A ready-made alumni list. Templates are plain [GtsListConfig]s and can be
/// changed after they are applied.
class GtsListTemplate {
  const GtsListTemplate({
    required this.key,
    required this.name,
    required this.summary,
    required this.config,
  });

  final String key;
  final String name;

  /// One line shown in the template picker.
  final String summary;

  /// Settings without a wave; [forWave] adds it.
  final GtsListConfig config;

  /// [surveyId] null means each graduate's latest answer from any wave.
  GtsListConfig forWave(String? surveyId) => surveyId == null
      ? config.copyWith(latestFromAnyWave: true)
      : config.copyWith(surveyId: surveyId);
}

abstract final class GtsListTemplates {
  static const _batch = GtsListConfig.batchColumn;
  static const _name = GtsListConfig.nameColumn;
  static const _course = GtsListConfig.courseColumn;
  static const _status = GtsListConfig.statusColumn;

  static const all = [
    GtsListTemplate(
      key: 'list_employment_status',
      name: 'Employment status of all alumni',
      summary:
          'Every alumnus with item 16, including those who have not answered.',
      config: GtsListConfig(
        templateKey: 'list_employment_status',
        title: 'Employment status of all alumni',
        description:
            'Every alumnus on the active roster with their answer to item 16 '
            '(presently employed). Untracked alumni are listed too.',
        columns: [_batch, _name, _course, 'ched_16', _status],
      ),
    ),
    GtsListTemplate(
      key: 'list_untracked_follow_up',
      name: 'Untracked alumni for follow-up',
      summary: 'Who has not answered, with contact details.',
      config: GtsListConfig(
        templateKey: 'list_untracked_follow_up',
        title: 'Untracked alumni for follow-up',
        description:
            'Alumni who have not answered the tracer, with roster contact '
            'details. "Not registered" alumni need a portal account first.',
        columns: [
          _name,
          _batch,
          _course,
          GtsListColumns.registrationColumn,
          GtsListColumns.emailColumn,
          GtsListColumns.contactColumn,
          _status,
        ],
        statuses: [
          GtsTracerStatus.untrackedRegistered,
          GtsTracerStatus.untrackedNotRegistered,
        ],
        chart: GtsListChart.none,
      ),
    ),
    GtsListTemplate(
      key: 'list_employed_job_details',
      name: 'Employed alumni job details',
      summary: 'Occupation, line of business, place of work, job status.',
      config: GtsListConfig(
        templateKey: 'list_employed_job_details',
        title: 'Employed alumni job details',
        description:
            'Alumni who are presently employed (item 16 = Yes) with their '
            'employment status, occupation, line of business and place of '
            'work (items 18 to 21).',
        columns: [
          _batch,
          _name,
          _course,
          'ched_18',
          'ched_19',
          'ched_20',
          'ched_21',
        ],
        statuses: [GtsTracerStatus.employed],
        chart: GtsListChart.none,
      ),
    ),
    GtsListTemplate(
      key: 'list_not_employed_reasons',
      name: 'Not employed, with reasons',
      summary: 'Not employed or never employed, with item 17 reasons.',
      config: GtsListConfig(
        templateKey: 'list_not_employed_reasons',
        title: 'Not employed, with reasons',
        description:
            'Alumni who answered No or Never Employed to item 16, with their '
            'reasons (item 17).',
        columns: [_batch, _name, _course, 'ched_16', 'ched_17'],
        statuses: [GtsTracerStatus.notEmployed, GtsTracerStatus.neverEmployed],
        chart: GtsListChart.none,
      ),
    ),
  ];

  static GtsListTemplate? byKey(String? key) {
    for (final t in all) {
      if (t.key == key) return t;
    }
    return null;
  }
}
