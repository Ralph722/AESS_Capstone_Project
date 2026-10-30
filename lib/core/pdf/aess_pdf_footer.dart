import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/pdf/aess_pdf_theme.dart';
import 'package:alumni_system/core/utils/personal_data_notice.dart';

/// Standard institutional footer for all AESS PDF documents.
abstract final class AessPdfFooter {
  AessPdfFooter._();

  static const String administrativeNotice =
      'Official Institutional Document. For authorized university administrative & academic evaluation only.';

  /// Unified footer builder matching the institutional reporting standard.
  static pw.Widget build(
    pw.Context ctx, {
    bool containsPersonalData = false,
    String? customNotice,
  }) {
    final noticeText = containsPersonalData
        ? personalDataNotice
        : (customNotice ?? administrativeNotice);

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(
          color: AessPdfTheme.borderColor,
          thickness: 0.6,
          height: 0.6,
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Left: Notice / Data Privacy
            pw.Expanded(
              flex: 4,
              child: pw.Text(
                noticeText,
                style: containsPersonalData
                    ? AessPdfTheme.footerNoticePersonal
                    : AessPdfTheme.footerNotice,
              ),
            ),
            pw.SizedBox(width: 8),

            // Center: System tag
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                'AESS v2.0 · University Tracer System',
                textAlign: pw.TextAlign.center,
                style: AessPdfTheme.footerNotice,
              ),
            ),
            pw.SizedBox(width: 8),

            // Right: Pagination
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                textAlign: pw.TextAlign.right,
                style: AessPdfTheme.footerPageNumber,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

