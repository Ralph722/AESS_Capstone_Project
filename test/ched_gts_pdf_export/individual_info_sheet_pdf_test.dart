import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IndividualInfoSheetPdf.parseBirthdayParts', () {
    test('parses ISO dates', () {
      final parts = IndividualInfoSheetPdf.parseBirthdayParts('1998-07-04');
      expect(parts.year, '1998');
      expect(parts.month, '07');
      expect(parts.day, '04');
    });

    test('parses slash dates', () {
      final parts = IndividualInfoSheetPdf.parseBirthdayParts('7/4/1998');
      expect(parts.year, '1998');
      expect(parts.month, '07');
      expect(parts.day, '04');
    });

    test('returns blanks for unknown formats', () {
      final parts = IndividualInfoSheetPdf.parseBirthdayParts('July 4, 1998');
      expect(parts.year, isEmpty);
      expect(parts.month, isEmpty);
      expect(parts.day, isEmpty);
    });
  });

  group('IndividualInfoSheetPdf.educationRows', () {
    test('keeps filled Q12 rows and drops empty maps', () {
      final rows = IndividualInfoSheetPdf.educationRows([
        {
          'Degree(s) & Specialization(s)': 'BSIT',
          'College or University': 'USTP',
          'Year Graduated': '2020',
          'Honor(s) or Award(s) Received': 'Cum Laude',
        },
        {
          'Degree(s) & Specialization(s)': '',
          'College or University': '',
          'Year Graduated': '',
          'Honor(s) or Award(s) Received': '',
        },
      ]);
      expect(rows, hasLength(1));
      expect(rows.first['Degree(s) & Specialization(s)'], 'BSIT');
      expect(rows.first['Year Graduated'], '2020');
    });
  });

  group('IndividualInfoSheetPdf.suggestFileName', () {
    test('includes name and date', () {
      expect(
        IndividualInfoSheetPdf.suggestFileName(
          displayName: 'Jane Doe',
          surveyLabel: 'CHED GTS',
          when: DateTime(2026, 11, 9),
        ),
        'Membership-Form-Jane-Doe-CHED-GTS-2026-11-09.pdf',
      );
    });
  });

  group('IndividualInfoSheetPdf.build', () {
    test('renders a non-empty PDF with Section A + Q12 answers', () async {
      expect(IndividualInfoSheetPdf.reportTitle, 'Membership Form');
      final bytes = await IndividualInfoSheetPdf.build(
        answers: {
          'ched_1': 'Jane Doe',
          'ched_2': 'Purok 6, Mobod, Oroquieta City',
          'ched_3': 'jane@example.com',
          'ched_4': '088-123-4567',
          'ched_5': '09171234567',
          'ched_6': 'Single',
          'ched_7': 'Female',
          'ched_8': '1998-07-04',
          'ched_9': 'Region 10',
          'ched_10': 'Misamis Occidental',
          'ched_11': 'City',
          'ched_12': [
            {
              'Degree(s) & Specialization(s)': 'BS Information Technology',
              'College or University': 'USTP Oroquieta',
              'Year Graduated': '2020',
              'Honor(s) or Award(s) Received': 'Cum Laude',
            },
          ],
        },
        alumniName: 'Jane Doe',
        generatedAt: DateTime(2026, 11, 9),
      );
      expect(bytes.length, greaterThan(1000));
      // PDF magic
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
