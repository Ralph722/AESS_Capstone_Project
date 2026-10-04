import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/core/services/app_session.dart';

/// Reads and updates the signed-in user's notifications
/// (`public.user_notifications`).
///
/// Notifications are created on the server only (database triggers,
/// scheduled jobs and admin RPCs via `enqueue_notifications`), so this
/// service never inserts rows for other users.
class NotificationService {
  NotificationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const pageSize = 20;

  /// Newest first. [before] pages backwards; [type] filters one category.
  Future<List<NotificationModel>> getUserNotifications({
    int limit = 50,
    bool unreadOnly = false,
    DateTime? before,
    NotificationType? type,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) return [];

    try {
      final rows = await fetchPage(
        limit: limit,
        unreadOnly: unreadOnly,
        before: before,
        type: type,
      );
      return rows;
    } catch (_) {
      return [];
    }
  }

  /// Same as [getUserNotifications] but lets errors reach the caller so a
  /// screen can show a retry state.
  Future<List<NotificationModel>> fetchPage({
    int limit = pageSize,
    bool unreadOnly = false,
    DateTime? before,
    NotificationType? type,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) return [];

    var query = _supabase
        .from('user_notifications')
        .select()
        .eq('user_id', userId);
    if (unreadOnly) query = query.eq('is_read', false);
    if (type != null) query = query.eq('type', type.name);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    final now = DateTime.now();
    return rows
        .map(NotificationModel.fromSupabaseRow)
        .where((n) => n.expiresAt == null || n.expiresAt!.isAfter(now))
        .toList();
  }

  /// Unread count for the signed-in user. [excludeType] leaves one type out
  /// (the admin bell already counts unread messages separately).
  Future<int> getUnreadCount({NotificationType? excludeType}) async {
    final userId = AppSession.userId;
    if (userId == null) return 0;

    try {
      var query = _supabase
          .from('user_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      if (excludeType != null) {
        query = query.neq('type', excludeType.name);
      }
      final response = await query.count(CountOption.exact);
      return response.count;
    } catch (_) {
      return 0;
    }
  }

  Stream<int> getUnreadCountStream({NotificationType? excludeType}) {
    final userId = AppSession.userId;
    if (userId == null) return Stream.value(0);
    return _NotificationChangeHub.watch(
      _supabase,
      userId,
      () => getUnreadCount(excludeType: excludeType),
    );
  }

  Stream<List<NotificationModel>> getNotificationsStream({int limit = 50}) {
    final userId = AppSession.userId;
    if (userId == null) return Stream.value(const []);
    return _NotificationChangeHub.watch(
      _supabase,
      userId,
      () => getUserNotifications(limit: limit),
    );
  }

  /// Emits whenever the signed-in user's notifications change.
  Stream<void> watchChanges() {
    final userId = AppSession.userId;
    if (userId == null) return const Stream.empty();
    return _NotificationChangeHub.watch<void>(_supabase, userId, () async {});
  }

  Future<void> markAsRead(String notificationId) async {
    if (AppSession.userId == null) return;
    await _supabase
        .from('user_notifications')
        .update({
          'is_read': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final userId = AppSession.userId;
    if (userId == null) return;

    await _supabase
        .from('user_notifications')
        .update({
          'is_read': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    if (AppSession.userId == null) return;
    await _supabase.from('user_notifications').delete().eq('id', notificationId);
  }

  Future<void> deleteAllRead() async {
    final userId = AppSession.userId;
    if (userId == null) return;

    await _supabase
        .from('user_notifications')
        .delete()
        .eq('user_id', userId)
        .eq('is_read', true);
  }
}

/// One Realtime channel per signed-in user, shared by every badge / list
/// listener. Bursts of row changes (e.g. "mark all read") collapse into a
/// single refetch; a slow poll covers dropped connections.
class _NotificationChangeHub {
  _NotificationChangeHub._(this._supabase, this.userId);

  static final Map<String, _NotificationChangeHub> _hubs = {};

  static const _debounce = Duration(milliseconds: 250);
  static const _pollEvery = Duration(seconds: 30);

  final SupabaseClient _supabase;
  final String userId;
  final _ticks = StreamController<void>.broadcast();
  RealtimeChannel? _channel;
  Timer? _poller;
  Timer? _debouncer;
  int _listeners = 0;

  static Stream<T> watch<T>(
    SupabaseClient supabase,
    String userId,
    Future<T> Function() load,
  ) {
    late StreamController<T> controller;
    StreamSubscription<void>? tickSub;
    _NotificationChangeHub? hub;

    Future<void> emit() async {
      try {
        final value = await load();
        if (!controller.isClosed) controller.add(value);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        hub = _hubs.putIfAbsent(
          userId,
          () => _NotificationChangeHub._(supabase, userId),
        );
        hub!._retain();
        tickSub = hub!._ticks.stream.listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await tickSub?.cancel();
        hub?._release();
      },
    );
    return controller.stream;
  }

  void _retain() {
    _listeners++;
    if (_listeners == 1) _connect();
  }

  void _release() {
    _listeners--;
    if (_listeners > 0) return;
    _debouncer?.cancel();
    _poller?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) _supabase.removeChannel(channel);
    _hubs.remove(userId);
  }

  void _connect() {
    _poller = Timer.periodic(_pollEvery, (_) => _tick());
    try {
      _channel = _supabase
          .channel(
            'user_notifications:$userId:${DateTime.now().microsecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => _scheduleTick(),
          )
          .subscribe((status, [_]) {
            if (status == RealtimeSubscribeStatus.subscribed) _scheduleTick();
          });
    } catch (_) {
      // Polling keeps the badge fresh when Realtime is unavailable.
    }
  }

  void _scheduleTick() {
    _debouncer?.cancel();
    _debouncer = Timer(_debounce, _tick);
  }

  void _tick() {
    if (!_ticks.isClosed) _ticks.add(null);
  }
}
