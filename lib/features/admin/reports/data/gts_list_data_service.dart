import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/utils/supabase_paging.dart';
import 'package:alumni_system/features/admin/reports/application/gts_alumni_list.dart';

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
