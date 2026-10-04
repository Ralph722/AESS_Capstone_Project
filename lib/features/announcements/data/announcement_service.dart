import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/core/services/email_service.dart';
/// Announcements data access — Supabase only.
class AnnouncementService {
  AnnouncementService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<Announcement>> getAllAnnouncements() async {
    final rows = await _supabase
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return rows.map(Announcement.fromSupabaseRow).toList();
  }

  Future<int> countPublishedAnnouncements() async {
    try {
      final rows = await _supabase
          .from('announcements')
          .select('id')
          .eq('status', AnnouncementStatus.published.name);
      return rows.length;
    } catch (_) {
      final list = await getAllAnnouncements();
      return list
          .where((a) => a.status == AnnouncementStatus.published)
          .length;
    }
  }

  Future<Announcement?> getAnnouncement(String id) async {
    final row = await _supabase
        .from('announcements')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Announcement.fromSupabaseRow(row);
  }

  Future<String> createAnnouncement({
    required String title,
    required String body,
    AnnouncementPriority priority = AnnouncementPriority.normal,
  }) async {
    final userId = AppSession.requireUserId();

    final announcement = Announcement(
      id: LocalId.generate(),
      title: title,
      body: body,
      status: AnnouncementStatus.draft,
      priority: priority,
      createdBy: userId,
      createdAt: DateTime.now(),
    );

    try {
      await _supabase.from('announcements').upsert(
            announcement.toSupabaseRow(),
            onConflict: 'id',
          );
    } catch (e) {
      throw Exception('Error creating announcement: $e');
    }

    return announcement.id;
  }

  Future<void> updateAnnouncement(Announcement announcement) async {
    try {
      await _supabase.from('announcements').upsert(
            announcement.toSupabaseRow(),
            onConflict: 'id',
          );
    } catch (e) {
      throw Exception('Error updating announcement: $e');
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      await _supabase.from('announcements').delete().eq('id', id);
    } catch (e) {
      throw Exception('Error deleting announcement: $e');
    }
  }

  Future<void> archiveAnnouncement(String id) async {
    final item = await getAnnouncement(id);
    if (item == null) throw Exception('Announcement not found');

    final archived = item.copyWith(status: AnnouncementStatus.archived);
    await updateAnnouncement(archived);
  }

  Future<List<TracerProfile>> _fetchEligibleAlumni() async {
    final rows = await _supabase.from('users').select();
    return rows
        .where((row) => (row['role'] as String? ?? 'user').toLowerCase() != 'admin')
        .map(TracerProfile.fromSupabaseRow)
        .toList();
  }

  bool _matchesTarget(Announcement item, TracerProfile profile) {
    return AudienceTargeting.matches(
      targetPrograms: item.targetPrograms,
      targetBatchYears: item.targetBatchYears,
      profile: profile,
    );
  }

  Future<int> countAudience({
    required List<String> targetPrograms,
    required List<String> targetBatchYears,
  }) async {
    final profiles = await _fetchEligibleAlumni();
    return AudienceTargeting.countMatches(
      targetPrograms: targetPrograms,
      targetBatchYears: targetBatchYears,
      profiles: profiles,
    );
  }

  Future<int> publishAnnouncement(String id) async {
    final item = await getAnnouncement(id);
    if (item == null) throw Exception('Announcement not found');
    if (item.title.trim().isEmpty || item.body.trim().isEmpty) {
      throw Exception('Title and body are required');
    }

    final profiles = await _fetchEligibleAlumni();
    final matched = <String, TracerProfile>{};
    for (final profile in profiles) {
      if (_matchesTarget(item, profile)) {
        matched[profile.uid] = profile;
      }
    }

    if (matched.isEmpty) {
      final hasFilters = item.targetPrograms.isNotEmpty ||
          item.targetBatchYears.isNotEmpty;
      throw Exception(
        hasFilters
            ? 'No alumni in this program/batch range. Check tracer profiles or adjust filters.'
            : 'No alumni accounts found to notify.',
      );
    }

    // In-app notices are created by the announcements trigger when the
    // status flips to published (notify_announcement_published).
    EmailService? emailService;
    if (item.notifyEmail && EmailDeliveryConfig.isConfigured) {
      emailService = EmailService();
    }

    if (item.notifyEmail && emailService != null) {
      for (final entry in matched.entries) {
        final profile = entry.value;
        final address = profile.email.trim();
        if (address.isEmpty || !address.contains('@')) continue;
        final name = profile.displayName.isNotEmpty
            ? profile.displayName
            : address;
        try {
          await emailService.sendSurveyReminderEmail(
            toEmail: address,
            userName: name,
            surveyTitle: item.title,
            message: item.body,
          );
        } catch (_) {}
      }
    }

    final published = item.copyWith(
      status: AnnouncementStatus.published,
      publishedAt: DateTime.now(),
      recipientCount: matched.length,
    );
    await updateAnnouncement(published);

    return matched.length;
  }

  Future<List<Announcement>> getPublishedForUser(String userId) async {
    final userRow = await _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (userRow == null) return [];
    final profile = TracerProfile.fromSupabaseRow(userRow);

    final rows = await _supabase
        .from('announcements')
        .select()
        .eq('status', AnnouncementStatus.published.name);
    final published = rows.map(Announcement.fromSupabaseRow).toList();

    final list = published.where((a) => _matchesTarget(a, profile)).toList();
    list.sort((a, b) {
      final ad = a.publishedAt ?? a.createdAt;
      final bd = b.publishedAt ?? b.createdAt;
      return bd.compareTo(ad);
    });
    return list;
  }

  /// Last list delivered per user, so reopening the screen can paint
  /// immediately while the live subscription reconnects.
  static final Map<String, List<Announcement>> _lastPublishedByUser = {};

  List<Announcement>? cachedPublishedForUser(String userId) =>
      _lastPublishedByUser[userId];

  Stream<List<Announcement>> watchPublishedForUser(String userId) {
    final controller = StreamController<List<Announcement>>();
    var delivered = false;

    Future<void> emit() async {
      try {
        final list = await getPublishedForUser(userId);
        _lastPublishedByUser[userId] = list;
        delivered = true;
        if (!controller.isClosed) controller.add(list);
      } catch (e, st) {
        // Keep showing the last good list on a transient refresh failure.
        if (!delivered && !controller.isClosed) controller.addError(e, st);
      }
    }

    StreamSubscription<dynamic>? sub;
    Timer? poller;

    Future<void> startPolling() async {
      await sub?.cancel();
      sub = null;
      poller?.cancel();
      poller = Timer.periodic(const Duration(seconds: 20), (_) => emit());
    }

    controller.onListen = () async {
      await emit();
      try {
        sub = _supabase
            .from('announcements')
            .stream(primaryKey: ['id'])
            .eq('status', AnnouncementStatus.published.name)
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
}
