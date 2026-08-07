import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/messages/models/message_model.dart';

/// Handle returned by [MessageRealtime.subscribeMessageChanges].
class MessageChangeSubscription {
  MessageChangeSubscription._(this._cancel);
  final Future<void> Function() _cancel;
  Future<void> cancel() => _cancel();
}

/// Realtime subscriptions for messaging.
///
/// Uses postgres_changes (Reports-style) with debounce + slow safety poll.
/// Keeps legacy `.stream` helpers for callers that still need row snapshots.
class MessageRealtime {
  MessageRealtime({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const Duration defaultDebounce = Duration(milliseconds: 400);
  static const Duration defaultSafetyPoll = Duration(seconds: 60);

  /// Full-table messages stream (snapshot style).
  Stream<List<Map<String, dynamic>>> watchAllMessageRows() {
    return _supabase.from('messages').stream(primaryKey: ['id']);
  }

  /// Filtered stream for a recipient.
  Stream<List<Map<String, dynamic>>> watchRowsForRecipient(
    String recipientSupabaseId,
  ) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', recipientSupabaseId);
  }

  /// Debounced INSERT/UPDATE/DELETE notifications on `messages`.
  ///
  /// [onChange] is also invoked once after subscribe and on the safety poll.
  MessageChangeSubscription subscribeMessageChanges({
    required String channelName,
    required void Function() onChange,
    Duration debounce = defaultDebounce,
    Duration safetyPoll = defaultSafetyPoll,
    bool invokeImmediately = true,
  }) {
    Timer? debounceTimer;
    Timer? pollTimer;
    RealtimeChannel? channel;
    var cancelled = false;

    void schedule() {
      if (cancelled) return;
      debounceTimer?.cancel();
      debounceTimer = Timer(debounce, () {
        if (!cancelled) onChange();
      });
    }

    try {
      final unique =
          '$channelName-${DateTime.now().microsecondsSinceEpoch}';
      channel = _supabase.channel(unique);
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) => schedule(),
      );
      channel.subscribe();
    } catch (_) {
      // Realtime unavailable — safety poll still runs.
    }

    if (invokeImmediately) {
      schedule();
    }

    pollTimer = Timer.periodic(safetyPoll, (_) {
      if (!cancelled) onChange();
    });

    return MessageChangeSubscription._(() async {
      cancelled = true;
      debounceTimer?.cancel();
      pollTimer?.cancel();
      final ch = channel;
      channel = null;
      if (ch != null) {
        try {
          await _supabase.removeChannel(ch);
        } catch (_) {}
      }
    });
  }

  /// Stream that emits a tick whenever messages change (debounced).
  Stream<void> watchMessageChangeTicks({
    String channelName = 'messages-ticks',
    Duration debounce = defaultDebounce,
    Duration safetyPoll = defaultSafetyPoll,
  }) {
    final controller = StreamController<void>();
    MessageChangeSubscription? sub;

    controller.onListen = () {
      sub = subscribeMessageChanges(
        channelName: channelName,
        debounce: debounce,
        safetyPoll: safetyPoll,
        invokeImmediately: true,
        onChange: () {
          if (!controller.isClosed) controller.add(null);
        },
      );
    };

    controller.onCancel = () async {
      await sub?.cancel();
    };

    return controller.stream;
  }

  /// Unread count: realtime change ticks + slow safety poll (no 5s hammering).
  Stream<int> watchUnreadCount({
    required Future<int> Function() fetchCount,
    required Future<String?> Function() resolveRecipientId,
    Duration pollInterval = defaultSafetyPoll,
    String channelName = 'messages-unread',
  }) {
    final controller = StreamController<int>();

    Future<void> setup() async {
      MessageChangeSubscription? changeSub;
      var lastEmitted = -1;

      Future<void> emit() async {
        if (controller.isClosed) return;
        final count = await fetchCount();
        if (controller.isClosed) return;
        if (count == lastEmitted) return;
        lastEmitted = count;
        controller.add(count);
      }

      try {
        final recipientId = await resolveRecipientId();
        if (recipientId == null || recipientId.isEmpty) {
          controller.add(0);
          await controller.close();
          return;
        }

        await emit();

        changeSub = subscribeMessageChanges(
          channelName: '$channelName-$recipientId',
          safetyPoll: pollInterval,
          invokeImmediately: false,
          onChange: () {
            unawaited(emit());
          },
        );

        controller.onCancel = () async {
          await changeSub?.cancel();
        };
      } catch (_) {
        await changeSub?.cancel();
        if (!controller.isClosed) controller.add(0);
      }
    }

    setup();
    return controller.stream;
  }

  /// Dedupes conversation snapshots by message id (last write wins).
  static Map<String, MessageModel> mergeRowsById(
    Iterable<MessageModel> rows,
  ) {
    final byId = <String, MessageModel>{};
    for (final row in rows) {
      if (row.id.isEmpty) continue;
      final existing = byId[row.id];
      if (existing == null) {
        byId[row.id] = row;
        continue;
      }
      final existingUpdated = existing.updatedAt ?? existing.createdAt;
      final incomingUpdated = row.updatedAt ?? row.createdAt;
      if (!incomingUpdated.isBefore(existingUpdated)) {
        byId[row.id] = row;
      }
    }
    return byId;
  }

  /// Stable fingerprint so callers can skip identical emissions.
  static String conversationFingerprint(
    Iterable<ConversationMessage> items,
  ) {
    final parts = items.map((m) {
      final ts = m.data['timestamp'];
      final body = m.data['messageText'] ?? '';
      final read = m.data['isRead'];
      final reactions = m.data['reactions'];
      final image = m.data['imageUrl'] ?? '';
      return '${m.docId}|$ts|$body|$read|$reactions|$image';
    }).toList()
      ..sort();
    return parts.join(';;');
  }

  static String legacyListFingerprint(Iterable<Map<String, dynamic>> items) {
    final parts = items.map((m) {
      final id = m['docId'] ?? m['id'] ?? m['messagingId'] ?? '';
      final ts = m['timestamp'] ?? m['lastMessageTime'] ?? '';
      final body = m['messageText'] ?? m['lastMessage'] ?? '';
      final read = m['isRead'];
      final reactions = m['reactions'];
      return '$id|$ts|$body|$read|$reactions';
    }).toList()
      ..sort();
    return parts.join(';;');
  }
}
