import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/personal_data_export_dialog.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/admin/surveys/presentation/admin_survey_editor_page.dart';
import 'package:alumni_system/features/admin/surveys/presentation/admin_survey_responses_page.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_template_picker.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';

enum _SurveyStatusFilter { all, draft, published, closed, archived }

enum _SurveyKindFilter { all, officialChed, custom }

enum _SurveySort {
  newest,
  oldest,
  titleAsc,
  responsesDesc,
}

enum _SurveyPanel { list, responses, editor }

class AdminSurveysScreen extends StatefulWidget {
  const AdminSurveysScreen({super.key});

  @override
  State<AdminSurveysScreen> createState() => _AdminSurveysScreenState();
}

class _AdminSurveysScreenState extends State<AdminSurveysScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _surveyService = SurveyService();
  final _searchController = TextEditingController();
  List<Survey> _surveys = [];
  bool _isLoading = false;

  _SurveyStatusFilter _statusFilter = _SurveyStatusFilter.all;
  _SurveyKindFilter _kindFilter = _SurveyKindFilter.all;
  _SurveySort _sort = _SurveySort.newest;
  String _query = '';

  _SurveyPanel _panel = _SurveyPanel.list;
  /// Survey shown in the responses workspace (Overview / Pending / Submitted).
  String? _activeSurveyId;
  /// Survey opened in the edit/publish workspace.
  String? _editorSurveyId;
  /// When true, closing the editor returns to responses for [_activeSurveyId].
  bool _editorReturnToResponses = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditor(String surveyId, {bool fromResponses = false}) {
    setState(() {
      _editorSurveyId = surveyId;
      _editorReturnToResponses = fromResponses;
      if (!fromResponses) {
        _activeSurveyId = surveyId;
      }
      _panel = _SurveyPanel.editor;
    });
  }

  void _openResponses(String surveyId) {
    setState(() {
      _activeSurveyId = surveyId;
      _editorSurveyId = null;
      _editorReturnToResponses = false;
      _panel = _SurveyPanel.responses;
    });
  }

  Future<void> _closeEditor() async {
    if (_editorReturnToResponses && _activeSurveyId != null) {
      setState(() {
        _panel = _SurveyPanel.responses;
        _editorSurveyId = null;
        _editorReturnToResponses = false;
      });
      return;
    }
    await _closePanel();
  }

  Future<void> _closePanel() async {
    setState(() {
      _panel = _SurveyPanel.list;
      _activeSurveyId = null;
      _editorSurveyId = null;
      _editorReturnToResponses = false;
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _surveyService.getAllSurveysForAdmin();
      if (!mounted) return;

      setState(() {
        _surveys = list;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading surveys: $e')),
        );
      }
    }
  }

  List<Survey> get _filtered {
    var list = _surveys.where((s) {
      switch (_statusFilter) {
        case _SurveyStatusFilter.all:
          if (s.archived) return false;
        case _SurveyStatusFilter.draft:
          if (s.archived || s.status != SurveyStatus.draft) return false;
        case _SurveyStatusFilter.published:
          if (s.archived || s.status != SurveyStatus.published) return false;
        case _SurveyStatusFilter.closed:
          if (s.archived || s.status != SurveyStatus.closed) return false;
        case _SurveyStatusFilter.archived:
          if (!s.archived) return false;
      }

      switch (_kindFilter) {
        case _SurveyKindFilter.all:
          break;
        case _SurveyKindFilter.officialChed:
          if (!s.isChedGtsBuiltin) return false;
        case _SurveyKindFilter.custom:
          if (s.isChedGtsBuiltin) return false;
      }

      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hay =
            '${s.title} ${s.description} ${s.templateKey ?? ''} ${s.kind ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _SurveySort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SurveySort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SurveySort.titleAsc:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _SurveySort.responsesDesc:
        list.sort((a, b) => b.responseCount.compareTo(a.responseCount));
    }
    return list;
  }

  int get _draftCount =>
      _surveys.where((s) => !s.archived && s.status == SurveyStatus.draft).length;
  int get _publishedCount => _surveys
      .where((s) => !s.archived && s.status == SurveyStatus.published)
      .length;
  int get _closedCount => _surveys
      .where((s) => !s.archived && s.status == SurveyStatus.closed)
      .length;
  int get _archivedCount => _surveys.where((s) => s.archived).length;
  int get _responseTotal => _surveys
      .where((s) => !s.archived)
      .fold<int>(0, (sum, s) => sum + s.responseCount);

  Future<void> _createSurvey() async {
    final choice = await showAdminNewSurveyPicker(context);
    if (choice == null || !mounted) return;

    try {
      final String id;
      if (choice is NewSurveyChedBuiltin) {
        id = await _surveyService.createBuiltinChedGtsSurvey();
      } else {
        final titleController = TextEditingController();
        final descController = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Blank survey'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: AdminSurveyTheme.fieldDecoration(label: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration:
                      AdminSurveyTheme.fieldDecoration(label: 'Description'),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: surveyFilledButtonStyle(),
                child: const Text('Create'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) {
          titleController.dispose();
          descController.dispose();
          return;
        }
        id = await _surveyService.createSurvey(
          title: titleController.text.trim(),
          description: descController.text.trim(),
        );
        titleController.dispose();
        descController.dispose();
      }

      if (!mounted) return;
      _openEditor(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _exportSurvey(Survey survey) async {
    if (!requireWebExport(context)) return;
    if (!await confirmPersonalDataExport(
          context,
          what: 'The detailed survey export',
        ) ||
        !mounted) {
      return;
    }
    try {
      final questions = await _surveyService.getQuestions(survey.id);
      final participants = await _surveyService.getSurveyParticipants(survey.id);
      final csv = _surveyService.buildDetailedSurveyExportCsv(
        survey: survey,
        questions: questions,
        participants: participants,
      );
      final bytes = utf8.encode(csv);
      if (!mounted) return;
      tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName:
            'survey_${survey.title.replaceAll(RegExp(r'[^\w\-]+'), '_')}_detailed_export.csv',
        mimeType: 'text/csv',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportSurveyPdfSummary(Survey survey) async {
    if (!requireWebExport(context)) return;
    try {
      final questions = await _surveyService.getQuestions(survey.id);
      final participants = await _surveyService.getSurveyParticipants(survey.id);
      final bytes = await _surveyService.buildDetailedSurveySummaryPdfBytes(
        survey: survey,
        questions: questions,
        participants: participants,
      );
      if (!mounted) return;
      tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName:
            'survey_${survey.title.replaceAll(RegExp(r'[^\w\-]+'), '_')}_summary.pdf',
        mimeType: 'application/pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _duplicate(Survey s) async {
    try {
      final id = await _surveyService.duplicateSurvey(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey duplicated as draft'),
          backgroundColor: Colors.green,
        ),
      );
      _openEditor(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String body,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: surveyFilledButtonStyle(
              background: destructive
                  ? AdminSurveyTheme.danger
                  : AdminSurveyTheme.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _archive(Survey s, {required bool archived}) async {
    final ok = await _confirmAction(
      title: archived ? 'Archive survey?' : 'Restore survey?',
      body: archived
          ? 'Archived surveys are hidden from the active list. You can restore them later.'
          : 'This survey will return to the active list with its previous status.',
      confirmLabel: archived ? 'Archive' : 'Restore',
    );
    if (!ok) return;
    try {
      await _surveyService.setSurveyArchived(s.id, archived: archived);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(archived ? 'Survey archived' : 'Survey restored'),
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _remindPending(Survey s) async {
    try {
      final participants =
          await _surveyService.getSurveyParticipants(s.id);
      final pending =
          _surveyService.pendingParticipants(participants);
      final pendingIds = pending.map((p) => p.assignment.userId).toList();
      if (pendingIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending alumni to remind')),
          );
        }
        return;
      }
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Send reminders?'),
          content: Text(
            'Send in-app and email reminders to ${pendingIds.length} '
            'pending alumni for "${s.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      final result = await _surveyService.sendReminders(
        surveyId: s.id,
        userIds: pendingIds,
        inApp: true,
        email: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminders sent: ${result.inAppSent} in-app'
            '${result.emailSent > 0 ? ', ${result.emailSent} email' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onSurveyMenu(Survey s, String value) async {
    if (value == 'edit') {
      _openEditor(s.id);
    } else if (value == 'responses') {
      _openResponses(s.id);
    } else if (value == 'export') {
      await _exportSurvey(s);
    } else if (value == 'export_pdf') {
      await _exportSurveyPdfSummary(s);
    } else if (value == 'duplicate') {
      await _duplicate(s);
    } else if (value == 'remind' &&
        s.status == SurveyStatus.published &&
        !s.archived) {
      await _remindPending(s);
    } else if (value == 'archive') {
      await _archive(s, archived: true);
    } else if (value == 'unarchive') {
      await _archive(s, archived: false);
    } else if (value == 'reassign' &&
        s.status == SurveyStatus.published &&
        !s.archived) {
      final ok = await _confirmAction(
        title: 'Re-assign alumni?',
        body:
            'Refresh assignments for alumni matching this survey’s audience. '
            'Existing submissions are kept.',
        confirmLabel: 'Re-assign',
      );
      if (!ok) return;
      try {
        final count = await _surveyService.publishSurvey(s.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assigned to $count alumni'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (value == 'close' &&
        s.status == SurveyStatus.published &&
        !s.archived) {
      final ok = await _confirmAction(
        title: 'Close survey?',
        body:
            'Alumni will no longer be able to submit. You can still view responses.',
        confirmLabel: 'Close',
        destructive: true,
      );
      if (!ok) return;
      await _surveyService.closeSurvey(s.id);
      _load();
    } else if (value == 'delete') {
      final confirm = await _confirmAction(
        title: 'Delete survey?',
        body: 'This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (confirm) {
        await _surveyService.deleteSurvey(s.id);
        _load();
      }
    }
  }

  List<PopupMenuEntry<String>> _menuItemsFor(Survey s) {
    return [
      const PopupMenuItem(
        value: 'edit',
        child: Text('Edit / publish'),
      ),
      const PopupMenuItem(
        value: 'responses',
        child: Text('View responses'),
      ),
      const PopupMenuItem(
        value: 'duplicate',
        child: Text('Duplicate'),
      ),
      // Official CHED exports live under View responses (CSV / CHED Excel pack).
      if (!s.isChedGtsBuiltin &&
          !s.isFromTemplate &&
          s.responseCount > 0 &&
          canExportFiles) ...[
        const PopupMenuItem(
          value: 'export',
          child: Text('Export detailed CSV'),
        ),
        const PopupMenuItem(
          value: 'export_pdf',
          child: Text('Export PDF summary'),
        ),
      ],
      if (s.status == SurveyStatus.published && !s.archived) ...[
        const PopupMenuItem(
          value: 'remind',
          child: Text('Remind pending'),
        ),
        const PopupMenuItem(
          value: 'reassign',
          child: Text('Re-assign alumni'),
        ),
        const PopupMenuItem(
          value: 'close',
          child: Text('Close survey'),
        ),
      ],
      if (s.archived)
        const PopupMenuItem(
          value: 'unarchive',
          child: Text('Restore from archive'),
        )
      else
        const PopupMenuItem(
          value: 'archive',
          child: Text('Archive'),
        ),
      const PopupMenuItem(
        value: 'delete',
        child: Text('Delete'),
      ),
    ];
  }

  String _metaLine(Survey s) {
    final fmt = DateFormat.yMMMd();
    final parts = <String>[
      '${s.assignmentCount} assigned',
      '${s.responseCount} submitted',
      'Created ${fmt.format(s.createdAt)}',
    ];
    if (s.openAt != null) {
      parts.add('Opens ${fmt.format(s.openAt!)}');
    }
    if (s.closeAt != null) {
      parts.add('Closes ${fmt.format(s.closeAt!)}');
    }
    return parts.join(' · ');
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _statusFilter != _SurveyStatusFilter.all ||
      _kindFilter != _SurveyKindFilter.all;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _statusFilter = _SurveyStatusFilter.all;
      _kindFilter = _SurveyKindFilter.all;
    });
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    if (_query.isNotEmpty) {
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Search: $_query',
          onRemoved: () {
            _searchController.clear();
            setState(() => _query = '');
          },
        ),
      );
    }
    if (_statusFilter != _SurveyStatusFilter.all) {
      final label = switch (_statusFilter) {
        _SurveyStatusFilter.draft => 'Draft',
        _SurveyStatusFilter.published => 'Published',
        _SurveyStatusFilter.closed => 'Closed',
        _SurveyStatusFilter.archived => 'Archived',
        _SurveyStatusFilter.all => 'Active',
      };
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Status: $label',
          onRemoved: () => setState(() => _statusFilter = _SurveyStatusFilter.all),
        ),
      );
    }
    if (_kindFilter != _SurveyKindFilter.all) {
      final label = switch (_kindFilter) {
        _SurveyKindFilter.officialChed => 'Official CHED',
        _SurveyKindFilter.custom => 'Custom',
        _SurveyKindFilter.all => 'All',
      };
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Kind: $label',
          onRemoved: () => setState(() => _kindFilter = _SurveyKindFilter.all),
        ),
      );
    }
    return chips;
  }

  Widget _buildMetrics() {
    return DirectoryStatsGrid(
      children: [
        DirectoryStatCard(
          label: 'Draft',
          value: '$_draftCount',
          description: 'Not yet published',
          icon: Icons.edit_note_outlined,
          accent: AdminSurveyTheme.warning,
          onTap: () => setState(() => _statusFilter = _SurveyStatusFilter.draft),
        ),
        DirectoryStatCard(
          label: 'Published',
          value: '$_publishedCount',
          description: 'Live waves',
          icon: Icons.publish_outlined,
          accent: AdminSurveyTheme.success,
          onTap: () =>
              setState(() => _statusFilter = _SurveyStatusFilter.published),
        ),
        DirectoryStatCard(
          label: 'Closed',
          value: '$_closedCount',
          description: 'Ended waves',
          icon: Icons.lock_outline,
          accent: AdminSurveyTheme.textSecondary,
          onTap: () =>
              setState(() => _statusFilter = _SurveyStatusFilter.closed),
        ),
        DirectoryStatCard(
          label: 'Responses',
          value: '$_responseTotal',
          description: 'Submitted answers',
          icon: Icons.insights_outlined,
          accent: AdminSurveyTheme.primary,
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return DirectoryToolbarCard(
      searchController: _searchController,
      onSearchChanged: (v) => setState(() => _query = v.trim()),
      onClearSearch: () {
        _searchController.clear();
        setState(() => _query = '');
      },
      isLoading: _isLoading,
      onRefresh: _load,
      hasActiveFilters: _hasActiveFilters,
      onResetFilters: _resetFilters,
      activeFilterChips: _activeFilterChips(),
      searchHint: 'Search by title, description, or kind…',
      filters: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DirectoryFilterField<_SurveyKindFilter>(
            label: 'Kind',
            value: _kindFilter,
            width: 148,
            items: const [
              DropdownMenuItem(
                value: _SurveyKindFilter.all,
                child: Text('All kinds'),
              ),
              DropdownMenuItem(
                value: _SurveyKindFilter.officialChed,
                child: Text('Official CHED'),
              ),
              DropdownMenuItem(
                value: _SurveyKindFilter.custom,
                child: Text('Custom'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _kindFilter = v);
            },
          ),
          DirectoryFilterField<_SurveySort>(
            label: 'Sort',
            value: _sort,
            width: 148,
            items: const [
              DropdownMenuItem(
                value: _SurveySort.newest,
                child: Text('Newest first'),
              ),
              DropdownMenuItem(
                value: _SurveySort.oldest,
                child: Text('Oldest first'),
              ),
              DropdownMenuItem(
                value: _SurveySort.titleAsc,
                child: Text('Title A–Z'),
              ),
              DropdownMenuItem(
                value: _SurveySort.responsesDesc,
                child: Text('Most responses'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _sort = v);
            },
          ),
          for (final f in _SurveyStatusFilter.values)
            DirectoryToolbarFilterChip(
              label: switch (f) {
                _SurveyStatusFilter.all => 'Active',
                _SurveyStatusFilter.draft => 'Draft',
                _SurveyStatusFilter.published => 'Published',
                _SurveyStatusFilter.closed => 'Closed',
                _SurveyStatusFilter.archived => 'Archived ($_archivedCount)',
              },
              selected: _statusFilter == f,
              onSelected: (_) => setState(() => _statusFilter = f),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_panel == _SurveyPanel.editor && _editorSurveyId != null) {
      return AdminSurveyEditorScreen(
        key: ValueKey('editor-$_editorSurveyId'),
        surveyId: _editorSurveyId!,
        onClose: _closeEditor,
        backTooltip: _editorReturnToResponses
            ? 'Back to responses'
            : 'Back to surveys',
      );
    }

    if (_panel == _SurveyPanel.responses && _activeSurveyId != null) {
      return AdminSurveyResponsesScreen(
        key: ValueKey('responses-$_activeSurveyId'),
        surveyId: _activeSurveyId!,
        onClose: _closePanel,
        onOpenEditor: (id) => _openEditor(id, fromResponses: true),
      );
    }

    return _buildSurveyList();
  }

  Widget _buildSurveyList() {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            SurveyPageHeader(
              title: 'Tracer surveys',
              subtitle: 'Create and manage tracer waves and surveys.',
              actions: [
                FilledButton.icon(
                  onPressed: _isLoading ? null : _createSurvey,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('New survey'),
                  style: surveyFilledButtonStyle(),
                ),
              ],
            ),
            const SizedBox(height: AdminSurveyTheme.space2),
            _buildMetrics(),
            const SizedBox(height: AdminSurveyTheme.space2),
            _buildToolbar(),
            const SizedBox(height: AdminSurveyTheme.space1),
            Expanded(
              child: AdminInstantContent(
                loading: _isLoading,
                loadingSkeleton: const PortalCardListSkeleton(),
                isEmpty: filtered.isEmpty,
                empty: DirectoryEmptyState(
                  title: _surveys.isEmpty ? 'No surveys yet' : 'No matches',
                  subtitle: _surveys.isEmpty
                      ? 'Create an Official CHED GTS wave or a blank custom survey.'
                      : 'Try a different search or filter.',
                  icon: Icons.poll_outlined,
                  primaryAction: _surveys.isEmpty ? _createSurvey : null,
                  primaryLabel: 'New survey',
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: AdminDensity.space3),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return SurveyListCard(
                      survey: s,
                      metaLine: _metaLine(s),
                      menuItems: _menuItemsFor(s),
                      onMenuSelected: (value) => _onSurveyMenu(s, value),
                      onOpen: () => _openResponses(s.id),
                    );
                  },
                ),
              ),
            ),
          ],
    );
  }
}
