import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/data/survey_formal_report_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:alumni_system/shared/widgets/admin/admin_state_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';

/// Dialog: generate, edit, copy, and export a formal AI survey report.
Future<void> showAdminSurveyFormalReportDialog(
  BuildContext context, {
  required Survey survey,
  required List<SurveyQuestion> questions,
  required List<SurveyParticipant> participants,
  required List<SurveyResponse> responses,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SurveyFormalReportDialog(
      survey: survey,
      questions: questions,
      participants: participants,
      responses: responses,
    ),
  );
}

/// The dialog with a stand-in draft generator (no AI service).
@visibleForTesting
Widget surveyFormalReportDialogForTest({
  required Survey survey,
  required Future<SurveyFormalReportResult> Function() generate,
}) {
  return _SurveyFormalReportDialog(
    survey: survey,
    questions: const [],
    participants: const [],
    responses: const [],
    generateOverride: generate,
  );
}

class _SurveyFormalReportDialog extends StatefulWidget {
  const _SurveyFormalReportDialog({
    required this.survey,
    required this.questions,
    required this.participants,
    required this.responses,
    this.generateOverride,
  });

  final Survey survey;
  final List<SurveyQuestion> questions;
  final List<SurveyParticipant> participants;
  final List<SurveyResponse> responses;
  final Future<SurveyFormalReportResult> Function()? generateOverride;

  @override
  State<_SurveyFormalReportDialog> createState() =>
      _SurveyFormalReportDialogState();
}

class _SurveyFormalReportDialogState extends State<_SurveyFormalReportDialog> {
  late final _service = SurveyFormalReportService();
  final _controller = TextEditingController();
  bool _loading = true;
  bool _exporting = false;
  Object? _error;
  SurveyFormalReportResult? _result;

  /// Text as generated; anything else in the editor counts as an edit.
  String _generatedBody = '';

  bool get _hasEdits =>
      _result != null && _controller.text.trim() != _generatedBody.trim();

  Future<bool> _confirmDiscard({
    required String message,
    required String confirmLabel,
  }) {
    return showAdminConfirmDialog(
      context,
      title: 'Discard your edits?',
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: 'Keep editing',
      destructive: true,
      icon: Icons.edit_off_outlined,
    );
  }

  Future<void> _requestClose() async {
    if (_hasEdits &&
        !await _confirmDiscard(
          message: 'Your changes to the report text will be lost.',
          confirmLabel: 'Discard',
        )) {
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _requestRegenerate() async {
    if (_hasEdits &&
        !await _confirmDiscard(
          message: 'A new draft will replace the text you edited.',
          confirmLabel: 'Regenerate',
        )) {
      return;
    }
    if (mounted) await _generate();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _generate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final override = widget.generateOverride;
      final result = override != null
          ? await override()
          : await _service.generate(
              survey: widget.survey,
              questions: widget.questions,
              participants: widget.participants,
              responses: widget.responses,
            );
      if (!mounted) return;
      setState(() {
        _result = result;
        _generatedBody = result.body;
        _controller.text = result.body;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report copied to clipboard'),
        backgroundColor: AdminColors.success,
      ),
    );
  }

  Future<void> _exportPdf({required bool printPreview}) async {
    final result = _result;
    final body = _controller.text.trim();
    if (result == null || body.isEmpty) return;
    if (!printPreview && !requireWebExport(context)) return;

    setState(() => _exporting = true);
    try {
      final bytes = await SurveyFormalReportService.toPdf(
        surveyTitle: widget.survey.title.trim().isEmpty
            ? 'Untitled survey'
            : widget.survey.title,
        body: body,
        disclaimer: result.disclaimer,
        generatedAt: result.generatedAt,
        usedAi: result.usedAi,
      );
      if (!mounted) return;

      if (printPreview) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: _fileBase(),
        );
      } else {
        tryDownloadBytesOnWeb(
          context,
          bytes: bytes,
          fileName: '${_fileBase()}.pdf',
          mimeType: 'application/pdf',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formal report PDF downloaded'),
            backgroundColor: AdminColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final reason = e is Error ? '' : surveyFriendlyError(e, '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reason.isEmpty
                ? 'Couldn’t create the report PDF. Try again.'
                : 'Couldn’t create the report PDF. $reason',
          ),
          backgroundColor: AdminColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _fileBase() {
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final raw = widget.survey.title.trim().isEmpty
        ? 'Survey'
        : widget.survey.title.trim();
    final safe = raw
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'AESS_Formal_Report_${safe.isEmpty ? 'Survey' : safe}_$stamp';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final result = _result;

    return PopScope(
      canPop: !_hasEdits,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: wide ? 48 : 16,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 820,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AdminSurveyTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AdminSurveyTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Formal survey report',
                            style: AdminText.sectionTitle.copyWith(
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.survey.title.trim().isEmpty
                                ? 'Untitled survey'
                                : widget.survey.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdminText.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _requestClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (!AiConfig.isEnabled)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.warningBg,
                    borderRadius: BorderRadius.circular(AdminSurfaces.radiusSm),
                    border: Border.all(
                      color: AdminColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'AI is turned off in this build — a metric-based formal '
                    'draft will still be generated for you to edit.',
                    style: AdminText.caption.copyWith(
                      height: 1.35,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                ),
              if (result != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    result.disclaimer,
                    style: AdminText.caption.copyWith(
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _loading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Writing formal report…'),
                            ],
                          ),
                        )
                      : _error != null
                      ? AdminStateView.error(
                          title: 'Couldn’t write the report',
                          message: surveyFriendlyError(
                            _error!,
                            'Something went wrong while writing the draft. '
                            'Try again.',
                          ),
                          details: '$_error',
                          onRetry: _generate,
                        )
                      : TextField(
                          controller: _controller,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AdminSurveyTheme.surface,
                            hintText: 'Formal report text…',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AdminSurveyTheme.border,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: AdminSurveyTheme.textPrimary,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loading || _exporting
                          ? null
                          : _requestRegenerate,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Regenerate'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading || _controller.text.trim().isEmpty
                          ? null
                          : _copy,
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('Copy'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _loading ||
                              _exporting ||
                              _controller.text.trim().isEmpty
                          ? null
                          : () => _exportPdf(printPreview: true),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print'),
                    ),
                    FilledButton.icon(
                      onPressed:
                          _loading ||
                              _exporting ||
                              _controller.text.trim().isEmpty ||
                              !canExportFiles
                          ? null
                          : () => _exportPdf(printPreview: false),
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(_exporting ? 'Exporting…' : 'Download PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminSurveyTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
