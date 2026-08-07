import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:alumni_system/core/config/ai_config.dart';
import 'package:alumni_system/core/utils/export_platform.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/features/surveys/data/survey_formal_report_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

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

class _SurveyFormalReportDialog extends StatefulWidget {
  const _SurveyFormalReportDialog({
    required this.survey,
    required this.questions,
    required this.participants,
    required this.responses,
  });

  final Survey survey;
  final List<SurveyQuestion> questions;
  final List<SurveyParticipant> participants;
  final List<SurveyResponse> responses;

  @override
  State<_SurveyFormalReportDialog> createState() =>
      _SurveyFormalReportDialogState();
}

class _SurveyFormalReportDialogState extends State<_SurveyFormalReportDialog> {
  final _service = SurveyFormalReportService();
  final _controller = TextEditingController();
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  SurveyFormalReportResult? _result;

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
      final result = await _service.generate(
        survey: widget.survey,
        questions: widget.questions,
        participants: widget.participants,
        responses: widget.responses,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _controller.text = result.body;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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
      const SnackBar(content: Text('Report copied to clipboard')),
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
          const SnackBar(content: Text('Formal report PDF downloaded')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
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

    return Dialog(
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
                        const Text(
                          'Formal survey report',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AdminSurveyTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.survey.title.trim().isEmpty
                              ? 'Untitled survey'
                              : widget.survey.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AdminSurveyTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (!AiConfig.isConfigured)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Text(
                  'Gemini API key not configured — a metric-based formal draft '
                  'will still be generated for you to edit.',
                  style: TextStyle(fontSize: 12.5, height: 1.35),
                ),
              ),
            if (result != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  result.disclaimer,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AdminSurveyTheme.textSecondary,
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
                    ? Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
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
                    onPressed: _loading || _exporting ? null : _generate,
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
                    onPressed: _loading ||
                            _exporting ||
                            _controller.text.trim().isEmpty
                        ? null
                        : () => _exportPdf(printPreview: true),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print'),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ||
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
    );
  }
}
