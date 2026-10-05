import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';

/// Employment rows derived from each alumnus' latest submitted CHED GTS
/// response (`gts_employment_records` view). Read-only: alumni update their
/// employment by answering the tracer survey.
class IdTracerService {
  IdTracerService({
    SupabaseClient? supabase,
    AuthService? authService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _authService = authService ?? AuthService();

  static const _view = 'gts_employment_records';

  final SupabaseClient _supabase;
  final AuthService _authService;

  Future<void> _assertAdminCaller() async {
    final uid = AppSession.userId;
    if (uid == null) throw Exception('Not authenticated');
    final role = await _authService.getUserRole(uid);
    if (role != UserRole.admin) {
      throw Exception('Admin access required');
    }
  }

  /// Get employment record by user ID
  Future<EmploymentRecord?> getEmploymentRecordByUserId(String userId) async {
    try {
      final row = await _supabase
          .from(_view)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return null;
      return EmploymentRecord.fromSupabaseRow(row);
    } catch (e) {
      throw Exception('Error fetching employment record: $e');
    }
  }

  /// Get current user's employment record
  Future<EmploymentRecord?> getCurrentUserRecord() async {
    final userId = AppSession.userId;
    if (userId == null) return null;
    return getEmploymentRecordByUserId(userId);
  }

  /// Get all employment records (for admin)
  Future<List<EmploymentRecord>> getAllEmploymentRecords({
    int limit = 100,
  }) async {
    await _assertAdminCaller();
    try {
      final rows = await _supabase
          .from(_view)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map(EmploymentRecord.fromSupabaseRow).toList();
    } catch (e) {
      throw Exception('Error fetching all employment records: $e');
    }
  }

  Future<int> getActiveRegisteredRecordsCount() async {
    try {
      final activeAuthUids = await AlumniMemberService()
          .getActiveRegisteredAuthUids();
      if (activeAuthUids.isEmpty) return 0;

      return await _supabase
          .from(_view)
          .count(CountOption.exact)
          .inFilter('user_id', activeAuthUids.toList());
    } catch (e) {
      throw Exception('Error getting active registered employment count: $e');
    }
  }
}
