import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/events/models/event_model.dart';

/// Events data access — Supabase only.
class EventService {
  EventService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> addEvent(AlumniEvent event) async {
    await _supabase.from('events').upsert(
          event.toSupabaseRow(),
          onConflict: 'id',
        );
  }

  Future<void> autoArchivePastEvents() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final active = await _fetchActiveFromSupabase();

      for (final event in active) {
        final eventDate =
            DateTime(event.date.year, event.date.month, event.date.day);
        if (eventDate.isBefore(today)) {
          await updateEventStatus(event.id, 'Archived');
        }
      }
    } catch (_) {}
  }

  Future<List<AlumniEvent>> getActiveEvents({bool runAutoArchive = true}) async {
    if (runAutoArchive) {
      await autoArchivePastEvents();
    }
    final events = await _fetchActiveFromSupabase();
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  Future<List<AlumniEvent>> getUpcomingEvents() async {
    await autoArchivePastEvents();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final events = await getActiveEvents(runAutoArchive: false);
    return events
        .where((event) {
          final eventDate =
              DateTime(event.date.year, event.date.month, event.date.day);
          return eventDate.isAtSameMomentAs(today) || eventDate.isAfter(today);
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<AlumniEvent?> getEventById(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return null;
    try {
      final row = await _supabase
          .from('events')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return AlumniEvent.fromSupabaseRow(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<AlumniEvent>> getAllEvents() async {
    final events = await _fetchAllFromSupabase();
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  Future<List<AlumniEvent>> getEventsByBatchYear(String batchYear) async {
    final events = await getActiveEvents();
    return events.where((e) => e.batchYear == batchYear).toList();
  }

  Future<void> updateEventStatus(String eventId, String newStatus) async {
    await _supabase.from('events').update({
      'status': newStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    await _supabase.from('events').delete().eq('id', eventId);
  }

  Future<void> archiveEvent(String eventId) async {
    await updateEventStatus(eventId, 'Archived');
  }

  Future<List<AlumniEvent>> getArchivedEvents() async {
    final events = await _fetchArchivedFromSupabase();
    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  Future<int> getTotalEventsCount() async {
    try {
      final rows = await _supabase.from('events').select('id');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getExpiringEventsCount() async {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));
    final active = await getActiveEvents(runAutoArchive: true);
    return active
        .where((event) =>
            event.date.isAfter(now) && event.date.isBefore(sevenDaysLater))
        .length;
  }

  Future<int> getArchivedEventsCount() async {
    final archived = await getArchivedEvents();
    return archived.length;
  }

  Future<void> updateEvent(AlumniEvent event) async {
    await _supabase.from('events').upsert(
          event.toSupabaseRow(),
          onConflict: 'id',
        );
  }

  Future<void> restoreEvent(String eventId) async {
    await updateEventStatus(eventId, 'Active');
  }

  Future<void> cancelEvent(String eventId) async {
    await _supabase.from('events').update({
      'cancelled': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', eventId);
  }

  Future<void> incrementViews(String eventId) async {
    try {
      final row = await _supabase
          .from('events')
          .select('views_count')
          .eq('id', eventId)
          .maybeSingle();
      final current = (row?['views_count'] as int?) ?? 0;
      await _supabase.from('events').update({
        'views_count': current + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', eventId);
    } catch (_) {}
  }

  Stream<List<AlumniEvent>> getActiveEventsStream() {
    return _supabase
        .from('events')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
            .map(AlumniEvent.fromSupabaseRow)
            .where((e) => e.status == 'Active')
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date)));
  }

  Stream<List<AlumniEvent>> getUpcomingEventsStream() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return getActiveEventsStream().map((events) {
      return events
          .where((event) {
            final eventDate =
                DateTime(event.date.year, event.date.month, event.date.day);
            return eventDate.isAtSameMomentAs(today) ||
                eventDate.isAfter(today);
          })
          .toList();
    });
  }

  Future<void> addReminder(String userId, String eventId) async {
    try {
      await _supabase.from('reminders').upsert({
        'user_id': userId,
        'title': 'event:$eventId',
        'data': {'eventId': eventId},
      });
    } catch (e) {
      throw Exception('Error adding reminder: $e');
    }
  }

  Future<void> removeReminder(String userId, String eventId) async {
    try {
      await _supabase
          .from('reminders')
          .delete()
          .eq('user_id', userId)
          .eq('title', 'event:$eventId');
    } catch (e) {
      throw Exception('Error removing reminder: $e');
    }
  }

  Future<bool> hasReminder(String userId, String eventId) async {
    try {
      final row = await _supabase
          .from('reminders')
          .select('title')
          .eq('user_id', userId)
          .eq('title', 'event:$eventId')
          .maybeSingle();
      return row != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> addNotification(
    String userId,
    String title,
    String message,
    String eventId,
  ) async {
    try {
      await _supabase.from('user_notifications').insert({
        'user_id': userId,
        'title': title,
        'body': message,
        'type': 'event',
        'is_read': false,
        'data': {'eventId': eventId},
      });
    } catch (e) {
      throw Exception('Error adding notification: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final rows = await _supabase
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getUserNotificationsStream(
    String userId,
  ) {
    return _supabase
        .from('user_notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          final sorted = List<Map<String, dynamic>>.from(rows)
            ..sort((a, b) => (b['created_at'] as String? ?? '')
                .compareTo(a['created_at'] as String? ?? ''));
          return sorted;
        });
  }

  Future<void> markNotificationAsRead(
    String userId,
    String notificationId,
  ) async {
    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Error marking notification as read: $e');
    }
  }

  Future<List<AlumniEvent>> _fetchActiveFromSupabase() async {
    try {
      final rows = await _supabase
          .from('events')
          .select()
          .eq('status', 'Active');
      return rows.map(AlumniEvent.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AlumniEvent>> _fetchArchivedFromSupabase() async {
    try {
      final rows = await _supabase
          .from('events')
          .select()
          .eq('status', 'Archived');
      return rows.map(AlumniEvent.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AlumniEvent>> _fetchAllFromSupabase() async {
    try {
      final rows = await _supabase
          .from('events')
          .select()
          .order('date', ascending: true);
      return rows.map(AlumniEvent.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

}
