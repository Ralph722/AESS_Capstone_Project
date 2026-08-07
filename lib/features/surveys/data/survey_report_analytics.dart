import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

/// Per-question and participation aggregates from submitted responses.
class SurveyReportAnalytics {
  SurveyReportAnalytics._();

  static List<SurveyQuestionAggregate> aggregateResponses({
    required List<SurveyQuestion> questions,
    required List<SurveyResponse> responses,
  }) {
    final total = responses.length;
    if (total == 0 || questions.isEmpty) return [];

    final sortedQs = [...questions]..sort((a, b) => a.order.compareTo(b.order));
    final out = <SurveyQuestionAggregate>[];

    for (final q in sortedQs) {
      switch (q.type) {
        case SurveyQuestionType.singleChoice:
          out.add(_aggregateChoice(
            q: q,
            totalResponses: total,
            responses: responses,
            multi: false,
          ));
        case SurveyQuestionType.multipleChoice:
          out.add(_aggregateChoice(
            q: q,
            totalResponses: total,
            responses: responses,
            multi: true,
          ));
        case SurveyQuestionType.scale:
          out.add(_aggregateScale(q, total, responses));
        case SurveyQuestionType.text:
        case SurveyQuestionType.longText:
        case SurveyQuestionType.date:
          out.add(_aggregateTextLike(q, total, responses));
      }
    }
    return out;
  }

  /// Official CHED builtin: aggregate choice items from answers map (no DB rows).
  static List<SurveyQuestionAggregate> aggregateChedResponses({
    required List<SurveyResponse> responses,
  }) {
    if (responses.isEmpty) return [];
    final questions = <SurveyQuestion>[];
    var order = 0;
    for (final item in ChedGtsBuiltin.items) {
      if (item.type != ChedGtsFieldType.single &&
          item.type != ChedGtsFieldType.multi) {
        continue;
      }
      questions.add(
        SurveyQuestion(
          id: item.id,
          surveyId: '',
          order: order++,
          type: item.type == ChedGtsFieldType.multi
              ? SurveyQuestionType.multipleChoice
              : SurveyQuestionType.singleChoice,
          prompt: '${item.chedNumber}. ${item.prompt}',
          options: List<String>.from(item.options),
          required: item.required,
        ),
      );
    }
    return aggregateResponses(questions: questions, responses: responses);
  }

  static SurveyParticipationSnapshot participationFromParticipants(
    List<SurveyParticipant> participants,
  ) {
    var notStarted = 0;
    var inProgress = 0;
    var completed = 0;
    for (final p in participants) {
      switch (p.assignment.status) {
        case SurveyAssignmentStatus.notStarted:
          notStarted++;
        case SurveyAssignmentStatus.inProgress:
          inProgress++;
        case SurveyAssignmentStatus.completed:
          completed++;
      }
    }
    return SurveyParticipationSnapshot(
      assigned: participants.length,
      notStarted: notStarted,
      inProgress: inProgress,
      completed: completed,
    );
  }

  static List<SurveyAudienceBucket> audienceByProgram(
    List<SurveyParticipant> participants, {
    int maxBuckets = 8,
  }) {
    return _audienceBuckets(
      participants,
      labelOf: (p) {
        final v = p.program.trim();
        return v.isEmpty ? 'Unspecified' : v;
      },
      maxBuckets: maxBuckets,
    );
  }

  static List<SurveyAudienceBucket> audienceByBatch(
    List<SurveyParticipant> participants, {
    int maxBuckets = 10,
  }) {
    return _audienceBuckets(
      participants,
      labelOf: (p) {
        final v = p.batchYear.trim();
        return v.isEmpty ? 'Unspecified' : v;
      },
      maxBuckets: maxBuckets,
    );
  }

  static List<SurveyAudienceBucket> _audienceBuckets(
    List<SurveyParticipant> participants, {
    required String Function(SurveyParticipant) labelOf,
    required int maxBuckets,
  }) {
    final assigned = <String, int>{};
    final completed = <String, int>{};
    for (final p in participants) {
      final label = labelOf(p);
      assigned[label] = (assigned[label] ?? 0) + 1;
      if (!p.isPending) {
        completed[label] = (completed[label] ?? 0) + 1;
      }
    }
    final buckets = assigned.entries
        .map(
          (e) => SurveyAudienceBucket(
            label: e.key,
            assigned: e.value,
            completed: completed[e.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.assigned.compareTo(a.assigned));
    if (buckets.length <= maxBuckets) return buckets;
    final head = buckets.take(maxBuckets - 1).toList();
    final rest = buckets.skip(maxBuckets - 1);
    var otherAssigned = 0;
    var otherCompleted = 0;
    for (final b in rest) {
      otherAssigned += b.assigned;
      otherCompleted += b.completed;
    }
    return [
      ...head,
      SurveyAudienceBucket(
        label: 'Other',
        assigned: otherAssigned,
        completed: otherCompleted,
      ),
    ];
  }

  /// Daily submission counts from [submittedAt] (last [days] calendar days).
  static List<SurveySubmissionTrendPoint> submissionTrend({
    required List<SurveyResponse> responses,
    int days = 30,
  }) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final counts = <DateTime, int>{};
    for (var i = 0; i < days; i++) {
      counts[start.add(Duration(days: i))] = 0;
    }
    for (final r in responses) {
      if (r.status != SurveyResponseStatus.submitted) continue;
      final at = r.submittedAt ?? r.updatedAt;
      final day = DateTime(at.year, at.month, at.day);
      if (day.isBefore(start)) continue;
      if (!counts.containsKey(day)) continue;
      counts[day] = counts[day]! + 1;
    }
    final keys = counts.keys.toList()..sort();
    return [
      for (final d in keys)
        SurveySubmissionTrendPoint(day: d, count: counts[d] ?? 0),
    ];
  }

  static SurveyReminderStats reminderStats(
    List<SurveyParticipant> participants,
  ) {
    var withReminders = 0;
    var totalSent = 0;
    var completedAfter = 0;
    for (final p in participants) {
      final n = p.assignment.reminderCount;
      if (n <= 0) continue;
      withReminders++;
      totalSent += n;
      if (!p.isPending) completedAfter++;
    }
    return SurveyReminderStats(
      assignmentsWithReminders: withReminders,
      totalRemindersSent: totalSent,
      completedAfterReminder: completedAfter,
    );
  }

  /// Most-skipped questions among submitted responses (highest skip rate).
  static List<SurveyQuestionAggregate> mostSkipped(
    List<SurveyQuestionAggregate> aggregates, {
    int limit = 5,
  }) {
    final withSkips = aggregates.where((a) => a.skippedCount > 0).toList()
      ..sort((a, b) {
        final ra = a.totalResponses == 0
            ? 0.0
            : a.skippedCount / a.totalResponses;
        final rb = b.totalResponses == 0
            ? 0.0
            : b.skippedCount / b.totalResponses;
        return rb.compareTo(ra);
      });
    return withSkips.take(limit).toList();
  }

  static SurveyQuestionAggregate _aggregateChoice({
    required SurveyQuestion q,
    required int totalResponses,
    required List<SurveyResponse> responses,
    required bool multi,
  }) {
    final counts = <String, int>{};
    for (final opt in q.options) {
      counts[opt] = 0;
    }
    var answered = 0;
    for (final r in responses) {
      final raw = r.answers[q.id];
      if (raw == null) continue;
      if (multi) {
        final list = (raw is List)
            ? raw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];
        if (list.isEmpty) continue;
        answered++;
        for (final v in list) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
      } else {
        final v = raw.toString().trim();
        if (v.isEmpty) continue;
        answered++;
        counts[v] = (counts[v] ?? 0) + 1;
      }
    }
    final denom = answered == 0 ? 1 : answered;
    final pct = <String, double>{};
    for (final e in counts.entries) {
      pct[e.key] = (e.value / denom) * 100;
    }
    return SurveyQuestionAggregate(
      questionId: q.id,
      prompt: q.prompt,
      type: q.type,
      answeredCount: answered,
      totalResponses: totalResponses,
      choicePercentages: pct,
      skippedCount: totalResponses - answered,
    );
  }

  static SurveyQuestionAggregate _aggregateScale(
    SurveyQuestion q,
    int totalResponses,
    List<SurveyResponse> responses,
  ) {
    final min = q.scaleMin ?? 1;
    final max = q.scaleMax ?? 5;
    final values = <int>[];
    for (final r in responses) {
      final raw = r.answers[q.id];
      if (raw == null) continue;
      int? v;
      if (raw is int) {
        v = raw;
      } else if (raw is double) {
        v = raw.round();
      } else {
        v = int.tryParse(raw.toString());
      }
      if (v == null) continue;
      if (v < min || v > max) continue;
      values.add(v);
    }
    if (values.isEmpty) {
      return SurveyQuestionAggregate(
        questionId: q.id,
        prompt: q.prompt,
        type: q.type,
        answeredCount: 0,
        totalResponses: totalResponses,
        skippedCount: totalResponses,
      );
    }
    final sum = values.fold<int>(0, (a, b) => a + b);
    return SurveyQuestionAggregate(
      questionId: q.id,
      prompt: q.prompt,
      type: q.type,
      answeredCount: values.length,
      totalResponses: totalResponses,
      scaleAverage: sum / values.length,
      scaleMinObserved: values.reduce((a, b) => a < b ? a : b),
      scaleMaxObserved: values.reduce((a, b) => a > b ? a : b),
      skippedCount: totalResponses - values.length,
    );
  }

  static SurveyQuestionAggregate _aggregateTextLike(
    SurveyQuestion q,
    int totalResponses,
    List<SurveyResponse> responses,
  ) {
    var n = 0;
    for (final r in responses) {
      final raw = r.answers[q.id];
      if (raw == null) continue;
      if (raw.toString().trim().isEmpty) continue;
      n++;
    }
    return SurveyQuestionAggregate(
      questionId: q.id,
      prompt: q.prompt,
      type: q.type,
      answeredCount: n,
      totalResponses: totalResponses,
      textAnswerCount: n,
      skippedCount: totalResponses - n,
    );
  }
}
