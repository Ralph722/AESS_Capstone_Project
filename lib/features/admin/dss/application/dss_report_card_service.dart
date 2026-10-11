import 'package:alumni_system/features/admin/dss/application/dss_evaluation_service.dart';
import 'package:alumni_system/features/admin/dss/application/dss_policy.dart';
import 'package:alumni_system/features/admin/dss/application/dss_report_card.dart';
import 'package:alumni_system/features/admin/dss/data/dss_repository.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/data/alumni_member_service.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/surveys/data/survey_service.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Loads everything a program report card needs.
class DssReportCardService {
  DssReportCardService({
    DssRepository? repository,
    SurveyService? surveyService,
    AlumniMemberService? memberService,
  }) : _repo = repository ?? DssRepository(),
       _surveys = surveyService ?? SurveyService(),
       _members = memberService ?? AlumniMemberService();

  final DssRepository _repo;
  final SurveyService _surveys;
  final AlumniMemberService _members;

  /// Picker value for the institution report (never a roster course).
  static const wholeInstitution = '\u0000whole-institution';

  static const _maxActions = 30;
  static const _actionEvents = {
    DssNoteEventType.action,
    DssNoteEventType.announcement,
    DssNoteEventType.status,
    DssNoteEventType.impact,
    DssNoteEventType.reopen,
    DssNoteEventType.evidence,
    DssNoteEventType.outcome,
  };

  /// Programs on the active roster, alphabetical.
  Future<List<String>> courses() async {
    final members = await _members.getAllMembers();
    final set = <String>{
      for (final m in members)
        if (!m.isDeactivated && m.course.trim().isNotEmpty) m.course.trim(),
    };
    return set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// One program's report card, or the institution's for [wholeInstitution].
  Future<DssReportCardData> build(String course) async {
    final institution = course == wholeInstitution;
    final members = await _members.getAllMembers();
    final active = members.where((m) => !m.isDeactivated).toList();
    final byAuth = <String, AlumniMember>{
      for (final m in active)
        if (m.authUid != null && m.authUid!.trim().isNotEmpty)
          m.authUid!.trim(): m,
    };
    final programRoster = active.where((m) => m.course.trim() == course).length;
    final classifiedRoster = active
        .where((m) => DssPolicy.groupOf(m) != null)
        .length;

    final surveys = await _surveys.getAllSurveys();
    final chedWaves =
        surveys
            .where(
              (s) =>
                  !s.archived &&
                  s.isChedGtsBuiltin &&
                  (s.status == SurveyStatus.published ||
                      s.status == SurveyStatus.closed),
            )
            .toList()
          ..sort(
            (a, b) => DssEvaluationService.waveDate(
              a,
            ).compareTo(DssEvaluationService.waveDate(b)),
          );

    final waves = <DssReportCardWave>[];
    for (final survey in chedWaves) {
      final responses = await _surveys.getSurveyResponses(survey.id);
      if (responses.isEmpty) continue;
      final all = <Map<String, dynamic>>[];
      final program = <Map<String, dynamic>>[];
      for (final r in responses) {
        final group = DssPolicy.groupOf(byAuth[r.userId]);
        if (group == null) continue;
        all.add(r.answers);
        if (group.course == course) program.add(r.answers);
      }
      if (all.isEmpty) continue;
      final whole = DssProgramSnapshot.from(all, roster: classifiedRoster);
      waves.add(
        DssReportCardWave(
          title: survey.title,
          date: DssEvaluationService.waveDate(survey),
          program: institution
              ? whole
              : DssProgramSnapshot.from(program, roster: programRoster),
          institution: whole,
        ),
      );
    }

    final flags = institution
        ? await _repo.listFlags(limit: 1000)
        : await _repo.listFlags(course: course, limit: 500);
    final byId = {for (final f in flags) f.id: f};
    final notes = await _repo.listNotesForFlags(byId.keys.toList());
    final actions = [
      for (final n in notes)
        if (_actionEvents.contains(n.eventType) && byId[n.flagId] != null)
          DssReportCardAction(flag: byId[n.flagId]!, note: n),
    ].take(_maxActions).toList();
    final interventions = institution
        ? await _repo.listRecentInterventions(lookbackDays: null)
        : await _repo.listInterventionsForFlags(byId.keys.toList());

    return DssReportCardData(
      course: institution ? 'Whole institution (all programs)' : course,
      generatedAt: DateTime.now(),
      waves: waves,
      flags: flags,
      actions: actions,
      interventions: interventions,
      institution: institution,
    );
  }
}
