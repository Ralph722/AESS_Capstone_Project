import 'dart:math' as math;

import 'package:alumni_system/features/admin/dss/application/dss_evaluator.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_rollup.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// One row of `dss_cohort_metrics(p_survey_id)`: one metric of one group in
/// one CHED GTS wave.
class DssCohortMetric {
  const DssCohortMetric({
    required this.level,
    required this.course,
    required this.batchYear,
    required this.metricKey,
    required this.hits,
    required this.total,
    required this.value,
    required this.respondents,
    required this.nonResponse,
    required this.eligible,
    required this.registered,
    required this.rosterBasis,
    required this.evidenceStrength,
    required this.coverageWarning,
    required this.ciLow,
    required this.ciHigh,
    this.metricVersion = DssCohortMetrics.metricVersion,
  });

  factory DssCohortMetric.fromRow(Map<String, dynamic> row) {
    int? asInt(Object? v) => (v as num?)?.toInt();
    double? asDouble(Object? v) => (v as num?)?.toDouble();
    return DssCohortMetric(
      level: DssCohortLevelX.fromDb(row['level']?.toString()),
      course: (row['course'] ?? '').toString(),
      batchYear: (row['batch_year'] ?? '').toString(),
      metricKey: (row['metric_key'] ?? '').toString(),
      hits: asInt(row['hits']),
      total: asInt(row['total']) ?? 0,
      value: asDouble(row['value']),
      respondents: asInt(row['respondents']) ?? 0,
      nonResponse: asInt(row['non_response']),
      eligible: asInt(row['eligible']) ?? 0,
      registered: asInt(row['registered']) ?? 0,
      rosterBasis: (row['roster_basis'] ?? '').toString(),
      evidenceStrength: DssEvidenceStrengthX.fromDb(
        row['evidence_strength']?.toString(),
      ),
      coverageWarning: row['coverage_warning'] == true,
      ciLow: asDouble(row['ci_low']),
      ciHigh: asDouble(row['ci_high']),
      metricVersion: asInt(row['metric_version']) ?? 0,
    );
  }

  final DssCohortLevel level;

  /// [DssRollup.all] for the institution.
  final String course;

  /// [DssRollup.all] for course and institution rows.
  final String batchYear;
  final String metricKey;

  /// Null for the salary gap (a difference of medians, not a count).
  final int? hits;

  /// Denominator: valid answers to the metric, or the roster count for the
  /// response rate.
  final int total;

  /// Null when [total] is 0 (or, for the salary gap, without peers).
  final double? value;

  /// Submitted responses in the group.
  final int respondents;

  /// Respondents without a valid answer to the metric; null for the
  /// response rate.
  final int? nonResponse;
  final int eligible;
  final int registered;

  /// `open_wave`, `snapshot` or `current`.
  final String rosterBasis;

  /// Null for the response rate.
  final DssEvidenceStrength? evidenceStrength;
  final bool coverageWarning;
  final double? ciLow;
  final double? ciHigh;
  final int metricVersion;

  String get key => '${level.dbValue}|$course|$batchYear|$metricKey';

  Map<String, dynamic> toRow() => {
    'level': level.dbValue,
    'course': course,
    'batch_year': batchYear,
    'metric_key': metricKey,
    'hits': hits,
    'total': total,
    'value': value,
    'respondents': respondents,
    'non_response': nonResponse,
    'eligible': eligible,
    'registered': registered,
    'roster_basis': rosterBasis,
    'evidence_strength': evidenceStrength?.dbValue,
    'coverage_warning': coverageWarning,
    'ci_low': ciLow,
    'ci_high': ciHigh,
    'metric_version': metricVersion,
  };
}

/// Dart reference for `dss_cohort_metrics`. The SQL function and this code
/// must produce the same rows; parity tests compare them.
abstract final class DssCohortMetrics {
  static const metricVersion = 2;

  static const metricKeys = [
    'response_rate',
    'unemployment_rate',
    'seeking_work_rate',
    'unrelated_or_irrelevant_rate',
    'related_and_relevant_rate',
    'clerical_among_employed_rate',
    'long_time_to_first_job_rate',
    'salary_peer_gap',
  ];

  /// Every group and metric of [survey]. [roster] is the active roster,
  /// [snapshots] the saved roster counts of this wave.
  static List<DssCohortMetric> compute({
    required Survey survey,
    required List<SurveyResponse> responses,
    required List<AlumniMember> roster,
    required List<DssRule> rules,
    required DateTime now,
    List<DssCohortSnapshot> snapshots = const [],
  }) {
    final saved = [
      for (final s in snapshots)
        if (s.surveyId == survey.id) s,
    ];
    final String basis;
    final DssRoster counts;
    if (DssEvaluator.acceptsResponses(survey, now)) {
      basis = 'open_wave';
      counts = DssRoster.fromMembers(roster);
    } else if (saved.isNotEmpty) {
      basis = 'snapshot';
      counts = DssRoster.fromSnapshots(saved);
    } else {
      basis = 'current';
      counts = DssRoster.fromMembers(roster);
    }

    final byAuth = <String, AlumniMember>{
      for (final m in roster)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };
    final classified =
        <({String course, String batch, Map<String, dynamic> answers})>[];
    for (final r in responses) {
      if (r.status != SurveyResponseStatus.submitted) continue;
      final group = DssPolicy.groupOf(byAuth[r.userId]);
      if (group == null) continue;
      classified.add((
        course: group.course,
        batch: DssPolicy.batchLabel(group.batch),
        answers: r.answers,
      ));
    }

    final ranksByCourse = <String, List<int>>{};
    for (final c in classified) {
      final rank = DssMetrics.salaryRank(
        DssMetrics.single(c.answers['ched_31']),
      );
      if (rank >= 0) ranksByCourse.putIfAbsent(c.course, () => []).add(rank);
    }

    int ruleGate(String metricKey) {
      int? minN;
      for (final r in rules.where((r) => r.metricKey == metricKey)) {
        minN = minN == null ? r.minN : math.max(minN, r.minN);
      }
      return DssPolicy.findingGate(minN);
    }

    final out = <DssCohortMetric>[];
    void addGroup(
      DssCohortLevel level,
      String course,
      String batch,
      int eligible,
      int registered,
    ) {
      final answers = [
        for (final c in classified)
          if (level == DssCohortLevel.institution ||
              (c.course == course &&
                  (level == DssCohortLevel.course || c.batch == batch)))
            c.answers,
      ];
      final n = answers.length;
      final coverage =
          eligible > 0 && n / eligible < DssPolicy.lowCoverageBelow;

      DssCohortMetric row(
        String key, {
        required int? hits,
        required int total,
        required double? value,
        bool share = false,
        bool rate = false,
      }) {
        final interval = share && total > 0
            ? DssMetrics.wilson(hits!, total)
            : null;
        return DssCohortMetric(
          level: level,
          course: course,
          batchYear: batch,
          metricKey: key,
          hits: hits,
          total: total,
          value: value,
          respondents: n,
          nonResponse: rate ? null : n - total,
          eligible: eligible,
          registered: registered,
          rosterBasis: basis,
          evidenceStrength: rate
              ? null
              : DssPolicy.strength(total, minN: ruleGate(key)),
          coverageWarning: coverage,
          ciLow: interval?.low,
          ciHigh: interval?.high,
        );
      }

      DssCohortMetric shareRow(String key, DssProportion? p) => row(
        key,
        hits: p?.hits ?? 0,
        total: p?.total ?? 0,
        value: p == null || p.total == 0 ? null : p.hits / p.total,
        share: true,
      );

      out.add(
        row(
          'response_rate',
          hits: n,
          total: eligible,
          value: eligible > 0 ? n / eligible : null,
          rate: true,
        ),
      );
      if (n == 0) return;

      out.add(shareRow('unemployment_rate', DssMetrics.unemployment(answers)));
      out.add(shareRow('seeking_work_rate', DssMetrics.seekingWork(answers)));
      final related = DssMetrics.relatedness(answers);
      out.add(shareRow('unrelated_or_irrelevant_rate', related?.mismatchShare));
      out.add(shareRow('related_and_relevant_rate', related?.alignedShare));
      out.add(
        shareRow('clerical_among_employed_rate', DssMetrics.clerical(answers)),
      );
      out.add(
        shareRow(
          'long_time_to_first_job_rate',
          DssMetrics.longTimeToFirstJob(answers),
        ),
      );
      if (level != DssCohortLevel.institution) {
        final ranks = DssMetrics.salaryRanks(answers);
        out.add(
          row(
            'salary_peer_gap',
            hits: null,
            total: ranks.length,
            value: DssMetrics.salaryGap(
              ranks,
              DssMetrics.peerMedianExcluding(ranksByCourse, course),
            ),
          ),
        );
      }
    }

    addGroup(
      DssCohortLevel.institution,
      DssRollup.all,
      DssRollup.all,
      counts.total,
      counts.registered,
    );
    final courses = <String>{
      for (final c in classified) c.course,
      for (final g in counts.groups)
        if (g.counts.total > 0) g.course,
    }.toList()..sort();
    for (final course in courses) {
      final c = counts.course(course);
      addGroup(
        DssCohortLevel.course,
        course,
        DssRollup.all,
        c.total,
        c.registered,
      );
    }
    final batches =
        <({String course, String batch})>{
          for (final c in classified)
            if (c.batch != DssPolicy.batchNotRecorded)
              (course: c.course, batch: c.batch),
          for (final g in counts.groups)
            if (g.batch != DssPolicy.batchNotRecorded && g.counts.total > 0)
              (course: g.course, batch: g.batch),
        }.toList()..sort((a, b) {
          final byCourse = a.course.compareTo(b.course);
          return byCourse != 0 ? byCourse : a.batch.compareTo(b.batch);
        });
    for (final (:course, :batch) in batches) {
      final c = counts.batch(course, batch);
      final n = classified
          .where((r) => r.course == course && r.batch == batch)
          .length;
      addGroup(
        DssCohortLevel.batch,
        course,
        batch,
        c?.total ?? n,
        c?.registered ?? 0,
      );
    }
    return out;
  }
}
