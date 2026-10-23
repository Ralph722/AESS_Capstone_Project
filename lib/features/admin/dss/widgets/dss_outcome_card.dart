import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_dialogs.dart';

const _titleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 13.5,
  color: AdminDssTheme.textPrimary,
);
const _hintStyle = TextStyle(fontSize: 11.5, color: AdminDssTheme.textMuted);
const _bodyStyle = TextStyle(
  fontSize: 12.5,
  height: 1.35,
  color: AdminDssTheme.textSecondary,
);
final _dateFormat = DateFormat.yMMMd();

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Color dssOutcomeColor(DssOutcomeStatus status) => switch (status) {
  DssOutcomeStatus.successful => AdminDssTheme.success,
  DssOutcomeStatus.partiallySuccessful => AdminDssTheme.warning,
  DssOutcomeStatus.unsuccessful => AdminDssTheme.danger,
  DssOutcomeStatus.pendingFollowup => AdminDssTheme.info,
  DssOutcomeStatus.inconclusive ||
  DssOutcomeStatus.noComparableData ||
  DssOutcomeStatus.notEvaluated => AdminDssTheme.textMuted,
};

/// The success test the server will set for a new intervention on [flag]
/// (mirrors `dss_interventions_stamp`; the server stays authoritative).
({String metric, String operator, double? target}) dssOutcomeDefaults(
  DssFlag flag,
) {
  if (flag.ruleId == 'UNEMPLOYMENT_TREND_UP') {
    final previous = flag.evidence['previous_rate'];
    return (
      metric: 'unemployment_rate',
      operator: 'lte',
      target: previous is num ? previous.toDouble() : null,
    );
  }
  final metric = switch (flag.ruleId) {
    'DATA_QUALITY_LOW' => 'response_rate',
    'UNEMPLOYMENT_HIGH' => 'unemployment_rate',
    'SEEKING_WORK_HIGH' => 'seeking_work_rate',
    'RELATEDNESS_LOW' => 'unrelated_or_irrelevant_rate',
    'RELATEDNESS_HIGH' => 'related_and_relevant_rate',
    'UNDEREMPLOYMENT' => 'clerical_among_employed_rate',
    'TIME_TO_JOB_LONG' => 'long_time_to_first_job_rate',
    'SALARY_STAGNATION' => 'salary_peer_gap',
    _ => 'unemployment_rate',
  };
  final ruleOp = flag.ruleOperator ?? 'gte';
  final operator = flag.ruleCategory == DssRuleCategory.opportunity
      ? ruleOp
      : switch (ruleOp) {
          'gte' => 'lt',
          'gt' => 'lte',
          'lte' => 'gt',
          _ => 'gte',
        };
  return (metric: metric, operator: operator, target: flag.thresholdSnapshot);
}

/// Interventions on a finding and their next-wave outcome, with the
/// decision buttons once an outcome is known.
class DssOutcomeCard extends StatelessWidget {
  const DssOutcomeCard({
    super.key,
    required this.flag,
    required this.interventions,
    this.check,
    required this.busy,
    required this.onCheck,
    this.onEditPlan,
    required this.onDecide,
  });

  final DssFlag flag;

  /// Every intervention on the finding, newest first.
  final List<DssIntervention> interventions;

  /// Latest check of the current intervention (carries the open-wave
  /// preview).
  final DssOutcomeCheck? check;
  final bool busy;

  final ValueChanged<DssIntervention> onCheck;

  /// Scrolls to the Plan card (Phase 3); plan is edited inline there.
  final VoidCallback? onEditPlan;
  final void Function(DssIntervention, DssOutcomeDecision) onDecide;

  DssIntervention? get current {
    for (final i in interventions) {
      if (!i.isDecided) return i;
    }
    return interventions.isEmpty ? null : interventions.first;
  }

  @override
  Widget build(BuildContext context) {
    final now = current;
    final earlier = [
      for (final i in interventions)
        if (i.id != now?.id) i,
    ];
    final legacy =
        interventions.isEmpty &&
        flag.status != DssFlagStatus.open &&
        flag.status != DssFlagStatus.inProgress;

    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Intervention outcome', style: _titleStyle),
              const SizedBox(width: 8),
              if (legacy)
                const DssMetaChip(label: 'Not evaluated (legacy)')
              else if (now != null)
                DssMetaChip(
                  label: now.outcomeStatus.label,
                  color: dssOutcomeColor(now.outcomeStatus),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            legacy
                ? 'This finding was closed before outcomes were tracked. The '
                      'coverage re-check is a same-wave check, not an outcome.'
                : 'Judged by fixed rules from the next tracer wave, not by AI.',
            style: _hintStyle,
          ),
          const SizedBox(height: 10),
          if (now == null && !legacy)
            const Text(
              'No intervention recorded yet. Set the Plan above, then Resolve '
              'finding — or Save plan when details are ready.',
              style: _bodyStyle,
            ),
          if (now != null) _currentBlock(now),
          if (earlier.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Earlier interventions on this finding',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminDssTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            for (final i in earlier) _earlierRow(i),
          ],
        ],
      ),
    );
  }

  Widget _currentBlock(DssIntervention i) {
    final preview = check != null && check!.provisional ? check : null;
    final judged =
        i.outcomeStatus == DssOutcomeStatus.successful ||
        i.outcomeStatus == DssOutcomeStatus.partiallySuccessful ||
        i.outcomeStatus == DssOutcomeStatus.unsuccessful;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i.interventionType,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AdminDssTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Started ${_dateFormat.format(i.startedOn)}'
          '${i.createdByName.isEmpty ? '' : ' · recorded by ${i.createdByName}'}',
          style: _hintStyle,
        ),
        if (i.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(i.description, style: _bodyStyle),
        ],
        const SizedBox(height: 8),
        if (i.expectedOutcome.isNotEmpty)
          _kv('Expected outcome', i.expectedOutcome),
        _kv('Success test', DssCopy.successTest(i)),
        _kv('Baseline', DssCopy.outcomeBaseline(i)),
        _kv('Next wave', DssCopy.outcomeFollowup(i)),
        const SizedBox(height: 2),
        Text(DssCopy.outcomeHint(i.outcomeStatus), style: _hintStyle),
        if (preview != null && preview.previewStatus != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminDssTheme.infoBg,
              borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
            ),
            child: Text(
              'Preview, not final: ${preview.followupSurveyTitle ?? 'the next wave'} '
              'still accepts responses. Today it shows '
              '${DssCopy.outcomeValue(i.successMetric, preview.followupValue)}'
              '${preview.followupN == null ? '' : ' from ${preview.followupN} answers'}'
              ', which would be "${preview.previewStatus!.label}".',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AdminDssTheme.textPrimary,
              ),
            ),
          ),
        ],
        if (judged) ...[
          const SizedBox(height: 6),
          const Text(
            DssCopy.outcomeCaveat,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: AdminDssTheme.textMuted,
            ),
          ),
        ],
        if (i.isDecided) ...[const SizedBox(height: 8), _decisionLine(i)],
        if (!i.isDecided) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : () => onCheck(i),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check outcome'),
                style: dssOutlinedButtonStyle(),
              ),
              if (i.canEditPlan && onEditPlan != null)
                OutlinedButton.icon(
                  onPressed: busy ? null : onEditPlan,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit plan'),
                  style: dssOutlinedButtonStyle(),
                ),
            ],
          ),
        ],
        if (i.canDecide) ...[
          const SizedBox(height: 12),
          const Text(
            'Decide what happens next',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminDssTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Outcome decision — separate from Resolve finding above.',
            style: _hintStyle,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: busy
                    ? null
                    : () => onDecide(i, DssOutcomeDecision.resolve),
                style: dssFilledButtonStyle(background: AdminDssTheme.success),
                child: const Text('Decide: Resolve'),
              ),
              for (final d in const [
                DssOutcomeDecision.continueWork,
                DssOutcomeDecision.modify,
                DssOutcomeDecision.escalate,
              ])
                OutlinedButton(
                  onPressed: busy ? null : () => onDecide(i, d),
                  style: dssOutlinedButtonStyle(),
                  child: Text('Decide: ${d.label}'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _decisionLine(DssIntervention i) {
    final by = [
      if ((i.decidedByName ?? '').isNotEmpty) i.decidedByName!,
      if (i.decidedAt != null) _dateFormat.format(i.decidedAt!.toLocal()),
    ].join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminDssTheme.surface,
        borderRadius: BorderRadius.circular(AdminDssTheme.radiusSm),
        border: Border.all(color: AdminDssTheme.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text:
                  'Decision: ${i.decision!.label}'
                  '${i.escalatedTo == null ? '' : ' to ${i.escalatedTo}'}. ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AdminDssTheme.textPrimary,
              ),
            ),
            TextSpan(text: i.decisionNote ?? ''),
            if (by.isNotEmpty) TextSpan(text: ' ($by)'),
          ],
        ),
        style: const TextStyle(fontSize: 12.5, height: 1.35),
      ),
    );
  }

  Widget _earlierRow(DssIntervention i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '${i.interventionType} · started '
              '${_dateFormat.format(i.startedOn)}'
              '${i.decision == null ? '' : ' · ${i.decision!.label}'}',
              style: _bodyStyle,
            ),
          ),
          const SizedBox(width: 8),
          DssMetaChip(
            label: i.outcomeStatus.label,
            color: dssOutcomeColor(i.outcomeStatus),
          ),
        ],
      ),
    );
  }

  static Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$k: ',
            style: const TextStyle(color: AdminDssTheme.textMuted),
          ),
          TextSpan(
            text: v,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AdminDssTheme.textPrimary,
            ),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 12.5, height: 1.35),
    ),
  );
}

InputDecoration _decoration(String label, {String? helper, String? error}) {
  final radius = BorderRadius.circular(AdminDssTheme.radiusSm);
  return InputDecoration(
    isDense: true,
    labelText: label,
    helperText: helper,
    errorText: error,
    helperMaxLines: 2,
    labelStyle: const TextStyle(
      fontSize: 12,
      color: AdminDssTheme.textSecondary,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AdminDssTheme.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AdminDssTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AdminDssTheme.primary, width: 1.5),
    ),
  );
}

/// The success target as typed: percent for shares, brackets for the
/// salary gap. Null when it is not a number in range.
double? dssParseOutcomeTarget(String metric, String text) {
  final v = double.tryParse(text.trim().replaceAll('%', ''));
  if (v == null) return null;
  if (metric == 'salary_peer_gap') return v < -10 || v > 10 ? null : v;
  if (v < 0 || v > 100) return null;
  return v / 100;
}

String dssFormatOutcomeTarget(String metric, double? target) {
  if (target == null) return '';
  if (metric == 'salary_peer_gap') return target.toStringAsFixed(1);
  final pct = target * 100;
  return pct == pct.roundToDouble()
      ? pct.toStringAsFixed(0)
      : pct.toStringAsFixed(1);
}

String _targetText(String metric, double? target) =>
    dssFormatOutcomeTarget(metric, target);

/// What the admin entered for a new or edited intervention. [target] is
/// null when the rule's default was kept.
typedef DssInterventionDraft = ({
  String type,
  String description,
  String expectedOutcome,
  double? target,
  DateTime startedOn,
});

Future<DssInterventionDraft?> showDssInterventionDialog(
  BuildContext context, {
  required DssFlag flag,
  DssIntervention? existing,
}) {
  return showDialog<DssInterventionDraft>(
    context: context,
    builder: (_) => _InterventionDialog(flag: flag, existing: existing),
  );
}

class _InterventionDialog extends StatefulWidget {
  const _InterventionDialog({required this.flag, this.existing});

  final DssFlag flag;
  final DssIntervention? existing;

  @override
  State<_InterventionDialog> createState() => _InterventionDialogState();
}

class _InterventionDialogState extends State<_InterventionDialog> {
  late final _defaults = dssOutcomeDefaults(widget.flag);
  late final String _metric =
      widget.existing?.successMetric ?? _defaults.metric;
  late final String _operator =
      widget.existing?.successOperator ?? _defaults.operator;
  late final double? _initialTarget =
      widget.existing?.successTarget ?? _defaults.target;
  late final _options = {
    ...DssCopy.interventionsForRule(widget.flag.ruleId),
    if (widget.existing != null) widget.existing!.interventionType,
    if (widget.existing == null && widget.flag.interventionType != null)
      widget.flag.interventionType!,
  }.toList();
  late String? _type =
      widget.existing?.interventionType ?? widget.flag.interventionType;
  late final _descriptionCtrl = TextEditingController(
    text: widget.existing?.description ?? widget.flag.interventionDetail ?? '',
  );
  late final _expectedCtrl = TextEditingController(
    text: widget.existing?.expectedOutcome ?? '',
  );
  late final _targetCtrl = TextEditingController(
    text: _targetText(_metric, _initialTarget),
  );
  late DateTime _start =
      widget.existing?.startedOn ?? widget.flag.startDate ?? _today();

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _expectedCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  String? get _targetError =>
      dssParseOutcomeTarget(_metric, _targetCtrl.text) == null
      ? (_metric == 'salary_peer_gap'
            ? 'Enter -10 to 10 brackets'
            : 'Enter 0 to 100')
      : null;

  @override
  Widget build(BuildContext context) {
    final salary = _metric == 'salary_peer_gap';
    final type = _type;
    final needsDetail = type == 'Other' && _descriptionCtrl.text.trim().isEmpty;
    final canSave = type != null && !needsDetail && _targetError == null;
    final today = _today();
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: AdminDialogStandards.shape,
      elevation: AdminDialogStandards.elevation,
      title: Text(
        widget.existing == null ? 'Record intervention' : 'Edit plan',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _options.contains(type) ? type : null,
                dropdownColor: Colors.white,
                isExpanded: true,
                decoration: _decoration('Intervention'),
                items: [
                  for (final o in _options)
                    DropdownMenuItem(value: o, child: Text(o)),
                ],
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionCtrl,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  type == 'Other'
                      ? 'What is being done (required)'
                      : 'What is being done',
                ).copyWith(alignLabelWithHint: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _expectedCtrl,
                maxLength: 1000,
                style: const TextStyle(fontSize: 13),
                decoration: _decoration(
                  'Expected outcome',
                  helper: 'e.g. More of this batch employed by the next tracer',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  'Target: ${DssCopy.outcomeMetricLabel(_metric)} '
                  '${DssCopy.outcomeOperator(_operator)}',
                  helper: salary
                      ? 'Salary brackets. Default is the rule threshold.'
                      : 'Percent of answers. Default is the rule threshold'
                            '${widget.flag.ruleId == 'UNEMPLOYMENT_TREND_UP' ? ' (the previous wave\'s rate)' : ''}.',
                  error: _targetError,
                ).copyWith(suffixText: salary ? 'brackets' : '%'),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _start.isAfter(today) ? today : _start,
                    firstDate: DateTime(today.year - 5),
                    lastDate: today,
                  );
                  if (picked != null) setState(() => _start = picked);
                },
                child: InputDecorator(
                  decoration:
                      _decoration(
                        'Started',
                        helper:
                            'The outcome comes from the first tracer wave '
                            'published after this date.',
                      ).copyWith(
                        suffixIcon: const Icon(Icons.calendar_today, size: 16),
                      ),
                  child: Text(
                    _dateFormat.format(_start),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave
              ? () {
                  final target = dssParseOutcomeTarget(
                    _metric,
                    _targetCtrl.text,
                  );
                  final unchanged =
                      _targetCtrl.text.trim() ==
                      _targetText(_metric, _initialTarget);
                  Navigator.of(context).pop((
                    type: type,
                    description: _descriptionCtrl.text.trim(),
                    expectedOutcome: _expectedCtrl.text.trim(),
                    target: unchanged && widget.existing == null
                        ? null
                        : target,
                    startedOn: _start,
                  ));
                }
              : null,
          style: dssFilledButtonStyle(),
          child: Text(widget.existing == null ? 'Record' : 'Save'),
        ),
      ],
    );
  }
}

/// What the admin entered in the decision dialog. Plan fields are set only
/// for Modify, [office] only for Escalate.
typedef DssDecisionDraft = ({
  String note,
  String? office,
  String? type,
  String? description,
  String? expectedOutcome,
  double? target,
});

String dssDecisionHint(DssOutcomeDecision d) => switch (d) {
  DssOutcomeDecision.resolve =>
    'Close the finding. The flag is resolved if it is still open.',
  DssOutcomeDecision.continueWork =>
    'Keep the same plan. A new intervention starts today, with this result '
        'as its baseline.',
  DssOutcomeDecision.modify =>
    'Change the plan. A new intervention starts today, with this result as '
        'its baseline.',
  DssOutcomeDecision.escalate =>
    'Hand the finding to another office. A closed flag is reopened.',
};

Future<DssDecisionDraft?> showDssDecisionDialog(
  BuildContext context, {
  required DssFlag flag,
  required DssIntervention intervention,
  required DssOutcomeDecision decision,
}) {
  return showDialog<DssDecisionDraft>(
    context: context,
    builder: (_) => _DecisionDialog(
      flag: flag,
      intervention: intervention,
      decision: decision,
    ),
  );
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({
    required this.flag,
    required this.intervention,
    required this.decision,
  });

  final DssFlag flag;
  final DssIntervention intervention;
  final DssOutcomeDecision decision;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _noteCtrl = TextEditingController();
  final _officeCtrl = TextEditingController();
  late final _descriptionCtrl = TextEditingController(
    text: widget.intervention.description,
  );
  late final _expectedCtrl = TextEditingController(
    text: widget.intervention.expectedOutcome,
  );
  late final _targetCtrl = TextEditingController(
    text: _targetText(
      widget.intervention.successMetric,
      widget.intervention.successTarget,
    ),
  );
  late final _options = {
    ...DssCopy.interventionsForRule(widget.flag.ruleId),
    widget.intervention.interventionType,
  }.toList();
  late String _type = widget.intervention.interventionType;

  bool get _modify => widget.decision == DssOutcomeDecision.modify;
  bool get _escalate => widget.decision == DssOutcomeDecision.escalate;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _officeCtrl.dispose();
    _descriptionCtrl.dispose();
    _expectedCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metric = widget.intervention.successMetric;
    final target = dssParseOutcomeTarget(metric, _targetCtrl.text);
    final canSave =
        _noteCtrl.text.trim().isNotEmpty && (!_modify || target != null);
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: AdminDialogStandards.shape,
      elevation: AdminDialogStandards.elevation,
      title: Text(
        '${widget.decision.label}: ${widget.intervention.outcomeStatus.label}',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(dssDecisionHint(widget.decision), style: _bodyStyle),
              const SizedBox(height: 12),
              if (_escalate) ...[
                TextField(
                  controller: _officeCtrl,
                  maxLength: 120,
                  style: const TextStyle(fontSize: 13),
                  decoration:
                      _decoration(
                        'Escalate to office (optional)',
                        helper: 'Becomes the owner office of the flag',
                      ).copyWith(
                        counterText: '',
                        suffixIcon: PopupMenuButton<String>(
                          tooltip: 'Suggested offices',
                          icon: const Icon(Icons.arrow_drop_down),
                          color: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          onSelected: (v) =>
                              setState(() => _officeCtrl.text = v),
                          itemBuilder: (_) => [
                            for (final o in DssCopy.officeSuggestions)
                              PopupMenuItem(value: o, child: Text(o)),
                          ],
                        ),
                      ),
                ),
                const SizedBox(height: 10),
              ],
              if (_modify) ...[
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  decoration: _decoration('New intervention'),
                  items: [
                    for (final o in _options)
                      DropdownMenuItem(value: o, child: Text(o)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionCtrl,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                  style: const TextStyle(fontSize: 13),
                  decoration: _decoration(
                    'What will be done',
                  ).copyWith(alignLabelWithHint: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _expectedCtrl,
                  maxLength: 1000,
                  style: const TextStyle(fontSize: 13),
                  decoration: _decoration('Expected outcome'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration:
                      _decoration(
                        'Target: ${DssCopy.outcomeMetricLabel(metric)} '
                        '${DssCopy.outcomeOperator(widget.intervention.successOperator)}',
                        error: target == null ? 'Enter a valid target' : null,
                      ).copyWith(
                        suffixText: metric == 'salary_peer_gap'
                            ? 'brackets'
                            : '%',
                      ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                style: const TextStyle(fontSize: 13),
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  'Note (required)',
                  helper: 'Why this decision, based on the outcome',
                ).copyWith(alignLabelWithHint: true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave
              ? () {
                  final office = _officeCtrl.text.trim();
                  Navigator.of(context).pop((
                    note: _noteCtrl.text.trim(),
                    office: _escalate && office.isNotEmpty ? office : null,
                    type: _modify ? _type : null,
                    description: _modify ? _descriptionCtrl.text.trim() : null,
                    expectedOutcome: _modify ? _expectedCtrl.text.trim() : null,
                    target: _modify ? target : null,
                  ));
                }
              : null,
          style: dssFilledButtonStyle(),
          child: Text(widget.decision.label),
        ),
      ],
    );
  }
}
