import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/personal_data_export_dialog.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/admin/surveys/presentation/admin_survey_editor_page.dart';
import 'package:alumni_system/features/admin/surveys/presentation/admin_survey_responses_page.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_instant_content.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_template_picker.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/share/share_link_sheet.dart';
import 'package:alumni_system/features/share/shareable_content.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_density.dart';
import 'package:alumni_system/shared/widgets/admin/admin_kpi_card.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

enum _SurveyStatusFilter { all, draft, published, closed, archived }

enum _SurveyKindFilter { all, officialChed, chedPreset, custom }

enum _SurveySort { newest, oldest, titleAsc, responsesDesc }

enum _SurveyPanel { list, responses, editor }

enum _SnackTone { neutral, success, warning, danger }

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
  bool _hasLoaded = false;
  String? _loadError;
  String? _loadErrorDetails;

  /// Surveys with a menu action in progress (blocks starting it twice).
  final Set<String> _busyIds = {};

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
        _hasLoaded = true;
        _loadError = null;
        _loadErrorDetails = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = _friendlyError(
            e,
            'Check your connection and try again.',
          );
          _loadErrorDetails = '$e';
        });
      }
    }
  }

  /// Service messages are shown as-is; technical errors fall back to
  /// [fallback].
  String _friendlyError(Object error, String fallback) {
    var text = '$error';
    while (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length);
    }
    text = text.trim();
    final technical =
        text.isEmpty ||
        text.startsWith('Error ') ||
        text.contains('Exception') ||
        text.length > 160;
    return technical ? fallback : text;
  }

  void _showSnack(String message, {_SnackTone tone = _SnackTone.neutral}) {
    if (!mounted) return;
    final background = switch (tone) {
      _SnackTone.neutral => null,
      _SnackTone.success => AdminColors.success,
      _SnackTone.warning => AdminColors.warning,
      _SnackTone.danger => AdminColors.danger,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  Future<void> _runBusy(Survey s, Future<void> Function() action) async {
    if (_busyIds.contains(s.id)) return;
    setState(() => _busyIds.add(s.id));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyIds.remove(s.id));
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
        case _SurveyKindFilter.chedPreset:
          if (s.isChedGtsBuiltin || !s.isFromTemplate) return false;
        case _SurveyKindFilter.custom:
          if (s.isChedGtsBuiltin || s.isFromTemplate) return false;
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

  int get _draftCount => _surveys
      .where((s) => !s.archived && s.status == SurveyStatus.draft)
      .length;
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
        final input = await showAdminDialogSurface<(String, String)>(
          context: context,
          maxWidth: 480,
          child: const _BlankSurveyDialog(),
        );
        if (input == null || !mounted) return;
        id = await _surveyService.createSurvey(
          title: input.$1,
          description: input.$2,
        );
      }

      if (!mounted) return;
      _openEditor(id);
    } catch (e) {
      _showSnack(
        _friendlyError(e, "Couldn't create the survey. Please try again."),
        tone: _SnackTone.danger,
      );
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
      final participants = await _surveyService.getSurveyParticipants(
        survey.id,
      );
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
      _showSnack(
        _friendlyError(
          e,
          "Couldn't export the detailed CSV. Please try again.",
        ),
        tone: _SnackTone.danger,
      );
    }
  }

  Future<void> _exportSurveyPdfSummary(Survey survey) async {
    if (!requireWebExport(context)) return;
    if (!await confirmPersonalDataExport(
          context,
          what: 'The PDF survey summary',
        ) ||
        !mounted) {
      return;
    }
    try {
      final questions = await _surveyService.getQuestions(survey.id);
      final participants = await _surveyService.getSurveyParticipants(
        survey.id,
      );
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
      _showSnack(
        _friendlyError(e, "Couldn't export the PDF summary. Please try again."),
        tone: _SnackTone.danger,
      );
    }
  }

  Future<void> _duplicate(Survey s) async {
    try {
      final id = await _surveyService.duplicateSurvey(s.id);
      if (!mounted) return;
      _showSnack('Survey duplicated as draft', tone: _SnackTone.success);
      _openEditor(id);
    } catch (e) {
      _showSnack(
        _friendlyError(e, "Couldn't duplicate the survey. Please try again."),
        tone: _SnackTone.danger,
      );
    }
  }

  Future<void> _archive(Survey s, {required bool archived}) async {
    final ok = await showAdminConfirmDialog(
      context,
      title: archived ? 'Archive survey?' : 'Restore survey?',
      message:
          '${surveyIdentityText(s)}\n\n'
          '${archived ? 'Archived surveys are hidden from the active list. You can restore them later.' : 'This survey will return to the active list with its previous status.'}',
      confirmLabel: archived ? 'Archive' : 'Restore',
      icon: archived ? Icons.archive_outlined : Icons.unarchive_outlined,
    );
    if (!ok) return;
    try {
      await _surveyService.setSurveyArchived(s.id, archived: archived);
      _showSnack(
        archived ? 'Survey archived' : 'Survey restored',
        tone: _SnackTone.success,
      );
      _load();
    } catch (e) {
      _showSnack(
        _friendlyError(
          e,
          archived
              ? "Couldn't archive the survey. Please try again."
              : "Couldn't restore the survey. Please try again.",
        ),
        tone: _SnackTone.danger,
      );
    }
  }

  Future<void> _remindPending(Survey s) async {
    try {
      final participants = await _surveyService.getSurveyParticipants(s.id);
      final pending = _surveyService.pendingParticipants(participants);
      final pendingIds = pending.map((p) => p.assignment.userId).toList();
      if (pendingIds.isEmpty) {
        _showSnack('No pending alumni to remind');
        return;
      }
      if (!mounted) return;
      final confirm = await showAdminConfirmDialog(
        context,
        title: 'Send reminders?',
        message:
            'Send in-app and email reminders to ${pendingIds.length} '
            'pending alumni?\n\n${surveyIdentityText(s)}',
        confirmLabel: 'Send reminders',
        icon: Icons.notifications_active_outlined,
      );
      if (!confirm) return;
      final result = await _surveyService.sendReminders(
        surveyId: s.id,
        userIds: pendingIds,
        inApp: true,
        email: true,
      );
      if (!mounted) return;
      final skipped = <String>[
        if (result.emailSkippedNoAddress > 0)
          '${result.emailSkippedNoAddress} without an email address',
        if (result.emailSkippedNotConfigured > 0)
          '${result.emailSkippedNotConfigured} because email is not configured',
      ];
      final message = StringBuffer(
        'Reminders sent: ${result.inAppSent} in-app'
        '${result.emailSent > 0 ? ', ${result.emailSent} email' : ''}.',
      );
      if (skipped.isNotEmpty) {
        message.write(' Email skipped: ${skipped.join('; ')}.');
      }
      if (result.failures.isNotEmpty) {
        message.write(' ${result.failures.length} failed.');
      }
      _showSnack(
        message.toString(),
        tone: skipped.isEmpty && result.failures.isEmpty
            ? _SnackTone.success
            : _SnackTone.warning,
      );
    } catch (e) {
      _showSnack(
        _friendlyError(e, "Couldn't send reminders. Please try again."),
        tone: _SnackTone.danger,
      );
    }
  }

  Future<void> _onSurveyMenu(Survey s, String value) async {
    if (value == 'share') {
      await showShareLinkSheet(context, ShareableContent.fromSurvey(s));
      return;
    }
    if (value == 'edit') {
      _openEditor(s.id);
    } else if (value == 'responses') {
      _openResponses(s.id);
    } else {
      await _runBusy(s, () => _runMenuAction(s, value));
    }
  }

  Future<void> _runMenuAction(Survey s, String value) async {
    if (value == 'export') {
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
      final ok = await showAdminConfirmDialog(
        context,
        title: 'Re-assign alumni?',
        message:
            '${surveyIdentityText(s)}\n\n'
            'Refresh assignments for alumni matching this survey’s audience. '
            'Existing submissions are kept.',
        confirmLabel: 'Re-assign',
        icon: Icons.group_add_outlined,
      );
      if (!ok) return;
      try {
        final count = await _surveyService.publishSurvey(s.id);
        _showSnack('Assigned to $count alumni', tone: _SnackTone.success);
        _load();
      } catch (e) {
        _showSnack(
          _friendlyError(e, "Couldn't re-assign alumni. Please try again."),
          tone: _SnackTone.danger,
        );
      }
    } else if (value == 'close' &&
        s.status == SurveyStatus.published &&
        !s.archived) {
      final ok = await showAdminConfirmDialog(
        context,
        title: 'Close survey?',
        message:
            '${surveyIdentityText(s)}\n\n'
            'Alumni will no longer be able to submit. You can still view responses.',
        confirmLabel: 'Close',
        destructive: true,
        icon: Icons.lock_outline,
      );
      if (!ok) return;
      try {
        await _surveyService.closeSurvey(s.id);
        _showSnack('Survey closed', tone: _SnackTone.success);
      } catch (e) {
        _showSnack(
          _friendlyError(e, "Couldn't close the survey. Please try again."),
          tone: _SnackTone.danger,
        );
      }
      _load();
    } else if (value == 'delete') {
      final confirm = await showAdminConfirmDialog(
        context,
        title: 'Delete survey?',
        message:
            '${surveyIdentityText(s)}\n\n'
            'This cannot be undone. Surveys with submitted responses can’t be '
            'deleted — archive them instead.',
        confirmLabel: 'Delete',
        destructive: true,
        icon: Icons.delete_outline,
      );
      if (confirm) {
        try {
          await _surveyService.deleteSurvey(s.id);
          _showSnack('Survey deleted', tone: _SnackTone.success);
        } catch (e) {
          _showSnack(
            _friendlyError(
              e,
              "Couldn't delete the survey. Surveys with submitted responses "
              "can't be deleted — archive it instead.",
            ),
            tone: _SnackTone.danger,
          );
        }
        _load();
      }
    }
  }

  List<PopupMenuEntry<String>> _menuItemsFor(Survey s) {
    final live = s.status == SurveyStatus.published && !s.archived;
    final hasResponses = s.responseCount > 0;
    // Official CHED exports live under View responses (CSV / CHED Excel pack).
    final canExport =
        !s.isChedGtsBuiltin &&
        !s.isFromTemplate &&
        hasResponses &&
        canExportFiles;
    final exportsInResponses =
        (s.isChedGtsBuiltin || s.isFromTemplate) && hasResponses;
    return [
      surveyMenuItem(
        value: 'edit',
        label: 'Edit / publish',
        icon: Icons.edit_outlined,
      ),
      surveyMenuItem(
        value: 'responses',
        label: 'View responses',
        icon: Icons.insights_outlined,
      ),
      surveyMenuItem(
        value: 'duplicate',
        label: 'Duplicate',
        icon: Icons.content_copy_outlined,
      ),
      if (canExport) ...[
        const PopupMenuDivider(height: 8),
        surveyMenuItem(
          value: 'export',
          label: 'Export detailed CSV',
          icon: Icons.table_view_outlined,
        ),
        surveyMenuItem(
          value: 'export_pdf',
          label: 'Export PDF summary',
          icon: Icons.picture_as_pdf_outlined,
        ),
      ] else if (exportsInResponses) ...[
        const PopupMenuDivider(height: 8),
        surveyMenuItem(
          value: 'exports_hint',
          label: 'Exports: open View responses',
          icon: Icons.info_outline,
          enabled: false,
        ),
      ],
      if (live) ...[
        const PopupMenuDivider(height: 8),
        surveyMenuItem(
          value: 'share',
          label: 'Share link…',
          icon: Icons.share_outlined,
        ),
        surveyMenuItem(
          value: 'remind',
          label: 'Remind pending',
          icon: Icons.notifications_active_outlined,
        ),
        surveyMenuItem(
          value: 'reassign',
          label: 'Re-assign alumni',
          icon: Icons.group_add_outlined,
        ),
      ],
      const PopupMenuDivider(height: 8),
      if (live)
        surveyMenuItem(
          value: 'close',
          label: 'Close survey',
          icon: Icons.lock_outline,
          destructive: true,
        ),
      if (s.archived)
        surveyMenuItem(
          value: 'unarchive',
          label: 'Restore from archive',
          icon: Icons.unarchive_outlined,
        )
      else
        surveyMenuItem(
          value: 'archive',
          label: 'Archive',
          icon: Icons.archive_outlined,
        ),
      const PopupMenuDivider(height: 8),
      surveyMenuItem(
        value: 'delete',
        label: 'Delete',
        icon: Icons.delete_outline,
        destructive: true,
        enabled: !hasResponses,
        note: hasResponses ? 'Has responses — archive instead' : null,
      ),
    ];
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
        _SurveyStatusFilter.all => 'All',
      };
      chips.add(
        DirectoryActiveFilterChip(
          label: 'Status: $label',
          onRemoved: () =>
              setState(() => _statusFilter = _SurveyStatusFilter.all),
        ),
      );
    }
    if (_kindFilter != _SurveyKindFilter.all) {
      final label = switch (_kindFilter) {
        _SurveyKindFilter.officialChed => 'Official CHED',
        _SurveyKindFilter.chedPreset => 'CHED preset',
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
    return DirectoryKpiRow(
      children: [
        AdminKpiCard(
          dense: true,
          label: 'Draft',
          value: '$_draftCount',
          caption: 'Not yet published',
          icon: Icons.edit_note_outlined,
          palette: AdminAccents.orange,
          onTap: () =>
              setState(() => _statusFilter = _SurveyStatusFilter.draft),
        ),
        AdminKpiCard(
          dense: true,
          label: 'Published',
          value: '$_publishedCount',
          caption: 'Live, scheduled or window ended',
          icon: Icons.publish_outlined,
          palette: AdminAccents.gold,
          onTap: () =>
              setState(() => _statusFilter = _SurveyStatusFilter.published),
        ),
        AdminKpiCard(
          dense: true,
          label: 'Closed',
          value: '$_closedCount',
          caption: 'Ended waves',
          icon: Icons.lock_outline,
          palette: AdminAccents.midBlue,
          onTap: () =>
              setState(() => _statusFilter = _SurveyStatusFilter.closed),
        ),
        AdminKpiCard(
          dense: true,
          label: 'Responses',
          value: '$_responseTotal',
          caption: 'Submitted · all active surveys (CHED + custom)',
          icon: Icons.insights_outlined,
          palette: AdminAccents.blue,
        ),
      ],
    );
  }

  List<Widget> _filterControls() {
    return [
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
            value: _SurveyKindFilter.chedPreset,
            child: Text('CHED preset'),
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
      for (final f in _SurveyStatusFilter.values) _statusChip(f),
    ];
  }

  Widget _statusChip(_SurveyStatusFilter f) {
    final chip = DirectoryToolbarFilterChip(
      label: switch (f) {
        _SurveyStatusFilter.all => 'All',
        _SurveyStatusFilter.draft => 'Draft',
        _SurveyStatusFilter.published => 'Published',
        _SurveyStatusFilter.closed => 'Closed',
        _SurveyStatusFilter.archived => 'Archived ($_archivedCount)',
      },
      selected: _statusFilter == f,
      onSelected: (_) => setState(() => _statusFilter = f),
    );
    if (f != _SurveyStatusFilter.all) return chip;
    return Tooltip(message: 'All surveys except archived', child: chip);
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
      searchHint: 'Search title, description, kind…',
      singleRowMinWidth: 1000,
      // Single-row mode gives the filters an unbounded width.
      filters: LayoutBuilder(
        builder: (context, constraints) {
          final controls = _filterControls();
          if (constraints.maxWidth.isInfinite) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < controls.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  controls[i],
                ],
              ],
            );
          }
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: controls,
          );
        },
      ),
    );
  }

  Widget _buildRefreshErrorNotice() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AdminColors.warningBg,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        border: Border.all(color: AdminColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AdminColors.warning,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Couldn't refresh the list. Showing the last loaded surveys.",
              style: TextStyle(fontSize: 13, color: AdminColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _load,
            child: const Text('Try again'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurveyPageHeader(
          title: 'Surveys',
          subtitle: 'Official CHED GTS tracer waves and custom alumni surveys.',
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
        if (_hasLoaded && _loadError != null) ...[
          const SizedBox(height: AdminSurveyTheme.space1),
          _buildRefreshErrorNotice(),
        ],
        const SizedBox(height: AdminSurveyTheme.space1),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (!_hasLoaded && _loadError != null && !_isLoading) {
      return AdminStateView.error(
        title: "Couldn't load surveys",
        message: _loadError,
        details: _loadErrorDetails,
        onRetry: _load,
      );
    }
    final filtered = _filtered;
    return AdminInstantContent(
      loading: _isLoading,
      loadingSkeleton: const SurveyListSkeleton(),
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
            menuItems: _menuItemsFor(s),
            onMenuSelected: (value) => _onSurveyMenu(s, value),
            onOpen: () => _openResponses(s.id),
            busy: _busyIds.contains(s.id),
          );
        },
      ),
    );
  }
}

/// Title + description for a new blank survey; Create needs a title.
/// Pops with the trimmed (title, description).
class _BlankSurveyDialog extends StatefulWidget {
  const _BlankSurveyDialog();

  @override
  State<_BlankSurveyDialog> createState() => _BlankSurveyDialogState();
}

class _BlankSurveyDialogState extends State<_BlankSurveyDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  bool get _canCreate => _titleController.text.trim().isNotEmpty;

  void _submit() {
    if (!_canCreate) return;
    Navigator.of(
      context,
    ).pop((_titleController.text.trim(), _descController.text.trim()));
  }

  InputDecoration _decoration(String label, {String? helper}) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
      borderSide: BorderSide(
        color: AdminColors.textMuted.withValues(alpha: 0.6),
      ),
    );
    return AdminSurveyTheme.fieldDecoration(
      label: label,
      helper: helper,
    ).copyWith(
      fillColor: AdminColors.card,
      border: outline,
      enabledBorder: outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AdminColors.primaryTint,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
                child: const Icon(
                  Icons.edit_note_outlined,
                  size: 20,
                  color: AdminColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blank survey',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Creates a draft. You add questions in the editor next.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AdminColors.textMuted,
                ),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: _decoration('Title', helper: 'Required'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: _decoration('Description (optional)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: AdminButtonStyles.outlined(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _canCreate ? _submit : null,
                  style: AdminButtonStyles.filled(),
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
