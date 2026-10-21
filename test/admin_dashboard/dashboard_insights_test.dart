import 'package:alumni_system/features/admin/dashboard/application/dashboard_insights.dart';
import 'package:alumni_system/features/admin/dss/models/dss_models.dart';
import 'package:alumni_system/features/admin/roster/models/alumni_member_model.dart';
import 'package:alumni_system/features/alumni/tracer/models/id_tracer_model.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';
import 'package:alumni_system/features/surveys/models/survey_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 14, 9);

AlumniMember _member(
  String id,
  String course, {
  String? uid,
  bool deactivated = false,
}) => AlumniMember(
  id: id,
  fullName: 'Member $id',
  course: course,
  studentId: 'S-$id',
  authUid: uid,
  isRegisteredUser: uid != null,
  isDeactivated: deactivated,
);

Survey _survey(
  String id, {
  SurveyStatus status = SurveyStatus.published,
  bool ched = false,
  bool archived = false,
  DateTime? closeAt,
  DateTime? publishedAt,
  int assigned = 0,
  int submitted = 0,
}) => Survey(
  id: id,
  title: 'Survey $id',
  description: '',
  status: status,
  createdBy: 'admin',
  createdAt: DateTime(2026, 1, 1),
  publishedAt: publishedAt,
  closeAt: closeAt,
  kind: ched ? 'ched_gts_builtin' : null,
  archived: archived,
  assignmentCount: assigned,
  responseCount: submitted,
);

EmploymentRecord _employment(String uid, String status) => EmploymentRecord(
  id: 'r-$uid',
  userId: uid,
  userName: '',
  userEmail: '',
  schoolId: '',
  employmentStatus: status,
  contactNumber: '',
);

JobPosting _job(String id, DateTime deadline) => JobPosting(
  id: id,
  companyName: 'Acme',
  companyLogo: '',
  jobTitle: 'Job $id',
  jobType: 'Full-time',
  location: '',
  salaryRange: '',
  description: '',
  requirements: const [],
  benefits: const [],
  postedDate: DateTime(2026, 10, 1),
  applicationDeadline: deadline,
  contactEmail: '',
  applicationMethod: '',
  isActive: true,
  views: 0,
  applications: 0,
  adminId: '',
  isRemote: false,
  experienceLevel: '',
  status: 'active',
);

DssFlag _flag(
  String id, {
  DssFlagStatus status = DssFlagStatus.open,
  DssSeverity? severity,
  String? strength = 'strong',
  DateTime? dueDate,
  DateTime? reviewDate,
}) => DssFlag(
  id: id,
  ruleId: 'LOW_EMPLOYMENT',
  course: 'BSIT',
  batchYear: '2024',
  surveyId: 's',
  surveyTitle: 'GTS',
  metricValue: 0.2,
  thresholdSnapshot: 0.5,
  sampleN: 20,
  confidence: DssConfidence.ok,
  status: status,
  title: 'Finding $id',
  body: '',
  recommendedAction: '',
  evidence: const {},
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
  severity: severity,
  evidenceStrengthRaw: strength,
  dueDate: dueDate,
  reviewDate: reviewDate,
);

AlumniEvent _event(
  String id,
  DateTime date, {
  DateTime? registrationDeadline,
  bool cancelled = false,
}) => AlumniEvent(
  id: id,
  theme: 'Event $id',
  batchYear: '',
  date: date,
  venue: '',
  status: 'active',
  comments: 0,
  registrationDeadline: registrationDeadline,
  cancelled: cancelled,
);

DashboardInsights _build({
  List<AlumniMember>? members,
  List<Survey> surveys = const [],
  Map<String, int> assigned = const {},
  Map<String, int> submitted = const {},
  Set<String> submitters = const {},
  List<EmploymentRecord> employment = const [],
  List<JobPosting> jobs = const [],
  List<DssFlag>? flags = const [],
}) => DashboardInsights.build(
  members: members ?? const [],
  surveys: surveys,
  assignmentCounts: assigned,
  submittedCounts: submitted,
  tracerSubmitterIds: submitters,
  employmentRecords: employment,
  activeJobs: jobs,
  flags: flags,
  now: _now,
);

void main() {
  final roster = [
    _member('1', 'BSIT', uid: 'u1'),
    _member('2', 'BSIT', uid: 'u2'),
    _member('3', 'BSIT'),
    _member('4', 'BTLED-ICT', uid: 'u4'),
    _member('5', '', uid: 'u5'),
    _member('6', 'BSIT', uid: 'u6', deactivated: true),
  ];

  group('tracer response (Reports "Tracer reach" definition)', () {
    test('counts registered active alumni who submitted a tracer', () {
      final i = _build(members: roster, submitters: {'u1', 'u4', 'u6', 'zz'});
      expect(i.registered, 4);
      expect(i.tracerResponded, 2);
      expect(i.tracerRate, 0.5);
    });

    test('no registered alumni → no rate', () {
      final i = _build(members: [_member('1', 'BSIT')]);
      expect(i.tracerRate, isNull);
    });

    test('current tracer is the newest published CHED survey', () {
      final i = _build(
        surveys: [
          _survey('old', ched: true, publishedAt: DateTime(2025, 1, 1)),
          _survey(
            'new',
            ched: true,
            publishedAt: DateTime(2026, 6, 1),
            closeAt: DateTime(2026, 11, 30),
          ),
          _survey(
            'closed',
            ched: true,
            status: SurveyStatus.closed,
            publishedAt: DateTime(2026, 9, 1),
          ),
          _survey('other', publishedAt: DateTime(2026, 10, 1)),
        ],
      );
      expect(i.currentTracerTitle, 'Survey new');
      expect(i.currentTracerCloseAt, DateTime(2026, 11, 30));
    });
  });

  test('employment rate uses Reports calculation (one per person)', () {
    final i = _build(
      members: roster,
      employment: [
        _employment('u1', 'Employed'),
        _employment('u2', 'Unemployed'),
        _employment('not-on-roster', 'Employed'),
      ],
    );
    expect(i.employmentRecords, 2);
    expect(i.employed, 1);
    expect(i.employmentRate, 0.5);
    expect(_build().employmentRate, isNull);
  });

  test('programs: per-program counts, largest first, Unknown course', () {
    final i = _build(members: roster, submitters: {'u1'});
    expect(i.programs.map((p) => p.program), ['BSIT', 'BTLED-ICT', 'Unknown']);
    final bsit = i.programs.first;
    expect(bsit.alumni, 3);
    expect(bsit.registered, 2);
    expect(bsit.tracerResponded, 1);
    expect(bsit.registrationRate, closeTo(2 / 3, 1e-9));
    expect(bsit.tracerRate, 0.5);
    expect(
      _build(members: [_member('1', 'X')]).programs.single.tracerRate,
      isNull,
    );
  });

  test('other surveys exclude CHED tracer and archived surveys', () {
    final i = _build(
      surveys: [
        _survey('a'),
        _survey('b'),
        _survey('d', status: SurveyStatus.draft),
        _survey('c', status: SurveyStatus.closed),
        _survey('t', ched: true),
        _survey('x', archived: true),
      ],
      assigned: {'a': 10, 'b': 4, 'c': 6, 't': 50, 'x': 9},
      submitted: {'a': 5, 'b': 1, 'c': 6, 't': 40, 'x': 9},
    );
    final s = i.otherSurveys;
    expect(s.published, 2);
    expect(s.drafts, 1);
    expect(s.assigned, 20);
    expect(s.submitted, 12);
    expect(s.responseRate, 0.6);
    expect(s.lowestTitle, 'Survey b');
    expect(s.lowestRate, 0.25);
  });

  group('Program Insights', () {
    test('counts open/in-progress findings like the Program Insights page', () {
      final i = _build(
        flags: [
          _flag('1', severity: DssSeverity.critical),
          _flag('2', status: DssFlagStatus.inProgress),
          _flag('3', status: DssFlagStatus.watch),
          _flag('4', strength: 'watch'),
          _flag('5', status: DssFlagStatus.resolved),
          _flag('6', dueDate: DateTime(2026, 10, 10)),
        ],
      );
      expect(i.findingsOpen, 2);
      expect(i.findingsInProgress, 1);
      expect(i.findingsActive, 3);
      expect(i.findingsCritical, 1);
      expect(i.actionsOverdue, 1);
    });

    test('unavailable when flags could not load', () {
      final i = _build(flags: null);
      expect(i.insightsAvailable, isFalse);
      expect(i.findingsActive, isNull);
    });
  });

  group('deadlines and agenda', () {
    test('survey, job and insight dates; past and closed items skipped', () {
      final i = _build(
        surveys: [
          _survey('s', closeAt: DateTime(2026, 10, 20)),
          _survey('t', ched: true, closeAt: DateTime(2026, 11, 2)),
          _survey('past', closeAt: DateTime(2026, 10, 1)),
          _survey(
            'draft',
            status: SurveyStatus.draft,
            closeAt: DateTime(2026, 10, 20),
          ),
        ],
        jobs: [
          _job('j', DateTime(2026, 10, 25)),
          _job('old', DateTime(2026, 10, 1)),
        ],
        flags: [
          _flag(
            'f',
            dueDate: DateTime(2026, 10, 10),
            reviewDate: DateTime(2026, 10, 18),
          ),
          _flag(
            'done',
            status: DssFlagStatus.resolved,
            dueDate: DateTime(2026, 10, 16),
          ),
        ],
      );
      final kinds = {for (final d in i.deadlines) d.title: d.kind};
      expect(kinds['Survey s'], DashboardAgendaKind.survey);
      expect(kinds['Survey t'], DashboardAgendaKind.tracer);
      expect(kinds['Job j'], DashboardAgendaKind.job);
      expect(kinds.containsKey('Survey past'), isFalse);
      expect(kinds.containsKey('Survey draft'), isFalse);
      expect(kinds.containsKey('Job old'), isFalse);
      expect(kinds.containsKey('Finding done'), isFalse);
      final due = i.deadlines.firstWhere(
        (d) => d.kind == DashboardAgendaKind.insightDue,
      );
      expect(due.overdue, isTrue);
      expect(
        i.deadlines.where((d) => d.kind == DashboardAgendaKind.insightReview),
        hasLength(1),
      );
    });

    test('overdue first, then by date, within 30 days', () {
      final items = buildDashboardAgenda(
        now: _now,
        events: [
          _event('soon', DateTime(2026, 10, 15)),
          _event('far', DateTime(2026, 12, 25)),
          _event('cancelled', DateTime(2026, 10, 16), cancelled: true),
        ],
        deadlines: [
          DashboardAgendaItem(
            kind: DashboardAgendaKind.job,
            date: DateTime(2026, 10, 20),
            title: 'Job',
            detail: '',
          ),
          DashboardAgendaItem(
            kind: DashboardAgendaKind.insightDue,
            date: DateTime(2026, 10, 2),
            title: 'Overdue',
            detail: '',
            overdue: true,
          ),
          DashboardAgendaItem(
            kind: DashboardAgendaKind.survey,
            date: DateTime(2026, 11, 20),
            title: 'Too late',
            detail: '',
          ),
        ],
      );
      expect(items.map((e) => e.title), ['Overdue', 'Event soon', 'Job']);
      expect(items.map((e) => e.menuIndex), [15, 1, 5]);
    });

    test('registration deadline shown on the event row, never twice', () {
      final items = buildDashboardAgenda(
        now: _now,
        events: [
          _event(
            'a',
            DateTime(2026, 10, 30),
            registrationDeadline: DateTime(2026, 10, 20),
          ),
          _event(
            'b',
            DateTime(2026, 12, 5),
            registrationDeadline: DateTime(2026, 10, 25),
          ),
        ],
        deadlines: const [],
      );
      expect(items, hasLength(2));
      expect(items[0].title, 'Event b');
      expect(items[0].kind, DashboardAgendaKind.eventRegistration);
      expect(items[0].detail, 'Event registration closes · event on Dec 5');
      expect(items[1].title, 'Event a');
      expect(items[1].kind, DashboardAgendaKind.event);
      expect(items[1].detail, 'Event · registration closes Oct 20');
    });
  });
}
