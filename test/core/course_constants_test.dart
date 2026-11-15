import 'package:alumni_system/core/constants/course_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourseConstants.normalize', () {
    test('plain codes stay canonical', () {
      expect(CourseConstants.normalize('BSIT'), 'BSIT');
      expect(CourseConstants.normalize('bfpt'), 'BFPT');
      expect(CourseConstants.normalize('BTLED-IA'), 'BTLED-IA');
      expect(CourseConstants.normalize('BTLED-ICT'), 'BTLED-ICT');
      expect(CourseConstants.normalize('BTLED-HE'), 'BTLED-HE');
    });

    test('BTLED spacing typos map to codes', () {
      expect(CourseConstants.normalize('BTLED HE'), 'BTLED-HE');
      expect(CourseConstants.normalize('BTLED IA'), 'BTLED-IA');
      expect(CourseConstants.normalize('BTLED ICT'), 'BTLED-ICT');
    });

    test('official full names map to codes', () {
      expect(
        CourseConstants.normalize(
          'Bachelor of Science in Information Technology',
        ),
        'BSIT',
      );
      expect(
        CourseConstants.normalize('Bachelor in Food Processing and Technology'),
        'BFPT',
      );
      expect(
        CourseConstants.normalize(
          'Bachelor of Technology and Livelihood Education major in Industrial Arts',
        ),
        'BTLED-IA',
      );
      expect(
        CourseConstants.normalize(
          'Bachelor of Technology and Livelihood Education major in Information and Communication Technology',
        ),
        'BTLED-ICT',
      );
      expect(
        CourseConstants.normalize(
          'Bachelor of Technology and Livelihood Education major in Home Economics',
        ),
        'BTLED-HE',
      );
    });

    test('full names tolerate extra spaces and punctuation', () {
      expect(
        CourseConstants.normalize(
          '  Bachelor  of Science in Information Technology  ',
        ),
        'BSIT',
      );
      expect(
        CourseConstants.normalize(
          'Bachelor of Technology and Livelihood Education, Major in Home Economics',
        ),
        'BTLED-HE',
      );
    });

    test('short BSIT aliases', () {
      expect(CourseConstants.normalize('BS Information Technology'), 'BSIT');
    });

    test('unknown strings are returned trimmed and fail isValid', () {
      final n = CourseConstants.normalize('Bachelor of Made Up Program');
      expect(n, 'Bachelor of Made Up Program');
      expect(CourseConstants.isValid(n), isFalse);
    });

    test('null and empty', () {
      expect(CourseConstants.normalize(null), isNull);
      expect(CourseConstants.normalize('   '), isNull);
    });
  });

  group('CourseConstants.isValid', () {
    test('only official codes', () {
      expect(CourseConstants.isValid('BSIT'), isTrue);
      expect(CourseConstants.isValid('BFPT'), isTrue);
      expect(CourseConstants.isValid('bsit'), isFalse);
      expect(
        CourseConstants.isValid(
          'Bachelor of Science in Information Technology',
        ),
        isFalse,
      );
    });
  });
}
