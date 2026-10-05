import 'package:alumni_system/features/forum/data/forum_content_moderation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool blocked(String text) =>
      ForumContentModerationService.containsBlockedLanguage(text);

  group('blocks', () {
    for (final text in [
      'wtf is this',
      'WTF!!',
      'just stfu already',
      'gtfo',
      'w.t.f',
      'w t f',
      'f u c k this',
      'f*ck',
      'sh1t',
      'fuuuuck',
      'shiiiit happens',
      'fuckyou',
      'tngina',
      'ptngina mo',
      'putanginaaaa',
      'tanginamo talaga',
      'pota naman',
      'gago ka',
      'yawa ka',
      'giatay',
      'b!tch',
      'lmfao',
    ]) {
      test(text, () => expect(blocked(text), isTrue));
    }
  });

  group('allows', () {
    for (final text in [
      'I finished my BS in Information Technology.',
      'Add an FK constraint to the table.',
      'I practice kung fu on weekends.',
      'Class of 2020 reunion assessment',
      'Section A, B and C will meet at 5 pm.',
      'Hi! Looking forward to the homecoming.',
      'What the heck happened to the schedule?',
      'Thank you po sa lahat!',
    ]) {
      test(text, () => expect(blocked(text), isFalse));
    }
  });
}
