import 'package:flutter/material.dart';
import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/data/survey_report_analytics.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

/// Crucial CHED choice/multi fields for graduate-status overview charts.
/// Skips early demographics and free-text / matrix-only items.
const _chedCrucialDistributionIds = <String>{
  'ched_11', // location of residence
  'ched_14', // reasons for taking the course
  'ched_15b', // pursue advance studies
  'ched_16', // presently employed
  'ched_17', // reasons not employed
  'ched_18', // employment status
  'ched_20', // line of business
  'ched_21', // place of work
  'ched_22', // is this your first job
  'ched_23', // reasons for accepting the job
  'ched_24a', // job related to course
  'ched_24b', // reasons if not related
  'ched_25', // (legacy) how found first job if present
  'ched_27', // length of stay in first job
  'ched_28', // how found first job
  'ched_29', // time to land first job
  'ched_31', // initial gross monthly earning
  'ched_32', // was college curriculum relevant
  'ched_33', // competencies useful in first job
};

/// Per-survey analytics for the responses Overview right pane.
///
/// Fixed filters on top; funnel → most-skipped scroll below.
class AdminSurveyAnalyticsPanel extends StatefulWidget {
  const AdminSurveyAnalyticsPanel({
    super.key,
    required this.survey,
    required this.participants,
    required this.questions,
    required this.responses,
  });

  final Survey survey;
  final List<SurveyParticipant> participants;
  final List<SurveyQuestion> questions;
  final List<SurveyResponse> responses;

  @override
  State<AdminSurveyAnalyticsPanel> createState() =>
      _AdminSurveyAnalyticsPanelState();
}

class _AdminSurveyAnalyticsPanelState extends State<AdminSurveyAnalyticsPanel> {
  String? _batchFilter;
  String? _courseFilter;

  /// Cache heavy aggregates across rebuilds when inputs are unchanged.
  Object? _cacheKey;
  List<SurveyQuestionAggregate> _cachedAggregates = const [];
  List<SurveyParticipant> _cachedFilteredParticipants = const [];
  List<SurveyResponse> _cachedSubmitted = const [];

  Survey get survey => widget.survey;

  List<String> get _batchOptions {
    final set = <String>{};
    for (final p in widget.participants) {
      final b = p.batchYear.trim();
      if (b.isNotEmpty) set.add(b);
    }
    final list = set.toList()
      ..sort((a, b) {
        final an = int.tryParse(a);
        final bn = int.tryParse(b);
        if (an != null && bn != null) return bn.compareTo(an);
        return b.compareTo(a);
      });
    return list;
  }

  List<String> get _courseOptions {
    final set = <String>{};
    for (final p in widget.participants) {
      final c = p.program.trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  bool _matchParticipant(SurveyParticipant p) {
    if (_batchFilter != null &&
        p.batchYear.trim().toLowerCase() != _batchFilter!.toLowerCase()) {
      return false;
    }
    if (_courseFilter != null &&
        p.program.trim().toLowerCase() != _courseFilter!.toLowerCase()) {
      return false;
    }
    return true;
  }

  void _ensureAggregates() {
    final key = (
      widget.survey.id,
      widget.participants.length,
      widget.responses.length,
      _batchFilter,
      _courseFilter,
    );
    if (_cacheKey == key) return;
    _cacheKey = key;

    final filteredParticipants =
        widget.participants.where(_matchParticipant).toList(growable: false);
    final userIds = {
      for (final p in filteredParticipants) p.assignment.userId,
    };
    final submitted = widget.responses
        .where(
          (r) =>
              userIds.contains(r.userId) &&
              r.status == SurveyResponseStatus.submitted,
        )
        .toList(growable: false);

    _cachedFilteredParticipants = filteredParticipants;
    _cachedSubmitted = submitted;
    _cachedAggregates = survey.isChedGtsBuiltin
        ? SurveyReportAnalytics.aggregateChedResponses(responses: submitted)
        : SurveyReportAnalytics.aggregateResponses(
            questions: widget.questions,
            responses: submitted,
          );
  }

  List<SurveyQuestionAggregate> _choiceAggregates(
    List<SurveyQuestionAggregate> aggregates,
  ) {
    final withChoices = aggregates
        .where(
          (a) => a.choicePercentages.isNotEmpty && a.answeredCount > 0,
        )
        .toList();
    if (!survey.isChedGtsBuiltin) {
      return withChoices.take(6).toList();
    }
    final byId = {for (final a in withChoices) a.questionId: a};
    final ordered = <SurveyQuestionAggregate>[
      for (final id in _chedCrucialDistributionIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
    // Cap widgets on screen — too many progress charts freeze Flutter web.
    if (ordered.isEmpty) {
      return withChoices.take(8).toList();
    }
    return ordered.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    _ensureAggregates();
    final filteredParticipants = _cachedFilteredParticipants;
    final submitted = _cachedSubmitted;
    final aggregates = _cachedAggregates;
    final userIds = {
      for (final p in filteredParticipants) p.assignment.userId,
    };
    final filteredResponses = widget.responses
        .where((r) => userIds.contains(r.userId))
        .toList(growable: false);

    final participation = SurveyReportAnalytics.participationFromParticipants(
      filteredParticipants,
    );
    final byProgram =
        SurveyReportAnalytics.audienceByProgram(filteredParticipants);
    final byBatch = SurveyReportAnalytics.audienceByBatch(filteredParticipants);
    final trend =
        SurveyReportAnalytics.submissionTrend(responses: filteredResponses);
    final reminders =
        SurveyReportAnalytics.reminderStats(filteredParticipants);
    final skipped = SurveyReportAnalytics.mostSkipped(aggregates).take(6).toList();
    final choiceAggs = _choiceAggregates(aggregates);
    final scaleAggs = aggregates
        .where((a) => a.scaleAverage != null)
        .take(4)
        .toList();

    final programs = survey.targetPrograms
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final batches = AudienceTargeting.expandBatchYearTargets(
      survey.targetBatchYears,
    );
    final audienceNote = (programs.isEmpty && batches.isEmpty)
        ? 'Audience: all eligible alumni'
        : 'Audience: ${[
            if (programs.isNotEmpty) programs.join(', '),
            if (batches.isNotEmpty)
              AudienceTargeting.formatBatchYearsForDisplay(batches),
          ].join(' · ')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurveySectionCard(
          title: 'Filters',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                audienceNote,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AdminSurveyTheme.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Batch',
                        isDense: true,
                        filled: true,
                        fillColor: AdminSurveyTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AdminSurveyTheme.radiusMd,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _batchFilter,
                          isExpanded: true,
                          isDense: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All batches'),
                            ),
                            for (final b in _batchOptions)
                              DropdownMenuItem(value: b, child: Text(b)),
                          ],
                          onChanged: (v) => setState(() => _batchFilter = v),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Course',
                        isDense: true,
                        filled: true,
                        fillColor: AdminSurveyTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AdminSurveyTheme.radiusMd,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _courseFilter,
                          isExpanded: true,
                          isDense: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All courses'),
                            ),
                            for (final c in _courseOptions)
                              DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _courseFilter = v),
                        ),
                      ),
                    ),
                  ),
                  if (_batchFilter != null || _courseFilter != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _batchFilter = null;
                        _courseFilter = null;
                      }),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_batchFilter ?? 'All batches'} · '
                '${_courseFilter ?? 'All courses'} · '
                '${submitted.length} submitted',
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminSurveyTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: filteredParticipants.isEmpty
              ? const Center(
                  child: Text(
                    'No participants match this batch/course filter.',
                    style: TextStyle(color: AdminSurveyTheme.textMuted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _FunnelCard(snapshot: participation),
                    const SizedBox(height: 10),
                    _ReminderCard(stats: reminders),
                    const SizedBox(height: 10),
                    _TrendCard(points: trend),
                    const SizedBox(height: 10),
                    if (byProgram.isNotEmpty) ...[
                      _AudienceCard(
                        title: 'By course / program',
                        buckets: byProgram,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (byBatch.isNotEmpty) ...[
                      _AudienceCard(
                        title: 'By batch year',
                        buckets: byBatch,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (choiceAggs.isNotEmpty) ...[
                      const _SectionTitle('Response distribution'),
                      const SizedBox(height: 8),
                      for (final a in choiceAggs) ...[
                        _ChoiceAggregateCard(aggregate: a),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (scaleAggs.isNotEmpty) ...[
                      const _SectionTitle('Rating / scale'),
                      const SizedBox(height: 8),
                      for (final a in scaleAggs) ...[
                        _ScaleAggregateCard(aggregate: a),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (skipped.isNotEmpty) ...[
                      const _SectionTitle('Most skipped'),
                      const SizedBox(height: 8),
                      for (final a in skipped) ...[
                        _SkippedRow(aggregate: a),
                        const SizedBox(height: 6),
                      ],
                    ],
                    if (submitted.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'No submitted responses for this filter yet.',
                          style: TextStyle(
                            color: AdminSurveyTheme.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AdminSurveyTheme.textPrimary,
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.snapshot});
  final SurveyParticipationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.assigned == 0 ? 1 : snapshot.assigned;
    return _AnalyticsCard(
      title: 'Participation funnel',
      child: Column(
        children: [
          _FunnelBar(
            label: 'Not started',
            value: snapshot.notStarted,
            total: total,
            color: AdminSurveyTheme.warning,
          ),
          const SizedBox(height: 8),
          _FunnelBar(
            label: 'In progress',
            value: snapshot.inProgress,
            total: total,
            color: AdminSurveyTheme.primary,
          ),
          const SizedBox(height: 8),
          _FunnelBar(
            label: 'Completed',
            value: snapshot.completed,
            total: total,
            color: AdminSurveyTheme.success,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Completion ${snapshot.completionRate.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AdminSurveyTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AdminSurveyTheme.surface,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.stats});
  final SurveyReminderStats stats;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Reminder effectiveness',
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _MiniStat(
            label: 'Alumni reminded',
            value: '${stats.assignmentsWithReminders}',
          ),
          _MiniStat(
            label: 'Reminders sent',
            value: '${stats.totalRemindersSent}',
          ),
          _MiniStat(
            label: 'Completed after reminder',
            value: '${stats.completedAfterReminder}',
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AdminSurveyTheme.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AdminSurveyTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});
  final List<SurveySubmissionTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final max = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final total = points.fold<int>(0, (s, p) => s + p.count);
    return _AnalyticsCard(
      title: 'Daily submissions (30 days)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            total == 0
                ? 'No submissions in the last 30 days'
                : '$total submissions in the last 30 days',
            style: const TextStyle(
              fontSize: 12.5,
              color: AdminSurveyTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        height: max == 0
                            ? 4
                            : (4 + (p.count / max) * 68).clamp(4, 72),
                        decoration: BoxDecoration(
                          color: p.count == 0
                              ? AdminSurveyTheme.border
                              : AdminSurveyTheme.primary.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({required this.title, required this.buckets});
  final String title;
  final List<SurveyAudienceBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final top = buckets.take(8).toList();
    final max = top.fold<int>(0, (m, b) => b.assigned > m ? b.assigned : m);
    return _AnalyticsCard(
      title: title,
      child: Column(
        children: [
          for (final b in top) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    b.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : b.assigned / max,
                      minHeight: 7,
                      backgroundColor: AdminSurveyTheme.surface,
                      color: AdminSurveyTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${b.assigned}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _ChoiceAggregateCard extends StatelessWidget {
  const _ChoiceAggregateCard({required this.aggregate});
  final SurveyQuestionAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final entries = aggregate.choicePercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _AnalyticsCard(
      title: aggregate.prompt,
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${aggregate.answeredCount} answered',
            style: const TextStyle(
              fontSize: 11.5,
              color: AdminSurveyTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (final e in entries.take(5)) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.key,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${e.value.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (e.value / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AdminSurveyTheme.surface,
                color: AdminSurveyTheme.primary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ScaleAggregateCard extends StatelessWidget {
  const _ScaleAggregateCard({required this.aggregate});
  final SurveyQuestionAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: aggregate.prompt,
      dense: true,
      child: Text(
        'Average ${aggregate.scaleAverage!.toStringAsFixed(1)} '
        '(min ${aggregate.scaleMinObserved}, max ${aggregate.scaleMaxObserved})',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _SkippedRow extends StatelessWidget {
  const _SkippedRow({required this.aggregate});
  final SurveyQuestionAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final skipped = aggregate.skippedCount;
    final pct = aggregate.totalResponses == 0
        ? 0.0
        : skipped / aggregate.totalResponses * 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminSurveyTheme.surface,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusMd),
        border: Border.all(color: AdminSurveyTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              aggregate.prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$skipped skipped (${pct.toStringAsFixed(0)}%)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminSurveyTheme.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.child,
    this.dense = false,
  });

  final String title;
  final Widget child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 12 : 14),
      decoration: AdminSurveyTheme.surfaceCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: dense ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: AdminSurveyTheme.textPrimary,
            ),
          ),
          SizedBox(height: dense ? 8 : 12),
          child,
        ],
      ),
    );
  }
}
