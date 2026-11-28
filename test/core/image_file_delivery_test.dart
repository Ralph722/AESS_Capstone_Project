import 'package:alumni_system/core/utils/image_file_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('imageFileNameForMime', () {
    test('keeps an existing extension', () {
      expect(imageFileNameForMime('cover.png', 'image/jpeg'), 'cover.png');
    });

    test('adds extension from mime', () {
      expect(imageFileNameForMime('Job_Title_cover', 'image/png'), 'Job_Title_cover.png');
      expect(imageFileNameForMime('photo', 'image/webp'), 'photo.webp');
      expect(imageFileNameForMime('photo', 'image/jpeg'), 'photo.jpg');
    });

    test('falls back when base is blank', () {
      expect(imageFileNameForMime('  ', 'image/png'), 'photo.png');
    });
  });

  test('gallery success copy is clear', () {
    expect(
      const ImageDeliveryResult(ImageDeliveryKind.gallery).successMessage,
      'Saved to your gallery',
    );
  });
}
