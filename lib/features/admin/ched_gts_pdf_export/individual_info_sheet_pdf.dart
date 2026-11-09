import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:alumni_system/core/pdf/aess_pdf_components.dart';
import 'package:alumni_system/core/utils/pdf_safe_text.dart';
import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_option_maps.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/data/survey_answer_display.dart';

/// Institutional Membership Form PDF (CHED Section A + Q12).
///
/// Layout follows a membership-style boxed form. Header/footer use the
/// system letterhead ([AessPdfHeader] / [AessPdfFooter]), not the paper
/// reference's social strip or Vision/Mission block.
abstract final class IndividualInfoSheetPdf {
  IndividualInfoSheetPdf._();

  static const reportTitle = 'Membership Form';

  static const declarationText =
      'I hereby certify that the information provided is true and correct to '
      'the best of my knowledge. By signing this form, as a proud graduate of '
      'the University of Science and Technology of Southern Philippines, '
      'Oroquieta City Campus, I pledge my unwavering loyalty and commitment to '
      'the USTP Alumni Association Oroquieta Campus Inc. I promise to uphold '
      'the values of integrity, excellence, and responsibility instilled in me '
      'by the university, ensuring that these principles guide my personal and '
      'professional endeavors. With pride in my alma mater, I will serve as an '
      'ambassador of USTP, promoting its reputation and contributing to its '
      'continued success.';

  static const _boxBorder = PdfColor.fromInt(0xFF1A1851);
  static const _labelColor = PdfColor.fromInt(0xFF64748B);

  /// Build a filled one-person sheet from assembled `ched_*` [answers].
  static Future<Uint8List> build({
    required Map<String, dynamic> answers,
    String? alumniName,
    DateTime? generatedAt,
  }) async {
    await AessPdfHeader.ensureLoaded();
    final when = generatedAt ?? DateTime.now();
    final fmt = DateFormat.yMMMd().add_jm();
    final birth = parseBirthdayParts(answers['ched_8']);
    final eduRows = educationRows(answers['ched_12']);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(26, 22, 26, 22),
        header: (ctx) => AessPdfHeader.build(
          title: reportTitle,
          generationDate: fmt.format(when),
          classification: 'CONFIDENTIAL',
        ),
        footer: (ctx) => AessPdfFooter.build(
          ctx,
          containsPersonalData: true,
        ),
        build: (ctx) => [
          _sectionTitle('GENERAL INFORMATION'),
          pw.SizedBox(height: 6),
          _boxedField('Name', _text(answers['ched_1'], fallback: alumniName)),
          pw.SizedBox(height: 4),
          _boxedField(
            'Permanent Address',
            _text(answers['ched_2']),
            minHeight: 36,
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _boxedField('E-mail Address', _text(answers['ched_3'])),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: _boxedField(
                  'Telephone / Contact Number(s)',
                  _text(answers['ched_4']),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _boxedField('Mobile Number', _text(answers['ched_5'])),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: _boxedField('Civil Status', _text(answers['ched_6'])),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: _boxedField('Sex', _text(answers['ched_7'])),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: _birthdayBoxes(birth),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                flex: 2,
                child: _boxedField(
                  'Region of Origin',
                  _text(answers['ched_9']),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                flex: 2,
                child: _boxedField('Province', _text(answers['ched_10'])),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          _boxedField(
            'Location of Residence',
            _text(answers['ched_11']),
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('EDUCATIONAL BACKGROUND'),
          pw.SizedBox(height: 6),
          _educationTable(eduRows),
          pw.SizedBox(height: 14),
          _sectionTitle('DECLARATION'),
          pw.SizedBox(height: 6),
          pw.Text(
            PdfSafeText.sanitize(declarationText),
            style: const pw.TextStyle(
              fontSize: 8,
              height: 1.35,
              color: AessPdfTheme.textSecondary,
            ),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: _signatureBlock(
                            'SIGNATURE OVER PRINTED NAME',
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          flex: 2,
                          child: _signatureBlock('DATE'),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 14),
                    _officialUseOnly(),
                  ],
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Suggested download filename.
  static String suggestFileName({
    required String displayName,
    String? surveyLabel,
    DateTime? when,
  }) {
    final stamp = DateFormat('yyyy-MM-dd').format(when ?? DateTime.now());
    final name = _slug(displayName).isEmpty ? 'Alumni' : _slug(displayName);
    final wave = surveyLabel == null || surveyLabel.trim().isEmpty
        ? ''
        : '-${_slug(surveyLabel)}';
    return 'Membership-Form-$name$wave-$stamp.pdf';
  }

  /// Month / day / year parts from a stored birthday answer.
  static ({String month, String day, String year}) parseBirthdayParts(
    dynamic raw,
  ) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return (month: '', day: '', year: '');
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (iso != null) {
      return (year: iso.group(1)!, month: iso.group(2)!, day: iso.group(3)!);
    }
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (slash != null) {
      return (
        month: slash.group(1)!.padLeft(2, '0'),
        day: slash.group(2)!.padLeft(2, '0'),
        year: slash.group(3)!,
      );
    }
    return (month: '', day: '', year: '');
  }

  /// Normalized Q12 education rows.
  static List<Map<String, String>> educationRows(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final degree = _cell(row, kChedGtsPdfEduDegreeCol);
      final college = _cell(row, kChedGtsPdfEduCollegeCol);
      final year = _cell(row, kChedGtsPdfEduYearCol);
      final honors = _cell(row, kChedGtsPdfEduHonorsCol);
      if (degree.isEmpty &&
          college.isEmpty &&
          year.isEmpty &&
          honors.isEmpty) {
        continue;
      }
      out.add({
        kChedGtsPdfEduDegreeCol: degree,
        kChedGtsPdfEduCollegeCol: college,
        kChedGtsPdfEduYearCol: year,
        kChedGtsPdfEduHonorsCol: honors,
      });
    }
    return out;
  }

  static String _cell(Map<String, dynamic> row, String key) =>
      row[key]?.toString().trim() ?? '';

  static String _text(dynamic value, {String? fallback}) {
    final formatted = formatSurveyAnswerValue(value).trim();
    if (formatted.isNotEmpty) return PdfSafeText.sanitize(formatted);
    final fb = fallback?.trim() ?? '';
    return fb.isEmpty ? '' : PdfSafeText.sanitize(fb);
  }

  static String _slug(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]+'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    return cleaned.isEmpty ? '' : cleaned;
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: AessPdfTheme.primaryNavy,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static pw.Widget _boxedField(
    String label,
    String value, {
    double minHeight = 28,
  }) {
    return pw.Container(
      constraints: pw.BoxConstraints(minHeight: minHeight),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _boxBorder, width: 0.9),
      ),
      padding: const pw.EdgeInsets.fromLTRB(5, 3, 5, 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(
              fontSize: 6.5,
              color: _labelColor,
              letterSpacing: 0.2,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value.isEmpty ? ' ' : value,
            style: const pw.TextStyle(
              fontSize: 9,
              color: AessPdfTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _birthdayBoxes(
    ({String month, String day, String year}) birth,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _boxBorder, width: 0.9),
      ),
      padding: const pw.EdgeInsets.fromLTRB(5, 3, 5, 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'BIRTHDAY',
            style: const pw.TextStyle(
              fontSize: 6.5,
              color: _labelColor,
              letterSpacing: 0.2,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              pw.Expanded(child: _miniPart('Month', birth.month)),
              pw.SizedBox(width: 3),
              pw.Expanded(child: _miniPart('Day', birth.day)),
              pw.SizedBox(width: 3),
              pw.Expanded(child: _miniPart('Year', birth.year)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniPart(String label, String value) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _boxBorder, width: 0.7),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(fontSize: 5.5, color: _labelColor),
          ),
          pw.Text(
            value.isEmpty ? ' ' : value,
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: AessPdfTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _educationTable(List<Map<String, String>> rows) {
    final displayRows = rows.isEmpty
        ? [
            {
              kChedGtsPdfEduDegreeCol: '',
              kChedGtsPdfEduCollegeCol: '',
              kChedGtsPdfEduYearCol: '',
              kChedGtsPdfEduHonorsCol: '',
            },
          ]
        : rows;

    pw.Widget cell(String label, String value, {int flex = 1}) {
      return pw.Expanded(
        flex: flex,
        child: pw.Container(
          constraints: const pw.BoxConstraints(minHeight: 30),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _boxBorder, width: 0.8),
          ),
          padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                label.toUpperCase(),
                style: const pw.TextStyle(fontSize: 5.5, color: _labelColor),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                value.isEmpty ? ' ' : PdfSafeText.sanitize(value),
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: AessPdfTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      children: [
        for (var i = 0; i < displayRows.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 3),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              cell(
                'Degree(s) & Specialization(s)',
                displayRows[i][kChedGtsPdfEduDegreeCol] ?? '',
                flex: 3,
              ),
              cell(
                'College or University',
                displayRows[i][kChedGtsPdfEduCollegeCol] ?? '',
                flex: 3,
              ),
              cell(
                'Year Graduated',
                displayRows[i][kChedGtsPdfEduYearCol] ?? '',
                flex: 1,
              ),
              cell(
                'Honor(s) or Award(s)',
                displayRows[i][kChedGtsPdfEduHonorsCol] ?? '',
                flex: 2,
              ),
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _signatureBlock(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: 28,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _boxBorder, width: 0.9),
            ),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          label,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: AessPdfTheme.textDark,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  static pw.Widget _officialUseOnly() {
    pw.Widget line(String label) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 88,
              child: pw.Text(
                label,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: AessPdfTheme.textDark,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                height: 12,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: _boxBorder, width: 0.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _boxBorder, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'FOR OFFICIAL USE ONLY',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: AessPdfTheme.primaryNavy,
              letterSpacing: 0.4,
            ),
          ),
          pw.SizedBox(height: 8),
          line('Date Received'),
          line('OR Number'),
          line('Processed By'),
          line('Remarks'),
        ],
      ),
    );
  }
}

/// Section A item ids used by the individual information sheet.
List<String> get individualInfoSectionAIds => [
  for (final item in ChedGtsBuiltin.items)
    if (item.section == ChedGtsSection.a && !item.isOthersSpecify) item.id,
];
