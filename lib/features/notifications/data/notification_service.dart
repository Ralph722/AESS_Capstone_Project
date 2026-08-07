import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/core/services/app_session.dart';

/// User notifications — Supabase only (`public.user_notifications`).
class NotificationService {
  NotificationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    if (userId.isEmpty) return;
    final notification = NotificationModel(
      id: '',
      userId: userId,
      type: type,
      title: title,
      message: message,
      relatedId: relatedId,
      isRead: false,
      createdAt: DateTime.now(),
      data: data,
    );

    await _supabase
        .from('user_notifications')
        .insert(notification.toSupabaseRow(supabaseUserId: userId));
  }

  Future<void> createNotificationForAllUsers({
    required NotificationType type,
    required String title,
    required String message,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    final users = await _supabase.from('users').select('id');
    if (users.isEmpty) return;

    final rows = users.map((u) {
      final notification = NotificationModel(
        id: '',
        userId: u['id'] as String,
        type: type,
        title: title,
        message: message,
        relatedId: relatedId,
        isRead: false,
        createdAt: DateTime.now(),
        data: data,
      );
      return notification.toSupabaseRow(supabaseUserId: u['id'] as String);
    }).toList();

    await _supabase.from('user_notifications').insert(rows);
  }

  Future<List<NotificationModel>> getUserNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) return [];

    try {
      var query = _supabase
          .from('user_notifications')
          .select()
          .eq('user_id', userId);
      if (unreadOnly) {
        query = query.eq('is_read', false);
      }
      final rows =
          await query.order('created_at', ascending: false).limit(limit);
      return rows.map(NotificationModel.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    final userId = AppSession.userId;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('user_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (_) {
      try {
        final rows = await _supabase
            .from('user_notifications')
            .select('id')
            .eq('user_id', userId)
            .eq('is_read', false)
            .limit(200);
        return rows.length;
      } catch (_) {
        return 0;
      }
    }
  }

  Stream<int> getUnreadCountStream() {
    final userId = AppSession.userId;
    if (userId == null) return Stream.value(0);

    final controller = StreamController<int>();
    StreamSubscription<dynamic>? sub;
    Timer? poller;

    Future<void> emit() async {
      final count = await getUnreadCount();
      if (!controller.isClosed) controller.add(count);
    }

    Future<void> startPolling() async {
      await emit();
      poller?.cancel();
      poller = Timer.periodic(const Duration(seconds: 15), (_) => emit());
    }

    controller.onListen = () async {
      await emit();
      try {
        sub = _supabase
            .from('user_notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .listen(
              (_) => emit(),
              onError: (_) => startPolling(),
            );
      } catch (_) {
        await startPolling();
      }
    };

    controller.onCancel = () async {
      await sub?.cancel();
      poller?.cancel();
    };

    return controller.stream;
  }

  Stream<List<NotificationModel>> getNotificationsStream({int limit = 50}) {
    final userId = AppSession.userId;
    if (userId == null) return Stream.value([]);

    return _notificationsStream(limit: limit);
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

  Future<void> notifyNewEvent({
    required String eventId,
    required String eventTitle,
    required String eventDate,
  }) async {
    await createNotificationForAllUsers(
      type: NotificationType.event,
      title: 'New Event: $eventTitle',
      message: 'A new event has been scheduled on $eventDate',
      relatedId: eventId,
      data: {'eventTitle': eventTitle, 'eventDate': eventDate, 'eventId': eventId},
    );
  }

  Future<void> notifyEventUpdate({
    required String eventId,
    required String eventTitle,
    required String message,
  }) async {
    await createNotificationForAllUsers(
      type: NotificationType.event,
      title: eventTitle,
      message: message,
      relatedId: eventId,
      data: {'eventId': eventId, 'eventTitle': eventTitle},
    );
  }

  Future<void> notifyEventCancelled({
    required String eventId,
    required String eventTitle,
  }) async {
    await notifyEventUpdate(
      eventId: eventId,
      eventTitle: 'Event cancelled: $eventTitle',
      message: 'The event "$eventTitle" has been cancelled.',
    );
  }

  Future<void> notifyNewJob({
    required String jobId,
    required String jobTitle,
    required String companyName,
    List<String> targetPrograms = const [],
  }) async {
    final data = {
      'jobTitle': jobTitle,
      'companyName': companyName,
      'jobId': jobId,
      'target': 'jobs',
    };
    if (targetPrograms.isEmpty) {
      await createNotificationForAllUsers(
        type: NotificationType.job,
        title: 'New Job Opportunity: $jobTitle',
        message: '$companyName is looking for $jobTitle',
        relatedId: jobId,
        data: data,
      );
      return;
    }

    // Targeted: users whose program matches any target course code.
    try {
      final users = await _supabase
          .from('users')
          .select('id, program');
      final targets = targetPrograms.map((e) => e.toUpperCase()).toSet();
      final ids = <String>[];
      for (final u in users) {
        final program = (u['program'] as String? ?? '').toUpperCase();
        if (targets.any((t) => program.contains(t) || t.contains(program))) {
          final id = u['id']?.toString() ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
      }
      // Also check roster course codes.
      final members = await _supabase
          .from('alumni_members')
          .select('auth_uid, course')
          .eq('is_registered_user', true)
          .eq('is_deactivated', false);
      for (final m in members) {
        final course = (m['course'] as String? ?? '').toUpperCase();
        if (targets.contains(course)) {
          final id = m['auth_uid']?.toString() ?? '';
          if (id.isNotEmpty) ids.add(id);
        }
      }
      final unique = ids.toSet().toList();
      if (unique.isEmpty) {
        await createNotificationForAllUsers(
          type: NotificationType.job,
          title: 'New Job Opportunity: $jobTitle',
          message: '$companyName is looking for $jobTitle',
          relatedId: jobId,
          data: data,
        );
        return;
      }
      for (final id in unique) {
        await createNotification(
          userId: id,
          type: NotificationType.job,
          title: 'New Job Opportunity: $jobTitle',
          message: '$companyName is looking for $jobTitle',
          relatedId: jobId,
          data: data,
        );
      }
    } catch (_) {
      await createNotificationForAllUsers(
        type: NotificationType.job,
        title: 'New Job Opportunity: $jobTitle',
        message: '$companyName is looking for $jobTitle',
        relatedId: jobId,
        data: data,
      );
    }
  }

  /// Notify alumni who favorited or expressed interest in this job.
  Future<void> notifyJobUpdated({
    required String jobId,
    required String jobTitle,
    required String companyName,
  }) async {
    final userIds = <String>{};
    try {
      final favs = await _supabase
          .from('favorite_jobs')
          .select('user_id')
          .eq('job_id', jobId);
      for (final r in favs) {
        final id = r['user_id']?.toString() ?? '';
        if (id.isNotEmpty) userIds.add(id);
      }
    } catch (_) {}
    try {
      final interests = await _supabase
          .from('job_interests')
          .select('user_id')
          .eq('job_id', jobId);
      for (final r in interests) {
        final id = r['user_id']?.toString() ?? '';
        if (id.isNotEmpty) userIds.add(id);
      }
    } catch (_) {}

    for (final id in userIds) {
      await createNotification(
        userId: id,
        type: NotificationType.job,
        title: 'Job updated: $jobTitle',
        message: '$companyName updated "$jobTitle"',
        relatedId: jobId,
        data: {
          'jobId': jobId,
          'jobTitle': jobTitle,
          'companyName': companyName,
          'target': 'jobs',
          'kind': 'job_updated',
        },
      );
    }
  }

  Future<void> notifyJobRestored({
    required String jobId,
    required String jobTitle,
    required String companyName,
  }) {
    return notifyJobUpdated(
      jobId: jobId,
      jobTitle: jobTitle,
      companyName: companyName,
    );
  }

  /// Client-side deadline reminder (deduped by kind+jobId in data).
  Future<void> notifyJobDeadlineIfNeeded({
    required String userId,
    required String jobId,
    required String jobTitle,
    required String companyName,
    required int daysLeft,
  }) async {
    if (userId.isEmpty || jobId.isEmpty) return;
    if (daysLeft != 1 && daysLeft != 3) return;
    final kind = 'job_deadline_${daysLeft}d';
    try {
      final existing = await _supabase
          .from('user_notifications')
          .select('id, data')
          .eq('user_id', userId)
          .eq('related_id', jobId)
          .eq('type', 'job')
          .limit(40);
      for (final row in existing) {
        final data = row['data'];
        if (data is Map && data['kind'] == kind) return;
      }
    } catch (_) {}

    await createNotification(
      userId: userId,
      type: NotificationType.job,
      title: daysLeft == 1
          ? 'Deadline tomorrow: $jobTitle'
          : 'Deadline in 3 days: $jobTitle',
      message: '$companyName — application deadline approaching',
      relatedId: jobId,
      data: {
        'jobId': jobId,
        'jobTitle': jobTitle,
        'companyName': companyName,
        'target': 'jobs',
        'kind': kind,
        'daysLeft': daysLeft,
      },
    );
  }

  Future<void> notifyNewMessage({
    required String userId,
    required String messageId,
    required String senderName,
    String? senderId,
    String senderRole = '',
    String? preview,
  }) async {
    if (userId.isEmpty || messageId.isEmpty) return;

    // Prefer SECURITY DEFINER RPC so alumni→admin notifies work under RLS.
    try {
      await _supabase.rpc(
        'notify_new_message',
        params: {
          'p_recipient_id': userId,
          'p_message_id': messageId,
          'p_sender_name': senderName,
          'p_sender_id': senderId,
          'p_sender_role': senderRole,
          'p_preview': preview,
        },
      );
      return;
    } catch (_) {
      // Fall through for environments where the RPC is not deployed yet.
    }

    // Dedupe client-side when falling back to direct insert.
    try {
      final existing = await _supabase
          .from('user_notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('type', 'message')
          .contains('data', {'messageId': messageId})
          .limit(1);
      if (existing.isNotEmpty) return;
    } catch (_) {}

    final conversationUserId = senderRole.toLowerCase() == 'admin'
        ? userId
        : (senderId ?? userId);

    await createNotification(
      userId: userId,
      type: NotificationType.message,
      title: senderRole.toLowerCase() == 'admin'
          ? 'New message from Alumni Office'
          : 'New Message from $senderName',
      message: (preview != null && preview.trim().isNotEmpty)
          ? preview.trim()
          : 'You have received a new message',
      relatedId: messageId,
      data: {
        'senderName': senderName,
        'senderId': senderId,
        'senderRole': senderRole,
        'messageId': messageId,
        'conversationUserId': conversationUserId,
        'relatedId': messageId,
        'target': 'messages',
      },
    );
  }

  Stream<List<NotificationModel>> _notificationsStream({
    int limit = 50,
  }) {
    final controller = StreamController<List<NotificationModel>>();
    final userId = AppSession.userId;
    if (userId == null) {
      controller.add([]);
      return controller.stream;
    }

    Future<void> emit() async {
      final items = await getUserNotifications(limit: limit);
      if (!controller.isClosed) controller.add(items);
    }

    StreamSubscription<dynamic>? sub;
    Timer? poller;

    Future<void> startPolling() async {
      await emit();
      poller?.cancel();
      poller = Timer.periodic(
        const Duration(seconds: 15),
        (_) => emit(),
      );
    }

    controller.onListen = () async {
      await emit();
      try {
        sub = _supabase
            .from('user_notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .listen(
              (_) => emit(),
              onError: (_) => startPolling(),
            );
      } catch (_) {
        await startPolling();
      }
    };

    controller.onCancel = () async {
      await sub?.cancel();
      poller?.cancel();
    };

    return controller.stream;
  }
}
