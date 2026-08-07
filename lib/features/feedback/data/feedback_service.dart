import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/feedback/models/feedback_model.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/core/services/supabase_user_bridge.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';

/// Feedback data access — Supabase only.
class FeedbackService {
  FeedbackService({
    SupabaseClient? supabase,
    SupabaseUserBridge? bridge,
    AuditService? auditService,
    NotificationService? notificationService,
    UserProfileService? userProfileService,
    AuthService? authService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _bridge = bridge ?? SupabaseUserBridge(client: supabase),
        _auditService = auditService ?? AuditService(),
        _notificationService = notificationService ?? NotificationService(),
        _userProfileService = userProfileService ?? UserProfileService(),
        _authService = authService ?? AuthService();

  final SupabaseClient _supabase;
  final SupabaseUserBridge _bridge;
  final AuditService _auditService;
  final NotificationService _notificationService;
  final UserProfileService _userProfileService;
  final AuthService _authService;

  Future<void> _assertAdminCaller() async {
    final uid = AppSession.userId;
    if (uid == null) throw Exception('Not authenticated');
    final role = await _authService.getUserRole(uid);
    if (role != UserRole.admin) {
      throw Exception('Admin access required');
    }
  }

  Future<String> submitFeedback({
    required FeedbackCategory category,
    String? subject,
    required String message,
    int? rating,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) {
      throw Exception('You must be signed in to send feedback.');
    }

    final trimmedMessage = message.trim();
    if (trimmedMessage.length < 10) {
      throw Exception('Please enter at least 10 characters in your message.');
    }

    final profile = await _userProfileService.getTracerProfile();
    final now = DateTime.now();

    final trimmedSubject = subject?.trim();
    final safeSubject =
        (trimmedSubject != null && trimmedSubject.isNotEmpty) ? trimmedSubject : null;

    final userName = (profile?.displayName.trim().isNotEmpty == true)
        ? profile!.displayName
        : (AppSession.email ?? 'Alumni');

    final userEmail = AppSession.email ?? profile?.email ?? '';

    final submission = FeedbackSubmission(
      id: LocalId.generate(),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      program: profile?.program,
      batchYear: profile?.batchYear,
      category: category,
      subject: safeSubject,
      message: trimmedMessage,
      rating: rating,
      status: FeedbackStatus.submitted,
      createdAt: now,
    );

    try {
      final supabaseUserId = await _bridge.resolveSupabaseUserId(userId);
      if (supabaseUserId == null) {
        throw Exception('User not found');
      }
      await _supabase.from('feedback').upsert(
            submission.toSupabaseRow(supabaseUserId: supabaseUserId),
            onConflict: 'id',
          );
    } catch (e) {
      throw Exception('Error submitting feedback: $e');
    }

    final short = trimmedMessage.length > 60
        ? '${trimmedMessage.substring(0, 60)}…'
        : trimmedMessage;

    await _auditService.logAction(
      action: 'SUBMIT_FEEDBACK',
      resource: 'Feedback',
      resourceId: submission.id,
      description:
          'Submitted ${category.label} feedback: ${safeSubject ?? short}',
      userRole: 'user',
    );

    return submission.id;
  }

  Stream<List<FeedbackSubmission>> watchMyFeedback() {
    final userId = AppSession.userId;
    if (userId == null) return Stream.value([]);

    final controller = StreamController<List<FeedbackSubmission>>();

    Future<void> emit() async {
      try {
        final items = await _fetchMyFeedback(userId);
        if (!controller.isClosed) controller.add(items);
      } catch (_) {
        if (!controller.isClosed) controller.add(const []);
      }
    }

    StreamSubscription<dynamic>? sub;
    Timer? poller;

    Future<void> startPolling() async {
      await sub?.cancel();
      sub = null;
      poller?.cancel();
      poller = Timer.periodic(const Duration(seconds: 15), (_) => emit());
    }

    controller.onListen = () async {
      await emit();
      try {
        final supabaseUserId = await _bridge.resolveSupabaseUserId(userId);
        if (supabaseUserId == null) {
          await startPolling();
          return;
        }
        sub = _supabase
            .from('feedback')
            .stream(primaryKey: ['id'])
            .eq('user_id', supabaseUserId)
            .listen(
              (_) => emit(),
              onError: (_) => startPolling(),
              cancelOnError: true,
            );
      } catch (_) {
        await startPolling();
      }
    };

    controller.onCancel = () async {
      poller?.cancel();
      await sub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<FeedbackSubmission>> watchAllFeedback({
    FeedbackStatus? statusFilter,
    FeedbackCategory? categoryFilter,
  }) {
    final controller = StreamController<List<FeedbackSubmission>>();

    Future<void> emit() async {
      try {
        var items = await _fetchAllFeedback();
        if (statusFilter != null) {
          items = items.where((f) => f.status == statusFilter).toList();
        }
        if (categoryFilter != null) {
          items = items.where((f) => f.category == categoryFilter).toList();
        }
        if (!controller.isClosed) controller.add(items);
      } catch (_) {
        // Network / CORS failures should not crash admin streams.
        if (!controller.isClosed) controller.add(const []);
      }
    }

    StreamSubscription<dynamic>? sub;
    Timer? poller;

    Future<void> startPolling() async {
      await emit();
      poller?.cancel();
      poller = Timer.periodic(
        const Duration(seconds: 10),
        (_) => emit(),
      );
    }

    controller.onListen = () async {
      await emit();
      try {
        sub = _supabase
            .from('feedback')
            .stream(primaryKey: ['id'])
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

  Stream<int> watchOpenFeedbackCount() {
    return watchAllFeedback()
        .map((items) => items.where((f) => f.isOpen).length);
  }

  Future<int> countOpenFeedback() async {
    final items = await _fetchAllFeedback();
    return items.where((f) => f.isOpen).length;
  }

  Future<FeedbackSubmission?> getFeedbackById(String id) async {
    final row = await _supabase
        .from('feedback')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return FeedbackSubmission.fromSupabaseRow(row);
  }

  Future<FeedbackSubmission?> getFeedbackByIdForAdmin(String id) async {
    final item = await getFeedbackById(id);
    if (item == null) return null;
    if (item.hasAdminResponse &&
        (item.status == FeedbackStatus.submitted ||
            item.status == FeedbackStatus.inReview)) {
      await _updateFeedbackRecord(
        id,
        status: FeedbackStatus.resolved,
      );
      return getFeedbackById(id);
    }
    return item;
  }

  Future<void> updateStatus({
    required String feedbackId,
    required FeedbackStatus status,
  }) async {
    await _assertAdminCaller();

    final existing = await getFeedbackById(feedbackId);
    if (existing == null) throw Exception('Feedback not found');

    await _updateFeedbackRecord(feedbackId, status: status);

    await _auditService.logAction(
      action: 'UPDATE_FEEDBACK_STATUS',
      resource: 'Feedback',
      resourceId: feedbackId,
      description:
          'Changed feedback status from ${existing.status.label} to ${status.label}',
      userRole: 'admin',
    );

    if (status == FeedbackStatus.resolved || status == FeedbackStatus.closed) {
      await _notifySubmitter(
        userId: existing.userId,
        feedbackId: feedbackId,
        title: 'Feedback update',
        message: 'Your feedback is now marked as ${status.label.toLowerCase()}.',
      );
    }
  }

  Future<void> respondToFeedback({
    required String feedbackId,
    required String adminResponse,
    FeedbackStatus? status,
  }) async {
    await _assertAdminCaller();

    final trimmed = adminResponse.trim();
    if (trimmed.isEmpty) throw Exception('Please enter a response.');

    final existing = await getFeedbackById(feedbackId);
    if (existing == null) throw Exception('Feedback not found');

    final newStatus = _statusAfterAdminResponse(status);
    final admin = AppSession.currentUser;
    final adminName = (admin?.userMetadata?['display_name'] as String?) ??
        admin?.email ??
        'Admin';
    final respondedAt = DateTime.now();

    await _updateFeedbackRecord(
      feedbackId,
      status: newStatus,
      adminResponse: trimmed,
      respondedBy: AppSession.requireUserId(),
      respondedByName: adminName,
      respondedAt: respondedAt,
      base: existing,
    );

    await _auditService.logAction(
      action: 'RESPOND_TO_FEEDBACK',
      resource: 'Feedback',
      resourceId: feedbackId,
      description: 'Replied to feedback from ${existing.userName}',
      userRole: 'admin',
    );

    await _notifySubmitter(
      userId: existing.userId,
      feedbackId: feedbackId,
      title: 'Response to your feedback',
      message: trimmed.length > 120 ? '${trimmed.substring(0, 120)}…' : trimmed,
    );
  }

  FeedbackStatus _statusAfterAdminResponse(FeedbackStatus? status) {
    if (status == FeedbackStatus.closed) return FeedbackStatus.closed;
    return FeedbackStatus.resolved;
  }

  Future<void> _updateFeedbackRecord(
    String feedbackId, {
    FeedbackStatus? status,
    String? adminResponse,
    String? respondedBy,
    String? respondedByName,
    DateTime? respondedAt,
    FeedbackSubmission? base,
  }) async {
    final existing = base ?? await getFeedbackById(feedbackId);
    if (existing == null) throw Exception('Feedback not found');

    final updated = FeedbackSubmission(
      id: existing.id,
      userId: existing.userId,
      userName: existing.userName,
      userEmail: existing.userEmail,
      program: existing.program,
      batchYear: existing.batchYear,
      category: existing.category,
      subject: existing.subject,
      message: existing.message,
      rating: existing.rating,
      status: status ?? existing.status,
      adminResponse: adminResponse ?? existing.adminResponse,
      respondedBy: respondedBy ?? existing.respondedBy,
      respondedByName: respondedByName ?? existing.respondedByName,
      respondedAt: respondedAt ?? existing.respondedAt,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      final supabaseUserId = await _bridge.resolveSupabaseUserId(existing.userId);
      if (supabaseUserId == null) {
        throw Exception('User not found');
      }
      await _supabase.from('feedback').upsert(
            updated.toSupabaseRow(supabaseUserId: supabaseUserId),
            onConflict: 'id',
          );
    } catch (e) {
      throw Exception('Error updating feedback: $e');
    }
  }

  Future<List<FeedbackSubmission>> _fetchMyFeedback(String userId) async {
    final supabaseUserId = await _bridge.resolveSupabaseUserId(userId);
    if (supabaseUserId == null) return [];

    final rows = await _supabase
        .from('feedback')
        .select()
        .eq('user_id', supabaseUserId);
    final list = rows.map(FeedbackSubmission.fromSupabaseRow).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<FeedbackSubmission>> _fetchAllFeedback() async {
    final rows = await _supabase
        .from('feedback')
        .select()
        .order('created_at', ascending: false);
    return rows.map(FeedbackSubmission.fromSupabaseRow).toList();
  }

  Future<void> _notifySubmitter({
    required String userId,
    required String feedbackId,
    required String title,
    required String message,
  }) async {
    try {
      await _notificationService.createNotification(
        userId: userId,
        type: NotificationType.feedback,
        title: title,
        message: message,
        relatedId: feedbackId,
        data: {'feedbackId': feedbackId},
      );
    } catch (_) {}
  }
}
