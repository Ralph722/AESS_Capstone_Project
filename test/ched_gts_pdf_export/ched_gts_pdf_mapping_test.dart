import 'package:alumni_system/features/admin/ched_gts_pdf_export/ched_gts_pdf_export.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChedGtsPdfFieldCatalog', () {
    test('declares 130 unique fields matching active template contract', () {
      expect(ChedGtsPdfFieldCatalog.fields.length, 130);
      expect(
        ChedGtsPdfFieldCatalog.fields.length,
        ChedGtsPdfTemplate.expectedFieldCount,
      );
      expect(
        ChedGtsPdfFieldCatalog.allNames.length,
        ChedGtsPdfFieldCatalog.fields.length,
      );
    });

    test('active template asset is official-aligned v3.1.0', () {
      expect(ChedGtsPdfTemplate.schemaVersion, ChedGtsBuiltin.schemaVersion);
      expect(
        ChedGtsPdfTemplate.assetPath,
        'assets/ched_gts/CHED-GTS-v3.1.0-fillable.pdf',
      );
      expect(ChedGtsPdfTemplate.active, same(ChedGtsPdfTemplate.v3_1_0));
    });
  });

  group('ChedGtsPdfMapper coverage', () {
    test('every catalog PDF field has an explicit mapping rule', () {
      final uncovered = ChedGtsPdfFieldCatalog.allNames
          .difference(ChedGtsPdfMapper.coveredPdfFields);
      expect(
        uncovered,
        isEmpty,
        reason: 'Uncovered PDF fields: $uncovered',
      );

      final unknown = ChedGtsPdfMapper.coveredPdfFields
          .difference(ChedGtsPdfFieldCatalog.allNames);
      expect(
        unknown,
        isEmpty,
        reason: 'coveredPdfFields lists unknown names: $unknown',
      );
    });
  });

  group('ChedGtsPdfMapper.mapAnswers', () {
    test('maps core identity, radios, and ARMM region', () {
      final mapped = ChedGtsPdfMapper.mapAnswers({
        'ched_1': 'Jane Doe',
        'ched_2': '123 Main St',
        'ched_3': 'jane@example.com',
        'ched_4': '088-123',
        'ched_5': '09171234567',
        'ched_6': 'Widow or Widower',
        'ched_7': 'Female',
        'ched_8': '1998-03-15',
        'ched_9': 'ARMM',
        'ched_10': 'Lanao del Sur',
        'ched_11': 'City',
        'ched_16': 'Yes',
      });

      expect(mapped.values['fullName'], 'Jane Doe');
      expect(mapped.values['civilStatus'], '/widowed');
      expect(mapped.values['sex'], '/female');
      expect(mapped.values['birthMonth'], '03');
      expect(mapped.values['birthDay'], '15');
      expect(mapped.values['birthYear'], '1998');
      expect(mapped.values['region'], 'ARMM');
      expect(mapped.values['residenceType'], '/city');
      expect(mapped.values['employmentStatus'], '/employed');
    });

    test('maps up to three education rows', () {
      final mapped = ChedGtsPdfMapper.mapAnswers({
        'ched_12': [
          {
            'Degree(s) & Specialization(s)': 'BSIT',
            'College or University': 'USTP',
            'Year Graduated': '2024',
            'Honor(s) or Award(s) Received': 'Cum Laude',
          },
          {
            'Degree(s) & Specialization(s)': 'MSIT',
            'College or University': 'USTP',
            'Year Graduated': '2026',
            'Honor(s) or Award(s) Received': '',
          },
        ],
      });

      expect(mapped.values['degree'], 'BSIT');
      expect(mapped.values['collegeUniversity'], 'USTP');
      expect(mapped.values['yearGraduated'], '2024');
      expect(mapped.values['honors'], 'Cum Laude');
      expect(mapped.values['degree2'], 'MSIT');
      expect(mapped.values['yearGraduated2'], '2026');
      expect(
        mapped.notes.any((n) => n.contains('ched_12') && n.contains('omitted')),
        isFalse,
      );
    });

    test('maps undergraduate and graduate course reasons', () {
      final mapped = ChedGtsPdfMapper.mapAnswers({
        'ched_14': {
          'Strong passion for the profession': {
            'Undergraduate/AB/BS': true,
            'Graduate/MS/MA/PhD': true,
          },
          'Peer Influence': {
            'Undergraduate/AB/BS': false,
            'Graduate/MS/MA/PhD': true,
          },
        },
        'ched_14_other': 'Family tradition',
      });

      expect(mapped.values['courseReasons__passion'], '/Yes');
      expect(mapped.values['courseReasonsGrad__passion'], '/Yes');
      expect(mapped.values['courseReasonsGrad__peers'], '/Yes');
      expect(mapped.values.containsKey('courseReasons__peers'), isFalse);
      expect(mapped.values['courseReasonsOther'], 'Family tradition');
    });

    test('maps multi-select staying reasons, others text, and job levels', () {
      final mapped = ChedGtsPdfMapper.mapAnswers({
        'ched_23': [
          'Salaries and benefits',
          'Proximity to residence',
          'Other reason(s), please specify',
        ],
        'ched_23_other': 'Flexible hours',
        'ched_30': {
          'Rank or Clerical': {
            '30.1. First Job': true,
            '30.2. Current or Present Job': false,
          },
          'Managerial or Executive': {
            '30.1. First Job': false,
            '30.2. Current or Present Job': true,
          },
        },
      });

      expect(mapped.values['stayingReasons__salary'], '/Yes');
      expect(mapped.values['stayingReasons__proximity'], '/Yes');
      expect(mapped.values['stayingReasons__other'], '/Yes');
      expect(mapped.values['stayingReasonsOther'], 'Flexible hours');
      expect(mapped.values['firstJobLevel'], '/rank');
      expect(mapped.values['currentJobLevel'], '/managerial');
    });

    test('maps official businessLine wording without shortening', () {
      final mapped = ChedGtsPdfMapper.mapAnswers({
        'ched_20':
            'Wholesale and Retail Trade, repair of motor vehicles, motorcycles and personal and household goods',
      });
      expect(
        mapped.values['businessLine'],
        'Wholesale and Retail Trade, repair of motor vehicles, motorcycles and personal and household goods',
      );
    });

    test('maps duration others option', () {
      final mapped = ChedGtsPdfMapper.mapAnswers({
        'ched_27': 'Others, please specify',
        'ched_27_other': '4 years and 2 months',
      });
      expect(mapped.values['firstJobDuration'], '/other');
      expect(mapped.values['firstJobDurationOther'], '4 years and 2 months');
    });
  });
}
