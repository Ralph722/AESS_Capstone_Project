import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/pdf/aess_pdf_theme.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/core/utils/personal_data_notice.dart';

/// Footer taken from the Oroquieta Alumni Association office template
/// (R.01 Series of 2025), plus page numbers for multi-page reports.
abstract final class AessPdfFooter {
  AessPdfFooter._();

  static const String addressLine1 = 'PUROK 6, MOBOD, OROQUIETA CITY';
  static const String addressLine2 = 'MISAMIS OCCIDENTAL';
  static const String addressLine3 = '7207';

  /// Unified footer builder matching the office letterhead.
  static pw.Widget build(
    pw.Context ctx, {
    bool containsPersonalData = false,
    String? customNotice,
  }) {
    final extra = PdfSafeText.sanitize(
      containsPersonalData
          ? personalDataNotice
          : (customNotice ?? ''),
    );

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (extra.isNotEmpty) ...[
          pw.Text(
            extra,
            style: containsPersonalData
                ? AessPdfTheme.footerNoticePersonal
                : AessPdfTheme.footerNotice,
          ),
          pw.SizedBox(height: 3),
        ],
        pw.Divider(
          color: AessPdfTheme.borderColor,
          thickness: 0.8,
          height: 0.8,
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final line in [
                    addressLine1,
                    addressLine2,
                    addressLine3,
                  ])
                    pw.Text(line, style: AessPdfTheme.footerAddress),
                ],
              ),
            ),
            pw.Text(
              'Page | ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: AessPdfTheme.footerPageNumber,
            ),
          ],
        ),
      ],
    );
  }
}
