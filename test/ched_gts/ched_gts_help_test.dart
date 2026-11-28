import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_help_service.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_help_sheet.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';

void main() {
  group('ChedGtsHelpSuggestion', () {
    test('parses from normal json', () {
      final s = ChedGtsHelpSuggestion.fromJson({
        'unclear': false,
        'occupation': 'Software Engineer',
        'lineOfBusiness': 'Information Technology',
        'specifyText': '',
        'reason': 'Company builds web applications.',
        'remaining': 18,
      });

      expect(s.unclear, isFalse);
      expect(s.occupation, 'Software Engineer');
      expect(s.lineOfBusiness, 'Information Technology');
      expect(s.specifyText, isEmpty);
      expect(s.reason, 'Company builds web applications.');
      expect(s.remaining, 18);
    });

    test('parses unclear suggestion', () {
      final s = ChedGtsHelpSuggestion.fromJson({
        'unclear': true,
        'occupation': '',
        'lineOfBusiness': '',
        'specifyText': '',
        'reason': '',
        'remaining': 19,
      });

      expect(s.unclear, isTrue);
      expect(s.occupation, isEmpty);
      expect(s.lineOfBusiness, isNull);
    });

    test('parses specifyText for Others option', () {
      final s = ChedGtsHelpSuggestion.fromJson({
        'unclear': false,
        'occupation': 'Space Researcher',
        'lineOfBusiness': ChedGtsBuiltin.othersSpecify,
        'specifyText': 'Aerospace Research Institute',
        'reason': 'Specialized aerospace facility.',
        'remaining': 15,
      });

      expect(s.lineOfBusiness, ChedGtsBuiltin.othersSpecify);
      expect(s.specifyText, 'Aerospace Research Institute');

      final updates = chedGtsLineOfBusinessUpdates(s);
      expect(updates['ched_20'], ChedGtsBuiltin.othersSpecify);
      expect(updates['ched_20_other'], 'Aerospace Research Institute');
    });
  });

  group('chedGtsLineOfBusinessUpdates', () {
    test('returns standard line of business update without other', () {
      const s = ChedGtsHelpSuggestion(
        unclear: false,
        occupation: 'Chef',
        lineOfBusiness: 'Hotels and Restaurants',
        specifyText: '',
        reason: 'Restaurant kitchen work.',
        remaining: 10,
      );

      final updates = chedGtsLineOfBusinessUpdates(s);
      expect(updates, {'ched_20': 'Hotels and Restaurants'});
      expect(updates.containsKey('ched_20_other'), isFalse);
    });
  });
}
