import 'package:flutter_test/flutter_test.dart';
import 'package:alumni_system/shared/widgets/user/portal_states.dart';

void main() {
  group('portalFriendlyError', () {
    test('maps network failures', () {
      expect(
        portalFriendlyError(Exception('SocketException: failed host lookup')),
        'Connection problem. Check your internet and try again.',
      );
      expect(
        portalFriendlyError('ClientException: Failed to fetch'),
        'Connection problem. Check your internet and try again.',
      );
    });

    test('maps permission and session failures', () {
      expect(
        portalFriendlyError('PostgrestException: 42501 permission denied'),
        'You do not have permission to do that.',
      );
      expect(
        portalFriendlyError(Exception('JWT expired / session invalid')),
        'Your session expired. Please sign in again.',
      );
      expect(
        portalFriendlyError(StateError('Not signed in.')),
        'Not signed in.',
      );
    });

    test('maps storage / upload size failures', () {
      expect(
        portalFriendlyError(Exception('StorageException: Payload too large')),
        'Could not upload that image. Try a smaller photo.',
      );
      expect(
        portalFriendlyError(ArgumentError('Image exceeds maximum upload size.')),
        'Image exceeds maximum upload size.',
      );
    });

    test('keeps short safe ArgumentError messages', () {
      expect(
        portalFriendlyError(
          ArgumentError('Image is too large. Please choose a file under 12 MB.'),
        ),
        'Image is too large. Please choose a file under 12 MB.',
      );
    });

    test('hides technical dumps', () {
      expect(
        portalFriendlyError(
          Exception('PostgrestException(message: PGRST116, code: PGRST116)'),
        ),
        'Something went wrong. Please try again.',
      );
      expect(
        portalFriendlyError('package:supabase_flutter/src/foo.dart:12'),
        'Something went wrong. Please try again.',
      );
    });
  });
}
