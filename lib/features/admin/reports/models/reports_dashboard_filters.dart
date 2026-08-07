import 'package:alumni_system/core/constants/audience_targeting.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Cohort filters for Tracer and Survey tabs only (not Overview / Downloads).
class ReportsDashboardFilters {
  const ReportsDashboardFilters({
    this.surveyId,
    this.batchYear,
    this.course,
  });

  /// Focus on one published survey wave (`null` = all in scope).
  final String? surveyId;
  final String? batchYear;
  final String? course;

  bool get isEmpty =>
      surveyId == null && batchYear == null && course == null;

  int get activeCount {
    var n = 0;
    if (surveyId != null) n++;
    if (batchYear != null) n++;
    if (course != null) n++;
    return n;
  }

  ReportsDashboardFilters copyWith({
    String? surveyId,
    String? batchYear,
    String? course,
    bool clearSurvey = false,
    bool clearBatch = false,
    bool clearCourse = false,
  }) {
    return ReportsDashboardFilters(
      surveyId: clearSurvey ? null : (surveyId ?? this.surveyId),
      batchYear: clearBatch ? null : (batchYear ?? this.batchYear),
      course: clearCourse ? null : (course ?? this.course),
    );
  }

  static const empty = ReportsDashboardFilters();

  /// Human-readable scope line for KPI/chart captions.
  String scopeLabel({
    required List<Survey> surveys,
    required int? responseOrRecordCount,
    String countNoun = 'records',
  }) {
    final parts = <String>[];
    if (surveyId == null) {
      parts.add('All published waves');
    } else {
      final match = surveys.where((s) => s.id == surveyId);
      parts.add(match.isEmpty ? 'Selected wave' : match.first.title);
    }
    parts.add(batchYear ?? 'All batches');
    parts.add(course ?? 'All courses');
    if (responseOrRecordCount != null) {
      parts.add('$responseOrRecordCount $countNoun');
    }
    return parts.join(' · ');
  }
}

/// Applies cohort filters to an analytics snapshot (roster + employment + survey list).
AdminReportsAnalytics applyReportsDashboardFilters({
  required AdminReportsAnalytics source,
  required ReportsDashboardFilters filters,
}) {
  if (filters.isEmpty) return source;

  final members = source.members
      .where((m) => _matchMember(m, filters))
      .toList(growable: false);

  final registeredAuth = <String>{
    for (final m in members)
      if (m.isRegisteredUser && m.authUid != null && m.authUid!.isNotEmpty)
        m.authUid!,
  };
  final registeredSchool = <String>{
    for (final m in members)
      if (m.isRegisteredUser && m.studentId.trim().isNotEmpty)
        AlumniMemberService.normalizeStudentId(m.studentId),
  };

  final employment = source.employmentRecords.where((r) {
    if (filters.batchYear == null && filters.course == null) return true;
    final uid = r.userId.trim();
    if (uid.isNotEmpty && registeredAuth.contains(uid)) return true;
    final sid = AlumniMemberService.normalizeStudentId(r.schoolId);
    return sid.isNotEmpty && registeredSchool.contains(sid);
  }).toList(growable: false);

  final surveys = filters.surveyId == null
      ? source.surveys
      : source.surveys
            .where((s) => s.id == filters.surveyId)
            .toList(growable: false);

  final portalUsers =
      members.where((m) => !m.isDeactivated && m.isRegisteredUser).length;

  return AdminReportsAnalytics(
    members: members,
    employmentRecords: employment,
    surveys: surveys,
    announcements: source.announcements,
    forumTopics: source.forumTopics,
    portalUserCount: portalUsers,
    pendingSurveyAssignments: filters.surveyId == null
        ? source.pendingSurveyAssignments
        : _pendingForSurvey(source, filters.surveyId!),
    assignmentCountsBySurveyId: source.assignmentCountsBySurveyId,
    submittedResponsesBySurveyId: source.submittedResponsesBySurveyId,
  );
}

int _pendingForSurvey(AdminReportsAnalytics source, String surveyId) {
  final assigned =
      source.assignmentCountsBySurveyId[surveyId] ??
      source.surveys
          .where((s) => s.id == surveyId)
          .fold<int>(0, (sum, s) => sum + s.assignmentCount);
  final submitted =
      source.submittedResponsesBySurveyId[surveyId] ??
      source.surveys
          .where((s) => s.id == surveyId)
          .fold<int>(0, (sum, s) => sum + s.responseCount);
  return (assigned - submitted).clamp(0, assigned);
}

bool _matchMember(AlumniMember m, ReportsDashboardFilters filters) {
  if (filters.batchYear != null) {
    final batch = m.batchYear.trim().isEmpty
        ? (m.yearGraduated ?? '').trim()
        : m.batchYear.trim();
    if (batch.toLowerCase() != filters.batchYear!.trim().toLowerCase()) {
      return false;
    }
  }
  if (filters.course != null) {
    if (m.course.trim().toLowerCase() != filters.course!.trim().toLowerCase()) {
      return false;
    }
  }
  return true;
}

/// Distinct batch years from roster for filter dropdown options.
List<String> reportsFilterBatchOptions(List<AlumniMember> members) {
  final set = <String>{};
  for (final m in members) {
    if (m.isDeactivated) continue;
    final batch = m.batchYear.trim().isNotEmpty
        ? m.batchYear.trim()
        : (m.yearGraduated ?? '').trim();
    if (batch.isNotEmpty) set.add(batch);
  }
  final list = set.toList()
    ..sort((a, b) {
      final an = int.tryParse(a);
      final bn = int.tryParse(b);
      if (an != null && bn != null) return bn.compareTo(an);
      return b.compareTo(a);
    });
  return list;
}

/// Survey wave options for Tracer (published CHED / tracer) or Survey portfolio.
List<Survey> reportsFilterSurveyOptions(
  List<Survey> surveys, {
  required bool tracerOnly,
}) {
  final list = surveys.where((s) {
    if (s.archived) return false;
    if (s.status != SurveyStatus.published && s.status != SurveyStatus.closed) {
      return false;
    }
    if (tracerOnly) return s.isChedGtsBuiltin;
    return true;
  }).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return list;
}

/// Audience caption when a wave has publish-time targeting.
String? reportsAudienceHint(Survey? survey) {
  if (survey == null) return null;
  final programs = survey.targetPrograms
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final batches = AudienceTargeting.expandBatchYearTargets(
    survey.targetBatchYears,
  );
  if (programs.isEmpty && batches.isEmpty) {
    return 'This wave has no audience target (all eligible alumni).';
  }
  final parts = <String>[];
  if (programs.isNotEmpty) parts.add(programs.join(', '));
  if (batches.isNotEmpty) {
    parts.add(batches.length <= 6
        ? batches.join(', ')
        : '${batches.first}–${batches.last} (${batches.length} years)');
  }
  return 'Published for ${parts.join(' · ')}. Filters below can narrow further.';
}

/// Prefill cohort filters from a wave's audience when the selection changes.
ReportsDashboardFilters filtersPrefillFromSurvey(
  ReportsDashboardFilters current,
  Survey? survey,
) {
  if (survey == null) {
    return current.copyWith(clearSurvey: true);
  }
  final programs = survey.targetPrograms
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final batches = AudienceTargeting.expandBatchYearTargets(
    survey.targetBatchYears,
  );

  return ReportsDashboardFilters(
    surveyId: survey.id,
    batchYear: batches.length == 1 ? batches.first : null,
    course: programs.length == 1 ? programs.first : null,
  );
}
