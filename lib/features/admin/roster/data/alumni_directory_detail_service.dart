import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/core/services/audit_service.dart';
import 'package:alumni_system/features/admin/activity/models/audit_log_model.dart';
import 'package:alumni_system/features/alumni/profile/data/user_profile_service.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Loaded admin view: roster row + linked user tracer + survey history.
class AlumniDirectoryDetail {
  const AlumniDirectoryDetail({
    required this.roster,
    this.tracer,
    this.profileImageUrl,
    this.activityCount = 0,
    this.activityLogs = const [],
    this.tracerResponses = const [],
  });

  final AlumniMember roster;
  final TracerProfile? tracer;
  final String? profileImageUrl;
  final int activityCount;
  final List<AuditLog> activityLogs;
  final List<SurveyResponseWithMeta> tracerResponses;
}

class AlumniDirectoryDetailService {
  AlumniDirectoryDetailService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  final UserProfileService _profiles = UserProfileService();
  final SurveyService _surveys = SurveyService();
  final AuditService _audit = AuditService();
  final AlumniMemberService _members = AlumniMemberService();

  Future<AlumniDirectoryDetail> loadDetail(AlumniMember member) async {
    var imageUrl = member.profileImageUrl;
    var roster = member;
    var tracerResponses = <SurveyResponseWithMeta>[];
    TracerProfile? tracer;
    var activityLogs = <AuditLog>[];

    final uid = member.authUid;
    if (uid != null && uid.isNotEmpty) {
      final results = await Future.wait<Object?>([
        _profiles.getTracerProfile(uid),
        _surveys.getUserSubmittedResponses(uid),
        _supabase
            .from('users')
            .select('profile_image_base64')
            .eq('id', uid)
            .maybeSingle(),
        _audit.getRelatedAuditLogs(
          userId: uid,
          resource: 'AlumniMember',
          resourceId: member.id,
        ),
      ]);

      tracer = results[0] as TracerProfile?;
      tracerResponses = results[1] as List<SurveyResponseWithMeta>;
      final userRow = results[2] as Map<String, dynamic>?;
      activityLogs = results[3] as List<AuditLog>;

      final url = userRow?['profile_image_base64'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        imageUrl = url;
      }

      // Keep roster card / dashboard chip in sync with the users profile.
      if (tracer != null &&
          tracer.isComplete &&
          !member.tracerProfileComplete) {
        try {
          await _supabase
              .from('alumni_members')
              .update({
                'tracer_profile_complete': true,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', member.id);
          roster = member.copyWith(tracerProfileComplete: true);
        } catch (_) {}
      }
    } else {
      activityLogs = await _audit.getRelatedAuditLogs(
        userId: null,
        resource: 'AlumniMember',
        resourceId: member.id,
      );
    }

    return AlumniDirectoryDetail(
      roster: roster,
      tracer: tracer,
      profileImageUrl: imageUrl,
      activityCount: activityLogs.length,
      activityLogs: activityLogs,
      tracerResponses: tracerResponses,
    );
  }

  /// Opening the detail records the view but keeps the profile-update flag;
  /// only [markProfileReviewed] clears it.
  Future<AlumniMember> recordAdminViewed(AlumniMember member) async {
    await _members.recordAdminViewed(member.id);
    return member.copyWith(adminViewedAt: DateTime.now());
  }

  Future<AlumniMember> markProfileReviewed(AlumniMember member) async {
    await _members.markProfileReviewed(member.id);
    return member.copyWith(
      hasProfileUpdates: false,
      adminViewedAt: DateTime.now(),
    );
  }
}
