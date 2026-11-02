import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/utils/supabase_paging.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';

/// Loads submitted CHED GTS responses with every answer for alumni lists.
/// Reads `survey_responses` under the existing admin RLS policy.
class GtsListDataService {
  GtsListDataService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<GtsListResponse>> loadResponses(List<String> surveyIds) async {
    if (surveyIds.isEmpty) return const [];
    final rows = await fetchAllPages(
      (from, to) => _supabase
          .from('survey_responses')
          .select('id, survey_id, user_id, submitted_at, answers')
          .inFilter('survey_id', surveyIds)
          .eq('status', 'submitted')
          .order('id')
          .range(from, to),
    );
    return responsesFromRows(rows);
  }

  /// Section A fields on `users`. Employment columns are not loaded: sections
  /// B–D are taken only from a submitted tracer.
  static const profileColumns =
      'id, email, display_name, student_id, program, year_graduated, '
      'telephone_number, mobile_number, address, gender, civil_status, '
      'birth_date, region_of_origin, province, location_of_residence, '
      'college_university, honors_awards, contact_email, '
      'contact_email_verified_at';

  /// Profiles keyed by user id. Ids with no `users` row are omitted.
  Future<Map<String, TracerProfile>> loadProfiles(List<String> userIds) async {
    final ids = userIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    final out = <String, TracerProfile>{};
    const chunk = 100;
    for (var i = 0; i < ids.length; i += chunk) {
      final end = i + chunk > ids.length ? ids.length : i + chunk;
      final rows = await _supabase
          .from('users')
          .select(profileColumns)
          .inFilter('id', ids.sublist(i, end));
      out.addAll(
        profilesFromRows([
          for (final row in rows) Map<String, dynamic>.from(row),
        ]),
      );
    }
    return out;
  }

  static Map<String, TracerProfile> profilesFromRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final out = <String, TracerProfile>{};
    for (final row in rows) {
      final profile = TracerProfile.fromSupabaseRow(row);
      if (profile.uid.isNotEmpty) out[profile.uid] = profile;
    }
    return out;
  }

  static List<GtsListResponse> responsesFromRows(
    Iterable<Map<String, dynamic>> rows,
  ) => [
    for (final row in rows)
      if ((row['user_id']?.toString() ?? '').isNotEmpty &&
          (row['survey_id']?.toString() ?? '').isNotEmpty)
        GtsListResponse(
          userId: row['user_id'].toString(),
          surveyId: row['survey_id'].toString(),
          responseId: row['id']?.toString() ?? '',
          submittedAt: DateTime.tryParse(row['submitted_at']?.toString() ?? ''),
          answers: row['answers'] is Map
              ? Map<String, dynamic>.from(row['answers'] as Map)
              : const {},
        ),
  ];
}
