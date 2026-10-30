import 'package:pdf/widgets.dart' as pw;
import 'package:alumni_system/core/pdf/aess_pdf_footer.dart';

/// Footer printed on files that list graduates by name or contact details.
const personalDataNotice =
    'Contains personal data. For authorized alumni office use only; '
    'handle under the Data Privacy Act of 2012 (RA 10173).';

/// PDF page footer: the personal-data notice (when [personal]) and the page
/// number, following the institutional AESS reporting design.
pw.Widget pdfPageFooter(pw.Context ctx, {bool personal = true}) =>
    AessPdfFooter.build(ctx, containsPersonalData: personal);
