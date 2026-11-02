import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/pdf/aess_pdf_theme.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';

/// Institutional header banner applied across all official AESS PDF reports.
abstract final class AessPdfHeader {
  AessPdfHeader._();

  static const String universityName =
      'UNIVERSITY OF SCIENCE AND TECHNOLOGY OF SOUTHERN PHILIPPINES';
  static const String systemName =
      'ALUMNI ENGAGEMENT AND SUPPORT SYSTEM (AESS) - OFFICIAL REPORTING';

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

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Top Institutional Bar
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    universityName,
                    style: AessPdfTheme.superTitle,
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    systemName,
                    style: AessPdfTheme.systemSubline,
                  ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2.5,
              ),
              decoration: pw.BoxDecoration(
                color: AessPdfTheme.bannerBg,
                border: pw.Border.all(
                  color: AessPdfTheme.borderColor,
                  width: 0.5,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(
                PdfSafeText.sanitize(classification),
                style: pw.TextStyle(
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                  color: AessPdfTheme.secondaryNavy,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // Report Title and Metadata
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    safeTitle,
                    style: AessPdfTheme.reportTitle,
                  ),
                  if (safeSubtitle != null && safeSubtitle.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      safeSubtitle,
                      style: AessPdfTheme.reportSubtitle,
                    ),
                  ],
                ],
              ),
            ),
            if (safeDate != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: $safeDate',
                      style: AessPdfTheme.reportSubtitle,
                    ),
                  ],
                ),
              ),
          ],
        ),

        // Filter Summary (if present)
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
        // Clean dual-tone rule
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

