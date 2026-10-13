import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Footer printed on files that list graduates by name or contact details.
const personalDataNotice =
    'Contains personal data. For authorized alumni office use only; '
    'handle under the Data Privacy Act of 2012 (RA 10173).';

/// PDF page footer: the personal-data notice (when [personal]) and the page
/// number.
pw.Widget pdfPageFooter(pw.Context ctx, {bool personal = true}) => pw.Row(
  children: [
    pw.Expanded(
      child: personal
          ? pw.Text(
              personalDataNotice,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.red800),
            )
          : pw.SizedBox(),
    ),
    pw.Text(
      'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    ),
  ],
);
