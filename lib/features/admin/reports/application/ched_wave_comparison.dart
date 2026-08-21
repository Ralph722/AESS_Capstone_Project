import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/data/survey_report_analytics.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';
import 'package:intl/intl.dart';

/// Curated CHED fields for cross-sectional wave comparison downloads.
class ChedWaveComparisonFieldSpec {
  const ChedWaveComparisonFieldSpec({
    required this.questionId,
    required this.shortLabel,
    this.highlightOption,
  });

  final String questionId;
  final String shortLabel;

  /// Option whose share is surfaced on the summary sheet (e.g. Yes).
  final String? highlightOption;
}

/// One published wave column in the comparison.
class ChedWaveComparisonColumn {
  const ChedWaveComparisonColumn({
    required this.survey,
    required this.label,
    required this.shortLabel,
    required this.submittedCount,
    required this.aggregatesByQuestionId,
  });

  final Survey survey;
  final String label;
  final String shortLabel;
  final int submittedCount;

  /// questionId → aggregate for that wave (after cohort filter).
  final Map<String, SurveyQuestionAggregate> aggregatesByQuestionId;

  double? highlightRate(String questionId, String option) {
    final agg = aggregatesByQuestionId[questionId];
    if (agg == null || agg.answeredCount == 0) return null;
    return agg.choicePercentages[option];
  }
}

/// Cross-sectional comparison across selected Official CHED GTS waves.
class ChedWaveComparisonReport {
  const ChedWaveComparisonReport({
    required this.waves,
    required this.fields,
    this.batchFilter,
    this.courseFilter,
  });

  final List<ChedWaveComparisonColumn> waves;
  final List<ChedWaveComparisonFieldSpec> fields;
  final String? batchFilter;
  final String? courseFilter;

  static const maxWaves = 8;

  static const crucialFields = <ChedWaveComparisonFieldSpec>[
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_16',
      shortLabel: 'Presently employed',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_18',
      shortLabel: 'Employment status',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_21',
      shortLabel: 'Place of work',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_24a',
      shortLabel: 'Job related to course',
      highlightOption: ChedGtsBuiltin.yes,
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_31',
      shortLabel: 'Initial monthly earning',
    ),
    ChedWaveComparisonFieldSpec(
      questionId: 'ched_32',
      shortLabel: 'Curriculum relevant',
      highlightOption: ChedGtsBuiltin.yes,
    ),
  ];

  /// Build from selected waves + submitted responses (already cohort-filtered).
  ///
  /// [responsesBySurveyId] must contain submitted responses only.
  /// Waves are sorted chronologically (oldest → newest) for delta = latest − earliest.
  static ChedWaveComparisonReport build({
    required List<Survey> selectedSurveys,
    required Map<String, List<SurveyResponse>> responsesBySurveyId,
    String? batchFilter,
    String? courseFilter,
    List<ChedWaveComparisonFieldSpec> fields = crucialFields,
  }) {
    final sorted = List<Survey>.from(selectedSurveys)
      ..sort((a, b) {
        final aAt = a.publishedAt ?? a.openAt ?? a.createdAt;
        final bAt = b.publishedAt ?? b.openAt ?? b.createdAt;
        return aAt.compareTo(bAt);
      });

    final take = sorted.take(maxWaves).toList();
    final dateFmt = DateFormat.yMMMd();
    final columns = <ChedWaveComparisonColumn>[];

    for (var i = 0; i < take.length; i++) {
      final survey = take[i];
      final responses = responsesBySurveyId[survey.id] ?? const [];
      final aggregates = SurveyReportAnalytics.aggregateChedResponses(
        responses: responses,
      );
      final byId = <String, SurveyQuestionAggregate>{
        for (final a in aggregates) a.questionId: a,
      };
      final when = survey.publishedAt ?? survey.openAt ?? survey.createdAt;
      final short = 'W${i + 1}';
      final title = survey.title.trim();
      final label = title.isEmpty
          ? '$short · ${dateFmt.format(when)}'
          : '$title (${dateFmt.format(when)})';

      columns.add(
        ChedWaveComparisonColumn(
          survey: survey,
          label: label,
          shortLabel: short,
          submittedCount: responses.length,
          aggregatesByQuestionId: byId,
        ),
      );
    }

    return ChedWaveComparisonReport(
      waves: columns,
      fields: fields,
      batchFilter: batchFilter,
      courseFilter: courseFilter,
    );
  }

  List<String> get filterSummary {
    final parts = <String>[
      'Cross-sectional compare',
      '${waves.length} waves',
    ];
    if (batchFilter != null && batchFilter!.trim().isNotEmpty) {
      parts.add('Batch ${batchFilter!.trim()}');
    }
    if (courseFilter != null && courseFilter!.trim().isNotEmpty) {
      parts.add(courseFilter!.trim());
    }
    return parts;
  }

  List<String> optionsFor(String questionId) {
    final item = ChedGtsBuiltin.byId(questionId);
    if (item != null && item.options.isNotEmpty) {
      return List<String>.from(item.options);
    }
    final set = <String>{};
    for (final w in waves) {
      final agg = w.aggregatesByQuestionId[questionId];
      if (agg == null) continue;
      set.addAll(agg.choicePercentages.keys);
    }
    final list = set.toList()..sort();
    return list;
  }
}
