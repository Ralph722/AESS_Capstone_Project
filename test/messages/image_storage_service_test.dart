import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/messages/data/image_storage_service.dart';

void main() {
  group('ImageStorageService helpers', () {
    test('isJpegBytes checks SOI marker', () {
      expect(ImageStorageService.isJpegBytes(Uint8List(0)), isFalse);
      expect(ImageStorageService.isJpegBytes(Uint8List.fromList([0xFF])), isFalse);
      expect(
        ImageStorageService.isJpegBytes(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
        isTrue,
      );
      expect(
        ImageStorageService.isJpegBytes(Uint8List.fromList([0x89, 0x50])),
        isFalse,
      );
    });

    test('message attachment refs', () {
      expect(
        ImageStorageService.isMessageAttachmentRef(
          'message-attachments/u1/m1.jpg',
        ),
        isTrue,
      );
      expect(
        ImageStorageService.isAllowedMessageImageUrl(null),
        isTrue,
      );
      expect(
        ImageStorageService.isAllowedMessageImageUrl(''),
        isTrue,
      );
      expect(
        ImageStorageService.isAllowedMessageImageUrl('https://evil.example/x'),
        isFalse,
      );
    });

    test('sanitizePathSegment rejects traversal and odd chars', () {
      expect(
        ImageStorageService.sanitizePathSegment('abc_123', label: 'id'),
        'abc_123',
      );
      expect(
        () => ImageStorageService.sanitizePathSegment('../x', label: 'id'),
        throwsArgumentError,
      );
      expect(
        () => ImageStorageService.sanitizePathSegment('a/b', label: 'id'),
        throwsArgumentError,
      );
      expect(
        () => ImageStorageService.sanitizePathSegment('', label: 'id'),
        throwsArgumentError,
      );
    });

    test('storagePathFromPublicUrl extracts known prefixes only', () {
      expect(
        ImageStorageService.storagePathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/images/avatars/u1.jpg?v=1',
        ),
        'avatars/u1.jpg',
      );
      expect(
        ImageStorageService.storagePathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/images/secret/x.jpg',
        ),
        isNull,
      );
      expect(
        ImageStorageService.storagePathFromPublicUrl('data:image/jpeg;base64,xx'),
        isNull,
      );
    });

    test('signed URL cache clear is idempotent', () {
      ImageStorageService.clearSignedUrlCache();
      ImageStorageService.invalidateSignedUrl('message-attachments/u/m.jpg');
      ImageStorageService.clearSignedUrlCache();
    });
  });

  group('AppImage URL guards', () {
    test('isNetworkUrl allows only http(s)', () {
      expect(AppImage.isNetworkUrl('https://cdn.example/a.jpg'), isTrue);
      expect(AppImage.isNetworkUrl('http://cdn.example/a.jpg'), isTrue);
      expect(AppImage.isNetworkUrl('javascript:alert(1)'), isFalse);
      expect(AppImage.isNetworkUrl('file:///tmp/x'), isFalse);
      expect(AppImage.isNetworkUrl('/relative/path'), isFalse);
    });

    test('provider returns null for unsafe schemes', () {
      expect(AppImage.provider('javascript:alert(1)'), isNull);
      expect(AppImage.provider(''), isNull);
      expect(AppImage.provider(null), isNull);
    });
  });
}
