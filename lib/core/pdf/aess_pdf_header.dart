import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/pdf/aess_pdf_theme.dart';
import 'package:alumni_system/core/pdf/ustp_oroquieta_letterhead_bytes.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';

/// Institutional header used by generated AESS PDF reports.
///
/// The banner is the Oroquieta Alumni Association letterhead from the office
/// template (R.01 Series of 2025). Report title, date, and filters stay under
/// that banner so each export is still identifiable.
abstract final class AessPdfHeader {
  AessPdfHeader._();

  /// Text used only when the letterhead image cannot be decoded.
  static const String universityName =
      'UNIVERSITY OF SCIENCE AND TECHNOLOGY OF SOUTHERN PHILIPPINES';
  static const String officeName =
      'OFFICE OF THE USTP-ALUMNI ASSOCIATION OROQUIETA CAMPUS INC.';
  static const String secRegistration = 'SEC REG. NO.: 2023070107993-00';

  static pw.MemoryImage? _letterhead;

  /// Decodes the embedded letterhead once. Call before building a PDF document.
  static Future<void> ensureLoaded() async {
    _letterhead ??= pw.MemoryImage(ustpOroquietaLetterheadPng);
  }

  /// Standard multi-line institutional header widget.
  static pw.Widget build({
    required String title,
    String? subtitle,
    String? generationDate,
    List<String> filterSummary = const [],
    String classification = 'OFFICIAL REPORT',
    bool isLandscape = false,
  }) {
    final safeTitle = PdfSafeText.sanitize(title);
    final safeSubtitle =
        subtitle != null ? PdfSafeText.sanitize(subtitle) : null;
    final safeDate =
        generationDate != null ? PdfSafeText.sanitize(generationDate) : null;
    final safeFilters = filterSummary.isNotEmpty
        ? PdfSafeText.sanitize('Filters: ${filterSummary.join(' | ')}')
        : null;
    final letterhead = _letterhead;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (letterhead != null)
          pw.Image(letterhead, fit: pw.BoxFit.fitWidth)
        else
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(universityName, style: AessPdfTheme.superTitle),
              pw.SizedBox(height: 1.5),
              pw.Text(officeName, style: AessPdfTheme.systemSubline),
              pw.SizedBox(height: 1.5),
              pw.Text(secRegistration, style: AessPdfTheme.reportSubtitle),
            ],
          ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(safeTitle, style: AessPdfTheme.reportTitle),
                  if (safeSubtitle != null && safeSubtitle.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(safeSubtitle, style: AessPdfTheme.reportSubtitle),
                  ],
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (classification.trim().isNotEmpty)
                    pw.Text(
                      PdfSafeText.sanitize(classification),
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                        color: AessPdfTheme.secondaryNavy,
                      ),
                    ),
                  if (safeDate != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Generated: $safeDate',
                      style: AessPdfTheme.reportSubtitle,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (safeFilters != null && safeFilters.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 3,
            ),
            decoration: const pw.BoxDecoration(
              color: AessPdfTheme.bannerBg,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Text(
              safeFilters,
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: AessPdfTheme.textSecondary,
              ),
            ),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Divider(
          color: AessPdfTheme.primaryNavy,
          thickness: 1.2,
          height: 1.2,
        ),
        pw.SizedBox(height: 1.5),
        pw.Divider(
          color: AessPdfTheme.borderColor,
          thickness: 0.5,
          height: 0.5,
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }
}
