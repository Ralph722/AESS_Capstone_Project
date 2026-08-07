import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/events/models/event_rsvp_model.dart';

class EventRsvpService {
  EventRsvpService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<EventRsvp?> getMyRsvp(String eventId) async {
    final userId = AppSession.userId;
    if (userId == null) return null;
    try {
      final row = await _supabase
          .from('event_rsvps')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return EventRsvp.fromSupabaseRow(row);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, EventRsvpStatus>> getMyRsvpsForEvents(
    List<String> eventIds,
  ) async {
    final userId = AppSession.userId;
    if (userId == null || eventIds.isEmpty) return {};
    try {
      final rows = await _supabase
          .from('event_rsvps')
          .select('event_id, status')
          .eq('user_id', userId)
          .inFilter('event_id', eventIds);
      final map = <String, EventRsvpStatus>{};
      for (final row in rows) {
        final id = row['event_id']?.toString();
        final status = EventRsvpStatusX.tryParse(row['status'] as String?);
        if (id != null && status != null) map[id] = status;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<EventRsvpCounts> getCounts(String eventId) async {
    try {
      final rows = await _supabase
          .from('event_rsvps')
          .select('status')
          .eq('event_id', eventId);
      var going = 0;
      var interested = 0;
      var cant = 0;
      for (final row in rows) {
        switch (EventRsvpStatusX.tryParse(row['status'] as String?)) {
          case EventRsvpStatus.going:
            going++;
          case EventRsvpStatus.interested:
            interested++;
          case EventRsvpStatus.cantAttend:
            cant++;
          case null:
            break;
        }
      }
      return EventRsvpCounts(
        going: going,
        interested: interested,
        cantAttend: cant,
      );
    } catch (_) {
      return const EventRsvpCounts();
    }
  }

  Future<Map<String, EventRsvpCounts>> getCountsForEvents(
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return {};
    try {
      final rows = await _supabase
          .from('event_rsvps')
          .select('event_id, status')
          .inFilter('event_id', eventIds);
      final map = <String, EventRsvpCounts>{};
      for (final id in eventIds) {
        map[id] = const EventRsvpCounts();
      }
      for (final row in rows) {
        final id = row['event_id']?.toString();
        if (id == null) continue;
        final current = map[id] ?? const EventRsvpCounts();
        switch (EventRsvpStatusX.tryParse(row['status'] as String?)) {
          case EventRsvpStatus.going:
            map[id] = current.copyWith(going: current.going + 1);
          case EventRsvpStatus.interested:
            map[id] = current.copyWith(interested: current.interested + 1);
          case EventRsvpStatus.cantAttend:
            map[id] = current.copyWith(cantAttend: current.cantAttend + 1);
          case null:
            break;
        }
      }
      return map;
    } catch (_) {
      return {for (final id in eventIds) id: const EventRsvpCounts()};
    }
  }

  Future<List<EventRsvp>> listForEvent(
    String eventId, {
    EventRsvpStatus? status,
  }) async {
    try {
      var query = _supabase
          .from('event_rsvps')
          .select()
          .eq('event_id', eventId);
      if (status != null) {
        query = query.eq('status', status.dbValue);
      }
      final rows = await query.order('updated_at', ascending: false);
      return _attachUserInfo(List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      throw Exception('Error loading RSVPs: $e');
    }
  }

  Future<EventRsvp> setRsvp({
    required String eventId,
    required EventRsvpStatus status,
  }) async {
    final userId = AppSession.userId;
    if (userId == null) {
      throw Exception('Please log in to RSVP');
    }

    try {
      final row = await _supabase
          .from('event_rsvps')
          .upsert({
            'event_id': eventId,
            'user_id': userId,
            'status': status.dbValue,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'event_id,user_id')
          .select()
          .single();
      return EventRsvp.fromSupabaseRow(row);
    } catch (e) {
      throw Exception('Error saving RSVP: $e');
    }
  }

  Future<void> clearRsvp(String eventId) async {
    final userId = AppSession.userId;
    if (userId == null) return;
    try {
      await _supabase
          .from('event_rsvps')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error clearing RSVP: $e');
    }
  }

  Future<List<EventRsvp>> _attachUserInfo(
    List<Map<String, dynamic>> rows,
  ) async {
    final userIds = rows
        .map((r) => r['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final infoById = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      try {
        final users = await _supabase
            .from('users')
            .select('id, display_name, email, profile_image_base64')
            .inFilter('id', userIds);
        for (final u in users) {
          infoById[u['id'] as String] = u;
        }
      } catch (_) {}
    }
    return rows.map((row) {
      final info = infoById[row['user_id']?.toString()];
      return EventRsvp.fromSupabaseRow(
        row,
        userName: info?['display_name'] as String? ?? 'Alumni',
        userEmail: info?['email'] as String? ?? '',
        profileImageUrl: info?['profile_image_base64'] as String? ?? '',
      );
    }).toList();
  }

  /// Emits whenever RSVPs change for [eventId] (Realtime with polling fallback).
  Stream<void> watchEventChanges(String eventId) {
    final controller = StreamController<void>();
    StreamSubscription<dynamic>? sub;
    Timer? poller;

    Future<void> emit() async {
      if (!controller.isClosed) controller.add(null);
    }

    Future<void> startPolling() async {
      await emit();
      poller?.cancel();
      poller = Timer.periodic(const Duration(seconds: 8), (_) => emit());
    }

    controller.onListen = () async {
      await emit();
      try {
        sub = _supabase
            .from('event_rsvps')
            .stream(primaryKey: ['id'])
            .eq('event_id', eventId)
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
