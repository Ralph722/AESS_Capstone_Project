import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Coverage funnel: roster → registered → took tracer.
class TracerCoverageSnapshot {
  const TracerCoverageSnapshot({
    required this.rosterTotal,
    required this.notRegistered,
    required this.registered,
    required this.tookTracer,
    required this.registeredNoTracer,
    required this.waveLabel,
    required this.definition,
    this.scopedToWave = false,
  });

  final int rosterTotal;
  final int notRegistered;
  final int registered;

  /// Registered alumni who submitted the tracer wave(s) in scope.
  final int tookTracer;

  /// Registered alumni with no submitted tracer in scope.
  final int registeredNoTracer;

  final String waveLabel;
  final String definition;

  /// True when the alumni-list side was limited to people already on the list
  /// when the selected wave opened or was published.
  final bool scopedToWave;

  double get registrationRate =>
      rosterTotal == 0 ? 0 : registered / rosterTotal;

  /// Among registered alumni in scope.
  double get tracerTakeRateAmongRegistered =>
      registered == 0 ? 0 : tookTracer / registered;

  /// Among full roster in scope (stricter “system reach”).
  double get tracerTakeRateAmongRoster =>
      rosterTotal == 0 ? 0 : tookTracer / rosterTotal;

  static const empty = TracerCoverageSnapshot(
    rosterTotal: 0,
    notRegistered: 0,
    registered: 0,
    tookTracer: 0,
    registeredNoTracer: 0,
    waveLabel: 'All published tracers',
    definition:
        'Took tracer = submitted the selected CHED/tracer wave(s). '
        'Registered = portal account linked to the alumni list.',
  );
}

/// Builds coverage from cohort-filtered roster + submitter auth UIDs.
///
/// When [filters.surveyId] picks one wave, the alumni-list / registered steps
/// only count members already on the list when that wave opened (or was
/// published / created if no open date). “All published tracers” keeps the
/// current alumni list.
TracerCoverageSnapshot buildTracerCoverage({
  required List<AlumniMember> members,
  required Set<String> tracerSubmitterUserIds,
  required ReportsDashboardFilters filters,
  required List<Survey> surveys,
}) {
  final submitters = {
    for (final id in tracerSubmitterUserIds)
      if (id.trim().isNotEmpty) id.trim(),
  };

  final wave = _selectedWave(filters.surveyId, surveys);
  final cutoff = wave == null ? null : _waveRosterCutoff(wave);
  final scopedToWave = cutoff != null;

  final active = <AlumniMember>[
    for (final m in members)
      if (!m.isDeactivated &&
          (cutoff == null || !m.createdAt.isAfter(cutoff)))
        m,
  ];

  var notRegistered = 0;
  var registered = 0;
  var took = 0;

  for (final m in active) {
    if (!m.isRegisteredUser) {
      notRegistered++;
      continue;
    }
    registered++;
    final uid = (m.authUid ?? '').trim();
    if (uid.isNotEmpty && submitters.contains(uid)) {
      took++;
    }
  }

  final waveLabel = _waveLabel(filters.surveyId, surveys);
  final definition = cutoff == null
      ? 'Took tracer = submitted $waveLabel. '
          'Registered = portal account linked to the current alumni list. '
          'Not registered = on the current alumni list only.'
      : 'Took tracer = submitted $waveLabel. '
          'Alumni list and Registered count only people already on the '
          'list when that wave opened or was published '
          '(${_formatCutoff(cutoff)}). '
          'Not registered = on that list only.';

  return TracerCoverageSnapshot(
    rosterTotal: active.length,
    notRegistered: notRegistered,
    registered: registered,
    tookTracer: took,
    registeredNoTracer: (registered - took).clamp(0, registered),
    waveLabel: waveLabel,
    scopedToWave: scopedToWave,
    definition: definition,
  );
}

Survey? _selectedWave(String? surveyId, List<Survey> surveys) {
  if (surveyId == null) return null;
  for (final s in surveys) {
    if (s.id == surveyId) return s;
  }
  return null;
}

/// Prefer open date (when alumni could answer), then first publish, then create.
DateTime _waveRosterCutoff(Survey survey) =>
    survey.openAt ?? survey.publishedAt ?? survey.createdAt;

String _formatCutoff(DateTime cutoff) {
  final local = cutoff.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _waveLabel(String? surveyId, List<Survey> surveys) {
  if (surveyId == null) return 'any published/closed CHED tracer wave';
  for (final s in surveys) {
    if (s.id == surveyId) return '“${s.title}”';
  }
  return 'the selected tracer wave';
}
