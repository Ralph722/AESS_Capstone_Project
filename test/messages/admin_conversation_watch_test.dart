import 'package:alumni_system/features/messages/application/admin_conversation_watch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isAlreadyWatchingAdminConversation', () {
    test('false when no active subscription', () {
      expect(
        isAlreadyWatchingAdminConversation(
          hasActiveSubscription: false,
          watchingMessagingId: 'a',
          requestedMessagingId: 'a',
        ),
        isFalse,
      );
    });

    test('true when re-tapping the same watched conversation', () {
      expect(
        isAlreadyWatchingAdminConversation(
          hasActiveSubscription: true,
          watchingMessagingId: 'a',
          requestedMessagingId: 'a',
          watchingDocId: 'doc-a',
          requestedDocId: 'doc-a',
        ),
        isTrue,
      );
    });

    test(
      'false when switching alumni after selection already updated '
      '(regression: comparing selected id made every switch look already watching)',
      () {
        // Selection set _selectedUserId to B first; old subscription for A still open.
        // Using watching id A vs requested B must reload — not early-return.
        expect(
          isAlreadyWatchingAdminConversation(
            hasActiveSubscription: true,
            watchingMessagingId: 'a',
            requestedMessagingId: 'b',
          ),
          isFalse,
        );
      },
    );
  });

  group('isAdminConversationEmitStillSelected', () {
    test('accepts emit for the open messaging id', () {
      expect(
        isAdminConversationEmitStillSelected(
          selectedMessagingId: 'b',
          emitMessagingId: 'b',
        ),
        isTrue,
      );
    });

    test('drops late emit from a previous conversation', () {
      expect(
        isAdminConversationEmitStillSelected(
          selectedMessagingId: 'b',
          emitMessagingId: 'a',
          selectedDocId: 'doc-b',
          emitDocId: 'doc-a',
        ),
        isFalse,
      );
    });
  });
}
