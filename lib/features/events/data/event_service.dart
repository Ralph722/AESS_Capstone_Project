import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/audit_events.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/core/utils/local_id.dart';
import 'package:alumni_system/features/events/models/event_agenda_item.dart';
import 'package:alumni_system/features/events/models/event_model.dart';

/// Events data access — Supabase only.
class EventService {
  EventService({SupabaseClient? supabase, AuditService? auditService})
    : _supabase = supabase ?? Supabase.instance.client,
      _audit = auditService ?? AuditService(supabase: supabase);

  final SupabaseClient _supabase;
  final AuditService _audit;

  Future<void> addEvent(AlumniEvent event) async {
    await _supabase
        .from('events')
        .upsert(event.toSupabaseRow(), onConflict: 'id');
    unawaited(
      _audit.logAction(
        action: AuditActions.createEvent,
        resource: 'Event',
        resourceId: event.id,
        description: 'Created event: ${event.theme}',
        userRole: 'admin',
        module: AuditModules.events,
        targetLabel: event.theme,
      ),
    );
  }

  Future<void> autoArchivePastEvents() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final active = await _fetchActiveFromSupabase();

      for (final event in active) {
        final eventDate = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
        );
        if (eventDate.isBefore(today)) {
          await updateEventStatus(event.id, 'Archived', audit: false);
        }
      }
    } catch (_) {}
  }

  Future<List<AlumniEvent>> getActiveEvents({
    bool runAutoArchive = true,
  }) async {
    if (runAutoArchive) {
      await autoArchivePastEvents();
    }
    final events = await _fetchActiveFromSupabase();
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  Future<List<AlumniEvent>> getUpcomingEvents({
    bool runAutoArchive = true,
  }) async {
    // Archive in the background so Home / lists are not blocked on a second
    // full fetch plus per-event status updates.
    if (runAutoArchive) {
      unawaited(autoArchivePastEvents());
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final events = await getActiveEvents(runAutoArchive: false);
    return events.where((event) {
      final eventDate = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      return eventDate.isAtSameMomentAs(today) || eventDate.isAfter(today);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Columns needed by [AlumniEvent.fromSupabaseRow].
  static const eventSelectColumns =
      'id, theme, batch_year, date, venue, status, comments_count, '
      'start_time, end_time, description, created_at, cover_image_url, '
      'category, capacity, registration_deadline, agenda, views_count, '
      'cancelled, venue_latitude, venue_longitude';

  Future<AlumniEvent?> getEventById(String eventId) async {
    final id = eventId.trim();
    if (id.isEmpty) return null;
    try {
      final row = await _supabase
          .from('events')
          .select(eventSelectColumns)
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

  Future<void> updateEventStatus(
    String eventId,
    String newStatus, {
    bool audit = true,
  }) async {
    await _supabase
        .from('events')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', eventId);
    if (!audit) return;
    final action = switch (newStatus) {
      'Archived' => AuditActions.archiveEvent,
      'Active' => AuditActions.publishEvent,
      'Draft' => AuditActions.updateEvent,
      _ => AuditActions.updateEvent,
    };
    unawaited(
      _audit.logAction(
        action: action,
        resource: 'Event',
        resourceId: eventId,
        description: 'Event status → $newStatus',
        changes: {'status': newStatus},
        userRole: 'admin',
        module: AuditModules.events,
      ),
    );
  }

  Future<void> deleteEvent(String eventId) async {
    await _supabase.from('events').delete().eq('id', eventId);
    unawaited(
      _audit.logAction(
        action: AuditActions.deleteEvent,
        resource: 'Event',
        resourceId: eventId,
        description: 'Deleted event',
        userRole: 'admin',
        module: AuditModules.events,
        category: AuditCategories.security,
      ),
    );
  }

  Future<void> archiveEvent(String eventId) async {
    final event = await getEventById(eventId);
    if (event == null) throw Exception('Event not found');
    if (event.status == 'Archived') return;
    if (event.status == 'Draft') {
      throw Exception(
        'Draft events cannot be archived. Delete or publish them first.',
      );
    }
    await updateEventStatus(eventId, 'Archived');
  }

  Future<List<AlumniEvent>> getArchivedEvents() async {
    final events = await _fetchArchivedFromSupabase();
    events.sort((a, b) => b.date.compareTo(a.date));
    return events;
  }

  Future<List<AlumniEvent>> getDraftEvents() async {
    final events = await _fetchDraftFromSupabase();
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  Future<int> getTotalEventsCount() async {
    try {
      return await _supabase.from('events').count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  Future<int> getExpiringEventsCount() async {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));
    final active = await getActiveEvents(runAutoArchive: true);
    return active
        .where(
          (event) =>
              event.date.isAfter(now) && event.date.isBefore(sevenDaysLater),
        )
        .length;
  }

  Future<int> getArchivedEventsCount() async {
    final archived = await getArchivedEvents();
    return archived.length;
  }

  Future<void> updateEvent(AlumniEvent event) async {
    await _supabase
        .from('events')
        .upsert(event.toSupabaseRow(), onConflict: 'id');
    unawaited(
      _audit.logAction(
        action: AuditActions.updateEvent,
        resource: 'Event',
        resourceId: event.id,
        description: 'Updated event: ${event.theme}',
        userRole: 'admin',
        module: AuditModules.events,
        targetLabel: event.theme,
      ),
    );
  }

  /// Publishes a draft event so alumni can see it.
  Future<void> publishEvent(String eventId) async {
    final event = await getEventById(eventId);
    if (event == null) throw Exception('Event not found');
    if (event.status != 'Draft') {
      throw Exception(
        'Archived events cannot be restored. '
        'Duplicate to create a new draft from this template.',
      );
    }
    await updateEventStatus(eventId, 'Active');
  }

  /// Clones an event as a new draft (template only — no RSVPs).
  Future<String> duplicateEvent(String sourceId) async {
    final source = await getEventById(sourceId);
    if (source == null) throw Exception('Event not found');
    final baseTheme = source.theme.trim().isEmpty
        ? 'Untitled event'
        : source.theme.trim();
    final copy = AlumniEvent(
      id: LocalId.generate(),
      theme: baseTheme.endsWith('(Copy)') ? baseTheme : '$baseTheme (Copy)',
      batchYear: source.batchYear,
      date: source.date,
      venue: source.venue,
      status: 'Draft',
      comments: 0,
      startTime: source.startTime,
      endTime: source.endTime,
      description: source.description,
      createdAt: DateTime.now(),
      coverImageUrl: source.coverImageUrl,
      category: source.category,
      capacity: source.capacity,
      registrationDeadline: source.registrationDeadline,
      agenda: [
        for (final item in source.agenda)
          EventAgendaItem(time: item.time, title: item.title),
      ],
      viewsCount: 0,
      cancelled: false,
      venueLatitude: source.venueLatitude,
      venueLongitude: source.venueLongitude,
    );
    await _supabase.from('events').upsert(copy.toSupabaseRow(), onConflict: 'id');
    unawaited(
      _audit.logAction(
        action: AuditActions.duplicateEvent,
        resource: 'Event',
        resourceId: copy.id,
        description: 'Duplicated event as draft: ${copy.theme}',
        changes: {'sourceId': sourceId},
        userRole: 'admin',
        module: AuditModules.events,
        targetLabel: copy.theme,
      ),
    );
    return copy.id;
  }

  Future<void> cancelEvent(String eventId) async {
    await _supabase
        .from('events')
        .update({
          'cancelled': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', eventId);
    unawaited(
      _audit.logAction(
        action: AuditActions.cancelEvent,
        resource: 'Event',
        resourceId: eventId,
        description: 'Cancelled event',
        userRole: 'admin',
        module: AuditModules.events,
      ),
    );
  }

  Future<void> incrementViews(String eventId) async {
    try {
      final row = await _supabase
          .from('events')
          .select('views_count')
          .eq('id', eventId)
          .maybeSingle();
      final current = (row?['views_count'] as int?) ?? 0;
      await _supabase
          .from('events')
          .update({
            'views_count': current + 1,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', eventId);
    } catch (_) {}
  }

  Stream<List<AlumniEvent>> getActiveEventsStream() {
    return _supabase
        .from('events')
        .stream(primaryKey: ['id'])
        .map(
          (rows) =>
              rows
                  .map(AlumniEvent.fromSupabaseRow)
                  .where((e) => e.status == 'Active')
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date)),
        );
  }

  Stream<List<AlumniEvent>> getUpcomingEventsStream() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return getActiveEventsStream().map((events) {
      return events.where((event) {
        final eventDate = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
        );
        return eventDate.isAtSameMomentAs(today) || eventDate.isAfter(today);
      }).toList();
    });
  }

  Future<List<AlumniEvent>> _fetchActiveFromSupabase() async {
    try {
      final rows = await _supabase
          .from('events')
          .select(eventSelectColumns)
          .eq('status', 'Active')
          .order('date', ascending: true)
          .limit(200);
      return rows.map(AlumniEvent.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AlumniEvent>> _fetchArchivedFromSupabase() async {
    try {
      final rows = await _supabase
          .from('events')
          .select(eventSelectColumns)
          .eq('status', 'Archived')
          .order('date', ascending: false)
          .limit(100);
      return rows.map(AlumniEvent.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AlumniEvent>> _fetchDraftFromSupabase() async {
    try {
      final rows = await _supabase
          .from('events')
          .select(eventSelectColumns)
          .eq('status', 'Draft')
          .order('date', ascending: true)
          .limit(100);
      return rows.map(AlumniEvent.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AlumniEvent>> _fetchAllFromSupabase() async {
    try {
      final rows = await _supabase
          .from('events')
          .select(eventSelectColumns)
          .order('date', ascending: true)
          .limit(300);
      return rows.map(AlumniEvent.fromSupabaseRow).toList();
    } catch (_) {
      return [];
    }
  }
}
