import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_text_fit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('ChedGtsPdfTextFit', () {
    test('fits USTP college name in collegeUniversity-sized widget', () {
      const text =
          'University of Science and Technology of Southern Philippines';
      // Official collegeUniversity Rect ≈ 220 × 14 pt.
      final fit = ChedGtsPdfTextFit.fit(
        text: text,
        width: 220,
        height: 14,
      );

      expect(fit.fits, isTrue);
      expect(fit.multiline, isFalse);
      expect(fit.fontSize, lessThan(ChedGtsPdfTextFit.preferredFontSize));
      expect(fit.fontSize, greaterThanOrEqualTo(ChedGtsPdfTextFit.minimumFontSize));

      final font = PdfStandardFont(PdfFontFamily.helvetica, fit.fontSize);
      expect(font.measureString(text).width, lessThanOrEqualTo(216));
    });

    test('fits long degree in degree-sized widget', () {
      const text = 'Bachelor of Science in Information Technology';
      final fit = ChedGtsPdfTextFit.fit(text: text, width: 260, height: 14);
      expect(fit.fits, isTrue);
      expect(fit.fontSize, greaterThanOrEqualTo(ChedGtsPdfTextFit.minimumFontSize));
    });

    test('wraps long curriculum suggestions in tall multiline field', () {
      const text =
          'Strengthen industry partnerships, expand internship placements, '
          'modernize laboratory equipment for networking and cloud computing, '
          'and add soft-skills workshops aligned with employer feedback.';
      // curriculumSuggestions ≈ 500 × 56 pt, already multiline in template.
      final fit = ChedGtsPdfTextFit.fit(
        text: text,
        width: 500,
        height: 56,
        templateMultiline: true,
      );

      expect(fit.fits, isTrue);
      expect(fit.multiline, isTrue);
      expect(fit.lineCount, greaterThan(1));
    });

    test('wrapLines never drops characters from long tokens', () {
      const token = 'SupercalifragilisticexpialidociousInstitutionName';
      final font = PdfStandardFont(PdfFontFamily.helvetica, 9);
      final lines = ChedGtsPdfTextFit.wrapLines(token, font, 80);
      expect(lines.join(), token);
      expect(lines.length, greaterThan(1));
    });

    test('reports overflow without shrinking below minimum', () {
      final huge = List.filled(40, 'Department of Information').join(' ');
      final fit = ChedGtsPdfTextFit.fit(text: huge, width: 100, height: 14);
      expect(fit.fontSize, ChedGtsPdfTextFit.minimumFontSize);
      expect(fit.fits, isFalse);
      expect(fit.overflowDetail, isNotNull);
    });
  });
}
