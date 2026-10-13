import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/announcements/models/announcement_model.dart';
import 'package:alumni_system/features/forum/models/forum_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';

/// Aggregated metrics for the admin Reports & Analytics dashboard.
class AdminReportsAnalytics {
  AdminReportsAnalytics({
    required this.members,
    required this.employmentRecords,
    required this.surveys,
    required this.announcements,
    required this.forumTopics,
    required this.portalUserCount,
    this.pendingSurveyAssignments = 0,
    this.assignmentCountsBySurveyId = const {},
    this.submittedResponsesBySurveyId = const {},
  }) : _activeRoster = members
           .where((m) => !m.isDeactivated)
           .toList(growable: false),
       _registeredOnRoster = members
           .where((m) => !m.isDeactivated && m.isRegisteredUser)
           .length;

  final List<AlumniMember> members;
  final List<EmploymentRecord> employmentRecords;
  final List<Survey> surveys;
  final List<Announcement> announcements;
  final List<ForumTopic> forumTopics;
  final int portalUserCount;

  /// Active assignments not yet completed (notStarted + inProgress).
  final int pendingSurveyAssignments;

  /// Active linked assignments per survey.
  final Map<String, int> assignmentCountsBySurveyId;

  /// Submitted response docs per survey (source of truth). When empty, falls back to [Survey.responseCount].
  final Map<String, int> submittedResponsesBySurveyId;
  final List<AlumniMember> _activeRoster;
  final int _registeredOnRoster;

  /// Prefer live count from `surveys/{id}/responses` when provided.
  int submittedResponseCount(Survey s) =>
      submittedResponsesBySurveyId[s.id] ?? s.responseCount;

  /// Prefer live assignment count for active linked alumni when provided.
  int assignmentCount(Survey s) => assignmentCountsBySurveyId[s.id] ?? s.assignmentCount;

  List<AlumniMember> get activeRoster => _activeRoster;

  int get rosterTotal => activeRoster.length;

  int get registeredOnRoster => _registeredOnRoster;

  int get unclaimedRoster => rosterTotal - registeredOnRoster;

  int get tracerCompleteCount =>
      activeRoster.where((m) => m.tracerProfileComplete).length;

  double get registrationRate =>
      rosterTotal == 0 ? 0 : registeredOnRoster / rosterTotal;

  double get tracerCompletionRate =>
      registeredOnRoster == 0 ? 0 : tracerCompleteCount / registeredOnRoster;

  /// Registered roster rows without a complete demographics tracer profile.
  int get registeredWithoutTracerComplete =>
      (registeredOnRoster - tracerCompleteCount).clamp(0, registeredOnRoster);

  /// Employed ÷ submissions with employment data (deduped registered alumni).
  ///
  /// Definition (shown under KPIs): employed among alumni who submitted
  /// employment data — not among the full roster.
  static const employmentRateDefinition =
      'Employment rate is the share of employed alumni among those who '
      'submitted employment information — not among the entire roster.';

  double get employmentRateAmongSubmissions =>
      reportEmploymentCount == 0 ? 0 : employedCount / reportEmploymentCount;

  /// One entry per alumni (latest submission wins); excludes orphan test docs.
  List<EmploymentRecord> get reportEmploymentRecords {
    final registeredAuth = <String>{
      for (final m in activeRoster)
        if (m.isRegisteredUser && m.authUid != null && m.authUid!.isNotEmpty)
          m.authUid!,
    };
    final registeredSchool = <String>{
      for (final m in activeRoster)
        if (m.isRegisteredUser && m.studentId.trim().isNotEmpty)
          AlumniMemberService.normalizeStudentId(m.studentId),
    };

    final latest = <String, EmploymentRecord>{};
    for (final r in employmentRecords) {
      final key = _employmentPersonKey(r);
      final existing = latest[key];
      if (existing == null || r.lastUpdated.isAfter(existing.lastUpdated)) {
        latest[key] = r;
      }
    }

    return latest.values.where((r) {
      final uid = r.userId.trim();
      if (uid.isNotEmpty && registeredAuth.contains(uid)) return true;
      final sid = AlumniMemberService.normalizeStudentId(r.schoolId);
      return sid.isNotEmpty && registeredSchool.contains(sid);
    }).toList();
  }

  int get reportEmploymentCount => reportEmploymentRecords.length;

  int get employedCount => reportEmploymentRecords
      .where((r) => r.employmentStatus.toLowerCase() == 'employed')
      .length;

  /// Everyone not employed: CHED item 16 "No" plus "Never Employed".
  int get unemployedCount => reportEmploymentCount - employedCount;

  /// CHED item 16 "No" only.
  int get notEmployedCount => reportEmploymentRecords
      .where((r) => r.employmentStatus.toLowerCase() == 'unemployed')
      .length;

  /// CHED item 16 "Never Employed" only.
  int get neverEmployedCount => reportEmploymentRecords
      .where((r) => r.employmentStatus.toLowerCase() == 'never employed')
      .length;

  static String _employmentPersonKey(EmploymentRecord r) {
    final uid = r.userId.trim();
    if (uid.isNotEmpty) return 'uid:$uid';
    final sid = AlumniMemberService.normalizeStudentId(r.schoolId);
    if (sid.isNotEmpty) return 'sid:$sid';
    return 'doc:${r.id}';
  }

  Map<String, int> get membersByCourse {
    final counts = <String, int>{};
    for (final m in activeRoster) {
      final course = m.course.isNotEmpty ? m.course : 'Unknown';
      counts[course] = (counts[course] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get membersByBatch {
    final counts = <String, int>{};
    for (final m in activeRoster) {
      final year = m.batchYear.trim().isEmpty ? 'Unknown' : m.batchYear.trim();
      counts[year] = (counts[year] ?? 0) + 1;
    }
    return counts;
  }

  int get publishedSurveys => surveys
      .where((s) => !s.archived && s.status == SurveyStatus.published)
      .length;

  int get draftSurveys =>
      surveys.where((s) => !s.archived && s.status == SurveyStatus.draft).length;

  int get closedSurveys => surveys
      .where((s) => !s.archived && s.status == SurveyStatus.closed)
      .length;

  int get archivedSurveys => surveys.where((s) => s.archived).length;

  int get totalSurveyAssignments => surveys
      .where((s) => !s.archived)
      .fold(0, (sum, s) => sum + assignmentCount(s));

  int get totalSurveyResponses => surveys
      .where((s) => !s.archived)
      .fold(0, (sum, s) => sum + submittedResponseCount(s));

  double get surveyResponseRate => totalSurveyAssignments == 0
      ? 0
      : totalSurveyResponses / totalSurveyAssignments;

  int get publishedAnnouncements => announcements
      .where((a) => a.status == AnnouncementStatus.published)
      .length;

  int get draftAnnouncements =>
      announcements.where((a) => a.status == AnnouncementStatus.draft).length;

  int get announcementRecipients => announcements
      .where((a) => a.status == AnnouncementStatus.published)
      .fold(0, (sum, a) => sum + a.recipientCount);

  int get forumTopicCount => forumTopics.length;

  int get forumReplies => forumTopics.fold(0, (sum, t) => sum + t.replyCount);

  int get pinnedTopics => forumTopics.where((t) => t.isPinned).length;

  int get lockedTopics => forumTopics.where((t) => t.isLocked).length;

  int get solvedTopics => forumTopics.where((t) => t.isSolved).length;

  int get unansweredTopics =>
      forumTopics.where((t) => t.needsResponse).length;

  int get announcementTopics =>
      forumTopics.where((t) => t.isAnnouncement).length;

  /// Surveys with assignments, sorted by response rate descending (uses live counts when provided).
  List<Survey> get surveysForChart {
    final list = surveys
        .where((s) => !s.archived && assignmentCount(s) > 0)
        .toList()
      ..sort((a, b) {
        final ar = submittedResponseCount(a) / assignmentCount(a);
        final br = submittedResponseCount(b) / assignmentCount(b);
        return br.compareTo(ar);
      });
    return list.take(6).toList();
  }

  /// Top N batch years by member count (numeric sort when possible).
  List<MapEntry<String, int>> topBatchYears({int limit = 8}) {
    final entries = membersByBatch.entries.toList();
    entries.sort((a, b) {
      final an = int.tryParse(a.key);
      final bn = int.tryParse(b.key);
      if (an != null && bn != null) return an.compareTo(bn);
      return a.key.compareTo(b.key);
    });
    if (entries.length <= limit) return entries;
    return entries.sublist(entries.length - limit);
  }

  List<MapEntry<String, int>> topCourses() {
    final entries = membersByCourse.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Employed alumni only; missing industry → "Not specified".
  List<MapEntry<String, int>> topIndustries({int limit = 12}) {
    final counts = <String, int>{};
    for (final r in reportEmploymentRecords) {
      if (r.employmentStatus.toLowerCase() != 'employed') continue;
      final key = (r.industry ?? '').trim().isEmpty ? 'Not specified' : r.industry!.trim();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }
}
