import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Centralized visual style and design constants for official AESS PDF reports.
///
/// Ensures all reports adhere to a consistent, institutional University
/// standard (USTP / AESS).
abstract final class AessPdfTheme {
  AessPdfTheme._();

  // —— Institutional Color Palette ——
  static const primaryNavy = PdfColor.fromInt(0xFF1B365D);
  static const secondaryNavy = PdfColor.fromInt(0xFF2C5282);
  static const slateBlue = PdfColor.fromInt(0xFF3B82F6);
  static const accentGold = PdfColor.fromInt(0xFFD97706);

  static const headerBg = PdfColor.fromInt(0xFF1B365D);
  static const subHeaderBg = PdfColor.fromInt(0xFF243B55);
  static const lightHeaderBg = PdfColor.fromInt(0xFFF1F5F9);

  static const zebraBg = PdfColor.fromInt(0xFFF8FAFC);
  static const cardBg = PdfColor.fromInt(0xFFF8FAFC);
  static const bannerBg = PdfColor.fromInt(0xFFF1F5F9);

  static const borderColor = PdfColor.fromInt(0xFFE2E8F0);
  static const borderDark = PdfColor.fromInt(0xFFCBD5E1);

  static const textDark = PdfColor.fromInt(0xFF0F172A);
  static const textSecondary = PdfColor.fromInt(0xFF334155);
  static const textMuted = PdfColor.fromInt(0xFF64748B);
  static const textWhite = PdfColors.white;

  static const dangerRed = PdfColor.fromInt(0xFF991B1B);
  static const successGreen = PdfColor.fromInt(0xFF166534);

  // —— Page Margins ——
  static const pageMargin = pw.EdgeInsets.all(26);
  static const pageMarginLandscape = pw.EdgeInsets.symmetric(
    horizontal: 26,
    vertical: 24,
  );

  // —— Typography ——
  static pw.TextStyle get superTitle => pw.TextStyle(
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        color: secondaryNavy,
        letterSpacing: 0.5,
      );

  static pw.TextStyle get systemSubline => pw.TextStyle(
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: primaryNavy,
        letterSpacing: 0.3,
      );

  static pw.TextStyle get reportTitle => pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: primaryNavy,
      );

  static pw.TextStyle get reportSubtitle => const pw.TextStyle(
        fontSize: 8.5,
        color: textMuted,
      );

  static pw.TextStyle get sectionHeading => pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: primaryNavy,
      );

  static pw.TextStyle get subSectionHeading => pw.TextStyle(
        fontSize: 9.5,
        fontWeight: pw.FontWeight.bold,
        color: textDark,
      );

  static pw.TextStyle get tableHeader => pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: textWhite,
      );

  static pw.TextStyle get tableHeaderDark => pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: primaryNavy,
      );

  static pw.TextStyle get tableCell => const pw.TextStyle(
        fontSize: 7.5,
        color: textDark,
        lineSpacing: 1.1,
      );

  static pw.TextStyle get tableCellBold => pw.TextStyle(
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        color: textDark,
        lineSpacing: 1.1,
      );

  static pw.TextStyle get tableCellMuted => const pw.TextStyle(
        fontSize: 7,
        color: textMuted,
      );

  static pw.TextStyle get kpiValue => pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: primaryNavy,
      );

  static pw.TextStyle get kpiLabel => pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: textSecondary,
        letterSpacing: 0.2,
      );

  static pw.TextStyle get footerNotice => const pw.TextStyle(
        fontSize: 7,
        color: textMuted,
      );

  static pw.TextStyle get footerNoticePersonal => pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: dangerRed,
      );

  static pw.TextStyle get footerPageNumber => pw.TextStyle(
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        color: textMuted,
      );

  static pw.TextStyle get caption => const pw.TextStyle(
        fontSize: 7.5,
        color: textMuted,
      );

  // —— Table & Card Dimensions ——
  static const cellPadding = pw.EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 4.5,
  );
  static const cellPaddingCompact = pw.EdgeInsets.symmetric(
    horizontal: 4.5,
    vertical: 3.5,
  );
}
