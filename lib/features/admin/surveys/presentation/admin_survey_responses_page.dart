import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/core/services/ched_gts_export_service.dart';
import 'package:alumni_system/features/admin/surveys/presentation/admin_survey_editor_page.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_response_detail_sheet.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_response_timeline_sheet.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_analytics_panel.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_formal_report_dialog.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/data/survey_report_pack_service.dart';
import 'package:alumni_system/shared/widgets/admin/admin_skeletons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/shared/widgets/admin/admin_search_field.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/surveys/data/survey_single_response_export_service.dart';

class AdminSurveyResponsesScreen extends StatefulWidget {
  const AdminSurveyResponsesScreen({
    super.key,
    required this.surveyId,
    this.onClose,
  });

  final String surveyId;

  /// When set, responses are shown inline in the surveys panel (no route push).
  final VoidCallback? onClose;

  @override
  State<AdminSurveyResponsesScreen> createState() =>
      _AdminSurveyResponsesScreenState();
}

class _AdminSurveyResponsesScreenState extends State<AdminSurveyResponsesScreen>
    with SingleTickerProviderStateMixin {
  final _surveyService = SurveyService();
  final _searchController = TextEditingController();

  Survey? _survey;
  List<SurveyQuestion> _questions = [];
  List<SurveyParticipant> _participants = [];
  List<SurveyResponse> _responses = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = false;
  bool _isSendingReminders = false;
  bool _isExportingChed = false;
  String? _loadError;
  bool _loadErrorLooksOffline = false;
  late TabController _tabController;

  /// Pending workspace filters (UI-only; Phase 5).
  SurveyAssignmentStatus? _pendingStatusFilter;
  String? _pendingProgramFilter;
  String? _pendingBatchFilter;
  _PendingSort _pendingSort = _PendingSort.assignedNewest;
  _SubmittedSort _submittedSort = _SubmittedSort.newest;
  final _submittedSearchController = TextEditingController();
  int _pendingPage = 0;
  int _pendingPageSize = 25;
  int _submittedPage = 0;
  int _submittedPageSize = 25;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _submittedSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _loadErrorLooksOffline = false;
    });
    try {
      final survey = await _surveyService.getSurvey(widget.surveyId);
      final questions = await _surveyService.getQuestions(widget.surveyId);
      final participants = await _surveyService.getSurveyParticipants(
        widget.surveyId,
      );
      final responses = await _surveyService.getSurveyResponses(
        widget.surveyId,
      );
      if (!mounted) return;
      setState(() {
        _survey = survey;
        _questions = questions;
        _participants = participants;
        _responses = responses;
        _selectedUserIds.removeWhere(
          (id) => !participants.any(
            (p) => p.assignment.userId == id && p.isPending,
          ),
        );
        _isLoading = false;
        _loadError = null;
      });
      try {
        await _surveyService.markSurveyResponsesSeenByAdmin(widget.surveyId);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      final message = '$e';
      final offline = _looksLikeOfflineError(message);
      setState(() {
        _isLoading = false;
        _loadError = message;
        _loadErrorLooksOffline = offline;
      });
    }
  }

  bool _looksLikeOfflineError(String message) {
    final m = message.toLowerCase();
    return m.contains('socket') ||
        m.contains('network') ||
        m.contains('failed host') ||
        m.contains('connection') ||
        m.contains('offline') ||
        m.contains('timed out') ||
        m.contains('timeout');
  }

  List<SurveyParticipant> get _pending =>
      _surveyService.pendingParticipants(_participants);

  List<SurveyParticipant> get _submitted =>
      _participants.where((p) => !p.isPending).toList();

  List<SurveyParticipant> _filter(List<SurveyParticipant> list) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((p) {
      return p.displayName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          p.program.toLowerCase().contains(q) ||
          p.batchYear.toLowerCase().contains(q);
    }).toList();
  }

  List<SurveyParticipant> _pendingWorkspaceList() {
    var list = _filter(_pending);
    final status = _pendingStatusFilter;
    if (status != null) {
      list = list.where((p) => p.assignment.status == status).toList();
    }
    final program = _pendingProgramFilter;
    if (program != null) {
      list = list.where((p) => p.program == program).toList();
    }
    final batch = _pendingBatchFilter;
    if (batch != null) {
      list = list.where((p) => p.batchYear == batch).toList();
    }
    list = List<SurveyParticipant>.from(list);
    switch (_pendingSort) {
      case _PendingSort.assignedNewest:
        list.sort(
          (a, b) => b.assignment.assignedAt.compareTo(a.assignment.assignedAt),
        );
      case _PendingSort.assignedOldest:
        list.sort(
          (a, b) => a.assignment.assignedAt.compareTo(b.assignment.assignedAt),
        );
      case _PendingSort.nameAsc:
        list.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
      case _PendingSort.reminderRecent:
        list.sort((a, b) {
          final aAt = a.assignment.lastReminderAt;
          final bAt = b.assignment.lastReminderAt;
          if (aAt == null && bAt == null) {
            return b.assignment.reminderCount.compareTo(
              a.assignment.reminderCount,
            );
          }
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return bAt.compareTo(aAt);
        });
      case _PendingSort.reminderCountDesc:
        list.sort(
          (a, b) =>
              b.assignment.reminderCount.compareTo(a.assignment.reminderCount),
        );
    }
    return list;
  }

  Set<String> get _pendingProgramOptions =>
      _pending.map((p) => p.program).where((p) => p.trim().isNotEmpty).toSet();

  Set<String> get _pendingBatchOptions => _pending
      .map((p) => p.batchYear)
      .where((b) => b.trim().isNotEmpty)
      .toSet();

  void _exportPendingSelectedCsv(List<SurveyParticipant> visible) {
    if (!requireWebExport(context)) return;
    final selected = visible
        .where((p) => _selectedUserIds.contains(p.assignment.userId))
        .toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select pending alumni to export')),
      );
      return;
    }
    final buf = StringBuffer();
    buf.writeln(
      'name,email,program,batch,status,assigned_at,last_reminder_at,reminder_count',
    );
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    for (final p in selected) {
      final a = p.assignment;
      buf.writeln(
        [
          esc(p.displayName),
          esc(p.email),
          esc(p.program),
          esc(p.batchYear),
          a.status.name,
          a.assignedAt.toIso8601String(),
          a.lastReminderAt?.toIso8601String() ?? '',
          '${a.reminderCount}',
        ].join(','),
      );
    }
    final bytes = Uint8List.fromList(utf8.encode(buf.toString()));
    final title = (_survey?.title ?? 'survey')
        .replaceAll(RegExp(r'[^\w\-]+'), '_')
        .toLowerCase();
    tryDownloadBytesOnWeb(
      context,
      bytes: bytes,
      fileName: '${title}_pending_selected.csv',
      mimeType: 'text/csv',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${selected.length} pending alumni'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _sendReminders({
    required bool inApp,
    required bool email,
  }) async {
    final targets = _selectedUserIds.isEmpty
        ? _pending.map((p) => p.assignment.userId).toList()
        : _selectedUserIds.toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending alumni selected')),
      );
      return;
    }

    final channels = <String>[
      if (inApp) 'in-app',
      if (email) 'email',
    ].join(' + ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Send reminders?'),
        content: Text(
          'Send $channels reminders to ${targets.length} pending alumni?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    if (email && !EmailDeliveryConfig.isConfigured) {
      if (!inApp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email reminders are not configured. Check Gmail SMTP / '
              'Supabase secrets or use In-app.',
            ),
          ),
        );
        return;
      }
      email = false;
    }

    setState(() => _isSendingReminders = true);
    try {
      final result = await _surveyService.sendReminders(
        surveyId: widget.surveyId,
        userIds: targets,
        inApp: inApp,
        email: email,
      );
      if (!mounted) return;
      final parts = <String>[];
      if (inApp) parts.add('${result.inAppSent} in-app');
      if (email) parts.add('${result.emailSent} email');
      if (result.emailSkippedNoAddress > 0) {
        parts.add('${result.emailSkippedNoAddress} skipped (no email)');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty ? 'No reminders sent' : 'Sent: ${parts.join(', ')}',
          ),
          backgroundColor: result.failures.isEmpty
              ? Colors.green
              : Colors.orange,
        ),
      );
      if (result.failures.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Some reminders failed'),
            content: SingleChildScrollView(
              child: Text(result.failures.join('\n')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReminders = false);
    }
  }

  void _exportCsv() {
    if (!requireWebExport(context)) return;
    if (_survey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Survey not loaded yet')));
      return;
    }
    if (_submitted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submitted responses to export')),
      );
      return;
    }
    try {
      final csv = _surveyService.buildResponsesCsv(
        survey: _survey!,
        questions: _questions,
        participants: _participants,
      );
      // UTF-8 BOM so Excel opens columns correctly on Windows.
      final bytes = utf8.encode('\uFEFF$csv');
      final ok = tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName:
            'survey_${_survey!.title.replaceAll(RegExp(r'[^\w\-]+'), '_')}_responses.csv',
        mimeType: 'text/csv;charset=utf-8',
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Responses CSV downloaded'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportManagementPack({required String format}) async {
    if (!requireWebExport(context)) return;
    if (_survey == null) return;
    setState(() => _isExportingChed = true);
    try {
      final pack = SurveyReportPackService.buildSurveyPack(
        survey: _survey!,
        participants: _participants,
        questions: _questions,
        responses: _responses,
      );
      final safe = _survey!.title.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
      late final Uint8List bytes;
      late final String fileName;
      late final String mime;
      switch (format) {
        case 'pdf':
          bytes = await SurveyReportPackService.toPdf(pack);
          fileName = 'survey_${safe}_report_pack_$stamp.pdf';
          mime = 'application/pdf';
        case 'xlsx':
          bytes = SurveyReportPackService.toExcel(pack);
          fileName = 'survey_${safe}_report_pack_$stamp.xlsx';
          mime =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        default:
          bytes = Uint8List.fromList(
            utf8.encode('\uFEFF${SurveyReportPackService.toCsv(pack)}'),
          );
          fileName = 'survey_${safe}_report_pack_$stamp.csv';
          mime = 'text/csv;charset=utf-8';
      }
      if (!mounted) return;
      tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName: fileName,
        mimeType: mime,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Management report downloaded'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingChed = false);
    }
  }

  Future<void> _exportChedGtsExcel() async {
    if (!requireWebExport(context)) return;
    if (_survey == null || _submitted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submitted responses to export')),
      );
      return;
    }

    setState(() => _isExportingChed = true);
    try {
      final bytes = await ChedGtsExportService().buildExcelBytes(
        survey: _survey!,
        questions: _questions,
        participants: _participants,
      );
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nothing to export')));
        return;
      }
      final slug = _survey!.title.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
        fileName: 'ched_gts_${slug}_$date.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CHED GTS Excel export downloaded'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingChed = false);
    }
  }

  List<PopupMenuEntry<String>> _overflowMenuItems() {
    return [
      const PopupMenuItem(
        value: 'refresh',
        child: _ExportMenuRow(icon: Icons.refresh, title: 'Refresh'),
      ),
      if (_survey != null)
        const PopupMenuItem(
          value: 'formal_report',
          child: _ExportMenuRow(
            icon: Icons.auto_awesome,
            title: 'Generate formal report',
            subtitle: 'AI draft — review before official use',
          ),
        ),
      if (canExportFiles && _survey != null) ...[
        const PopupMenuDivider(),
        if (_submitted.isNotEmpty)
          const PopupMenuItem(
            value: 'ched',
            child: _ExportMenuRow(
              icon: Icons.table_chart_outlined,
              title: 'CHED GTS Excel pack',
              subtitle: 'Tracer A/B + employment + survey C/D sheets',
            ),
          ),
        if (_submitted.isNotEmpty)
          const PopupMenuItem(
            value: 'csv',
            child: _ExportMenuRow(
              icon: Icons.description_outlined,
              title: 'Responses CSV',
            ),
          ),
        const PopupMenuItem(
          value: 'pack_pdf',
          child: _ExportMenuRow(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Management report PDF',
            subtitle: 'Executive + participation + insights pack',
          ),
        ),
        const PopupMenuItem(
          value: 'pack_xlsx',
          child: _ExportMenuRow(
            icon: Icons.grid_on_outlined,
            title: 'Management report Excel',
          ),
        ),
        const PopupMenuItem(
          value: 'pack_csv',
          child: _ExportMenuRow(
            icon: Icons.summarize_outlined,
            title: 'Management report CSV',
          ),
        ),
      ],
    ];
  }

  void _onOverflowSelected(String value) {
    switch (value) {
      case 'refresh':
        _load();
        break;
      case 'formal_report':
        _openFormalReport();
        break;
      case 'csv':
        _exportCsv();
        break;
      case 'ched':
        _exportChedGtsExcel();
        break;
      case 'pack_pdf':
        _exportManagementPack(format: 'pdf');
        break;
      case 'pack_xlsx':
        _exportManagementPack(format: 'xlsx');
        break;
      case 'pack_csv':
        _exportManagementPack(format: 'csv');
        break;
    }
  }

  void _openFormalReport() {
    final survey = _survey;
    if (survey == null) return;
    showAdminSurveyFormalReportDialog(
      context,
      survey: survey,
      questions: _questions,
      participants: _participants,
      responses: _responses,
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = _submitted.length;
    final pending = _pending.length;
    final assigned = _participants.length;
    final rate = assigned == 0 ? 0.0 : (completed / assigned) * 100;
    final title = _survey?.title ?? 'Survey responses';
    final embedded = widget.onClose != null;

    final workspaceTabs = <SurveyWorkspaceTabSpec>[
      const SurveyWorkspaceTabSpec(
        id: 'overview',
        label: 'Overview',
        icon: Icons.insights_outlined,
      ),
      SurveyWorkspaceTabSpec(
        id: 'pending',
        label: 'Pending',
        icon: Icons.schedule_outlined,
        count: pending,
      ),
      SurveyWorkspaceTabSpec(
        id: 'submitted',
        label: 'Submitted',
        icon: Icons.task_alt_outlined,
        count: completed,
      ),
    ];

    final segmentNav = SurveyWorkspaceSegmentedNav(
      tabs: workspaceTabs,
      controller: _tabController,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (embedded)
          SurveyResponsesWorkspaceHeader(
            survey: _survey,
            onBack: widget.onClose!,
            overflowBusy: _isExportingChed,
            overflowItems: _overflowMenuItems(),
            onOverflowSelected: _onOverflowSelected,
          ),
        segmentNav,
        if (_isLoading && _survey != null)
          const LinearProgressIndicator(
            minHeight: 2,
            color: AdminSurveyTheme.primary,
            backgroundColor: AdminSurveyTheme.infoBg,
          ),
        Expanded(
          child: _buildWorkspaceBody(
            assigned: assigned,
            completed: completed,
            pending: pending,
            rate: rate,
          ),
        ),
      ],
    );

    if (embedded) {
      return _withWorkspaceShortcuts(
        ColoredBox(color: AdminSurveyTheme.background, child: body),
      );
    }

    return _withWorkspaceShortcuts(
      Scaffold(
        backgroundColor: AdminSurveyTheme.background,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AdminSurveyTheme.primary,
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton<String>(
              enabled: !_isExportingChed,
              tooltip: 'More actions',
              icon: _isExportingChed
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.more_vert),
              itemBuilder: (_) => _overflowMenuItems(),
              onSelected: _onOverflowSelected,
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _withWorkspaceShortcuts(Widget child) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _goToWorkspaceTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _goToWorkspaceTab(1),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _goToWorkspaceTab(2),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goToWorkspaceTab(_tabController.index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goToWorkspaceTab(_tabController.index + 1),
        const SingleActivator(LogicalKeyboardKey.escape): _clearWorkspaceSearch,
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  void _clearWorkspaceSearch() {
    final hadPending = _searchController.text.isNotEmpty;
    final hadSubmitted = _submittedSearchController.text.isNotEmpty;
    if (!hadPending && !hadSubmitted) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    _searchController.clear();
    _submittedSearchController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  void _goToWorkspaceTab(int index) {
    if (index < 0 || index >= _tabController.length) return;
    if (index == _tabController.index) return;
    _tabController.animateTo(index);
    setState(() {});
  }

  Widget _buildWorkspaceBody({
    required int assigned,
    required int completed,
    required int pending,
    required double rate,
  }) {
    if (_isLoading && _survey == null) {
      final tab = _tabController.index;
      if (tab == 1 || tab == 2) {
        return const SurveyResponsesWorkspaceSkeleton.list();
      }
      return const SurveyResponsesWorkspaceSkeleton.overview();
    }

    if (_loadError != null && _survey == null) {
      return SurveyEmptyState(
        title: _loadErrorLooksOffline
            ? 'You appear to be offline'
            : 'Couldn’t load responses',
        subtitle: _loadErrorLooksOffline
            ? 'Check your internet connection, then try again.'
            : _loadError!,
        icon: _loadErrorLooksOffline
            ? Icons.wifi_off_outlined
            : Icons.error_outline,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loadError != null && _survey != null)
          Material(
            color: AdminSurveyTheme.warningBg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _loadErrorLooksOffline
                        ? Icons.wifi_off_outlined
                        : Icons.error_outline,
                    size: 18,
                    color: AdminSurveyTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loadErrorLooksOffline
                          ? 'Refresh failed — you may be offline. Showing last loaded data.'
                          : 'Refresh failed. Showing last loaded data.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminSurveyTheme.warning,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverview(assigned, completed, pending, rate),
              _buildPendingTab(),
              _buildSubmittedTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(int assigned, int completed, int pending, double rate) {
    final survey = _survey;
    final dateFmt = DateFormat.yMMMd().add_jm();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final left = _overviewLeftColumn(
          survey: survey,
          assigned: assigned,
          completed: completed,
          dateFmt: dateFmt,
        );
        final right = survey == null
            ? const Center(
                child: Text(
                  'Survey details unavailable.',
                  style: TextStyle(color: AdminSurveyTheme.textMuted),
                ),
              )
            : AdminSurveyAnalyticsPanel(
                survey: survey,
                participants: _participants,
                questions: _questions,
                responses: _responses,
              );

        if (!wide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            children: [
              left,
              const SizedBox(height: 12),
              SizedBox(
                height: math.max(420, constraints.maxHeight * 0.7),
                child: right,
              ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: _overviewPane(child: left),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: _overviewPane(child: right),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _overviewPane({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AdminSurveyTheme.card,
        borderRadius: BorderRadius.circular(AdminSurveyTheme.radiusLg),
        border: Border.all(color: AdminSurveyTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(10),
      child: child,
    );
  }

  Widget _overviewLeftColumn({
    required Survey? survey,
    required int assigned,
    required int completed,
    required DateFormat dateFmt,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurveySectionCard(
            title: 'Quick actions',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (survey != null) ...[
                  _quickActionChip(
                    icon: survey.status == SurveyStatus.published
                        ? Icons.lock_outline
                        : Icons.publish_outlined,
                    label: survey.status == SurveyStatus.draft
                        ? 'Publish'
                        : survey.status == SurveyStatus.published
                        ? 'Close survey'
                        : 'Re-publish',
                    primary: true,
                    onPressed: _isBusyQuickAction
                        ? null
                        : () => _overviewPublishToggle(survey),
                  ),
                  _quickActionChip(
                    icon: Icons.edit_outlined,
                    label: 'View survey',
                    onPressed: () =>
                        showAdminSurveyEditorDialog(
                          context,
                          surveyId: survey.id,
                        ).then((_) {
                          if (mounted) _load();
                        }),
                  ),
                  _quickActionChip(
                    icon: Icons.copy_outlined,
                    label: 'Duplicate survey',
                    onPressed: _isBusyQuickAction ? null : _overviewDuplicate,
                  ),
                ],
                _quickActionChip(
                  icon: Icons.download_outlined,
                  label: 'Export responses',
                  onPressed: !canExportFiles || completed == 0
                      ? null
                      : _showExportPicker,
                ),
                if (survey != null)
                  _quickActionChip(
                    icon: Icons.auto_awesome,
                    label: 'Generate formal report',
                    onPressed: _openFormalReport,
                  ),
                _quickActionChip(
                  icon: Icons.history_outlined,
                  label: 'Reminder history',
                  onPressed: _showReminderHistorySheet,
                ),
              ],
            ),
          ),
          if (survey != null) ...[
            const SizedBox(height: 10),
            SurveySectionCard(
              title: 'Survey information',
              child: Column(
                children: [
                  _infoRow('Survey type', _surveyTypeLabel(survey)),
                  _infoRow(
                    'Status',
                    survey.archived ? 'Archived' : survey.status.name,
                  ),
                  _infoRow(
                    'Created by',
                    survey.createdByLabel.trim().isEmpty
                        ? '—'
                        : survey.createdByLabel,
                  ),
                  _infoRow('Created date', dateFmt.format(survey.createdAt)),
                  _infoRow(
                    'Publish date',
                    survey.status == SurveyStatus.draft
                        ? 'Not published'
                        : SurveyResponsesWorkspaceHeader.publishedAtOf(
                                survey,
                              ) ==
                              null
                        ? '—'
                        : dateFmt.format(
                            SurveyResponsesWorkspaceHeader.publishedAtOf(
                              survey,
                            )!,
                          ),
                  ),
                  _infoRow(
                    'Last updated',
                    survey.updatedAt == null
                        ? '—'
                        : dateFmt.format(survey.updatedAt!),
                  ),
                  _infoRow('Target audience', _audienceLabel(survey)),
                  _infoRow('Assigned alumni', '$assigned'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _isBusyQuickAction => _isSendingReminders || _isExportingChed;

  String _surveyTypeLabel(Survey survey) {
    if (survey.isChedGtsBuiltin) return 'Official CHED GTS';
    if (survey.isFromTemplate) return 'CHED preset / template';
    return 'Custom survey';
  }

  String _audienceLabel(Survey survey) {
    final programs = survey.targetPrograms;
    final batches = survey.targetBatchYears;
    if (programs.isEmpty && batches.isEmpty) {
      return 'All alumni';
    }
    final parts = <String>[];
    if (programs.isNotEmpty) {
      parts.add(programs.join(', '));
    }
    if (batches.isNotEmpty) {
      parts.add('Batches ${batches.join(', ')}');
    }
    return parts.join(' · ');
  }

  Widget _infoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminSurveyTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminSurveyTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _quickActionChip({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
  }) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: surveyFilledButtonStyle(),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: surveyOutlinedButtonStyle(),
    );
  }

  Future<void> _overviewPublishToggle(Survey survey) async {
    try {
      if (survey.status == SurveyStatus.draft ||
          survey.status == SurveyStatus.closed) {
        final count = await _surveyService.publishSurvey(
          survey.id,
          notify: survey.status == SurveyStatus.draft,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              survey.status == SurveyStatus.draft
                  ? 'Published · $count alumni assigned'
                  : 'Re-published · $count alumni assigned',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (survey.status == SurveyStatus.published) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Close survey?'),
            content: const Text(
              'Alumni will no longer be able to submit new responses.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Close survey'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        await _surveyService.closeSurvey(survey.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Survey closed')));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _overviewDuplicate() async {
    try {
      final id = await _surveyService.duplicateSurvey(widget.surveyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey duplicated as draft'),
          backgroundColor: Colors.green,
        ),
      );
      await showAdminSurveyEditorDialog(context, surveyId: id);
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showExportPicker() async {
    final choice = await showAdminOptionPicker<String>(
      context: context,
      title: 'Export responses',
      options: const [
        AdminPickerOption(
          value: 'ched',
          label: 'CHED GTS Excel pack',
          icon: Icons.table_chart_outlined,
        ),
        AdminPickerOption(
          value: 'csv',
          label: 'Responses CSV',
          icon: Icons.description_outlined,
        ),
        AdminPickerOption(
          value: 'pack_pdf',
          label: 'Management report PDF',
          icon: Icons.picture_as_pdf_outlined,
        ),
        AdminPickerOption(
          value: 'pack_xlsx',
          label: 'Management report Excel',
          icon: Icons.grid_on_outlined,
        ),
      ],
    );
    if (choice == null || !mounted) return;
    _onOverflowSelected(choice);
  }

  void _showReminderHistorySheet() {
    final withReminders =
        _participants.where((p) => p.assignment.reminderCount > 0).toList()
          ..sort(
            (a, b) => (b.assignment.lastReminderAt ?? b.assignment.assignedAt)
                .compareTo(
                  a.assignment.lastReminderAt ?? a.assignment.assignedAt,
                ),
          );
    final totalReminders = _participants.fold<int>(
      0,
      (sum, p) => sum + p.assignment.reminderCount,
    );

    Widget header() => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reminder history',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalReminders reminder(s) across '
            '${withReminders.length} alumni '
            '(from assignment records).',
            style: const TextStyle(
              fontSize: 13,
              color: AdminSurveyTheme.textSecondary,
            ),
          ),
        ],
      ),
    );

    Widget list({ScrollController? controller}) => withReminders.isEmpty
        ? const SurveyEmptyState(
            title: 'No reminders sent yet',
            subtitle:
                'When you send in-app or email reminders, '
                'counts appear here.',
            icon: Icons.notifications_none_outlined,
          )
        : ListView.builder(
            controller: controller,
            itemCount: withReminders.length,
            itemBuilder: (context, index) {
              final p = withReminders[index];
              final a = p.assignment;
              final last = a.lastReminderAt;
              return ListTile(
                title: Text(p.displayName),
                subtitle: Text(
                  '${a.reminderCount} reminder(s)'
                  '${last == null ? '' : ' · last ${DateFormat.yMMMd().add_jm().format(last)}'}',
                ),
                trailing: Text(
                  p.isPending ? 'Pending' : 'Submitted',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.isPending
                        ? AdminSurveyTheme.warning
                        : AdminSurveyTheme.success,
                  ),
                ),
              );
            },
          );

    if (adminIsWideSurface(context)) {
      showAdminSidePanel<void>(
        context: context,
        width: 460,
        backgroundColor: AdminSurveyTheme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: header()),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(child: list()),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header(),
                const Divider(height: 1),
                Expanded(child: list(controller: scrollController)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPendingTab() {
    final allPending = _pending;
    final list = _pendingWorkspaceList();
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final hasFilters =
        _pendingStatusFilter != null ||
        _pendingProgramFilter != null ||
        _pendingBatchFilter != null;
    final safePage = adminClampPage(
      _pendingPage,
      list.length,
      _pendingPageSize,
    );
    final pageList = adminPaginate(list, safePage, _pendingPageSize);
    final selectedOnPage = pageList
        .where((p) => _selectedUserIds.contains(p.assignment.userId))
        .length;
    final allVisibleSelected =
        pageList.isNotEmpty && selectedOnPage == pageList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSearchField(
                controller: _searchController,
                onDebouncedChanged: (_) => setState(() => _pendingPage = 0),
                hintText: 'Name, email, course, or batch…',
                decoration: AdminSurveyTheme.toolbarFieldDecoration(
                  hint: 'Name, email, course, or batch…',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AdminSurveyTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pendingFilterChip(
                    label: _pendingStatusFilter == null
                        ? 'Status'
                        : _statusLabel(_pendingStatusFilter!),
                    selected: _pendingStatusFilter != null,
                    onTap: _pickPendingStatusFilter,
                  ),
                  _pendingFilterChip(
                    label: _pendingProgramFilter ?? 'Course',
                    selected: _pendingProgramFilter != null,
                    onTap: _pickPendingProgramFilter,
                  ),
                  _pendingFilterChip(
                    label: _pendingBatchFilter == null
                        ? 'Batch'
                        : 'Batch $_pendingBatchFilter',
                    selected: _pendingBatchFilter != null,
                    onTap: _pickPendingBatchFilter,
                  ),
                  PopupMenuButton<_PendingSort>(
                    tooltip: 'Sort',
                    initialValue: _pendingSort,
                    onSelected: (v) => setState(() {
                      _pendingSort = v;
                      _pendingPage = 0;
                    }),
                    itemBuilder: (context) => [
                      for (final s in _PendingSort.values)
                        PopupMenuItem(value: s, child: Text(s.label)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.sort, size: 16),
                      label: Text(_pendingSort.label),
                      backgroundColor: AdminSurveyTheme.surface,
                      side: const BorderSide(color: AdminSurveyTheme.border),
                    ),
                  ),
                  if (hasFilters)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _pendingStatusFilter = null;
                          _pendingProgramFilter = null;
                          _pendingBatchFilter = null;
                          _pendingPage = 0;
                        });
                      },
                      child: const Text('Clear filters'),
                    ),
                  TextButton.icon(
                    onPressed: pageList.isEmpty
                        ? null
                        : () {
                            setState(() {
                              if (allVisibleSelected) {
                                for (final p in pageList) {
                                  _selectedUserIds.remove(p.assignment.userId);
                                }
                              } else {
                                _selectedUserIds.addAll(
                                  pageList.map((p) => p.assignment.userId),
                                );
                              }
                            });
                          },
                    icon: Icon(
                      allVisibleSelected
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    label: Text(
                      allVisibleSelected
                          ? 'Clear page selection'
                          : 'Select page',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_selectedUserIds.isNotEmpty)
          Material(
            color: AdminSurveyTheme.infoBg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_selectedUserIds.length} selected',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AdminSurveyTheme.primary,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _isSendingReminders
                        ? null
                        : () => _sendReminders(inApp: true, email: true),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Send reminder'),
                    style: surveyFilledButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSendingReminders
                        ? null
                        : () => _sendReminders(inApp: false, email: true),
                    icon: const Icon(Icons.email_outlined, size: 16),
                    label: const Text('Send email'),
                    style: surveyOutlinedButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSendingReminders
                        ? null
                        : () => _sendReminders(inApp: true, email: false),
                    icon: const Icon(Icons.notifications_outlined, size: 16),
                    label: const Text('Notify in-app'),
                    style: surveyOutlinedButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportPendingSelectedCsv(list),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Export selected'),
                    style: surveyOutlinedButtonStyle(),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Text(
            allPending.isEmpty
                ? 'No pending assignments'
                : 'Showing ${list.length} of ${allPending.length} pending',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminSurveyTheme.textMuted,
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? SurveyEmptyState(
                  title: allPending.isEmpty
                      ? 'No pending alumni'
                      : hasQuery || hasFilters
                      ? 'No matching alumni'
                      : 'No pending alumni',
                  subtitle: allPending.isEmpty
                      ? 'Everyone assigned to this survey has submitted. Great work.'
                      : hasQuery || hasFilters
                      ? 'Try clearing search or filters to see more pending alumni.'
                      : 'Everyone assigned to this survey has submitted.',
                  icon: allPending.isEmpty
                      ? Icons.celebration_outlined
                      : Icons.search_off_outlined,
                  actionLabel: (hasQuery || hasFilters) && allPending.isNotEmpty
                      ? 'Clear search & filters'
                      : null,
                  onAction: (hasQuery || hasFilters) && allPending.isNotEmpty
                      ? () {
                          setState(() {
                            _searchController.clear();
                            _pendingStatusFilter = null;
                            _pendingProgramFilter = null;
                            _pendingBatchFilter = null;
                            _pendingPage = 0;
                          });
                        }
                      : null,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AdminDataTable(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        columns: _pendingTableColumns,
                        leadingHeader: Checkbox(
                          value: allVisibleSelected
                              ? true
                              : (selectedOnPage > 0 ? null : false),
                          tristate: true,
                          onChanged: pageList.isEmpty
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedUserIds.addAll(
                                        pageList.map(
                                          (p) => p.assignment.userId,
                                        ),
                                      );
                                    } else {
                                      for (final p in pageList) {
                                        _selectedUserIds.remove(
                                          p.assignment.userId,
                                        );
                                      }
                                    }
                                  });
                                },
                        ),
                        leadingWidth: 48,
                        rowCount: pageList.length,
                        rowBuilder: (context, index) {
                          final p = pageList[index];
                          return _PendingAlumniCard(
                            participant: p,
                            selected: _selectedUserIds.contains(
                              p.assignment.userId,
                            ),
                            onSelected: (v) {
                              setState(() {
                                if (v) {
                                  _selectedUserIds.add(p.assignment.userId);
                                } else {
                                  _selectedUserIds.remove(p.assignment.userId);
                                }
                              });
                            },
                            statusLabel: _statusLabel(p.assignment.status),
                          );
                        },
                      ),
                    ),
                    AdminPaginationBar(
                      totalItems: list.length,
                      page: safePage,
                      pageSize: _pendingPageSize,
                      onPageChanged: (p) => setState(() => _pendingPage = p),
                      onPageSizeChanged: (s) => setState(() {
                        _pendingPageSize = s;
                        _pendingPage = 0;
                      }),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _pendingFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AdminSurveyTheme.infoBg,
      checkmarkColor: AdminSurveyTheme.primary,
      side: BorderSide(
        color: selected
            ? AdminSurveyTheme.primary.withValues(alpha: 0.35)
            : AdminSurveyTheme.border,
      ),
    );
  }

  Future<void> _pickPendingStatusFilter() async {
    final value = await showAdminOptionPicker<Object>(
      context: context,
      title: 'Filter by status',
      options: [
        AdminPickerOption(
          value: '__clear__',
          label: 'All statuses',
          selected: _pendingStatusFilter == null,
        ),
        AdminPickerOption(
          value: SurveyAssignmentStatus.notStarted,
          label: _statusLabel(SurveyAssignmentStatus.notStarted),
          selected: _pendingStatusFilter == SurveyAssignmentStatus.notStarted,
        ),
        AdminPickerOption(
          value: SurveyAssignmentStatus.inProgress,
          label: _statusLabel(SurveyAssignmentStatus.inProgress),
          selected: _pendingStatusFilter == SurveyAssignmentStatus.inProgress,
        ),
      ],
    );
    if (!mounted || value == null) return;
    setState(() {
      _pendingPage = 0;
      if (value == '__clear__') {
        _pendingStatusFilter = null;
      } else if (value is SurveyAssignmentStatus) {
        _pendingStatusFilter = value;
      }
    });
  }

  Future<void> _pickPendingProgramFilter() async {
    final options = _pendingProgramOptions.toList()..sort();
    final value = await showAdminOptionPicker<String>(
      context: context,
      title: 'Filter by course',
      options: [
        AdminPickerOption(
          value: '',
          label: 'All courses',
          selected: _pendingProgramFilter == null,
        ),
        for (final p in options)
          AdminPickerOption(
            value: p,
            label: p,
            selected: _pendingProgramFilter == p,
          ),
      ],
    );
    if (!mounted || value == null) return;
    setState(() {
      _pendingPage = 0;
      _pendingProgramFilter = value.isEmpty ? null : value;
    });
  }

  Future<void> _pickPendingBatchFilter() async {
    final options = _pendingBatchOptions.toList()..sort();
    final value = await showAdminOptionPicker<String>(
      context: context,
      title: 'Filter by batch',
      options: [
        AdminPickerOption(
          value: '',
          label: 'All batches',
          selected: _pendingBatchFilter == null,
        ),
        for (final b in options)
          AdminPickerOption(
            value: b,
            label: b,
            selected: _pendingBatchFilter == b,
          ),
      ],
    );
    if (!mounted || value == null) return;
    setState(() {
      _pendingPage = 0;
      _pendingBatchFilter = value.isEmpty ? null : value;
    });
  }

  Widget _buildSubmittedTab() {
    final allSubmitted = _submitted;
    final list = _submittedWorkspaceList();
    final hasQuery = _submittedSearchController.text.trim().isNotEmpty;
    final safePage = adminClampPage(
      _submittedPage,
      list.length,
      _submittedPageSize,
    );
    final pageList = adminPaginate(list, safePage, _submittedPageSize);
    final isChedBuiltin =
        _survey?.isChedGtsBuiltin == true ||
        allSubmitted.any(
          (p) =>
              p.response?.answers.keys.any(
                (k) => k.toString().startsWith('ched_'),
              ) ==
              true,
        );
    final versionLabel = _surveyVersionLabel(_survey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSearchField(
                controller: _submittedSearchController,
                onDebouncedChanged: (_) => setState(() => _submittedPage = 0),
                hintText: 'Name, email, course, or batch…',
                decoration: AdminSurveyTheme.toolbarFieldDecoration(
                  hint: 'Name, email, course, or batch…',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: AdminSurveyTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PopupMenuButton<_SubmittedSort>(
                    tooltip: 'Sort',
                    initialValue: _submittedSort,
                    onSelected: (v) => setState(() {
                      _submittedSort = v;
                      _submittedPage = 0;
                    }),
                    itemBuilder: (context) => [
                      for (final s in _SubmittedSort.values)
                        PopupMenuItem(value: s, child: Text(s.label)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.sort, size: 16),
                      label: Text(_submittedSort.label),
                      backgroundColor: AdminSurveyTheme.surface,
                      side: const BorderSide(color: AdminSurveyTheme.border),
                    ),
                  ),
                  Text(
                    allSubmitted.isEmpty
                        ? 'No submissions'
                        : 'Showing ${list.length} of ${allSubmitted.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AdminSurveyTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? SurveyEmptyState(
                  title: allSubmitted.isEmpty
                      ? 'No submissions yet'
                      : 'No matching submissions',
                  subtitle: allSubmitted.isEmpty
                      ? 'Submitted responses will appear here as alumni complete the survey.'
                      : 'Try a different search to find a submitted response.',
                  icon: allSubmitted.isEmpty
                      ? Icons.inbox_outlined
                      : Icons.search_off_outlined,
                  actionLabel: hasQuery && allSubmitted.isNotEmpty
                      ? 'Clear search'
                      : null,
                  onAction: hasQuery && allSubmitted.isNotEmpty
                      ? () {
                          _submittedSearchController.clear();
                          setState(() => _submittedPage = 0);
                        }
                      : null,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AdminDataTable(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        columns: _submittedTableColumns,
                        trailingHeader: const SizedBox.shrink(),
                        trailingWidth: 44,
                        rowCount: pageList.length,
                        rowBuilder: (context, index) {
                          final p = pageList[index];
                          final r = p.response!;
                          return _SubmittedResponseCard(
                            participant: p,
                            response: r,
                            surveyVersionLabel: versionLabel,
                            onViewResponse: () => _openSubmittedResponseDetail(
                              participant: p,
                              isChedBuiltin: isChedBuiltin,
                            ),
                            onAction: (action) => _onSubmittedCardAction(
                              action: action,
                              participant: p,
                              isChedBuiltin: isChedBuiltin,
                            ),
                          );
                        },
                      ),
                    ),
                    AdminPaginationBar(
                      totalItems: list.length,
                      page: safePage,
                      pageSize: _submittedPageSize,
                      onPageChanged: (p) => setState(() => _submittedPage = p),
                      onPageSizeChanged: (s) => setState(() {
                        _submittedPageSize = s;
                        _submittedPage = 0;
                      }),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  List<SurveyParticipant> _submittedWorkspaceList() {
    final q = _submittedSearchController.text.trim().toLowerCase();
    var list = _submitted;
    if (q.isNotEmpty) {
      list = list.where((p) {
        return p.displayName.toLowerCase().contains(q) ||
            p.email.toLowerCase().contains(q) ||
            p.program.toLowerCase().contains(q) ||
            p.batchYear.toLowerCase().contains(q);
      }).toList();
    }
    list = List<SurveyParticipant>.from(list);
    switch (_submittedSort) {
      case _SubmittedSort.newest:
        list.sort((a, b) {
          final aAt = a.response?.submittedAt ?? a.response?.updatedAt;
          final bAt = b.response?.submittedAt ?? b.response?.updatedAt;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return bAt.compareTo(aAt);
        });
      case _SubmittedSort.oldest:
        list.sort((a, b) {
          final aAt = a.response?.submittedAt ?? a.response?.updatedAt;
          final bAt = b.response?.submittedAt ?? b.response?.updatedAt;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return aAt.compareTo(bAt);
        });
      case _SubmittedSort.nameAsc:
        list.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
    }
    return list;
  }

  String _surveyVersionLabel(Survey? survey) {
    if (survey == null) return '—';
    if (survey.isChedGtsBuiltin) {
      final v = survey.schemaVersion?.trim();
      return (v == null || v.isEmpty) ? 'CHED GTS' : 'CHED GTS · $v';
    }
    final template = survey.templateVersion?.trim();
    if (template != null && template.isNotEmpty) {
      return 'Template v$template';
    }
    final schema = survey.schemaVersion?.trim();
    if (schema != null && schema.isNotEmpty) return schema;
    return 'Current';
  }

  Future<void> _exportSubmittedResponse({
    required SurveyParticipant participant,
    required String action,
  }) async {
    final survey = _survey;
    final response = participant.response;
    if (survey == null || response == null) return;

    try {
      if (action == 'pdf') {
        if (!requireWebExport(context)) return;
        final bytes = await SurveySingleResponseExportService.toPdf(
          survey: survey,
          response: response,
          questions: _questions,
          participant: participant,
        );
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName:
              '${SurveySingleResponseExportService.fileBaseName(participant)}.pdf',
          mimeType: 'application/pdf',
        );
        return;
      }

      if (action == 'excel') {
        if (!requireWebExport(context)) return;
        final bytes = SurveySingleResponseExportService.toExcel(
          survey: survey,
          response: response,
          questions: _questions,
          participant: participant,
        );
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName:
              '${SurveySingleResponseExportService.fileBaseName(participant)}.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        return;
      }

      if (action == 'print') {
        final bytes = await SurveySingleResponseExportService.toPdf(
          survey: survey,
          response: response,
          questions: _questions,
          participant: participant,
        );
        if (!mounted) return;
        await SurveySingleResponseExportService.printPdf(
          pdfBytes: bytes,
          documentName: survey.title,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _onSubmittedCardAction({
    required String action,
    required SurveyParticipant participant,
    required bool isChedBuiltin,
  }) {
    switch (action) {
      case 'view':
        _openSubmittedResponseDetail(
          participant: participant,
          isChedBuiltin: isChedBuiltin,
        );
      case 'pdf':
      case 'excel':
      case 'print':
        _exportSubmittedResponse(participant: participant, action: action);
      case 'timeline':
        showAdminSurveyResponseTimelineSheet(
          context: context,
          participant: participant,
        );
    }
  }

  void _openSubmittedResponseDetail({
    required SurveyParticipant participant,
    required bool isChedBuiltin,
  }) {
    final r = participant.response;
    if (r == null) return;
    showAdminSurveyResponseDetailSheet(
      context: context,
      alumniName: participant.displayName,
      response: r,
      isChedBuiltin: isChedBuiltin,
      questions: _questions,
      onViewTimeline: () {
        showAdminSurveyResponseTimelineSheet(
          context: context,
          participant: participant,
        );
      },
    );
  }

  String _statusLabel(SurveyAssignmentStatus status) {
    switch (status) {
      case SurveyAssignmentStatus.notStarted:
        return 'Not started';
      case SurveyAssignmentStatus.inProgress:
        return 'In progress';
      case SurveyAssignmentStatus.completed:
        return 'Completed';
    }
  }
}

enum _PendingSort {
  assignedNewest,
  assignedOldest,
  nameAsc,
  reminderRecent,
  reminderCountDesc,
}

extension on _PendingSort {
  String get label => switch (this) {
    _PendingSort.assignedNewest => 'Newest assigned',
    _PendingSort.assignedOldest => 'Oldest assigned',
    _PendingSort.nameAsc => 'Name A–Z',
    _PendingSort.reminderRecent => 'Recent reminder',
    _PendingSort.reminderCountDesc => 'Most reminded',
  };
}

enum _SubmittedSort { newest, oldest, nameAsc }

extension on _SubmittedSort {
  String get label => switch (this) {
    _SubmittedSort.newest => 'Newest submitted',
    _SubmittedSort.oldest => 'Oldest submitted',
    _SubmittedSort.nameAsc => 'Name A–Z',
  };
}

const _pendingTableColumns = <AdminDataColumn>[
  AdminDataColumn(label: 'NAME', flex: 3),
  AdminDataColumn(label: 'COURSE', flex: 2),
  AdminDataColumn(label: 'BATCH', width: 90),
  AdminDataColumn(label: 'STATUS', width: 120),
  AdminDataColumn(label: 'ASSIGNED', width: 130),
  AdminDataColumn(label: 'REMINDERS', width: 130),
];

const _submittedTableColumns = <AdminDataColumn>[
  AdminDataColumn(label: 'NAME', flex: 3),
  AdminDataColumn(label: 'COURSE', flex: 2),
  AdminDataColumn(label: 'BATCH', width: 90),
  AdminDataColumn(label: 'SUBMITTED', width: 150),
  AdminDataColumn(label: 'DURATION', width: 90),
  AdminDataColumn(label: 'DEVICE', flex: 2),
  AdminDataColumn(label: 'STATUS', width: 100),
];

class _SubmittedResponseCard extends StatelessWidget {
  const _SubmittedResponseCard({
    required this.participant,
    required this.response,
    required this.surveyVersionLabel,
    required this.onViewResponse,
    required this.onAction,
  });

  final SurveyParticipant participant;
  final SurveyResponse response;
  final String surveyVersionLabel;
  final VoidCallback onViewResponse;
  final ValueChanged<String> onAction;

  static String _durationLabel(SurveyParticipant p, SurveyResponse r) {
    final end = r.submittedAt ?? r.updatedAt;
    final start = p.assignment.assignedAt;
    final mins = end.difference(start).inMinutes;
    if (mins < 0) return '—';
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final rem = mins % 60;
    if (hours < 48) {
      return rem == 0 ? '${hours}h' : '${hours}h ${rem}m';
    }
    final days = end.difference(start).inDays;
    return '$days day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final p = participant;
    final r = response;
    final fmt = DateFormat.yMMMd().add_jm();
    final submittedLabel = r.submittedAt == null
        ? fmt.format(r.updatedAt)
        : fmt.format(r.submittedAt!);
    final statusLabel = r.status == SurveyResponseStatus.submitted
        ? 'Submitted'
        : 'Draft';
    final isSubmitted = r.status == SurveyResponseStatus.submitted;

    return Semantics(
      button: true,
      label:
          '${p.displayName}. Submitted $submittedLabel. $statusLabel. Version $surveyVersionLabel.',
      child: AdminDataRow(
        columns: _submittedTableColumns,
        onTap: onViewResponse,
        trailingWidth: 44,
        trailing: PopupMenuButton<String>(
          tooltip: 'Response actions',
          onSelected: onAction,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'view',
              child: _ExportMenuRow(
                icon: Icons.visibility_outlined,
                title: 'View response',
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: _ExportMenuRow(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Export PDF',
              ),
            ),
            PopupMenuItem(
              value: 'excel',
              child: _ExportMenuRow(
                icon: Icons.grid_on_outlined,
                title: 'Export Excel',
              ),
            ),
            PopupMenuItem(
              value: 'print',
              child: _ExportMenuRow(icon: Icons.print_outlined, title: 'Print'),
            ),
            PopupMenuItem(
              value: 'timeline',
              child: _ExportMenuRow(
                icon: Icons.timeline_outlined,
                title: 'View timeline',
              ),
            ),
          ],
          icon: const Icon(
            Icons.more_vert,
            color: AdminSurveyTheme.textSecondary,
          ),
        ),
        cells: [
          AdminTableIdentityCell(
            title: p.displayName.trim().isEmpty
                ? 'Unnamed alumni'
                : p.displayName,
            subtitle: p.email.trim().isEmpty ? 'No email on file' : p.email,
            leading: _ParticipantAvatar(
              name: p.displayName,
              imageUrl: p.profileImageUrl,
              backgroundColor: AdminSurveyTheme.successBg,
              foregroundColor: AdminSurveyTheme.success,
              size: 32,
            ),
          ),
          AdminTableTextCell(
            p.program.isEmpty ? '—' : p.program,
            muted: p.program.isEmpty,
          ),
          AdminTableTextCell(
            p.batchYear.isEmpty ? '—' : p.batchYear,
            muted: p.batchYear.isEmpty,
          ),
          AdminTableTextCell(submittedLabel),
          AdminTableTextCell(_durationLabel(p, r), muted: true),
          AdminTableTextCell(
            r.deviceSummary,
            muted: r.deviceSummary == 'Device not recorded',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AdminTableBadge(
              label: statusLabel,
              bg: isSubmitted
                  ? AdminTableTheme.successBg
                  : AdminTableTheme.warningBg,
              fg: isSubmitted
                  ? AdminTableTheme.success
                  : AdminTableTheme.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingAlumniCard extends StatelessWidget {
  const _PendingAlumniCard({
    required this.participant,
    required this.selected,
    required this.onSelected,
    required this.statusLabel,
  });

  final SurveyParticipant participant;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final p = participant;
    final a = p.assignment;
    final days = DateTime.now().difference(a.assignedAt).inDays;
    final lastReminder = a.lastReminderAt;
    final dateFmt = DateFormat.yMMMd();
    final reminderLabel = lastReminder == null
        ? (a.reminderCount == 0 ? 'None' : '${a.reminderCount}x')
        : '${a.reminderCount}x · ${dateFmt.format(lastReminder)}';

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label:
          '${p.displayName}. $statusLabel. ${p.program}. Batch ${p.batchYear}.',
      child: AdminDataRow(
        columns: _pendingTableColumns,
        selected: selected,
        onTap: () => onSelected(!selected),
        leadingWidth: 48,
        leading: Checkbox(
          value: selected,
          onChanged: (v) => onSelected(v == true),
        ),
        cells: [
          AdminTableIdentityCell(
            title: p.displayName.trim().isEmpty
                ? 'Unnamed alumni'
                : p.displayName,
            subtitle: p.email.trim().isEmpty ? 'No email on file' : p.email,
            leading: _ParticipantAvatar(
              name: p.displayName,
              imageUrl: p.profileImageUrl,
              backgroundColor: AdminSurveyTheme.infoBg,
              foregroundColor: AdminSurveyTheme.primary,
              size: 32,
            ),
          ),
          AdminTableTextCell(
            p.program.isEmpty ? '—' : p.program,
            muted: p.program.isEmpty,
          ),
          AdminTableTextCell(
            p.batchYear.isEmpty ? '—' : p.batchYear,
            muted: p.batchYear.isEmpty,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AdminTableBadge(
              label: statusLabel,
              bg: AdminTableTheme.warningBg,
              fg: AdminTableTheme.warning,
            ),
          ),
          AdminTableTextCell(
            '${dateFmt.format(a.assignedAt)} · ${days}d',
            muted: true,
          ),
          AdminTableTextCell(reminderLabel, muted: a.reminderCount == 0),
        ],
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({
    required this.name,
    this.imageUrl,
    required this.backgroundColor,
    required this.foregroundColor,
    this.size = 44,
  });

  final String name;
  final String? imageUrl;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppImage.provider(imageUrl);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      backgroundImage: provider,
      child: provider == null
          ? Text(
              _initials(name),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: size < 36 ? 11 : 13,
              ),
            )
          : null,
    );
  }
}

/// Simple row for export menu — avoid [ListTile] inside [PopupMenuItem] (swallows taps).
class _ExportMenuRow extends StatelessWidget {
  const _ExportMenuRow({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
