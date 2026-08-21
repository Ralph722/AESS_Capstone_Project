import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/admin/reports/data/custom_report_export_service.dart';
import 'package:alumni_system/features/admin/reports/data/custom_report_template_service.dart';
import 'package:alumni_system/features/admin/reports/models/custom_report_template.dart';
import 'package:alumni_system/features/admin/reports/widgets/admin_reports_layout.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/surveys/models/survey_reports_aggregate.dart';

/// Unified export hub for the Reports & Analytics Export tab.
///
/// The admin composes a report from sections and filters, optionally saves it
/// as a browser-local template, and exports it as PDF, Excel, or CSV (or opens
/// the print dialog). Naming/saving a template is optional — one-off exports
/// work immediately.
class CustomReportHubPanel extends StatefulWidget {
  const CustomReportHubPanel({
    super.key,
    required this.analytics,
    required this.events,
    required this.jobs,
    required this.rollups,
    required this.onExport,
    this.profiles = const {},
    this.presetSections = const [],
    this.presetRevision = 0,
    this.templateService,
  });

  final AdminReportsAnalytics analytics;
  final List<AlumniEvent> events;
  final List<JobPosting> jobs;
  final List<SurveyReportRollup> rollups;

  /// Live registered-account profiles keyed by auth uid; enriches roster
  /// batch/email data and drives the batch filter options.
  final Map<String, TracerProfile> profiles;

  /// Runs the actual export/print. The panel validates and manages busy state.
  final Future<void> Function(
    CustomReportTemplate template, {
    required bool printPreview,
  })
  onExport;

  /// Sections requested by quick links elsewhere on the dashboard.
  /// Applied whenever [presetRevision] changes.
  final List<CustomReportSectionId> presetSections;
  final int presetRevision;

  final CustomReportTemplateService? templateService;

  @override
  State<CustomReportHubPanel> createState() => _CustomReportHubPanelState();
}

class _CustomReportHubPanelState extends State<CustomReportHubPanel> {
  late final CustomReportTemplateService _service =
      widget.templateService ?? CustomReportTemplateService();

  final _nameController = TextEditingController();
  late CustomReportTemplate _draft;
  List<CustomReportTemplate> _saved = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _selectedSavedId;
  int _appliedPresetRevision = 0;

  /// Session-scoped export history (cleared on reload) for quick re-runs.
  final List<_RecentExport> _recentExports = [];

  static const _accentTeal = Color(0xFF0F766E);

  /// One-tap starting points that preselect a sensible section mix.
  static const List<_QuickPack> _quickPacks = [
    _QuickPack(
      label: 'Executive brief',
      description: 'KPIs, survey summary & employment outcomes',
      icon: Icons.dashboard_customize_outlined,
      sections: [
        CustomReportSectionId.executiveKpis,
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.employmentRecords,
      ],
    ),
    _QuickPack(
      label: 'CHED GTS pack',
      description: 'KPIs, survey questions & employment for GTS reporting',
      icon: Icons.verified_outlined,
      sections: [
        CustomReportSectionId.executiveKpis,
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.surveyQuestions,
        CustomReportSectionId.employmentRecords,
      ],
    ),
    _QuickPack(
      label: 'Registrar roster',
      description: 'Full alumni roster with employment records',
      icon: Icons.groups_outlined,
      sections: [
        CustomReportSectionId.alumniRoster,
        CustomReportSectionId.employmentRecords,
      ],
    ),
    _QuickPack(
      label: 'Participation pack',
      description: 'Survey summary & participation by wave',
      icon: Icons.how_to_vote_outlined,
      sections: [
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.surveyParticipation,
      ],
    ),
    _QuickPack(
      label: 'Full report',
      description: 'Every available section in one document',
      icon: Icons.all_inbox_outlined,
      sections: CustomReportSectionId.values,
    ),
  ];

  /// Section grouping for the picker (presentation only — order matches enum).
  static const List<(String, List<CustomReportSectionId>)> _sectionGroups = [
    ('Overview', [CustomReportSectionId.executiveKpis]),
    (
      'Alumni & tracer',
      [
        CustomReportSectionId.alumniRoster,
        CustomReportSectionId.employmentRecords,
      ],
    ),
    (
      'Surveys',
      [
        CustomReportSectionId.surveySummary,
        CustomReportSectionId.surveyParticipation,
        CustomReportSectionId.surveyQuestions,
        CustomReportSectionId.chedWaveComparison,
      ],
    ),
    (
      'Engagement',
      [
        CustomReportSectionId.events,
        CustomReportSectionId.jobPostings,
        CustomReportSectionId.announcements,
        CustomReportSectionId.forumTopics,
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _draft = CustomReportTemplate.draft(id: _newId());
    _appliedPresetRevision = widget.presetRevision;
    if (widget.presetSections.isNotEmpty) {
      _draft = _draft.copyWith(sections: List.of(widget.presetSections));
    }
    _nameController.text = _draft.name;
    _loadSaved();
  }

  @override
  void didUpdateWidget(covariant CustomReportHubPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.presetRevision != _appliedPresetRevision &&
        widget.presetSections.isNotEmpty) {
      _appliedPresetRevision = widget.presetRevision;
      _applyDraft(
        _draft.copyWith(
          sections: List.of(widget.presetSections),
          updatedAt: DateTime.now(),
        ),
        selectSaved: _selectedSavedId != null,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _newId() =>
      'crt_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}';

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    final list = await _service.loadAll();
    if (!mounted) return;
    setState(() {
      _saved = list;
      _loading = false;
    });
  }

  void _applyDraft(CustomReportTemplate draft, {bool selectSaved = false}) {
    setState(() {
      _draft = draft;
      if (_nameController.text != draft.name) {
        _nameController.text = draft.name;
      }
      _error = null;
      if (!selectSaved) _selectedSavedId = null;
    });
  }

  void _startNew() {
    _applyDraft(CustomReportTemplate.draft(id: _newId()));
  }

  void _applyQuickPack(_QuickPack pack) {
    _applyDraft(
      CustomReportTemplate.draft(
        id: _newId(),
      ).copyWith(sections: List.of(pack.sections), updatedAt: DateTime.now()),
    );
  }

  void _loadTemplate(CustomReportTemplate t) {
    setState(() => _selectedSavedId = t.id);
    _applyDraft(t, selectSaved: true);
  }

  void _toggleSection(CustomReportSectionId id) {
    final next = List<CustomReportSectionId>.from(_draft.sections);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
      next.sort(
        (a, b) => CustomReportSectionId.values
            .indexOf(a)
            .compareTo(CustomReportSectionId.values.indexOf(b)),
      );
    }
    _applyDraft(
      _draft.copyWith(sections: next, updatedAt: DateTime.now()),
      selectSaved: _selectedSavedId != null,
    );
  }

  void _updateFilters(CustomReportFilters filters) {
    _applyDraft(
      _draft.copyWith(filters: filters, updatedAt: DateTime.now()),
      selectSaved: _selectedSavedId != null,
    );
  }

  CustomReportTemplate get _currentTemplate => _draft.copyWith(
    name: _nameController.text.trim(),
    updatedAt: DateTime.now(),
  );

  /// Row estimates for every section (selected or not) so cards can show
  /// exactly how much data each one would contribute with current filters.
  Map<CustomReportSectionId, int> get _estimates {
    return CustomReportExportService.estimateRowCounts(
      template: _draft.copyWith(
        name: 'estimate',
        sections: CustomReportSectionId.values,
      ),
      analytics: widget.analytics,
      events: widget.events,
      jobs: widget.jobs,
      rollups: widget.rollups,
      profilesByAuthUid: widget.profiles,
    );
  }

  /// Batch years present on actual accounts in the system (roster rows and
  /// registered profiles) — updates automatically as new batches register.
  List<String> get _batchOptions {
    final set = <String>{};
    for (final m in widget.analytics.activeRoster) {
      final profile = CustomReportExportService.profileFor(m, widget.profiles);
      final b = CustomReportExportService.memberBatch(m, profile);
      if (b.isNotEmpty && b.toLowerCase() != 'unknown') set.add(b);
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<String> get _courseOptions {
    final set = <String>{};
    for (final m in widget.analytics.activeRoster) {
      final c = m.course.trim();
      if (c.isNotEmpty && c.toLowerCase() != 'unknown') set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  int get _activeFilterCount {
    final f = _draft.filters;
    var n = 0;
    if (f.batchYears.isNotEmpty) n++;
    if (f.courses.isNotEmpty) n++;
    if (f.registration != CustomReportRegistrationFilter.all) n++;
    if (f.tracer != CustomReportTracerFilter.all) n++;
    if (f.employment != CustomReportEmploymentFilter.all) n++;
    if (f.hasDateRange) n++;
    return n;
  }

  Future<void> _saveTemplate() async {
    final template = _currentTemplate;
    final error = template.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.save(template);
      if (!mounted) return;
      setState(() {
        _draft = template;
        _selectedSavedId = template.id;
        _busy = false;
      });
      await _loadSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved “${template.name}”.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deleteSelected() async {
    final id = _selectedSavedId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete “${_draft.name}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AdminReportsTheme.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _service.delete(id);
    if (!mounted) return;
    _startNew();
    await _loadSaved();
  }

  void _duplicateSelected() {
    final now = DateTime.now();
    final copy = _draft.copyWith(
      id: _newId(),
      name: '${_nameController.text.trim()} (copy)',
      createdAt: now,
      updatedAt: now,
    );
    _applyDraft(copy);
  }

  Future<void> _runExport({required bool printPreview}) async {
    final template = _currentTemplate;
    final error = template.validate(forSave: false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final estimates = _estimates;
    final rows = template.sections.fold<int>(
      0,
      (sum, id) => sum + (estimates[id] ?? 0),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onExport(template, printPreview: printPreview);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recentExports.insert(
          0,
          _RecentExport(
            title: template.name.trim().isEmpty
                ? 'Untitled report'
                : template.name.trim(),
            format: template.format,
            sections: List.of(template.sections),
            rows: rows,
            printed: printPreview,
            at: DateTime.now(),
          ),
        );
        if (_recentExports.length > 6) {
          _recentExports.removeRange(6, _recentExports.length);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 25),
      lastDate: DateTime(now.year + 2),
      initialDateRange:
          _draft.filters.dateStart != null && _draft.filters.dateEnd != null
          ? DateTimeRange(
              start: _draft.filters.dateStart!,
              end: _draft.filters.dateEnd!,
            )
          : DateTimeRange(
              start: DateTime(now.year, now.month - 3, now.day),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AdminReportsTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    _updateFilters(
      _draft.filters.copyWith(dateStart: picked.start, dateEnd: picked.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estimates = _estimates;
    final selectedRows = _draft.sections.fold<int>(
      0,
      (sum, id) => sum + (estimates[id] ?? 0),
    );

    return ReportsSectionStack(
      children: [
        ReportsSectionShell(
          icon: Icons.tune_outlined,
          title: 'Report center',
          subtitle:
              'Start from a quick pack or build your own, then export or print.',
          collapsible: false,
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _quickPacksBlock(),
                    const SizedBox(height: AdminReportsTheme.space3),
                    _savedTemplatesStrip(),
                    if (_recentExports.isNotEmpty) ...[
                      const SizedBox(height: AdminReportsTheme.space3),
                      _recentExportsBlock(),
                    ],
                    const SizedBox(height: AdminReportsTheme.space3),
                    _stepHeader(
                      step: 1,
                      title: 'Choose sections',
                      caption:
                          '${_draft.sections.length} selected — tap a card to toggle it',
                    ),
                    const SizedBox(height: 12),
                    _groupedSectionGrid(estimates),
                    const SizedBox(height: AdminReportsTheme.space3),
                    _stepHeader(
                      step: 2,
                      title: 'Refine filters',
                      caption: _activeFilterCount == 0
                          ? 'No filters — everything is included'
                          : '$_activeFilterCount active filter(s)',
                      trailing: _activeFilterCount == 0
                          ? null
                          : TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _updateFilters(
                                      const CustomReportFilters(),
                                    ),
                              icon: const Icon(
                                Icons.filter_alt_off_outlined,
                                size: 16,
                              ),
                              label: const Text('Clear all'),
                            ),
                    ),
                    const SizedBox(height: 12),
                    _filtersBlock(),
                    const SizedBox(height: AdminReportsTheme.space3),
                    _stepHeader(
                      step: 3,
                      title: 'Format & export',
                      caption:
                          'Name it only if you want to save it as a template',
                    ),
                    const SizedBox(height: 12),
                    _formatAndNameRow(),
                    const SizedBox(height: AdminReportsTheme.space2),
                    _summaryBanner(selectedRows),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _errorBanner(),
                    ],
                    const SizedBox(height: AdminReportsTheme.space2),
                    const Divider(height: 1, color: AdminReportsTheme.border),
                    const SizedBox(height: AdminReportsTheme.space2),
                    _footer(),
                  ],
                ),
        ),
      ],
    );
  }

  // —— saved templates ——

  Widget _savedTemplatesStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bookmarks_outlined,
              size: 16,
              color: AdminReportsTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Saved templates',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AdminReportsTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _saved.isEmpty ? 'none yet' : '${_saved.length}',
              style: const TextStyle(
                fontSize: 12,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _newTemplateCard(),
              for (final t in _saved) ...[
                const SizedBox(width: 10),
                _savedTemplateCard(t),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _newTemplateCard() {
    return InkWell(
      onTap: _busy ? null : _startNew,
      borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(
            color: AdminReportsTheme.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
          color: AdminReportsTheme.primary.withValues(alpha: 0.04),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: AdminReportsTheme.primary,
              size: 22,
            ),
            SizedBox(height: 6),
            Text(
              'New report',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AdminReportsTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedTemplateCard(CustomReportTemplate t) {
    final selected = t.id == _selectedSavedId;
    return InkWell(
      onTap: _busy ? null : () => _loadTemplate(t),
      borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(
            color: selected
                ? AdminReportsTheme.primary
                : AdminReportsTheme.border,
            width: selected ? 1.6 : 1,
          ),
          color: selected
              ? AdminReportsTheme.primary.withValues(alpha: 0.06)
              : AdminReportsTheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 15,
                  color: selected
                      ? AdminReportsTheme.primary
                      : AdminReportsTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AdminReportsTheme.primary
                          : AdminReportsTheme.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 15,
                    color: AdminReportsTheme.primary,
                  ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                _miniPill(t.format.label, AdminReportsTheme.primary),
                const SizedBox(width: 6),
                _miniPill(
                  '${t.sections.length} section(s)',
                  AdminReportsTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Updated ${DateFormat.yMMMd().format(t.updatedAt)}',
              style: const TextStyle(
                fontSize: 10.5,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // —— step header ——

  Widget _stepHeader({
    required int step,
    required String title,
    required String caption,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AdminReportsTheme.primary,
                AdminReportsTheme.primary.withValues(alpha: 0.75),
              ],
            ),
          ),
          child: Text(
            '$step',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AdminReportsTheme.textPrimary,
                ),
              ),
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // —— quick packs ——

  Widget _quickPacksBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(
              Icons.bolt_outlined,
              size: 16,
              color: AdminReportsTheme.textSecondary,
            ),
            SizedBox(width: 6),
            Text(
              'Quick report packs',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AdminReportsTheme.textPrimary,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'one tap to preselect sections',
              style: TextStyle(
                fontSize: 12,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final pack in _quickPacks) _quickPackCard(pack)],
        ),
      ],
    );
  }

  Widget _quickPackCard(_QuickPack pack) {
    final active =
        _draft.sections.length == pack.sections.length &&
        pack.sections.every(_draft.sections.contains);
    return InkWell(
      onTap: _busy ? null : () => _applyQuickPack(pack),
      borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 232,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(
            color: active ? _accentTeal : AdminReportsTheme.border,
            width: active ? 1.6 : 1,
          ),
          color: active
              ? _accentTeal.withValues(alpha: 0.06)
              : AdminReportsTheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: _accentTeal.withValues(alpha: 0.12),
              ),
              child: Icon(pack.icon, size: 17, color: _accentTeal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? _accentTeal
                          : AdminReportsTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pack.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.3,
                      color: AdminReportsTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // —— recent exports ——

  Widget _recentExportsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.history_outlined,
              size: 16,
              color: AdminReportsTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Recent exports',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AdminReportsTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'this session only',
                style: TextStyle(
                  fontSize: 12,
                  color: AdminReportsTheme.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => setState(_recentExports.clear),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _recentExports.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _recentExportRow(_recentExports[i]),
        ],
      ],
    );
  }

  Widget _recentExportRow(_RecentExport e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AdminReportsTheme.surface,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            e.printed ? Icons.print_outlined : _formatIcon(e.format),
            size: 16,
            color: AdminReportsTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AdminReportsTheme.textPrimary,
                  ),
                ),
                Text(
                  '${e.printed ? 'Printed' : e.format.label} · '
                  '${e.sections.length} section(s) · ~${e.rows} row(s) · '
                  '${DateFormat.jm().format(e.at)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminReportsTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _busy ? null : () => _reuseRecent(e),
            icon: const Icon(Icons.replay, size: 15),
            label: const Text('Reuse'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _reuseRecent(_RecentExport e) {
    _applyDraft(
      CustomReportTemplate.draft(id: _newId()).copyWith(
        sections: List.of(e.sections),
        format: e.format,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // —— section grid ——

  Widget _groupedSectionGrid(Map<CustomReportSectionId, int> estimates) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 330).floor().clamp(1, 3);
        const gap = 10.0;
        final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var g = 0; g < _sectionGroups.length; g++) ...[
              if (g > 0) const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _sectionGroups[g].$1.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AdminReportsTheme.textSecondary,
                  ),
                ),
              ),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final id in _sectionGroups[g].$2)
                    SizedBox(
                      width: cardWidth,
                      child: _sectionCard(id, estimates[id] ?? 0),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionCard(CustomReportSectionId id, int rows) {
    final selected = _draft.sections.contains(id);
    final zero = rows == 0;
    final countColor = zero
        ? AdminReportsTheme.warning
        : AdminReportsTheme.success;
    return InkWell(
      onTap: _busy ? null : () => _toggleSection(id),
      borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          border: Border.all(
            color: selected
                ? AdminReportsTheme.primary
                : AdminReportsTheme.border,
            width: selected ? 1.6 : 1,
          ),
          color: selected
              ? AdminReportsTheme.primary.withValues(alpha: 0.05)
              : AdminReportsTheme.surface,
          boxShadow: selected ? AdminReportsTheme.cardShadow : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color:
                    (selected
                            ? AdminReportsTheme.primary
                            : AdminReportsTheme.textSecondary)
                        .withValues(alpha: 0.10),
              ),
              child: Icon(
                id.icon,
                size: 18,
                color: selected
                    ? AdminReportsTheme.primary
                    : AdminReportsTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          id.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AdminReportsTheme.primary
                                : AdminReportsTheme.textPrimary,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          key: ValueKey(selected),
                          size: 17,
                          color: selected
                              ? AdminReportsTheme.primary
                              : AdminReportsTheme.border,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    id.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: AdminReportsTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _miniPill(
                    zero ? 'No rows with current filters' : '$rows row(s)',
                    countColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // —— filters ——

  Widget _filtersBlock() {
    return Container(
      padding: const EdgeInsets.all(AdminReportsTheme.space2),
      decoration: BoxDecoration(
        color: AdminReportsTheme.background,
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: AdminReportsTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Filters apply only where the field exists — batch/course on roster & '
            'events, registration/tracer on roster, employment status on employment, '
            'dates on rows with a date (roster uses the date the member was added).',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AdminReportsTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _MultiSelectField(
            label: 'Batch years',
            options: _batchOptions,
            selected: _draft.filters.batchYears,
            enabled: !_busy,
            onChanged: (next) =>
                _updateFilters(_draft.filters.copyWith(batchYears: next)),
          ),
          const SizedBox(height: 10),
          _MultiSelectField(
            label: 'Courses / programs',
            options: _courseOptions,
            selected: _draft.filters.courses,
            enabled: !_busy,
            onChanged: (next) =>
                _updateFilters(_draft.filters.copyWith(courses: next)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _enumDropdown<CustomReportRegistrationFilter>(
                label: 'Registration',
                value: _draft.filters.registration,
                values: CustomReportRegistrationFilter.values,
                labelOf: (v) => switch (v) {
                  CustomReportRegistrationFilter.all => 'All',
                  CustomReportRegistrationFilter.registeredOnly =>
                    'Registered only',
                  CustomReportRegistrationFilter.unregisteredOnly =>
                    'Unregistered only',
                },
                onChanged: (v) =>
                    _updateFilters(_draft.filters.copyWith(registration: v)),
              ),
              _enumDropdown<CustomReportTracerFilter>(
                label: 'Tracer',
                value: _draft.filters.tracer,
                values: CustomReportTracerFilter.values,
                labelOf: (v) => switch (v) {
                  CustomReportTracerFilter.all => 'All',
                  CustomReportTracerFilter.completeOnly => 'Complete only',
                  CustomReportTracerFilter.incompleteOnly => 'Incomplete only',
                },
                onChanged: (v) =>
                    _updateFilters(_draft.filters.copyWith(tracer: v)),
              ),
              _enumDropdown<CustomReportEmploymentFilter>(
                label: 'Employment',
                value: _draft.filters.employment,
                values: CustomReportEmploymentFilter.values,
                labelOf: (v) => switch (v) {
                  CustomReportEmploymentFilter.all => 'All',
                  CustomReportEmploymentFilter.employedOnly => 'Employed only',
                  CustomReportEmploymentFilter.unemployedOnly =>
                    'Unemployed only',
                },
                onChanged: (v) =>
                    _updateFilters(_draft.filters.copyWith(employment: v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickDateRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  _draft.filters.hasDateRange
                      ? '${DateFormat.yMMMd().format(_draft.filters.dateStart!)}'
                            ' – '
                            '${DateFormat.yMMMd().format(_draft.filters.dateEnd!)}'
                      : 'Date range (optional)',
                ),
              ),
              if (_draft.filters.hasDateRange) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _updateFilters(
                          _draft.filters.copyWith(clearDateRange: true),
                        ),
                  child: const Text('Clear dates'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _enumDropdown<T extends Enum>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<T>(
        key: ValueKey('$label-${value.name}'),
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AdminReportsTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: [
          for (final v in values)
            DropdownMenuItem(value: v, child: Text(labelOf(v))),
        ],
        onChanged: _busy
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      ),
    );
  }

  // —— format + name ——

  Widget _formatAndNameRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final formatPicker = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<CustomReportFormat>(
              segments: [
                for (final f in CustomReportFormat.values)
                  ButtonSegment(
                    value: f,
                    label: Text(f.label),
                    icon: Icon(_formatIcon(f), size: 16),
                  ),
              ],
              selected: {_draft.format},
              onSelectionChanged: _busy
                  ? null
                  : (set) => _applyDraft(
                      _draft.copyWith(
                        format: set.first,
                        updatedAt: DateTime.now(),
                      ),
                      selectSaved: _selectedSavedId != null,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatHint(_draft.format),
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminReportsTheme.textMuted,
              ),
            ),
          ],
        );
        final nameField = TextField(
          controller: _nameController,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: 'Template name (optional)',
            hintText: 'Only needed to save — e.g. Registrar weekly pack',
            prefixIcon: const Icon(Icons.drive_file_rename_outline, size: 18),
            filled: true,
            fillColor: AdminReportsTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
            ),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              formatPicker,
              const SizedBox(width: 20),
              Expanded(child: nameField),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [formatPicker, const SizedBox(height: 12), nameField],
        );
      },
    );
  }

  IconData _formatIcon(CustomReportFormat f) => switch (f) {
    CustomReportFormat.pdf => Icons.picture_as_pdf_outlined,
    CustomReportFormat.excel => Icons.table_chart_outlined,
    CustomReportFormat.csv => Icons.description_outlined,
  };

  String _formatHint(CustomReportFormat f) => switch (f) {
    CustomReportFormat.pdf =>
      'Landscape PDF with one titled table per section — good for sharing.',
    CustomReportFormat.excel =>
      'One worksheet per section — good for pivots and further analysis.',
    CustomReportFormat.csv =>
      'Single flat file with labeled section blocks — good for other tools.',
  };

  // —— summary + errors + footer ——

  Widget _summaryBanner(int selectedRows) {
    final IconData icon;
    final Color color;
    final String text;
    if (_draft.sections.isEmpty) {
      icon = Icons.info_outline;
      color = AdminReportsTheme.warning;
      text = 'Select at least one section above to enable exporting.';
    } else if (selectedRows == 0) {
      icon = Icons.warning_amber_rounded;
      color = AdminReportsTheme.warning;
      text =
          'Heads up — no data rows match the current filters. The exported file '
          'would contain section headers only. Loosen the filters to include data.';
    } else {
      icon = Icons.check_circle_outline;
      color = AdminReportsTheme.success;
      text =
          'Ready to export: ~$selectedRows data row(s) across '
          '${_draft.sections.length} section(s)'
          '${_activeFilterCount > 0 ? ' with $_activeFilterCount filter(s) applied' : ''}.';
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        _error!,
        style: const TextStyle(color: AdminReportsTheme.danger, fontSize: 12.5),
      ),
    );
  }

  Widget _footer() {
    final canExport = _draft.sections.isNotEmpty && !_busy;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_selectedSavedId != null) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : _duplicateSelected,
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Duplicate'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _deleteSelected,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminReportsTheme.danger,
            ),
          ),
          const SizedBox(width: 4),
        ],
        OutlinedButton.icon(
          onPressed: _busy ? null : _saveTemplate,
          icon: const Icon(Icons.bookmark_add_outlined, size: 16),
          label: const Text('Save template'),
        ),
        OutlinedButton.icon(
          onPressed: canExport ? () => _runExport(printPreview: true) : null,
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text('Print'),
        ),
        FilledButton.icon(
          onPressed: canExport ? () => _runExport(printPreview: false) : null,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_outlined, size: 16),
          label: Text('Export ${_draft.format.label}'),
          style: FilledButton.styleFrom(
            backgroundColor: _accentTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// One-tap starting point that preselects a curated section mix.
class _QuickPack {
  const _QuickPack({
    required this.label,
    required this.description,
    required this.icon,
    required this.sections,
  });

  final String label;
  final String description;
  final IconData icon;
  final List<CustomReportSectionId> sections;
}

/// A single session-scoped export/print event shown in Recent exports.
class _RecentExport {
  const _RecentExport({
    required this.title,
    required this.format,
    required this.sections,
    required this.rows,
    required this.printed,
    required this.at,
  });

  final String title;
  final CustomReportFormat format;
  final List<CustomReportSectionId> sections;
  final int rows;
  final bool printed;
  final DateTime at;
}

/// Multi-select chip field with a built-in search box for long option lists.
class _MultiSelectField extends StatefulWidget {
  const _MultiSelectField({
    required this.label,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_MultiSelectField> createState() => _MultiSelectFieldState();
}

class _MultiSelectFieldState extends State<_MultiSelectField> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.toLowerCase().contains(q))
              .toList(growable: false);
    final showSearch = widget.options.length > 10;

    return InputDecorator(
      decoration: InputDecoration(
        labelText:
            '${widget.label}${widget.selected.isEmpty ? '' : ' · ${widget.selected.length} selected'}',
        filled: true,
        fillColor: AdminReportsTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminReportsTheme.radiusMd),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      child: widget.options.isEmpty
          ? const Text(
              'No options loaded yet',
              style: TextStyle(
                fontSize: 12.5,
                color: AdminReportsTheme.textMuted,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSearch) ...[
                  TextField(
                    enabled: widget.enabled,
                    decoration: const InputDecoration(
                      hintText: 'Search…',
                      prefixIcon: Icon(Icons.search, size: 16),
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12.5),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 8),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final option in visible)
                          FilterChip(
                            label: Text(
                              option,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: widget.selected.contains(option),
                            onSelected: widget.enabled
                                ? (v) {
                                    final next = List<String>.from(
                                      widget.selected,
                                    );
                                    if (v) {
                                      next.add(option);
                                    } else {
                                      next.remove(option);
                                    }
                                    widget.onChanged(next);
                                  }
                                : null,
                            selectedColor: AdminReportsTheme.primary.withValues(
                              alpha: 0.14,
                            ),
                            checkmarkColor: AdminReportsTheme.primary,
                          ),
                        if (visible.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'No matches',
                              style: TextStyle(
                                fontSize: 12,
                                color: AdminReportsTheme.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
