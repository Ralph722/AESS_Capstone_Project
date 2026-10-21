import 'package:intl/intl.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/reports/application/admin_reports_analytics.dart';
import 'package:alumni_system/features/admin/reports/application/tracer_coverage.dart';
import 'package:alumni_system/features/admin/reports/models/reports_dashboard_filters.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';

/// Alumni, registration and tracer response for one program on the roster.
class DashboardProgramStat {
  const DashboardProgramStat({
    required this.program,
    required this.alumni,
    required this.registered,
    required this.tracerResponded,
  });

  final String program;
  final int alumni;
  final int registered;

  /// Registered alumni in this program who submitted a CHED tracer wave.
  final int tracerResponded;

  double get registrationRate => alumni == 0 ? 0 : registered / alumni;

  /// Null when nobody in the program is registered yet.
  double? get tracerRate =>
      registered == 0 ? null : tracerResponded / registered;
}

/// Surveys other than the CHED tracer (non-archived).
class DashboardSurveySummary {
  const DashboardSurveySummary({
    this.published = 0,
    this.drafts = 0,
    this.assigned = 0,
    this.submitted = 0,
    this.lowestTitle,
    this.lowestRate,
  });

  final int published;
  final int drafts;
  final int assigned;
  final int submitted;

  /// Published survey with the lowest response rate (needs assignments).
  final String? lowestTitle;
  final double? lowestRate;

  double? get responseRate => assigned == 0 ? null : submitted / assigned;
}

enum DashboardAgendaKind {
  event,
  eventRegistration,
  survey,
  tracer,
  job,
  insightDue,
  insightReview,
}

/// One dated item in "Upcoming & deadlines".
class DashboardAgendaItem {
  const DashboardAgendaItem({
    required this.kind,
    required this.date,
    required this.title,
    required this.detail,
    this.overdue = false,
  });

  final DashboardAgendaKind kind;
  final DateTime date;
  final String title;
  final String detail;
  final bool overdue;

  /// Admin menu index of the page that owns the item.
  int get menuIndex => switch (kind) {
    DashboardAgendaKind.event || DashboardAgendaKind.eventRegistration => 1,
    DashboardAgendaKind.survey || DashboardAgendaKind.tracer => 10,
    DashboardAgendaKind.job => 5,
    DashboardAgendaKind.insightDue || DashboardAgendaKind.insightReview => 15,
  };
}

/// Directory, tracer, employment, survey and Program Insights figures for the
/// dashboard. Definitions match Reports & Analytics and Program Insights.
class DashboardInsights {
  const DashboardInsights({
    this.registered = 0,
    this.tracerResponded = 0,
    this.currentTracerTitle,
    this.currentTracerCloseAt,
    this.employmentRecords = 0,
    this.employed = 0,
    this.findingsOpen,
    this.findingsInProgress,
    this.findingsCritical,
    this.actionsOverdue,
    this.programs = const [],
    this.otherSurveys = const DashboardSurveySummary(),
    this.deadlines = const [],
  });

  final int registered;

  /// Registered alumni who submitted any published/closed CHED tracer wave
  /// (Reports "Tracer reach").
  final int tracerResponded;

  /// Newest published CHED tracer, if any.
  final String? currentTracerTitle;
  final DateTime? currentTracerCloseAt;

  /// Registered alumni with employment information (one per person).
  final int employmentRecords;
  final int employed;

  /// Null when Program Insights could not be loaded.
  final int? findingsOpen;
  final int? findingsInProgress;
  final int? findingsCritical;
  final int? actionsOverdue;

  final List<DashboardProgramStat> programs;
  final DashboardSurveySummary otherSurveys;

  /// Survey, job and Program Insights dates (events are added by
  /// [buildDashboardAgenda]).
  final List<DashboardAgendaItem> deadlines;

  double? get tracerRate =>
      registered == 0 ? null : tracerResponded / registered;

  double? get employmentRate =>
      employmentRecords == 0 ? null : employed / employmentRecords;

  bool get insightsAvailable => findingsOpen != null;

  int? get findingsActive => findingsOpen == null
      ? null
      : findingsOpen! + (findingsInProgress ?? 0);

  static DashboardInsights build({
    required List<AlumniMember> members,
    required List<Survey> surveys,
    required Map<String, int> assignmentCounts,
    required Map<String, int> submittedCounts,
    required Set<String> tracerSubmitterIds,
    required List<EmploymentRecord> employmentRecords,
    required List<JobPosting> activeJobs,
    List<DssFlag>? flags,
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final clock = now ?? DateTime.now();

    final analytics = AdminReportsAnalytics(
      members: members,
      employmentRecords: employmentRecords,
      surveys: surveys,
      announcements: const [],
      forumTopics: const [],
      portalUserCount: 0,
      assignmentCountsBySurveyId: assignmentCounts,
      submittedResponsesBySurveyId: submittedCounts,
    );
    final coverage = buildTracerCoverage(
      members: analytics.activeRoster,
      tracerSubmitterUserIds: tracerSubmitterIds,
      filters: ReportsDashboardFilters.empty,
      surveys: surveys,
    );

    final currentTracer = _currentTracer(surveys);

    final findings = flags
        ?.where(
          (f) =>
              f.isFinding &&
              (f.status == DssFlagStatus.open ||
                  f.status == DssFlagStatus.inProgress),
        )
        .toList(growable: false);

    return DashboardInsights(
      registered: coverage.registered,
      tracerResponded: coverage.tookTracer,
      currentTracerTitle: currentTracer?.title,
      currentTracerCloseAt: currentTracer?.closeAt,
      employmentRecords: analytics.reportEmploymentCount,
      employed: analytics.employedCount,
      findingsOpen: findings
          ?.where((f) => f.status == DssFlagStatus.open)
          .length,
      findingsInProgress: findings
          ?.where((f) => f.status == DssFlagStatus.inProgress)
          .length,
      findingsCritical: findings
          ?.where((f) => f.severity == DssSeverity.critical)
          .length,
      actionsOverdue: flags?.where((f) => f.isOverdue(clock)).length,
      programs: _programs(analytics.activeRoster, tracerSubmitterIds),
      otherSurveys: _otherSurveys(analytics),
      deadlines: [
        ..._surveyDeadlines(surveys, clock),
        ..._jobDeadlines(activeJobs, today),
        ..._insightDates(flags ?? const [], clock),
      ],
    );
  }

  static Survey? _currentTracer(List<Survey> surveys) {
    Survey? best;
    DateTime? bestAt;
    for (final s in surveys) {
      if (!s.isChedGtsBuiltin ||
          s.archived ||
          s.status != SurveyStatus.published) {
        continue;
      }
      final at = s.publishedAt ?? s.openAt ?? s.createdAt;
      if (bestAt == null || at.isAfter(bestAt)) {
        best = s;
        bestAt = at;
      }
    }
    return best;
  }

  static List<DashboardProgramStat> _programs(
    List<AlumniMember> activeRoster,
    Set<String> tracerSubmitterIds,
  ) {
    final alumni = <String, int>{};
    final registered = <String, int>{};
    final responded = <String, int>{};
    for (final m in activeRoster) {
      final program = m.course.trim().isEmpty ? 'Unknown' : m.course.trim();
      alumni[program] = (alumni[program] ?? 0) + 1;
      if (!m.isRegisteredUser) continue;
      registered[program] = (registered[program] ?? 0) + 1;
      final uid = (m.authUid ?? '').trim();
      if (uid.isNotEmpty && tracerSubmitterIds.contains(uid)) {
        responded[program] = (responded[program] ?? 0) + 1;
      }
    }
    final list = [
      for (final entry in alumni.entries)
        DashboardProgramStat(
          program: entry.key,
          alumni: entry.value,
          registered: registered[entry.key] ?? 0,
          tracerResponded: responded[entry.key] ?? 0,
        ),
    ];
    list.sort((a, b) {
      final byAlumni = b.alumni.compareTo(a.alumni);
      return byAlumni != 0 ? byAlumni : a.program.compareTo(b.program);
    });
    return list;
  }

  static DashboardSurveySummary _otherSurveys(AdminReportsAnalytics a) {
    final others = a.surveys
        .where((s) => !s.archived && !s.isChedGtsBuiltin)
        .toList(growable: false);
    var assigned = 0;
    var submitted = 0;
    String? lowestTitle;
    double? lowestRate;
    for (final s in others) {
      final sAssigned = a.assignmentCount(s);
      final sSubmitted = a.submittedResponseCount(s);
      assigned += sAssigned;
      submitted += sSubmitted;
      if (s.status != SurveyStatus.published || sAssigned == 0) continue;
      final rate = sSubmitted / sAssigned;
      if (lowestRate == null ||
          rate < lowestRate ||
          (rate == lowestRate && s.title.compareTo(lowestTitle!) < 0)) {
        lowestRate = rate;
        lowestTitle = s.title;
      }
    }
    return DashboardSurveySummary(
      published: others
          .where((s) => s.status == SurveyStatus.published)
          .length,
      drafts: others.where((s) => s.status == SurveyStatus.draft).length,
      assigned: assigned,
      submitted: submitted,
      lowestTitle: lowestTitle,
      lowestRate: lowestRate,
    );
  }

  static Iterable<DashboardAgendaItem> _surveyDeadlines(
    List<Survey> surveys,
    DateTime now,
  ) sync* {
    for (final s in surveys) {
      final close = s.closeAt;
      if (s.archived || s.status != SurveyStatus.published || close == null) {
        continue;
      }
      if (close.isBefore(now)) continue;
      final tracer = s.isChedGtsBuiltin;
      yield DashboardAgendaItem(
        kind: tracer ? DashboardAgendaKind.tracer : DashboardAgendaKind.survey,
        date: close,
        title: s.title,
        detail: tracer ? 'Tracer closes' : 'Survey closes',
      );
    }
  }

  static Iterable<DashboardAgendaItem> _jobDeadlines(
    List<JobPosting> jobs,
    DateTime today,
  ) sync* {
    for (final j in jobs) {
      if (_day(j.applicationDeadline).isBefore(today)) continue;
      final company = j.companyName.trim();
      yield DashboardAgendaItem(
        kind: DashboardAgendaKind.job,
        date: j.applicationDeadline,
        title: j.jobTitle,
        detail: company.isEmpty
            ? 'Application deadline'
            : 'Application deadline · $company',
      );
    }
  }

  static Iterable<DashboardAgendaItem> _insightDates(
    List<DssFlag> flags,
    DateTime now,
  ) sync* {
    final today = _day(now);
    for (final f in flags) {
      if (f.status != DssFlagStatus.open &&
          f.status != DssFlagStatus.inProgress) {
        continue;
      }
      final due = f.dueDate;
      if (due != null) {
        yield DashboardAgendaItem(
          kind: DashboardAgendaKind.insightDue,
          date: due,
          title: f.title,
          detail: 'Program Insights · action due',
          overdue: f.isOverdue(now),
        );
      }
      final review = f.reviewDate;
      if (review != null && !_day(review).isBefore(today)) {
        yield DashboardAgendaItem(
          kind: DashboardAgendaKind.insightReview,
          date: review,
          title: f.title,
          detail: 'Program Insights · progress review',
        );
      }
    }
  }
}

/// Events plus [deadlines] for the next [windowDays] days, overdue items first
/// (oldest first), then by date. One row per event: its registration deadline
/// is shown on the event row, or as its own row only when the event itself is
/// outside the window.
List<DashboardAgendaItem> buildDashboardAgenda({
  required List<AlumniEvent> events,
  required List<DashboardAgendaItem> deadlines,
  DateTime? now,
  int windowDays = 30,
}) {
  final clock = now ?? DateTime.now();
  final today = _day(clock);
  final lastDay = today.add(Duration(days: windowDays));
  bool inWindow(DateTime d) {
    final day = _day(d);
    return !day.isBefore(today) && !day.isAfter(lastDay);
  }

  final items = <DashboardAgendaItem>[];
  for (final e in events) {
    if (e.cancelled || e.status == 'Archived') continue;
    final reg = e.registrationDeadline;
    final regUpcoming =
        reg != null && reg.isAfter(clock) && _day(reg).isBefore(_day(e.date));
    if (inWindow(e.date)) {
      items.add(
        DashboardAgendaItem(
          kind: DashboardAgendaKind.event,
          date: e.date,
          title: e.theme,
          detail: regUpcoming
              ? 'Event · registration closes ${_shortDate(reg)}'
              : 'Event',
        ),
      );
    } else if (regUpcoming && inWindow(reg)) {
      items.add(
        DashboardAgendaItem(
          kind: DashboardAgendaKind.eventRegistration,
          date: reg,
          title: e.theme,
          detail: 'Event registration closes · event on ${_shortDate(e.date)}',
        ),
      );
    }
  }
  for (final d in deadlines) {
    if (d.overdue || inWindow(d.date)) items.add(d);
  }

  items.sort((a, b) {
    if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.kind.index.compareTo(b.kind.index);
  });
  return items;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _shortDate(DateTime d) => DateFormat('MMM d').format(d);
