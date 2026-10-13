import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/admin/reports/application/gts_field_dictionary.dart';
import 'package:alumni_system/features/admin/reports/models/gts_field.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';

void main() {
  GtsField field(String key) => GtsFieldDictionary.byKey(key)!;

  group('coverage', () {
    test('every CHED item appears once, with its printed number', () {
      final keys = GtsFieldDictionary.fields.map((f) => f.key).toList();
      expect(keys.toSet().length, keys.length);
      for (final item in ChedGtsBuiltin.items) {
        final f = field(item.id);
        expect(f.chedNumber, item.chedNumber, reason: item.id);
        expect(f.prompt, item.prompt, reason: item.id);
        expect(f.options, item.options, reason: item.id);
        expect(f.label, isNotEmpty, reason: item.id);
      }
      expect(GtsFieldDictionary.chedFields.length, ChedGtsBuiltin.items.length);
    });

    test('ids and printed numbers differ where the paper form does', () {
      expect(
        field('ched_24a').numberedLabel,
        '24. First job related to course',
      );
      expect(field('ched_24b').chedNumber, '25');
      expect(field('ched_25').chedNumber, '26');
      expect(GtsFieldDictionary.byKey('ched_26'), isNull);
    });

    test('others-specify text links to its parent item', () {
      expect(field('ched_20_other').othersOf, 'ched_20');
      expect(
        field('ched_20_other').label,
        'Line of business: other (specified)',
      );
      expect(field('ched_14_other').othersOf, 'ched_14');
      expect(field('ched_18_skills').othersOf, isNull);
    });
  });

  group('skip logic agrees with the form', () {
    test('with no answers, only unconditional items are shown', () {
      final visible = ChedGtsVisibility.visibleItemIds(const {});
      for (final f in GtsFieldDictionary.chedFields) {
        expect(visible.contains(f.key), !f.isConditional, reason: f.key);
      }
    });

    test('each asked-of rule opens its items', () {
      const gates = <String, Map<String, dynamic>>{
        'Item 16 = Yes': {'ched_16': 'Yes'},
        'Item 16 = No or Never Employed': {'ched_16': 'No'},
        'Item 18 = Self-employed': {
          'ched_16': 'Yes',
          'ched_18': 'Self-employed',
        },
        'Item 22 = Yes': {'ched_16': 'Yes', 'ched_22': 'Yes'},
        'Item 24 = Yes': {
          'ched_16': 'Yes',
          'ched_22': 'Yes',
          'ched_24a': 'Yes',
        },
        'Item 22 = No, or item 24 = No': {'ched_16': 'Yes', 'ched_22': 'No'},
        'Item 32 = Yes': {'ched_16': 'Yes', 'ched_32': 'Yes'},
      };
      for (final f in GtsFieldDictionary.chedFields) {
        if (!f.isConditional || f.othersOf != null) continue;
        final answers = gates[f.askedOf];
        expect(answers, isNotNull, reason: 'No test gate for ${f.askedOf}');
        expect(
          GtsFieldDictionary.isAskedFor(f.key, answers!),
          isTrue,
          reason: f.key,
        );
        expect(
          GtsFieldDictionary.isAskedFor(f.key, const {}),
          isFalse,
          reason: f.key,
        );
      }
    });

    test('Q26 also opens when the first job is not related', () {
      expect(
        GtsFieldDictionary.isAskedFor('ched_25', const {
          'ched_16': 'Yes',
          'ched_22': 'Yes',
          'ched_24a': 'No',
        }),
        isTrue,
      );
    });

    test('cohort fields apply to everyone', () {
      expect(GtsFieldDictionary.isAskedFor('course', const {}), isTrue);
      expect(GtsFieldDictionary.isAskedFor('year_graduated', const {}), isTrue);
      expect(GtsFieldDictionary.isAskedFor('unknown_key', const {}), isFalse);
    });
  });

  group('calculation rules', () {
    test('only bracket items are ordinal and allow a median', () {
      final ordinal = GtsFieldDictionary.fields
          .where((f) => f.valueClass == GtsValueClass.ordinal)
          .map((f) => f.key);
      expect(ordinal, ['ched_27', 'ched_29', 'ched_31']);
      for (final f in GtsFieldDictionary.fields) {
        expect(
          f.allows(GtsCalculation.medianBracket),
          f.valueClass == GtsValueClass.ordinal,
          reason: f.key,
        );
      }
    });

    test('brackets keep questionnaire order and drop "Others"', () {
      expect(field('ched_31').brackets, field('ched_31').options);
      expect(field('ched_29').brackets.length, 6);
      expect(field('ched_29').brackets.first, 'Less than a month');
      expect(
        field('ched_29').brackets.any((b) => b.startsWith('Others')),
        isFalse,
      );
    });

    test('personal fields cannot be calculated, grouped or filtered', () {
      for (final key in [
        'ched_1',
        'ched_2',
        'ched_3',
        'ched_4',
        'ched_5',
        'ched_8',
      ]) {
        final f = field(key);
        expect(f.isPersonal, isTrue, reason: key);
        expect(f.calculations, isEmpty, reason: key);
        expect(f.groupable, isFalse, reason: key);
        expect(f.filterable, isFalse, reason: key);
      }
    });

    test('multi-select filters but never groups', () {
      final q17 = field('ched_17');
      expect(q17.valueClass, GtsValueClass.multiSelect);
      expect(q17.groupable, isFalse);
      expect(q17.filterable, isTrue);
      expect(q17.allows(GtsCalculation.shareOfAnswered), isTrue);
    });

    test('open text only counts answers', () {
      for (final key in ['ched_10', 'ched_19', 'ched_34', 'ched_20_other']) {
        expect(field(key).calculations, {
          GtsCalculation.answeredCount,
        }, reason: key);
        expect(field(key).groupable, isFalse, reason: key);
      }
    });

    test('roster fields have no eligibility share', () {
      expect(field('course').allows(GtsCalculation.shareOfEligible), isFalse);
      expect(field('ched_16').allows(GtsCalculation.shareOfEligible), isTrue);
      expect(field('year_graduated').groupable, isTrue);
    });
  });

  test('server columns match gts_respondent_facts', () {
    final columns = {
      for (final f in GtsFieldDictionary.fields)
        if (f.factColumn != null) f.key: f.factColumn,
    };
    expect(columns, {
      'course': 'course',
      'year_graduated': 'year_graduated',
      'survey': 'survey_id',
      'ched_16': 'presently_employed',
      'ched_17': 'not_employed_reasons',
      'ched_18': 'employment_type',
      'ched_19': 'occupation',
      'ched_20': 'industry',
      'ched_21': 'place_of_work',
      'ched_24a': 'first_job_related',
      'ched_29': 'time_to_first_job',
      'ched_31': 'initial_salary',
      'ched_32': 'curriculum_relevant',
    });
  });
}
