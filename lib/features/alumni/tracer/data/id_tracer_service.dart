import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/app_session.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';

class IdTracerService {
  IdTracerService({
    SupabaseClient? supabase,
    AuthService? authService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _authService = authService ?? AuthService();

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

  /// Submit employment record
  Future<void> submitEmploymentRecord(EmploymentRecord record) async {
    try {
      final existingRecord = await getEmploymentRecordByUserId(record.userId);
      final payload = record
          .copyWith(lastUpdated: DateTime.now())
          .toSupabaseRow();

      if (existingRecord != null) {
        await _supabase
            .from('employment_records')
            .update(payload)
            .eq('id', existingRecord.id);
      } else {
        await _supabase.from('employment_records').insert(payload);
      }
      await AlumniMemberService().flagProfileUpdatedForAuthUid(record.userId);
      await _mirrorEmploymentOnRoster(record);
    } catch (e) {
      throw Exception('Error submitting employment record: $e');
    }
  }

  Future<void> _mirrorEmploymentOnRoster(EmploymentRecord record) async {
    await AlumniMemberService().mirrorEmploymentStatusForAuthUid(
      record.userId,
      employmentStatus: record.employmentStatus,
      companyName: record.companyName,
      position: record.position,
    );
  }

  /// Get employment record by user ID
  Future<EmploymentRecord?> getEmploymentRecordByUserId(String userId) async {
    try {
      final row = await _supabase
          .from('employment_records')
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

  /// Indexes employment records for admin directory filters.
  Future<EmploymentStatusIndex> getEmploymentStatusIndex() async {
    try {
      final rows = await _supabase.from('employment_records').select();
      final byAuthUid = <String, String>{};
      final bySchoolId = <String, String>{};
      for (final row in rows) {
        final record = EmploymentRecord.fromSupabaseRow(row);
        final status = record.employmentStatus.trim();
        if (status.isEmpty) continue;

        if (record.userId.isNotEmpty) {
          byAuthUid[record.userId] = status;
        }

        if (record.schoolId.isNotEmpty) {
          bySchoolId[AlumniMemberService.normalizeStudentId(record.schoolId)] =
              status;
        }
      }
      return EmploymentStatusIndex(
        byAuthUid: byAuthUid,
        bySchoolId: bySchoolId,
      );
    } catch (e) {
      throw Exception('Error loading employment statuses: $e');
    }
  }

  /// Get all employment records (for admin)
  Future<List<EmploymentRecord>> getAllEmploymentRecords({
    int limit = 100,
  }) async {
    await _assertAdminCaller();
    try {
      final rows = await _supabase
          .from('employment_records')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map(EmploymentRecord.fromSupabaseRow).toList();
    } catch (e) {
      throw Exception('Error fetching all employment records: $e');
    }
  }

  /// Get employment records by status
  Future<List<EmploymentRecord>> getRecordsByStatus(String status) async {
    await _assertAdminCaller();
    try {
      final rows = await _supabase
          .from('employment_records')
          .select()
          .eq('status', status)
          .order('created_at', ascending: false);

      return rows.map(EmploymentRecord.fromSupabaseRow).toList();
    } catch (e) {
      throw Exception('Error fetching records by status: $e');
    }
  }

  /// Search employment records (for admin)
  Future<List<EmploymentRecord>> searchRecords(String query) async {
    await _assertAdminCaller();
    try {
      final allRecords = await getAllEmploymentRecords(limit: 500);

      final lowerQuery = query.toLowerCase();
      return allRecords.where((record) {
        return record.userName.toLowerCase().contains(lowerQuery) ||
            record.userEmail.toLowerCase().contains(lowerQuery) ||
            record.schoolId.toLowerCase().contains(lowerQuery) ||
            (record.companyName?.toLowerCase().contains(lowerQuery) ?? false) ||
            (record.position?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      throw Exception('Error searching records: $e');
    }
  }

  /// Filter records by multiple criteria
  Future<List<EmploymentRecord>> filterRecords({
    String? employmentStatus,
    String? industry,
    String? employmentType,
    String? province,
    String? verificationStatus,
  }) async {
    await _assertAdminCaller();
    try {
      var query = _supabase.from('employment_records').select();

      if (employmentStatus != null && employmentStatus.isNotEmpty) {
        query = query.eq('status', employmentStatus);
      }

      if (verificationStatus != null && verificationStatus.isNotEmpty) {
        query = query.eq('verification_status', verificationStatus);
      }

      final rows = await query.order('created_at', ascending: false);
      var records = rows.map(EmploymentRecord.fromSupabaseRow).toList();

      // Filter in memory for fields stored inside `data` jsonb.
      if (industry != null && industry.isNotEmpty) {
        records = records.where((r) => r.industry == industry).toList();
      }

      if (employmentType != null && employmentType.isNotEmpty) {
        records = records
            .where((r) => r.employmentType == employmentType)
            .toList();
      }

      if (province != null && province.isNotEmpty) {
        records = records.where((r) => r.province == province).toList();
      }

      return records;
    } catch (e) {
      throw Exception('Error filtering records: $e');
    }
  }

  /// Verify employment record (admin only)
  Future<void> verifyRecord(
    String recordId,
    String adminId, {
    String? notes,
  }) async {
    await _assertAdminCaller();
    try {
      await _updateVerification(
        recordId,
        adminId: adminId,
        status: 'Verified',
        notes: notes,
      );
    } catch (e) {
      throw Exception('Error verifying record: $e');
    }
  }

  /// Reject employment record (admin only)
  Future<void> rejectRecord(
    String recordId,
    String adminId, {
    String? notes,
  }) async {
    await _assertAdminCaller();
    try {
      await _updateVerification(
        recordId,
        adminId: adminId,
        status: 'Rejected',
        notes: notes,
      );
    } catch (e) {
      throw Exception('Error rejecting record: $e');
    }
  }

  Future<void> _updateVerification(
    String recordId, {
    required String adminId,
    required String status,
    String? notes,
  }) async {
    final existing = await _supabase
        .from('employment_records')
        .select()
        .eq('id', recordId)
        .maybeSingle();
    final data = Map<String, dynamic>.from(
      existing?['data'] as Map<String, dynamic>? ?? {},
    );
    if (notes != null) data['notes'] = notes;

    await _supabase
        .from('employment_records')
        .update({
          'verification_status': status,
          'verified_by': adminId,
          'verified_at': DateTime.now().toUtc().toIso8601String(),
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', recordId);
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final allRecords = await getAllEmploymentRecords(limit: 1000);

      final total = allRecords.length;
      final employed = allRecords
          .where((r) => r.employmentStatus == 'Employed')
          .length;
      final unemployed = allRecords
          .where((r) => r.employmentStatus == 'Unemployed')
          .length;
      final verified = allRecords
          .where((r) => r.verificationStatus == 'Verified')
          .length;
      final pending = allRecords
          .where((r) => r.verificationStatus == 'Pending')
          .length;

      return {
        'total': total,
        'employed': employed,
        'unemployed': unemployed,
        'employmentRate': total > 0
            ? (employed / total * 100).toStringAsFixed(1)
            : '0.0',
        'verified': verified,
        'pending': pending,
      };
    } catch (e) {
      throw Exception('Error getting statistics: $e');
    }
  }

  /// Get total count
  Future<int> getTotalRecordsCount() async {
    try {
      final rows = await _supabase.from('employment_records').select('id');
      return rows.length;
    } catch (e) {
      throw Exception('Error getting total count: $e');
    }
  }

  Future<int> getActiveRegisteredRecordsCount() async {
    try {
      final activeAuthUids = await AlumniMemberService()
          .getActiveRegisteredAuthUids();
      if (activeAuthUids.isEmpty) return 0;

      final rows = await _supabase
          .from('employment_records')
          .select('id')
          .inFilter('user_id', activeAuthUids.toList());
      return rows.length;
    } catch (e) {
      throw Exception('Error getting active registered employment count: $e');
    }
  }
}
