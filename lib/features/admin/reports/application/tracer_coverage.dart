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
        'Registered = portal account linked to the roster.',
  );
}

/// Builds coverage from cohort-filtered roster + submitter auth UIDs.
TracerCoverageSnapshot buildTracerCoverage({
  required List<AlumniMember> members,
  required Set<String> tracerSubmitterUserIds,
  required ReportsDashboardFilters filters,
  required List<Survey> surveys,
}) {
  final active = members.where((m) => !m.isDeactivated).toList(growable: false);
  final submitters = {
    for (final id in tracerSubmitterUserIds)
      if (id.trim().isNotEmpty) id.trim(),
  };

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

  return TracerCoverageSnapshot(
    rosterTotal: active.length,
    notRegistered: notRegistered,
    registered: registered,
    tookTracer: took,
    registeredNoTracer: (registered - took).clamp(0, registered),
    waveLabel: waveLabel,
    definition:
        'Took tracer = submitted $waveLabel. '
        'Registered = portal account linked to the roster. '
        'Not registered = on roster only.',
  );
}

String _waveLabel(String? surveyId, List<Survey> surveys) {
  if (surveyId == null) return 'any published/closed CHED tracer wave';
  for (final s in surveys) {
    if (s.id == surveyId) return '“${s.title}”';
  }
  return 'the selected tracer wave';
}
