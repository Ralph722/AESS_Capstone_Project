import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChedGtsVisibility', () {
    test('always shows A–C core, item 16, 34', () {
      final v = ChedGtsVisibility.visibleItemIds({});
      expect(v, contains('ched_1'));
      expect(v, contains('ched_12'));
      expect(v, contains('ched_15a'));
      expect(v, contains('ched_16'));
      expect(v, contains('ched_34'));
      expect(v, isNot(contains('ched_17')));
      expect(v, isNot(contains('ched_18')));
      expect(v, isNot(contains('ched_referral')));
    });

    test('16=No shows 17 and hides employed path', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.no,
      });
      expect(v, contains('ched_17'));
      expect(v, isNot(contains('ched_18')));
      expect(v, isNot(contains('ched_22')));
      expect(v, isNot(contains('ched_27')));
      expect(v, isNot(contains('ched_33')));
      expect(v, contains('ched_34'));
    });

    test('16=Never Employed shows 17 only for employment block', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.neverEmployed,
      });
      expect(v, contains('ched_17'));
      expect(v, isNot(contains('ched_19')));
    });

    test('16=Yes shows 18–22 and first-job block', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.yes,
      });
      expect(v, isNot(contains('ched_17')));
      expect(v, containsAll(['ched_18', 'ched_19', 'ched_20', 'ched_21', 'ched_22']));
      expect(v, containsAll(['ched_27', 'ched_28', 'ched_29', 'ched_30', 'ched_31', 'ched_32']));
    });

    test('18=Self-employed shows skills follow-up', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.yes,
        'ched_18': ChedGtsBuiltin.selfEmployed,
      });
      expect(v, contains('ched_18_skills'));
    });

    test('20=Others shows required line-of-business specify', () {
      final base = {
        'ched_16': ChedGtsBuiltin.yes,
        'ched_20': 'Education',
      };
      expect(
        ChedGtsVisibility.visibleItemIds(base),
        isNot(contains('ched_20_other')),
      );
      final withOther = {...base, 'ched_20': ChedGtsBuiltin.othersSpecify};
      expect(
        ChedGtsVisibility.visibleItemIds(withOther),
        contains('ched_20_other'),
      );
      expect(
        ChedGtsVisibility.missingRequired(withOther),
        contains('ched_20_other'),
      );
    });

    test('22=Yes shows stay reasons and 24a; hides 25', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.yes,
        'ched_22': ChedGtsBuiltin.yes,
      });
      expect(v, contains('ched_23'));
      expect(v, contains('ched_24a'));
      expect(v, isNot(contains('ched_25')));
    });

    test('22=No shows change reasons; hides 23/24', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.yes,
        'ched_22': ChedGtsBuiltin.no,
      });
      expect(v, contains('ched_25'));
      expect(v, isNot(contains('ched_23')));
      expect(v, isNot(contains('ched_24a')));
      expect(v, isNot(contains('ched_24b')));
      expect(v, contains('ched_27'));
    });

    test('24a=No skips accepting reasons 24b and shows change reasons', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.yes,
        'ched_22': ChedGtsBuiltin.yes,
        'ched_24a': ChedGtsBuiltin.no,
        'ched_25': ['Other reason(s), please specify'],
      });
      expect(v, contains('ched_24a'));
      expect(v, isNot(contains('ched_24b')));
      expect(v, contains('ched_25'));
      expect(v, contains('ched_25_other'));
      expect(v, contains('ched_27'));
    });

    test('24a=Yes shows accepting reasons 24b; hides change reasons', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.yes,
        'ched_22': ChedGtsBuiltin.yes,
        'ched_24a': ChedGtsBuiltin.yes,
      });
      expect(v, contains('ched_24b'));
      expect(v, isNot(contains('ched_25')));
    });

    test('32=No hides competencies 33', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.yes,
        'ched_32': ChedGtsBuiltin.no,
      });
      expect(v, isNot(contains('ched_33')));
    });

    test('32=Yes shows competencies 33', () {
      final v = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.yes,
        'ched_32': ChedGtsBuiltin.yes,
      });
      expect(v, contains('ched_33'));
    });

    test('Others specify appears only when option selected', () {
      final without = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.no,
        'ched_17': ['Lack of work experience'],
      });
      expect(without, isNot(contains('ched_17_other')));

      final withOther = ChedGtsVisibility.visibleItemIds({
        'ched_16': ChedGtsBuiltin.no,
        'ched_17': ['Other reason(s), please specify'],
      });
      expect(withOther, contains('ched_17_other'));
    });

    test('pruneHiddenAnswers removes unemployed reasons when employed', () {
      final pruned = ChedGtsVisibility.pruneHiddenAnswers({
        'ched_16': ChedGtsBuiltin.yes,
        'ched_17': ['No job opportunity'],
        'ched_18': 'Regular or Permanent',
      });
      expect(pruned.containsKey('ched_17'), isFalse);
      expect(pruned['ched_18'], 'Regular or Permanent');
    });

    test('missingRequired requires item 16', () {
      final missing = ChedGtsVisibility.missingRequired({});
      expect(missing, contains('ched_16'));
    });
  });
}
