import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/utils/supabase_paging.dart';
import 'package:alumni_system/features/admin/reports/models/gts_respondent.dart';

/// Loads report respondents from `gts_report_facts` (submitted CHED GTS
/// responses with roster cohort; personal items removed in the database).
class GtsReportDataService {
  GtsReportDataService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<GtsRespondent>> loadRespondents(List<String> surveyIds) async {
    if (surveyIds.isEmpty) return const [];
    final rows = await fetchAllPages(
      (from, to) => _supabase
          .from('gts_report_facts')
          .select(
            'response_id, survey_id, user_id, submitted_at, '
            'on_active_roster, course, year_graduated, answers',
          )
          .inFilter('survey_id', surveyIds)
          .order('response_id')
          .range(from, to),
    );
    return respondentsFromRows(rows);
  }

  /// One respondent per graduate per wave: the latest submission wins.
  static List<GtsRespondent> respondentsFromRows(
    Iterable<Map<String, dynamic>> rows,
  ) {
    final latest = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final userId = row['user_id']?.toString() ?? '';
      final surveyId = row['survey_id']?.toString() ?? '';
      if (userId.isEmpty || surveyId.isEmpty) continue;
      final key = '$surveyId/$userId';
      final previous = latest[key];
      if (previous == null || _isLater(row, previous)) latest[key] = row;
    }
    return [
      for (final row in latest.values)
        GtsRespondent(
          userId: row['user_id'].toString(),
          surveyId: row['survey_id'].toString(),
          answers: row['answers'] is Map
              ? Map<String, dynamic>.from(row['answers'] as Map)
              : const {},
          course: row['course']?.toString() ?? '',
          yearGraduated: row['year_graduated']?.toString() ?? '',
          onActiveRoster: row['on_active_roster'] == true,
        ),
    ];
  }

  static bool _isLater(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ta = DateTime.tryParse(a['submitted_at']?.toString() ?? '');
    final tb = DateTime.tryParse(b['submitted_at']?.toString() ?? '');
    if (ta != null && tb != null && ta != tb) return ta.isAfter(tb);
    if (ta != null && tb == null) return true;
    if (ta == null && tb != null) return false;
    return (a['response_id']?.toString() ?? '').compareTo(
          b['response_id']?.toString() ?? '',
        ) >
        0;
  }
}
