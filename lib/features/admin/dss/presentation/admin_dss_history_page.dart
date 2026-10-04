import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

class AdminDssHistoryPanel extends StatefulWidget {
  const AdminDssHistoryPanel({super.key, required this.onClose});

  final Future<void> Function() onClose;

  @override
  State<AdminDssHistoryPanel> createState() => _AdminDssHistoryPanelState();
}

class _AdminDssHistoryPanelState extends State<AdminDssHistoryPanel> {
  final _repo = DssRepository();
  DssHistoryStats? _stats;
  Map<String, String> _ruleNames = {};
  bool _loading = true;
  String? _error;

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
        _repo.historyStats(),
        _repo.listRules(),
      ]);
      final stats = results[0] as DssHistoryStats;
      final rules = results[1] as List<DssRule>;
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _ruleNames = {for (final r in rules) r.ruleId: r.name};
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
          title: 'Insights history & trends',
          subtitle:
              'Flags raised and closed over time — useful continuous-improvement evidence.',
          onBack: () => widget.onClose(),
          backTooltip: 'Back to recommendations',
          actions: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Refresh'),
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
                DirectoryStatsGrid(
                  children: [
                    DirectoryStatCard(
                      label: 'Raised',
                      value: '${s.raised}',
                      description: 'Last 12 months',
                      icon: Icons.flag_outlined,
                      accent: AdminDssTheme.primary,
                    ),
                    DirectoryStatCard(
                      label: 'Open',
                      value: '${s.open}',
                      description: 'Still active',
                      icon: Icons.pending_outlined,
                      accent: AdminDssTheme.danger,
                    ),
                    DirectoryStatCard(
                      label: 'Resolved',
                      value: '${s.resolved}',
                      description: 'Closed with action',
                      icon: Icons.check_circle_outline,
                      accent: AdminDssTheme.success,
                    ),
                    DirectoryStatCard(
                      label: 'Avg days',
                      value: s.avgResolutionDays == null
                          ? '—'
                          : s.avgResolutionDays!.toStringAsFixed(1),
                      description: 'Time to close',
                      icon: Icons.timelapse_outlined,
                      accent: AdminDssTheme.warning,
                    ),
                  ],
                ),
                const SizedBox(height: AdminDssTheme.space2),
                DirectoryStatsGrid(
                  children: [
                    DirectoryStatCard(
                      label: 'Impact checked',
                      value: '${s.impactChecked}',
                      description: 'Resolved with verdict',
                      icon: Icons.verified_outlined,
                      accent: AdminDssTheme.info,
                    ),
                    DirectoryStatCard(
                      label: 'Improved',
                      value: s.improvedPct == null
                          ? '—'
                          : '${(s.improvedPct! * 100).toStringAsFixed(0)}%',
                      description:
                          '${s.impactImproved} of ${s.impactChecked} improved',
                      icon: Icons.trending_up,
                      accent: AdminDssTheme.success,
                    ),
                    DirectoryStatCard(
                      label: 'Still flagged',
                      value: '${s.impactStillFlagged}',
                      description: 'Need more follow-up',
                      icon: Icons.warning_amber_outlined,
                      accent: AdminDssTheme.danger,
                    ),
                    DirectoryStatCard(
                      label: 'Dismissed',
                      value: '${s.dismissed}',
                      description: 'Closed without action',
                      icon: Icons.remove_circle_outline,
                      accent: AdminDssTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AdminDssTheme.space3),
                DssSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Impact by rule',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AdminDssTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (s.impactByRule.isEmpty)
                        const Text(
                          'Resolve flags and recheck impact to see rates here.',
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
                          'No flags in this period.',
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
                const SizedBox(height: AdminDensity.space3),
              ],
            ),
          ),
      ],
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
