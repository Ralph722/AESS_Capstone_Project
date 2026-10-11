import 'package:flutter/material.dart';

import 'package:alumni_system/features/admin/dss/application/dss_copy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';

class AdminDssSettingsPanel extends StatefulWidget {
  const AdminDssSettingsPanel({super.key, required this.onClose});

  final Future<void> Function() onClose;

  @override
  State<AdminDssSettingsPanel> createState() => _AdminDssSettingsPanelState();
}

class _AdminDssSettingsPanelState extends State<AdminDssSettingsPanel> {
  final _repo = DssRepository();
  List<DssRule> _rules = [];
  bool _loading = true;
  String? _error;
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rules = await _repo.listRules();
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      for (final r in rules) {
        final isRate = r.ruleId != 'SALARY_STAGNATION';
        final display = isRate ? (r.threshold * 100) : r.threshold;
        _controllers['${r.ruleId}|threshold'] = TextEditingController(
          text: display.toStringAsFixed(isRate ? 0 : 1),
        );
        _controllers['${r.ruleId}|minN'] = TextEditingController(
          text: '${r.minN}',
        );
      }
      if (!mounted) return;
      setState(() {
        _rules = rules;
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

  Future<void> _save(DssRule rule) async {
    final thrCtrl = _controllers['${rule.ruleId}|threshold'];
    final minCtrl = _controllers['${rule.ruleId}|minN'];
    final thrRaw = double.tryParse(thrCtrl?.text.trim() ?? '');
    final minN = int.tryParse(minCtrl?.text.trim() ?? '');
    if (thrRaw == null || minN == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid threshold and minimum responses.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final isRate = rule.ruleId != 'SALARY_STAGNATION';
    final threshold = isRate ? thrRaw / 100.0 : thrRaw;
    final error = DssPolicy.ruleEditError(
      rule,
      threshold: threshold,
      minN: minN,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    try {
      await _repo.updateRule(rule.copyWith(threshold: threshold, minN: minN));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${rule.displayName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggle(DssRule rule, bool enabled) async {
    try {
      await _repo.updateRule(rule.copyWith(enabled: enabled));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _severityLabel(DssSeverity severity) => switch (severity) {
    DssSeverity.critical => 'Critical',
    DssSeverity.warning => 'Warning',
    DssSeverity.info => 'Info',
  };

  String _categoryLabel(DssRuleCategory category) => switch (category) {
    DssRuleCategory.outcome => 'Outcome',
    DssRuleCategory.dataQuality => 'Data quality',
    DssRuleCategory.opportunity => 'Opportunity',
    DssRuleCategory.trend => 'Trend',
  };

  InputDecoration _fieldDecoration(String label) {
    final radius = BorderRadius.circular(AdminDssTheme.radiusSm);
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: AdminDssTheme.textSecondary,
      ),
      filled: true,
      fillColor: AdminDssTheme.background,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DssPageHeader(
          title: 'Insight rule settings',
          subtitle:
              'Set when an alert should appear. Use plain percentages and minimum answers — then Save each rule.',
          onBack: () => widget.onClose(),
          backTooltip: 'Back to recommendations',
        ),
        const SizedBox(height: AdminDssTheme.space2),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: DirectoryEmptyState(
              title: 'Could not load rules',
              subtitle: _error!,
              icon: Icons.error_outline,
              primaryAction: _load,
              primaryLabel: 'Retry',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: AdminDensity.space3),
              itemCount: _rules.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AdminDensity.listItemGap),
              itemBuilder: (context, i) {
                final rule = _rules[i];
                final sevColor = dssSeverityColor(rule.severity);
                return DssSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: sevColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AdminDssTheme.radiusSm,
                              ),
                            ),
                            child: Icon(
                              dssRuleIcon(rule.ruleId),
                              size: 18,
                              color: sevColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rule.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AdminDssTheme.textPrimary,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: rule.enabled,
                            onChanged: (v) => _toggle(rule, v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rule.description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AdminDssTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DssCopy.settingsMinResponsesHint(rule),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AdminDssTheme.textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Click Save after editing this rule. Then go back and click Refresh insights.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AdminDssTheme.textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          DssMetaChip(
                            label: _severityLabel(rule.severity),
                            color: sevColor,
                          ),
                          DssMetaChip(label: _categoryLabel(rule.category)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller:
                                  _controllers['${rule.ruleId}|threshold'],
                              decoration: _fieldDecoration(
                                DssCopy.settingsThresholdHint(rule),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 168,
                            child: TextField(
                              controller: _controllers['${rule.ruleId}|minN'],
                              decoration: _fieldDecoration(
                                'Minimum (at least '
                                '${DssPolicy.minNFloor(rule.category)})',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _save(rule),
                            style: dssFilledButtonStyle(),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class AdminDssSettingsPage extends StatelessWidget {
  const AdminDssSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDssTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AdminDensity.space3),
          child: AdminDssSettingsPanel(
            onClose: () async => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
