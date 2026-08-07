import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChedGtsPdfFillEngine', () {
    test('fills text, radio, checkbox, combo from mapped values', () async {
      final template = await rootBundle.load(
        ChedGtsPdfTemplate.assetPath,
      );
      final result = await ChedGtsPdfFillEngine.fillMapped(
        templateBytes: template.buffer.asUint8List(),
        values: {
          'fullName': 'Ralph Jezron A. Juab',
          'email': 'rauljuab@gmail.com',
          'region': 'ARMM',
          'civilStatus': '/single',
          'sex': '/male',
          'employmentStatus': '/unemployed',
          'firstJobDuration': '/lt1mo',
          'initialSalary': '/lt5k',
          'courseReasons__passion': '/Yes',
          'unemployedReasons__further-study': '/Yes',
          'businessLine': 'Education',
        },
      );

      expect(result.bytes.length, greaterThan(1000));
      expect(result.appliedFieldCount, 11);

      final doc = PdfDocument(inputBytes: result.bytes);
      try {
        final form = doc.form;
        PdfField field(String name) {
          for (var i = 0; i < form.fields.count; i++) {
            if (form.fields[i].name == name) return form.fields[i];
          }
          fail('missing $name');
        }

        expect((field('fullName') as PdfTextBoxField).text, 'Ralph Jezron A. Juab');
        expect((field('email') as PdfTextBoxField).text, 'rauljuab@gmail.com');
        expect((field('region') as PdfTextBoxField).text, 'ARMM');
        expect(
          (field('civilStatus') as PdfRadioButtonListField).selectedValue,
          'single',
        );
        expect((field('sex') as PdfRadioButtonListField).selectedValue, 'male');
        expect(
          (field('employmentStatus') as PdfRadioButtonListField).selectedValue,
          'unemployed',
        );
        expect(
          (field('courseReasons__passion') as PdfCheckBoxField).isChecked,
          isTrue,
        );
        expect(
          (field('unemployedReasons__further-study') as PdfCheckBoxField)
              .isChecked,
          isTrue,
        );
        expect(
          (field('businessLine') as PdfTextBoxField).text,
          'Education',
        );

        // Duration / salary radio values use lt* slugs (no '<' encoding).
        final duration =
            field('firstJobDuration') as PdfRadioButtonListField;
        expect(duration.selectedValue, 'lt1mo');
        final salary = field('initialSalary') as PdfRadioButtonListField;
        expect(salary.selectedValue, 'lt5k');
      } finally {
        doc.dispose();
      }
    });

    test('fillFromAnswers integrates assembler mapper path', () async {
      final template = await rootBundle.load(
        ChedGtsPdfTemplate.assetPath,
      );
      final result = await ChedGtsPdfFillEngine.fillFromAnswers(
        templateBytes: template.buffer.asUint8List(),
        answers: {
          'ched_1': 'Jane Doe',
          'ched_3': 'jane@school.edu',
          'ched_6': 'Married',
          'ched_7': 'Female',
          'ched_9': 'ARMM',
          'ched_16': 'Yes',
          'ched_18': 'Regular or Permanent',
          'ched_19': 'Teacher',
          'ched_20': 'Education',
          'ched_21': 'Local',
          'ched_22': 'Yes',
          'ched_23': ['Salaries and benefits'],
          'ched_24a': 'Yes',
          'ched_27': 'Less than a month',
          'ched_28': 'As walk-in applicant',
          'ched_29': '1 to 6 months',
          'ched_30': {
            'Rank or Clerical': {
              '30.1. First Job': true,
              '30.2. Current or Present Job': false,
            },
            'Professional, Technical or Supervisory': {
              '30.1. First Job': false,
              '30.2. Current or Present Job': true,
            },
          },
          'ched_31': 'Below P5,000.00',
          'ched_32': 'Yes',
          'ched_33': ['Communication skills'],
          'ched_34': 'More labs',
        },
      );

      expect(result.appliedFieldCount, greaterThan(10));
      expect(result.mapped, isNotNull);
      expect(result.mapped!.values['fullName'], 'Jane Doe');
      expect(result.mapped!.values['region'], 'ARMM');

      final doc = PdfDocument(inputBytes: result.bytes);
      try {
        PdfField? byName(String name) {
          for (var i = 0; i < doc.form.fields.count; i++) {
            if (doc.form.fields[i].name == name) return doc.form.fields[i];
          }
          return null;
        }

        expect((byName('fullName') as PdfTextBoxField).text, 'Jane Doe');
        expect(
          (byName('civilStatus') as PdfRadioButtonListField).selectedValue,
          'married',
        );
        expect(
          (byName('stayingReasons__salary') as PdfCheckBoxField).isChecked,
          isTrue,
        );
        expect(
          (byName('firstJobLevel') as PdfRadioButtonListField).selectedValue,
          'rank',
        );
        expect(
          (byName('currentJobLevel') as PdfRadioButtonListField).selectedValue,
          'professional',
        );
        expect(
          (byName('curriculumSuggestions') as PdfTextBoxField).text,
          'More labs',
        );
      } finally {
        doc.dispose();
      }
    });

    test('suggestFileName slugs identity and date', () {
      expect(
        ChedGtsPdfFillEngine.suggestFileName(
          displayName: 'Ralph Jezron A. Juab',
          surveyLabel: 'CHED GTS 2026',
          when: DateTime(2026, 7, 25),
        ),
        'GTS-Ralph-Jezron-A-Juab-CHED-GTS-2026-2026-07-25.pdf',
      );
    });

    test('long text answers are stored complete with fitted font', () async {
      const college =
          'University of Science and Technology of Southern Philippines';
      const degree = 'Bachelor of Science in Information Technology';
      const address =
          'Block 12 Lot 45, Purok Mabuhay, Barangay Carmen, '
          'Cagayan de Oro City, Misamis Oriental 9000';
      const suggestions =
          'Add more industry immersion hours, upgrade laboratory facilities '
          'for cybersecurity and cloud computing, and expand soft-skills '
          'workshops based on employer tracer feedback from partner agencies.';
      // Longer than template MaxLen (100).
      expect(suggestions.length, greaterThan(100));

      final template = await rootBundle.load(ChedGtsPdfTemplate.assetPath);
      final result = await ChedGtsPdfFillEngine.fillMapped(
        templateBytes: template.buffer.asUint8List(),
        flatten: true,
        values: {
          'collegeUniversity': college,
          'degree': degree,
          'permanentAddress': address,
          'honors':
              'Department of Information and Communications Technology Scholar',
          'curriculumSuggestions': suggestions,
          'selfEmployedSkills':
              'Full-stack web development, network administration, '
              'and technical training facilitation for LGUs',
          'occupation':
              'Information Systems Analyst III / Project Technical Lead',
        },
      );

      expect(result.appliedFieldCount, 7);
      // Narrow table cells (e.g. honors) may still log OVERFLOW at min font;
      // the fill engine must preserve the complete value either way.
      final overflowNotes =
          result.notes.where((n) => n.startsWith('OVERFLOW')).toList();
      for (final note in overflowNotes) {
        expect(note, contains('value preserved in full'));
      }

      final doc = PdfDocument(inputBytes: result.bytes);
      try {
        // Flattened print-ready PDFs remove AcroForm fields.
        expect(doc.form.fields.count, 0);
      } finally {
        doc.dispose();
      }

      // Fillable path still exposes complete values + reduced font.
      final fillable = await ChedGtsPdfFillEngine.fillMapped(
        templateBytes: template.buffer.asUint8List(),
        flatten: false,
        values: {
          'collegeUniversity': college,
          'degree': degree,
          'permanentAddress': address,
          'curriculumSuggestions': suggestions,
        },
      );

      final live = PdfDocument(inputBytes: fillable.bytes);
      try {
        PdfTextBoxField textField(String name) {
          for (var i = 0; i < live.form.fields.count; i++) {
            final f = live.form.fields[i];
            if (f.name == name) return f as PdfTextBoxField;
          }
          fail('missing $name');
        }

        final collegeField = textField('collegeUniversity');
        expect(collegeField.text, college);
        expect(collegeField.maxLength, 0);
        expect(
          collegeField.font.size,
          lessThan(ChedGtsPdfTextFit.preferredFontSize),
        );
        expect(
          collegeField.font.size,
          greaterThanOrEqualTo(ChedGtsPdfTextFit.minimumFontSize),
        );

        expect(textField('degree').text, degree);
        expect(textField('permanentAddress').text, address);
        expect(textField('curriculumSuggestions').text, suggestions);
        expect(textField('curriculumSuggestions').multiline, isTrue);
      } finally {
        live.dispose();
      }
    });
  });
}
