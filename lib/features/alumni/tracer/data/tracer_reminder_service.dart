import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A reminder to finish a saved CHED GTS draft (sent by the server).
class TracerReminder {
  const TracerReminder({
    required this.surveyId,
    required this.remindAt,
    required this.repeatHourly,
    this.lastSentAt,
    this.cancelledAt,
  });

  final String surveyId;
  final DateTime remindAt;
  final bool repeatHourly;
  final DateTime? lastSentAt;
  final DateTime? cancelledAt;

  /// Set, not cancelled, and the first reminder has not gone out yet.
  bool get isUpcoming =>
      cancelledAt == null &&
      lastSentAt == null &&
      remindAt.isAfter(DateTime.now());

  factory TracerReminder.fromRow(Map<String, dynamic> row) {
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    return TracerReminder(
      surveyId: row['survey_id'].toString(),
      remindAt: parse(row['remind_at']) ?? DateTime.now(),
      repeatHourly: row['repeat_hourly'] == true,
      lastSentAt: parse(row['last_sent_at']),
      cancelledAt: parse(row['cancelled_at']),
    );
  }
}

class TracerReminderService {
  TracerReminderService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const _table = 'tracer_draft_reminders';

  String? get _uid => _supabase.auth.currentUser?.id;

  Future<TracerReminder?> getReminder(String surveyId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _supabase
          .from(_table)
          .select()
          .eq('user_id', uid)
          .eq('survey_id', surveyId)
          .maybeSingle();
      return row == null ? null : TracerReminder.fromRow(row);
    } catch (e) {
      debugPrint('TracerReminderService.getReminder failed: $e');
      return null;
    }
  }

  /// Replaces any existing reminder for this tracer. The fresh row id gives
  /// the new reminder its own notification dedupe keys.
  Future<TracerReminder> setReminder({
    required String surveyId,
    required DateTime remindAt,
    required bool repeatHourly,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in again.');
    await _supabase
        .from(_table)
        .delete()
        .eq('user_id', uid)
        .eq('survey_id', surveyId);
    final row = await _supabase
        .from(_table)
        .insert({
          'user_id': uid,
          'survey_id': surveyId,
          'remind_at': remindAt.toUtc().toIso8601String(),
          'repeat_hourly': repeatHourly,
        })
        .select()
        .single();
    return TracerReminder.fromRow(row);
  }

  Future<void> cancelReminder(String surveyId) async {
    final uid = _uid;
    if (uid == null) return;
    await _supabase
        .from(_table)
        .delete()
        .eq('user_id', uid)
        .eq('survey_id', surveyId);
  }
}
