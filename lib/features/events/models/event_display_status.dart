import 'package:flutter/material.dart';
import 'package:alumni_system/features/events/models/event_model.dart';

/// Derived presentation status for event badges.
enum EventDisplayStatus {
  upcoming,
  today,
  ongoing,
  finished,
  cancelled,
  archived,
}

extension EventDisplayStatusX on EventDisplayStatus {
  String get label => switch (this) {
    EventDisplayStatus.upcoming => 'Upcoming',
    EventDisplayStatus.today => 'Today',
    EventDisplayStatus.ongoing => 'Ongoing',
    EventDisplayStatus.finished => 'Finished',
    EventDisplayStatus.cancelled => 'Cancelled',
    EventDisplayStatus.archived => 'Archived',
  };

  Color get color => switch (this) {
    EventDisplayStatus.upcoming => const Color(0xFF2563EB),
    EventDisplayStatus.today => const Color(0xFFD97706),
    EventDisplayStatus.ongoing => const Color(0xFF059669),
    EventDisplayStatus.finished => const Color(0xFF64748B),
    EventDisplayStatus.cancelled => const Color(0xFFDC2626),
    EventDisplayStatus.archived => const Color(0xFF94A3B8),
  };

  Color get background => color.withValues(alpha: 0.12);
}

EventDisplayStatus deriveEventDisplayStatus(
  AlumniEvent event, {
  DateTime? now,
}) {
  if (event.cancelled) return EventDisplayStatus.cancelled;
  if (event.status == 'Archived') return EventDisplayStatus.archived;

  final clock = now ?? DateTime.now();
  final day = DateTime(clock.year, clock.month, clock.day);
  final eventDay = DateTime(event.date.year, event.date.month, event.date.day);

  if (eventDay.isBefore(day)) return EventDisplayStatus.finished;
  if (eventDay.isAfter(day)) return EventDisplayStatus.upcoming;

  // Same calendar day — check time window when possible.
  final start = _parseHm(event.startTime, eventDay);
  final end = _parseHm(event.endTime, eventDay);
  if (start != null && end != null) {
    if (clock.isBefore(start)) return EventDisplayStatus.today;
    if (clock.isAfter(end)) return EventDisplayStatus.finished;
    return EventDisplayStatus.ongoing;
  }
  return EventDisplayStatus.today;
}

DateTime? _parseHm(String raw, DateTime day) {
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}
