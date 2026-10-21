import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alumni_system/features/admin/dss/application/dss_history.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_kpi_card.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

class AdminDssHistoryPanel extends StatefulWidget {
  const AdminDssHistoryPanel({
    super.key,
    required this.onClose,
    this.selectedSubnav = 1,
    this.onSubnavSelected,
  });

  final Future<void> Function() onClose;
  final int selectedSubnav;
  final ValueChanged<int>? onSubnavSelected;

  @override
  State<AdminDssHistoryPanel> createState() => _AdminDssHistoryPanelState();
}

class _AdminDssHistoryPanelState extends State<AdminDssHistoryPanel> {
  final _repo = DssRepository();
  DssHistoryStats? _stats;
  DssOutcomeSummary? _outcomes;
  List<DssEvaluationRun> _runs = const [];
  Map<String, String> _ruleNames = {};
  bool _loading = true;
  String? _error;

  /// Days of history to show; null is all time.
  int? _lookbackDays = 365;

  String get _periodLabel =>
      _lookbackDays == null ? 'All time' : 'Last 12 months';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.historyStats(lookbackDays: _lookbackDays),
        _repo.listRules(),
        _repo.listRecentInterventions(lookbackDays: _lookbackDays),
        _repo.listEvaluationRuns(),
      ]);
      final stats = results[0] as DssHistoryStats;
      final rules = results[1] as List<DssRule>;
      final interventions = results[2] as List<DssIntervention>;
      final runs = results[3] as List<DssEvaluationRun>;
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _outcomes = DssOutcomeSummary.from(interventions);
        _runs = runs;
        _ruleNames = {for (final r in rules) r.ruleId: r.displayName};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DssPageHeader(
          title: 'History',
          subtitle: 'Findings raised, closed, and re-checked over time.',
          onBack: widget.onSubnavSelected == null
              ? () => widget.onClose()
              : null,
          backTooltip: 'Back to findings',
          selectedSubnav: widget.onSubnavSelected != null
              ? widget.selectedSubnav
              : null,
          onSubnavSelected: widget.onSubnavSelected,
          actions: [
            DirectoryFilterField<int?>(
              label: 'Period',
              value: _lookbackDays,
              width: 170,
              enabled: !_loading,
              items: const [
                DropdownMenuItem<int?>(
                  value: 365,
                  child: Text('Last 12 months'),
                ),
                DropdownMenuItem<int?>(value: null, child: Text('All time')),
              ],
              onChanged: (v) {
                if (v == _lookbackDays) return;
                setState(() => _lookbackDays = v);
                _load();
              },
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Reload'),
              style: dssOutlinedButtonStyle(),
            ),
          ],
        ),
        const SizedBox(height: AdminDssTheme.space2),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: DirectoryEmptyState(
              title: 'Could not load history',
              subtitle: _error!,
              icon: Icons.error_outline,
              primaryAction: _load,
              primaryLabel: 'Retry',
            ),
          )
        else if (s == null)
          const Expanded(child: Center(child: Text('No data')))
        else
          Expanded(
            child: ListView(
              children: [
                DirectoryKpiRow(
                  children: [
                    AdminKpiCard(
                      dense: true,
                      label: 'Raised',
                      value: '${s.raised}',
                      caption: s.superseded == 0
                          ? _periodLabel
                          : '$_periodLabel · ${s.superseded} superseded',
                      icon: Icons.flag_outlined,
                      accent: AdminColors.primary,
                    ),
                    AdminKpiCard(
                      dense: true,
                      label: 'Still open',
                      value: '${s.open}',
                      caption: 'Not started',
                      icon: Icons.pending_outlined,
                      accent: AdminColors.danger,
                    ),
                    AdminKpiCard(
                      dense: true,
                      label: 'Resolved',
                      value: '${s.resolved}',
                      caption: 'With action',
                      icon: Icons.check_circle_outline,
                      accent: AdminColors.success,
                    ),
                    AdminKpiCard(
                      dense: true,
                      label: 'Avg days',
                      value: s.avgResolutionDays == null
                          ? '—'
                          : s.avgResolutionDays!.toStringAsFixed(1),
                      caption: 'To close',
                      icon: Icons.timelapse_outlined,
                      accent: AdminColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: AdminDssTheme.space2),
                DirectoryKpiRow(
                  children: [
                    AdminKpiCard(
                      dense: true,
                      label: 'Re-checked',
                      value: '${s.impactChecked}',
                      caption: 'Same-wave coverage',
                      icon: Icons.verified_outlined,
                      accent: AdminColors.info,
                    ),
                    AdminKpiCard(
                      dense: true,
                      label: 'Improved',
                      value: s.improvedPct == null
                          ? '—'
                          : '${(s.improvedPct! * 100).toStringAsFixed(0)}%',
                      caption: s.impactChecked == 0
                          ? 'No re-checks'
                          : '${s.impactImproved}/${s.impactChecked}',
                      icon: Icons.trending_up,
                      accent: AdminColors.success,
                    ),
                    AdminKpiCard(
                      dense: true,
                      label: 'Still flagged',
                      value: '${s.impactStillFlagged}',
                      caption: 'Needs follow-up',
                      icon: Icons.warning_amber_outlined,
                      accent: AdminColors.danger,
                    ),
                    AdminKpiCard(
                      dense: true,
                      label: 'Dismissed',
                      value: '${s.dismissed}',
                      caption: 'No action',
                      icon: Icons.remove_circle_outline,
                      accent: AdminColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AdminDssTheme.space2),
                DssSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Coverage re-checks by rule',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AdminDssTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (s.impactByRule.isEmpty)
                        const Text(
                          'Re-check coverage on resolved findings to populate this.',
                          style: TextStyle(
                            color: AdminDssTheme.textMuted,
                            fontSize: 12.5,
                          ),
                        )
                      else
                        ...(() {
                          final entries = s.impactByRule.entries.toList()
                            ..sort(
                              (a, b) =>
                                  b.value.checked.compareTo(a.value.checked),
                            );
                          return entries.map((e) {
                            final pct = e.value.checked == 0
                                ? 0.0
                                : e.value.improved / e.value.checked;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    dssRuleIcon(e.key),
                                    size: 16,
                                    color: AdminDssTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _ruleNames[e.key] ?? e.key,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AdminDssTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(pct * 100).toStringAsFixed(0)}% improved'
                                    ' · ${e.value.stillFlagged} still',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminDssTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          });
                        })(),
                    ],
                  ),
                ),
                const SizedBox(height: AdminDssTheme.space2),
                DssSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'By rule',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AdminDssTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (s.byRule.isEmpty)
                        const Text(
                          'No findings in this period.',
                          style: TextStyle(
                            color: AdminDssTheme.textMuted,
                            fontSize: 12.5,
                          ),
                        )
                      else
                        ...(() {
                          final entries = s.byRule.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value));
                          return entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    dssRuleIcon(e.key),
                                    size: 16,
                                    color: AdminDssTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _ruleNames[e.key] ?? e.key,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AdminDssTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${e.value}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AdminDssTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })(),
                    ],
                  ),
                ),
                const SizedBox(height: AdminDssTheme.space2),
                DssSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'By month',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AdminDssTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (s.byMonth.isEmpty)
                        const Text(
                          'No monthly activity yet.',
                          style: TextStyle(
                            color: AdminDssTheme.textMuted,
                            fontSize: 12.5,
                          ),
                        )
                      else
                        ...(() {
                          final entries = s.byMonth.entries.toList()
                            ..sort((a, b) => a.key.compareTo(b.key));
                          final max = entries
                              .map((e) => e.value)
                              .fold<int>(1, (a, b) => a > b ? a : b);
                          return entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AdminDssTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${e.value}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: e.value / max,
                                      minHeight: 6,
                                      backgroundColor: AdminDssTheme.surface,
                                      color: AdminDssTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })(),
                    ],
                  ),
                ),
                const SizedBox(height: AdminDssTheme.space2),
                _OutcomesCard(
                  summary: _outcomes ?? DssOutcomeSummary.from(const []),
                  periodLabel: _periodLabel,
                  ruleNames: _ruleNames,
                ),
                const SizedBox(height: AdminDssTheme.space2),
                _RunsCard(runs: _runs),
                const SizedBox(height: AdminDensity.space3),
              ],
            ),
          ),
      ],
    );
  }
}

const _cardTitle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 13.5,
  color: AdminDssTheme.textPrimary,
);
const _muted = TextStyle(color: AdminDssTheme.textMuted, fontSize: 12.5);
const _cell = TextStyle(fontSize: 12.5, color: AdminDssTheme.textPrimary);
const _head = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w700,
  color: AdminDssTheme.textSecondary,
);

/// Next-wave outcomes of recorded interventions, by type and by rule.
class _OutcomesCard extends StatelessWidget {
  const _OutcomesCard({
    required this.summary,
    required this.periodLabel,
    required this.ruleNames,
  });

  final DssOutcomeSummary summary;
  final String periodLabel;
  final Map<String, String> ruleNames;

  @override
  Widget build(BuildContext context) {
    final o = summary.overall;
    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Intervention outcomes', style: _cardTitle),
          const SizedBox(height: 4),
          const Text(
            'Next tracer wave vs baseline — association, not causation.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AdminDssTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (summary.isEmpty)
            Text(
              'No interventions recorded ($periodLabel).',
              style: _muted,
            )
          else ...[
            Text(
              '${o.total} recorded ($periodLabel): '
              '${o.count(DssOutcomeStatus.successful)} successful · '
              '${o.count(DssOutcomeStatus.partiallySuccessful)} partial · '
              '${o.count(DssOutcomeStatus.unsuccessful)} unsuccessful · '
              '${o.count(DssOutcomeStatus.inconclusive)} inconclusive · '
              '${o.count(DssOutcomeStatus.noComparableData)} no data · '
              '${o.waiting} waiting',
              style: _cell,
            ),
            const SizedBox(height: 12),
            _OutcomeTable(firstColumn: 'Intervention type', rows: summary.byType),
            const SizedBox(height: 14),
            _OutcomeTable(
              firstColumn: 'Rule',
              rows: {
                for (final e in summary.byRule.entries)
                  ruleNames[e.key] ?? e.key: e.value,
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeTable extends StatelessWidget {
  const _OutcomeTable({required this.firstColumn, required this.rows});

  final String firstColumn;
  final Map<String, DssOutcomeTally> rows;

  @override
  Widget build(BuildContext context) {
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: child,
    );
    Widget num(int n) => pad(
      Text(
        '$n',
        textAlign: TextAlign.right,
        style: n == 0 ? _cell.copyWith(color: AdminDssTheme.textMuted) : _cell,
      ),
    );
    const headers = [
      'Recorded',
      'Successful',
      'Partially',
      'Unsuccessful',
      'Inconclusive',
      'No comparable data',
      'Waiting',
    ];
    return Table(
      columnWidths: const {0: FlexColumnWidth(2.6)},
      defaultColumnWidth: const FlexColumnWidth(1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        horizontalInside: BorderSide(color: AdminDssTheme.border, width: 0.6),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AdminDssTheme.surface),
          children: [
            pad(Text(firstColumn, style: _head)),
            for (final h in headers)
              pad(Text(h, textAlign: TextAlign.right, style: _head)),
          ],
        ),
        for (final e in rows.entries)
          TableRow(
            children: [
              pad(Text(e.key, style: _cell)),
              num(e.value.total),
              num(e.value.count(DssOutcomeStatus.successful)),
              num(e.value.count(DssOutcomeStatus.partiallySuccessful)),
              num(e.value.count(DssOutcomeStatus.unsuccessful)),
              num(e.value.count(DssOutcomeStatus.inconclusive)),
              num(e.value.count(DssOutcomeStatus.noComparableData)),
              num(e.value.waiting),
            ],
          ),
      ],
    );
  }
}

/// The latest Refresh and nightly evaluation runs.
class _RunsCard extends StatelessWidget {
  const _RunsCard({required this.runs});

  final List<DssEvaluationRun> runs;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    return DssSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evaluation runs', style: _cardTitle),
          const SizedBox(height: 4),
          const Text(
            'Latest Refresh insights and nightly runs (up to 20).',
            style: TextStyle(fontSize: 12, color: AdminDssTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          if (runs.isEmpty)
            const Text(
              'No runs logged yet.',
              style: _muted,
            )
          else
            for (final r in runs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.scheduled ? Icons.schedule : Icons.touch_app_outlined,
                      size: 16,
                      color: AdminDssTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 190,
                      child: Text(
                        df.format(r.at.toLocal()),
                        style: _cell,
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        r.triggerLabel,
                        style: _cell.copyWith(
                          color: AdminDssTheme.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${r.raised} new, ${r.updated} refreshed, '
                        '${r.superseded} superseded, ${r.skipped} not raised '
                        'again, ${r.notEnoughData} with too few answers',
                        style: _cell,
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

class AdminDssHistoryPage extends StatelessWidget {
  const AdminDssHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDssTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AdminDensity.space3),
          child: AdminDssHistoryPanel(
            onClose: () async => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
