import 'package:alumni_system/features/admin/dss/application/dss_evaluation_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_metrics.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/jobs/data/job_recommendation.dart';
import 'package:alumni_system/features/jobs/data/job_service.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/surveys/ched_gts/ched_gts_schema.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';

/// One alumnus listed in a DSS action dialog.
class DssActionPerson {
  const DssActionPerson({
    required this.name,
    required this.course,
    required this.batchYear,
    this.authUid,
  });

  final String name;
  final String course;
  final String batchYear;

  /// Null when the alumnus has not registered (cannot be notified in-app).
  final String? authUid;

  bool get canNotify => authUid != null;
}

class DssJobSuggestion {
  const DssJobSuggestion({required this.job, required this.matchesProgram});

  final JobPosting job;

  /// Job targets this flag's program; otherwise it is open to all programs.
  final bool matchesProgram;
}

/// Builds recipient lists for the one-click actions. Sending happens on the
/// server (`DssRepository.runFlagAction`), which re-checks every recipient.
class DssActionService {
  DssActionService({
    AlumniMemberService? memberService,
    SurveyService? surveyService,
    JobService? jobService,
  }) : _members = memberService ?? AlumniMemberService(),
       _surveys = surveyService ?? SurveyService(),
       _jobs = jobService ?? JobService();

  final AlumniMemberService _members;
  final SurveyService _surveys;
  final JobService _jobs;

  /// Roster members in the flag's group who have not submitted the wave.
  Future<List<DssActionPerson>> nonRespondents(DssFlag flag) async {
    final members = await _groupMembers(flag);
    final responses = await _surveys.getSurveyResponses(flag.surveyId);
    final submitted = {for (final r in responses) r.userId};
    return [
      for (final m in members)
        if (!submitted.contains(_uid(m))) _person(m),
    ]..sort(_byName);
  }

  /// Respondents in the flag's group who answered Q16 No / Never Employed.
  Future<List<DssActionPerson>> unemployedRespondents(DssFlag flag) async {
    final members = await _groupMembers(flag);
    final byUid = {
      for (final m in members)
        if (_uid(m) != null) _uid(m)!: m,
    };
    final responses = await _surveys.getSurveyResponses(flag.surveyId);
    final out = <DssActionPerson>[];
    for (final r in responses) {
      final m = byUid[r.userId];
      if (m == null) continue;
      final q16 = DssMetrics.single(r.answers['ched_16']);
      if (q16 == ChedGtsBuiltin.no || q16 == ChedGtsBuiltin.neverEmployed) {
        out.add(_person(m));
      }
    }
    return out..sort(_byName);
  }

  /// Active postings for the flag's program first, then postings open to
  /// every program. Institution-wide flags get all active postings.
  Future<List<DssJobSuggestion>> suggestJobs(DssFlag flag) async {
    final active = (await _jobs.getActiveJobs())
        .where((j) => j.isActiveForAlumni)
        .toList();
    if (flag.cohortLevel == DssCohortLevel.institution) {
      return [
        for (final j in active) DssJobSuggestion(job: j, matchesProgram: true),
      ];
    }
    final matched = <DssJobSuggestion>[];
    final openToAll = <DssJobSuggestion>[];
    for (final j in active) {
      if (JobRecommendation.matches(j, flag.course)) {
        matched.add(DssJobSuggestion(job: j, matchesProgram: true));
      } else if (j.targetPrograms.isEmpty) {
        openToAll.add(DssJobSuggestion(job: j, matchesProgram: false));
      }
    }
    return [...matched, ...openToAll];
  }

  Future<List<AlumniMember>> _groupMembers(DssFlag flag) async {
    final members = await _members.getAllMembers(includeDeactivated: false);
    return members
        .where(
          (m) => !m.isDeactivated && DssEvaluationService.inFlagGroup(flag, m),
        )
        .toList();
  }

  static String? _uid(AlumniMember m) {
    final uid = m.authUid?.trim() ?? '';
    return uid.isEmpty ? null : uid;
  }

  static DssActionPerson _person(AlumniMember m) => DssActionPerson(
    name: m.fullName.trim().isEmpty ? m.studentId : m.fullName.trim(),
    course: m.course.trim(),
    batchYear: m.batchYear.trim(),
    authUid: _uid(m),
  );

  static int _byName(DssActionPerson a, DssActionPerson b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
