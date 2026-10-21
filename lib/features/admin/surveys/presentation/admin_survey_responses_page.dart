import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/csv_safe.dart';
import 'package:alumni_system/core/utils/personal_data_notice.dart';
import 'package:alumni_system/shared/widgets/personal_data_export_dialog.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/core/services/ched_gts_export_service.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_response_detail_sheet.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_response_timeline_sheet.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_analytics_panel.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_formal_report_dialog.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_export_dialog.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/admin/surveys/widgets/survey_question_editor.dart';
import 'package:alumni_system/features/admin/roster/widgets/alumni_directory_ui.dart';
import 'package:alumni_system/features/surveys/data/survey_report_pack_service.dart';
import 'package:alumni_system/features/surveys/data/survey_ched_outcomes_summary_service.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_surface.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/admin/admin_data_table.dart';
import 'package:alumni_system/shared/widgets/admin/admin_pagination.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/surveys/data/survey_single_response_export_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Reminder confirmation text; [emailDropped] = email was requested but
/// isn't configured, so only in-app goes out.
@visibleForTesting
String surveyReminderConfirmMessage({
  required String surveyTitle,
  required int recipients,
  required bool inApp,
  required bool email,
  required bool emailDropped,
}) {
  final channels = <String>[
    if (inApp) 'in-app',
    if (email) 'email',
  ].join(' + ');
  final title = surveyTitle.trim().isEmpty
      ? 'this survey'
      : '“${surveyTitle.trim()}”';
  final who = recipients == 1 ? 'alumnus' : 'alumni';
  final note = emailDropped
      ? ' Email isn’t set up, so these will be sent in-app only.'
      : '';
  return 'Send $channels reminders for $title to $recipients pending $who?'
      '$note';
}

/// Result line after `sendReminders`, including skipped emails.
@visibleForTesting
String surveyReminderSummary(
  SurveyReminderResult result, {
  required bool inApp,
  required bool email,
  required bool emailDropped,
}) {
  final parts = <String>[
    if (inApp) '${result.inAppSent} in-app',
    if (email) '${result.emailSent} email',
    if (result.emailSkippedNoAddress > 0)
      '${result.emailSkippedNoAddress} skipped (no email)',
    if (result.emailSkippedOptedOut > 0)
      '${result.emailSkippedOptedOut} skipped (opted out of email)',
    if (result.emailSkippedNotConfigured > 0)
      '${result.emailSkippedNotConfigured} email skipped (not set up)',
  ];
  final summary = parts.isEmpty
      ? 'No reminders sent'
      : 'Sent: ${parts.join(', ')}';
  return emailDropped ? '$summary · email isn’t set up' : summary;
}

/// Export failure text: what failed, plus the reason when it reads cleanly.
@visibleForTesting
String surveyExportErrorMessage(String what, Object error) {
  final reason = error is Error ? '' : surveyFriendlyError(error, '');
  final base = 'Couldn’t create $what.';
  return reason.isEmpty ? '$base Try again.' : '$base $reason';
}

/// Detail panel meta line: course · batch · submitted date · device.
@visibleForTesting
String surveyResponseMetaLine(
  SurveyParticipant participant,
  SurveyResponse response,
) {
  final program = participant.program.trim();
  final batch = participant.batchYear.trim();
  final submittedAt = response.submittedAt;
  final device = response.deviceSummary;
  return <String>[
    if (program.isNotEmpty) program,
    if (batch.isNotEmpty) 'Batch $batch',
    if (submittedAt != null)
      'Submitted ${DateFormat.yMMMd().format(submittedAt)}'
    else
      'Last saved ${DateFormat.yMMMd().format(response.updatedAt)}',
    if (device != 'Device not recorded') device,
  ].join(' · ');
}

class AdminSurveyResponsesScreen extends StatefulWidget {
  const AdminSurveyResponsesScreen({
    super.key,
    required this.surveyId,
    this.onClose,
    this.onOpenEditor,
  });

  final String surveyId;

  /// When set, responses are shown inline in the surveys panel (no route push).
  final VoidCallback? onClose;

  /// Opens the edit/publish workspace for [surveyId] (or another draft id).
  /// Parent should return here when the editor closes.
  final ValueChanged<String>? onOpenEditor;

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

  /// Label of the running Overview publish / re-publish / close step.
  String? _stateActionBusy;
  bool _duplicating = false;
  String? _loadError;
  bool _loadErrorLooksOffline = false;
  late TabController _tabController;

  /// Pending workspace filters (UI-only; Phase 5).
  SurveyAssignmentStatus? _pendingStatusFilter;
  String? _pendingProgramFilter;
  String? _pendingBatchFilter;
  _PendingSort _pendingSort = _PendingSort.assignedNewest;
  _SubmittedSort _submittedSort = _SubmittedSort.newest;
  String? _submittedProgramFilter;
  String? _submittedBatchFilter;
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
      // Heal sticky publish stamp / badge cursor before reading survey for UI.
      try {
        await _surveyService.markSurveyResponsesSeenByAdmin(widget.surveyId);
      } catch (_) {}

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

  Future<void> _exportPendingSelectedCsv(
    List<SurveyParticipant> visible,
  ) async {
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
    if (!await confirmPersonalDataExport(
          context,
          what: 'The pending list',
        ) ||
        !mounted) {
      return;
    }
    final buf = StringBuffer();
    buf.writeln(
      'name,email,program,batch,status,assigned_at,last_reminder_at,reminder_count',
    );
    const esc = CsvSafe.cell;
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
    _showSnack(
      'Exported ${selected.length} pending alumni',
      color: AdminColors.success,
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

    final emailDropped = email && !EmailDeliveryConfig.isConfigured;
    if (emailDropped && !inApp) {
      _showSnack(
        'Email reminders are not configured. Check Gmail SMTP / '
        'Supabase secrets or use In-app.',
        color: AdminColors.warning,
      );
      return;
    }
    if (emailDropped) email = false;

    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Send reminders?',
      message: surveyReminderConfirmMessage(
        surveyTitle: _survey?.title ?? '',
        recipients: targets.length,
        inApp: inApp,
        email: email,
        emailDropped: emailDropped,
      ),
      confirmLabel: 'Send',
      icon: Icons.send_outlined,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSendingReminders = true);
    try {
      final result = await _surveyService.sendReminders(
        surveyId: widget.surveyId,
        userIds: targets,
        inApp: inApp,
        email: email,
      );
      if (!mounted) return;
      _showSnack(
        surveyReminderSummary(
          result,
          inApp: inApp,
          email: email,
          emailDropped: emailDropped,
        ),
        color: result.failures.isEmpty && !emailDropped
            ? AdminColors.success
            : AdminColors.warning,
      );
      if (result.failures.isNotEmpty) {
        showAdminDialogSurface<void>(
          context: context,
          maxWidth: 480,
          child: _ReminderFailuresDialog(failures: result.failures),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        _showSnack(
          surveyFriendlyError(e, 'Couldn’t send reminders. Try again.'),
          color: AdminColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReminders = false);
    }
  }

  Future<void> _exportCsv({
    List<SurveyParticipant>? participants,
    int? submittedCount,
  }) async {
    if (!requireWebExport(context)) return;
    if (_survey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Survey not loaded yet')));
      return;
    }
    if (!await confirmPersonalDataExport(
          context,
          what: 'The responses file',
        ) ||
        !mounted) {
      return;
    }
    final people = participants ?? _participants;
    final submitted = submittedCount ?? _submitted.length;
    if (submitted == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submitted responses to export')),
      );
      return;
    }
    try {
      final csv = _surveyService.buildResponsesCsv(
        survey: _survey!,
        questions: _questions,
        participants: people,
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
        _showSnack('Responses CSV downloaded', color: AdminColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          surveyExportErrorMessage('the responses CSV', e),
          color: AdminColors.danger,
        );
      }
    }
  }

  Future<void> _exportResponsesExcel({
    List<SurveyParticipant>? participants,
    int? submittedCount,
  }) async {
    if (!requireWebExport(context)) return;
    if (_survey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey not loaded yet')),
      );
      return;
    }
    if (!await confirmPersonalDataExport(
          context,
          what: 'The responses workbook',
        ) ||
        !mounted) {
      return;
    }
    final people = participants ?? _participants;
    final submittedN = submittedCount ?? _submitted.length;
    if (submittedN == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submitted responses to export')),
      );
      return;
    }
    setState(() => _isExportingChed = true);
    try {
      final book = Excel.createExcel();
      final defaultName = book.getDefaultSheet();
      if (defaultName != null) {
        book.rename(defaultName, 'Responses');
      }
      final sheet = book['Responses'];
      sheet.appendRow([
        'Name',
        'Email',
        'Program',
        'Batch',
        'Status',
        'Submitted At',
        ..._questions.map((q) => q.prompt),
      ]);
      final submitted = people
          .where((p) => !p.isPending && p.response != null)
          .toList(growable: false);
      for (final p in submitted) {
        final response = p.response!;
        sheet.appendRow([
          p.displayName,
          p.email,
          p.program,
          p.batchYear,
          p.assignment.status.name,
          response.submittedAt?.toIso8601String() ?? '',
          ..._questions.map((q) => '${response.answers[q.id] ?? ''}'),
        ]);
      }
      final encoded = book.encode();
      if (encoded == null) {
        throw StateError('Excel encode returned null');
      }
      if (!mounted) return;
      final safe = _survey!.title.replaceAll(RegExp(r'[^\w\-]+'), '_');
      tryDownloadBytesOnWeb(
        context,
        bytes: Uint8List.fromList(encoded),
        fileName:
            'survey_${safe}_responses_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      _showSnack('Responses Excel downloaded', color: AdminColors.success);
    } catch (e) {
      if (mounted) {
        _showSnack(
          surveyExportErrorMessage('the responses Excel file', e),
          color: AdminColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingChed = false);
    }
  }

  Future<void> _exportManagementPack({
    required String format,
    bool printPreview = false,
    List<SurveyParticipant>? participants,
    List<SurveyResponse>? responses,
  }) async {
    if (!printPreview && !requireWebExport(context)) return;
    if (_survey == null) return;
    setState(() => _isExportingChed = true);
    try {
      final pack = SurveyReportPackService.buildSurveyPack(
        survey: _survey!,
        participants: participants ?? _participants,
        questions: _questions,
        responses: responses ?? _responses,
      );
      final safe = _survey!.title.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());

      if (printPreview || format == 'pdf') {
        final bytes = await SurveyReportPackService.toPdf(pack);
        if (!mounted) return;
        if (printPreview) {
          await Printing.layoutPdf(
            onLayout: (_) async => bytes,
            name: '${_survey!.title} management report',
          );
          return;
        }
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: 'survey_${safe}_report_pack_$stamp.pdf',
          mimeType: 'application/pdf',
        );
      } else if (format == 'xlsx') {
        final bytes = SurveyReportPackService.toExcel(pack);
      if (!mounted) return;
      tryDownloadBytesOnWeb(
        context,
        bytes: bytes,
          fileName: 'survey_${safe}_report_pack_$stamp.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final bytes = Uint8List.fromList(
          utf8.encode('\uFEFF${SurveyReportPackService.toCsv(pack)}'),
        );
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: 'survey_${safe}_report_pack_$stamp.csv',
          mimeType: 'text/csv;charset=utf-8',
        );
      }

      if (!mounted) return;
      _showSnack('Management report downloaded', color: AdminColors.success);
    } catch (e) {
      if (mounted) {
        _showSnack(
          surveyExportErrorMessage('the management report', e),
          color: AdminColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingChed = false);
    }
  }

  Future<void> _exportChedGtsExcel({
    List<SurveyParticipant>? participants,
    int? submittedCount,
  }) async {
    if (!requireWebExport(context)) return;
    if (_survey == null) return;
    final people = participants ?? _participants;
    final submitted = submittedCount ?? _submitted.length;
    if (submitted == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submitted responses to export')),
      );
      return;
    }
    if (!await confirmPersonalDataExport(
          context,
          what: 'The CHED GTS filing workbook',
        ) ||
        !mounted) {
      return;
    }

    setState(() => _isExportingChed = true);
    try {
      final bytes = await ChedGtsExportService().buildExcelBytes(
        survey: _survey!,
        questions: _questions,
        participants: people,
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
        _showSnack(
          'CHED GTS Excel export downloaded',
          color: AdminColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          surveyExportErrorMessage('the CHED GTS Excel pack', e),
          color: AdminColors.danger,
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
        child: _ExportMenuRow(
          icon: Icons.refresh,
          title: 'Refresh',
          subtitle: 'Reload the latest survey data',
        ),
      ),
      if (_survey != null)
        const PopupMenuItem(
          value: 'formal_report',
          child: _ExportMenuRow(
            icon: Icons.auto_awesome,
            title: 'Generate formal report',
            subtitle: 'AI-written draft — check it before official use',
          ),
        ),
      if (canExportFiles && _survey != null) ...[
        const PopupMenuDivider(),
          const PopupMenuItem(
          value: 'export',
            child: _ExportMenuRow(
            icon: Icons.download_outlined,
            title: 'Download / export',
            subtitle: 'Choose a report, then save or print it',
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
      case 'export':
        _showExportPicker();
        break;
      // Legacy values (kept for any leftover callers)
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AdminColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.border),
                boxShadow: AdminSurfaces.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SurveyResponsesWorkspaceHeader(
                    survey: _survey,
                    onBack: widget.onClose!,
                    overflowBusy: _isExportingChed,
                    overflowItems: _overflowMenuItems(),
                    onOverflowSelected: _onOverflowSelected,
                    showBottomBorder: false,
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AdminColors.border,
                  ),
                  SurveyWorkspaceSegmentedNav(
                    tabs: workspaceTabs,
                    controller: _tabController,
                    showBottomBorder: false,
                  ),
                ],
              ),
            ),
          )
        else
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
    return SurveyWorkspaceShortcuts(
      currentTab: () => _tabController.index,
      onSelectTab: _goToWorkspaceTab,
      onEscape: _clearWorkspaceSearch,
      child: child,
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
    setState(() {
      if (hadPending) _selectedUserIds.clear();
    });
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
        return const SurveyResponsesSkeleton.table();
      }
      return const SurveyResponsesSkeleton.overview();
    }

    if (_loadError != null && _survey == null) {
      return AdminStateView.error(
        title: _loadErrorLooksOffline
            ? 'You appear to be offline'
            : 'Couldn’t load responses',
        message: _loadErrorLooksOffline
            ? 'Check your internet connection, then try again.'
            : surveyFriendlyError(
                _loadError!,
                'Something went wrong while loading this survey. Try again.',
              ),
        details: _loadErrorLooksOffline ? null : _loadError,
        onRetry: _load,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              left,
              const SizedBox(height: 14),
              SizedBox(
                height: math.max(420, constraints.maxHeight * 0.7),
                child: right,
              ),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: SingleChildScrollView(child: left),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 6, child: right),
            ],
          ),
        );
      },
    );
  }

  Widget _overviewLeftColumn({
    required Survey? survey,
    required int assigned,
    required int completed,
    required DateFormat dateFmt,
  }) {
    return Container(
      decoration: AdminSurfaces.card(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (survey != null)
            SurveyEditorSection(
              title: 'Survey',
              first: true,
              child: _overviewSurveyActions(survey),
            ),
          SurveyEditorSection(
            title: 'Outputs',
            first: survey == null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverviewLinkRow(
                  icon: Icons.download_outlined,
                  label: 'Download / export',
                  onTap: !canExportFiles || _survey == null
                      ? null
                      : _showExportPicker,
                ),
                if (survey != null)
                  _OverviewLinkRow(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Generate formal report',
                    onTap: _openFormalReport,
                  ),
                _OverviewLinkRow(
                  icon: Icons.history_outlined,
                  label: 'Reminder history',
                  onTap: _showReminderHistorySheet,
                ),
              ],
            ),
          ),
          if (survey != null) ...[
            SurveyEditorSection(
              title: 'Details',
              child: Column(
                children: [
                  _infoRow('Survey type', _surveyTypeLabel(survey)),
                  _infoRow('Status', surveyStatusText(survey)),
                  _infoRow(
                    'Window',
                    surveyWindowText(survey) ?? 'No window set',
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
      final years = AudienceTargeting.formatBatchYearsForDisplay(
        AudienceTargeting.expandBatchYearTargets(batches),
      );
      parts.add('Batches ${years.isEmpty ? batches.join(', ') : years}');
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
            width: 112,
            child: Text(
              label,
              style: AdminText.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AdminColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AdminText.body.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  bool get _overviewActionBusy =>
      _stateActionBusy != null || _duplicating || _isBusyQuickAction;

  Widget _overviewSurveyActions(Survey survey) {
    final busy = _overviewActionBusy;
    final published = survey.status == SurveyStatus.published;
    final stateLabel = _stateActionBusy ??
        switch (survey.status) {
          SurveyStatus.draft => 'Publish',
          SurveyStatus.published => 'Close survey',
          SurveyStatus.closed => 'Re-publish',
        };
    final stateIcon = _stateActionBusy != null
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            published ? Icons.lock_outline : Icons.publish_outlined,
            size: 18,
          );
    final stateOnPressed = busy ? null : () => _overviewPublishToggle(survey);
    final openEditor = widget.onOpenEditor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (published)
          OutlinedButton.icon(
            onPressed: stateOnPressed,
            icon: stateIcon,
            label: Text(stateLabel),
            style: AdminButtonStyles.outlined(),
          )
        else
          FilledButton.icon(
            onPressed: stateOnPressed,
            icon: stateIcon,
            label: Text(stateLabel),
            style: AdminButtonStyles.filled(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || openEditor == null
                    ? null
                    : () => openEditor(survey.id),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit survey', overflow: TextOverflow.ellipsis),
                style: AdminButtonStyles.outlined(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _overviewDuplicate,
                icon: _duplicating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.copy_outlined, size: 16),
                label: Text(
                  _duplicating ? 'Duplicating…' : 'Duplicate',
                  overflow: TextOverflow.ellipsis,
                ),
                style: AdminButtonStyles.outlined(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSnack(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _overviewPublishToggle(Survey survey) async {
    if (_overviewActionBusy) return;
    if (survey.status == SurveyStatus.published) {
      await _overviewClose(survey);
    } else {
      await _overviewPublish(survey);
    }
  }

  /// Publish (draft) or re-publish (closed) with the Editor's pre-publish
  /// checks: question problems, zero audience, then a confirmation.
  Future<void> _overviewPublish(Survey survey) async {
    final reopen = survey.status == SurveyStatus.closed;
    if (!survey.isChedGtsBuiltin) {
      final problems = surveyPublishProblems(_questions);
      if (problems.isNotEmpty) {
        final openEditor = await showAdminDialogSurface<bool>(
          context: context,
          maxWidth: 480,
          child: _OverviewPublishProblemsDialog(
            problems: problems,
            canOpenEditor: widget.onOpenEditor != null,
          ),
        );
        if (openEditor == true && mounted) {
          widget.onOpenEditor?.call(survey.id);
        }
        return;
      }
    }

    setState(() => _stateActionBusy = 'Checking audience…');
    try {
      final audienceCount = await _surveyService.countAudience(
        targetPrograms: survey.targetPrograms,
        targetBatchYears: AudienceTargeting.expandBatchYearTargets(
          survey.targetBatchYears,
        ),
      );
      if (!mounted) return;
      final hasFilters = survey.targetPrograms.isNotEmpty ||
          survey.targetBatchYears.isNotEmpty;
      if (hasFilters && audienceCount == 0) {
        _showSnack(
          'No alumni match this survey’s courses and batch years. '
          'Open the editor to adjust the audience.',
          color: AdminColors.danger,
        );
        return;
      }

      setState(() => _stateActionBusy = null);
      final audience =
          'About $audienceCount alumni match the current audience'
          '${hasFilters ? '' : ' (all alumni)'}.';
      final confirmed = await showAdminConfirmDialog(
        context,
        title: reopen ? 'Re-publish survey?' : 'Publish survey?',
        message: reopen
            ? '$audience The survey reopens for them. '
                  'Existing submissions are kept.'
            : '$audience They will be assigned and notified.',
        confirmLabel: reopen ? 'Re-publish' : 'Publish',
        icon: Icons.publish_outlined,
      );
      if (!confirmed || !mounted) return;

      setState(
        () => _stateActionBusy = reopen ? 'Re-publishing…' : 'Publishing…',
      );
      final count = await _surveyService.publishSurvey(survey.id);
      if (!mounted) return;
      _showSnack(
        reopen
            ? 'Re-published · $count alumni assigned'
            : 'Published · $count alumni assigned',
        color: AdminColors.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        surveyFriendlyError(
          e,
          reopen
              ? 'Couldn’t re-publish this survey. Try again.'
              : 'Couldn’t publish this survey. Try again.',
        ),
        color: AdminColors.danger,
      );
    } finally {
      if (mounted) setState(() => _stateActionBusy = null);
    }
  }

  Future<void> _overviewClose(Survey survey) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Close survey?',
      message: 'Alumni will no longer be able to submit new responses.',
      confirmLabel: 'Close survey',
      icon: Icons.lock_outline,
    );
    if (!confirmed || !mounted) return;
    setState(() => _stateActionBusy = 'Closing…');
    try {
      await _surveyService.closeSurvey(survey.id);
      if (!mounted) return;
      _showSnack('Survey closed', color: AdminColors.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        surveyFriendlyError(e, 'Couldn’t close this survey. Try again.'),
        color: AdminColors.danger,
      );
    } finally {
      if (mounted) setState(() => _stateActionBusy = null);
    }
  }

  Future<void> _overviewDuplicate() async {
    if (_overviewActionBusy) return;
    setState(() => _duplicating = true);
    try {
      final id = await _surveyService.duplicateSurvey(widget.surveyId);
      if (!mounted) return;
      _showSnack('Survey duplicated as draft', color: AdminColors.success);
      final open = widget.onOpenEditor;
      if (open != null) {
        open(id);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        surveyFriendlyError(e, 'Couldn’t duplicate this survey. Try again.'),
        color: AdminColors.danger,
      );
    } finally {
      if (mounted) setState(() => _duplicating = false);
    }
  }

  Future<void> _showExportPicker() async {
    if (_survey == null) return;
    final survey = _survey!;
    final openAudience = survey.targetPrograms.isEmpty &&
        survey.targetBatchYears.isEmpty;
    final showCohortFilters = survey.isChedGtsBuiltin && openAudience;

    final batchOptions = <String>{
      for (final p in _participants)
        if (p.batchYear.trim().isNotEmpty) p.batchYear.trim(),
    }.toList()
      ..sort((a, b) {
        final an = int.tryParse(a);
        final bn = int.tryParse(b);
        if (an != null && bn != null) return bn.compareTo(an);
        return b.compareTo(a);
      });
    final courseOptions = <String>{
      for (final p in _participants)
        if (p.program.trim().isNotEmpty) p.program.trim(),
    }.toList()
      ..sort();

    final choice = await showAdminSurveyExportDialog(
      context: context,
      hasSubmitted: _submitted.isNotEmpty,
      isChedGts: survey.isChedGtsBuiltin,
      showCohortFilters: showCohortFilters,
      batchOptions: batchOptions,
      courseOptions: courseOptions,
    );
    if (choice == null || !mounted) return;
    await _runSurveyExport(choice);
  }

  List<SurveyParticipant> _participantsForExport(SurveyExportChoice choice) {
    var list = _participants;
    final batch = choice.batchYear?.trim().toLowerCase();
    final course = choice.course?.trim().toLowerCase();
    if (batch != null && batch.isNotEmpty) {
      list = list
          .where((p) => p.batchYear.trim().toLowerCase() == batch)
          .toList(growable: false);
    }
    if (course != null && course.isNotEmpty) {
      list = list
          .where((p) => p.program.trim().toLowerCase() == course)
          .toList(growable: false);
    }
    return list;
  }

  List<SurveyResponse> _responsesForExport(
    List<SurveyParticipant> participants,
  ) {
    final ids = {for (final p in participants) p.assignment.userId};
    return _responses
        .where((r) => ids.contains(r.userId))
        .toList(growable: false);
  }

  Future<void> _runSurveyExport(SurveyExportChoice choice) async {
    final scopedParticipants = _participantsForExport(choice);
    final scopedResponses = _responsesForExport(scopedParticipants);
    final scopedSubmitted =
        scopedParticipants.where((p) => !p.isPending).toList(growable: false);
    final scopedPending =
        scopedParticipants.where((p) => p.isPending).toList(growable: false);

    switch (choice.report) {
      case SurveyExportReportKind.responses:
        switch (choice.format) {
          case SurveyExportFormat.csv:
            _exportCsv(
              participants: scopedParticipants,
              submittedCount: scopedSubmitted.length,
            );
          case SurveyExportFormat.excel:
            await _exportResponsesExcel(
              participants: scopedParticipants,
              submittedCount: scopedSubmitted.length,
            );
          case SurveyExportFormat.pdf:
          case SurveyExportFormat.print:
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Submitted responses export as Excel or CSV. '
                    'Use Management report or CHED outcomes for PDF / Print.',
                  ),
                ),
              );
            }
        }
      case SurveyExportReportKind.management:
        switch (choice.format) {
          case SurveyExportFormat.pdf:
            await _exportManagementPack(
              format: 'pdf',
              participants: scopedParticipants,
              responses: scopedResponses,
            );
          case SurveyExportFormat.excel:
            await _exportManagementPack(
              format: 'xlsx',
              participants: scopedParticipants,
              responses: scopedResponses,
            );
          case SurveyExportFormat.csv:
            await _exportManagementPack(
              format: 'csv',
              participants: scopedParticipants,
              responses: scopedResponses,
            );
          case SurveyExportFormat.print:
            await _exportManagementPack(
              format: 'pdf',
              printPreview: true,
              participants: scopedParticipants,
              responses: scopedResponses,
            );
        }
      case SurveyExportReportKind.ched:
        if (choice.format != SurveyExportFormat.excel) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('CHED GTS pack is available as Excel only.'),
              ),
            );
          }
          return;
        }
        await _exportChedGtsExcel(
          participants: scopedParticipants,
          submittedCount: scopedSubmitted.length,
        );
      case SurveyExportReportKind.chedOutcomes:
        await _exportChedOutcomesSummary(
          format: choice.format,
          printPreview: choice.format == SurveyExportFormat.print,
          participants: scopedParticipants,
          responses: scopedResponses,
          submittedCount: scopedSubmitted.length,
        );
      case SurveyExportReportKind.pending:
        await _exportPendingList(
          format: choice.format,
          printPreview: choice.format == SurveyExportFormat.print,
          pending: scopedPending,
        );
      case SurveyExportReportKind.chedFillable:
        await _exportOfficialFillableZip(submitted: scopedSubmitted);
    }
  }

  Future<void> _exportChedOutcomesSummary({
    required SurveyExportFormat format,
    bool printPreview = false,
    List<SurveyParticipant>? participants,
    List<SurveyResponse>? responses,
    int? submittedCount,
  }) async {
    if (!printPreview &&
        format != SurveyExportFormat.print &&
        !requireWebExport(context)) {
      return;
    }
    if (_survey == null || !_survey!.isChedGtsBuiltin) return;
    final submitted = submittedCount ?? _submitted.length;
    if (submitted == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submitted responses to summarize')),
      );
      return;
    }

    setState(() => _isExportingChed = true);
    try {
      final summary = SurveyChedOutcomesSummaryService.build(
        survey: _survey!,
        participants: participants ?? _participants,
        responses: responses ?? _responses,
      );
      final safe = _survey!.title.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());

      if (printPreview || format == SurveyExportFormat.pdf) {
        final bytes = await SurveyChedOutcomesSummaryService.toPdf(summary);
        if (!mounted) return;
        if (printPreview || format == SurveyExportFormat.print) {
          await Printing.layoutPdf(
            onLayout: (_) async => bytes,
            name: '${_survey!.title} CHED outcomes',
          );
          return;
        }
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: 'ched_outcomes_${safe}_$stamp.pdf',
          mimeType: 'application/pdf',
        );
      } else if (format == SurveyExportFormat.excel) {
        final bytes = SurveyChedOutcomesSummaryService.toExcel(summary);
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: 'ched_outcomes_${safe}_$stamp.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final bytes = SurveyChedOutcomesSummaryService.toCsvBytes(summary);
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: 'ched_outcomes_${safe}_$stamp.csv',
          mimeType: 'text/csv;charset=utf-8',
        );
      }

      if (!mounted) return;
      _showSnack('CHED outcomes summary ready', color: AdminColors.success);
    } catch (e) {
      if (mounted) {
        _showSnack(
          surveyExportErrorMessage('the CHED outcomes summary', e),
          color: AdminColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingChed = false);
    }
  }

  Future<void> _exportPendingList({
    required SurveyExportFormat format,
    bool printPreview = false,
    List<SurveyParticipant>? pending,
  }) async {
    if (!printPreview &&
        format != SurveyExportFormat.print &&
        !requireWebExport(context)) {
      return;
    }
    final list = pending ?? _pending;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending alumni in this survey')),
      );
      return;
    }
    if (!await confirmPersonalDataExport(context, what: 'The pending list') ||
        !mounted) {
      return;
    }

    setState(() => _isExportingChed = true);
    try {
      final safe = (_survey?.title ?? 'survey')
          .replaceAll(RegExp(r'[^\w\-]+'), '_');
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());

      if (printPreview ||
          format == SurveyExportFormat.pdf ||
          format == SurveyExportFormat.print) {
        final bytes = await _pendingListPdfBytes(list);
        if (!mounted) return;
        if (printPreview || format == SurveyExportFormat.print) {
          await Printing.layoutPdf(
            onLayout: (_) async => bytes,
            name: '${_survey?.title ?? 'Survey'} pending list',
          );
          return;
        }
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: '${safe}_pending_$stamp.pdf',
          mimeType: 'application/pdf',
        );
      } else if (format == SurveyExportFormat.excel) {
        final book = Excel.createExcel();
        final def = book.getDefaultSheet();
        if (def != null) book.rename(def, 'Pending');
        final sheet = book['Pending'];
        sheet.appendRow([
          'Name',
          'Email',
          'Program',
          'Batch',
          'Status',
          'Assigned At',
          'Last Reminder',
          'Reminder Count',
        ]);
        for (final p in list) {
          final a = p.assignment;
          sheet.appendRow([
            p.displayName,
            p.email,
            p.program,
            p.batchYear,
            a.status.name,
            a.assignedAt.toIso8601String(),
            a.lastReminderAt?.toIso8601String() ?? '',
            a.reminderCount,
          ]);
        }
        final encoded = book.encode();
        if (encoded == null) throw StateError('Excel encode returned null');
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: Uint8List.fromList(encoded),
          fileName: '${safe}_pending_$stamp.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final buf = StringBuffer();
        buf.writeln(
          'name,email,program,batch,status,assigned_at,last_reminder_at,reminder_count',
        );
        const esc = CsvSafe.cell;
        for (final p in list) {
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
        if (!mounted) return;
        tryDownloadBytesOnWeb(
          context,
          bytes: Uint8List.fromList(utf8.encode('\uFEFF${buf.toString()}')),
          fileName: '${safe}_pending_$stamp.csv',
          mimeType: 'text/csv;charset=utf-8',
        );
      }

      if (!mounted) return;
      _showSnack(
        'Pending list exported (${list.length})',
        color: AdminColors.success,
      );
    } catch (e) {
      if (mounted) {
        _showSnack(
          surveyExportErrorMessage('the pending list', e),
          color: AdminColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingChed = false);
    }
  }

  Future<Uint8List> _pendingListPdfBytes(List<SurveyParticipant> pending) async {
    final doc = pw.Document();
    final title = _survey?.title.trim().isNotEmpty == true
        ? _survey!.title.trim()
        : 'Survey';
    final stamp = DateFormat.yMMMMEEEEd().add_jm().format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              PdfSafeText.sanitize('Pending / non-response list'),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.Text(
              PdfSafeText.sanitize('$title · ${pending.length} pending · $stamp'),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.blue900),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: pdfPageFooter,
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: const [
              'Name',
              'Email',
              'Program',
              'Batch',
              'Status',
              'Reminders',
            ].map(PdfSafeText.sanitize).toList(),
            data: [
              for (final p in pending)
                [
                  PdfSafeText.sanitize(p.displayName),
                  PdfSafeText.sanitize(p.email),
                  PdfSafeText.sanitize(p.program),
                  PdfSafeText.sanitize(p.batchYear),
                  PdfSafeText.sanitize(p.assignment.status.name),
                  '${p.assignment.reminderCount}',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 3,
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<void> _exportOfficialFillableZip({
    List<SurveyParticipant>? submitted,
  }) async {
    if (!requireWebExport(context)) return;
    final survey = _survey;
    if (survey == null || !survey.isChedGtsBuiltin) return;
    var targets = submitted ?? _submitted;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No submitted responses to fill')),
      );
      return;
    }
    if (!await confirmPersonalDataExport(
          context,
          what: 'The filled CHED forms',
        ) ||
        !mounted) {
      return;
    }

    if (targets.length > ChedGtsPdfExportLimits.maxBatchSize) {
      final proceed = await showAdminConfirmDialog(
        context,
        title: 'Batch limit',
        message:
            '${ChedGtsPdfExportLimits.batchCapMessage(targets.length)}\n\n'
            'Export the first ${ChedGtsPdfExportLimits.maxBatchSize} now?',
        confirmLabel: 'Continue',
        icon: Icons.folder_zip_outlined,
      );
      if (!proceed || !mounted) return;
      targets = targets.take(ChedGtsPdfExportLimits.maxBatchSize).toList();
    }

    setState(() => _isExportingChed = true);
    final progress = ValueNotifier<(int, int, String?)>((0, targets.length, null));
    showAdminDialogSurface<void>(
      context: context,
      maxWidth: 420,
      barrierDismissible: false,
      child: PopScope(
        canPop: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: ValueListenableBuilder<(int, int, String?)>(
            valueListenable: progress,
            builder: (_, value, __) {
              final (done, total, name) = value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Building official CHED PDFs',
                    style: AdminText.sectionTitle,
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: total == 0 ? null : done / total,
                    color: AdminColors.primary,
                    backgroundColor: AdminColors.border,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$done / $total',
                    style: AdminText.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (name != null && name.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.caption,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );

    final batch = ChedGtsPdfBatchExportService();
    try {
      final members = [
        for (final p in targets)
          AlumniMember(
            id: p.assignment.userId,
            fullName: p.displayName.trim().isEmpty
                ? 'Alumni'
                : p.displayName.trim(),
            course: p.program,
            studentId: p.studentId ?? '',
            authUid: p.assignment.userId,
            isRegisteredUser: true,
            batchYear: p.batchYear,
            emailAddress: p.email,
            registeredEmail: p.email,
          ),
      ];

      final result = await batch.buildZip(
        members: members,
        surveyId: survey.id,
        fillGapsFromProfile: true,
        allowLiveFallback: false,
        onProgress: (done, total, name) {
          progress.value = (done, total, name);
        },
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      final ok = tryDownloadBytesOnWeb(
        context,
        bytes: result.zipBytes,
        fileName: result.zipFileName,
        mimeType: 'application/zip',
      );
      if (!ok) return;

      await batch.logBatchSuccess(
        result: result,
        selectedCount: members.length,
      );

      if (!mounted) return;
      final skipped = result.failures.length;
      _showSnack(
        skipped == 0
            ? 'Downloaded ZIP with ${result.successCount} fillable PDF(s)'
            : 'Downloaded ZIP with ${result.successCount} PDF(s); '
                '$skipped skipped/failed',
        color: skipped == 0 ? AdminColors.success : AdminColors.warning,
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await batch.logBatchFailure(error: e, selectedCount: targets.length);
      if (!mounted) return;
      _showSnack(
        surveyExportErrorMessage('the fillable CHED PDFs', e),
        color: AdminColors.danger,
      );
    } finally {
      progress.dispose();
      if (mounted) setState(() => _isExportingChed = false);
    }
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.border),
              boxShadow: AdminSurfaces.cardShadow,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {
                            _pendingPage = 0;
                            _selectedUserIds.clear();
                          }),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AdminColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search pending by name, email, course, or batch…',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AdminColors.textMuted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: AdminColors.textMuted,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _pendingPage = 0;
                                        _selectedUserIds.clear();
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AdminColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AdminColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AdminColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AdminColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
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
                        size: 16,
                      ),
                      label: Text(
                        allVisibleSelected ? 'Deselect page' : 'Select page',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: AdminButtonStyles.outlined(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _pendingFilterChip(
                      label: _pendingStatusFilter == null
                          ? 'Status: All'
                          : 'Status: ${_statusLabel(_pendingStatusFilter!)}',
                      selected: _pendingStatusFilter != null,
                      onTap: _pickPendingStatusFilter,
                    ),
                    _pendingFilterChip(
                      label: _pendingProgramFilter == null
                          ? 'Course: All'
                          : 'Course: $_pendingProgramFilter',
                      selected: _pendingProgramFilter != null,
                      onTap: _pickPendingProgramFilter,
                    ),
                    _pendingFilterChip(
                      label: _pendingBatchFilter == null
                          ? 'Batch: All'
                          : 'Batch: $_pendingBatchFilter',
                      selected: _pendingBatchFilter != null,
                      onTap: _pickPendingBatchFilter,
                    ),
                    _pendingFilterChip(
                      label: 'Sort: ${_pendingSort.label}',
                      selected: false,
                      onTap: _pickPendingSort,
                    ),
                    if (hasFilters || hasQuery)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _pendingStatusFilter = null;
                            _pendingProgramFilter = null;
                            _pendingBatchFilter = null;
                            _pendingPage = 0;
                            _selectedUserIds.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text(
                          'Reset',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AdminColors.textSecondary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_selectedUserIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AdminColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AdminColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AdminColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedUserIds.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'selected',
                        style: AdminText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AdminColors.primary,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(_selectedUserIds.clear),
                    child: const Text('Clear selection'),
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            allPending.isEmpty
                ? 'No pending assignments'
                : 'Showing ${list.length} of ${allPending.length} pending',
            style: AdminText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AdminColors.textMuted,
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
                            _selectedUserIds.clear();
                          });
                        }
                      : null,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SurveyResponsesTableFrame(
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
                                    _selectedUserIds.remove(
                                      p.assignment.userId,
                                    );
                                  }
                                });
                              },
                              statusLabel: _statusLabel(p.assignment.status),
                            );
                          },
                        ),
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
    return DirectoryToolbarFilterChip(
      label: label,
      selected: selected,
      onSelected: (_) => onTap(),
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
    final next = value is SurveyAssignmentStatus ? value : null;
    if (value != '__clear__' && next == null) return;
    setState(() {
      _pendingPage = 0;
      if (next != _pendingStatusFilter) _selectedUserIds.clear();
      _pendingStatusFilter = next;
    });
  }

  Future<void> _pickPendingSort() async {
    final value = await showAdminOptionPicker<_PendingSort>(
      context: context,
      title: 'Sort pending alumni',
      options: [
        for (final s in _PendingSort.values)
          AdminPickerOption(
            value: s,
            label: s.label,
            selected: s == _pendingSort,
          ),
      ],
    );
    if (!mounted || value == null) return;
    setState(() {
      _pendingSort = value;
      _pendingPage = 0;
    });
  }

  Future<void> _pickSubmittedSort() async {
    final value = await showAdminOptionPicker<_SubmittedSort>(
      context: context,
      title: 'Sort submitted responses',
      options: [
        for (final s in _SubmittedSort.values)
          AdminPickerOption(
            value: s,
            label: s.label,
            selected: s == _submittedSort,
          ),
      ],
    );
    if (!mounted || value == null) return;
    setState(() {
      _submittedSort = value;
      _submittedPage = 0;
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
    final next = value.isEmpty ? null : value;
    setState(() {
      _pendingPage = 0;
      if (next != _pendingProgramFilter) _selectedUserIds.clear();
      _pendingProgramFilter = next;
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
    final next = value.isEmpty ? null : value;
    setState(() {
      _pendingPage = 0;
      if (next != _pendingBatchFilter) _selectedUserIds.clear();
      _pendingBatchFilter = next;
    });
  }

  Set<String> get _submittedProgramOptions => _submitted
      .map((p) => p.program)
      .where((p) => p.trim().isNotEmpty)
      .toSet();

  Set<String> get _submittedBatchOptions => _submitted
      .map((p) => p.batchYear)
      .where((b) => b.trim().isNotEmpty)
      .toSet();

  Future<void> _pickSubmittedProgramFilter() async {
    final options = _submittedProgramOptions.toList()..sort();
    final value = await showAdminOptionPicker<String>(
      context: context,
      title: 'Filter by course',
      options: [
        AdminPickerOption(
          value: '',
          label: 'All courses',
          selected: _submittedProgramFilter == null,
        ),
        for (final p in options)
          AdminPickerOption(
            value: p,
            label: p,
            selected: _submittedProgramFilter == p,
          ),
      ],
    );
    if (!mounted || value == null) return;
    final next = value.isEmpty ? null : value;
    setState(() {
      _submittedPage = 0;
      _submittedProgramFilter = next;
    });
  }

  Future<void> _pickSubmittedBatchFilter() async {
    final options = _submittedBatchOptions.toList()..sort();
    final value = await showAdminOptionPicker<String>(
      context: context,
      title: 'Filter by batch',
      options: [
        AdminPickerOption(
          value: '',
          label: 'All batches',
          selected: _submittedBatchFilter == null,
        ),
        for (final b in options)
          AdminPickerOption(
            value: b,
            label: b,
            selected: _submittedBatchFilter == b,
          ),
      ],
    );
    if (!mounted || value == null) return;
    final next = value.isEmpty ? null : value;
    setState(() {
      _submittedPage = 0;
      _submittedBatchFilter = next;
    });
  }

  Widget _buildSubmittedTab() {
    final allSubmitted = _submitted;
    final list = _submittedWorkspaceList();
    final hasQuery = _submittedSearchController.text.trim().isNotEmpty;
    final hasFilters =
        _submittedProgramFilter != null || _submittedBatchFilter != null;
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.border),
              boxShadow: AdminSurfaces.cardShadow,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _submittedSearchController,
                    onChanged: (_) => setState(() => _submittedPage = 0),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AdminColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          'Search submitted responses by name, email, course, or batch…',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AdminColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AdminColors.textMuted,
                      ),
                      suffixIcon: _submittedSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _submittedSearchController.clear();
                                setState(() => _submittedPage = 0);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AdminColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AdminColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AdminColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AdminColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _pendingFilterChip(
                      label: _submittedProgramFilter == null
                          ? 'Course: All'
                          : 'Course: $_submittedProgramFilter',
                      selected: _submittedProgramFilter != null,
                      onTap: _pickSubmittedProgramFilter,
                    ),
                    _pendingFilterChip(
                      label: _submittedBatchFilter == null
                          ? 'Batch: All'
                          : 'Batch: $_submittedBatchFilter',
                      selected: _submittedBatchFilter != null,
                      onTap: _pickSubmittedBatchFilter,
                    ),
                    _pendingFilterChip(
                      label: 'Sort: ${_submittedSort.label}',
                      selected: false,
                      onTap: _pickSubmittedSort,
                    ),
                    if (hasFilters || hasQuery)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _submittedSearchController.clear();
                            _submittedProgramFilter = null;
                            _submittedBatchFilter = null;
                            _submittedPage = 0;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text(
                          'Reset',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AdminColors.textSecondary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            allSubmitted.isEmpty
                ? 'No submissions'
                : 'Showing ${list.length} of ${allSubmitted.length} submitted responses',
            style: AdminText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AdminColors.textMuted,
            ),
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
                      : 'Try clearing search or filters to find responses.',
                  icon: allSubmitted.isEmpty
                      ? Icons.inbox_outlined
                      : Icons.search_off_outlined,
                  actionLabel: (hasQuery || hasFilters) && allSubmitted.isNotEmpty
                      ? 'Clear search & filters'
                      : null,
                  onAction: (hasQuery || hasFilters) && allSubmitted.isNotEmpty
                      ? () {
                          _submittedSearchController.clear();
                          setState(() {
                            _submittedProgramFilter = null;
                            _submittedBatchFilter = null;
                            _submittedPage = 0;
                          });
                        }
                      : null,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SurveyResponsesTableFrame(
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
                              onViewResponse: () =>
                                  _openSubmittedResponseDetail(
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
    if (_submittedProgramFilter != null) {
      list = list.where((p) => p.program == _submittedProgramFilter).toList();
    }
    if (_submittedBatchFilter != null) {
      list = list.where((p) => p.batchYear == _submittedBatchFilter).toList();
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
    if (!await confirmPersonalDataExport(
          context,
          what: 'This response file',
        ) ||
        !mounted) {
      return;
    }

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
      _showSnack(
        surveyExportErrorMessage('this response file', e),
        color: AdminColors.danger,
      );
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
      subtitle: surveyResponseMetaLine(participant, r),
      response: r,
      isChedBuiltin: isChedBuiltin,
      questions: _questions,
      visibilityRules: _survey?.visibilityRules ?? const {},
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
  AdminDataColumn(label: 'TIME TO SUBMIT', width: 116),
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
          Tooltip(
            message: 'Time from assignment to submission',
            child: AdminTableTextCell(_durationLabel(p, r), muted: true),
          ),
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

/// Overview "Outputs" entry: icon · label · chevron; disabled when [onTap] is null.
class _OverviewLinkRow extends StatelessWidget {
  const _OverviewLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? AdminColors.textPrimary : AdminColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: enabled
                        ? AdminColors.primary.withValues(alpha: 0.08)
                        : AdminColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: enabled
                          ? AdminColors.primary.withValues(alpha: 0.15)
                          : AdminColors.border,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: enabled
                        ? AdminColors.primary
                        : AdminColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AdminText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AdminColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Fix before publishing" for the Overview; pops `true` to open the editor.
class _OverviewPublishProblemsDialog extends StatelessWidget {
  const _OverviewPublishProblemsDialog({
    required this.problems,
    required this.canOpenEditor,
  });

  final List<SurveyPublishProblem> problems;
  final bool canOpenEditor;

  static const _maxListed = 8;

  @override
  Widget build(BuildContext context) {
    final listed = problems.take(_maxListed).toList();
    final more = problems.length - listed.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminColors.warningBg,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
                child: const Icon(
                  Icons.rule_outlined,
                  size: 20,
                  color: AdminColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Semantics(
                    header: true,
                    child: const Text(
                      'Fix before publishing',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Alumni can\'t answer this survey yet:',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in listed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AdminColors.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.message, style: AdminText.body)),
                ],
              ),
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text('+ $more more', style: AdminText.caption),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  autofocus: !canOpenEditor,
                  onPressed: () => Navigator.of(context).pop(),
                  style: AdminButtonStyles.outlined(),
                  child: const Text('Close'),
                ),
                if (canOpenEditor)
                  FilledButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(true),
                    style: AdminButtonStyles.filled(),
                    child: const Text('Open in editor'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lists per-recipient reminder failures returned by `sendReminders`.
class _ReminderFailuresDialog extends StatelessWidget {
  const _ReminderFailuresDialog({required this.failures});

  final List<String> failures;

  @override
  Widget build(BuildContext context) {
    final count = failures.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminColors.warningBg,
                  borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AdminColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    count == 1
                        ? '1 reminder failed'
                        : '$count reminders failed',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The others were sent. These could not be delivered:',
            style: AdminText.body.copyWith(color: AdminColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                border: Border.all(color: AdminColors.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: count,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AdminColors.border),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(failures[i], style: AdminText.body),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              style: AdminButtonStyles.filled(),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
      children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AdminSurveyTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AdminSurveyTheme.primary,
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AdminSurveyTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: AdminSurveyTheme.textMuted,
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
      ),
    );
  }
}
